# Research: Eval-based testing for LLM / agentic features in x-qa

> **Date:** 2026-06-06
> **Source:** `/x-skills:x-research` (Deep, 4-lane parallel dispatch)
> **Lanes:** perplexity (metric taxonomy + non-determinism) · exa (practical code: promptfoo/deepeval/CI) · deepwiki→`confident-ai/deepeval` (framework internals) · gemini-3-pro (Google-grounded 2025–2026 SOTA)
> **Goal:** Inform extending `skills/x-qa` to test AI agentic applications and LLM features, where deterministic QA does not work.

---

## TL;DR — the gap and the shape of the fix

**The gap.** x-qa today is a *deterministic assertion* engine: it drives an HTTP channel and asserts `status == 200`, response shape, and obligation coverage. That model assumes **one correct output per input**. LLM features break that assumption — the same input yields a *distribution* of valid outputs, so `actual == expected` is the wrong test. The whole industry calls the replacement **"evals"**: instead of asserting equality, you **score** an output against a **metric** and gate on a **threshold / pass-rate** over **N samples**.

**The fix, in one line.** Add an *eval class* alongside the existing *assertion class*: same case/KB/coverage machinery, but the "assert" becomes a **scorer + threshold**, the verdict becomes **statistical (pass-rate over N runs)**, and for agents you must additionally **capture the trajectory (tool calls / steps), not just the final HTTP response.**

**Three things genuinely new to x-qa** (everything else reuses existing infra):
1. **Scorer assertions** (model-graded, semantic-similarity, RAG, agentic, safety) with float thresholds — not booleans.
2. **Statistical verdict** — N-sample pass-rate gating. This is *not* the existing flaky-retry (flaky = transient infra; eval variance = inherent and must be *measured*, not recovered-from).
3. **Trajectory capture** — the agent's internal tool-call/step trace. This is the one real infrastructure dependency; the rest is schema + runner-prompt work.

---

## 1. The eval paradigm vs assertion-based testing

| | Assertion-based (x-qa today) | Eval-based (what LLM features need) |
|---|---|---|
| Unit | test case → boolean pass/fail | test case → **score ∈ [0,1]** vs **threshold** |
| Expectation | exact / structural match | **golden dataset** + **metric** |
| Determinism | one correct answer | **distribution** of valid answers |
| Verdict | single run | **N samples → pass-rate**, confidence interval |
| Failure | bug | could be variance → needs statistics |

Core eval architecture everyone converges on (perplexity, deepeval, promptfoo, braintrust):

```
dataset (golden set)  →  run system under test  →  scorer/metric  →  threshold/pass-rate gate
```

Two orthogonal axes you must support:
- **Offline vs online.** Offline = curated golden set in version control, run in CI as a gate. Online = score live production traffic via tracing. (x-qa is an offline gate; online is a later concern.)
- **Component-level vs end-to-end (trace).** Score the final answer *and* score intermediate steps (which retrieval chunk, which tool, which reasoning step). deepeval does this with `@observe` spans; promptfoo via OTLP trace ingestion.

---

## 2. Taxonomy of scorers (the menu x-qa would offer)

Ordered cheapest/most-deterministic → most expensive/most-subjective. **Run them in that order** (tiered gate — see §6).

### a. Deterministic / rule-based (cheap, no LLM)
Exact match, regex, `contains`, **JSON-schema / is-json / contains-json**, **code execution** (run generated code, assert result). x-qa already does the HTTP-shape subset. Still the first line of defense for LLM output (format, required fields, no banned strings).

### b. Statistical / reference-based (cheap, needs a reference)
| Metric | Measures | Good for | Useless for |
|---|---|---|---|
| BLEU | n-gram precision + brevity penalty | machine translation, exact phrasing | open-ended, paraphrase-heavy |
| ROUGE | n-gram/LCS recall | summarization (content coverage) | factuality, reasoning |
| METEOR | unigram F + stem/synonym match | MT/summarization w/ paraphrase tolerance | long free-form |
| **BERTScore** | token-level **semantic** cosine match | paraphrase-heavy, abstractive | reference incomplete/wrong → false high |
| **Embedding/cosine similarity** | whole-text semantic similarity | **regression sanity checks**, dedup | grading correctness (two wrong-but-similar answers score high) |

> For RAG / reasoning / chat / agents these are **diagnostic only** (catch a quality collapse), never the primary success criterion. Embedding-similarity is the most useful one for x-qa as a cheap regression tripwire.

### c. Model-graded / LLM-as-a-judge (expensive, subjective, most powerful)
- **`llm-rubric`** — natural-language criteria → pass/fail (start here; one clear criterion).
- **G-Eval** — chain-of-thought: judge generates eval steps from criteria, then scores; deepeval normalizes via token-probability-weighted summation.
- **DAG (Deep Acyclic Graph)** — deterministic decision-tree of judgement nodes (`BinaryJudgementNode`, `VerdictNode`); use when the rubric has explicit branches. More reproducible than raw G-Eval.
- **Pairwise / `select-best`** — A-vs-B preference; **factuality** (OpenAI-eval method, claim adherence to reference).
- Biases + mitigations (must implement if judges gate CI): **position bias** → pairwise with swap; **verbosity bias** & **self-enhancement bias** → CoT rationale-before-score, specific bulleted rubrics, temperature=0; **prompt-injection of the judge** → treat candidate output as untrusted, add an `injection_guard` rubric that fails if the output tries to instruct the judge.

### d. RAG-specific (mix of judge + retrieval labels)
| Metric | Component | Needs gold answer? | Inputs | Focus |
|---|---|---|---|---|
| Faithfulness / groundedness | generator | no | q, context, answer | hallucination vs context |
| Answer relevancy | generator | no | q, answer | on-prompt relevance |
| Contextual precision | retriever | no | q, context (+labels) | how much retrieved is useful |
| Contextual recall | retriever | usually | q, context, gold | did retrieval get *enough* |
| Context relevance | retriever | no | q, context | fraction of context that's noise |

### e. Agent-specific — see §3.

### f. Safety / guardrail (classifier or judge)
Toxicity (classifier prob per category → rate), **PII leakage** (regex/NER + canary-extraction rate), bias (counterfactual balanced sets → group deltas), **prompt-injection robustness** (injection dataset → *injection success rate*), **jailbreak resistance** (jailbreak set → *attack success rate*). Report both **binary pass-rate** and **score distribution**.

---

## 3. Agentic evaluation (the hardest, most relevant part)

Key principle (gemini SOTA): **grade the trajectory, not just the final answer** — an agent can get the right answer via a catastrophic path (infinite loop, hallucinated tool, wrong-but-lucky). Final-answer-only is an anti-pattern.

**Metrics (deepeval names + promptfoo assertion equivalents):**

| Concern | deepeval metric | promptfoo assertion | Inputs required |
|---|---|---|---|
| Right tool, right selection | `ToolCorrectnessMetric` | `trajectory:tool-used` | input, output, `tools_called`, `expected_tools` |
| Right arguments | `ArgumentCorrectness` | `trajectory:tool-args-match` | tool call payloads |
| Right order | — | `trajectory:tool-sequence` | ordered trace |
| Did it finish the goal | `TaskCompletion` / `GoalAccuracy` | `trajectory:goal-success` (LLM judge) | input, output (+trace) |
| No wasted steps | `StepEfficiency` | `trajectory:step-count` | normalized trace |
| Followed its plan | `PlanAdherence` / `PlanQuality` | — | trace |
| Multi-turn quality | `KnowledgeRetention`, `ConversationCompleteness`, `TurnRelevancy`, `TurnFaithfulness`, `RoleAdherence` | (multi-turn provider) | `ConversationalTestCase` = list of `Turn{role, content}` |

> **Caveat — these metric names are research-grade, not an API contract.** `ToolCorrectness`, `TaskCompletion`, `Faithfulness`, `AnswerRelevancy` are well-established; `StepEfficiency` / `PlanAdherence` / `PlanQuality` / `GoalAccuracy` came from a deepwiki summary and may be version-specific or conflated. Since the recommendation (§6) is **native scorers**, treat this list as *what to score* (inspiration), not a deepeval API to call. Verify exact names/signatures against the installed version if you ever integrate the library directly.

**Simulated-user testing** (gemini): for multi-turn agents, spin up an LLM "simulated user" (angry customer, confused user) that drives 10–15 turns to test state preservation. UK AISI **Inspect** and Maxim AI do this natively.

**Benchmarks that inform real-world agent QA:** SWE-bench (coding agents resolve real issues), τ-bench / WebArena (stateful API/DOM navigation), AgentBench. Mine patterns from these into a private golden set.

**The infra cost:** all `trajectory:*` / `tool_*` / trace metrics require the agent's **internal spans**, not the HTTP body. promptfoo gets them via a custom `TracingProcessor` exporting to its **OTLP receiver**; deepeval via `@observe` span tree. **Mock stateful worlds** for trajectory eval: when the agent calls `DELETE /x`, the mock must update state so a later `GET /x` reflects it.

---

## 4. Handling non-determinism statistically

- **N samples per case** (typically 3–5), fixed settings; score each; aggregate (mean / median / best-of-N / **% above threshold**).
- **Per-case pass-rate** `p_i = passes/N`; suite verdict = mean of `p_i` with **binomial/bootstrap CI**; regression triggers when pass-rate drops below target (e.g. 95%).
- **Temperature = 0 for judges** (stabilize scoring); test-system temperature should **match production**.
- **Assertions + evals together:** hard constraints (JSON valid, no banned tool, no PII) as assertions; soft aspects (helpfulness, faithfulness) as scored evals.

> **Critical distinction for x-qa:** this N-sample pass-rate is **NOT** the existing `--retry-flaky` mechanism. Flaky-retry *recovers from* a transient infra failure (a 503, a cold container). Eval sampling *measures* inherent output variance and keeps the distribution. Conflating them would silently hide a quality regression as "flaky-recovered." Needs a distinct `--samples N` + pass-rate gate.

---

## 5. Framework landscape (2025–2026)

| Framework | Best at | Model | Test-case definition |
|---|---|---|---|
| **DeepEval** (Confident AI) | "pytest for LLMs", richest metric library, agentic + RAG + multi-turn, CI-native | Python | `LLMTestCase(input, actual_output, expected_output, retrieval_context, tools_called, expected_tools)` + `assert_test(case, [Metric(threshold=…)])`; `deepeval test run` |
| **promptfoo** | fast CLI matrix testing, prompt/model sweeps, **declarative YAML assertions** incl. `trajectory:*`, LLM-rubric, CI matrices | Node/YAML | `tests: [{vars, assert: [{type, value, threshold}]}]`; `npx promptfoo eval` |
| **Ragas** | offline **RAG** component metrics | Python | dataset + faithfulness/relevancy/precision/recall |
| **OpenAI Evals** | low-level benchmark scaffolding | Python | registry of evals |
| **Inspect** (UK AISI) | rigorous multi-turn **agent capability/safety** benchmarking, simulated users | Python | tasks + solvers + scorers |
| **LangSmith / Langfuse** | **tracing + online eval** of agent executions | SaaS/OSS | trace ingestion + evaluators |
| **Braintrust** | dataset mgmt + CI integration | SaaS | scorers + experiments |
| **Arize Phoenix** | OSS observability, OTel-native | OSS | OTel spans + evals |
| **Pydantic Evals** | strictly-typed agent output eval | Python | typed cases |

**Reference CI pattern** (numoru `agent-evals-template`, exa): promptfoo (deterministic + rubric) ∥ deepeval (RAG metrics in pytest) → a guard binary blocks merge when PR aggregate score drops > `--threshold 0.05` vs a rolling baseline. Per-layer thresholds: `llm-rubric 0.75`, `latency 6000ms`, `Faithfulness 0.85`, `AnswerRelevancy 0.80`, `ContextualRecall 0.70`.

**Tiered pipeline SOTA (gemini):** (1) Fast-gate PR-level — regex/schema/embedding, <2 min. (2) Deep-gate merge-level — judges + multi-turn sims over 100–500 hard golden cases. (3) Shadow/online — OTel GenAI semantic conventions (`gen_ai.prompt`, `gen_ai.completion`, tool spans) into Phoenix/Langfuse.

---

## 6. How this maps onto x-qa's existing architecture

The good news: **most of x-qa's spine is reusable.** The eval extension is mostly *new scorer types + statistical verdict + trace capture*, not a rewrite.

> **Proposal-grade, not verified.** This section is grounded in `SKILL.md` + `gotchas.md` (which were read) but makes file-specific claims (`test-plan-schema.md`, `kb-schema.md`, `aggregate-results.sh`) about files **not opened** in this research pass. The *altitude* (what to add, where conceptually) is sound; the *exact* touchpoints are inferred and must be confirmed against the real schema files in the planning phase.

| x-qa concept (today) | Eval extension |
|---|---|
| `profile.json` channels (`http`/`browser`/`computer-use`) | add an **`llm` / `agent` driver class** (or an `eval: true` flag on an http channel). For agents, the channel must also expose a **trace endpoint / OTLP receiver** to capture tool spans. |
| Case `assert` (status/shape) | add **scorer assertions**: `llm-rubric`, `g-eval`, `semantic-similarity`(threshold), RAG (`faithfulness`/`answer-relevancy`/`contextual-*`), agentic (`tool-correctness`/`trajectory:*`/`task-completion`), safety (`toxicity`/`pii`/`injection`/`jailbreak`). Each carries a **float threshold**, not a boolean. |
| Verdict `pass/warn/fail` + `--retry-flaky` | add **`--samples N` + per-case pass-rate gate** (distinct from flaky-retry — see §4). `warn` semantics fit "score in soft band". |
| KB green corpus + `baselines/*.json` | golden case gains `expected_output` / `retrieval_context` / `expected_tools`; baseline stores **score mean + pass-rate**, and **regression = score drop > delta** (cf. numoru `--threshold 0.05`), not response-shape diff. |
| `scope.json.obligations[]` (`inv:`/`xtrans:`/`fmode:`) | add obligation classes: **quality** (faithfulness on a RAG endpoint), **safety** (no PII / injection-resistant), **capability** (tool X must fire for intent Y). Coverage gate then enforces an eval case exists per obligation. |
| Case runners (gemini/claude bg) | add a **judge runner**: temperature=0, rubric/G-Eval prompt template, returns `{score, reason}`. Reuse the existing dispatch + `X_QA_*_RUNNER` infra; add a calibration step. |
| Exploratory bug-hunt team | natural fit for **red-teaming**: injection/jailbreak probes, adversarial multi-turn — workers already mint findings; safety findings become safety obligations. |
| **Real-QA contract** ("never run repo test suites") | **Decision point.** Shelling out to `promptfoo eval` / `deepeval test run` violates this contract *and* the "drive the channel yourself" philosophy. Prefer **native scorers** (x-qa calls the LLM endpoint, applies judge/embedding/rule scorers via its own runners). Reserve external-framework orchestration as an explicit opt-in. |

### Two cruxes for the planning phase

These two decisions are the whole ballgame — settle them before any schema work.

1. **Native scorers vs orchestrating an eval framework (the Real-QA contract conflict).** This is *the* architectural decision, not a footnote. `deepeval test run` / `promptfoo eval` are exactly the kind of test-runner commands the Real-QA contract forbids — so honoring the contract means **reimplementing LLM-as-judge + RAG metrics + embedding similarity natively** as x-qa runners. That is a *large* build, weighed against battle-tested libraries. The tradeoff (contract-consistent + consistent UX, but expensive and reinventing metrics ↔ fast + proven, but contract-violating + new heavy dependency) determines the size and shape of the entire feature. Resolve it first.

2. **Golden-data provenance.** x-qa's value is that it **auto-generates** cases from code + domain research — but it cannot mint "expected outputs" for open-ended LLM features (there is no single right answer to generate). So the extension must lean on **reference-free** scorers (faithfulness, answer-relevancy, tool-correctness, safety — none need a gold answer) and **rubric-based** judges (criteria, not references), reserving **reference-based** metrics (BLEU/BERTScore/contextual-recall) for the minority of cases that genuinely have a gold answer (e.g. a deterministic tool result, a known retrieval target). This constraint is what keeps the feature tractable inside x-qa's auto-gen model — make it explicit in the design.

**Concrete first-increment proposal** (smallest credible slice):
1. Schema: add `eval` assertion types + `threshold` + `samples` to the case schema (`references/test-plan-schema.md`, `kb-schema.md`).
2. Runner: a judge-runner prompt template (`references/case-runner-prompts.md`) — `llm-rubric` + `semantic-similarity` first (cheapest judges), temperature=0, CoT, injection-guard.
3. Verdict: N-sample pass-rate aggregation in `aggregate-results.sh`; baseline = score+pass-rate; regression delta gate.
4. Then RAG metrics (faithfulness/answer-relevancy), then agentic (`tool-correctness` from `tools_called` in the response), then trajectory (requires trace capture — the big infra item, defer behind a capability gate like the existing browser/computer-use drivers).

---

## 7. Pitfalls (from gemini SOTA + promptfoo/deepeval docs)

- **Eval flakiness** — judge says pass Monday, fail Tuesday. Fix: `temperature=0` + specific bulleted rubrics + N-sample pass-rate.
- **Evaluating too broadly** — "score 1–10" fails; evaluate **specific vectors** ("contains PII?", "used search tool?", "polite?").
- **Cost/latency** — judge-on-every-CI-run drains budget; tier deterministic + embedding checks *first*, judges last. Distilled evaluator models are emerging (e.g. Galileo Luna).
- **Uncalibrated judge in a gate** — calibrate against a labeled pass/fail set before trusting it; refine the rubric when it misses a known-bad output.
- **Judge prompt injection** — candidate output is untrusted input to the judge; add an injection-guard rubric.
- **Trace capture is the real dependency** — agentic `trajectory:*` metrics need internal spans; without OTLP/`@observe` you can only score the final answer. Gate this behind a capability like browser/computer-use are today.
- **Don't reuse flaky-retry as eval-sampling** (see §4).

---

## 8. Lane status

- ✅ perplexity_ask — metric taxonomy, RAG/safety defs, non-determinism stats (after `perplexity_research` **timed out at 240s** on the heavy prompt; substituted the faster ask).
- ✅ exa web_search_exa — promptfoo trajectory assertions, deepeval CI, numoru regression-guard template, judge configs (all 2026-dated).
- ✅ deepwiki → confident-ai/deepeval — metric architecture, G-Eval/DAG, agentic + multi-turn metrics, pytest/CI.
- ✅ gemini-3-pro (Google-grounded) — SOTA landscape, tiered CI, judge biases, HTTP-QA→LLM-QA transition, pitfalls.

**Convergence note:** deepeval architecture independently confirmed by exa (docs) + deepwiki (internals); tiered CI confirmed by exa (numoru) + gemini. Not three echoes of one blog — independent sources.

## Sources (selected)
- deepeval docs + internals; promptfoo assertions/trajectory/llm-as-judge/CI guides (promptfoo.dev, 2026)
- numoru-ia/agent-evals-template (GitHub)
- appxlab.io "AI Agent Testing CI/CD Pipeline With LLM-as-Judge" (2026-04)
- confident-ai.com "LLM evaluation metrics" ; elastic.co "Evaluating RAG metrics" ; braintrust.dev LLM eval guide ; sitepoint "deterministic evaluation in a non-deterministic world"
- UK AISI Inspect ; OpenTelemetry GenAI semantic conventions
