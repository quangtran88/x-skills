# Research: Doing automated eval *with AI agents* effectively (Max Mode)

> **Date:** 2026-06-06
> **Source:** `/x-skills:x-research max` (5-lane fan-out, reconciled synthesis)
> **Companion to:** `2026-06-06-llm-agentic-eval-for-x-qa.md` (that doc = the eval *landscape*; this doc = how to make the *AI evaluator itself* reliable)
> **Goal:** How to use AI agents/LLMs to perform evaluation effectively and trustworthily — the central crux flagged in the prior round ("native scorers / LLM-as-judge").

## Lane status (reconciliation)
- ✅ **perplexity_research** — exhaustive 8-section briefing, 44 citations (output was 94k chars; extracted from saved file).
- ✅ **perplexity_reason** — A/B/C decision framework + concrete CI-gating recipe with human-agreement thresholds.
- ✅ **exa web_search_exa** — primary sources: Agent-as-a-Judge (ICML 2025) + repo, jury/calibration libraries, BT-σ jury paper.
- ✅ **deepwiki → UKGovernmentBEIS/inspect_ai** — a real framework embodying the patterns (model-graded scorer, multi-scorer vote, epoch reducers, transcript access).
- ❌ **gemini-agent (Google-grounded)** — failed: Google quota exhausted ("exhausted your capacity on this model", killed at 4 min). Recency covered by the other lanes; not retried.

**Convergence (independent, not echoes):** the cascade/tiering pattern, `temperature=0`, jury-beats-single-judge, and the 85–90% human-agreement bar each appear in ≥3 lanes from *different* source types (research synthesis + reasoning + primary repos + a shipping framework). inspect_ai (Lane 4) independently implements what the others describe in prose — the strongest form of agreement.

---

## TL;DR — the decision spine

There are **three evaluator archetypes** on a cost↔power spectrum. Pick by *what you must inspect* and *what's at stake*, then **validate the evaluator against humans before trusting it.**

| | **A. Single LLM-as-judge** | **B. LLM-as-a-jury** | **C. Agent-as-a-Judge** |
|---|---|---|---|
| What | one capable model scores via rubric | panel of diverse (smaller) models vote | tool-using agent inspects the *trajectory* |
| Cost | 1× | ~1.5–4× small (often **< one big judge**) | several× (tool + multi-step calls) |
| Human agreement | ~85–93% | up to ~96%; +8–15% reliability | ~human baseline on agentic tasks |
| Best for | objective, final-output, regression | subjective / high-stakes / bias-prone | process matters: tool calls, steps, code |
| Key risk | systematic bias, flakiness | correlated errors if jurors too similar | evaluator loops/misuses tools; cost |

**Decision rule (from perplexity_reason):**
1. **Process/traces matter** (tool calls, multi-step, code) → **C** (Agent-as-a-Judge), or hybrid C-for-process + A/B-for-final-answer.
2. Else **high-stakes OR subjective/multifactor** → **B** (jury); route disagreements to humans.
3. Else (final-output + objective + low/med risk) → **A** with a tight rubric.
4. Always compose as a **cascade**: cheap deterministic checks → small judge → escalate only ambiguous/high-risk cases to jury/agent/human. (Cascade + sampling + caching cuts eval bills **80–95%** — FutureAGI 2026.)

---

## 1. LLM-as-a-judge, done right (archetype A)

**Prompt/rubric design:**
- **Narrow, single-objective judges.** Never "rate 1–10" mixing correctness+style+safety. One judge per dimension (fact-checker, safety, helpfulness).
- **Low-cardinality labels** (binary or 1–5 with *defined anchors per score*) beat 0–100. For smooth scores, **G-Eval** enumerates labels and computes a token-probability-weighted score.
- **CoT-before-score.** G-Eval's two-stage pattern: criteria → generated eval steps → methodical scoring. Reduces rubric-skipping.
- **Few-shot anchoring** with annotated good/bad examples (shapes label space *and* format).
- **Structured JSON output** (schema-validated via Pydantic/JSON-Schema) — lets you mix deterministic checks (parse/schema) with semantic scores.
- **`temperature ≈ 0`** — temperature rescales logits without changing ranking; higher T only adds noise. Decouple: high-T for generating rationales/tests, T=0 for the final label.
- **Pairwise > absolute** for reliability (easier to prefer than to calibrate) — but introduces position bias (mitigate below).

**Biases → mitigations (all empirically documented):**
| Bias | Mitigation |
|---|---|
| Position (favors 1st/2nd) | pairwise + **swap order**, report position-consistency/fairness |
| Verbosity (favors longer) | rubric explicitly penalizes length; add "conciseness" dimension; ground in reference |
| Self-preference (favors own outputs; measured via PIR) | **judge model ≠ candidate model/vendor**; dimension-wise decomposition cuts SPB ~31.5% |
| Leniency / variance compression ("too nice") | anchor in human gold; batch calibration; widen scoring range |
| Contextual / batch-induced | Batch Calibration (subtract average logit bias) |
| Adversarial / injection in candidate | treat candidate output as untrusted; injection-guard rubric; input sanitization |

Also: decompose holistic judgments into a **DAG of binary yes/no checks**; **fine-tune the judge** on domain labels for granularity (Wolfe).

---

## 2. Agent-as-a-Judge (archetype C)

**What:** the evaluator is itself an agent with tools + memory that inspects the *whole task-solving process*, not just the final text — at three levels: **black-box** (final answer), **glass-box** (trajectory: tool sequence, efficiency, constraint adherence), **white-box** (each step in isolation: is this query relevant? are these API args correct?).

**Evidence:** *Agent-as-a-Judge* (Zhuge et al., **ICML 2025**; `metauto-ai/agent-as-a-judge`), benchmarked on **DevAI** (55 realistic dev tasks, 365 hierarchical requirements). It **dramatically outperforms static LLM-as-judge and reaches human-evaluation reliability**, while saving **97.72% of time and 97.64% of cost vs human experts**. Crucially it grounds judgments in *tool outputs* (runs the unit tests, reads logs) and produces **step-wise reward signals** for agent self-improvement/RLAIF.

**When:** multi-step agents; code/data/infra agents (run tests > read code); safety/compliance (what *tools* were called, how data flowed); training loops needing dense feedback. For plain factoid-QA/summarization, A is enough and cheaper.

**Costs/failure modes:** multiple tool+LLM calls per eval; evaluator can mis-parse logs, loop, or inherit LLM bias; sees PII in traces (data-governance). Mitigate with importance sampling (only discrepant/high-impact/risky traces), caching, and meta-evaluation of the evaluator itself.

---

## 3. Juries / ensembles (archetype B)

**Why:** a panel of *diverse* models (different families/vendors/personas) averages out idiosyncratic bias. **PoLL** (Panel of LLM evaluators): panels of *smaller* models are often **cheaper AND better-aligned** than a single GPT-4 judge. Multi-agent debate (**ChatEval**) beats single-agent — and **diverse role prompts matter** (identical personas degrade results). Reported **+8–15% reliability** over single judges.

**Aggregation:** majority vote (simple, variance-reducing) → **performance-weighted vote** (weight jurors by gold-set accuracy, optionally per-dimension) → median (outlier-robust) → Bayesian. Rule-based override: *any* juror flagging a safety violation = fail.

**The trap:** if jurors share training data/family, errors **correlate** → biased consensus that *looks* reliable ("meta-evaluation collapse"). Diversify families/vendors/prompts and anchor in human gold.

**Shipping libraries (Lane 3, all 2025–2026):** `openjury` (weighted/ranked/consensus voting), `mokhld/llm-jury` (confidence-based escalation: fast classifier → persona debate → judge), `watchtree-19/llm-judge-calibration` (inter-judge Cohen's κ / Krippendorff's α / ICC, per-judge bias+variance), `judge-lab` (Bradley-Terry pairwise + **conformal abstention bands** + position-consistency), BT-σ paper (unsupervised reliability-weighted aggregation from pairwise comparisons, no human labels).

---

## 4. Validating the evaluator — meta-evaluation (non-negotiable)

> **Reliability ≠ validity.** A judge can be perfectly consistent and consistently *wrong*. Measure both before gating anything.

- **Build a human-labeled gold set:** 200–500 representative items (typical + edge + rare failures), 2–3 annotators using the *same rubric* the judge gets, resolved to consensus. For agents, gold includes **trajectory-level** truth (expected tool sequences/args), not just final answers. Best source: real production failures.
- **Measure agreement:** **Cohen's/Fleiss' κ** (categorical, corrects for chance — critical with imbalanced classes), **Pearson/Spearman** (continuous). Raw % agreement is misleading.
- **CI-gating thresholds (perplexity_reason):**
  - **< 85%** human agreement → evaluator is **advisory only** (soft gate); refine rubric or upgrade A→B→C.
  - **85–90%** → OK to gate low/medium-risk CI; keep regular human audits.
  - **≥ 90–92%** + manual audit of all judge↔human disagreements → OK for higher-stakes gates.
  - **Error asymmetry:** to *block* CI, require **high precision on FAIL (~95%)** — almost every blocked change is truly bad — even at lower recall.
- **JudgeBench reality check:** even GPT-4-class judges score near-random on hard response pairs. Don't assume "big model = good judge"; benchmark on *your* gold set.
- **Drift detection:** monitor judge score distribution over time; periodically re-label samples and track κ; correlate judge scores with downstream outcomes (bug reports, user satisfaction).
- **Goodhart / reward-hacking guard:** when optimizing *against* a judge (RLAIF, or just iterating to pass CI), keep a **hidden holdout meta-eval set**, use diverse/decomposed judges, and **randomly human-audit N% of pass+fail** weekly. Watch for length inflation, formulaic rubric-keyword stuffing — classic gaming signals.

---

## 5. Autonomous test/dataset generation with agents

Agents can synthesize normal cases, golden data, edge cases, and adversarial/red-team inputs — making the eval set self-expanding.
- **Pipeline:** generate → critic/judge filters → (human review on a sample). Optimize for **QDC** (Quality, Diversity, Complexity) — high-quality-but-low-diversity overfits.
- **Ground generation in external sources** (e.g. retrieve from the corpus, then write Q&A from *those* docs) so synthetic answers can't drift from real content; the judge checks faithfulness against the same source.
- **Red-teaming:** frameworks like **DeepTeam** automate attack generation → enhancement → execution → scoring across many harm categories (injection, jailbreak, bias, etc.). Agent-as-red-teamer pairs naturally with agent-as-judge.
- **⚠ Circularity (the central risk):** if the *same model family* generates the data AND grades the output, it grades itself — amplifying its blind spots; worse under RLAIF. **Mitigate:** different vendor/model for generation vs judging; human-anchored gold; ground both ends in external data; structural leakage prevention (eval data never in judge training).

---

## 6. Practical effectiveness levers

- **Determinism:** `temperature=0` + structured-output rails (schema-validated) → cacheable, stable CI signal.
- **Model choice:** frontier judges agree ~85% with humans (vs ~81% human-human) but are costly; **distill** a frontier judge into a small fine-tuned student for the bulk, escalate hard cases to frontier/jury.
- **Cost cascade (80–95% savings):** deterministic checks (schema/regex/structural/citation-validity) → small fast judge → frontier judge or jury → agent-as-judge/human. Add **importance sampling** (evaluate uncertain/high-impact/anomalous traces) + **caching** (T=0 outputs keyed by prompt+model+config).
- **Instrumentation first:** trajectory/tool-call tracing (Langfuse/Phoenix; OTel GenAI conventions) is a *prerequisite* for glass-box/agentic eval.
- **Treat the evaluator as a versioned product:** prompts, rubrics, gold sets, juror weights are artifacts under review, calibration, and gradual rollout.

---

## 7. What this means for x-qa (ties back to the goal)

This resolves *how* to build the prior round's central crux. x-qa already has the scaffolding; the eval extension maps cleanly:

| x-qa today | Maps to | Note |
|---|---|---|
| parallel runner dispatch (`X_QA_*_RUNNER`, `--max-bg`) | **jury (B)** = multi-scorer majority/weighted vote | inspect_ai's `multi_scorer(... mode)` is exactly this pattern |
| `--samples N` + pass-rate verdict (proposed last round) | **N-sample reducers** | inspect_ai ships `mean`/`mode`/`median`/`pass_at_k`/`at_least_k` — adopt these names/semantics |
| simple/complex runner tiering | **cost cascade** | extend: deterministic assert → cheap judge → frontier judge/jury → agent-as-judge |
| exploratory bug-hunt team (Phase 13.5) | **agent-as-judge / red-team generator** | already a multi-agent live-service structure — natural host for trajectory inspection + DeepTeam-style red-teaming |
| code-first domain research (scout) | **anti-circularity grounding** | grounding both case-gen and judging in code/domain-model already reduces self-grading drift |

**Mandates for x-qa's eval extension (highest-leverage):**
1. **Judge-runner contract:** `temperature=0`, rubric/G-Eval, CoT-before-score, JSON output, injection-guard, and **judge model ≠ system-under-test model** (x-qa runners are gemini/claude — using the same one to both produce and grade invites self-preference bias).
2. **Meta-evaluation gate before trust:** x-qa MUST ship a small human-labeled gold set and measure judge↔human **κ** before an LLM-judge sets `QA_VERDICT`. Below ~85% → judge is advisory (feeds `warn`, not `fail`). Without this, `QA_VERDICT` is "a precise measurement of nothing."
3. **Circularity firewall:** x-qa auto-generates cases *and* would auto-grade them. Use a different model (or vendor) for case-minting vs judging; keep grounding in the code/domain-model.
4. **Start A, earn B/C:** ship single rubric-judge + deterministic cascade first; add a jury for high-stakes obligations once a gold set exists; reserve agent-as-judge for trajectory/agentic obligations (gated like the browser/computer-use drivers).

**Top pitfalls:** gating CI on an unvalidated judge; circularity (gen model = judge model); reward-hacking the judge (Goodhart → holdout + human audits); jury correlated errors (diversify families); agent-as-judge cost/loops (sample + cache); confusing reliability with validity.

## Key sources
- Agent-as-a-Judge — Zhuge et al., ICML 2025 (`arxiv.org/abs/2410.10934`, `metauto-ai/agent-as-a-judge`, DevAI)
- inspect_ai (UK AISI) — Task/Solver/Scorer, `model_graded_qa`, `multi_scorer`, epoch reducers
- PoLL / LLM-as-a-jury — arize.com/llm-as-a-jury; ChatEval; BT-σ (`arxiv.org/pdf/2602.16610`)
- Jury/calibration libs — `openjury`, `mokhld/llm-jury`, `watchtree-19/llm-judge-calibration`, `judge-lab`
- Meta-eval — JudgeBench; "meta-evaluation collapse" (openreview IF0L7HSs3K); Cohen's κ; golden datasets (sigma.ai)
- Cost — FutureAGI 2026 eval cost-optimization (cascade/sampling/caching, 80–95%)
- G-Eval, red-teaming/DeepTeam, synthetic-data QDC — confident-ai.com guides
