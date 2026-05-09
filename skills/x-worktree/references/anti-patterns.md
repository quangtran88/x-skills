# Anti-Patterns

Patterns that break worktree isolation or surprise callers. Avoid.

- ❌ **Caller calls x-worktree, then dispatches an executor without setting cwd** → executor edits the original tree. Silent footgun. Always include the `WORKING DIRECTORY` header in agent prompts.

- ❌ **Caller reconstructs the worktree path from convention** instead of parsing the `WORKTREE_PATH=` line → breaks on `wt`-provided paths. Worktrunk uses `<repo>.<branch>`; native fallback uses `<parent>/<repo>-wt/<branch>`. Paths differ.

- ❌ **Skill auto-creates a branch from a detached HEAD** → produces an unnamed-base branch nobody can find. x-worktree refuses this.

- ❌ **Caller passes `--wt` token through to mode classification unstripped** → classifier treats it as task input. Strip the entire `--wt …` segment before classifying.

- ❌ **Caller forwards `WORKTREE_PATH` only on first handoff** → mid-task handoffs (x-do → x-bugfix) lose the path and downstream executors mutate the original tree. Always include `WORKTREE_PATH` in the handoff context envelope.

- ❌ **Skill emits non-envelope error text** → caller can't parse and may proceed with broken state. All failure paths use the standard `✗ Worktree FAILED` envelope.

- ❌ **Skill skips `git check-ref-format --branch` validation on user-supplied branch names** → silent late failure inside `git worktree add`. Validate eagerly and emit the standard error envelope.

- ❌ **Caller parses `ISOLATE_PORTS=…` from the envelope** → that field does not exist. Port + project info is read from `<WORKTREE_PATH>/.worktree-isolate/state.local.json` (`allocated_ports`, `compose_project_name`). Caching ports in the envelope would lie when the user re-runs apply with new allocations.

- ❌ **Caller caches `launch_cmd` from a prior x-worktree invocation** → goes stale when the user later adds or removes a base `.env`. Reconstruct the launch hint at every dispatch from `[ -f $WORKTREE_PATH/.env ]`.

- ❌ **Caller proceeds with executor dispatch when `ISOLATE_APPLIED=false`** → executor talks to docker without isolation, trampling the user's other parallel worktrees. Either retry isolate manually (read `ISOLATE_HINT`), pass `--no-isolate` deliberately, or abort. Default behavior on `false`: ask the user.
