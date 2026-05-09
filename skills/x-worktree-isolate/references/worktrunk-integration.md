# worktrunk-integration.md

How the skill wires into worktrunk's `wt` post-create / pre-remove hooks.

## Stable PATH-resolved entrypoint

The wt.toml hook MUST resolve the launcher by name, not by absolute plugin-cache path. Plugin caches rotate on upgrade — every plugin version lands at a fresh `~/.claude/plugins/cache/.../x-worktree-isolate/...` directory. A hook that hard-codes the cache path breaks the moment the plugin upgrades.

`bin/setup` symlinks `bin/x-worktree-isolate` to `~/.local/bin/x-worktree-isolate`. The hook just calls the launcher by name and lets PATH resolve it.

## wt.toml snippet

Append to `<repo-root>/.config/wt.toml` (the file `wt` reads on every command):

```toml
post-create = "x-worktree-isolate apply --quiet"
pre-remove  = "x-worktree-isolate release --quiet"
```

`init` does this automatically when both:

- `.config/wt.toml` is absent (creates the file with just these two lines), OR
- the file exists and does not already declare `post-create` / `pre-remove`.

If the file already has different `post-create` or `pre-remove` values, init **aborts** and asks the user to merge by hand. The skill never overwrites or re-orders existing keys.

## Manual usage without `wt`

`wt` is optional. Without it, the user runs after each `git worktree add`:

```
cd path/to/new-worktree
x-worktree-isolate apply
```

`x-worktree-isolate release` before `git worktree remove` (or run it after the fact to clean up the registry slot — `release` is idempotent on already-removed paths).

## --if-profile-exists for global hooks

Some users wire `apply --if-profile-exists` into a global wt config that runs on every worktree of every repo. The flag makes apply a silent no-op when the current repo has not run `init`, so it doesn't error on opt-out repos.

## What the hook does NOT do

- Does not run `docker compose up`. The user's Makefile / launch script is still in charge.
- Does not pull / install dependencies. Out of scope.
- Does not validate Makefile labels. That's the inspector's job (one-time, at `init`).

## Verifying the hook fires

After `wt switch -c new-branch`, check the new worktree for:

```
new-branch/
├── compose.override.yml
├── .env.worktree
└── .worktree-isolate/state.local.json
```

If those files are absent, the hook didn't fire. Most common cause: the launcher symlink is missing — re-run `bin/setup`.
