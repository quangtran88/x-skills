---
title: Foundations for x-skills v3 — consult / record / implement
slug: x-skills-v3-foundations
type: research
status: current
created: 2026-07-27
updated: 2026-07-28
related: [x-skills-v3]
---

# Foundations for x-skills v3

Factual record behind the v3 redesign. **Spot-check this doc; do not read it end to end.**
Its job is to stop the same research being run twice.

Method: two rounds. **Round 1** (2026-07-27) — 9 lanes, 1.35M subagent tokens, 26 min: 5 external
literature/practice, 2 local teardown, 1 source recovery, 1 adversarial synthesis. **Round 2**
(2026-07-28) — 8 lanes, 1.09M tokens, 47 min: 3 falsification lanes (citation forensics,
mechanism attack, primary-source verification), 4 triangulation lanes, 1 adjudication.
Lane transcripts: `.claude/projects/*/subagents/workflows/wf_7479589e-b86/` and `wf_2d3a1516-906/`.

## 1. How to cite from this doc — and how round 1's audit failed

Round 1 shipped a fabrication audit. **Round 2 tested it: three false positives out of three
tested rows, while a genuine misattribution passed without comment.** The method was the fault —
every verdict reasoned about the *shape* of a citation instead of resolving the identifier.

| Round-1 verdict | Reality |
|---|---|
| `arXiv:2604.09408` HiL-Bench — "post-cutoff, unverifiable, twelve named authors and one-decimal figures" | **Real.** All twelve authors confirmed against raw arXiv metadata. Ask-F1 is defined in-paper as the harmonic mean of question precision and blocker recall. The "too many authors, too precise" tell was noise. |
| `arXiv:2603.26233` "Ask or Assume?" — "same ID, two author sets, identical figure. Classic confabulation signature. Unusable." | **Real.** Nicholas Edwards & Sebastian Schuster. The identical 69.40% is an *advertised finding* stated three times including the conclusion: both Claude Sonnet 4.5 and Kimi K2.6 score it (N=500, 347/500). The lanes invented the author names; the paper was never in doubt. |
| `arXiv:2502.13069` — "real paper, wrong title; 'Ambig-SWE' is a lane-coined nickname" | **Both titles real — version drift.** v1 (18 Feb 2025) "Interactive Agents to Overcome Ambiguity…"; v3 (21 Feb 2026) "Ambig-SWE: …Underspecificity…", ICLR 2026. Ambig-SWE is the authors' own benchmark name, present in the v1 abstract. Round 1 read v1 and corrected a correct citation into a suspect one. |

**Method rule that replaces the heuristics:** resolve every arXiv ID against the API before any
fabrication verdict. One HTTP request, confabulation-proof. A *summarizing* WebFetch is not a
substitute — on the same abs page it produced a plausible but **third** author set for 2603.26233.

**The asymmetry that makes this urgent:** a false negative admits a bad citation a later reader
can catch. A false positive silently deletes a good one and leaves no trace. Round 1's errors were
not random — they under-rated evidence that *contradicts* DEC-003 and evidence that *supports* M7.

### Still dead — the three correct kills

These used the strong tell ("no primary source exists") and they stand.

| Claim | Status |
|---|---|
| "3–10× first-pass success" for spec-driven development | **Nonexistent.** Every instance traces to `thebcms.com` / `devtoollab.com` citing unnamed "early adopter reports." The nearest real literature reports company-wide gains of 5–15%. Nothing establishes that spec-first docs improve agent output at all. |
| "~150–200 instruction budget", "<40 instructions per prompt" | **Absent from the author's own text** — exhaustive grep, zero matches across `wsff.md`, `ace-fca.md`, `wdttg.md`. Keep the decomposition discipline; cite no number. |
| "~80% of expected pain gone in the first few minutes" | Alt text of a self-described didactic sketch (`wdttg.md:37`); `wdttg.md:31` says it blurs two variables into one percentage. |

### Newly found — misattributions round 1 missed

- **"Pitts & Browne, representational stability, N=115" — a conflation of two papers.** The N=115
  study is Browne, Pitts & Wetherbe (2007), *MIS Quarterly* 31(1), consumer web search, three
  authors. Pitts & Browne (2004), *JMIS* 21(1):203–226, is the requirements-elicitation paper —
  two authors, no N=115. "Representational stability" traces to Nickles (1995). **Delete: wrong
  paper, wrong N, wrong domain** for any stopping-rule or question-budget claim.
- **"Unsummarized tool output measured worse than removing the tool entirely" — no source exists.**
  See M14; the nearest real measurement inverts the natural reading.
- **"~1200 lines"** — appears in no primary. Grep for `1200` / `1,200` / `1.2k` across all three
  source files returns nothing. The real figures are "2000+ lines of code or even 500 lines"
  (`wsff.md:553`) and "2k+ lines" (`:587`).

### Single-source fragility (not fabrication)

All five July-2026 preprints resolve and match their claimed subject matter; round 1's caution was
proportionate but read as a fabrication charge. Two are load-bearing alone: `2607.05139` was the
sole primary under DEC-006 (**now relieved** by ICSE 2026) and `2607.09510` is still the sole
primary under DEC-011 (**not relieved**). Quality signal: `2607.00711`'s abstract still contains an
unfilled placeholder ("including N unique ambiguity types") — a genuinely unfinished draft.

## 2. Primary source — the inspiration video, identified

**"Harness Engineering is not Enough: Why Software Factories Fail"** — Dex Horthy, HumanLayer.
AI Engineer World's Fair 2026 keynote, ~18 min. `youtube.com/watch?v=Ib5GBkD555M`

The author published an expanded **text version**, which is the citation of record:

- `wsff.md` — <https://raw.githubusercontent.com/humanlayer/advanced-context-engineering-for-coding-agents/main/wsff.md>
- `ace-fca.md`, `wdttg.md` — same repo.

Round 2 spot-checked every line anchor in this section against the on-disk primaries: **all nine
quotations are verbatim at the stated line.** Alongside the local teardown (§4), this is the most
reliable material in the doc. The verbatim spoken transcript was never obtained.

**Lineage — eight phases, not five:** Questions → Research → Design → Structure → Plan → Worktree →
Implement → PR. Round 1 omitted Worktree and PR. Note `wsff.md` never uses the word QRSPI and gives
a *different* 4-phase decomposition at `:411-416` / `:576-579` (Product Requirements / System
Architecture / Program Design / Vertical Slices); neither "design discussion" nor "structure
outline" appears in the written primaries. Our three-skill split is a **merge** of his pipeline,
not an independent re-derivation of it — his Questions phase is agent-authored codebase
scaffolding answered by *another agent*, and human decisions live in a separate Design Discussion
phase. x-consult merges the two. Defensible, but a merge.

### The four load-bearing arguments

1. **Why human comprehension is permanent.** Coding models are RL-trained on binary test-pass
   verifiers with *no penalty for eroding maintainability* (`wsff.md:347`). "Tests give you
   feedback in seconds, but the cost function of bad architecture is measured in weeks, months,
   maybe even years" (`:367`); "maintainability has no fast oracle, so we can't reward for it
   during RL" (`:393`). → **Defines question altitude**: only decisions whose cost a test run
   cannot see.
2. **Why attention goes upstream.** "A bad line of code is… a bad line of code. But a bad line of
   a **plan** could lead to hundreds… a bad line of **research**… could land you with thousands"
   (`ace-fca.md:322-324`).
3. **What review was always for.** Mental alignment, not defect-catching — citing Blake Smith,
   *Code Review Essentials for Software Teams* (2015). "I was starting to lose touch with what our
   product was and how it worked" (`ace-fca.md:339/343/357`). Bandwidth: "I can't read 2000 lines
   of golang daily. But I *can* read 200 lines of a well-written implementation plan."
4. **Ceremony must be triaged.** "~40% of tasks get oneshot" (`wsff.md:583`) — **a practitioner's
   estimate**, since `:581` immediately preceding reads "I would guess the distribution is
   roughly:". The substantive prior art is the ladder at `:584-585`: "for medium tasks, we do
   product/system design all in one plan document, and don't bother breaking the work into phases;
   for large things, we do all the steps. we'll skip the product part for things where it doesn't
   make sense like big refactors." Note `:433`'s scope — it opens "Of course, not everything gets
   a **product review**", one phase of four, not the whole ceremony chain.

### Named antipatterns

- **Magic words.** The principle is sourced (`YwZR6tc7qYg` ts:653-659, "ideally we will avoid uh
  magic words"). **The recited 25-word phrase is UNVERIFIABLE** — grep returns one unrelated hit
  (`wsff.md:67`, about PR review bots). Keep the antipattern; never quote the sentence.
- **Prompt contamination.** The ticket is hidden during research so the agent produces "a factual
  record of what the code does." He discarded his first research doc because "Claude decided the
  bug was invalid and the codebase was correct" (`ace-fca.md:266`).
- **The plan-reading illusion — including the half round 1 omitted.** `5MWl3eRXVQk` ts:88 "I also
  don't think you should read really long plan files"; **ts:479 "the new advice — don't read the
  plans. Please, read the code. Just cuz it's the same amount of work"; ts:589 "You should have
  high leverage planning. You should not outsource the thinking. Read and own the code."**
  `ace-fca.md:333` ("when you review the research and the plans, you get more leverage than you do
  when you review the code") **is the claim being retracted.** Round 1 cited the older position.
- **Horizontal plans.** Stack order (migrations → services → API → frontend) leaves nothing
  testable until late. Prescription: vertical slices / tracer bullets (`wsff.md:542-570`). "Most
  frontier models won't design a plan like this without human steering" (`:570`). The "100–200
  lines" at `:568` is scoped to **how much code the human reads per step** — "Checking 100-200
  lines and resteering is a lot cheaper" — not a machine diff ceiling; and `:587` says "I'll send
  off a model to do 1-3 slices at a time," so he batches slices rather than stopping at each.
- **Diagram theater.** `wsff.md:489`: "The first version of our program design skill sucked… We
  tried mermaid, which has its place, but what we **actually love** are light visualizations in
  pseudocode" — an abandoned implementation, stronger than the `:479` caution round 1 cited.

### Format primitives

Plain-text contract shapes (`PUT /api/resources/:slug` + request/response) at **`wsff.md:459-463`,
inside § System architecture** — *not* the `:489-533` Program design range round 1 cited. That
range holds call-stack trees in diff syntax, `# NEW`/`# MODIFIED` file-tree diffs, and type +
method signatures. **He separates system-level contracts from code-shape signatures into two
review passes at two altitudes; DEC-009 collapses both into one section and loses that
separation** — a knowing simplification, recorded as such. "None of these take long to produce
(the model drafts them, you argue with it), and every one of them is a decision you'd otherwise be
making implicitly during code review — at the most expensive possible time to change your mind"
(`:536`).

## 3. Mechanisms (M1–M18)

Round 2 attacked M1–M16 directly. Status column records what survived.

| # | Mechanism | Evidence & status |
|---|---|---|
| M1 | **Terminal status DERIVED from machine state**, printed as the first token of a closed enum, never model-composed. | **Survived.** MAST (`arXiv:2503.13657v3`): FM-1.5 "not recognizing task completion" 12.4%, FM-1.3 step repetitions 15.7%, FC3 Task Verification 23.5%. **Bounded:** the token is *machine-facing*. A fixed token in a fixed position at a fixed form is not read by a human after roughly the second exposure (Anderson et al., CHI 2015 fMRI — "dramatic drop in the visual processing centers… after only the second exposure"; Vance et al., *MIS Quarterly*, three-week field experiment; alarm-fatigue base rates 72–99% false, Cvach 2012). Its job is to gate control flow and be validator-checked. **This resolves round 1's slot-blindness unknown: yes, it habituates.** |
| M2 | **Sufficiency judgement must be a DEDICATED, separately-prompted step whose verdict routes into control flow.** | **Rewritten — round 1 was wrong as stated.** Asked as *introspection* ("do I have questions? am I confident?") it runs near chance: Ask4Conf-d 55.0/57.9 AUROC (Hou et al., ICML 2024, `arXiv:2311.08718v2` Table 2); Ambig-SWE Neutral-prompt FNR 0.44. Asked as *explicit classification* it does not: Ambig-SWE Strong-Encouragement gives Claude Sonnet 4 Acc 0.89 / FPR 0.03 / FNR 0.18, and Joren et al. (ICLR 2025, `arXiv:2411.06037`) reach ≥93% sufficiency classification against 115 expert gold labels **with no ground-truth answer**. Their diagnosis: **the deficit is ABSTENTION, not detection** — correct answers with insufficient context only 35–62% of the time. Near-chance belongs to weak open-weight models (Qwen 3 Coder Acc 0.50 / FNR 1.00 — literally never asks). "Agent silence is evidence of guessing" **holds** — that is the abstention finding. Human analogue: Kamsties et al. (EMMSAD'01) measured that readers silently and often incorrectly disambiguate rather than reporting. |
| M3 | **Scout before asking**; the scout/ask boundary is mechanical: **navigational** gaps resolve by exploration, **informational** gaps require the human. | **Warrant replaced.** The "~50% fewer questions" figure is a **cross-model** comparison (Sonnet 3.80–4.03 vs Qwen 4.57–6.02), not an explore-vs-no-explore ablation; the paper runs no such ablation. Counterweight to carry: Cuadron et al. (`arXiv:2502.08235`, 4,018 SWE-bench Verified trajectories) names **Analysis Paralysis** — extended deliberation with minimal environment interaction — as a measured pattern correlated with lower resolve. |
| M4 | **Enumerated options with the agent's recommendation attached.** | **Survived a serious attack, with a stronger warrant.** It is an *information-budget requirement*, not a usability preference: Linacre's Rasch arithmetic (SE 0.3 needs ~45 dichotomous items) plus a² discrimination scaling is why PROMIS reaches SE<0.30 at a median of 4 **polytomous** items — yes/no confirmations are unaffordable at n≤7. GATE (Li, Tamkin, Goodman & Andreas, ICLR 2024, pre-registered): generative yes/no questions improved over user-written prompts in *every* setting, rated equally or **less** mentally demanding than writing a prompt. **Counterweight:** closed options suppress the answer the author didn't think of — Schuman & Presser (*ASR* 44, 1979): ~60% of open responses fall outside five researcher-written options; "respondents do not spontaneously give answers not on the list, even if the list does not reflect their own priorities." And the human cannot feel the loss (Doshi & Hauser, *Science Advances* 10(28):eadn5290, b=0.871 p<0.001, self-assessments showing no difference). Schuman's own remedy: **combine the forms** — a standing "D: none of these." |
| M5 | Human attention is worth more upstream than at the diff or per-step. | Held. See §2.2 and the Boehm curve in M9. |
| M6 | **Pointer-or-delete**; three evidence grades OBSERVED / INFERRED / ASSUMED; **no MODEL-AUTHORED numeric confidence.** | **Narrowed, citation corrected.** Bansal et al. (CHI 2021, N=1626) **cannot** warrant the confidence ban — his winning condition *was* confidence display ("explanations did not appear to offer benefit compared to simply displaying the AI's confidence"). Keep Bansal only for "explanations increased the chance that humans will accept the AI's recommendation, **regardless of its correctness**." Re-warrant the ban on verbalized-confidence miscalibration plus van der Linden & Glas (2000) capitalization on chance — a self-computed precision figure is biased optimistic by 25–40%, with **premature termination** as the published consequence in variable-length instruments. |
| M7 | **The oracle must not have seen the implementation.** | **Survived a deliberate kill attempt and came back stronger.** `arXiv:2607.05139` verified verbatim (14% vs 25% fault detection, 5 models × 3 benchmarks, Mann-Whitney p<0.05; CoT and CoVe did **not** recover the loss). **New peer-reviewed corroborator:** ICSE 2026, "Measuring the Influence of Incorrect Code on Test Generation" — 47% worse bug detection on 41 repo-level real-world examples, +34% recovered by supplying NL descriptions instead of code. The human *ordering* literature is null by comparison (Fucci et al., IEEE TSE 43(7):597–614, 82 data points / 39 professionals — little difference test-first vs test-last, with cycle **granularity and uniformity** predicting quality; Rafique & Mišić, TSE 39(6), 27 studies — small quality effect, no productivity effect, a productivity *drop* in industrial subgroups). Which is exactly why M7's framing (independence, not ritual) is the right one. |
| M8 | **No component approves its own output** — and a review dispatch fires only when gated on a failing gate or a concrete artifact, **never unconditionally.** | **Premise survived, sufficiency dented.** Self-preference verified (Panickssery, Bowman & Feng, NeurIPS 2024, `arXiv:2404.13076`); Huang et al. `arXiv:2310.01798v2` (ICLR 2024) is the cleanest citation in the corpus. **But separate dispatch is not the active ingredient — critic STRENGTH is:** Olausson et al. (ICLR 2024) — at equal compute self-repair often loses to drawing more i.i.d. samples; a **stronger model's** feedback beat both the i.i.d. baseline and self-repair at all budgets; an experienced human programmer's feedback in place of GPT-4's own raised repaired-and-passing programs **1.58×** (33.3%→52.6%). A LiveCodeBench Self-Refine replication reports ungrounded critics hallucinating flaws in correct code, the actor introducing regressions, Pass@1 degrading while cost rises. `arXiv:2504.03846`: harmful self-preference concentrates where the judge is weak as a generator. |
| M9 | **Ceremony tiered, tier announced before any artifact is written — with the default set LOW.** | **Shape survived; default moved down.** Boehm & Turner's COCOMO II RESL calibration (~161 projects, 25 years): minimum-total-delay sweet spot **~5% of schedule at 10 KSLOC**, ~20% at 100 KSLOC, ~33–37% at 10,000 KSLOC — "more than 5 percent architecting investment unnecessarily increases schedule" — with **Rapid Change moving the sweet spot LEFTWARD**. Cuadron et al.: lowest-overthinking selection improved resolve ~30% at 43% less compute. Bučinca et al. (CSCW 2021, N=199): "Participants preferred and trusted more the systems that they perceived as less mentally demanding, but with which they performed poorly" — the routing-around risk is a *measured preference penalty*. **Non-monotone caveat:** fewer reasoning tokens also raised behavioural overthinking, so the curve has a real minimum — this is not "less is always better." |
| M10 | Gates written as runnable operations with observable predicates, not exhortations. | Held. |
| M11 | Verify per task / per edit; stop and escalate rather than continuing to repair. | Held. Sole primary remains `2607.09510`, unrelieved. |
| M12 | **Serial vertical slices; subagents for context isolation, never concurrent mutation.** | **Promoted from "unvalidated bet" to measured.** CooperBench (Zhu, Yang et al., Stanford, `arXiv:2601.13295`): 652 tasks / 12 libraries across 4 languages; 77.3% of tasks have conflicting ground-truth solutions; GPT-5 and Claude Sonnet 4.5 reach **25% with two-agent cooperation, ~50% below a Solo baseline**; monotonic degradation 2→3→4 agents at 68.6%→46.5%→30.0%; up to 20% of budget on communication, which reduces merge conflicts but does **not** improve success. AgenticFlict (`arXiv:2604.03551`): 142K+ agentic PRs across 59K+ repos, 107K+ merge-simulated, **27.67% conflict rate**, 4.36 files / 540+ lines per conflicting PR. **Corrections:** Anthropic's 90.2% is a *relative* improvement on an internal unpublished eval, and 15× is multi-agent-vs-**chat** token cost, not a coordination-failure measure. Do **not** cite any "human PR conflict rate 10–15%" figure — blog-only. |
| M13 | Immutable paths, stable IDs, append-only decision blocks; **four Nygard fields as a lightweight default.** | **Weakened.** The one head-to-head (`arXiv:2604.27333`, DESMET feature analysis over five templates) **splits**: MADR won the expert analysis 0.900 vs 0.868; Nygard won a controlled experiment (Wilcoxon W=84.0, p=0.002) with **n=33 undergraduates against MADR only** — arc42 and Tyree/Akerman never reached stage 2. Authors conclude choice is context-dependent. **Two deliberate departures:** Nygard prescribes full-sentence prose (inverted by DEC-008) and a standalone `doc/arch/adr-NNN.md` directory (rejected here). **Traceability caveat:** Mäder & Egyed's 24% faster / 50% more correct (71 subjects, 461 tasks) was measured on curated **human-maintained** links with subjects who "sketched their task solutions on paper" — no code was written — so it cannot predict what agent-generated links will do. Gren & Berntsson Svensson (*Requirements Engineering* 26:459–480, six experiments, N=461): content explicitly marked as excluded **still** biases readers, at roughly twice the percentage of obsolete items present. |
| M14 | **Condense tool output deterministically, never with an LLM pass.** Top-load decision-relevant content. | **Round 1's warrant was NONEXISTENT and is struck.** Replacement: Lindenbauer, Slinko, Felder, Bogomolov & Zharov, "The Complexity Trap" (`arXiv:2508.21433`, DL4Code @ NeurIPS 2025) — inside SWE-agent on SWE-bench Verified across five model configurations, deterministically **masking** old tool outputs matches or beats LLM summarization in 4/5 configs at lower cost (Qwen3-Coder 480B 54.8% vs 53.8%, $0.61 vs $0.64), both roughly halve cost vs the unmanaged agent, and **summarization lengthens trajectories ~15% because summaries obscure failure signals.** Keep "Lost in the Middle" (Liu et al., `arXiv:2307.03172v3`; *TACL* vol. 12, 2024) for top-loading. |
| M15 | Question altitude is behavioral/decisional — decisions whose cost arrives weeks later and which no test run can verify. | Held; see §2.1. |
| M16 | **Match guidance form to failure type.** Output *shape* → positive recipe. *Discipline* → prohibition + rationalization table. | **Survived untouched by seven lanes, and was independently re-derived.** Shen, Singhal & Breaux (IEEE RE 2025): the checklist flavour with a measured effect is a list of **question defects** — a prohibition set — preferred in 87/128 pairs, Bradley-Terry p=4.23e-8, win probability 93.5%. The flavour with no effect on requirements-level defects is a list of **topics**. That is M16's distinction, measured. |
| **M17** | **Arbitration: the human wins unconditionally on intent; a factual position change requires new evidence the agent verifies ITSELF.** | **New — shipped prior art in FOUR artifacts across two prompt generations, not a designed mechanism.** `create-design-discussion/SKILL.md`: "If the user gives any input along the way: DO NOT just accept the correction. Spawn new research tasks to verify the correct information. Read the specific files/directories they mention. Only proceed with updates once you've verified the facts yourself." Verbatim-equivalent in `create-structure-outline`, `iterate-implementation`, and the 2025-era `create_plan.md` Step 2.1. The intent-side half is an artifact precedence chain restated in every skill: `plan > structure outline > design discussion > research > ticket`. |
| **M18** | **An independent second READING of the human's own words roughly doubles ambiguity yield, and the two readers barely overlap. Combine by mechanical UNION — never by discussion.** | **New.** Spoletini, Ferrari, Bano, Zowghi & Gnesi (REFSQ 2018, 42 students across two universities): "during the review, the analyst and the other reviewer identify **68%** of the total number of ambiguities discovered, while **32%** were identified during the interviews. Furthermore, the ambiguities identified by analysts and other reviewers during the review significantly differ from each other." Precursor (IEEE RE 2017): **~26% overlap** — reviewers alone 46%, analyst alone 28%. The union rule is **the one finding that replicated in both an original experiment and its independent replication**: collection meetings do not improve detection rate, meeting gain outweighed by meeting loss (Basili et al. 1996 p.9; Fusaro/Lanubile/Visaggio 1997) — Basili's team simulated teams by post-hoc union for exactly this reason. **CAVEAT:** the human mechanism is perception difference between *people*; two dispatches of one base model are a monomethod block, and MTMM predicts agreement will run too high, so the port is unvalidated and must be instrumented via overlap rate. |

## 4. Local teardown — fully verified

Current state: 19 skills, ~17,450 markdown lines, **101 external call sites — verified
2026-07-27**: 64 superpowers (`writing-plans` ×17, `requesting-code-review` ×8, `brainstorming` ×8,
`verification-before-completion` ×7, `subagent-driven-development` ×7,
`finishing-a-development-branch` ×5, …) and 37 OMC (`code-reviewer` ×18, `qa-tester` ×6, …),
across 40 files.

**The structural problem is not the dependencies.** It is 19 skills that document each other's
internals — up to ~342 possible directed handoff edges, paid in prose:

- `x-backlog/SKILL.md:136-157` — ~40 lines on git states *inside x-worktree*.
- `x-shared/completion-cascade.md:103-116` — per-skill rollout table, six rows "Deferred."
- `x-shared/slot-schema.md` — 7 slots, 2 "Emitted in v1"; plus a "v2 reference — not shipped".
- `x-shared/invocation-guide.md:164-171` — a section documenting `send_message` as "DEFERRED,
  dropped from the canonical vocabulary."
- `x-shared/done-format.md:80-91` — a "Letter Namespace Map" existing only because 19 skills each
  invented menu letters.

**Self-refuting output contract:** `done-format.md:98` says progress banners are "Never include in
output." **13 step files across three skills open with one — verified 2026-07-27** via
`grep -rlE 'Step [0-9]+ of [0-9]+' skills/` (x-do ×4, x-review ×4, x-guide ×5). Prose contracts do
not self-enforce.

**Carry forward:** `x-backlog/references/template.md`; `done-format.md` shapes 1–3;
`completion-cascade.md` §3's discover-and-run loop; `invocation-guide.md:125-192` (`handoff` vs
`assign`, parallel dispatches in ONE message); `instrument-and-verify.md` rule 3 (this is M6
already written down); `capability-loading.md` + the SessionStart hook (the framework drop costs it
exactly two tokens); x-backlog's draft-first walk.

**Delete (~1,700 lines of unusable bootstrap tax):** `slot-schema.md` + slot resolution;
`reactions-vocabulary.md`; the 9-layer *instruction*-precedence ladder; `x-omo` / `x-gemini` as
bootstrap deps (1,084 lines read unconditionally to maybe make one Bash call); `x-team`; the
45-line GitNexus freshness contract.

## 5. Unresolved

**Retired this round** — parallelism ("unvalidated bet": now evidenced against, M12); slot
blindness ("unknown": measured, answer is yes, M1); human-vs-code arbitration ("unaddressed by
every source": addressed in four artifacts, promoted to M17).

- **Does the manifest buy accuracy, or robustness plus cost?** Partially measured, and the answer
  is not flattering: Edwards & Schuster's scaffold beats an *unscaffolded* single agent (69.40% vs
  61.20%) but **ties a well-prompted one** (Interactive Baseline **70.40%**, p=0.621) at more than
  double the inference cost and double the human queries. Its clear win is on the
  instruction-fragile backbone (Kimi K2.6 Interactive collapses to 47.20% while the scaffold holds
  at 69.40%). So the honest claim is robustness, not accuracy.
- **A TOPIC checklist does not find requirements-level defects.** Three independent studies
  (Porter/Votta/Basili 1995 — "checklist reading was no more effective than ad hoc";
  Fusaro 1997 replication; Cox/Aurum/Jeffery), though it nearly doubles artifact-*internal*
  defects (23→47 individual, 36→64 group). **DEC-003 gates the second class, not the first — and
  you cannot enumerate the slot you do not know exists.**
- **The 3–5 question budget is an artifact of benchmark design.** Every question count in the
  corpus is extraction against a *simulated* user holding the full original issue text, told to say
  "I don't have that information", capped at 3 turns. The author's 2–8 bound is for agent-to-agent
  research questions explicitly *not* deduplicated against known facts. Neither transfers to one
  senior engineer with limited patience.
- **A same-base-model review dispatch is a monomethod block; MTMM predicts it will UNDER-flag.**
  Instrument via overlap rate against the ~26% human baseline (M18).
- **Divergence at design/plan altitude is unmeasured.** A targeted non-existence sweep found no
  work sampling N full plans from an underspecified requirement and validating divergence as an
  ambiguity signal. Output-side divergence on short-answer QA is **AUROC 54.9 — near chance** —
  because models stay 67–82% self-consistent under genuine ambiguity while holding real mass on
  the alternatives. The variant with signal is input-side (perturb with K candidate clarifications,
  71.7–81.3 AUROC), which needs a discrete answer space and is unmeasured at design altitude.
- **Whether an agent can generate useful exception candidates on a just-scouted codebase is
  unmeasured.** Alexander's 3.17× came from experienced engineers with operational intuition.
  Falsifier: ratio of exception probes ruled in scope vs dismissed.
- **Two agent-side mechanisms hunting the same omission class may overlap more than their
  individual effect sizes suggest** — Alexander measured 9.59 combined vs 7.59 for scenarios alone.
- **Whether slot/coverage gates are gameable** remains untested, and the canonical falsification of
  this instrument class is now on record: Urbach et al., *NEJM* 2014;370(11):1029–38 — mandatory
  surgical checklists across 101 hospitals, 215,711 procedures, **self-reported compliance 92–98%,
  adjusted mortality OR 0.91 (P=0.13), no subgroup benefited.** The editorial: "The likely reason
  for the failure of the surgical checklist in Ontario is that it was not actually used." Turpin
  et al. (NeurIPS 2023, `arXiv:2305.04388`) compounds it: forcing a per-row justification produces
  plausible post-hoc rationalization, dropping accuracy up to 36% while the reasoning never
  mentions the bias.
- **No effect size exists** for "print the command and exit code before claiming completion."
- **No evidence any full research→backlog→plan→implement cycle has completed once** in this repo.
- Repeated-exposure effects on the whole output contract are single-session everywhere.

## 6. The prompts — corrected

Round 1's §6 was **wrong twice over and would have delivered an anti-pattern into S3.**

**The ACE-FCA repo contains four content files and NO prompts** — verified via
`gh api repos/humanlayer/advanced-context-engineering-for-coding-agents/git/trees/main?recursive=1`
(38 entries: `ace-fca.md`, `wsff.md`, `side-quests/where-does-the-time-go.md`, `images/`).

Files under those names exist in `humanlayer/humanlayer/.claude/commands/`, but are the
**pre-QRSPI generation** (last touched 2025-10-15 and 2025-11-12, eight months before `wsff.md`)
that the author says he got wrong. **DO NOT READ THAT SET:** `create_plan.md:378-392` prescribes
"For Database Changes: Start with schema/migration → Add store methods → Update business logic →
Expose via API → Update clients" and "For New Features: Start with data model → Build backend logic
→ Add API endpoints → Implement UI last" **as recommended patterns** — verbatim the horizontal
stack-ordering DEC-010 exists to reject — and `research_codebase.md` instructs the researcher to
read ticket files FULLY, contradicting DEC-004.

**The current generation is HumanLayer's `rpi` plugin v0.18.1 — 16 skills**: create/iterate twins
for research-questions, research, design-discussion, structure-outline, plan, implementation, plus
setup-worktree, review-artifact-comments, describe-pr, ci-commit. **Its only inter-skill interface
is three conventions:** a per-task directory with a monotonic `NN` prefix discovered by `ls`; a
`### Status` block of derived counts; and a `### Next Steps` section printing a literal
copy-pasteable prompt naming the next skill. No skill documents another's internals. **This is why
16 skills cost him almost no coupling** — and why DEC-001's *Why* is right while its remedy treats
the symptom.

**LICENSE CAVEAT:** the only readable copy is a third-party mirror (`jturner421/rpi-skills`) whose
`plugin.json` self-attests HumanLayer authorship and "All Rights Reserved"; `humanlayer/riptide-rpi`
is public but ships only a 2.6KB bootstrap installer. **Cite behaviour; do not vendor text.**

**STILL UNREADABLE:** the `implementer-agent` prompt. `implement-plan/SKILL.md` delegates to
`subagent_type=implementer-agent` and no such definition is published anywhere — so the closest
prior art to x-implement's slice executor remains unavailable. §6's original premise that the
author publishes his workflow prompts is true only for the *planning* half.
