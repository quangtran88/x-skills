---
title: x-skills v3 — consult / record / implement
slug: x-skills-v3
type: refactor
status: ready
created: 2026-07-27
updated: 2026-07-27
related: [x-skills-v3-foundations]
---

# x-skills v3 — consult / record / implement

Collapse 19 interdependent skills into 3, with zero runtime dependency on `obra/superpowers`
or `yeachan-heo/oh-my-claudecode`. **This doc is the human review surface. Read it end to end.**
Facts and citations live in `../research/2026-07-27-x-skills-v3-foundations.md` (`[FOUND]` below).

## Context & Problem

Three things are wrong with v2, in order of cost.

**1. Skills document each other's internals.** 19 skills means up to ~342 possible directed
handoff edges, and v2 pays that in prose: `x-backlog/SKILL.md:136-157` spends ~40 lines on git
states inside x-worktree. Dropping the two frameworks is a 101-call-site mechanical change; the
coupling is the real cost, and 3 skills reduce it to 6 edges.

**2. The output contract does not self-enforce.** `done-format.md:98` bans progress banners;
13 step files open with one. ~1,700 lines of x-shared and bridge skills are read at bootstrap
and cannot be acted on — slots with no consumer, a `send_message` primitive documented as
"dropped from the vocabulary," a precedence ladder that admits it has no enforcement.

**3. Nothing closes the human/agent context gap.** No skill asks the questions that would. The
agent's own model of the system is never stated back for correction, so misunderstandings surface
at code review — the most expensive possible time to change your mind.

Success metric is **"my mental model matches the code,"** not "correct output" `[FOUND §2.3]`.
The reason this is permanent rather than a stopgap: coding models are RL-trained on binary
test-pass rewards with no penalty for eroding maintainability, and bad architecture's cost
arrives in weeks, where no reward signal reaches `[FOUND §2.1]`.

## Key Decisions

### DEC-001 — Three skills, dependency-free
- **Choice:** `x-consult` (align) → `x-record` (persist) → `x-implement` (build). Nothing outside
  this repo at runtime. Reference frameworks stay vendored under `research/` as reading material.
- **Why:** Coupling, not dependency count, is the cost driver.
- **Alternatives:** Trim 19 → ~8. Rejected: leaves the O(n²) documentation tax intact.
- **Consequences:** Orthogonal infrastructure (`x-worktree`, `x-qa`, `x-api-pentest`) survives
  untouched and is invoked by name, never referenced from inside the three.
- **Status:** accepted

### DEC-002 — Entry mandatory, depth triaged
- **Choice:** x-consult always enters. Its **first printed line is the tier**, overridable in one
  word. Predicate: *"would an agent misunderstanding my intent be expensive here?"*, with an
  observable tiebreaker when ambiguous (>1 file or >1 call site). Tier 0 ANSWER (read-only, no
  docs) · Tier 1 one-shot (no doc) · Tier 2 design doc only · Tier 3 full chain.
- **Why:** ~40% of tasks should be one-shot; unconditional ceremony is the documented reason both
  dropped frameworks got routed around `[FOUND §2.4, M9]`.
- **Alternatives:** Mandatory full depth (the original brief) — rejected, it is the failure mode
  that disables everything else. Purely mechanical predicate — rejected as over-ceremonying a
  one-line change in a hot function.
- **Consequences:** Must be a top-of-skill conditional on an observable predicate, **not an
  exemption clause** — exemption clauses provably do not scope `[FOUND M16]`.
- **Status:** accepted

### DEC-003 — Sufficiency is arithmetic, not introspection
- **Choice:** A hard-coded required-slot manifest per situation. One verdict per row:
  `RESOLVED` (+pointer) · `ASSUMED` (+the falsifier that would break it) · `DEFERRED` (+what
  breaks if wrong). Exit gate = zero open REQUIRED rows. ASSUMED/DEFERRED print every time.
- **Why:** The strongest convergence in the corpus — the agent cannot self-detect
  underspecification, and reasoning-tuning makes abstention worse `[FOUND M2]`. Converts an
  unanswerable question into "is anything on this list unacceptable?"
- **Alternatives:** Agent self-reflection ("do I have questions?") — near chance. A printed
  Ask-F1 score — rejected: blocker *recall* requires knowing the blockers, which is the very
  blind spot; it would be a fabricated number with a decimal point.
- **Consequences:** Completeness is only defined relative to a declared frame. The manifest must
  ship inline in the skill body, not be recalled by the model. Slot gameability is untested
  `[FOUND §5]`.
- **Status:** accepted

### DEC-004 — Questions before research; scout is intent-blind
- **Choice:** The agent writes its technical inquiries first; those steer the scout. Scouting runs
  in a subagent that **never receives the feature request or any hypothesis** and returns only
  verifiable file:line facts. No question may be emitted before scouting is recorded, and every
  question must cite the file/symbol it already checked.
- **Why:** Explore-before-ask buys equal information for ~50% fewer questions `[FOUND M3]`.
  Intent in the research prompt produces a narrative that pre-justifies the change — the
  documented failure is an agent concluding a real bug was invalid `[FOUND §2]`.
- **Alternatives:** Scout first, then ask whatever is left. Rejected: questions written before
  research are what force the scout to touch every relevant part of the codebase.
- **Consequences:** Highest value in situation (c), where a leading hypothesis produces a
  confidently wrong root cause. Costs one extra dispatch.
- **Status:** accepted

### DEC-005 — Fixed question recipe, recommendation attached
- **Choice:** Three slots — **EVIDENCE** (pointer that raised it) / **QUESTION** (exactly one
  decision, options A/B/C) / **MY ANSWER** (recommendation + cost of being wrong). Silence =
  accept. Budget 3–5, hard cap 7. Batch fact-gathering; serialize decision gates where each
  ruling changes the next question. Withhold the recommendation for at most **one** irreversible
  decision per round.
- **Why:** Recognition beats recall; enumerated options are what three independent
  implementations converged on `[FOUND M4]`. This *is* the altitude control: supplied evidence
  keeps a question from being too technical, a forced single decision keeps it from being too
  general `[FOUND M15]`.
- **Alternatives:** Withhold all recommendations (avoids anchoring, measurably less pleasant);
  ship all (anchors). One-per-round is the compromise.
- **Consequences:** Batched-vs-serial has never been A/B'd with humans and a vendored skill says
  the opposite — this is a house convention, not a finding `[FOUND §5]`.
- **Status:** accepted

### DEC-006 — Close with examples that become the frozen oracle
- **Choice:** End the interview with concrete acceptance examples (input → expected output); for
  Tier 0, claim → the probe command that proves it; for a bug, the failing reproduction. The
  human signs off by **disputing an example**, not approving prose. Those examples become
  x-implement's acceptance oracle, frozen and read-only to the implementer.
- **Why:** Concrete tests are what let humans catch bad AI output; humans reading AI prose
  over-trust it `[FOUND M4]`. Oracle independence is the active ingredient, not test-writing
  ritual `[FOUND M7]`.
- **Alternatives:** Prose teach-back — no published support in agent settings; treat as folklore.
- **Consequences:** This is the only linkage making the three skills one chain rather than three
  docs. Probe scripts are throwaway: quote the output, delete the script.
- **Status:** accepted

### DEC-007 — Derived status enum + mechanical emit validator
- **Choice:** First token of every terminal emit is one of `DONE` / `BLOCKED` / `NEEDS-INPUT` /
  `FAILED-GATE`, **computed from machine state** — x-implement from captured gate exit codes,
  x-consult from open-required-slot count, x-record from files-written-and-linked. Never composed
  by the model, no invented middle states. A script validates every emit.
- **Why:** False success is the largest measured reliability hazard and LLM judges cannot detect
  it `[FOUND M1]`. v2 proves prose contracts do not self-enforce (13 banner violations).
- **Alternatives:** Prose instruction to be honest about status. That is what v2 has.
- **Consequences:** ~10 lines of contract plus one validator script. Guidance form must match
  failure type: shape → positive recipe, discipline → prohibition + rationalization table.
- **Status:** accepted

### DEC-008 — Pointer-or-delete; three evidence grades
- **Choice:** Every claim carries a resolvable pointer (file:line, pasteable command + captured
  output, commit sha, doc anchor). Prose rationale is **deleted** wherever a pointer exists.
  Numeric confidence banned; grades are `OBSERVED` / `INFERRED` / `ASSUMED`, and the grade selects
  sentence form (bare assertion for OBSERVED; explicit uncertainty for the other two).
- **Why:** Explanations raise human acceptance of *wrong* answers; sources lower it. Verbalized
  LLM confidence is badly calibrated `[FOUND M6]`.
- **Alternatives:** Percentage confidence — unusable. Already specified in v2's
  `instrument-and-verify.md` rule 3, so this is promotion, not invention.
- **Status:** accepted

### DEC-009 — Three docs, immutable paths, stable IDs
- **Choice:** `docs/research/` (facts, intent-blind, spot-checked) · `docs/backlog/<slug>.md`
  (decisions + contracts + **Structure Outline** section; read fully; ~200-line target) ·
  `docs/plan/` (per-task detail; **machine-facing, not a human review surface**). Paths are
  immutable — `status: done` changes frontmatter only and the index moves the row between Active
  and Shipped tables. Decisions are append-only `DEC-00n` blocks with four Nygard fields plus a
  status line; reversal appends a new block and edits only the old status line. Links anchor on
  IDs (`#dec-003`), never heading prose. No `docs/adr/`.
- **Why:** v2's archival `git mv` out of `docs/backlog/` invalidates every inbound link and has
  already fired once. Nygard's four fields beat richer templates; standalone ADR dirs get
  abandoned `[FOUND M13]`. Reviewing long plans is illusory leverage `[FOUND §2]`.
- **Alternatives:** Structure outline as a 4th doc type or as the plan's head section — rejected;
  "a new file requires a new reader with a different question," and the plan is not a read surface.
- **Consequences:** Existing `docs/plans/` (plural) must be settled before anything writes links.
  Forbid code blocks longer than a signature — cite `path:symbol`.
- **Status:** accepted

### DEC-010 — Serial vertical slices; subagents for context isolation only
- **Choice:** Unit of work is a vertical slice with a named verification command and a real
  checkpoint; stop at each boundary, report diff size, refuse to pass ~200 lines without a
  checkpoint. x-record **mechanically rejects** a stack-ordered plan (migrations → services → API
  → frontend). Subagents are for scouting, review and probes — never concurrent mutation.
- **Why:** No published win for parallel code mutation; agents coordinate poorly at ~15× tokens.
  Horizontal plans leave nothing testable until ~1200 lines in, and models will not fix this
  unsteered `[FOUND M12, §5]`.
- **Alternatives:** Waves with proven file-disjointness — available per-plan, but instrumented;
  the plan must record predicted touched-files anyway as the anti-gaming check.
- **Status:** accepted

### DEC-011 — Per-task gate cascade, cheapest first
- **Choice:** syntax → typecheck → lint → this task's test → full suite → build → smoke. Fail
  fast, skip downstream. **Print command + exit code + diff stat for every gate.** Condense gate
  output before it enters context (first N failures, deduplicated, file:line only). Two failures
  on the same task = stop and escalate; do not keep repairing.
- **Why:** End-of-run verification arrives after the failure has locked in `[FOUND M11]`.
  Unsummarized iterative tool output measured *worse* than removing the tool `[FOUND M14]`.
- **Consequences:** Where an independent suite already exists (prod bugfix), require a failing
  reproduction then use the existing suite as the regression gate — do **not** commission a new
  suite. Only greenfield mandates test-first order `[FOUND M7]`.
- **Status:** accepted

### DEC-012 — Thin router + phase files; one model-invoked skill
- **Choice:** Each skill is a thin router plus small phase files loaded on demand. **x-consult is
  the only model-invoked skill**, with a trigger-only description; x-record and x-implement are
  reachable by name or by consult handoff, so their descriptions cost nothing per turn. Every
  judging pass is a separate dispatch that cannot see the authoring context. Section headings are
  claim sentences; the label vocabulary (Summary / Analysis / Overview / Findings / Details /
  Notes / Conclusion) is banned; no progress banners.
- **Why:** A workflow-summarizing description makes agents follow the description instead of the
  skill `[FOUND M14]`. No component may approve its own output `[FOUND M8]`.
- **Consequences:** Ordering is enforced structurally — **x-record refuses to write until the
  consult artifact exists on disk with its open-required-slots row resolved.** This does not stop
  a user who never invokes x-consult; that gap is accepted rather than papered over with a hook
  dependency we just removed `[FOUND §5]`.
- **Status:** accepted

### DEC-013 — Delete, don't port
- **Choice:** Drop `slot-schema.md` + slot resolution, `reactions-vocabulary.md`, the 9-layer
  precedence ladder, the `send_message` section, the letter-namespace map, `x-omo`/`x-gemini` as
  bootstrap deps, `x-team`, and the GitNexus freshness contract. Keep `capability-loading.md` and
  the SessionStart hook nearly verbatim, minus `plugin.omc` and `plugin.superpowers`.
- **Why:** ~1,700 lines the model must read at bootstrap and cannot act on — the direct opposite
  of the high-signal requirement, and the cheapest available win `[FOUND §4]`.
- **Status:** accepted

## Contracts

```
TerminalEmit                        # first token, derived — never model-composed
  status : DONE | BLOCKED | NEEDS-INPUT | FAILED-GATE
  source : gateExitCodes[] | openRequiredSlots:int | filesWritten[]

Claim                               # every user-facing assertion
  grade   : OBSERVED | INFERRED | ASSUMED
  pointer : file:line | command+output | commit-sha | doc-anchor   # required for OBSERVED

SlotRow                             # the sufficiency manifest
  name     : string
  required : bool
  verdict  : RESOLVED{pointer} | ASSUMED{falsifier} | DEFERRED{breaksIf}

Question                            # exactly one decision each
  evidence   : pointer               # what the scout checked and failed to resolve
  question   : string + options[A|B|C]
  myAnswer   : recommendation + costOfBeingWrong   # withheld for ≤1 per round

ConsultArtifact → x-record          # the gate x-record checks on disk
  tier         : 0 | 1 | 2 | 3
  slots        : SlotRow[]           # zero open REQUIRED rows to pass
  examples     : (input → expectedOutput)[]        # becomes the frozen oracle
  terminalState: answered | research | backlog | plan | handoff
```

Required-slot manifests are per situation, ordered so the cheapest disqualifier comes first:
**new-requirement** (user + trigger, current behavior, desired behavior, boundary/contract,
non-goals, acceptance examples) · **read-only-question** (the actual question asked, who is
asking and what decision it feeds, claim + probe) · **prod-bug** (expected behavior *first*,
error evidence, repro, blast radius, when it started).

## Structure Outline

```
skills/
  x-consult/                        # NEW — only model-invoked skill
    SKILL.md                        # thin router: triage → questions → scout → debate → close
    phases/00-triage.md             # tier decision, printed first, one-word override
    phases/01-questions.md          # inquiries written BEFORE the scout (DEC-004)
    phases/02-scout.md              # intent-blind subagent prompt; returns file:line facts only
    phases/03-debate.md             # question recipe (DEC-005) + slot sweep (DEC-003)
    phases/04-close.md              # acceptance examples → frozen oracle (DEC-006)
    manifests/{new-requirement,read-only-question,prod-bug}.md
  x-record/                         # NEW  (was x-backlog + x-research doc paths)
    SKILL.md
    templates/{research,backlog,plan}.md          # backlog carries Structure Outline section
    lint-plan.sh                    # rejects stack-ordered phases (DEC-010)
  x-implement/                      # NEW  (was x-do + x-bugfix + x-verify)
    SKILL.md
    phases/{01-slice,02-gates,03-review,04-report}.md
    gates.sh                        # cascade; prints command + exit code + diff stat
  x-shared/
    emit-contract.md                # NEW — DEC-007 + DEC-008, one place
    validate-emit.sh                # NEW — mechanical enforcement
    capability-loading.md           # MODIFIED — drop plugin.omc, plugin.superpowers
    done-format.md                  # MODIFIED — keep shapes 1-3, cut letter-namespace map
    invocation-guide.md             # MODIFIED — keep handoff/assign only
    instrument-and-verify.md        # unchanged — already DEC-008
    slot-schema.md                  # DELETED          reactions-vocabulary.md   # DELETED
  x-omo/ x-gemini/ x-team/          # DELETED as bootstrap deps (DEC-013)
  x-worktree/ x-qa/ x-api-pentest/  # unchanged — invoked by name, never cross-referenced
```

Slices, in order. Each is independently verifiable; **no slice starts before its predecessor's
checkpoint passes.**

| # | Slice | Verification checkpoint |
|---|---|---|
| S0 | `emit-contract.md` + `validate-emit.sh` | Feed it 3 good and 3 bad emits (missing status token, composed status, OBSERVED claim with no pointer) → correct verdict on all 6 |
| S1 | x-consult Tier 0 ANSWER, end to end | Ask a real read-only question about this repo → emit carries derived status, every claim has a pointer, terminates without offering implementation |
| S2 | x-consult Tier 2 + x-record backlog doc | Run on one small real feature → doc lands at immutable path with `DEC-`/`AC-` IDs and a Structure Outline section; validator passes |
| S3 | x-implement on that doc, serial slices | Implement it → every gate prints command + exit code; status derived from exit codes; stops at ~200 lines |
| S4 | prod-bug manifest + intent-blind scout | Real bug → scout subagent prompt provably contains no hypothesis; research doc is fact-only |
| S5 | Tier 3 full chain + plan doc + `lint-plan.sh` | A stack-ordered plan is rejected; a vertical-slice plan passes |
| S6 | Cutover — delete per DEC-013, retire the 19 | `grep -rc 'superpowers:\|oh-my-claudecode:' skills/` → 0; bootstrap line count down ~1,700 |

## Scope & Non-Goals

**In scope:** the three skills, the shared emit contract + validator, the three doc templates,
the DEC-013 deletions, and retiring the 19 v2 skills.

**Non-goals:** `x-worktree`, `x-qa`, `x-api-pentest`, `x-worktree-isolate`, `x-skill-improve`
(orthogonal infrastructure, invoked by name — untouched). Cross-model dispatch (dies with x-omo;
revisit only if same-model sufficiency auditing proves to reproduce the author's blind spot).
Hook-based enforcement of consult-first. Parallel code mutation. Any ML on the rework tally.

## Acceptance

- [ ] `grep -rc 'superpowers:\|oh-my-claudecode:' skills/` returns 0 across all shipped skills.
- [ ] x-consult works from a bare invocation with **no magic phrase**, and prints its tier first.
- [ ] Tier 0 terminates without offering x-record or x-implement.
- [ ] x-record refuses to write when the consult artifact is absent or has an open REQUIRED slot.
- [ ] `validate-emit.sh` rejects: missing status token, model-composed status, an OBSERVED claim
      with no pointer, numeric confidence, a banned label heading, a progress banner.
- [ ] `lint-plan.sh` rejects a stack-ordered plan.
- [ ] Every gate in x-implement prints command + exit code; status is derived, never asserted.
- [ ] No doc path changes on completion; no inbound link breaks when a doc reaches `status: done`.
- [ ] Bootstrap-path line count drops by ≥1,500 vs v2.
- [ ] One full Tier 3 cycle completes on a real feature — **which has never happened in v2**
      `[FOUND §5]`.

## Handoff Notes / Open Questions

- **Open:** `docs/plans/` (existing, plural) vs `docs/plan/` (DEC-009). Settle before S2 writes
  any cross-doc link. Recommend keeping the existing plural `docs/plans/`.
- **Open:** question budget of 3–5 is a guess for one senior engineer on their own codebase; every
  supporting benchmark used a simulated user with privileged information `[FOUND §5]`.
- **Assumed:** an explicit slot sweep closes the self-detection gap. **The failure is established;
  the fix is inferred and unmeasured.** Falsifier: consults that pass with zero open slots still
  produce rework attributable to a slot marked RESOLVED. Ship the rework tally from S2 to find out.
- **Assumed:** batching fact-gathering questions beats one-at-a-time. A vendored skill instructs
  the opposite and no human A/B exists. Falsifier: you report the batch as bewildering.
- **Deferred:** arbitration when your stated belief contradicts scouted code. Mechanism chosen —
  you win unconditionally on intent; factual position changes require new evidence, and a
  contradiction is surfaced as a named conflict rather than silently absorbed. Unevidenced by any
  source `[FOUND §5]`.
- **Deferred:** the rework tally ships as schema only (no logic) — at n≈30 the threshold is noisy.
- **Gotcha:** nothing stops a user who never invokes x-consult. Accepted, not solved.
- **Gotcha — this doc violates its own DEC-009 target:** 333 lines against a ~200 line cap. It
  covers three skills, so the cap is per *unit of work* and this is three. Either state that
  explicitly in the template or the cap will be broken silently on every multi-skill doc. First
  real data point on whether ~200 is the right number.
- **Not read:** Horthy's own `research_codebase.md` / `create_plan.md` / `implement_plan.md` —
  the closest prior art to x-implement. Read before authoring S3 `[FOUND §6]`.
