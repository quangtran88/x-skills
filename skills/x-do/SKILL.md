---
name: x-do
description: "Use when the user asks to build, implement, fix, or execute a plan — detects context (existing plan, new feature, bug, quick task, visual input) and routes through brainstorming, planning, debugging, or execution workflows"
role: router
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
- `Bash` for dispatching OMO agents via `omo-agent` (if available)

**Self-check (Modes A, B, E, F only):**
If you're about to call `Edit`/`Write`/mutating `Bash` and you're NOT in Mode D, STOP.
x-do routes. It does not execute. Dispatch to an executor subagent via `Agent` tool.

# x-do — Universal Work Command

Smart entry point that detects what to do and routes through the optimal workflow.

## Bootstrap

**MANDATORY first step — do this BEFORE anything else:**

### 1. Feature Gate — detect capabilities

```bash
cat ~/.config/x-skills/capabilities.json 2>/dev/null || echo '{"capabilities":{}}'
```

Parse the result to determine available capabilities. If the file doesn't exist, assume Claude-only mode. See `../../lib/feature-gate.md` for the full fallback table.

**Key checks:**
- `capabilities.opencode == true` → OMO agents available, load x-omo catalog (step 2)
- `capabilities.opencode == false` → Claude-only mode, skip step 2, use fallback routing:
  - Replace `oracle` → `Agent` tool with `model=opus`
  - Replace `explore` → `Agent` tool with `subagent_type=Explore`
  - Replace `executor` → `Agent` tool with `mode=auto`
  - Replace `code-reviewer` → `Agent` tool with `subagent_type="superpowers:code-reviewer"` (if superpowers available) or plain `Agent`
- `capabilities.plugins.superpowers == false` → inline workflow steps instead of Skill invocations

### 2. Load OMO catalog (skip if Claude-only)

Read `../x-omo/SKILL.md` to load the OMO agent catalog, invocation commands, and model routing. This ensures you know how to invoke OMO agents (momus, oracle, hephaestus, etc.) via Bash — they are NOT OMC agents.

The `omo-agent` command is resolved from config.json → `omo_agent` (PATH-based) or `omo_agent_fallback` (relative path).

## Invocation

For how to invoke skills, OMO agents, and OMC agents, see `../x-shared/invocation-guide.md`.

For x-do-specific routing, see `references/omo-routing.md`.

## Research Gate

Before classifying mode, check: **does this task need research first?**

| Signal | Action |
|--------|--------|
| Unfamiliar library/API/framework | → `/x-research` (Type B or D) first, then return here |
| Vague requirements spanning 3+ modules | → `/x-research` (Type F) first, then return here |
| "How does X work in our codebase?" before fixing/building | → `/x-research` (Type A) first, then return here |
| Clear requirements, known codebase area | → Skip, proceed to Detection below |

When x-research completes, it will offer to hand off to x-do. Use its handoff context to skip step-01-gather (requirements already collected).

**Return path:** If x-research just completed in the same session and provided findings/context, skip this gate entirely — research is already done. Proceed directly to Detection. This includes cases where x-research's quick-action exception applied the fix inline.

## Detection

Classify the user's input into ONE mode:

| Mode | Detect When | Key Signals |
|------|------------|-------------|
| **A: Existing Plan** | User references a plan/spec/doc file | File path, "implement the plan", "execute the spec" |
| **B: New Feature** | Something to build/add/create, no existing plan | Creative/new work, no plan referenced |
| **C: Bug Fix** | Error, stack trace, failure description | "fix", "bug", "error", "broken", "crash", "failing" |
| **D: Quick Task** | Trivial change, clearly < 5 min, no ambiguity | Rename, small edit, config change, single-file |
| **E: Visual Input** | PDF, image, screenshot, diagram provided | Binary file attachment, visual reference |
| **F: Refactor** | Structural code change, not a bug or new feature | "refactor", "restructure", "reorganize", "extract", "inline", "move to", "clean up" (multi-file) |

**Review feedback → Mode A:** When the user provides numbered/enumerated feedback on an existing commit or implementation (e.g., "I have feedback for commit abc: 1. use X lib, 2. extract method, 3. fix error..."), route to **Mode A** — the feedback list IS the plan. Do NOT classify as Mode F even if most items are refactoring.

**Mode D vs F boundary:** A single-file rename or trivial cleanup → Mode D. Multi-file structural changes, pattern migrations, or architecture reorganization → Mode F.

## Pre-Flight Checklist (MANDATORY)

Before starting any mode, complete ALL of these checks:

- [ ] **Resume detection:** Check for in-progress state (paths in `config.json`):
  - `ralph_state` — incomplete stories → offer to resume
  - `specs_dir` — uncommitted design docs → offer to continue
  - Draft plan files (`spec-wip.md`) → offer to continue
- [ ] **Gotchas:** Read `gotchas.md` for known failure patterns before starting
- [ ] **Depth check:** Assess complexity to calibrate ceremony (see below)

## Depth Calibration

Before entering mode guidance, assess the task along these dimensions to decide how much ceremony it needs:

| Dimension | Light | Standard | Heavy |
|-----------|-------|----------|-------|
| **Scope** | 1-2 files, single module | 3-5 files, 2 modules | 5+ files, 3+ modules |
| **Risk** | No shared state, reversible | Touches shared interfaces | Auth, data, payments, migrations |
| **Novelty** | Known patterns, clear path | Some unknowns | Unfamiliar stack, no precedent |
| **Dependencies** | Independent changes | Some ordering needed | Cross-task dependencies, integration points |

**Scoring:** Count how many dimensions land in each column. Majority determines ceremony level:

- **Light** → Skip brainstorming, skip plan review, 1 reviewer post-impl. Applies to Mode D always.
- **Standard** → Brief brainstorm, plan if 3+ tasks, full 3-reviewer post-impl.
- **Heavy** → Full pipeline: brainstorm → plan → plan review → execute → post-impl review.

This overrides file-count heuristics. A 3-file auth change (Heavy risk) needs more ceremony than a 6-file rename (Light scope, Light risk).

## Available Tools

See `references/available-tools.md` for the full tool table (MCP tools, skills, agents). Key rule: **morph-mcp tools are the DEFAULT** for search and edits — use them before spawning agents.

## Proactive OMO Delegation

See `references/delegation-and-scaling.md` for signal→agent routing table and delegation rules. Key rule: after 2+ failed attempts, delegate to `oracle` or `hephaestus` — don't keep grinding.

## Cross-Model Review

See `references/cross-model-review.md` for exact tool calls (plan review + post-implementation review).

**Key rules:** OMO agents run via Bash, not Agent tool. Launch all 3 reviewers in ONE message. Wait for ALL results before synthesizing.

## Mode Guidance

See `references/mode-guidance.md` for detailed per-mode instructions. Key rules:

- **A/B: Plan Review is NON-NEGOTIABLE** for 3+ tasks or multi-module plans. Launch all 3 reviewers (ABS) in ONE message.
- **A/B: Post-Implementation Review** is also mandatory (all 3 reviewers). Separate from tsc/eslint verification.
- **A/B: ralph for 3+ tasks** unless mechanical batch or surgical edit exception applies.
- **C: Delegate to `/x-bugfix`**, then post-fix review.
- **D: Direct execution**, still verify.
- **E: Analyze visual**, then route to A/B/C.
- **F: Delegate to `/refactor`**, then post-refactor review.

## Complexity Scaling

See `references/delegation-and-scaling.md` for the full scaling table. Key: single-file → skip brainstorming; 5+ files → full pipeline; mechanical batch → direct execution with reduced review.

## Post-Implementation Verification (MANDATORY)

After completing implementation in any TS/JS project, run before claiming done:

1. **TypeScript check:** `npx tsc --noEmit` (or project-specific typecheck command)
2. **ESLint check:** `npx eslint <changed-files>` (or project-specific lint command)

Fix all errors before proceeding to review or completion.

## After This Skill

Work done? → `/x-review` the changes. See `../x-shared/workflow-chains.md` for common sequences. Include a [handoff context](../x-shared/context-envelope.md) block.

**Learner hook:** If the completed workflow was complex (3+ steps, multi-agent, novel pattern), offer skill extraction:
> This workflow succeeded. Save as a reusable skill? **[Y]** `/oh-my-claudecode:learner` **[N]** Skip

## Dependencies

This skill references shared infrastructure in `../x-shared/`:
- `invocation-guide.md` — tool invocation patterns (OMO via Bash, OMC via Agent)
- `severity-guide.md` — finding severity scale
- `workflow-chains.md` — cross-skill chaining
- `context-envelope.md` — handoff context format

External skills used: `x-omo` (agent catalog), `x-bugfix` (Mode C), `refactor` (Mode F), `superpowers:brainstorming`, `superpowers:writing-plans`, `superpowers:test-driven-development`, `superpowers:verification-before-completion`, `superpowers:finishing-a-development-branch`, `superpowers:requesting-code-review`, `oh-my-claudecode:ralph`.

## Gotchas

See `gotchas.md` for known failure patterns — update it when you encounter new ones.

Task: {{ARGUMENTS}}
