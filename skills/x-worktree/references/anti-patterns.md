# Anti-Patterns

Patterns that break worktree isolation or surprise callers. Avoid.

- ❌ **Caller calls x-worktree, then dispatches an executor without setting cwd** → executor edits the original tree. Silent footgun. Always include the `WORKING DIRECTORY` header in agent prompts.

- ❌ **Caller reconstructs the worktree path from convention** instead of parsing the `WORKTREE_PATH=` line → breaks on `wt`-provided paths. Worktrunk uses `<repo>.<branch>`; native fallback uses `<parent>/<repo>-wt/<branch>`. Paths differ.

- ❌ **Skill auto-creates a branch from a detached HEAD** → produces an unnamed-base branch nobody can find. x-worktree refuses this.

- ❌ **Caller passes `--wt` token through to mode classification unstripped** → classifier treats it as task input. Strip the entire `--wt …` segment before classifying.

- ❌ **Caller forwards `WORKTREE_PATH` only on first handoff** → mid-task handoffs (x-do → x-bugfix) lose the path and downstream executors mutate the original tree. Always include `WORKTREE_PATH` in the handoff context envelope.

- ❌ **Skill emits non-envelope error text** → caller can't parse and may proceed with broken state. All failure paths use the standard `✗ Worktree FAILED` envelope.

- ❌ **Skill skips `git check-ref-format --branch` validation on user-supplied branch names** → silent late failure inside `git worktree add`. Validate eagerly and emit the standard error envelope.
