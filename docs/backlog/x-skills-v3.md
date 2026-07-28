---
title: x-skills v3 — consult / record / implement
slug: x-skills-v3
type: refactor
status: ready
created: 2026-07-27
updated: 2026-07-28
related: [x-skills-v3-foundations]
---

# x-skills v3 — consult / record / implement

Collapse 19 interdependent skills into 3, with zero runtime dependency on `obra/superpowers`
or `yeachan-heo/oh-my-claudecode`. **This doc is the human review surface. Read it end to end.**
Facts and citations live in `../research/2026-07-27-x-skills-v3-foundations.md` (`[FOUND]` below).

Round 2 (2026-07-28) falsified round 1's findings and researched a triangulation mechanism.
DEC-002 through DEC-013 carry round-2 amendments; DEC-014 and DEC-015 are new.

Round 3 (2026-07-28) surveyed eight OSS skill frameworks — facts in
`../research/2026-07-28-oss-skill-framework-survey.md` (`[OSS]` below). **Dependency scope changed:
basic-memory and gitnexus are kept** (DEC-016, DEC-017), which reopens part of DEC-013. DEC-018 is
new. All nine top transfer candidates were refuted as proposed and adopted only in narrowed form.

Round 4 (2026-07-28) re-verified every repo-checkable assumption, validated the direction against
Anthropic's published guidance and four prior-art lineages, and mapped all 19 v2 skills for reuse —
facts in `../research/2026-07-28-v3-round4-audit.md` (`[R4]` below). **0 of 20 assumptions refuted,
7 carried wrong numbers** (corrected in place). Two build-order blockers and ten internal
contradictions are fixed below; DEC-019 and DEC-020 are new; the **Disposition** section is new and
is what S6 executes. The direction is confirmed: the 3-skill thin-router shape is the *canonical*
documented pattern, not merely a permitted one `[R4 §3.1]`.

## Context & Problem

Three things are wrong with v2, in order of cost.

**1. Skills document each other's internals.** 18 plugin skills (19 dirs — `x-shared/` holds
assets and has no `SKILL.md`) means up to ~306 possible directed handoff edges, and v2 pays that in
prose: `x-backlog/SKILL.md:137-150` spends ~14 lines on git states inside x-worktree, inside a
22-line handoff block. Dropping the two frameworks is a **96-call-site** mechanical change (61
`superpowers:` + 35 `oh-my-claudecode:` across **30 tracked files** under `skills/`); the coupling
is the real cost. All four numbers corrected round 4 — the quadratic argument is unchanged
`[R4 §1]`.

**2. The output contract does not self-enforce.** `done-format.md:97` bans progress banners;
13 step files open with one (4 x-do + 4 x-review + 5 x-guide, confirmed exactly). **~2,200–2,400**
lines of x-shared and bridge skills are read at bootstrap and cannot be acted on — x-omo alone is
1,084, x-gemini 178, x-team 871 `[R4 §1]`.

**3. Nothing closes the human/agent context gap.** No skill asks the questions that would. The
agent's model of the system is never stated back for correction, so misunderstandings surface
at code review — the most expensive possible time to change your mind.

Success metric is **"my mental model matches the code,"** not "correct output" `[FOUND §2.3]`.
Why this is permanent rather than a stopgap: coding models are RL-trained on binary test-pass
rewards with no penalty for eroding maintainability, and bad architecture's cost arrives in weeks,
where no reward signal reaches `[FOUND §2.1]`.

## Key Decisions

### DEC-001 — Three skills, two kept dependencies
- **Choice:** `x-consult` (align) → `x-record` (persist) → `x-implement` (build). No *plugin*
  dependency at runtime. **Amended 2026-07-28:** two MCP dependencies are kept deliberately —
  `basic-memory` (DEC-016) and `gitnexus` (DEC-017) — plus the capability-gated optional dispatch in
  DEC-015. All three stay behind `capability-loading.md` and degrade silently; "kept" means *wired
  and warranted*, not *assumed present*. The 101-call-site framework coupling still goes.
- **Why:** Coupling, not dependency count, is the cost driver.
- **Alternatives:** Trim 19 → ~8. Rejected: leaves the O(n²) documentation tax intact.
- **Consequences:** **Round 2 counter-evidence, recorded rather than resolved.** The reference
  implementation runs **16 skills** and pays almost no coupling cost, because its only inter-skill
  interface is three conventions: a per-task directory with a monotonic `NN` prefix discovered by
  `ls`, a `### Status` block of derived counts, and a `### Next Steps` section printing a literal
  copy-pasteable prompt `[FOUND §6]`. So decoupling comes from the **interface**, not the skill
  count — and collapsing to 3 costs the ability to load one phase's instructions without the other
  two. We keep 3 skills *and* adopt the interface (DEC-012), accepting that the count is not what
  buys the win.
- **Status:** accepted

### DEC-002 — Entry mandatory, depth triaged, default LOW
- **Choice:** x-consult always enters. Its **first printed line is the tier**, overridable in one
  word. Predicate: *"would an agent misunderstanding my intent be expensive here, **and is this
  area stable enough that the answer will still hold?**"* — volatility pushes **down** a tier —
  with an observable tiebreaker (>1 file or >1 call site). Tier 0 ANSWER (read-only, no docs) ·
  Tier 1 one-shot (no doc) · Tier 2 design doc only · Tier 3 full chain.
- **Why:** Boehm's COCOMO II RESL curve (~161 projects) puts the minimum-total-delay sweet spot at
  **~5% of schedule for a 10 KSLOC project** — "more than 5 percent architecting investment
  unnecessarily increases schedule" — with Rapid Change moving it further left. **So Tier 0/1 is
  the correct answer for the modal x-skills task, and "x-consult always enters" must mean an entry
  that almost always exits immediately** `[FOUND M9]`. The routing-around risk is measured, not
  inferred: users "preferred and trusted more the systems that they perceived as less mentally
  demanding, but with which they performed poorly." The "~40% one-shot" figure is a practitioner's
  estimate, not a measurement `[FOUND §2.4]`.
- **Alternatives:** Mandatory full depth (the original brief) — rejected. Purely mechanical
  predicate — rejected as over-ceremonying a one-line change in a hot function.
- **Escalation floor (new).** Three orthogonal signals aggregated by MAX, plus a floor no score can
  undercut: **a change that alters a published contract, or is not cheaply reversible, is at least
  Tier 2 regardless of file count** `[OSS §3]`. Without it a one-line migration or public-API edit
  lands in Tier 0 — the one place the tier ladder is unsafe. Render the four tiers as a **phase-mask
  table** naming exactly which phase files load per tier; that is what a thin router dispatches on.
  The phase-mask table also carries the `terminalState` each tier may emit (Tier 0 → `answered`;
  Tier 1 → `answered`; Tier 2 → `research | backlog`; Tier 3 → `plan`), which closes a Contracts
  field no DEC previously defined. **"Not cheaply reversible" now has a definition** rather than
  being asserted: port `x-mindful/references/severity-rubric.md` § Reversibility Definitions
  (reversible / costly / one-way, with worked examples) into `00-triage.md` `[R4 §4]`.
- **Externally corroborated, and it is the load-bearing half.** Every credible negative field report
  on plan-first agent workflows attacks *mandatory ceremony on small tasks* — not planning — and
  Anthropic's own best-practices doc concedes the point: *"If you could describe the diff in one
  sentence, skip the plan"* `[R4 §3.2]`. Default-LOW tiering is therefore the mitigation that keeps
  v3 out of the failure mode that sank the tools it resembles, not a nicety.
- **Consequences:** Top-of-skill conditional on an observable predicate. ~~M16's exemption-clause
  ban is narrowed to DISCIPLINE gates~~ — **struck 2026-07-28: no narrowing was ever required.**
  M16's own table has a fourth row for exactly this case — *"Behavior should depend on a condition →
  Conditional keyed to an observable predicate; wrong form: unconditional rule + exemption clauses"*
  — which prescribes DEC-002's remedy natively `[OSS §8]`. The narrowing rested on a misreading of a
  source the foundations doc cited without pointing at. Two carry-forward rules from the same table
  now apply repo-wide: **no nuance clauses** (appending one to a winning recipe degraded it from
  consistent to noisy) and **exemption clauses don't scope** — *"this limit doesn't apply to code
  blocks" still suppresses code blocks; if part of the output must be exempt, restructure so the
  rule cannot reach it.* That second rule lands directly on DEC-007's "print only when non-empty."
  Carry the non-monotone caveat: fewer reasoning tokens also raise behavioural overthinking, so the
  curve has a real minimum — this is not "less is always better."
- **Status:** accepted

### DEC-003 — A hand-authored slot manifest, justified on auditability
- **Choice:** A required-slot manifest per situation. One verdict per row: `RESOLVED` (+pointer) ·
  `ASSUMED` (+falsifier) · `DEFERRED` (+what breaks). ASSUMED/DEFERRED **print only when
  non-empty.**
- **Why (rewritten — round 1's premise was false):** ~~the agent cannot self-detect
  underspecification~~. A hand-authored manifest is **auditable and deterministic, and it forces
  the classification to HAPPEN** — that is the active ingredient. Introspection ("do I have
  questions?") does run near chance at 55.0 AUROC; **explicit classification does not, at
  0.89–0.93. The measured deficit is abstention, not detection** `[FOUND M2]`.
- **Scope (new):** This gates **artifact-internal completeness** — is this consult record
  self-consistent and free of unresolved slots? It does **not** gate requirements completeness.
  Three independent inspection studies say a topic checklist does not find requirements-level
  defects, and **you cannot enumerate the slot you do not know exists** `[FOUND §5]`. DEC-014
  covers that class.
- **The exit gate is not sufficient, and the SlotRow splits.** The canonical falsification of this
  instrument class: mandatory surgical checklists, 101 hospitals, 215,711 procedures, self-reported
  compliance 92–98%, **zero measured benefit** — "the likely reason for the failure is that it was
  not actually used" `[FOUND §5]`. The **pointer** half stays mandatory and is what makes a
  RESOLVED row falsifiable — a `file:line` is checkable, a tick is not. The **prose** half
  (falsifier / breaksIf) is labelled narrative and is **never evidence a row was resolved**;
  forcing per-row justification reliably produces plausible post-hoc rationalization.
- **Better warrant, found 2026-07-28.** M16's table row 3 covers this case directly and more
  cheaply than arguing against Urbach: *"Omits a required element from something they already
  produce → Structural: REQUIRED field or slot in the template they fill in. Wrong form: prose
  reminders near the template"* `[OSS §8]`. **A required template slot and a tick-box checklist are
  different instruments** — the checklist evidence does not reach a slot the author cannot leave
  blank. Re-warrant on row 3; keep the Urbach caveat only against the *exit gate*.
- **Consequences:** The **rework tally is promoted from schema-only to load-bearing** — it is the
  only falsifier this design has. **Conceded 2026-07-28:** it has no observation channel *within* a
  run — it is detected in a later run against a different slug. It is a cross-run trend claim,
  resolvable across runs or not at all. Do not build a per-run storage tier for it.
- **Status:** accepted

### DEC-004 — Research questions before scouting; scout is intent-blind
- **Choice:** The agent writes **research questions (agent-authored, agent-answered, never emitted
  to the human)**; those steer the scout. Scouting runs in a subagent that **never receives the
  feature request or any hypothesis** and returns only verifiable `file:line` facts. No question
  reaches the human before scouting is recorded, and every question cites the file it checked.
- **Why:** The strongest-grounded decision in the set — verbatim in the current primary
  (`create-research/SKILL.md`: "**DO NOT read ticket files** — research must stay objective about
  the current codebase, not be influenced by what a ticket wants to build"), and a *deliberate
  correction*: the superseded 2025 prompt said the opposite `[FOUND §6]`. Independently supported:
  a non-interview evidence source contributed 21% completely novel topics and up to 42% additional
  features beyond interviews. The scout/ask boundary is mechanical — **navigational** gaps resolve
  by exploration, **informational** gaps require the human `[FOUND M3]`.
- **Intent-scrubbing is structural, not an instruction.** The research-question list must contain
  no implementation details and no statement of the task's nature — *"how does it work"*, never
  *"how would we X"*. Partial measures fail: anchoring shows **no decrease with decreasing anchor
  precision or source credibility**, and the only robust remedy is *removing* the misleading
  information. Withholding the ticket while supplying ticket-derived questions is exactly the
  partial measure.
- **Alternatives:** ~~Scout first, then ask what's left~~ — struck; it rejected a rule this design
  already complies with (a naming collision with M3, not a design difference).
- **Consequences:** Costs one extra dispatch, with **no measured benefit term** — round 1's "50%
  fewer questions" was a cross-model comparison, not an ablation. Counterweight: writing before
  touching the codebase is the shape of Analysis Paralysis `[FOUND M3]`.
- **Status:** accepted

### DEC-005 — Fixed question recipe
- **Choice:** Three slots — **EVIDENCE** (pointer that raised it) / **QUESTION** (exactly one
  decision, options A/B/C) / **MY ANSWER** (recommendation + cost of being wrong). Plus:
  - a standing **`D: none of these — what am I missing?`** on every question, its usage rate logged
    as a signal about the **manifest**, not the user;
  - questions ordered **stakes descending** — the irreversible decision goes first;
  - **no yes/no confirmation questions** inside the budget ("is that right?", "shall I proceed?");
  - **admission predicate:** a question is emitted only if two readings of the request would
    produce different implementations, and it must name which.
  - Budget 3–5, hard cap 7. Batch fact-gathering; serialize decision gates.
- **Why:** Enumerated options are an **information-budget requirement**, not a preference — SE 0.3
  needs ~45 dichotomous items, which is why yes/no confirmations are unaffordable at n≤7, while
  polytomous items reach SE<0.30 at a median of 4. Generative option-questions beat user-written
  prompts in *every* pre-registered setting and were rated **less** mentally demanding `[FOUND M4]`.
  Stakes-descending is the cheapest quality win available: response quality declines monotonically
  with position, random responding roughly doubling across a questionnaire.
- **The measured anchoring risk is the suppressed option, not the recommendation.** Closed options
  suppress ~60% of what open forms elicit, and the human cannot feel the loss. Hence `D`, which is
  Schuman's own combine-the-forms remedy at one line.
- **Alternatives:** ~~Withhold the recommendation for one irreversible decision per round~~ —
  **deleted.** No prior art, contradicted by the reference template (which attaches a
  recommendation to *every* question), and the pre-registered study that looked for exactly that
  anchoring effect did not detect it. Net simplification.
- **Consequences:** The 3–5 budget is an artifact of benchmark design and does not transfer
  cleanly `[FOUND §5]`. Treat as a house convention. **Independent counter-position, recorded
  2026-07-28:** a shipped skills repo refuses any cap on principle, from a real field report
  ("Codex just asked me 200 questions"), on the grounds that a cap conflates *genuine
  under-specification* (working as intended) with *redundant questions* (a prompt-quality problem)
  — "the fix for the latter belongs in the skill prompt, not in a counter" `[OSS §8]`. v3 already
  ships that prompt-side fix: the admission predicate. **Falsifier for the cap:** a run that
  terminates *at* the cap with every question still admissible is evidence the cap is wrong, not
  evidence it worked.
- **Status:** accepted

### DEC-006 — Close with examples that become the frozen oracle
- **Choice:** End with concrete acceptance examples (input → expected output); Tier 0, claim → the
  probe command; a bug, the failing reproduction. The human signs off by **disputing an example**.
  Those examples become x-implement's oracle, frozen and read-only to the implementer.
- **Then sweep for exceptions:** step each example, ask "what could go wrong here", resolve each
  candidate against the scout, and promote only unresolvable ones into the existing budget.
- **Why:** **The exception sweep is the only intervention in the corpus with a measured effect on
  the missing-requirement class** — 7.59 vs 3.53 exceptions found, factor 3.17, every subject
  improved. And the mechanism behind examples-over-prose: readers do **not** report ambiguity —
  they disambiguate it unconsciously and misinterpret ambiguities more often than any other defect
  type; what makes a reader notice is being forced to produce a **formal derived artifact**. A
  prose summary can be silently disambiguated by the human exactly as the spec was by the agent;
  an input→output example cannot. Oracle independence: 14% vs 25% fault detection, corroborated
  peer-reviewed at ICSE 2026 (47% worse on real-world code) `[FOUND M7]`.
- **"Frozen" becomes machine-enforced (new).** `gates.sh` records the sha256 of the acceptance-examples
  block when x-record writes **whichever artifact carries it** — the backlog doc at Tier 2, the plan
  at Tier 3 — and re-checks it at every gate run; a mismatch is `FAILED-GATE`.
  **Blocker fixed 2026-07-28:** this previously armed only "when x-record writes the plan", but
  Tier 2 produces no plan (DEC-002) and the plan template does not exist until S5 — so on the S2→S3
  path the freeze could never arm and its own falsifier ("if the hash never changes across S3 and
  S5") presupposed an impossible event. The backlog template therefore carries **both** the
  acceptance-examples block and a per-phase verification list; `lint-plan.sh` runs against either
  artifact `[R4 §2]`.
- **The frozen-oracle pattern is corroborated, and its failure mode is measured.** SWE-bench's
  FAIL_TO_PASS set, `tdd-guard`'s Write/Edit-blocking hook, and Spec Kit's user-approved
  confirmed-failing tests are all the same instrument. The documented way it breaks is **oracle
  gaming**: METR recorded frontier models overwriting graders and timers, with reward-hack attempts
  in ~80% of trajectories on a hard hidden-test variant, and Anthropic's emergent-misalignment work
  documents `sys.exit(0)` harness escapes and hardcoded expected outputs `[R4 §3.2]`. Two
  consequences: the sha256 freeze and DEC-011's stub scan are **mechanically** warranted (advisory
  "don't edit the examples" text is documented-insufficient), and **gate-pass is
  necessary-not-sufficient** — `03-review` against the diff is the backstop, never a formality.
  DEC-006 currently states the write restriction and enforces nothing — and under DEC-011 there is no
  human reading the diff, so an implementer that quietly relaxes an example is undetectable. One shell
  function in a file the Structure Outline already ships. **Falsifier:** if the hash never changes
  across S3 and S5, the check has fired zero times — drop it and revert to prose. Note the read/write
  asymmetry: this is a *write* restriction only. Withholding the examples from the implementer was
  considered and rejected — M7's contamination runs oracle-by-code, and the examples are authored
  before code exists, so temporal ordering already satisfies it `[OSS §3]`.
- **Alternatives:** ~~Prose teach-back — folklore~~ — **retracted as overstated.** Teach-back has
  two systematic reviews and summarise-back-to-confirm is a named step in an empirically derived
  interview order. Keep examples as the primary close on the Kamsties mechanism, not on a folklore
  charge. Carry the usable prohibition: "do you understand?" / "does that make sense?" are **not**
  teach-back, because people answer yes regardless.
- **Status:** accepted

### DEC-007 — Derived status enum + mechanical emit validator
- **Choice:** First token of every terminal emit is one of `DONE` / `BLOCKED` / `NEEDS-INPUT` /
  `FAILED-GATE`, **computed from machine state**. Never model-composed, no invented middle states.
  A script validates every emit.
- **Why:** MAST measures the hole directly — FM-1.5 "not recognizing task completion" 12.4%, FC3
  Task Verification 23.5% `[FOUND M1]`. And it is a **hole-closer, not a speculative guard**: the
  reference implementation's `implement_plan_final_answer.md` hardcodes `### Status /
  - Implementation complete` with **no failure branch anywhere** — no BLOCKED, no FAILED, no
  partial state the implementer is permitted to emit `[FOUND M1]`.
- **Consequences:** **The token is machine-facing.** A fixed token in a fixed position at a fixed
  form is not read by a human after roughly the second exposure (fMRI: visual-processing collapse
  after exposure two; three-week field experiment showing static-warning adherence decay). Its job
  is to gate control flow and be validator-consumed. Hence ASSUMED/DEFERRED print only when
  non-empty. **Do not build form-varying output** — that is the remedy for a human-attention
  channel this design does not rely on.
- **Status:** accepted

### DEC-008 — Pointer-or-delete; three evidence grades
- **Choice:** Every claim carries a resolvable pointer — `file:line`, a pasteable command + its
  captured output, a commit sha, a doc anchor, **or a verbatim user-utterance span** (DEC-014 needs
  somewhere to attach evidence, and an ambiguity in your own sentence has no `file:line`). Prose
  rationale is deleted wherever a pointer exists. **No model-authored numeric confidence**; grades
  are `OBSERVED` / `INFERRED` / `ASSUMED`, and the grade selects sentence form.
- **Why:** Explanations increase acceptance of AI recommendations **regardless of correctness**.
  The confidence ban is re-warranted on verbalized-confidence miscalibration plus capitalization on
  chance — a self-computed precision figure is biased optimistic by 25–40%, with **premature
  termination** as the published consequence in variable-length instruments `[FOUND M6]`.
- **Correction:** the CHI 2021 study is **not** a warrant for the ban — its winning condition *was*
  confidence display. Cite it only for the explanations finding.
- **Schema-conditional requirement (new).** The obligation is a function of the enum value, checked
  by the validator rather than requested in a prompt: `OBSERVED ⇒ pointer required`;
  `ASSUMED ⇒ falsifier required`; `RESOLVED ⇒ pointer required` (DEC-003's rule, asserted in prose
  and enforced nowhere today); and `BLOCKED`/`NEEDS-INPUT`/`FAILED-GATE` each carry a *different*
  obligatory payload (what blocks / which question / which gate + exit code) rather than sharing one
  `nextStep` string. Two independent repos converge on this `[OSS §3]`. Publish the schema as
  documentation, enforce it with a hand-rolled checker whose unknown-key rejection is a set
  difference — and keep **one** file authoritative; the source repo pays for the enum living in two
  files nothing keeps in sync.
- **Self-inflicted instance, fixed 2026-07-28.** The Contracts block encoded the exact shape this
  DEC rejects — one shared `nextStep: string` and a single `source` union — so `validate-emit.sh`,
  built in S0 from that block, would have enforced the rejected form. TerminalEmit now carries
  per-status payload variants. **The Contracts block is authoritative over DEC prose**; where they
  disagree, the block wins and the DEC is amended `[R4 §2]`.
- **Status:** accepted

### DEC-009 — Three docs, immutable paths, stable IDs, document precedence
- **Choice:** `docs/research/` (facts, intent-blind, spot-checked) · `docs/backlog/<slug>.md`
  (decisions + contracts + **Structure Outline** + acceptance-examples block + per-phase
  verification list; read fully; generous cap, destination `docs/research/` — see the settled
  budget below) ·
  **`docs/plans/`** (per-task detail; **machine-facing, not a human review surface**; plural, to
  match what already exists). Paths immutable — `status: done` changes frontmatter only and the
  index moves the row between Active and Shipped tables. Decisions are append-only `DEC-00n` blocks
  with four Nygard fields plus a status line. Links anchor on IDs, never heading prose. No
  `docs/adr/`.
- **Document precedence (new, and load-bearing):** when artifacts disagree, **the most recent
  wins: `plan > backlog > research > original request`**; decisions recorded in the backlog
  supersede the original request. v3 previously had three docs that could contradict each other
  with no resolution rule, while the reference implementation restates a five-layer chain verbatim
  in four skill bodies `[FOUND M17]`. DEC-013 deletes v2's 9-layer *instruction*-precedence ladder;
  a *document*-recency rule is a different object.
- **Superseded DEC blocks move to a "Superseded" section at the document foot**, not inline —
  content explicitly marked as excluded still biases readers, at roughly twice the percentage of
  obsolete items present (six experiments, N=461). IDs still resolve, so append-only and link
  stability are preserved.
- **Why:** v2's archival `git mv` invalidates every inbound link and has already fired once.
  Reviewing long plans is illusory leverage `[FOUND §2]`.
- **Alternatives:** Task-co-located (`docs/tasks/<slug>/NN-<phase>.md`), which is what the
  reference implementation does and is a genuinely stronger fix for link rot — most links stop
  existing rather than needing immutability. **Rejected:** immutable paths plus a precedence rule
  buy the same safety more cheaply than a layout migration, and the backlog dir stays browsable.
- **The line budget, settled 2026-07-28 — it is per file, and it needs a destination.** A three-repo
  natural experiment says what makes an *unenforced* budget hold `[OSS §5]`: a **generous** cap with
  a **named destination** held 24/24 (500 lines, "move detailed reference material into supporting
  files"); a **tight** cap with no destination failed 11/14, its own authoring guide 7.6× over. The
  unit that predicts rot is **lines per file**, not file count. So: the ~200-line target applies to
  each **phase file**, the backlog doc's destination is `docs/research/`, and the number is either a
  `wc -l` assertion in the same script as `validate-emit.sh` or it is deleted from this doc. An
  unenforced number is decoration. Also: the ≥1,500-line drop becomes a **standing** measurement,
  not a one-time cutover tick — deleted lines regrow as recovery shims and disabled-in-place code.
  **Both numbers get an owner (2026-07-28):** `lint-chain.sh` asserts the per-phase-file `wc -l`
  budget and prints the bootstrap-path line total on every run, and both are wired to
  `npm run check` — otherwise they are exactly the decoration this paragraph bans `[R4 §2]`.
  Independent confirmation of the cap: the Agent Skills spec sets SKILL.md at **<500 lines and
  <5,000 tokens**, with resources loaded on demand `[R4 §3.1]`.
- **Two prior-art deltas adopted 2026-07-28 `[R4 §3.2]`.** (1) **The record is the only human review
  surface**, because DEC-011 removes the diff review — so `lint-plan.sh` also enforces
  *reviewability*: per-phase success criteria, exact file paths, an explicit out-of-scope
  statement, and an end-to-end verification step. This is HumanLayer's leverage argument (*"a bad
  line of research … could land you with thousands of bad lines of code"*) plus Anthropic's own spec
  checklist. (2) **Status is written back into the record.** Kiro's most-cited failure is that its
  specs do not self-update; HumanLayer compacts phase status back into the plan. x-implement appends
  a deviation line to the source artifact whenever a slice diverges from it — the ledger (DEC-011)
  is the resume mechanism, not the drift record. **Not adopted:** Spec Kit's "the specification is
  the primary artifact, code is its expression" — the published critique that a non-deterministic
  generator yields different architectures from one spec falsifies it. The v3 record is a decision
  log plus a frozen acceptance contract, never a regenerable implementation spec.
- **Research template prohibition (new).** `templates/research.md` structurally excludes
  **Recommendations** and **Risk-Matrix** sections. Once the research doc prescribes, DEC-004's
  intent-blindness is gone downstream even if the scout dispatch was clean — and model-authored
  High/Medium/Low likelihood attached to no evidence is DEC-008's confidence ban smuggled in as a
  table. Observed degenerating exactly this way in the corpus `[OSS §2]`.
- **Consequences:** **Knowing simplification recorded:** the author separates system-level
  contracts from code-shape signatures into two review passes at two altitudes; DEC-009 collapses
  both into one Structure Outline section. Nygard's four fields are a **lightweight default chosen
  on a tie-breaker**, not a finding — the one head-to-head splits, and we deliberately invert his
  full-sentence-prose rule and reject his standalone `adr/` directory `[FOUND M13]`.
- **Status:** accepted

### DEC-010 — Serial vertical slices; subagents for context isolation only
- **Choice:** Unit of work is a vertical slice with a named verification command. **Subagents are
  for scouting, review and probes — never concurrent mutation.** `x-record` rejects a plan
  containing a phase that names no end-to-end validation.
- **Why:** Now measured, not a bet. Two-agent cooperation reaches **25%, ~50% below a solo
  baseline**, degrading monotonically 68.6% → 46.5% → 30.0% for 2/3/4 agents, with up to 20% of
  budget spent on communication that reduces merge conflicts but does **not** improve success.
  Real-world agentic PRs conflict at **27.67%** across 107k merge-simulated PRs `[FOUND M12]`.
- **Alternatives:** ~~Waves with proven file-disjointness, available per-plan~~ — **closed.**
  CooperBench degraded monotonically on file-overlapping-but-non-adversarial tasks.
  ~~there is no configuration with published support~~ — **overstated, corrected 2026-07-28.** One
  exists: 16 Claudes concurrently mutating a single repo via git-lock task-claiming produced a
  100k-line C compiler that builds Linux 6.9. It ships **no solo baseline and makes no superiority
  claim**, reports frequent merge conflicts, and rests on three preconditions x-implement's
  brownfield targets rarely meet — greenfield, a dense machine-checkable oracle (GCC differential
  testing), and naturally decomposable work `[R4 §3.3]`. The ban stands; the absolute claim does
  not. Newer measurement also still favours serial: parallel agents were faster per character but
  produced 82–189% more code at ~7.7% lower quality.
- **The plan lint is an end-to-end-validation check, not a keyword check.** Keyword rejection of
  "stack-ordered" phases is not implementable: the source's own horizontal and vertical examples
  use identical nouns and differ only in order, a vertical schema change legitimately opens with
  migrations, and renaming defeats it either way. The author's own observable predicate is strictly
  better: *"if a phase cannot be manually checked, the phase is either too small or not vertical
  enough."* Carry his hedge — "don't put steps for manual validation just to have them."
- **Consequences:** "100–200 lines" is restored to what the source says — **a human code-reading
  budget per checkpoint**, not a machine diff ceiling; the author batches 1–3 slices at a time.
  Given DEC-011, that budget is currently unspent. Corrections: 15× is multi-agent-vs-**chat**
  token cost, not a coordination measure; do not cite any "human PR conflict rate" figure.
- **Status:** accepted

### DEC-011 — Per-task gate cascade, fully autonomous
- **Choice:** syntax → typecheck → lint → this task's test → full suite → build → smoke, as a
  **floor**, with additional gates read from the plan's own per-phase verification list so
  DEC-006's acceptance examples become runnable gates. Fail fast, skip downstream. **Print command
  + exit code + diff stat for every gate.** Condense gate output **deterministically**. Two
  failures on the same task = **emit `BLOCKED{gate, both attempts' output}`** — corrected
  2026-07-28, since "escalate" is the exact word this DEC's own stop set bans and DEC-017 notes
  there is no one to escalate to mid-run. **No human stop at slice boundaries.**
- **Why:** End-of-run verification arrives after the failure has locked in `[FOUND M11]`. A fixed
  cascade alone cannot express per-feature probes (curl, sql queries) or manual validation, which
  is why the plan's own verification list extends it — otherwise DEC-006's oracle and this cascade
  have no interface. Deterministic condensation beats an LLM summarization pass at lower cost, and
  summarization *lengthens* trajectories ~15% by obscuring failure signals `[FOUND M14]`.
- **Oracle rule:** ~~only greenfield mandates test-first order~~ → **"the oracle must not have seen
  the implementation," plus "small uniform cycles."** The human ordering literature is null —
  granularity and uniformity predict quality, not sequencing — while the LLM
  context-contamination evidence is strong `[FOUND M7]`.
- **Alternatives — the evidence is SPLIT, not unanimous (corrected 2026-07-28).** One reference
  implementation gates on **human confirmation at every phase boundary**, and its author's 2026
  retraction is explicit: *"don't read the plans. Please, read the code"* `[FOUND §2]`. But a
  second shipped, eval-tested implementation does **deliberate full autonomy** and says so at the
  top: *"Do not pause to check in with your human partner between tasks… 'Should I continue?'
  prompts and progress summaries waste their time"* `[OSS §8]`. Round 2 recorded this decision as
  "against the evidence," which overstated a unanimity that does not exist. **The user's 2026-07-28
  choice of full autonomy is corroborated prior art, not a lone bet.**
- **What makes the autonomous side survivable — and v3 has neither half yet.** It is not a
  per-phase gate; it is an **enumerated stop set** (BLOCKED you cannot resolve · ambiguity that
  genuinely prevents progress · all tasks complete — *not* the word "escalate"), a **per-status
  control branch** with a distinct handling path each, and a hard prohibition: **never re-dispatch
  the same model unchanged after a failure** — change the context, change the model, or split the
  task. Adopt the routing table; do **not** adopt its status enum, which is model-asserted. Derive
  the token per DEC-007.
- **Consequences — residual risk, accepted knowingly, and now quantified.** The design's success
  metric is "my mental model matches the code," and it is carried **entirely by the upstream
  artifacts** (backlog doc + structure outline + acceptance examples). Acceptance criterion S3 can
  pass with no human having read a line of the diff. Field practice has moved *toward* this shape —
  experienced Claude Code users auto-approve at >40% vs ~20% for new users, interrupting on anomaly
  rather than on schedule — but the debt channel is now measured: autonomous-agent usage is
  associated with **+18% static-analysis warnings and +39% cognitive complexity, persisting after
  the velocity gain fades** (MSR 2026) `[R4 §3.3]`. **Falsifier, with an owner:** the rework tally
  (DEC-003), recorded in `x-skill-improve/data/alignment-log.jsonl` — the cross-run channel that
  already exists — and read at each release. Every credible source locates the needed check at the
  **merge boundary, not the slice boundary**; `03-review` against the diff is that check, and it
  costs no human time. If rework attributable to unread code shows up, the per-slice stop is the
  first thing to reconsider.
- **"Two failures = stop" is a house threshold.** Evidence brackets rather than fixes it — most
  achievable repair gains land inside the first three to four iterations, while the counter-argument
  says budget is better spent on fresh samples.
- **The retry is constrained, not re-run (new).** On a gate failure the second attempt receives the
  failing gate's command, exit code and captured output **verbatim** (not the condensed form), plus
  the pre-change state of the files the gate named, and is scoped: *fix only what the gate output
  names; do not regenerate the slice; do not touch a file no gate named.* Re-run the named gate plus
  the cascade downstream of it. Two independent repos converge on exactly these prohibitions
  `[OSS §3]`. **Falsifier:** diff attempt 1's tree against attempt 2's — if attempt 2 confined
  itself already, the constraint is decoration and gets deleted. **Observation channel (added
  2026-07-28, or the falsifier is unmeasurable):** before dispatching attempt 2, `gates.sh` stashes
  attempt 1's tree to `.x-skills/run/<slug>/attempt-1/` — nothing else preserves it. Prior art for
  the retry content itself: x-bugfix's **Instrumentation Pivot + 3-Strike** rule (two failed fixes ⇒
  stop guessing, instrument the full chain, log the decision variables) is the concrete recipe for
  "change the context" `[R4 §4]`.
- **Resume predicate (new, and it is a correctness mechanism, not an instrument).** x-implement
  appends one line per slice to `.x-skills/run/<plan-slug>/progress.md`, first line naming the plan
  as identity. *A slice is done iff it has a `Slice <N>: complete (<sha>)` line; resume at the first
  slice without one; a ledger whose first line names a different plan is not yours.* Warranted on
  MAST **FM-1.3 step repetitions 15.7%** — a figure `[FOUND M1]` already cites and spends on
  nothing — plus the strongest field observation in the corpus: *"controllers that lost their place
  have re-dispatched entire completed task sequences — the single most expensive failure observed"*
  `[OSS §3]`. DEC-011 removed the human who would have noticed. Writer and reader are the same skill,
  so this adds zero inter-skill edges; `.x-skills/` is already gitignored as "run artifacts."
  **Falsifier:** clear context mid-run — if it resumes correctly from `git log` plus the plan's own
  checkboxes alone, delete the ledger.
- **Stub scan (new), ported with its preconditions or not at all.** One more row in the floor
  cascade: reject completion-blocking patterns (`TODO`, `not implemented`, `pass  # stub`, …) in the
  slice's own diff. It attacks DEC-011's accepted residual with a machine check at zero human cost.
  But the six regexes are safe only because of ~100 lines of surrounding scaffolding, so port all
  three preconditions: **(1) added lines only** (`git diff --unified=0`), **(2) an extension
  allowlist**, **(3) string- and regex-literal stripping before matching.** Bare regexes in bash
  would first hit S0's deliberately-bad fixtures and `gates.sh`'s own pattern literals — and a gate
  that false-positives on the repo shipping it gets muted, which is worse than no gate.
  **Falsifier, with an owner and a time:** >1 false positive in 10 real diffs → ship nothing. The
  ten diffs are S3's own slices, labelled at the S3 checkpoint before the scan is wired to
  `npm run check` — a pre-ship trial, not a post-hoc hope.
- **What fail-fast cannot express is *inapplicable*, not *unrun*.** No typecheck configured, no
  build script, no smoke target — a cascade that silently omits those records nothing in
  `gateExitCodes[]` and reads as green. If a real S3 run shows ≥2 floor gates producing no entry at
  all, `gates.sh` needs an explicit N/A row printing the reason. A `gates.sh` output change, not a
  schema change. **Already solved twice in this repo `[R4 §4]`:** `x-qa/references/quality-gates.md`
  treats a missing metric as status `unmeasured` that does **not** flip the verdict and surfaces as
  a `⚠` row; `x-shared/completion-cascade.md` §3 supplies the command-discovery ladder
  (`package.json` scripts → per-language config → *"mark `<tool>: no-config` and continue. Do NOT
  invent a command"*). Port both rather than re-deriving them — the do-not-invent rule is the part
  most likely to be lost in a rewrite from memory.
- **Status:** accepted

### DEC-012 — Thin router + phase files; one model-invoked skill
- **Choice:** Each skill is a thin router plus small phase files loaded on demand. **x-consult is
  the only model-invoked skill**, trigger-only description. Section headings are claim sentences;
  the label vocabulary is banned; no progress banners.
- **Judging rule (narrowed):** every judging pass is a separate dispatch that cannot see the
  authoring context, **and fires only when gated on a failing gate or a concrete artifact — never
  unconditionally.** An ungrounded critic hallucinates flaws in functionally correct code and the
  actor introduces regressions, degrading Pass@1 while raising cost. And separate dispatch is
  **necessary but not the active ingredient — critic strength is** `[FOUND M8]`; see DEC-015.
- **Handoff convention (new, adopted wholesale):** every terminal emit ends with a **literal
  copy-pasteable next-step string** naming the next skill and the artifact path. This plus the
  per-task file convention is what lets the reference implementation run 16 skills at near-zero
  coupling `[FOUND §6]`.
- **`nextStep` is derived, not composed (amended 2026-07-28).** It is the one field DEC-012 makes
  load-bearing and the one field nothing derives or checks, while `status` beside it *is* derived.
  Declare `next-skill:` in x-consult's and x-record's frontmatter and generate the string from it,
  so a rename cannot break the chain silently at runtime. **Three enumerated variants, not one
  rule** — a single frontmatter derivation cannot express DEC-017's stale-index remediation
  (`node .gitnexus/run.cjs analyze` names no skill and no artifact) and x-implement declares no
  successor at all: `chain` (frontmatter successor + artifact path) · `remediate` (a command from a
  fixed table keyed on machine state) · `end` (empty, chain terminus). The validator checks the
  variant against the emitting skill and status `[R4 §2]`.
- **Coupling has no instrument, and that is the regression v3 exists to prevent.** The
  `superpowers:|oh-my-claudecode:` grep measures dependency strings and the ~1,500-line drop measures
  volume; neither would detect x-consult starting to document x-implement's internals. Add one
  ~40-line stdlib script in S6, self-tested in-file: assert the chain edges **by enumeration, not by
  count** (`x-consult → x-record`, `x-record → x-implement`, `x-implement → end`; "three-edge chain"
  was ambiguous — three nodes carry two forward edges); resolve every path
  and skill name mentioned in any skill body against disk; **bidirectional reachability** — every
  file a router names exists, every file under `phases/`/`manifests/`/`templates/` is named by a
  router, exemptions carrying a written reason; and budget live refs so **a phase file may name at
  most its immediate successor.** v2 produced exactly the unreachable-file failure this catches
  (`slot-schema.md`'s "v2 reference — not shipped"; `completion-cascade.md`'s six Deferred rows). Do
  not copy the corpus's `exit(0)` ending — a validator that cannot fail is Urbach in software `[OSS §2]`.
- **No pre-judging in dispatch prompts.** Nothing today stops the primary writing the verdict into
  the dispatch prompt, which defeats separation while satisfying it on paper. The tell is a fixed
  phrase list — *"do not flag", "don't treat X as a defect", "at most Minor", "the plan chose"* —
  so the composed prompt is greppable. This is also the cheapest way to make S4's "no hypothesis"
  and S2's review-isolation checks mechanical rather than a human reading a prompt `[OSS §3]`.
  **"Provably" needs a prover (fixed 2026-07-28).** Nothing in the design captured a dispatch prompt
  anywhere, so S4's checkpoint was unobservable. Every subagent dispatch prompt is written to
  `.x-skills/run/<slug>/dispatch/<phase>-<n>.txt` **before** dispatch, and the S4 check is a lint
  over that file: the pre-judging phrase list **plus** a hypothesis-marker list (`we should`,
  `the fix is`, `implement`, `add a`, `refactor` in an `02-scout` prompt). The lint lives in
  `validate-emit.sh`; note the prompt file is an input artifact, not an emit `[R4 §2]`. Harvested
  prior art for the prompt bodies themselves: `x-omo/references/prompt-blocks.md`'s
  `<grounding_rules>` and `<missing_context_gating>` blocks state DEC-008's grade discipline in
  dispatchable form, and `x-review`'s Scope Contract is the grounding DEC-012's judging rule
  requires `[R4 §4]`. One trap that follows: `x-review/references/scope-guard.md` is *written* in
  imperative "DO NOT report…" form, so the pre-judging lint must distinguish a generic policy block
  from target-specific pre-judgement or it false-positives on its own harvested asset.
- **Consequences:** Ordering enforced structurally — x-record refuses to write until the consult
  artifact exists on disk with its open-required-slots row resolved. Nothing stops a user who never
  invokes x-consult; accepted rather than papered over with a hook dependency we just removed.
- **Status:** accepted

### DEC-013 — Delete, don't port
- **Choice:** Drop `slot-schema.md` + slot resolution, `reactions-vocabulary.md`, the 9-layer
  *instruction*-precedence ladder, the `send_message` section, the letter-namespace map,
  `x-omo`/`x-gemini` as bootstrap deps, and `x-team`. Keep `capability-loading.md` and the
  SessionStart hook nearly verbatim, minus `plugin.omc` and `plugin.superpowers`.
- **Amended 2026-07-28:** the GitNexus freshness contract is **no longer deleted** — DEC-017 keeps
  gitnexus. What dies is its *shape*: 45 lines restated per skill become ~10 lines in one place
  (`mcp-toolbox.md`'s use-class index plus the probe section). The deletion target was duplication,
  and that target is still met.
- **Why:** **~2,200–2,400** lines the model reads at bootstrap and cannot act on — measured round 4;
  `[FOUND §4]`'s "~1,700" undercounted, and its "x-omo/x-gemini at 1,084" was x-omo alone (x-gemini
  is 178, x-team 871) `[R4 §1]`. The ≥1,500 acceptance floor is comfortably met either way.
- **Confirmed dead, not merely slated (round 4).** `reactions-vocabulary.md` has **zero** consumers
  outside itself — 71 bootstrap-read lines nobody names, whose own § Phase status concedes the
  execution contract that would give its 18 triggers meaning was never built. It and `slot-schema.md`
  (5 of 7 slots "not emitted in v1", 3 banned dependency strings, a "v2 reference — not shipped"
  section) become `lint-chain.sh`'s two bad-case fixtures: the cheapest possible proof that
  bidirectional reachability catches real rot `[R4 §4]`.
- **Consequences:** DEC-009's *document*-precedence rule replaces the deleted *instruction*-
  precedence ladder for the one job that was load-bearing. `capability-loading.md` survives and is
  what DEC-015 rides on.
- **Status:** accepted

### DEC-014 — Interview-review dispatch (Tier 2/3)
- **Choice:** Between `03-debate` and `04-close`, **one** dispatch receives only (a) the human's
  verbatim words, (b) the scout's `file:line` facts, (c) the drafted acceptance examples — **never**
  the primary agent's hypothesis, drafted questions, or slot verdicts. It:
  1. scans the human's own sentences for five ambiguity cues (under-specified terms, vague terms,
     quantifiers, pronouns, domain-specific terms) and returns the questions it would have asked,
     targeting question-probing / alternative-seeking / preference-seeking;
  2. cross-examines each `OBSERVED` scout claim in **one** round, downgrading unsupported claims to
     `INFERRED`;
  3. checks the drafted questions against DEC-005's prohibitions.

  Output is **unioned mechanically and deduped** with the primary's questions; the same 3–5
  (cap 7) budget is then spent on the ranked union. **Zero extra human questions.**
- **Why:** An independent second reader of the same interview roughly doubles ambiguity yield —
  **68% found in review vs 32% live — at only ~26% overlap between readers.** And the **union**
  rule, not a consensus rule, is the one finding that replicated in both an original experiment and
  its independent replication: collection meetings do not improve detection rate `[FOUND M18]`.
  One cross-examination round buys ~14 F1; each subsequent round ~3.
- **New quantitative support, LLM-side this time (2026-07-28).** Across 8 models and 294 confirmed
  defects: no single model exceeded ~61% recall, **56.8% of defects were found by exactly one
  model**, and a second independent reviewer lifts coverage **~47% → ~72%** — the largest marginal
  gain — at median cross-family overlap **~0.29**, strikingly close to the ~26% human baseline this
  DEC already uses as its health metric. A separate result validates the information-diet rule
  directly: a model reviewing its own output misses ~31.7% of its own semantic-drift errors and
  rationalizes them `[R4 §3.3]`. The confirmed caveat is the one already priced in — the gain
  concentrates when the second reader is a *different model family*, which is why DEC-015 exists and
  why same-model fallback is degraded rather than worthless.
- **Alternatives, all rejected on measured evidence:**
  - *N sampled readings of the request, diffed* — output-side divergence is **AUROC 54.9, near
    chance**, because models stay 67–82% self-consistent under genuine ambiguity while holding real
    mass on the alternatives.
  - *A gate deciding whether to ask* — an always-ask-one baseline scored **70.40% against an
    uncertainty-aware detector's 69.40%**, at 508 vs 1,053 human queries.
  - *Persona / perspective rotation* — 162 roles × 4 model families × 2,410 questions, no
    improvement over control, effects "largely random"; the RE replication found no significant
    difference among perspectives in detection rate, defects/hour, or coverage.
  - *Probing the human from multiple angles, reverse-worded items, repertory grid* — all cost the
    scarce resource and are counter-evidenced.
- **The overlap predicate is mechanical, and the decision rule is pre-registered (new).** Two
  questions are **the same iff their `eliminates:` reading strings match** — a field the Question
  contract already carries and already hangs inadmissibility off, which makes overlap an integer
  ratio a script computes rather than a prose judgement. And the consequence is written down *now*,
  before the number exists: **if overlap ≥ 80%, DEC-014's claim narrows** from "doubles ambiguity
  yield" to "catches DEC-005 prohibition violations" — the third of its three jobs, which needs no
  independence. Logging a threshold with no pre-declared consequence is how a falsifier becomes
  furniture `[OSS §3]`. **Falsifier for the predicate itself:** if `eliminates:` cannot yield a
  deterministic same/different verdict on 10 hand-built question pairs, the overlap row is
  unmeasurable and the honest move is to delete it, not to add a second unmeasurable comparison.
- **Consequences:** A same-base-model review is a **monomethod block; MTMM predicts it will
  UNDER-flag.** The overlap rate against the ~26% human baseline is the health metric and must be
  logged from S2. **The review may flag only cues present in the human's actual words** —
  inferring vagueness from brevity, silence or tone is banned (a trained human interviewer agrees
  at only κ≈.30, and probing beyond the verbal report produces false alarms). Falsifier: the user
  reporting a forked question as pedantic.
- **Status:** accepted

### DEC-015 — Cross-model dispatch, reopened for exactly two roles
- **Choice:** A different model may be used for **exactly two roles: the DEC-014 sufficiency /
  interview reviewer, and the DEC-006 acceptance oracle.** Never as a general dispatch layer.
  Gated on `capability-loading.md` — if a cross-model CLI is present, use it; if absent, run
  same-model and log the overlap rate. **No bootstrap dependency**: no catalog is read, no bridge
  skill is loaded, and the absent path is silent.
- **Why:** Critic **strength**, not context separation, is the active ingredient in review quality —
  a stronger model's feedback beat both the i.i.d. baseline and self-repair at every budget, and
  human feedback lifted repair **1.58×** `[FOUND M8]`. Model diversity is also the only fix for
  DEC-014's monomethod risk, and both of M7's source papers recommend a different model or session
  **by name**.
- **Alternatives:** Keep it a non-goal and instrument only — rejected by the user on 2026-07-28,
  on the grounds that the two roles are exactly where the evidence is specific. Resurrect x-omo —
  rejected; that is the 1,084-line bootstrap tax DEC-013 exists to delete.
- **Silence is a bootstrap property, not an output property (amended 2026-07-28).** An independent
  repo states the opposite rule three times — *"Skipping is fine; silent skipping is not"* — and the
  tension is also internal: DEC-014's overlap rate is uninterpretable if you cannot tell which mode
  produced it `[OSS §8]`. So: `ReviewFindings` gains `reviewer: same-model | cross-model:<cli>`,
  recorded on the overlap row. **Announce in the machine channel, stay silent in the human one.**
  Zero bootstrap cost, and it makes DEC-014's falsifier well-defined.
- **Consequences:** The two roles must degrade cleanly to same-model, so neither may *depend* on
  cross-model being present. This is the one place v3 reaches outside itself, and it is optional
  by construction. Per DEC-018 the prompt is piped on stdin, never interpolated into a shell argument.
- **Exit status cannot be trusted, and this nearly broke the falsifier `[R4 §4]`.** `x-gemini`'s
  gotchas file records that `agy` **exits 0 on auth failure, quota exhaustion and empty output**. A
  cross-model lane that reads exit status would score an auth failure as an empty review and log a
  0% overlap rate — silently corrupting DEC-014's only health metric in the *favourable* direction.
  So the lane re-derives a real exit code from empty stdout plus the log tail before recording any
  overlap row, and **serializes** cross-model calls (concurrent invocations contend on a
  per-invocation gRPC language server and hang). Harvest these into `capability-loading.md` when
  x-gemini is deleted; they are the only record of them. **Open:** DEC-015 requires a read-only
  flag and neither `agy` nor `bin/agy-agent` documents one — verify before S2 or drop the
  requirement to "no write tools in the prompt's tool allowlist."
- **Status:** accepted

### DEC-016 — basic-memory for cross-repo transferables only
- **Choice:** Kept as a first-class dependency, wired at exactly three points. **Recall** at
  **`03-debate`, after the scout has run** (`search_notes`, topical query, never the repo name,
  never `tags` — probed round 4 and confirmed a *restrictive AND* filter: querying a nonexistent tag
  returns output byte-identical to an empty knowledge base, so a miss is indistinguishable from no
  prior knowledge `[R4 §1]`); hits enter as `ASSUMED`-grade Claims.
  **Moved from `01-questions` on 2026-07-28.** Round 3 logged this as an open risk; round 4 found
  DEC-004 contradicts the old placement outright rather than merely warning about it — memory hits
  reaching the agent that authors the research questions reach the scout *through* those questions,
  which is precisely the partial measure DEC-004's evidence says fails ("anchoring shows no decrease
  with decreasing anchor precision"; "the only robust remedy is removing the misleading
  information"). Waiting for a falsifier that requires a prose judgement about whether a question
  "presupposed" a claim was not a plan `[R4 §2]`. **Stub write** in x-record after `docs/` lands: the transferable
  generalization plus a backlink to `docs/<kind>/<slug>.md @ <commit-sha>` — never the DEC body.
  **Persist** at x-implement `04-report`, on a *derived* precondition: at least one gate went RED
  then GREEN this run. A fully-green run writes nothing.
- **The routing rule is the pointer form**, which DEC-008 already forces every claim to carry:
  `file:line | commit-sha | doc-anchor` → `docs/`. **`command+output` splits (corrected
  2026-07-28):** repo-bound output → `docs/`; only a **repo-independent invariant** → basic-memory.
  The old rule sent all `command+output` to basic-memory while this DEC's own one-line test sent
  commit-dependent output to `docs/` — the two routed the same claim to different stores `[R4 §2]`.
  A user-utterance-span *about the user* → `MEMORY.md`, which x-skills never writes; a
  user-utterance-span that is **evidence for a Question or Claim** (DEC-014's cues) persists in the
  consult artifact itself and goes to neither store. One-line form for a phase file: *"if checking out a different commit would make
  this line wrong, it belongs in `docs/`; if a session in a different repo six months from now
  would want it and could not cheaply re-derive it, it belongs in basic-memory."*
- **Why:** cross-repo recall is the one job `docs/` structurally cannot do — x-skills runs inside
  *other* checkouts, so a gotcha learned while implementing in another repo has no home in either
  repo's `docs/`. Already OBSERVED in the live store `[OSS §4]`. It is also the only one of the
  three stores that is droppable, so it must earn its keep on that alone.
- **The strongest bet in the set after the 2026 sweep, and it names the failure mode `[R4 §3.3]`.**
  Cross-domain memory pooling across six coding benchmarks yields **+3.7% Pass@3 with 94.5% of the
  gain from procedural meta-knowledge** (debugging workflows, validation routines), and
  **insight-level memories — principles with file paths, variable names and concrete code stripped —
  help ~3× more than raw trajectories**, while low-abstraction memories cause **negative transfer**
  via misapplied patterns. Independently: ungoverned persistence is *worse than no memory at all*
  (96% task completion with selective memory vs 79% with none vs **71% with full-history
  persistence**). That is this DEC's design measured from the outside, and it upgrades **"link,
  don't restate" from a style rule to a correctness requirement** — so the >~40-contiguous-duplicated-
  words check becomes a **write-time lint at S2**, not a post-hoc diff audit after the notes exist.
- **Contract change:** DEC-008's pointer enum gains a sixth form, `memory://<permalink>`. Without
  it a recalled note cannot be cited at all. A memory hit is never `OBSERVED` — it is not an
  observation of the current code; it upgrades to `INFERRED` only once the scout corroborates it.
- **Prohibitions (each closing an OBSERVED failure `[OSS §4]`):** recall output **must not** reach
  the intent-blind scout — a note is a hypothesis, and DEC-004's evidence says partial withholding
  fails. No basic-memory in `03b-review` (contaminates DEC-014's monomethod control and inflates
  its only falsifier). No `recent_activity` at session start — a recency feed, not a relevance
  query. No `sessions/` auto-capture; ~18 such notes already exist, titled from raw first user
  messages. x-record **prints the derived project slug** and hard-fails on a slug containing a dot:
  three worktree-named folders already exist in the store, written silently (`lessons/` holds
  exactly three dotted folder slugs — verified round 4, along with 19 raw-titled session notes and
  the banned green-run note `[R4 §1]`). The slug normalizer already exists: port
  `x-worktree/references/doc-naming.md` (frontmatter slug > title > H1 > filename, plus its 6-step
  normalization) rather than writing a second one `[R4 §4]`.
- **Consequences:** no new plumbing — `mcp.basic_memory` already flows through `bin/setup:905` and
  `hooks/inject-capabilities.sh:50` (both line numbers verified exact, round 4). **Open risk:** "link, don't restate" is prose, and this
  design's own diagnosis is that prose contracts do not self-enforce. Falsifier: after S2/S3, diff
  every note under `decisions/x-skills/` against the doc it cites — any note carrying >~40
  contiguous duplicated words means the rule failed and the overlap check must become a write-time lint.
- **Status:** accepted

### DEC-017 — gitnexus is advisory, never a gate
- **Choice:** Kept, and scoped to what it can actually do. `query` + `context` in `02-scout` for
  unfamiliar **code** repos. `impact` (`summaryOnly:true`) and `detect_changes` in x-implement as
  **recorded evidence only** — two integers (direct callers at d=1, affected-process count) as an
  `OBSERVED` Claim with `commitsBehind` printed on the same line. Never control flow. The
  LOW/MEDIUM/HIGH/CRITICAL label is never consulted — it is a composed label, and DEC-007 bans
  composed status. x-record uses `context` to verify Structure Outline symbols exist, **downgrading**
  an unresolvable row to `ASSUMED` rather than rejecting it.
- **Three deterministic states, no model judgement:** (1) not pinned / not indexed / own-coverage
  false → lane absent, native `Grep`, silent. (2) indexed + fresh → all classes usable.
  (3) indexed + **stale** → advisory class usable *with `commitsBehind` printed*; correctness-sensitive
  class not consulted, and **the skip is printed**. Never silent either way. Never auto-run
  `analyze` — emit the command as DEC-012's copy-pasteable next step.
- **Why — measured, and it inverts the assumption `[OSS §4]`:** on this repo gitnexus indexes
  **2,231 own nodes against 153,719 vendored (1.4%)**, **0 own symbols in any of 300 Processes**,
  18 Functions all under an explicit non-goal directory, and **zero of 111 `.sh` files** produce a
  Function node. `list_repos` shows **7 of 8 repos stale**, with no incremental analyze. So the
  correctness-sensitive class is near-dead by default, and a design that gates on freshness has a
  decorative gitnexus path. gitnexus is a dependency for the **target repos x-skills operates on**,
  not for x-skills' own development.
- **Alternatives:** `impact` as a hard gate (the current `CLAUDE.md` "MUST"). **Rejected on three
  grounds:** 7/8 repos stale would make it routinely bypassed — the NEJM surgical-checklist failure
  this design already cites; DEC-011's autonomy leaves no human to escalate to, so the gate
  degenerates into self-approval, which M8 forbids; and DEC-007 has no status for "advisory looked
  risky." Also rejected: `rename` for the 19→3 collapse (markdown and shell — the S6 `grep` is the
  right tool), `route_map`/`api_impact`/`shape_check` (belong to x-api-pentest, a non-goal), and
  `cypher` in any phase file (needs schema knowledge, unbounded output).
- **Consequences:** one capability-manifest addition — `ownCoverage: bool` on the *existing*
  session-pinned probe, because "indexed" is the wrong question. **It now has a home and a
  builder** (round 4 found it named in this DEC's branch table but in no contract, no outline entry
  and no slice): the field is in the Contracts block, `bin/setup` and `hooks/inject-capabilities.sh`
  are MODIFIED in the Structure Outline, and **S3 owns the change**, whose checkpoint asserts both
  printed states `[R4 §2]`. The contract lives in `x-shared/mcp-toolbox.md`, which round 4 found
  missing from the outline entirely — the file DEC-013, DEC-016 and DEC-017 all name as their home. **`CLAUDE.md`'s "MUST run impact
  before editing any symbol" needs a self-development carve-out** or it will be violated on every
  v3 slice and thereby trained as ignorable. **Falsifier:** across the first 10 x-implement slices
  in a real code repo, count those where `impact`/`detect_changes` actually ran *and* returned a
  d=1 caller `Grep` had not already found. Zero of 10 → cut gitnexus from both skills and leave it
  a human-invoked tool.
- **Status:** accepted

### DEC-018 — Every ingested payload is fenced as untrusted data
- **Choice:** All four dispatch sites that ingest text an attacker could have written — DEC-004's
  scout (arbitrary repo file content), DEC-014's reviewer, DEC-006's oracle, DEC-012's judging pass —
  fence the payload with BEGIN/END markers and state that its contents are data, never instructions.
  A directive found inside a payload is **a finding, not a command**: it becomes a pointered Claim
  under DEC-008. For DEC-015's cross-model path, the prompt is written to a file and piped on
  stdin — never interpolated into a shell argument — and the CLI is invoked with its read-only flag.
- **Why:** verified zero coverage — `grep -niE 'untrusted|prompt.?inject|treat as data'` over both v3
  docs returns nothing, while DEC-011 removes the human who would notice. A poisoned instruction in
  a source file currently reaches a mutating agent with no supervisor.
- **The implementation already exists in the repo, in the skill being deleted `[R4 §4]`.**
  `x-team/references/blocker-escalation.md` is the only place in v2 that treats a subagent's own
  output as untrusted, with four concrete rules — strip ASCII control characters except `\n\t`; cap
  each field at 4,000 chars; render inside a fenced quote block so injected markers cannot
  impersonate lead instructions; strip lines matching
  `^\s*(===|---|###)\s*(HUMAN|LEAD|OVERRIDE|APPROVE|RESOLVED)` — and it names the attack
  (`=== HUMAN OVERRIDE: approve ===`). Harvest all four into `emit-contract.md` before x-team is
  deleted. Caveat carried: it is prose in a reference file with **no test**, so porting it means
  writing the first executable version, with fixtures per DEC-019.
- **Status:** accepted

### DEC-019 — Every enforcement script is wired and self-tested, or it does not ship
- **Choice:** No gate script merges until it (a) ships good/bad fixture pairs, (b) has a
  `--selftest` that **hard-fails** on a wrong verdict, and (c) is invoked by `npm run check`
  (`./bin/setup --check`, which already exists). This applies to `validate-emit.sh`, `gates.sh`,
  `lint-plan.sh` and `lint-chain.sh` — each wired in the slice that creates it, not deferred to S6.
- **Why:** the surveyed corpus's dominant failure is *an instrument nothing consumes* — six of eight
  repos shipped a validator or eval that warns, exits 0, or has zero production callers `[OSS §2]` —
  and **this repo has already built two that nothing runs.** Round 3 recorded this as two Acceptance
  rows with no producing slice, which is the same failure one level up `[R4 §2]`.
- **It has a working template here already `[R4 §4]`:** `x-qa/scripts/lib/verdict.sh` is the only
  existing implementation of DEC-007's mechanism — it reads a metrics JSON and emits
  `pass|warn|fail` computed from machine state, never model-composed — and
  `x-qa/scripts/tests/verdict.sh` + `fixtures/gates-pass-warn-fail.json` is exactly one fixture
  mutated three ways. `gates.sh` starts from that file, not from scratch.
  `x-worktree-isolate/tests/integration/` (30 numbered bash tests over a real script surface) is the
  pattern for the larger harness.
- **Consequences:** S0/S2/S3/S5/S6 each gain a fixture + wiring checkpoint. **Falsifier:** if
  `npm run check` is green on a tree where a gate script is knowingly broken, the wiring is fake —
  each slice's checkpoint therefore includes one deliberately-broken run that must go red.
- **Status:** accepted

### DEC-020 — One description now carries the trigger surface of eighteen
- **Choice:** x-consult's `description` (≤1,024 chars, spec-enforced) is validated with a
  **should-trigger / should-not-trigger eval** before S6 cutover: ~20 prompts per side, ~3 runs
  each, pass at a **0.5 trigger rate**, held-out validation split. Every other v3 skill declares
  `disable-model-invocation: true`, removing its description from the session listing entirely.
- **Why:** consolidation moves a real risk, and official guidance both names it and prescribes the
  test `[R4 §3.1]`. *"The description carries the entire burden of triggering"*; *"skills scoped too
  broadly become hard to activate precisely."* Meanwhile the failure consolidation **fixes** is
  mechanical: the skill listing is budgeted at ~1% of the context window with a 1,536-char per-entry
  cap, and **when it overflows Claude Code shortens descriptions and drops them starting with the
  least-invoked skills** — 18 overlapping routers sit inside that failure zone; 1 model-invoked skill
  does not. `disable-model-invocation` is also what the docs prescribe for side-effectful workflows
  (*"you don't want Claude deciding to deploy because your code looks ready"*), which independently
  confirms x-implement must be user-invoked.
- **Alternatives:** ship and watch. Rejected — a trigger miss is silent and indistinguishable from
  the user not wanting the skill, so there is no natural signal to watch.
- **Consequences:** two structural constraints from the same guidance become build rules: reference
  files stay **one level deep** from `SKILL.md` (deeper links are partially read, e.g. `head -100`),
  and every phase-file pointer states **when** to load it, not just that it exists. Both are
  `lint-chain.sh` assertions.
- **Status:** accepted

## Contracts

**This block is authoritative.** Where a DEC body and this block disagree, the block wins and the
DEC is amended (DEC-008).

```
TerminalEmit                        # first token, derived — never model-composed
  status   : DONE | BLOCKED | NEEDS-INPUT | FAILED-GATE
  payload  :                        # per-status, NOT a shared string (DEC-008)
    DONE        { filesWritten[], gateExitCodes[] }
    BLOCKED     { blocker, attempts[] }          # what blocks + both attempts' raw output
    NEEDS-INPUT { question: Question }           # the one admissible question
    FAILED-GATE { gate, exitCode, output }
  nextStep : chain{skill, artifactPath}          # derived from `next-skill:` frontmatter
           | remediate{command}                  # fixed table keyed on machine state (DEC-017)
           | end                                 # chain terminus (x-implement DONE)

Claim
  grade   : OBSERVED | INFERRED | ASSUMED
  pointer : file:line | command+output | commit-sha | doc-anchor | user-utterance-span
          | memory://<permalink>     # DEC-016 — never OBSERVED; INFERRED only once scouted
  # pointer form also routes the store: file:line|commit-sha|doc-anchor -> docs/
  #                                     command+output|repo-independent  -> basic-memory

SlotRow
  name     : string
  required : bool
  verdict  : RESOLVED{pointer}      # pointer is the CHECKABLE half — mandatory
           | ASSUMED{falsifier}     # narrative — never evidence of resolution
           | DEFERRED{breaksIf}     # narrative

Question                            # exactly one decision each
  evidence   : pointer              # what the scout checked and failed to resolve
  question   : string + options[A|B|C] + D:"none of these — what am I missing?"
  eliminates : reading              # which competing reading this rules out; none => inadmissible
  myAnswer   : recommendation + costOfBeingWrong
  # ordered stakes-descending; no yes/no confirmations

ReviewFindings → union              # DEC-014, agent-side, zero human cost
  cues[]       : user-utterance-span
  questions[]  : Question           # unioned + deduped with primary's, never reconciled
  downgraded[] : OBSERVED → INFERRED
  reviewer     : same-model | cross-model:<cli>    # DEC-015 — machine channel only
  overlap      : |same| / |union|   # same iff eliminates: strings match; >=0.80 narrows DEC-014

ConsultArtifact → x-record          # the gate x-record checks on disk
  tier         : 0 | 1 | 2 | 3
  slots        : SlotRow[]          # zero open REQUIRED rows to pass
  examples     : (input → expectedOutput)[]        # becomes the frozen oracle
  terminalState: answered | research | backlog | plan   # derived from tier, DEC-002 phase-mask
                                    # 0,1 -> answered | 2 -> research|backlog | 3 -> plan
                                    # `handoff` deleted — no DEC defined it
  nextStep     : TerminalEmit.nextStep

RunArtifacts   .x-skills/run/<slug>/               # gitignored; one dir per consult/plan slug
  metrics.md   : one row per instrument            # DEC-014 overlap, DEC-017 gitnexus-vs-Grep,
                                                   #   DEC-003 rework pointer — written from S2
  progress.md  : `Slice <N>: complete (<sha>)`     # resume predicate (DEC-011); line 1 names the plan
  dispatch/    : <phase>-<n>.txt, written pre-dispatch  # what S4's lint reads (DEC-012)
  attempt-1/   : stashed tree before a constrained retry  # DEC-011 falsifier's only channel

CapabilityManifest                  # additions only; schema lives in capability-loading.md
  mcp.gitnexus  : { pinned, indexed, fresh, commitsBehind, ownCoverage }   # DEC-017
  crossModelCli : string | null     # DEC-015 two-role gate
```

Manifests are per situation, cheapest disqualifier first: **new-requirement** (user + trigger,
current behavior, desired behavior, boundary/contract, non-goals, acceptance examples) ·
**read-only-question** (the question asked, who is asking and what decision it feeds, claim +
probe) · **prod-bug** (expected behavior *first*, error evidence, repro, blast radius, when it
started).

## Disposition — all 19 dirs, and what S6 actually does

**End state: 3 new skills + 6 kept unchanged + `x-shared/` = 10 dirs.** Round 3 never stated this
and three passages disagreed: the headline said "collapse 19 into 3", Non-Goals kept 5, and S6 said
"retire the 19" — which read literally deleted the kept ones. Six skills had no disposition anywhere
(x-design, x-guide, x-mindful, x-review, x-upstream, and x-research beyond its doc paths), and
**x-upstream has zero inbound references**, so nothing would have broken loudly when S6 deleted it
by omission `[R4 §2]`. Reuse verdicts and the assets behind them are in `[R4 §4]`.

| Dir | Fate | Goes where |
|---|---|---|
| x-do | absorbed | x-implement (`01-slice`); bounded-escalation branch → `02-gates` |
| x-bugfix | absorbed + harvest | intake → `manifests/prod-bug.md`; 3-Strike/Instrumentation Pivot → `02-gates`; `backward-tracing.md` near-verbatim |
| x-verify | absorbed | `gates.sh` + `validate-emit.sh` — its model-asserted verdicts are what DEC-007 inverts |
| x-review | absorbed + harvest | `03-review`: Scope Contract, `scope-guard.md`, verify-each-finding pass |
| x-research | absorbed + harvest | MCP detection rows → `02-scout`; `synthesis-rules.md` → `templates/research.md` |
| x-backlog | absorbed | x-record — `references/template.md` CORE skeleton is the backlog template |
| x-mindful | absorbed + harvest | `extraction-prompts.md` → `01-questions`/`03-debate`; reversibility + severity rubric → `00-triage`. **Do not port the per-item walkthrough** |
| x-omo · x-gemini · x-team | **deleted** | harvest first: `prompt-blocks.md` → dispatch prompts; agy exit-0 semantics → `capability-loading.md`; `blocker-escalation.md` sanitizer → `emit-contract.md` (DEC-018) |
| x-worktree · x-worktree-isolate · x-qa · x-api-pentest · x-skill-improve · x-design · x-guide · x-upstream | **kept unchanged** | plus a mandatory scrub pass, below. x-design/x-guide/x-upstream added round 4 — orthogonal jobs with no successor in v3 |
| x-shared | rebuilt | see the outline; 14 files today, 8 survive |

**S6 is not only deletion — the kept skills are not clean, and Acceptance row 1 fails on day one
without this `[R4 §4]`.** x-qa carries 8 framework strings and routes to x-omo/x-gemini/x-team in
three places (Bootstrap step 2, two Capability Routing rows, Dependencies); x-api-pentest carries 2;
`instrument-and-verify.md`, which the outline marked *unchanged*, carries
`superpowers:test-driven-development` at line 77 plus two dead intra-repo paths — one 83-line file
failing both the dependency grep and `lint-chain.sh` simultaneously. x-guide routes to x-gemini and
x-research; x-skill-improve's `analysis-rubric.md` is keyed to the 19 v2 skill names. Three
carry-overs must survive the x-shared pruning or a kept skill breaks silently:
`severity-guide.md` (17 lines, consumed by x-api-pentest and x-skill-improve), the DOCKER CONTEXT
half of `context-envelope.md` (x-worktree), and `workflow-chains.md`'s Backlog Lifecycle line — the
**only** documented entry into x-worktree's doc-driven mode, which must move into x-worktree's own
`SKILL.md` before the file dies.

## Structure Outline

```
skills/
  x-consult/                        # NEW — only model-invoked skill
    SKILL.md                        # thin router: triage → questions → scout → debate → review → close
    phases/00-triage.md             # tier printed first, one-word override (DEC-002)
    phases/01-questions.md          # research questions: agent-authored, agent-answered (DEC-004)
    phases/02-scout.md              # intent-blind subagent; file:line facts only
    phases/03-debate.md             # question recipe (DEC-005) + slot sweep (DEC-003)
    phases/03b-review.md            # NEW — interview-review dispatch, union + dedupe (DEC-014)
    phases/04-close.md              # acceptance examples + exception sweep (DEC-006)
    manifests/{new-requirement,read-only-question,prod-bug}.md
  x-record/                         # NEW  (was x-backlog + x-research doc paths)
    SKILL.md
    templates/{research,backlog,plan}.md          # backlog carries Structure Outline section
    lint-plan.sh                    # rejects any phase naming no end-to-end validation (DEC-010)
  x-implement/                      # NEW  (was x-do + x-bugfix + x-verify)
    SKILL.md
    phases/{01-slice,02-gates,03-review,04-report}.md
    gates.sh                        # floor cascade + plan's verification list; cmd+exit; sha256
                                    #   acceptance freeze (DEC-006); stub scan (DEC-011); N/A rows;
                                    #   from x-qa/scripts/lib/verdict.sh (DEC-019)
    # run dir: .x-skills/run/<slug>/ — progress.md, metrics.md, dispatch/, attempt-1/ (Contracts)
  x-shared/                         # 14 files today -> 8; every one has a verdict (DEC-013)
    emit-contract.md                # NEW — DEC-007 + DEC-008 + DEC-018 (x-team sanitizer), one place
    validate-emit.sh                # NEW — schema-conditional required fields; pre-judging +
                                    #   hypothesis-marker lint over dispatch/; ledger line format
    lint-chain.sh                   # NEW — reachability, enumerated chain edges, live-ref budget,
                                    #   phase-file wc -l, bootstrap line total, one-level-deep refs
    capability-loading.md           # MODIFIED — drop plugin.omc/superpowers + dead consumer list;
                                    #   add ownCoverage + crossModelCli + agy exit-0 semantics
    mcp-toolbox.md                  # MODIFIED — home of DEC-013/016/017 contracts; rewrite every
                                    #   OMO/agy fallback cell (was absent from this outline)
    completion-cascade.md           # MODIFIED -> harvested into gates.sh, then DELETED
    done-format.md                  # MODIFIED — 3 rules survive, not 3 shapes: banner ban (:97),
                                    #   first-token discipline, safety-axis option rule
    invocation-guide.md             # MODIFIED — handoff/assign + collect-all-background only
                                    #   (~45 of 235 lines); ladder deleted -> CLAUDE.md needs a fix
    instrument-and-verify.md        # MODIFIED (not "unchanged") — 3 rules keep; strip the
                                    #   superpowers: string at :77 and 2 dead intra-repo paths
    severity-guide.md               # unchanged — reuse verbatim; 2 KEPT skills consume it
    README.md                       # MODIFIED — rewrite the index, keep the "why no SKILL.md" rule
    context-envelope.md             # SPLIT — DOCKER CONTEXT half -> x-worktree/references/; rest dies
    slot-schema.md  reactions-vocabulary.md   # DELETED -> lint-chain.sh bad-case fixtures
    common-gotchas.md  omo-routing.md  workflow-chains.md   # DELETED (carry 1 line to x-worktree)
  bin/setup  hooks/inject-capabilities.sh     # MODIFIED — ownCoverage + crossModelCli probe (S3)
  x-omo/ x-gemini/ x-team/          # DELETED as bootstrap deps (DEC-013), after harvest
  x-worktree/ x-worktree-isolate/ x-qa/ x-api-pentest/ x-skill-improve/ x-design/ x-guide/
  x-upstream/                       # KEPT — jobs v3 does not absorb; S6 scrub pass required
```

Slices in order. **No slice starts before its predecessor's checkpoint passes.**

| # | Slice | Verification checkpoint |
|---|---|---|
| S0 | `emit-contract.md` + `validate-emit.sh` | 3 good / 3 bad emits (missing status token, composed status, OBSERVED claim with no pointer) → correct verdict on all 6; `--selftest` hard-fails; wired to `npm run check` and a deliberately-broken run goes red (DEC-019) |
| S1 | x-consult Tier 0 ANSWER, end to end | Real read-only question about this repo → derived status, every claim pointered, terminates without offering implementation |
| S2 | x-consult Tier 2 + x-record backlog doc + DEC-014 review | Doc lands at immutable path with `DEC-`/`AC-` IDs, a Structure Outline section, an acceptance-examples block and a per-phase verification list; **overlap rate written to `metrics.md`** with `reviewer:` recorded; basic-memory write-time overlap lint rejects a >40-word restatement; validator passes |
| S3 | x-implement on that doc, serial slices + gitnexus lane | Every gate prints command + exit code; status derived; the **backlog doc's** verification list extends the floor cascade; sha256 freeze fires; N/A rows print their reason; stub scan labelled over 10 real diffs; gitnexus prints `commitsBehind` when stale and prints the skip when it withholds |
| S4 | prod-bug manifest + intent-blind scout | Every dispatch prompt lands in `dispatch/` **before** dispatch; the lint finds no pre-judging phrase and no hypothesis marker in the `02-scout` prompt; research doc is fact-only |
| S5 | Tier 3 full chain + plan doc + `lint-plan.sh` | A plan with a phase naming no end-to-end validation is rejected; one missing a per-phase success criterion, exact file paths or an out-of-scope statement is rejected; a fully-validated plan passes |
| S6 | Cutover — delete + harvest per the Disposition table, **scrub the 8 kept skills** | `git grep -l 'superpowers:\|oh-my-claudecode:' -- skills/ \| wc -l` → 0 **including x-qa and x-api-pentest**; `lint-chain.sh` green on the whole tree; bootstrap line count down ≥1,500; DEC-020 trigger eval passes at ≥0.5 |

## Scope & Non-Goals

**In scope:** the three skills, the shared emit contract + validator, the three doc templates, the
DEC-014 review dispatch, the DEC-015 capability-gated two-role cross-model path, the DEC-013
deletions, and retiring the 19 v2 skills.

**Non-goals:** `x-worktree`, `x-qa`, `x-api-pentest`, `x-worktree-isolate`, `x-skill-improve`,
and — added round 4, previously unstated anywhere — `x-design`, `x-guide`, `x-upstream`
(orthogonal, invoked by name; see the Disposition table). Cross-model as a **general** dispatch layer (DEC-015 permits exactly
two roles). Hook-based enforcement of consult-first. Parallel code mutation. Human stops at slice
boundaries (DEC-011, decided against). Any ML on the rework tally.

## Acceptance

- [ ] `git grep -l 'superpowers:\|oh-my-claudecode:' -- skills/ | wc -l` returns 0 across all
      shipped skills — **including the kept ones**: x-qa (`SKILL.md`, `explorer-prompts.md`,
      `case-runner-prompts.md`), x-api-pentest (`SKILL.md`, `step-06-report.md`) and
      `x-shared/instrument-and-verify.md` all carry strings today. Two round-4 corrections:
      `grep -rc` prints a `path:count` line per file and can never output a bare `0`, and a
      plain `grep -r` also matches untracked gitignored `.omc/state/*.jsonl` debris — so the
      assertion must be tracking-aware.
- [ ] x-consult works from a bare invocation with **no magic phrase**, and prints its tier first.
- [ ] Tier 0 terminates without offering x-record or x-implement.
- [ ] x-record refuses to write when the consult artifact is absent or has an open REQUIRED slot.
- [ ] `validate-emit.sh` rejects: missing status token, model-composed status, an OBSERVED claim
      with no pointer, numeric confidence, a banned label heading, a progress banner, and a
      question that names no reading it eliminates.
- [ ] `lint-plan.sh` rejects a plan containing a phase that names no validation exercising the
      slice end to end.
- [ ] Every gate in x-implement prints command + exit code; status is derived, never asserted; the
      plan's own verification entries run alongside the floor cascade.
- [ ] The DEC-014 review dispatch's **overlap rate** with the primary agent's questions is logged
      from S2 — the falsifier for the monomethod risk.
- [ ] DEC-015's two roles degrade to same-model with `reviewer: same-model` recorded on the overlap
      row — silent in the human channel only, never in the machine channel (DEC-015, round 4).
- [ ] The cross-model lane re-derives a real exit code (empty stdout + log tail) instead of trusting
      `agy`'s exit 0, and serializes its calls — otherwise an auth failure logs as 0% overlap.
- [ ] DEC-020: x-consult's description passes a should/should-not-trigger eval at ≥0.5, and every
      other shipped skill declares `disable-model-invocation: true`.
- [ ] Reference files are one level deep from each `SKILL.md`, and every phase-file pointer states
      **when** to load it (`lint-chain.sh`).
- [ ] No doc path changes on completion; no inbound link breaks at `status: done`.
- [ ] Bootstrap-path line count drops by ≥1,500 vs v2, **measured on every release, not once**.
- [ ] `lint-chain.sh` rejects: a router naming a missing file, a `phases/` file no router names, and
      a phase file naming a skill more than one hop downstream.
- [ ] DEC-019: every gate script is **wired to `npm run check`** in the slice that creates it, ships
      good/bad fixture pairs and a `--selftest` that hard-fails, and each slice's checkpoint
      includes one deliberately-broken run that must go red.
- [ ] `.x-skills/run/<slug>/metrics.md` exists from S2 and carries the overlap row, the
      gitnexus-vs-`Grep` row, and the rework pointer — the three instruments that had no writer.
- [ ] x-record prints the derived project slug and hard-fails on a slug containing a dot (DEC-016).
- [ ] gitnexus lane prints `commitsBehind` when stale and prints the skip when it withholds the
      correctness-sensitive class; never silent either way (DEC-017).
- [ ] One full Tier 3 cycle completes on a real feature — **which has never happened in v2**.
      Human-observed; no instrument in the surveyed corpus can automate this row.

## Handoff Notes / Open Questions

- **Assumed — the manifest buys robustness, not accuracy.** The one A/B says a scaffold beats an
  *unscaffolded* agent (69.40% vs 61.20%) but **ties a well-prompted one (70.40%)** at double the
  cost; its clear win is on instruction-fragile backbones `[FOUND §5]`. Falsifier: the rework tally.
- **Assumed — DEC-014's port from humans to one base model holds.** The measured effect came from
  perception differences between *people*. Falsifier: overlap rate persistently above ~26%.
- **Assumed — the exception sweep works on a just-scouted codebase.** Alexander's 3.17× came from
  experienced engineers with operational intuition. Falsifier: ratio of exception probes ruled in
  scope vs dismissed. Also: DEC-006's sweep and DEC-014 hunt the same omission class and may
  overlap more than their individual effect sizes suggest.
- **Accepted risk — no human reads the diff (DEC-011).** Success metric now rests entirely on the
  upstream artifacts. Falsifier: rework attributable to code the human never read.
- **Open:** DEC-003 gates artifact-internal completeness only. Nothing in this design closes
  "the requirement nobody thought of" when it lives outside both your words and the codebase —
  and three inspection studies say a topic checklist does not close it either. Stated, not solved.
- **Gotcha:** nothing stops a user who never invokes x-consult. Accepted, not solved.
- **Resolved 2026-07-28 — the doc-length gotcha.** The question was "is the cap wrong or has this
  stopped being a review surface"; the corpus answered a better one: an unenforced cap holds when it
  is generous *and names a destination*, fails when it is tight and names none `[OSS §5]`. Both
  halves are now fixed in DEC-009 — the budget is **per phase file**, this doc's destination is
  `docs/research/`, and the number is asserted by `wc -l` or deleted. This doc stays long because it
  is a decision record with 18 blocks; the phase files are what must stay small.
- **Read before S3:** HumanLayer's `rpi` plugin v0.18.1 (16 skills) — **not** the pre-QRSPI
  `create_plan.md` set, which prescribes the exact horizontal ordering DEC-010 bans `[FOUND §6]`.
  Cite behaviour; do not vendor text (All Rights Reserved). The `implementer-agent` prompt — the
  closest prior art to x-implement's slice executor — is unpublished and remains unavailable.
  **Now partly superseded:** `[OSS §7]` names six readable files covering the same ground, including
  the constrained-repair and instrument-selftest prior art, with no licensing constraint.
- **Assumed — gitnexus earns its place.** Measured own-coverage is 1.4% and 7 of 8 repos are stale,
  so both lanes are near-dead exactly where DEC-017 gates them in. Falsifier: 10 x-implement slices
  in a real code repo with zero `impact` calls that beat `Grep` → cut it to a human-invoked tool.
- **Assumed — the basic-memory durability gate binds.** It is already being ignored in the live
  store (a green-run note the contract bans; ~18 session notes). DEC-016 replaces model discretion
  with a derived precondition. Falsifier: >1 non-durable note in 6 across S1–S6.
- **Resolved 2026-07-28 — recall placement.** Round 3 logged this as open pending a falsifier;
  round 4 found DEC-004's evidence contradicts the old placement outright, so recall **moved to
  `03-debate`, after the scout**. No experiment was needed to decide a question the cited evidence
  already answered `[R4 §2]`.
- **Gotcha — `CLAUDE.md` contradicts DEC-017, and it is now blocking.** Its "MUST run impact
  analysis before editing any symbol" is unsatisfiable on this repo (1.4% own coverage, 0 own
  processes, 0 of 113 `.sh` files indexed — all re-verified round 4). A mandatory gate that cannot
  be satisfied trains itself as ignorable. **Fix before S0**, since S0 edits code.
- **Gotcha — the installed capability manifest is one version stale.** `~/.config/x-skills/
  capabilities.json` reports `plugin_version 2.3.0` against the repo's 2.4.0, and it is what gates
  both kept dependencies. Re-run `/x-skills:setup` before trusting a capability-gated path `[R4 §1]`.
- **Open — DEC-015 has no read-only flag.** Neither `agy` nor `bin/agy-agent` documents one, so the
  DEC-018 requirement that the cross-model CLI run read-only currently has no implementation. Verify
  before S2 or weaken it to a tool-allowlist constraint `[R4 §4]`.
- **Open — DEC-020's trigger eval has no harness.** Official guidance supplies the protocol
  (~20 prompts per side, ~3 runs, 0.5 threshold) and `skill-creator` automates it, but v3 ships no
  implementation. It is the one instrument round 4 added that is unbuilt `[R4 §6]`.
- **Not verifiable, stated so it is not mistaken for evidence `[R4 §6]`.** No controlled study
  isolates spec-driven from plan-free agent workflows (the critique corpus is retrospectives plus
  one adjacent RCT); no end-to-end A/B exists for a coding agent with vs without a cross-session
  memory store, so DEC-016's magnitude is extrapolated; and the checkpointed-vs-autonomous question
  (DEC-011) has no RCT — it rests on field telemetry and split prior art.
