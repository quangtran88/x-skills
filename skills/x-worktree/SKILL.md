---
name: x-worktree
description: Use when the user (or a sibling skill via --wt flag) wants to spin up an isolated git worktree for a task — wraps the worktrunk `wt` CLI when present, falls back to native `git worktree`, switches the Bash session cwd into the new worktree, and emits a machine-readable result envelope
role: worktree-provider
---

# x-worktree — Isolated Worktree Provisioner

Provisions a fresh worktree on a new branch so callers (x-do, x-bugfix, ad-hoc users) can mutate files in isolation from the user's current checkout. Always creates a new branch — never switches into an existing one.

## Invocation

| Form | Behavior |
|------|----------|
| `/x-skills:x-worktree` | Base = current HEAD branch. Auto-generated new branch name. |
| `/x-skills:x-worktree <target_branch>` | Base = `<target_branch>`. Auto-generated new branch name. |
| `/x-skills:x-worktree <target_branch> <new_branch>` | Base = `<target_branch>`. New branch = `<new_branch>`. |
| `/x-skills:x-worktree "" <new_branch>` | Base = current HEAD. New branch = `<new_branch>`. |

Args: `$1` = target_branch (optional), `$2` = new_branch (optional).

## Hard requirements

- `git` ≥ 2.5 on PATH and cwd inside a git work tree
- `openssl` or `xxd` (auto-detected) for the 6-char hex
- Optional: `wt` (worktrunk) — auto-detected, native git fallback otherwise

## Steps

1. **Validate environment.** `git rev-parse --is-inside-work-tree`. On failure → emit standard error envelope with `REASON=cwd is not a git work tree`, `PROVIDER_ATTEMPTED=none`. STOP.

2. **Resolve base branch (`$1`).** If `$1` empty → `BASE_BRANCH=$(git rev-parse --abbrev-ref HEAD)`. If result is `HEAD` (detached) → emit error envelope with `REASON=HEAD is detached; pass an explicit target_branch`. STOP.

3. **Resolve new branch name (`$2`).**
   - If `$2` provided → validate with `git check-ref-format --branch "$2"`. On failure → emit error envelope with `REASON=branch name '<value>' fails git check-ref-format`. STOP.
   - If `$2` empty → auto-generate `<base-slug>-<6hex>` where `<base-slug>` = `BASE_BRANCH` with `/` and non-`[A-Za-z0-9._-]` chars replaced by `-`, truncated to 32 chars; `<6hex>` = `openssl rand -hex 3` (fallback `head -c 4 /dev/urandom | xxd -p | head -c 6`).

4. **Provision (Steps 4–5 use absolute path / `git -C` — cwd switch happens in Step 6).**
   - **`wt` present** (`command -v wt`): `wt switch --create --base "$BASE_BRANCH" "$NEW_BRANCH" --no-cd`. On `Branch already exists`: `wt switch "$NEW_BRANCH" --no-cd`. Capture path from `wt list`.
   - **`wt` absent**: `REPO_ROOT=$(git rev-parse --show-toplevel); WORKTREE_PATH="${REPO_ROOT%/*}/$(basename "$REPO_ROOT")-wt/$NEW_BRANCH"; mkdir -p "$(dirname "$WORKTREE_PATH")"; git worktree add -b "$NEW_BRANCH" "$WORKTREE_PATH" "$BASE_BRANCH"`. On `already exists`: `git worktree add "$WORKTREE_PATH" "$NEW_BRANCH"`.
   - On any other error → emit error envelope with `REASON=<exact git/wt stderr>` and the attempted provider. STOP.

5. **Submodule init (best-effort).** `git -C "$WORKTREE_PATH" submodule update --init --recursive 2>/dev/null || true`. Never fail the skill on submodule errors.

6. **Switch session cwd.** `cd "$WORKTREE_PATH" && pwd`. Bash tool persists cwd across calls; subsequent plain Bash calls now run inside the worktree.

7. **Emit success envelope** (exactly these lines, nothing above):
   ```
   ✓ Worktree ready
   WORKTREE_PATH=<absolute-path>
   BRANCH=<new-branch-name>
   BASE=<base-branch-name>
   PROVIDER=<wt|git>
   CWD_SWITCHED=true
   ```

## Error envelope (unified)

Every failure path emits this exact shape — no other error formats:
```
✗ Worktree FAILED
REASON=<one-line>
PROVIDER_ATTEMPTED=<wt|git|none>
CWD_SWITCHED=false
```

See `references/examples.md` for concrete examples of each failure mode.

## Always-create-new-branch (by design)

x-worktree never switches into an existing branch's worktree — it always creates a new branch from a base. Callers want a clean slate, not to land on an existing branch.

| Args | Behavior |
|---|---|
| 0 args | base = current HEAD, auto-generated new branch |
| 1 arg | use the arg as **base**, auto-generate new branch |
| 2 args | base + new branch (both explicit) |

To open an *existing* worktree, use `wt switch <branch> --no-cd` directly — outside x-worktree's scope.

## Caller integration (x-do, x-bugfix, others)

See `references/caller-integration.md` for: `--wt` flag parsing, dispatch shape, **non-negotiable cwd-propagation rules** for Agent / OMC / OMO / morph-mcp dispatches, and verification.

## Examples

See `references/examples.md` for success and failure envelope examples.

## Anti-Patterns

See `references/anti-patterns.md`.

## Gotchas

- **Detached HEAD** — refuses to auto-name a branch from a detached HEAD. User must pass an explicit base.
- **Branch already exists** — falls through to `wt switch <name> --no-cd` or `git worktree add <path> <branch>`. Never force-deletes.
- **wt vs git path divergence** — worktrunk writes worktrees as `<repo>.<branch>`; native fallback uses `<parent>/<repo>-wt/<branch>`. Callers MUST consume the emitted `WORKTREE_PATH=` line, never reconstruct it.
- **Submodule init failure** — non-fatal. Worktree is still usable.
- **Symlinks / non-standard layouts** — native fallback uses the `git rev-parse --show-toplevel` resolved path. Treat `WORKTREE_PATH` as opaque.

## Dependencies

- `git` (mandatory, ≥ 2.5)
- `wt` (optional, auto-detected)
- `openssl` or `xxd` (one is on every macOS/Linux box)
- `../x-shared/context-envelope.md` — caller handoff format

No skills are hard dependencies. Caller is responsible for cwd discipline downstream of the success envelope.

Task: {{ARGUMENTS}}
