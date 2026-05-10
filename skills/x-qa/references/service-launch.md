# Service Launch Reference

`launch-entry-point.sh` dispatches by `launch.kind`. All four kinds reduce to "execute `launch.command` in `launch.working_dir` via `bash -c`" — the kind is informational for human readers. Note: the script refuses any entry whose `type != http` (D5 — v1 limitation).

## Kinds

- `docker-compose`: command typically `docker compose up -d <service>`. Teardown should be `docker compose down`.
- `command`: arbitrary shell command. Teardown user-defined.
- `npm-script`: `npm run <script>`. Teardown can be `npm run stop` if defined.
- `makefile-target`: `make <target>`. Teardown is the target's reverse counterpart.

## Trust-on-First-Use (TOFU) Consent

`profile.json` is checked into the repo (D6) and `launch.command` is evaluated on every dev's machine. To prevent supply-chain RCE via a malicious PR mutating that field, the launcher:

1. Hashes the profile file (sha256) and joins it with `(repo_root, entry_point_name)` into a trust key.
2. Looks the key up in `${XDG_CONFIG_HOME:-$HOME/.config}/x-skills/x-qa/trusted-profiles.json`.
3. If absent and `--trust-profile` was not passed, refuses with exit 4 and prints the exact command for review.
4. On `--trust-profile`, stores the trust key with timestamp.

The cache is per-machine and per-profile-hash, so a profile.json edit forces a re-confirm. CI runs must pass `--trust-profile`; that flag should be wired to a pipeline step that fingerprints the profile change for human review at PR time.

## Base URL Resolution

If `launch.uses_isolate_profile == true` AND `<worktree>/.worktree-isolate/state.local.json` exists:

1. Read `state.local.json` (`schema: 1`).
2. Substitute every `${ISOLATE_PORT_<NAME>}` token in `base_url_template` from `state.allocated_ports.<NAME>` (the key is `allocated_ports` per x-worktree-isolate's contract).
3. Fall back to `base_url_fallback` if substitution fails.

Else: use `base_url_fallback` directly.

## Health Probe

After launch, immediately call `health-wait.sh` with:
- `--url $BASE_URL$health.path`
- `--status $health.expected_status`
- `--timeout $health.timeout_s`
- `--interval-ms $health.interval_ms`

Refuse to proceed to dispatch if health-wait returns non-zero.

## Teardown

Always invoke `launch.teardown` even on dispatch failure. Use bash `trap` in calling skill.
