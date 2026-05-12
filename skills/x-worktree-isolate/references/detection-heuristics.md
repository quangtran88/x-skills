# detection-heuristics.md

What the inspector probes for during `init`, and why.

| Probe | Tool | Captures | Why |
|---|---|---|---|
| Find compose files | `find` (depth ≤ 2) | `compose_files` | Repos sometimes nest compose under `infra/` or `docker/`. Depth 2 is the sweet spot — covers the common cases without scanning the whole repo. |
| Parse compose YAML | `parse-compose.py` (PyYAML, hard dep) | services, ports, volumes, labels, profiles, environment | YAML has anchors, merge keys, and multi-line scalars — a regex parser is a guaranteed source of subtle bugs. |
| Hardcoded `container_name:` | YAML walk | `services_to_strip[*].container_name` | These are the primary collision source. Apply emits `!reset null` keyed on the YAML service name. |
| `ports[]` host literals | YAML walk | `port_strategy.ports[]` AND `services_to_strip[*].ports[]` | Ports written as `127.0.0.1:18789:...` collide between worktrees. The flat `port_strategy.ports[]` drives the allocator; the per-service entries drive the renderer. |
| `${VAR}` in `ports[]` | YAML walk | already-templated, no rewrite needed | The user already designed for parameterization — just register the var name. |
| `${VAR}:${VAR}` identity mounts | YAML walk | `data_dirs[].dind_identity_mount = true` | Required for docker.sock-spawned containers. |
| Other `${VAR}` host volumes | YAML walk | `data_dirs[]` (per_worktree=true) | Need a per-worktree absolute path. |
| Env values referencing stripped names | substring scan against stripped container names | `service_dns_references` | Surfaces the rare case where `container_name` is used as a hostname (vs the service name). |
| Makefile / `*.mk` / `scripts/*.sh` / `bin/*.sh` `--filter label=` | grep | `global_label_warnings` (severity: blocker) | Cross-worktree teardown footgun. Scope was widened beyond Makefile because shell-script tear-down targets are equally common. |
| Compose `profiles:` blocks | YAML walk | `single_worktree_profiles` | Singletons (e.g., a public tunnel) shouldn't run in parallel worktrees. |
| Compose v2.24+ assertion | `docker compose version --short` | preflight | `!reset` / `!override` merge tags + stacked `--env-file` need v2.24. v1 (`docker-compose`) is rejected outright. |

`init` writes `.worktree-isolate/profile.json` and patches `.gitignore` by default. Pass `--dry-run` to print the draft profile to stdout without touching disk. `--rescan` writes `profile.json.new` next to the existing one and exits 1 with the diff command. `init` must run from the main checkout, not a linked worktree.

## Singleton probes (v0.2)

`detect-singletons.py` runs alongside the YAML walk and emits `singletons[]` candidates the user reviews interactively (default) or accepts wholesale via `--non-interactive`. Pattern catalog: `scripts/singleton-patterns.py`.

| Tier | Probe | Source scanned | Captures |
|---|---|---|---|
| 1: compose-service | env-var name + image substring match | `services.*.environment`, `services.*.image` | `kind=compose-service`, `compose_service`, `disable_method=replicas-zero` (default) |
| 2: env-flag | regex over source files | `.env*`, `.ts/.tsx/.js/.py/.rb/.go/.rs/.java/.kt` (gated by `detection_guardrails`) | `kind=env-flag`, `env_var`, `env_disabled_value="false"` |
| 3: host | fnmatch over repo-relative paths | repo tree (depth ≤ `scan_max_depth`) | `kind=host`, `host_artifact`, `severity=blocker`, `manual_fix_hint` |

Guardrails (`profile.detection_guardrails`): `scan_max_depth` (default 4), `scan_max_file_bytes` (default 1 MB), `exclude_dirs` (defaults: `node_modules`, `vendor`, `.git`, `dist`, `build`, `__pycache__`, `target`, `.next`, `.venv`, `tests/fixtures`), `exclude_globs` (defaults: `*.min.js`, `*.lock`, `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `Cargo.lock`).

See `references/singleton-patterns.md` for the full pattern catalog and per-tier rationale.
