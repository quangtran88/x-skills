---
name: x-do
description: Use when the user asks to build, implement, fix, or execute a plan — detects context (existing plan, new feature, bug, quick task, visual input) and routes through brainstorming, planning, debugging, or execution workflows
role: router
slots:
  workspace: current-dir                   # Override to `worktree` per-task for isolation
  verifier: x-verify                       # x-verify internally runs the cascade from completion-cascade.md
reactions:
  research-needed:
    action: route
    to: x-research
    auto: true
  plan-needed:
    action: route
    to: superpowers:writing-plans
    auto: true
  test-failed:
    action: route
    to: x-bugfix
    retries: 2
    auto: true
  lint-failed:
    action: route
    to: x-bugfix
    auto: true
  typecheck-failed:
    action: route
    to: x-bugfix
    auto: true
  verification-failed:
    action: re-review
    to: x-verify
    auto: true
  implementation-complete:
    action: menu
    options: [commit, x-review, plan-next, done]
    auto: false
  stagnation-detected:
    action: menu
    options: [alternative-A, alternative-B, alternative-C, abort]
    auto: false
  human-approval-needed:
    action: notify
    auto: false
---

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
- `Bash` for dispatching OMO agents via `omo-agent`

**Self-check (Modes A, B, E, F only):**
If you're about to call `Edit`/`Write`/mutating `Bash` and you're NOT in Mode D, STOP.
x-do routes. It does not execute. Dispatch to an executor subagent via `Agent` tool.

## Completion (MANDATORY)

Before claiming done, **resolve the `verifier` slot** per `../x-shared/slot-schema.md` § "Slot precedence (v1 — 3-layer cascade)":

1. **User in-prompt override?** ("use x-review for verification this time", "skip verification") → wins.
2. **Skill frontmatter `slots:` block** (this skill declares `verifier: x-verify`).
3. **Schema default** (would be `verification-before-completion`) — only if 1 and 2 are silent.

Surface the resolution inline before dispatching, e.g. `Dispatching verifier slot → resolved to x-verify via skill frontmatter default`. Then dispatch the resolved value via the Skill tool (skills) or Agent tool (OMC agents) per `../x-shared/invocation-guide.md` § "skill-or-agent-typed slot dispatch".

```
# Default resolution (no override): Skill tool: x-verify
```

x-verify runs the completion cascade (see `../x-shared/completion-cascade.md`). Honor its verdict:

- `verdict: done` → proceed to the handoff menu
- `verdict: failed` → fire `verification-failed` reaction (routes to re-review, then re-execute if approved)
- `verdict: needs-user-review` → surface x-verify's menu to the user, wait for input
- `verdict: aborted` → exit the current workflow immediately; do not proceed to the handoff menu. Report the abort reason (`user-abort` or `stagnation-option-D`) to the user.
- `verdict: waiting-for-user` → surface x-verify's menu (e.g., stagnation A/B/C/D) and pause. Do NOT loop or re-dispatch until the user answers.

**Do not claim done without calling x-verify.** This is the single biggest compliance-gap closer.

# x-do — Universal Work Command

Smart entry point that detects what to do and routes through the optimal workflow.

## Bootstrap

**MANDATORY first step — do this BEFORE anything else:**

0. Pin capabilities for the session per `../x-shared/capability-loading.md` (look for the `[x-skills/capabilities]` snapshot injected by SessionStart; otherwise read `~/.config/x-skills/capabilities.json` once). Filter routing tables against the pinned set; do NOT re-check per dispatch. **If `mcp.gitnexus` is pinned, also consume the shared session-pinned indexed+fresh probe per `../x-shared/capability-loading.md` § "Shared GitNexus Indexed+Fresh Probe" — do NOT run an independent `gitnexus list`; read the single pinned record.** (F3)
1. Read `../x-omo/SKILL.md` to load the OMO agent catalog, invocation commands, and model routing. This ensures you know how to invoke OMO agents (`oracle`, `explore`, `librarian`, `multimodal-looker`) via Bash — they are NOT OMC agents. **For the unavailable-agent list and replacement model-routing (`--model codex`, `--model gpt`), see `../x-shared/omo-routing.md § Unavailable Agents`.**

## Invocation

For how to invoke skills, OMO agents, and OMC agents, see `../x-shared/invocation-guide.md`.

For x-do-specific routing, see `references/omo-routing.md`.

## Research Gate

Before classifying mode, check: **does this task need research first?**

Trigger rule: if ANY of the following hold, dispatch `Skill: x-skills:x-research` first and return on its envelope, then re-enter this skill skipping `step-01-gather.md`:

- Unfamiliar library, framework, API, or external system involved
- Requirements vague AND scope crosses 3+ modules
- "How does X work in our codebase?" must be answered before fixing/building
- User explicitly asks for research / investigation / understanding

x-research owns the signal taxonomy and tool selection — do NOT re-classify here. When it completes, it will offer to hand off to x-do; use its envelope to skip `step-01-gather.md` (requirements already collected).

**Return path:** If x-research just completed in the same session and provided findings/context, skip this gate entirely. Proceed directly to Detection. This includes cases where x-research's quick-action exception applied a small fix inline.

## Detection (pattern-match, no LLM judgment)

Classify into ONE of 4 modes via observable signals:

| Mode | Detect When | Key Signals |
|------|------------|-------------|
| **A: Existing Plan** | Prompt references an existing plan/spec/doc file path | `.md` file path that exists, "implement the plan", "execute the spec", numbered feedback list on a prior commit |
| **B: New Work** | Build / add / create / refactor with no plan referenced | Creative/new work, structural changes, no plan path in prompt |
| **C: Bug Fix** | Error, stack trace, or failure described | "fix", "bug", "error", "broken", "crash", "failing", stack trace text |
| **D: Quick Task** | Trivial single-file change, ≤ 10 lines, no ambiguity | Rename, typo, config tweak, comment fix, one-line edit |

**Modes E (Visual) and F (Refactor) collapsed:**
- Visual input (image / PDF / screenshot) → Claude is multimodal; read the artifact inside Mode B brainstorming.
- Refactor **with** plan ref → Mode A. Refactor **without** plan ref → Mode B (still goes through brainstorm + writing-plans).

**Review feedback → Mode A:** When the user provides numbered/enumerated feedback on an existing commit or implementation, the feedback list IS the plan.

## Pre-Flight Checklist (MANDATORY)

Before starting any mode, complete ALL of these checks:

- [ ] **`--wt` flag detection:** Scan the user prompt for `--wt` (with optional `<target_branch>` and optional `<new_branch>`). Also scan for `--wt-no-isolate` (caller-side flag — translates to passing `--no-isolate` through to x-worktree, suppressing auto-isolation). If present:
  1. Strip the entire `--wt …` segment AND any `--wt-no-isolate` token from the prompt — mode classification must NOT see them.
  2. Dispatch via `Skill: x-skills:x-worktree` with the parsed args (empty string if a slot was omitted). Append `--no-isolate` to the inner args when `--wt-no-isolate` was set.
  3. Parse the returned envelope. Pin `WORKTREE_PATH` for the rest of this task.
  4. From this point, **every** mutating Bash / Agent / OMC executor / OMO / morph-mcp dispatch MUST run inside `WORKTREE_PATH` per the cwd-propagation rules in `../x-worktree/SKILL.md` § "CWD propagation". Forward `WORKTREE_PATH` in any handoff envelope (e.g., x-do → x-bugfix).
  5. **Parse `ISOLATE_APPLIED` and act on it** (see `../x-worktree/references/auto-isolation.md` for the full contract):
     - `ISOLATE_APPLIED=true` → Read `$WORKTREE_PATH/.worktree-isolate/state.local.json`, validate `schema == 1` (refuse on mismatch), build the DOCKER CONTEXT block per `../x-worktree/references/caller-integration.md` § "DOCKER CONTEXT propagation". Prepend that block to **every** subsequent executor / Agent / OMC / OMO / morph dispatch for the rest of the task. Reconstruct `Launch:` line at every dispatch from `[ -f $WORKTREE_PATH/.env ]` — never cache the rendered block.
     - `ISOLATE_APPLIED=false` → Surface `ISOLATE_REASON` + `ISOLATE_HINT` to the user via AskUserQuestion (2 options, default abort): `(1) abort and let me retry isolate manually` / `(2) proceed without isolation, I accept docker collisions with my other worktrees`. Default = abort.
     - `ISOLATE_APPLIED=skipped` → Proceed normally. No DOCKER CONTEXT block.
     - `ISOLATE_APPLIED` line absent (because `--no-isolate` / `--wt-no-isolate` was set) → Proceed normally. No DOCKER CONTEXT block.
  6. If x-worktree returns `✗ Worktree FAILED`, abort and surface the reason — do NOT silently continue in the original cwd.
- [ ] **Resume detection:** Check for in-progress state (paths in `config.json`):
  - `ralph_state` — incomplete stories → offer to resume
  - `specs_dir` — uncommitted design docs → offer to continue
  - Draft plan files (`spec-wip.md`) → offer to continue
- [ ] **Gotchas:** Read `gotchas.md` for known failure patterns before starting

## Routing Signals (3 axes — replaces Depth Calibration)

After mode detection, only three axes drive routing — no scoring, no depth ladder:

1. **Mode** (A / B / C / D from Detection above)
2. **Task count** (from the plan, after step-02-plan) — `1-2` / `3+`
3. **Walk-away signal** (from user prompt language) — present when the user says "until done" / "don't stop" / "walk away" / "finish overnight" / similar; otherwise absent (default = stay in session)

That's the entire routing surface. Depth scoring (Light / Standard / Heavy) and gitnexus-grounded impact routing are **removed** — they added complexity without proportional value. The optional x-mindful envelope consumption (Mode A handoff) remains intact: symbols named in envelope items are already analyzed, do NOT re-invoke `impact`.

## Available Tools

See `references/available-tools.md` for the full tool table (MCP tools, skills, agents). Key rule: **morph-mcp tools are the DEFAULT** for search and edits — use them before spawning agents.

## Proactive OMO Delegation

See `references/delegation-and-scaling.md` for signal→agent routing table and delegation rules. Key rule: after 2+ failed attempts, delegate to `oracle` or `--model codex` (replaces UNAVAILABLE `hephaestus`) — don't keep grinding.

## Cross-Model Review

Cross-model review (plan or post-implementation) is delegated to **x-review**. Dispatch `Skill: x-skills:x-review <target>` and honor the returned verdict envelope. x-review owns reviewer fan-out, synthesis, severity tiering, passes menu, and Fix Mode. Do not redefine reviewer dispatch here.

## Mode Guidance

See `references/mode-guidance.md` for detailed per-mode instructions. Key rules:

- **A/B: Plan Review** — dispatch `Skill: x-skills:x-review <plan-path>` when plan has 3+ tasks or crosses modules. x-review owns the cross-model fan-out — single call, single envelope.
- **A: Consume x-mindful envelope** when present. Symbols named in envelope items are already analyzed; do NOT re-invoke `impact` on them.
- **A/B: Post-Implementation Review** mandatory before claiming done — dispatch `Skill: x-skills:x-review` on the diff.
- **B: Brainstorming gate** — when no plan/spec ref provided, dispatch `superpowers:brainstorming` FIRST (creates `design.md` per project convention), then `superpowers:writing-plans`. Run `explore` in parallel to detect the convention. See `steps/step-01-gather.md`.
- **C: Delegate to `/x-bugfix`** — uses `systematic-debugging` gate + `debugger` agent + TDD failing test before fix.
- **D: Direct execution** via `morph-mcp edit_file`, still verify.

## Complexity Scaling

The 3-axis Routing Signals above replace previous file-count and depth heuristics. `references/delegation-and-scaling.md` is retained for its agent fallback table and escalation rules — ignore any scaling guidance in it that contradicts the 3-axis model.

## Implementation Discipline (MANDATORY)

Every executor / ralph / `--model codex` / direct-execution route MUST carry the three rules from `../x-shared/instrument-and-verify.md` into the implementation:

1. **Log on first pass** — structured logs at decision points (entry/exit, branches, state transitions, error catches, external boundaries) ship in the same diff as the implementation. Not a debugging afterthought.
2. **Test-first for unknowns** — before calling any unfamiliar lib/API/upstream-path, run a scratch script (REPL, `node -e`, `curl -v`, 10-line `/tmp/scratch.*`) and observe the REAL return shape / error class. Cite the artifact in the implementation rationale.
3. **Never guess** — every claim ("this lib returns X", "this endpoint accepts Y") needs a citation: `file:line`, test output, log line, doc URL, or a re-readable tool call result. Words like "probably", "I think", "should work" are STOP signals — go run an experiment instead.

These rules are forwarded into every executor dispatch via the `[STANDING CONSTRAINTS]` block in `steps/step-04-execute.md` § "Forward Intelligence". Do NOT strip them when composing the executor prompt.

## Post-Implementation Verification (MANDATORY)

After completing implementation in any TS/JS project, run before claiming done:

1. **TypeScript check:** `npx tsc --noEmit` (or project-specific typecheck command)
2. **ESLint check:** `npx eslint <changed-files>` (or project-specific lint command)

Fix all errors before proceeding to review or completion.

## Commit Recomposition (executor / ralph routes)

OMC `executor` and `ralph` commit per micro-step, producing noisy history. After verification passes, recompose into atomic, domain-grouped commits via the `commit` skill. See `steps/step-04-execute.md` § "Commit Recomposition" for the full procedure (capture `BASE_SHA` before dispatch → soft-reset → `Skill commit` → verify zero net diff). Skip if branch is already pushed/shared, or if user asked to preserve granular commits.

## After This Skill

Use `../x-shared/done-format.md` DONE shape. Next-step options typically: `[A] commit · [B] x-review`. Append `· [L] save as skill` when OMC plugin is available and the workflow was complex (3+ steps, multi-agent, novel pattern) — skip [L] silently otherwise. Handoff context block suppressed by default per done-format.md; include only when the next skill explicitly requires it. See `../x-shared/workflow-chains.md` for chaining sequences.

## Dependencies

This skill references shared infrastructure in `../x-shared/`:
- `invocation-guide.md` — tool invocation patterns (OMO via Bash, OMC via Agent)
- `severity-guide.md` — finding severity scale
- `workflow-chains.md` — cross-skill chaining
- `context-envelope.md` — handoff context format

External skills used: `x-research` (Mode B vague-requirements path + step-01-gather delegation), `x-review` (Modes A/B/C plan review + post-impl review delegation), `x-omo` (agent catalog), `x-bugfix` (Mode C), `superpowers:brainstorming`, `superpowers:writing-plans`, `superpowers:test-driven-development`, `superpowers:subagent-driven-development`, `superpowers:verification-before-completion`, `superpowers:finishing-a-development-branch`, `superpowers:requesting-code-review`, `oh-my-claudecode:ralph`, `oh-my-claudecode:ultrawork`.

## Gotchas

See `gotchas.md` for known failure patterns — update it when you encounter new ones.

Task: {{ARGUMENTS}}
