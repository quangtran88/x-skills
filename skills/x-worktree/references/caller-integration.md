# Caller Integration

Patterns for skills that dispatch x-worktree (e.g., `x-do --wt`, `x-bugfix --wt`).

## Flag parsing (in caller)

The caller MUST detect and strip these tokens from the user's prompt **before** mode classification, so mode detection sees only the task description:

| Token | Meaning |
|-------|---------|
| `--wt` (alone) | Provision worktree. Base = current HEAD. New branch auto-named. |
| `--wt <branch>` | Provision worktree. Base = `<branch>`. New branch auto-named. |
| `--wt <branch> --new-branch <name>` (or `--wt <branch>:<name>`) | Provision worktree with explicit new branch name. |

Strip the entire `--wt …` segment from the prompt before passing the residue to mode classification. Otherwise the classifier sees `--wt` as task content and misroutes.

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

## Verification step (caller-side)

Before claiming the task done, the caller's verifier (x-verify or otherwise) MUST confirm changes landed in the worktree:

```bash
git -C "$WORKTREE_PATH" status --short
git -C "$WORKTREE_PATH" log --oneline -5
```

If `git -C <orig-repo> status` shows mutations in the original cwd, that is a CWD-leak bug — surface it loudly and ask the user how to recover.
