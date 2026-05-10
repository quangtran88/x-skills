---
name: x-team
description: Use when the user asks for parallel team-style execution of multiple features in one project — orchestrates a team lead + N dev workers, one feature per worktree, each gated on x-qa E2E tests, with blocker escalation to human via SendMessage. Hard requires `plugin.omc` (TeamCreate/SendMessage primitives) and `.x-skills/x-qa/profile.json` (E2E gate).
role: team-orchestrator
---

# x-team — Parallel Feature Team Orchestrator

## Bootstrap (MANDATORY)

Before any phase:

1. Pin capabilities per `../x-shared/capability-loading.md`. **HARD requirement: `plugin.omc == true`.** Refuse with a clear message otherwise.
2. Read `../x-omo/SKILL.md` for the OMO catalog (used inside dev workers via x-do, not directly here).
3. Read `gotchas.md`.
4. Verify the x-qa skill is installed: check that `skills/x-qa/SKILL.md` exists in the plugin tree (the skill itself, not just a profile). If missing, refuse with: `x-team requires the x-qa skill. Ensure x-skills plugin is up-to-date (≥ version that includes x-qa).` Then verify `<repo-root>/.x-skills/x-qa/profile.json` exists. If missing, surface:
   > x-team requires an x-qa profile. Run `/x-skills:x-qa init` first.
   Offer to invoke it inline; block until profile ready.
5. Verify `git rev-parse --is-inside-work-tree` succeeds and the user's main branch is clean (`git status --porcelain` empty), or warn explicitly.

## Invocation

| Form | Behavior |
|---|---|
| `/x-skills:x-team "<request>"` | Decompose into N features, provision team, run. |
| `/x-skills:x-team --features <N> "<request>"` | Force feature count (else auto-decompose). |
| `/x-skills:x-team --max-features <N> "<request>"` | Cap parallel concurrency (default 3). NEVER drops features — extra features are queued and promoted as in-flight slots free up. |
| `/x-skills:x-team --base <branch> "<request>"` | Base branch for worktrees (default: current HEAD). |
| `/x-skills:x-team --auto-merge` | On feature pass, auto-merge to base. Default OFF. |
| `/x-skills:x-team --resume <team-slug>` | Resume an interrupted run. |
| `/x-skills:x-team --no-isolate` | Skip `x-worktree-isolate` per-feature (passes the equivalent flag through to `x-worktree`). |

## Phases

1. Parse request. Decompose into features per `references/decomposition-rules.md`.
2. `TeamCreate` with slug derived from request.
3. Per feature: `Skill: x-skills:x-worktree <base> <feat-slug>` → capture `WORKTREE_PATH_i`.
4. `TaskCreate` per feature with metadata (branch, worktree, phase).
5. `TaskUpdate(owner=worker-N)` to pre-assign.
6. Spawn `Task(subagent_type=executor, team_name, name=worker-N, working_directory=WORKTREE_PATH_i, prompt=preamble + feature-spec)` in parallel.
7. Monitor loop per `references/monitor-loop.md`.
8. On all features terminal: shutdown protocol, `TeamDelete`, cleanup.

## Hard Requirements

- `plugin.omc == true`
- `.x-skills/x-qa/profile.json` exists
- `git ≥ 2.5`
- Clean working tree on the lead session (or explicit `--allow-dirty`)

## After This Skill

If all features pass + auto-merge: surface merged branches list.
If features pass without auto-merge: print merge commands for human.
If any feature blocked: surface blocker reasons, ask user how to proceed.

## Dependencies

- `../x-shared/capability-loading.md`, `invocation-guide.md`, `context-envelope.md`
- `../x-worktree/SKILL.md` (provisioning)
- `../x-qa/SKILL.md` (E2E gate inside workers)
- `../x-do/SKILL.md` (impl inside workers)

## Gotchas

See `gotchas.md`.

Task: {{ARGUMENTS}}
