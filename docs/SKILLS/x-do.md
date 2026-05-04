# x-do — Execution Router

> **Role:** `router`  
> **Purpose:** Universal work command — classifies tasks into modes and dispatches through optimal workflows.

---

## Detection (6 Modes)

| Mode | Detect When | Route |
|------|-------------|-------|
| **A: Existing Plan** | User references a plan/spec/doc file | Execute plan directly |
| **B: New Feature** | Something to build/add/create, no existing plan | Brainstorm → Plan → Execute |
| **C: Bug Fix** | Error, stack trace, failure description | Delegate to `/x-bugfix` |
| **D: Quick Task** | Trivial change, < 5 min, no ambiguity | Direct execution |
| **E: Visual Input** | PDF, image, screenshot, diagram | Analyze visual → route to A/B/C |
| **F: Refactor** | Structural code change, not bug or new feature | Delegate to `/refactor` |

---

## Research Gate (Before Detection)

Before classifying mode, check: **does this task need research first?**

| Signal | Action |
|--------|--------|
| Unfamiliar library/API/framework | → `/x-research` (Type B or D) first, then return here |
| Vague requirements spanning 3+ modules | → `/x-research` (Type F) first, then return here |
| "How does X work in our codebase?" before fixing/building | → `/x-research` (Type A) first, then return here |
| Clear requirements, known codebase area | → Skip, proceed to Detection |

**Return path:** If x-research just completed in the same session and provided findings/context, skip this gate entirely — research is already done. Proceed directly to Detection.

---

## Pre-Flight Checklist (MANDATORY)

Before starting any mode, complete ALL of these checks:

1. **Resume detection:** Check for in-progress state (paths in `config.json`):
   - `ralph_state` — incomplete stories → offer to resume
   - `specs_dir` — uncommitted design docs → offer to continue
   - Draft plan files (`spec-wip.md`) → offer to continue
2. **Gotchas:** Read `gotchas.md` for known failure patterns before starting
3. **Depth check:** Assess complexity to calibrate ceremony (see Depth Calibration below)

---

## Workflow (4 Steps)

```
Step 1: Gather (step-01-gather.md)
  ├─ Fire oracle (OMO pre-planning) + OMC Explore (codebase context) IN PARALLEL
  ├─ Collect both results
  ├─ Synthesize findings
  └─ Present to user for validation

Step 2: Plan (step-02-plan.md)
  ├─ Route A: superpowers:writing-plans (TDD-oriented)
  ├─ Route B: --model gpt (complex dependency graph)
  └─ Route C: Inline plan (2-3 tasks)

Step 3: Review (step-03-review.md)
  └─ Cross-model review (Claude + GPT perspectives)

Step 4: Execute (step-04-execute.md)
  └─ Dispatch to executor subagent (OMC executor, ralph, or --model codex)
```

---

## Depth Calibration

Before entering mode guidance, assess task along 4 dimensions (Scope, Risk, Novelty, Dependencies) to decide ceremony level:

- **Light** → Skip brainstorming, skip plan review, 1 reviewer post-impl
- **Standard** → Brief brainstorm, plan if 3+ tasks, full 3-reviewer post-impl
- **Heavy** → Full pipeline: brainstorm → plan → plan review → execute → post-impl review

---

## Reactions Block

```yaml
reactions:
  research-needed:      { action: route, to: x-research, auto: true }
  plan-needed:          { action: route, to: superpowers:writing-plans, auto: true }
  test-failed:          { action: route, to: x-bugfix, retries: 2, auto: true }
  lint-failed:          { action: route, to: x-bugfix, auto: true }
  typecheck-failed:     { action: route, to: x-bugfix, auto: true }
  verification-failed:  { action: re-review, to: x-verify, auto: true }
  implementation-complete: { action: menu, options: [commit, x-review, plan-next, done], auto: false }
  stagnation-detected:  { action: menu, options: [alternative-A, alternative-B, alternative-C, abort], auto: false }
  human-approval-needed: { action: notify, auto: false }
```

---

## Completion (Mandatory)

Before claiming done, resolve the `verifier` slot (3-layer cascade):
1. User in-prompt override
2. Skill frontmatter `slots: verifier: x-verify`
3. Schema default (`verification-before-completion`)

Then dispatch `Skill tool: x-verify` and honor its verdict (`done`, `failed`, `needs-user-review`, `aborted`, `waiting-for-user`).

---

## Role Forbid Block

```
x-do MUST NOT (Modes A, B, E, F):
- Call Edit/Write directly → dispatch to executor subagent
- Call Bash to run mutating commands → dispatch to verifier/executor

Exceptions:
- Mode D (Quick Task): < 10 lines, no ambiguity → direct Edit/Write allowed
- Post-execution correction: ≤ 3 files, clear instructions → direct correction allowed
```

---

## Dependencies

- **Shared:** `invocation-guide.md`, `severity-guide.md`, `workflow-chains.md`, `context-envelope.md`
- **External skills:** `x-omo`, `x-bugfix`, `refactor`, `superpowers:brainstorming`, `superpowers:writing-plans`, `superpowers:test-driven-development`, `superpowers:verification-before-completion`, `superpowers:finishing-a-development-branch`, `superpowers:requesting-code-review`, `oh-my-claudecode:ralph`
