# 04 — Role Separation: Pilot Forbid Blocks on x-do and x-review

**Tier:** 1 (apply first)
**Source:** OpenCode Orchestrator (`~/.claude/research/orchestration/opencode-orchestrator/docs/03-patterns.md` § 1)
**Touches:** `x-do/SKILL.md`, `x-review/SKILL.md` (pilot only)
**Status:** applied: 2026-04-09 (pilot — x-do + x-review only)
**Estimated effort:** 30 minutes (2 forbid blocks in 2 skills)

## Problem

`feedback_xskill_router_principle.md` declares x-skills are routers — route to best existing tools, never reimplement. This is a solved *philosophy* but an *unenforced discipline*.

In practice:
1. **`x-review`** sometimes proposes fixes inline instead of just returning findings — leaks reviewer into executor
2. **`x-do` in Modes A/B** occasionally calls `Edit`/`Write` directly for "easy fixes" instead of dispatching to an executor subagent

The compliance gap "reviewer #3 Skill tool" (`feedback_xreview_compliance.md`) is the observable symptom: the reviewer implements the review itself instead of dispatching.

**Root cause:** The router principle is abstract. Nothing structurally says "STOP — you're about to violate your role." The agent interprets "route to executor" as "or just do it yourself if it's fast."

## Enforcement honesty

Claude Code's Skill tool only parses `name:` and `description:` from frontmatter. The `role:` field is **prominently-formatted prose the model self-reads** — NOT runtime-validated by the harness. Role enforcement is a self-check discipline: frontmatter declares the role, the forbid block names the constraints, the agent self-checks before every tool call, and `x-skill-review` validates during audit. If the agent ignores the forbid block, the role field is decoration.

The value: _structured_ self-check (prominent, named, with concrete examples) is dramatically better than _abstract_ principle (a memory file that says "x-skills are routers" without naming what's forbidden).

## Proposal (revised): Pilot on 2 skills, defer everything else

### Change 1: Add Role section to `x-do/SKILL.md`

Insert immediately after the frontmatter (before Bootstrap), per the placement rule — the agent reads the top of a skill attentively and skims the middle.

```markdown
## Role: router

**x-do is a router.** It classifies the user's request, detects mode, and dispatches to the right executor. It does **not** apply code changes itself in Modes A, B, E, or F.

**x-do MUST NOT (in Modes A, B, E, F):**
- Call `Edit` or `Write` directly — dispatch to an executor subagent via `Agent` tool or `ralph`
- Call `Bash` to run mutating commands on project files — dispatch to a verifier/executor

**Mode D exception:** Quick tasks (single file, <10 lines, no ambiguity) may use `Edit`/`Write`/`morph-mcp edit_file` directly. Mode D was designed for this — spawning an executor for `s/foo/bar/` adds 30-60s overhead for zero benefit. The forbid applies to complex work, not trivial edits.

**Post-execution correction exception:** After an executor completes and the user provides a targeted correction (≤ 3 files, clear instructions, no investigation needed), x-do may apply corrections directly using `Edit`/`morph-mcp edit_file`. For corrections spanning 4+ files or requiring investigation, dispatch a new executor.

**Always allowed:**
- `Read` for loading gotchas, config, referenced files
- `Skill` tool for dispatching to x-research, writing-plans, etc.
- `Agent` tool for launching executor / verifier subagents
- `Bash` for dispatching OMO agents via `~/.claude/skills/x-omo/omo-agent`

**Self-check (Modes A, B, E, F only):**
If you're about to call `Edit`/`Write`/mutating `Bash` and you're NOT in Mode D, STOP.
x-do routes. It does not execute. Dispatch to an executor subagent via `Agent` tool.
```

### Change 2: Add Role section to `x-review/SKILL.md`

Insert immediately after the frontmatter.

```markdown
## Role: reviewer

**x-review is a reviewer.** It evaluates existing work and returns verdicts. It does **not** apply fixes.

**x-review MUST NOT:**
- Call `Edit` or `Write` during the review phase (steps 1-3 up to verdict) — reviewers evaluate, they don't fix
- Propose "while I'm here, let me just fix this" inline fixes — that's role leakage
- Run `Bash` commands that mutate state (no `git commit`, no `npm install`, no `gh pr merge`) during the review phase

**Exception — Fix Mode:** When the user explicitly requests fixes (e.g., "fix all", "apply fixes") after a REQUEST_CHANGES verdict, x-review enters Fix Mode (step 3). In Fix Mode, `Edit`/`Write`/mutating `Bash` are permitted via the `receiving-code-review` workflow. The role boundary shifts from "report only" to "report then fix on request."

**Allowed:**
- `Read` to inspect diff, source files, tests
- `Bash` for **read-only** verification (running tests, reading git log, checking lint output)
- `Agent` tool to dispatch `code-reviewer` for cross-model passes
- `Skill` tool for dispatching additional review passes

**Self-check before every tool call:**
If you're about to call `Edit`/`Write` or a mutating `Bash` and you are NOT in Fix Mode, STOP.
Reviewers report; they don't fix — until the user says otherwise.
Return your findings and surface the menu — only enter Fix Mode after explicit user request.
```

### Change 3: Add `role:` to frontmatter of both skills

Add after `description:`:
- x-do: `role: router`
- x-review: `role: reviewer`

## What's deferred (post-pilot)

| Item | Why deferred |
|---|---|
| `x-shared/role-vocabulary.md` (10-role taxonomy) | Over-specified for 2-skill pilot. Create when 3+ skills need shared reference. |
| x-skill-review Role Compliance Checklist | Validate pilot works first. Premature to add checklist for untested mechanism. |
| Remaining skills (x-bugfix, x-research, x-design, x-omo, x-skill-improve, x-skill-review) | Full rollout after pilot proves the forbid blocks change agent behavior. |
| Multi-role rules, role transitions, Bash-CLI exceptions | Speculative until real skills surface the need. |

## Migration steps

**Step 1** — Apply Change 3 (frontmatter) + Change 1 (Role section) to `x-do/SKILL.md`.

**Step 2** — Test: give x-do a Mode A or B task with a "tempting" inline edit. Expected: x-do dispatches to executor instead of editing directly.

**Step 3** — Test: give x-do a Mode D quick task. Expected: x-do edits directly (Mode D exception honored, no unnecessary subagent spawn).

**Step 4** — Apply Change 3 + Change 2 to `x-review/SKILL.md`.

**Step 5** — Test: run x-review on a PR with an obvious small bug. Expected: x-review reports the finding and surfaces the menu instead of proposing an inline fix.

**Step 6** — Track "reviewer #3 Skill tool" gap over 10 sessions. If it stops recurring, pilot succeeded. If not, tighten language.

## Validation

**Test case 1 — Router doesn't execute (Mode A/B):**
Give `x-do` a multi-file task. Expected: dispatches to executor/ralph, never calls Edit directly.

**Test case 2 — Mode D exception honored:**
Give `x-do` "rename variable X to Y in file Z." Expected: edits directly without spawning executor. No false enforcement.

**Test case 3 — Reviewer doesn't fix:**
Run `x-review` on code with an obvious issue. Expected: reports the finding, does NOT call Edit.

**Success metric:** "reviewer #3 Skill tool" compliance gap stops recurring. Role leakage incidents drop. Mode D quick tasks remain fast.

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Agent reads forbid block but still shortcuts | Medium | Self-check is prominent and explicit. If still bypassed, add pre-tool-call hook (future). |
| Mode D exception becomes a loophole ("this complex task is actually quick") | Medium | Mode D boundary is defined in mode-guidance.md: "single file, <10 lines, no ambiguity." If agent reclassifies complex work as D, that's a classification bug, not a role bug. |
| Forbid blocks feel like noise in the skill | Low | They're prominent by design. If users complain, improve language, don't remove. |

**Rollback plan:** Remove the `role:` frontmatter field and Role sections from x-do and x-review. Back to current state. Zero downstream effects.

## What changed from v1

The original v1 proposed:
1. A 107-line `role-vocabulary.md` defining 10 canonical roles
2. `role:` frontmatter + forbid blocks for all 8 x-skills
3. x-skill-review checklist extension
4. Multi-role rules, role transitions, Bash-CLI dispatch exceptions
5. Estimated effort: 3-4 hours

Research found:
1. **Mode D contradiction** — v1 forbade all Edit/Write in x-do, but Mode D is explicitly designed for direct execution of trivial changes
2. **Over-specification** — 10-role taxonomy for a 2-skill pilot is speculative. Most roles (diagnostician, orchestrator, skill-maintainer) have 0-1 holders.
3. **Premature checklist** — adding x-skill-review items for an untested mechanism

Revised approach: pilot on 2 skills with Mode D exception, defer everything else. Same compliance gap closure, ~1/6 the surface area.

## Patterns we considered and rejected

**Full role-vocabulary.md upfront** (v1 of this proposal) — rejected for pilot. Create when 3+ skills need shared reference.

**Runtime tool gating** — requires Claude Code changes. Out of scope.

**Roles as separate files** (`x-do/role.md`) — forbids should be visible in the main skill, not buried in a sidecar.

**No Mode D exception** (strict router for all modes) — rejected because Mode D overhead (30-60s subagent spawn for a one-line edit) penalizes the most common user experience.

## Out of scope

- **Runtime tool restrictions** — we declare forbids in prose, not via a runtime feature
- **Per-project role overrides** — keeps the router principle inviolable
- **Remaining skills** — deferred to post-pilot rollout
- **role-vocabulary.md** — deferred until 3+ skills need shared reference

## References

- Source pattern: `~/.claude/research/orchestration/opencode-orchestrator/docs/03-patterns.md` § 1
- Existing principle: `feedback_xskill_router_principle.md`
- Compliance gap closed: "reviewer #3 Skill tool" (primary owner)
- Mode D definition: `x-do/references/mode-guidance.md:43`
- Related proposals: 02 (reactions specify which role handles events), 03 (primitives are the "how" of role transitions)
