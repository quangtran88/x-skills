---
name: x-worktree-isolate
description: Use when the user runs multiple git worktrees of the same repo in parallel and hits docker-compose container_name / port / volume collisions, or asks to set up per-worktree compose isolation, or invokes `init worktree-isolate`. Wraps inspector + override emitter + worktrunk hook.
---

# x-worktree-isolate — Per-Worktree Docker Compose Isolation

Two-phase model:

1. **INSPECT (once per repo, committed)** — scan compose files, draft `profile.json` capturing hardcoded `container_name`s, fixed ports, identity-mount data dirs, cross-worktree footguns. User reviews + commits.
2. **APPLY (every new worktree, automatic)** — read profile, allocate a slot from a per-repo registry, write `compose.override.yml` (with `!reset null` + `!override` ports) and `.env.worktree` (`COMPOSE_PROJECT_NAME` + ports + data dir). Triggered by worktrunk's `wt` post-create hook.

The skill never runs `docker compose up`, never reads or writes the user's `.env`, and never auto-patches their Makefile.

## Bootstrap

**MANDATORY first step — do this BEFORE anything else:**

1. Pin capabilities for the session per `../x-shared/capability-loading.md`. Relevant capabilities: `gemini_cli` is irrelevant; this skill is a self-contained CLI. Skip the multi-model dispatch lanes.
2. Verify the launcher is on PATH: `command -v x-worktree-isolate`. If absent, point the user at the repo root: `/Users/randytran/Codes/x-skills/bin/setup` (the setup script symlinks `bin/x-worktree-isolate` into `~/.local/bin/`).
3. Read `gotchas.md` — known failure patterns the apply step won't catch.
4. Read `config.json` for the version, schema version, stack identity, minimum Compose version, and dependency list. Per-repo runtime values (port range, registry root, lock retry counts) are owned by `port_strategy` in each profile and the constants in `scripts/allocate-ports.sh`.

## Detection table

| Signal | Subcommand |
|---|---|
| User asks to "isolate worktrees", "make compose work in parallel worktrees", "container name conflict in second worktree", or types `init worktree-isolate` | `init` |
| Just ran `wt switch -c <branch>` (or `git worktree add`) and started seeing port/name collisions | `apply` (auto via wt post-create hook; manual run also valid) |
| `docker compose up` in a second worktree binds to the same host ports as the first / silently uses the same `container_name` | `doctor` |
| `wt remove` was just run and the registry needs cleanup | `release` (auto via wt pre-remove hook) |
| User wants to see all currently-claimed slots | `list` |

## When NOT to use

- Repo has **zero** hardcoded `container_name:` entries AND **no** Makefile/script global `--filter label=` filters AND only `${VAR}` host ports → use [`wtc`](https://github.com/raunis-stark/wtc) or [`rft`](https://github.com/uithub/rft) instead. They handle just `COMPOSE_PROJECT_NAME` + port renaming and require less ceremony. See `references/existing-tools.md` for the comparison matrix.
- Single-worktree repo (no parallel work expected) — the override file is overhead with no payoff.
- Stack is Kubernetes / Tilt / Skaffold / pm2 / npm — v1 is compose-only.

## Workflow

The dispatch.sh router exposes one subcommand per workflow stage:

1. **`init`** — scan repo, write `.worktree-isolate/profile.json`, patch `.gitignore`. Must run from the main checkout (not a linked worktree). Idempotent: re-runs only append missing `.gitignore` lines.
2. **`init --dry-run`** — print the draft profile JSON to stdout, do not touch disk.
3. **`init --rescan`** — re-detect, write `profile.json.new` next to existing, exit 1 with the exact `diff` command. The user merges by hand (no auto-merge in v1).
4. **`apply`** — Phase 2. Reads profile, acquires registry lock, allocates next slot, picks ports (`default + slot * 1000` deterministic-first, then `lsof` collision scan inside `scan_range`), writes override + env file + state. Hard-blocks on any `severity: blocker` warning unless `--ignore-warnings`. Re-applying a worktree that already has a registry entry reuses its existing ports byte-for-byte.
5. **`apply --quiet`** — same, suppress success summary. Used by the wt hook.
6. **`apply --if-profile-exists`** — exit 0 silently when no profile. Safe for global hooks that may run on repos that haven't opted in.
7. **`apply --ignore-warnings`** — explicit footgun acknowledgement. Skips the blocker gate.
8. **`apply --dry-run`** — render override + env to stdout, do not touch disk, do not claim slot.
9. **`release`** — drop this worktree's registry slot. Removes generated files only when their first line still matches the auto-generated header.
10. **`doctor`** — validation suite. Asserts `docker compose --env-file .env.worktree config` (with `--env-file .env` stacked first when a base `.env` exists) actually exposes overridden host ports.
11. **`list`** — print all slots claimed in the per-repo registry.
12. **`version`** — print version (currently `0.1.0`).

## Anti-patterns

- **Never edit the base `compose.yml`** — apply only writes `compose.override.yml` (auto-merged by Compose) and `.env.worktree` (passed via stacked `--env-file`).
- **Never read the user's `.env`** — `.env.worktree` contains only the override keys. When a base `.env` is present, Compose merges via `docker compose --env-file .env --env-file .env.worktree up` (later file wins, Compose v2.24+). When there is no base `.env`, the launch command drops to a single `--env-file .env.worktree`.
- **Never run `docker compose up` from this skill** — that's the user's Makefile / launch tooling. Apply only writes files and prints the launch command.
- **Never auto-patch a user's Makefile** — Makefile global label filters are reported as `severity: blocker` warnings; the user fixes them by hand. Out of scope for v1.
- **Never use the plugin-cache path in wt.toml** — plugin caches rotate on upgrade. Always use the PATH-resolved `x-worktree-isolate` (symlinked by `bin/setup`).

## Gotchas

See `gotchas.md`. Highlights:

- `container_name: !reset null` is the **only** incantation that removes the field at merge time. `null`, `""`, and field-omission all silently retain the base value.
- DinD identity mounts (`${V}:${V}`) require an absolute host path that equals the container path — apply produces an absolute path; the user MUST keep the mount line as `${V}:${V}` in the base compose.
- Service-name DNS still works after stripping `container_name` only when env values reference the service name (almost always true). The inspector flags any environment value that hard-codes a stripped container name.
- `apply` hard-blocks on global Makefile label filters (`--filter label=app.sandbox=1`) because they cross-tear-down parallel worktrees' containers. Resolve by scoping the filter to `COMPOSE_PROJECT_NAME`.

## Trigger phrases

- "set up worktree compose isolation"
- "container name conflict" / "container_name conflict" / "name already in use" across parallel worktrees
- "docker compose port conflict" between two `wt switch -c` worktrees
- "isolate worktrees", "per-worktree compose", "parallel worktree compose"
- "compose project name collision", "compose collision in worktree"
- `init worktree-isolate`, `apply worktree-isolate`, `worktree doctor`

## Dependencies

- **Hard requirements:** `git ≥ 2.5`, `python3` + `PyYAML` (for `parse-compose.py`), `docker compose ≥ 2.24` (for `--env-file` stacking and `!reset` / `!override` merge tags), `lsof` (port collision check), `openssl` or `python3 hashlib` (sha1 of repo identity).
- **Optional:** worktrunk `wt` CLI for automatic post-create / pre-remove hooks. Without it, the user invokes `apply` manually after `git worktree add`.
- **Plugin integration:** `bin/setup` symlinks `bin/x-worktree-isolate` to `~/.local/bin/x-worktree-isolate`. The wt.toml hook resolves the launcher via PATH, never the plugin cache.

## References

Loaded only when the workflow needs them:

- `references/detection-heuristics.md` — what the inspector probes for and why
- `references/compose-override-cookbook.md` — `!reset null` empirical verification
- `references/port-strategies.md` — slot formula, collision behavior, range
- `references/worktrunk-integration.md` — wt.toml snippet, manual fallback
- `references/existing-tools.md` — wtc / rft / grove comparison

Task: {{ARGUMENTS}}
