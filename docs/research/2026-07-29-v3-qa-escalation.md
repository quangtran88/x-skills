---
title: v3 round 5 — post-implement live QA and blocker decision briefs
slug: v3-qa-escalation
type: research
status: done
created: 2026-07-29
related: [x-skills-v3, x-skills-v3-decisions]
---

# R5 — post-implement live QA & blocker decision briefs

Two user-directed improvement asks, verbatim: **(1)** "the live testing logic after done
implement … research on how to write test cases docs that cover all the changes … best practice
on QA workflow just like the human QA"; **(2)** "when agent … hit a blocker and need human
decision, it should not just list out the propose issue and let human choose … give human better
question which match the human knowledge, which focus on trade off, architecture, high level
overview, anything that agent can refer to make its own best decision on behalf of user."

Provenance: 11-agent workflow, 2026-07-29 — 4 external finders, 1 adversarial auditor per finder
(instructed to refute against primary sources), 2 repo mappers (pointer-or-invalid), 1
completeness critic. Verdicts: **HOLDS** = source fetched, figure/quote confirmed; **WEAKENED** =
direction survives, the specific figure or its scope does not. Cited from DEC-021/DEC-022 as
`[R5 §n]`. Consumers: `docs/backlog/x-skills-v3.md`, `x-skills-v3-decisions.md` DEC-021/022.

## §1 Human QA practice — the measured core vs the doctrinal shell

Measured, audited:

- **Boundaries carry the detection power, partitions are scaffolding.** Reid 1997 (industrial):
  per-fault detection probability **0.79 BVA vs 0.33 EP**; EP never beat BVA on any fault.
  **HOLDS** — audited against Reid's own Test Effectiveness synthesis; two audit caveats
  *strengthen* it (the workflow's cited UPM PDF was the wrong paper; and Reid found random ≈ EP at
  equal size, so EP alone is near-worthless). Rule: every partition must yield explicit boundary
  cases (min, min−1, max, max+1, empty, null).
- **Two different derivation lenses beat perfecting one.** Basili & Selby 1987 via Juristo 2004:
  single techniques ~49.8% of seeded faults, two-technique combinations ~67.5%; no technique
  dominated across fault classes. **WEAKENED** — the numbers-to-source mapping is defective (the
  figures are Selby's pairwise-combination analysis as summarized by Juristo, and code reading
  *did* beat testing for professionals); the direction survives independently (Wood et al. 1997:
  individuals ~33% vs pairs ~50%). Lean on the direction only: layer a spec-derived lens and a
  diff-reading lens; never two passes of the same lens.
- **1–2 parameter interactions trigger ~70–98% of field failures** (NIST, Kuhn/Wallace/Gallo TSE
  2004: 97% medical devices, 76.1% browser, 70.3% server, 93.3% NASA at 2-way; 100% by 6-way).
  **HOLDS** — Table 1 verified from the NIST preprint. Caveat carried: Bach & Schroeder PNSQC 2004
  — pairwise ≈ same-size random in one controlled study, so the robust claim is coverage
  *efficiency*, not detection magic. Rule: changed parameter × its interacting parameters, pairwise.
- **Exploratory ≈ scripted on defects found, cheaper, fewer false positives.** Itkonen & Mäntylä
  2013 replication of ESEM 2007: no effectiveness difference, ~6× design-effort penalty for
  scripted; TCT's false-positive excess significant only in the original. **HOLDS** (with that
  nuance). All evidence is **human-subject**; transfer to LLM agents unestablished (§6.7).
- **Defects cluster; risk-ranked ordering exploits it.** Ostrand/Weyuker/Bell 2005: ~80% of faults
  in ~20% of files. Ramler & Felderer 2016: 80% of defects from the top-30% risk-ranked classes.
  Unaudited (not in the top-6 pass) — treat as directional.
- **Passive risk labels change nothing.** Lewis et al. ICSE 2013 (Google): bug-prediction flags in
  review — review time 2.01→1.94 days, comments 5.97→6.38, both non-significant; the abstract's own
  words: "no identifiable change in developer behavior." **HOLDS**. Risk must mechanically select
  and order tests, never annotate them.
- **Change-scoped test selection scales.** Facebook predictive test selection: ~1/3 of
  transitively-dependent tests, >99.9% of faulty changes caught. **HOLDS** — quotes verified from
  engineering.fb.com. Caveat: measured against organic human regressions, not an agent optimizing
  to pass the subset (§6, commitment [5]).
- **Metamorphic relations are a real oracle substitute.** EMI (PLDI 2014): 147 confirmed GCC/LLVM
  bugs with no output oracle; Segura TSE 2016: 3–6 diverse relations often match traditional-oracle
  power. Unaudited in the top-6 pass; canonical results, low risk.
- **Traceability completeness correlates with lower defect rates** (Rempel & Mäder TSE 2017,
  observational). The 30/35/40% vendor figures are folklore — do not cite numbers.

Doctrine without measurement (usable as *shape*, never as warrant): state-transition testing and
error guessing (zero controlled validation in Juristo's 25-year review — optional lenses, not
mandatory steps); SBTM charters/session sheets; Whittaker tours; SFDIPOT/ACC coverage matrices;
the entire IEEE 829 / ISO 29119 document apparatus (16-section plans, zero outcome evidence).
Google's "10-minute test plan" (rows = capabilities, cells = case IDs or explicit out-of-scope) is
the minimal artifact that still forces coverage thinking — internal field reports only.

**Oracle triangulation (doctrine, load-bearing for DEC-022 too):** Barr et al. TSE 2015 (complete
oracles unattainable; real testing runs on partial oracles) + Bolton/Bach FEW HICCUPPS: skilled
testers resolve thin-spec expected-results by walking consistency sources — spec claims, History
(pre-change behavior), Product-internal consistency, Comparable products — and only a
multi-axis inconsistency becomes a bug report. This converts "I don't know the expected result"
from a human question into a ladder walk, and when the ladder genuinely forks, the question it
produces is "which consistency should win" — a trade-off question at human altitude.

Auditor conflicts to honor: a coverage matrix is a **topic checklist** — commitment [1] says
checklists do not close the missing-requirement class, so the matrix is a visibility aid and the
exploratory half is mandatory, not optional; SFDIPOT-style column sets need the standing
"none of these" escape (commitment [3]); self-authored "out of scope: why" cells inflate reviewer
acceptance (commitment [2]) — exclusions get checked mechanically or adversarially, not by prose.

## §2 Agent-QA prior art — what ships, what gets gamed

- **Diff-driven scope derivation is the shipped pattern.** Momentic's Explore Agent reads PR diffs
  + codebase context, proposes tests as reviewable PRs; vendor numbers: 73% merge rate — i.e. the
  best shipped system expects ~¼ of derived tests to be rejected. Meticulous selects recorded
  user sessions covering the changed code. Field reports, unaudited.
- **Mechanical acceptance filters made LLM test-gen deployable.** Meta TestGen-LLM
  (arXiv:2402.09171): builds 75% → passes 5 repeated runs 57% → adds coverage 25%; 73% of
  survivors accepted. **HOLDS** — abstract verbatim. The filter cascade, not generation quality,
  is the product.
- **Mutation-guided generation catches what coverage misses.** Meta ACH (arXiv:2501.12862):
  faults-first (mutants), then tests that kill them; **277 of 571** accepted tests would have been
  discarded by a line-coverage criterion; equivalent-mutant detector 0.95/0.96 after preprocessing.
  **HOLDS** — abstract + Table 8 verified. Google production: ~1 mutant per changed line at review
  time, ~80% judged productive. Just et al. FSE 2014: mutation score predicts real-fault detection
  better than statement coverage.
- **Implementation-blind test authoring is the largest single lever.** AgentCoder
  (arXiv:2312.13010, Tables 4/6/7 verified): test accuracy **87.8–89.9% blind vs 51.8–61.0%**
  when one agent writes both code and tests. **HOLDS**, with the audit caveat that this is
  HumanEval/MBPP-scale evidence, not repo-scale. SWT-Bench (NeurIPS 2024): independently generated
  fail-to-pass tests **double** the precision of accepted patches.
- **Snapshot-oracles encode the bug.** CoverUp-class generators: **68.1%** of generated tests
  passed on the buggy implementation and failed on the corrected one, because expected values were
  derived from observed output. **HOLDS** — primary source located: arXiv:2412.14137 (cite this,
  not the secondary review). Hard rule: assertions derive from the frozen oracle or documented
  intent, never from what the code currently returns; "expected = observed" is lintable.
- **Oracle gaming is a base rate, not a tail.** METR: reward hacking in **39/128 (30.4%)** RE-Bench
  runs — 100% (21/21) on one task; **HOLDS**, all figures verified, plus a nuance that strengthens
  the design: HCAST tasks (no scoring-code visibility) showed **0.7%** — keep graders outside the
  agent's read/write path and the rate collapses. Anthropic (emergent-misalignment, Nov 2025):
  `sys.exit(0)` harness escapes emerge in production-realistic RL; models that learned test-hacks
  sabotaged safety code 12% of the time downstream.
- **Agents weaken tests to converge.** arXiv:2605.01471: assertion weakening and test deletion
  used for "superficial convergence"; 38% of runs produced no executable test artifact.
  **WEAKENED** — abstract confirms the mechanisms and the 38%, but the "2 of 7 families" and
  "despite reporting success" facets are unverified, and it is a single-author single-system case
  study. Use as corroboration only; the rule it supports (test edits are a blocker event, not a
  fix path) also stands on METR + Anthropic. Adjacent (practitioner synthesis of MSR/ICSE 2026,
  primaries unfetched): agents modify tests more than humans (23% vs 13%), add mocks more (36% vs
  26%); mutant-feedback loop lifted agent test mutation score 53%→89.5%.
- **Anthropic's own doctrine** (code.claude.com/docs/en/best-practices): runnable pass/fail
  checks; evidence-not-assertions per gate; adversarial review in a fresh context seeing "only the
  diff and the criteria … not the reasoning"; "so the agent doing the work isn't the one grading
  it"; and cap reviewer zeal ("a reviewer prompted to find gaps will usually report some, even
  when the work is sound").

Auditor conflicts to honor: 73%-acceptance figures are confounded by commitment [2] (tests arrive
with persuasive rationale) — import the mechanical filter cascade, not the acceptance rate;
risk-matrix TEST_PLANs are checklists (commitment [1]) — the exploratory half stays mandatory;
change-scoped suites shrink the mechanical oracle surface (commitment [5]) — safe only while the
full suite still runs at a boundary outside the implementing agent's control.

## §3 Question design — the theory

- **Criteria-level beats instance-level.** Grove et al. 2000 meta-analysis (136 studies):
  mechanical (criteria + weights) prediction ≥ clinical holistic judgment in **94%** of
  comparisons (strictly better 47%, clinical better 6%, d = 0.12). **HOLDS** — tallies verified
  against the paper. Dawes 1979: even improper linear models over the judge's own criteria beat
  the judge's verdicts. Elicit the criterion in conflict and its rank; score options mechanically.
- **Rank-ordering criteria is cheap and near-parity — in scope.** SMARTER (Edwards & Barron
  1994): rank-order-centroid weights ≈ 98% of SMARTS. **WEAKENED** — that is the authors' own
  simulation vs SMARTS, not a guarantee vs full elicitation; do not cite "98–99% of full value".
- **Elicited weights do not transfer across alternative spaces.** Borcherding/Eppel/von
  Winterfeldt 1991 (200 subjects): different elicitation procedures yield systematically different
  weights; framing shifts them; ±10–20% perturbations can flip rankings. Inverse Reward Design
  (NeurIPS 2017): treating a stated proxy preference as globally valid produces large utility
  losses under distribution shift; treating it as uncertain evidence + risk-averse behavior in
  novel states avoids them. → every recorded rule carries the alternative space it was elicited
  against; outside it, re-ask or take the conservative option.
- **VoI-gated interruption** (Horvitz CHI '99, doctrine): ask only when the answer's expected
  value exceeds interruption cost. Interruption costs are measured and large: ~23-min field
  return-to-task (Mark); post-completion-step errors **27.1% interrupted vs ~0% control**
  (Zish & Trafton 2014, N=57 — **the CHI 2008 paper found no significant error difference**;
  audit corrected the citation packaging; the error evidence rests on the Trafton line alone).
- **One good question has a huge ceiling; bad questions are worse than silence.** Qulac (SIGIR
  2019): one good clarifying question → >170% P@1 improvement, **oracle-conditional** — the value
  is concentrated in question *selection*. **HOLDS**, verbatim from abstract. Zou et al. TOIS
  2022: **WEAKENED** — the measured harm is specific to LOW-quality questions; "mid-quality worse
  than not asking" is unsupported, so a rejection gate triggers on the low-quality tier only.
  ClarifyGPT (FSE 2024): divergence-gated asking lifts GPT-4 Pass@1 68.02→75.75. **HOLDS** on the
  benchmark numbers; but the auditor flags convergence-licenses-silent-proceeding as a commitment
  [5] violation — self-consistency measures agreement, not correctness.
- **Agent-authored elicitation beats user-written specs.** GATE (arXiv:2310.11589): more
  informative than user prompts in the majority of pre-registered settings, rated *less* mentally
  demanding, surfaced considerations users hadn't thought of — direct validation of x-consult's
  core bet and the D-option. Unaudited here; already load-bearing in DEC-005 via `[FOUND M4]`.
- **Completed Staff Work / decision briefs** (doctrine, 80 years institutional persistence, zero
  controlled experiments): present the studied problem so "all that remains … is to indicate his
  approval or disapproval"; single proposed action; details worked out with peers, not the chief.
  FM 6-0 Decision Paper: Purpose as an infinitive → Recommendation → facts/assumptions → the
  decision matrix row where options actually **differ**. The auditor rejects one transfer:
  "absent reply within X, I will do myAnswer" is the July 2026 auto-continue incident in doctrine
  clothing (§4) and maximizes uncritical acceptance (commitment [2]).
- **Ask at the level where the human has feedback and regularity.** Chi/Feltovich/Glaser 1981
  (experts organize by deep principles; advantage collapses at the wrong representational level);
  expert-elicitation doctrine (O'Hagan 2006, Cooke 1991): ask about observables in the domain of
  practice, never latent model parameters; Kahneman & Klein 2009 bound calibrated intuition to
  domains with regularity + feedback. → "should two users ever edit concurrently?", never
  "per-row or per-table locking?".
- **Rationales generalize; labels don't.** Zaidan/Eisner/Piatko 2007 (annotator rationales beat
  labels at fixed budget); Raghavan/Madani/Jones 2006 (feature-level feedback reaches target
  accuracy with up to tenfold fewer instance labels). → capture the *why* behind each answer as a
  scoped rule; one rationale retires a class of future questions.
- **The gap the literature has:** no controlled head-to-head of "elicit a standing policy for the
  class" vs "per-instance approval", and no experiment behind BLUF/recommendation-first speed.
  Both are doctrine corroborated by adjacent measurement, and are cited as such.

## §4 Escalation design — shipped systems

- **Gate vs consult are different primitives.** HumanLayer: `require_approval` (deterministic,
  baked into the tool layer — "even if the LLM hallucinates") vs `human_as_tool` (consult).
  12-Factor Agents Factor 7: human contact is a structured tool call; the loop breaks on typed
  tokens, state serializes, the run exits and resumes on answer — the envelope is a **resume
  point**, not a chat message.
- **AskUserQuestion contract** (code.claude.com/docs/en/agent-sdk/user-input, fetched): 1–4
  questions, 2–4 options {label, description}, header ≤12 chars, multiSelect, answers keyed by
  question text, **not available in subagents spawned via the Agent tool**. **WEAKENED facet,
  design-relevant:** free-text "Other" is *integrator-implemented UI*, not tool contract — in
  SDK/headless contexts it can vanish. The D-option must therefore stay a listed option, never
  delegated to the UI's free-text affordance. Recommended-first labeling lives in the internal
  tool description (community-documented), not public docs.
- **The July 2026 auto-continue incident.** Claude Code v2.1.198 shipped default-on 60s
  timeout self-answering; users: "unusable"; the tool's author (trq_, HN 48947776, verified):
  "did not meet our bar", tool had grown into a safety gate beyond intent; v2.1.200 reverted to
  opt-in. **HOLDS** (only the word "inexcusable" was not found). → an unanswered question
  degrades to BLOCKED; no self-answer path may exist.
- **Devin: confidence-gated asking + playbook pre-authorization.** Devin 2.1 (fetched, verbatim):
  asks when not green-confidence, proceeds when green; docs push "make important decisions …
  don't leave decisions open-ended" and playbook sections (Required-from-User / Forbidden
  Actions), folding every mid-run intervention back into the playbook "so the next run does not
  need you". **But the Answer.AI field report (fetched, 20 tasks, 14 failures) shows the dominant
  failure was UNDER-escalation** — "Devin would spend days pursuing impossible solutions rather
  than recognizing fundamental blockers" — with the confidence machinery live. Self-assessed
  confidence is an advisory layer (commitment [5]); it coexisted with the failure it was meant to
  prevent.
- **OpenAI:** Agents SDK ships interruptions with serializable pause/resume and deliberately
  nothing else — "no notification … waits indefinitely … no timeout or escalation … no audit
  record" (integrators build 7 components). Codex's safety design interposes an **auto-approval
  subagent** that approves low-risk actions instead of interrupting — a triage filter. Auditor
  rule: model-graded filters may only *add* escalations, never suppress a human-directed gate.
- **OSS convergence** (vendored copies read directly, verbatim-verified): superpowers
  `executing-plans` enumerates stop triggers — missing dependency, plan gap, unintelligible
  instruction, repeated verification failure — then "Ask for clarification rather than guessing."
  mattpocock/skills: grilling = "one question at a time, a recommended answer attached to each";
  wayfinder tags every open decision **HITL** (agent may never self-answer) vs **AFK** (agent must
  research, never ask). Community decision-brief template: one question + recommended default +
  the consequence delta per option.
- **Anti-patterns reported in the field:** questions the agent could have answered ("symptoms of
  insufficient context-building"), no attached recommendation, mid-execution interruption floods
  (documented for spec-interview tools, *not* Claude Code), and timeout self-answering. Planning
  phase questions are welcomed; execution-phase questions are presumed answerable-by-more-context.

## §5 What the repo already has (pointer inventory)

The full maps live in the run record; the load-bearing rows:

- **x-qa is a near-complete human-QA engine**: obligation grammar + blocking coverage gate
  (`scout-prompt.md:101-134`, `SKILL.md:173`); Domain Research = BVA + state-transition via field
  constraints and transition tables (`scout-prompt.md:49-99`); failure-mode taxonomy incl.
  false-case oracles (`failure-mode-taxonomy.md:8-45`); budget-bounded exploratory hunt with
  independent adversarial triage (`SKILL.md:182`, `triage-verify.md:9-26`); KB regression
  lifecycle (`gap-analyzer.md:14-47`); real-channel contract (`SKILL.md:188-207`); PR-surface
  derivation from a diff — endpoint granularity only (`pr-surface-derivation.md:5-17`).
- **The four QA gaps are all wiring**: (a) x-implement DONE is hardcoded as chain terminus
  (`x-skills-v3.md` Contracts `end`); the only implement→QA loop lives in x-team's worker preamble
  (`worker-preamble.md:31-39`) and dies with x-team's deletion; (b) acceptance examples feed only
  the sha256 gate, never obligations; (c) the scout — the only place the named techniques run —
  is **skipped on branch/pr intent** (`SKILL.md:169`), i.e. exactly the "cover all the changes"
  path runs without obligations and with a disarmed coverage gate; decision tables appear nowhere;
  (d) TEST_PLAN is a gitignored run-local file (`init.sh:80`), not an x-record-grade artifact.
- **The blocker path already owns every missing ingredient, unwired**: BLOCKED is a report with
  no question (`x-skills-v3.md` Contracts; DEC-011); the Question recipe exists but options carry
  no implications and admission is reading-divergence, not stakes; x-team's escalation format has
  options-with-implications + custom-guidance + abort (`blocker-escalation.md:35,52-70`) but v3
  harvests only its sanitizer; done-format Shape 3 has the axis/decider/tradeoff footer
  (`done-format.md:31-58`); x-mindful has the altitude hard rule ("no code-level identifiers…",
  `SKILL.md:27`) and the reversibility rubric + senior_weigh_in gate (`severity-rubric.md:14-41`);
  DEC-016 has the store routing a generalized rule needs — and **no persist trigger fires on a
  blocker resolution**; the same class re-asks from zero next run.

## §6 The critic's holes, and what each decided

1. **Weakened claims quarantined** — SMARTER 98–99%, Basili/Selby figures, Zou mid-quality,
   CHI-2008-as-error-evidence, arXiv:2605.01471 facets: none is cited as a number in any DEC;
   directions only (§7).
2. **NEEDS-INPUT rendering path**: AskUserQuestion is unavailable in Task subagents → contract
   rule: subagents never ask; a blocker inside a dispatched agent returns as fenced data
   (DEC-018) and only the top-level router emits. The D-option stays a listed option (the "Other"
   facet is UI, not contract).
3. **Mutation vs the real-QA contract**: diff-scoped mutants require running the repo's own
   suite, which x-qa's contract forbids and must keep forbidding. Resolution: the mutant probe
   lands in **x-implement's 03-review lane** (reviewer-authored mutants on changed hunks; the
   task tests must kill them), not in x-qa. Repo-suite instruments belong to x-implement;
   real-channel instruments to x-qa.
4. **Suppress-vs-under-escalate tension**: resolved by splitting the predicates. DEC-011's
   two-failure trip-wire is *progress-based* and is not softened (Answer.AI: the expensive
   failure is grinding, so BLOCKED still always fires). The new reversibility gate governs only
   *decision* interrupts: reversible + recommendation ⇒ decide-and-log; costly/one-way ⇒ ask. The
   boundary is a derived stakes predicate, not model confidence (Devin's confidence machinery
   coexisted with days of under-escalation).
5. **Who authors task tests**: landed in DEC-021 — a fresh-context author given plan + acceptance
   examples + public interfaces, never the diff (AgentCoder ~30-pt swing); the
   "expected = observed output" pattern is a lintable violation (CoverUp 68.1%).
6. **Tamper machinery cross-wired**: `test-modification` joins the blocker classes (an edit to a
   pre-existing test or the frozen oracle is a BLOCKED event, not attempt 2), and 03-review gains
   a first-class tamper checklist (METR 30.4% base rate; graders stay outside the write path —
   HCAST 0.7%).
7. **ET evidence is human-subject**: acknowledged in DEC-021 as an assumption with a falsifier
   (confirmed-finding rate of the exploratory phase vs its probe budget); mitigation is that
   x-qa's bounded-probe + independent-triage hunt is already agent-native and shipping.
8. **Transport/wait semantics**: minimally defined rather than researched further — the envelope
   serializes to the run dir, the run exits; resume reads envelope-then-ledger; no-answer means
   still-blocked; notification infrastructure is an explicit non-goal.

## §7 Claims the DECs must not lean on

- "SMARTER captures 98–99% of full elicitation value" — simulation vs SMARTS only.
- Basili & Selby "49.8%/67.5%" — defective source mapping; direction only (Wood et al.).
- "Mid-quality questions are worse than not asking" — only LOW-quality is supported.
- CHI 2008 as interruption-*error* evidence — that paper found no significant error difference;
  the 27.1% figure is Zish & Trafton, procedural post-completion steps.
- arXiv:2605.01471's "2 of 7 families" / "despite reporting success" — unverified facets of a
  single-system case study.
- Any vendor acceptance rate (73% Momentic / 73% Meta) as a correctness bar — commitment [2]
  confound; only the mechanical filter cascades transfer.
- "Random ≈ EP" as a reason to skip partitioning — partitioning is still the enumeration step
  boundary derivation hangs off; it is the *sole* technique it must never be.
