---
title: Foundations for x-skills v3 — consult / record / implement
slug: x-skills-v3-foundations
type: research
status: current
created: 2026-07-27
updated: 2026-07-27
related: [x-skills-v3]
---

# Foundations for x-skills v3

Factual record behind the v3 redesign. **Spot-check this doc; do not read it end to end.**
Its job is to stop the same research being run twice.

Method: 9 parallel research lanes (5 external literature/practice, 2 local teardown, 1 source
recovery, 1 adversarial synthesis), 1.35M subagent tokens, 319 tool calls, 26 min wall clock.
Lane transcripts: `.claude/projects/*/subagents/workflows/wf_7479589e-b86/journal.jsonl`.

## 1. Read this section before citing anything else

The synthesis lane audited its own sources for fabrication and found real problems. **The
mechanisms below are corroborated across independent lanes and are safe to build on. The
numbers are not, and none of them belong in a skill body.**

Specific findings that must not be cited:

| Claim | Problem |
|---|---|
| `arXiv:2604.09408` "HiL-Bench" per-model Ask-F1 figures | Post-cutoff, unverifiable, twelve named authors and one-decimal figures. Its "gap attributable purely to help-seeking judgment" compares two different task setups — a causal attribution, not a measured decomposition. |
| `arXiv:2603.26233` "Ask or Assume?", 69.40% resolve rate | Same arXiv ID attributed to two different author sets by two lanes, both quoting an identical figure. Classic confabulation signature. Unusable. |
| `arXiv:2502.13069` titled "Ambig-SWE… Underspecificity" | Real paper, wrong title (actual: "Interactive Agents to Overcome **Ambiguity** in Software Engineering"). "Ambig-SWE" is a lane-coined nickname. Mechanisms corroborated elsewhere; re-read the primary before quoting figures. |
| "3–10× first-pass success" for spec-driven development | **No primary source exists.** Traces to vendor blogs citing "early adopter reports." Nothing in this corpus establishes that spec-first docs improve agent output at all. |
| "~150–200 instruction budget", "<40 instructions per prompt" | Two third-party blog paraphrases of a talk. The strings appear nowhere in the author's own primary write-ups. Keep the decomposition discipline; cite no number. |
| "~80% of expected pain gone in the first few minutes" | Alt text of a hand-drawn illustrative diagram (`wdttg.md:37`). A practitioner's sketch, not data. |
| Five July-2026 preprints supplying the corpus's most-quoted figures | Days-to-weeks old, unreviewed. Keep mechanisms, strip numbers. |

Cross-cutting tells that dates and model names were reconstructed rather than read: arXiv ID
months contradict stated dates repeatedly (`2603.*` described as "Feb 2026"), and evaluated
model names are mutually inconsistent across lanes (Opus 4.5/4.6/4.7/4.8, GPT-5.2/5.4/5.5).

**The one fully verified lane is the local repo teardown** — every checked claim was accurate,
and it *understated* one case (it named 5 files carrying banned progress banners; there are 13).

## 2. Primary source — the inspiration video, identified

**"Harness Engineering is not Enough: Why Software Factories Fail"** — Dex Horthy, HumanLayer.
AI Engineer World's Fair 2026 keynote, ~18 min. `youtube.com/watch?v=Ib5GBkD555M`

The author published an expanded **text version of the same argument**, which is reviewable and
should be the citation of record:

- `wsff.md` — <https://raw.githubusercontent.com/humanlayer/advanced-context-engineering-for-coding-agents/main/wsff.md> (708 lines, read in full)
- `ace-fca.md` — same repo, "Advanced Context Engineering for Coding Agents"
- `wdttg.md` — same repo, "Where does the time go"

The verbatim spoken transcript was **not** obtained. Everything attributed below comes from the
author's own text versions, the video description and chapter list, or press coverage.

Lineage worth knowing: Horthy ran Research→Plan→Implement, found it insufficient for the same
reason we did, and evolved it to **Questions→Research→Design→Structure→Plan→Implement** (talks
`YwZR6tc7qYg`, `5MWl3eRXVQk`). Our three-skill split is an independent re-derivation of it.

### The four load-bearing arguments

1. **Why human comprehension is permanent, not a stopgap.** Coding models are RL-trained on
   binary test-pass verifiers with *no penalty for eroding maintainability* (`wsff.md:347`).
   "Tests give you feedback in seconds, but the cost function of bad architecture is measured in
   weeks, months, maybe even years" (`wsff.md:367`). "If a model could reliably tell good code
   from bad, it might have written the good version to begin with, but maintainability has no
   fast oracle, so we can't reward for it during RL" (`wsff.md:393`).
   → **This defines question altitude**: ask only about decisions whose cost a test run cannot
   see. Exclude correctness, which the agent verifies itself.

2. **Why attention goes upstream.** "A bad line of code is… a bad line of code. But a bad line
   of a **plan** could lead to hundreds of bad lines of code. And a bad line of **research**…
   could land you with thousands" (`ace-fca.md:320-333`).
   → Verify the agent's factual model of the codebase *before* debating design.

3. **What review was always for.** Mental alignment, not defect-catching — citing Blake Smith,
   *Code Review Essentials for Software Teams* (2015). Horthy's own failure: "I was starting to
   lose touch with what our product was and how it worked" (`ace-fca.md:335-359`). Bandwidth
   economics: "I can't read 2000 lines of golang daily. But I *can* read 200 lines of a
   well-written implementation plan."
   → Success metric is "human mental model matches the code," not "correct output."

4. **Ceremony must be triaged.** "~40% of tasks get oneshot or oneshot w/ 1-2 rounds of light
   feedback" (`wsff.md:583`). "A copy tweak, a one-off script, a bug with an obvious repro — we
   still just oneshot those straight to the agent. This is for the changes where an agent
   misunderstanding our intent is expensive" (`wsff.md:433`).

### Named antipatterns from the same source

- **Magic words.** RPI only worked if the user recited "work back and forth with me, sharing your
  open questions and phases outline before writing the plan." Without it the agent skipped the
  design discussion and produced output that looked right but was never aligned. Verdict: if the
  tool needs secret phrases, the tool is broken. → **x-consult must work from a bare invocation**,
  and the interview must be control flow, not a prose request the model can silently drop.
- **Prompt contamination.** The feature ticket is hidden during codebase research so the agent
  produces "a factual record of what the code does" rather than "a persuasive narrative."
  Horthy discarded his first research doc because "Claude decided the bug was invalid and the
  codebase was correct" (`ace-fca.md:266`).
- **The plan-reading illusion.** "I don't think you should read really long plan files"
  (`5MWl3eRXVQk` ts:88). Reviewing 1000-line plans instead of 1000-line diffs is illusory —
  plans and implementations diverge, so you review twice.
- **Horizontal plans.** Models default to stack order (migrations → services → API → frontend),
  leaving nothing testable until ~1200 lines in. Prescription: vertical slices / tracer bullets,
  human review at 100–200 lines per slice (`wsff.md:542-570`). "Most frontier models won't design
  a plan like this without human steering" (`wsff.md:570`).
- **Diagram theater.** "Mermaid is fine here but it can sometimes be overkill and sometimes lure
  you into a false sense that you are aligned" (`wsff.md:479`).

### Format primitives the author converged on

Not style guidance — a spec. Plain-text contract shapes (`PUT /api/resources/:slug` + request /
response), call-stack trees in diff syntax (`+ handleCreateResource` / `- legacyCreateFlow`),
file-tree diffs annotated `# NEW` / `# MODIFIED`, and bare type + method signatures
(`resolveTarget(items: Item[], cursor: Cursor) -> ItemId | null`). `wsff.md:489-533`.
"None of these take long to produce (the model drafts them, you argue with it), and every one of
them is a decision you'd otherwise be making implicitly during code review — at the most
expensive possible time to change your mind" (`wsff.md:536`).

## 3. Corroborated mechanisms (safe to build on)

Each was reached independently by 3+ lanes from different literatures.

| # | Mechanism | Why it holds |
|---|---|---|
| M1 | **Terminal status must be DERIVED from machine state** (gate exit codes, open-slot counts, file-written checks) and printed as the first token from a closed enum — never a sentence the model composes. | False success is the largest measured reliability hazard and is undetectable by LLM judges. Taking status authorship away from the component with an incentive to soften it costs ~10 lines of contract. |
| M2 | **The agent cannot judge its own informational sufficiency.** Replace introspection with an external artifact whose rows are individually resolved. Agent silence is evidence of guessing, not understanding. | Strongest convergence in the corpus — five independent literatures, same result. Self-detection of underspecification runs near chance; reasoning-tuning makes abstention worse. |
| M3 | **Scout before asking; gate every question on "the scout already failed to resolve this."** Facts belong to the agent, decisions to the human. | Equal information for ~50% fewer questions. Three vendored frameworks enforce it independently as their #1 rule. |
| M4 | **Ask by presenting a concrete artifact or enumerated options with the agent's recommendation attached.** Recognition beats recall. Open-ended prose questions are the measured worst case. | Also solves the too-technical/too-general calibration problem: choosing among concrete options needs judgment, not expertise, and cannot drift the way an open question does. |
| M5 | **Human attention is worth more upstream than at the diff or per-step.** | Plan-approval oversight reduced exposure to problematic actions; per-step confirmation did not improve runtime correction. Goal/constraint clarification retains near-oracle value only early in a trajectory. |
| M6 | **Pointer-or-delete.** Every claim carries a resolvable pointer (file:line, command + captured output, commit sha, doc anchor); prose rationale is deleted wherever a pointer exists. Numeric confidence banned; three grades — OBSERVED / INFERRED / ASSUMED. | Explanations measurably raise human acceptance of *wrong* answers; sources measurably lower reliance on incorrect ones. LLM verbalized confidence is badly calibrated. |
| M7 | **The acceptance oracle is frozen before implementation and read-only to the implementer.** | Tests authored after code detect ~half as many faults; LLM test generators "fix" failing tests to match buggy implementations. The active ingredient is oracle *independence*, not test-writing ritual. |
| M8 | **No component approves its own output.** Any judging pass is a separate dispatch or it does not exist. | Intrinsic self-correction without an external oracle degrades accuracy; self-preference bias scales with self-recognition. |
| M9 | **Ceremony tiered, tier announced before any artifact is written.** | Unconditional ceremony is precisely why users route around a mandatory-first gate. The leading spec toolchain's file fan-out is its most-criticised property. |
| M10 | **Gates written as runnable operations with observable predicates, not exhortations.** | "Trace the flow end to end" scored 0/3 on a seeded bug; "grep every caller of the function you touch" scored 6/6. Prompt-level guardrails measurably failed to close the submit-vs-resolve gap. |
| M11 | **Verify per task / per edit, never only at the end.** Stop and escalate rather than continuing to repair. | Median decisive error lands early in a long failed trajectory with a short recovery window; recovery attempts past ~5 steps do not succeed. |
| M12 | **Vertical slices with a named verification command beat horizontal waves**, at ~100–200 line checkpoints. Models default to horizontal and will not fix it unsteered — so the plan format must reject stack-ordering mechanically. | Convergent from the source video and from trajectory-failure analysis. |
| M13 | **Immutable doc paths, stable IDs (REQ/AC/DEC), append-only decision blocks with a superseding status line.** Anchor cross-doc links on IDs, never heading prose. | Moving a doc on completion breaks every inbound link. Nygard's four fields beat richer templates on comprehension and adoption; standalone ADR directories get seeded and abandoned. |
| M14 | **Context budget is a correctness constraint.** Decision-relevant content top-loaded, bounded recency window (3–5 related docs) instead of whole-directory loads, tool/gate output condensed before entering context, skill descriptions carrying triggering conditions only. | Unsummarized iterative tool output measured *worse* than removing the tool entirely. A workflow-summarizing description made an agent follow the description instead of the skill. |
| M15 | **Question altitude is behavioral/decisional** — the class of decisions whose cost arrives weeks later and which no test run can verify. | Implementation-detail questions exceed what the human can answer; generic questions yield near-zero information. Matches the RL-verifier argument in §2. |
| M16 | **Match guidance form to failure type.** Output *shape* (format, slot order, length) → positive recipe. *Discipline* (don't skip the gate, don't self-approve) → prohibition + short rationalization table. No nuance clauses; exemption clauses do not scope. | This is what the measured source actually says — one lane flattened its four-row taxonomy into "prohibitions backfire," which would wrongly disarm the discipline gates. |

## 4. Local teardown — the verified lane

Current state: 19 skills, ~17,450 markdown lines, **101 external call sites — verified
2026-07-27**: 64 superpowers (`writing-plans` ×17, `requesting-code-review` ×8, `brainstorming`
×8, `verification-before-completion` ×7, `subagent-driven-development` ×7,
`finishing-a-development-branch` ×5, …) and 37 OMC (`code-reviewer` ×18, `qa-tester` ×6, …),
across 40 files.

**The structural problem is not the dependencies.** It is 19 skills that document each other's
internals — up to ~342 possible directed handoff edges, paid in prose. Evidence:

- `x-backlog/SKILL.md:136-157` — ~40 lines on git-state edge cases *inside x-worktree*
  ("an *update* run leaves it tracked + modified, which x-worktree step 2.5 hard-rejects").
- `x-shared/completion-cascade.md:103-116` — per-skill rollout table, six rows "Deferred."
- `x-shared/slot-schema.md` — 7 slots, 2 "Emitted in v1"; plus a "v2 reference — not shipped" section.
- `x-shared/invocation-guide.md:164-171` — a section documenting `send_message` as
  "DEFERRED, dropped from the canonical vocabulary."
- `x-shared/done-format.md:80-91` — a "Letter Namespace Map" that exists only because 19 skills
  each invented menu letters.

**Self-refuting output contract:** `done-format.md:98` says progress banners are "Never include
in output." **13 step files across three skills open with one — verified 2026-07-27** via
`grep -rlE 'Step [0-9]+ of [0-9]+' skills/` (x-do ×4, x-review ×4, x-guide ×5). Prose contracts
do not self-enforce.

### Carry forward mostly intact

- `x-backlog/references/template.md` — CORE + optional MODULES, "omit rather than write N/A".
- `x-shared/done-format.md` shapes 1–3 (DONE / BLOCKED / DECIDE, one decision at a time,
  `→ Recommended:`, explicit decider) — minus the letter-namespace bureaucracy.
- `x-shared/completion-cascade.md` §3 core loop — discover the project's real test/lint/typecheck
  commands, run them, never return `done` without a green signal or an explicit human ack.
- `x-shared/invocation-guide.md:125-192` — `handoff` vs `assign`, with the hard rule that
  parallel dispatches go in ONE message.
- `x-shared/instrument-and-verify.md` rule 3 — five accepted artifact types. This is M6 already
  written down; promote it, don't reinvent it.
- `x-shared/capability-loading.md` + the SessionStart hook — the best-engineered thing in the
  repo. The framework drop costs it exactly two tokens (`plugin.omc`, `plugin.superpowers`).
- x-backlog's draft-first walk — draft autonomously, ask only at a real blocker, batch blocker
  questions into ONE checkpoint. Note this *contradicts* an interview-drip design.

### Delete — ~1,700 lines of unusable context tax

| Target | Why |
|---|---|
| `x-shared/slot-schema.md` + slot resolution in `invocation-guide.md` | 5 of 7 slots have no consumer; live slots always resolve to their frontmatter default. |
| `x-shared/reactions-vocabulary.md` | Self-declared documentation-only; two completion-cascade branches gated on a Phase 2 that never shipped. |
| 9-layer precedence ladder (`invocation-guide.md:73-123`) | Its own priority-0 admits it has no runtime enforcement. |
| `x-omo`, `x-gemini` as bootstrap deps | 1,084 lines read unconditionally to maybe make one Bash call. |
| `x-team` | Cannot survive the framework drop. |
| 45-line GitNexus freshness contract | Best-effort guidance already, per CLAUDE.md's own fallback clause. |

## 5. Unresolved — do not pretend these are settled

- Nobody has measured whether an explicit slot-sweep scaffold actually closes the self-detection
  gap it routes around. The failure is established; **the fix is inferred.**
- The right question budget for one senior engineer on their own codebase is unestablished.
  Convergent hints point at 3–5; every benchmark used a simulated user with privileged
  information, which could invert the specificity findings entirely.
- **Batched vs one-at-a-time questioning has never been A/B'd with humans.** A verified vendored
  skill (`research/mattpocock/skills/**/grilling/SKILL.md`) instructs the exact opposite of our
  chosen rule. Ours is a house convention, not a finding.
- **How to arbitrate when a confident human contradicts scouted code evidence is unaddressed by
  every source.** All benchmarks assume the human holds ground truth; the sycophancy data says
  the agent will fold. Our split (human wins on intent; factual position changes require new
  evidence) is a designed mechanism, not an evidenced one.
- Hook-free enforcement of a mandatory-first skill is an unsolved design problem. Both dropped
  frameworks enforce their equivalent with a SessionStart / UserPromptSubmit hook.
- No effect size exists for the intervention this design leans on hardest — "print the command
  and exit code before claiming completion." Worth measuring locally once x-implement ships.
- Whether slot/coverage gates are gameable (one throwaway task per requirement, one hand-waved
  verdict per slot) is untested. The traceability benefit was measured on human-maintained links.
- Whether a sufficiency auditor on the same base model catches what the author missed, or merely
  reproduces the blind spot, is unmeasured. Cross-model auditing is plausibly required.
- The wave/parallelism structure is an unvalidated bet. No evidence exists for dependency-ordered
  parallel code *mutation*; the only relevant published guidance says coding parallelizes poorly.
- **No evidence any full research→backlog→plan→implement→archive cycle has ever completed once**
  in this repo. The lifecycle being carried forward may be aspirational.
- Repeated-exposure effects on the output contract are unknown: whether first-person uncertainty
  reads as noise on the 200th exposure, and whether a fixed slot schema induces slot blindness
  when a slot is empty 80% of the time. All supporting studies are single-session.

## 6. Not read, worth reading next

Horthy publishes his actual workflow prompts — `research_codebase.md`, `create_plan.md`,
`implement_plan.md` in `humanlayer/advanced-context-engineering-for-coding-agents`. **No lane
read them.** They are the closest available prior art to all three skills and should be read
before x-implement is authored. Consider vendoring that repo under `research/humanlayer/`
alongside the existing reference submodules.
