# Caller Integration

Patterns for skills that dispatch x-worktree (e.g., `x-do --wt`, `x-bugfix --wt`).

## Flag parsing (in caller)

The caller MUST detect and strip these tokens from the user's prompt **before** mode classification, so mode detection sees only the task description:

| Token | Meaning |
|-------|---------|
| `--wt` (alone) | Provision worktree. Base = current HEAD. New branch auto-named. |
| `--wt <branch>` | Provision worktree. Base = `<branch>`. New branch auto-named. |
| `--wt <branch> --new-branch <name>` (or `--wt <branch>:<name>`) | Provision worktree with explicit new branch name. |
| `--wt-no-isolate` | (Caller-side flag.) Translates to passing `--no-isolate` through to x-worktree. Skips auto-isolate; envelope omits `ISOLATE_APPLIED` line entirely. Caller MUST NOT then build a DOCKER CONTEXT block (no signal to build one from). |

Strip the entire `--wt …` segment AND any `--wt-no-isolate` token from the prompt before passing the residue to mode classification. Otherwise the classifier sees them as task content and misroutes.

`--wt-no-isolate` is per-invocation. It does NOT set `XWI_AUTO_ISOLATE=0` — that env var is the user's persistent escape hatch and must be set explicitly by the user, not the caller.

## Dispatch

```
Skill tool: x-skills:x-worktree
Args: "<target_branch_or_empty>" "<new_branch_or_empty>"
```

Wait for the `WORKTREE_PATH=` line in the success envelope. If the skill returns `✗ Worktree FAILED`, abort the parent flow and surface the reason — do NOT silently proceed in the original cwd, that defeats the isolation intent.

## CWD propagation (NON-NEGOTIABLE)

After x-worktree returns successfully, **every** downstream mutating dispatch from the caller MUST run in the worktree.

x-worktree itself runs a final `cd "$WORKTREE_PATH"` before exiting, so the **Bash tool's session cwd is already inside the worktree** — plain Bash calls inherit it. But Agent / OMC executor / OMO / morph-mcp dispatches **do NOT** inherit Bash cwd; they need explicit instruction. Apply ALL of:

1. **Bash dispatches:** session cwd is already the worktree (set by x-worktree). Plain `npm test`, `git status`, etc. work as-is. Defensive callers MAY still prefix with `git -C "$WORKTREE_PATH" …` or `cd "$WORKTREE_PATH" && …` for safety in long sessions where another Bash call may have `cd`-ed elsewhere.
2. **Agent / OMC executor / OMO `omo-agent` dispatches:** include this header verbatim at the top of the prompt:
   ```
   WORKING DIRECTORY: <WORKTREE_PATH>
   All file edits, builds, tests, and commits MUST happen inside this directory.
   Use absolute paths or `cd <WORKTREE_PATH> && …` for every shell command.
   Do NOT touch files outside this directory.
   ```
3. **morph-mcp `edit_file`:** pass absolute paths under `<WORKTREE_PATH>`. Never pass paths from the original repo root.

The caller is responsible for keeping `WORKTREE_PATH` in scope across the whole task. If a sub-handoff happens (e.g., x-do → x-bugfix mid-task), forward `WORKTREE_PATH` in the [handoff context envelope](../../x-shared/context-envelope.md).

## DOCKER CONTEXT propagation

When x-worktree's envelope includes `ISOLATE_APPLIED=true`, the caller MUST read `state.local.json` and prepend a DOCKER CONTEXT block to every executor / Agent / OMC / OMO / morph dispatch made for the rest of the task. This block tells downstream workers how to talk to docker without trampling the user's other worktrees' containers.

### When to build the block

| `ISOLATE_APPLIED` value | Action |
|---|---|
| `true` | Read state.local.json, validate `schema == 1`, build the block. Prepend to every dispatch. |
| `false` | Surface `ISOLATE_REASON` + `ISOLATE_HINT` to user. Ask whether to abort or proceed without isolation (default abort). Do NOT build a block. |
| `skipped` | Proceed normally. No block. |
| *(line absent — `--no-isolate` was set)* | Proceed normally. No block. |

### How to build the block

```bash
state_file="$WORKTREE_PATH/.worktree-isolate/state.local.json"
[ -f "$state_file" ] || fail "ISOLATE_APPLIED=true but state.local.json missing"

schema=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("schema",0))' "$state_file")
[ "$schema" = "1" ] || fail "state.local.json schema mismatch (got $schema, want 1)"

compose_project=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["compose_project_name"])' "$state_file")
ports=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(", ".join(f"{k}={v}" for k,v in d["allocated_ports"].items()))' "$state_file")
data_dir=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["data_dir_path"])' "$state_file")

# Reconstruct launch command at dispatch time — never cache.
if [ -f "$WORKTREE_PATH/.env" ]; then
  launch="docker compose --env-file .env --env-file .env.worktree"
else
  launch="docker compose --env-file .env.worktree"
fi
```

### Block content (verbatim — this is the contract)

```
DOCKER CONTEXT (this worktree is isolated):
COMPOSE_PROJECT_NAME=<compose_project_name>
Allocated ports: <VAR>=<port>, <VAR>=<port>, …
Data dir: <data_dir_path>
Launch: <launch>
Use `docker compose exec <service>` (NOT `docker exec <name>`).
```

Notes:
- `Data dir:` line is omitted when `data_dir_path` is empty (no per-worktree data dirs in profile).
- `<launch>` is the reconstructed command from above — `[--env-file .env]` segment depends on `[ -f $WORKTREE_PATH/.env ]` evaluated at *dispatch* time, never cached.
- The "use `docker compose exec`" guidance is fixed text — `docker exec <name>` would target the wrong container in parallel-worktree setups.

## Verification step (caller-side)

Before claiming the task done, the caller's verifier (x-verify or otherwise) MUST confirm changes landed in the worktree:

```bash
git -C "$WORKTREE_PATH" status --short
git -C "$WORKTREE_PATH" log --oneline -5
```

If `git -C <orig-repo> status` shows mutations in the original cwd, that is a CWD-leak bug — surface it loudly and ask the user how to recover.

When `ISOLATE_APPLIED=true`, also verify the isolation marker survived the session:

```bash
[ -f "$WORKTREE_PATH/.worktree-isolate/state.local.json" ] || fail "isolate marker missing"
schema=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("schema",0))' "$WORKTREE_PATH/.worktree-isolate/state.local.json")
[ "$schema" = "1" ] || fail "state.local.json schema mismatch (got $schema, want 1)"
```
