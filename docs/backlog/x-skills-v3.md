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

## Context & Problem

Three things are wrong with v2, in order of cost.

**1. Skills document each other's internals.** 19 skills means up to ~342 possible directed
handoff edges, and v2 pays that in prose: `x-backlog/SKILL.md:136-157` spends ~40 lines on git
states inside x-worktree. Dropping the two frameworks is a 101-call-site mechanical change; the
coupling is the real cost.

**2. The output contract does not self-enforce.** `done-format.md:98` bans progress banners;
13 step files open with one. ~1,700 lines of x-shared and bridge skills are read at bootstrap
and cannot be acted on.

**3. Nothing closes the human/agent context gap.** No skill asks the questions that would. The
agent's model of the system is never stated back for correction, so misunderstandings surface
at code review — the most expensive possible time to change your mind.

Success metric is **"my mental model matches the code,"** not "correct output" `[FOUND §2.3]`.
Why this is permanent rather than a stopgap: coding models are RL-trained on binary test-pass
rewards with no penalty for eroding maintainability, and bad architecture's cost arrives in weeks,
where no reward signal reaches `[FOUND §2.1]`.

## Key Decisions

### DEC-001 — Three skills, dependency-free
- **Choice:** `x-consult` (align) → `x-record` (persist) → `x-implement` (build). Nothing outside
  this repo at runtime, except the capability-gated optional dispatch in DEC-015.
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
- **Consequences:** Top-of-skill conditional on an observable predicate. **M16's exemption-clause
  ban is narrowed to DISCIPLINE gates** — it is about not-skipping-the-gate rules; per-phase
  skipping at the tier-*selection* step is legitimate and is what the reference implementation
  does. Carry the non-monotone caveat: fewer reasoning tokens also raise behavioural overthinking,
  so the curve has a real minimum — this is not "less is always better."
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
- **Consequences:** The **rework tally is promoted from schema-only to load-bearing** — it is the
  only falsifier this design has.
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
  cleanly `[FOUND §5]`. Treat as a house convention.
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
- **Status:** accepted

### DEC-009 — Three docs, immutable paths, stable IDs, document precedence
- **Choice:** `docs/research/` (facts, intent-blind, spot-checked) · `docs/backlog/<slug>.md`
  (decisions + contracts + **Structure Outline** section; read fully; ~200-line target) ·
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
  CooperBench degraded monotonically on file-overlapping-but-non-adversarial tasks; there is no
  configuration with published support.
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
  failures on the same task = stop and escalate. **No human stop at slice boundaries.**
- **Why:** End-of-run verification arrives after the failure has locked in `[FOUND M11]`. A fixed
  cascade alone cannot express per-feature probes (curl, sql queries) or manual validation, which
  is why the plan's own verification list extends it — otherwise DEC-006's oracle and this cascade
  have no interface. Deterministic condensation beats an LLM summarization pass at lower cost, and
  summarization *lengthens* trajectories ~15% by obscuring failure signals `[FOUND M14]`.
- **Oracle rule:** ~~only greenfield mandates test-first order~~ → **"the oracle must not have seen
  the implementation," plus "small uniform cycles."** The human ordering literature is null —
  granularity and uniformity predict quality, not sequencing — while the LLM
  context-contamination evidence is strong `[FOUND M7]`.
- **Alternatives — and this is a deliberate, user-made call against the evidence.** The reference
  implementation gates on **human confirmation at every phase boundary** ("Wait for the human to:
  Confirm manual checks passed / Report any issues found / Give permission to continue"), and the
  author's 2026 retraction is explicit: *"don't read the plans. Please, read the code"; "You should
  not outsource the thinking. Read and own the code"* `[FOUND §2]`. **Rejected by the user on
  2026-07-28** in favour of full autonomy: attention is spent entirely upstream, per the leverage
  gradient (a bad line of research costs thousands of lines of code).
- **Consequences — residual risk, accepted knowingly:** the design's success metric is "my mental
  model matches the code," and it is now carried **entirely by the upstream artifacts** (backlog
  doc + structure outline + acceptance examples). Acceptance criterion S3 can pass with no human
  having read a line of the diff. **Falsifier:** rework attributable to code the human never read.
  If that shows up in the tally, the per-slice stop is the first thing to reconsider.
- **"Two failures = stop" is a house threshold.** Evidence brackets rather than fixes it — most
  achievable repair gains land inside the first three to four iterations, while the counter-argument
  says budget is better spent on fresh samples.
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
- **Consequences:** Ordering enforced structurally — x-record refuses to write until the consult
  artifact exists on disk with its open-required-slots row resolved. Nothing stops a user who never
  invokes x-consult; accepted rather than papered over with a hook dependency we just removed.
- **Status:** accepted

### DEC-013 — Delete, don't port
- **Choice:** Drop `slot-schema.md` + slot resolution, `reactions-vocabulary.md`, the 9-layer
  *instruction*-precedence ladder, the `send_message` section, the letter-namespace map,
  `x-omo`/`x-gemini` as bootstrap deps, `x-team`, and the GitNexus freshness contract. Keep
  `capability-loading.md` and the SessionStart hook nearly verbatim, minus `plugin.omc` and
  `plugin.superpowers`.
- **Why:** ~1,700 lines the model reads at bootstrap and cannot act on `[FOUND §4]`.
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
- **Consequences:** The two roles must degrade cleanly to same-model, so neither may *depend* on
  cross-model being present. This is the one place v3 reaches outside itself, and it is optional
  by construction.
- **Status:** accepted

## Contracts

```
TerminalEmit                        # first token, derived — never model-composed
  status   : DONE | BLOCKED | NEEDS-INPUT | FAILED-GATE
  source   : gateExitCodes[] | openRequiredSlots:int | filesWritten[]
  nextStep : string                 # literal copy-pasteable prompt naming the next skill + path

Claim
  grade   : OBSERVED | INFERRED | ASSUMED
  pointer : file:line | command+output | commit-sha | doc-anchor | user-utterance-span

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

ConsultArtifact → x-record          # the gate x-record checks on disk
  tier         : 0 | 1 | 2 | 3
  slots        : SlotRow[]          # zero open REQUIRED rows to pass
  examples     : (input → expectedOutput)[]        # becomes the frozen oracle
  terminalState: answered | research | backlog | plan | handoff
  nextStep     : string
```

Manifests are per situation, cheapest disqualifier first: **new-requirement** (user + trigger,
current behavior, desired behavior, boundary/contract, non-goals, acceptance examples) ·
**read-only-question** (the question asked, who is asking and what decision it feeds, claim +
probe) · **prod-bug** (expected behavior *first*, error evidence, repro, blast radius, when it
started).

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
    gates.sh                        # floor cascade + plan's own verification list; prints cmd+exit
  x-shared/
    emit-contract.md                # NEW — DEC-007 + DEC-008, one place
    validate-emit.sh                # NEW — mechanical enforcement
    capability-loading.md           # MODIFIED — drop plugin.omc/superpowers; carries DEC-015 gate
    done-format.md                  # MODIFIED — keep shapes 1-3, cut letter-namespace map
    invocation-guide.md             # MODIFIED — keep handoff/assign only
    instrument-and-verify.md        # unchanged — already DEC-008
    slot-schema.md                  # DELETED          reactions-vocabulary.md   # DELETED
  x-omo/ x-gemini/ x-team/          # DELETED as bootstrap deps (DEC-013)
  x-worktree/ x-qa/ x-api-pentest/  # unchanged — invoked by name, never cross-referenced
```

Slices in order. **No slice starts before its predecessor's checkpoint passes.**

| # | Slice | Verification checkpoint |
|---|---|---|
| S0 | `emit-contract.md` + `validate-emit.sh` | 3 good / 3 bad emits (missing status token, composed status, OBSERVED claim with no pointer) → correct verdict on all 6 |
| S1 | x-consult Tier 0 ANSWER, end to end | Real read-only question about this repo → derived status, every claim pointered, terminates without offering implementation |
| S2 | x-consult Tier 2 + x-record backlog doc + DEC-014 review | Doc lands at immutable path with `DEC-`/`AC-` IDs and a Structure Outline section; **review overlap rate logged**; validator passes |
| S3 | x-implement on that doc, serial slices | Every gate prints command + exit code; status derived; plan's own verification list extends the floor cascade |
| S4 | prod-bug manifest + intent-blind scout | Scout prompt provably contains no hypothesis and no task-nature statement; research doc is fact-only |
| S5 | Tier 3 full chain + plan doc + `lint-plan.sh` | A plan with a phase naming no end-to-end validation is rejected; a fully-validated plan passes |
| S6 | Cutover — delete per DEC-013, retire the 19 | `grep -rc 'superpowers:\|oh-my-claudecode:' skills/` → 0; bootstrap line count down ~1,700 |

## Scope & Non-Goals

**In scope:** the three skills, the shared emit contract + validator, the three doc templates, the
DEC-014 review dispatch, the DEC-015 capability-gated two-role cross-model path, the DEC-013
deletions, and retiring the 19 v2 skills.

**Non-goals:** `x-worktree`, `x-qa`, `x-api-pentest`, `x-worktree-isolate`, `x-skill-improve`
(orthogonal, invoked by name). Cross-model as a **general** dispatch layer (DEC-015 permits exactly
two roles). Hook-based enforcement of consult-first. Parallel code mutation. Human stops at slice
boundaries (DEC-011, decided against). Any ML on the rework tally.

## Acceptance

- [ ] `grep -rc 'superpowers:\|oh-my-claudecode:' skills/` returns 0 across all shipped skills.
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
- [ ] DEC-015's two roles degrade silently to same-model when no cross-model CLI is present.
- [ ] No doc path changes on completion; no inbound link breaks at `status: done`.
- [ ] Bootstrap-path line count drops by ≥1,500 vs v2.
- [ ] One full Tier 3 cycle completes on a real feature — **which has never happened in v2**.

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
- **Gotcha — this doc is 527 lines against its own DEC-009 target of ~200, and the gap widened
  from 337 after one audit round.** "Three skills, so the cap is per unit of work" no longer
  explains a 2.6× overrun. Two real readings: the cap is wrong for decision-dense docs, or a doc
  that absorbs its own research audit has stopped being the human review surface DEC-009 says it
  is. **Falsifier: whether you actually read this one end to end.** If you skimmed it, the cap is
  right and the citations belong in `[FOUND]` refs only. Settle before S2 renders the template.
- **Read before S3:** HumanLayer's `rpi` plugin v0.18.1 (16 skills) — **not** the pre-QRSPI
  `create_plan.md` set, which prescribes the exact horizontal ordering DEC-010 bans `[FOUND §6]`.
  Cite behaviour; do not vendor text (All Rights Reserved). The `implementer-agent` prompt — the
  closest prior art to x-implement's slice executor — is unpublished and remains unavailable.
