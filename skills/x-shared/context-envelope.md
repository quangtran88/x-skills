# Context Envelope

Optional convention for passing context between x-skills. Include this block when the "After This Skill" section routes to the next skill.

## Format

```
## Handoff Context
- **From:** [skill name] | **Type/Mode:** [classification used]
- **Key finding:** [one-liner summary of what was learned/decided]
- **Agents used:** [list of agents that contributed]
- **Recommendation:** [next skill + mode/type to use]
- **Artifacts:** [file paths of any documents produced]
```

## Examples

After x-research (Type F: Pre-Planning):
```
## Handoff Context
- **From:** x-research | **Type:** F (Pre-Planning)
- **Key finding:** Auth system needs RBAC, current implementation only has binary auth
- **Agents used:** oracle, explore
- **Recommendation:** x-do Mode B (new feature)
- **Artifacts:** none (findings synthesized above)
```

After x-do (Mode B: New Feature):
```
## Handoff Context
- **From:** x-do | **Mode:** B (New Feature)
- **Key finding:** RBAC implemented with 3 roles, 47 files changed
- **Agents used:** ralph (12 stories), code-reviewer
- **Recommendation:** x-review Target C (branch diff vs main)
- **Artifacts:** docs/superpowers/plans/2026-03-29-rbac.md
```

## DOCKER CONTEXT block

A separate, formally-specified block prepended to **every** executor / Agent / OMC / OMO dispatch when a worktree was provisioned with `ISOLATE_APPLIED=true`. Distinct from Handoff Context above.

### When to emit

Caller has consumed `ISOLATE_APPLIED=true` from x-worktree's success envelope (see [`x-worktree/references/auto-isolation.md`](../x-worktree/references/auto-isolation.md)). Emit on every downstream dispatch for the rest of the task — not just the first one.

Do NOT emit when:
- `ISOLATE_APPLIED=skipped` or `false`
- The `ISOLATE_APPLIED` line is absent (user passed `--no-isolate` / `--wt-no-isolate`)
- The dispatch context has no docker / compose interaction (e.g., a pure documentation task — block is harmless but noisy)

### Source of truth

`<WORKTREE_PATH>/.worktree-isolate/state.local.json` (schema v1, JSON key is `schema`). Caller validates `schema == 1` before reading any other field; refuses on mismatch with `ISOLATE_REASON=schema-mismatch`.

### Block content (verbatim)

```
DOCKER CONTEXT (this worktree is isolated):
COMPOSE_PROJECT_NAME=<compose_project_name>
Allocated ports: <VAR>=<port>, <VAR>=<port>, …
Data dir: <data_dir_path>
Launch: <launch>
Use `docker compose exec <service>` (NOT `docker exec <name>`).
```

Field rules:
- `<compose_project_name>` — `state.local.json.compose_project_name`.
- `<VAR>=<port>` list — joined from `state.local.json.allocated_ports` (object key=value, comma-separated).
- `Data dir: <data_dir_path>` — included only when `state.local.json.data_dir_path` is non-empty.
- `<launch>` — reconstructed at *dispatch time*, never cached:
  - `docker compose --env-file .env --env-file .env.worktree` when `[ -f $WORKTREE_PATH/.env ]`
  - `docker compose --env-file .env.worktree` otherwise
- The "use `docker compose exec`" guidance is fixed text. Never replace `<service>` with a literal value — the worker chooses the service per-command.

### Anti-pattern

Do NOT embed this block in non-Docker contexts (e.g., pure refactoring tasks with no compose interaction). It misleads the worker into believing docker is in scope. The caller is responsible for context-appropriate suppression.

Do NOT cache the rendered block across dispatches and reuse — `Launch:` line depends on `.env` presence at dispatch time, which can change mid-task. Rebuild on every dispatch.
