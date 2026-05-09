# existing-tools.md

When to use x-worktree-isolate vs existing OSS alternatives.

## Comparison

| Capability | x-worktree-isolate | wtc | rft | grove |
|---|---|---|---|---|
| Sets `COMPOSE_PROJECT_NAME` per worktree | ✓ | ✓ | ✓ | ✓ |
| Allocates host ports per worktree | ✓ (registry + lsof) | ✓ (formula only) | ✓ (formula) | partial |
| Strips hardcoded `container_name:` via `!reset null` | ✓ | ✗ | ✗ | ✗ |
| Detects DinD identity mounts (`${V}:${V}`) | ✓ | ✗ | ✗ | ✗ |
| Detects Makefile global label filters | ✓ (severity: blocker) | ✗ | ✗ | ✗ |
| Hard-blocks on cross-worktree footguns | ✓ | ✗ | ✗ | ✗ |
| worktrunk `wt` hook integration | ✓ | ✗ | ✗ | ✗ |
| Validates via `docker compose config` (doctor) | ✓ | ✗ | ✗ | ✗ |
| Runs `docker compose up` for you | ✗ (by design) | ✓ | ✓ | ✓ |
| Multi-stack (compose + pm2 + npm) | ✗ (v1 compose only) | ✗ | partial | ✓ |

## When to use wtc / rft instead

If your repo:

- Has **zero** `container_name:` entries (relies on Compose's default `<project>-<service>-1` naming), AND
- Has **no** Makefile or shell-script `--filter label=` global filters, AND
- Already uses `${VAR}` host ports (no hardcoded literals), AND
- Has no DinD / docker-socket sandboxes,

then wtc or rft will save you the inspector + override boilerplate. They run `docker compose up` themselves, which x-worktree-isolate refuses to do.

## When to use x-worktree-isolate

If your repo has any of:

- Hardcoded `container_name:` (apply with `!reset null` is the only working override).
- Hardcoded host ports (e.g., `127.0.0.1:18789:18789`) that need rewriting.
- DinD bind mounts that require `${V}:${V}` identity.
- A Makefile target that does global-label cleanup that would cross-tear-down parallel worktrees.
- A worktrunk `wt` workflow you want the isolation tied to automatically.

The skill is intentionally narrow: scan, draft, commit profile; on each new worktree, apply. The user's compose / Makefile / launcher remains in charge of running things.

## Reference links

- wtc — https://github.com/raunis-stark/wtc
- rft — https://github.com/uithub/rft
- grove — broader multi-stack worktree manager (varied implementations)
- worktrunk `wt` — https://github.com/worktrunk/wt
