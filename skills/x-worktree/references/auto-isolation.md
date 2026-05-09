# Auto-Isolation Contract

How `/x-skills:x-worktree` integrates with `x-worktree-isolate` so users invoke ONE command and get docker-compose isolation when a profile is present.

## Detection (delegated to apply.sh)

x-worktree does **not** detect profile presence. It calls `x-worktree-isolate apply --quiet --if-profile-exists` unconditionally from the new worktree's cwd. apply.sh resolves the profile from either:

1. `<worktree>/.worktree-isolate/profile.json` (rare — only if a worktree has its own profile)
2. `<main-checkout>/.worktree-isolate/profile.json` (primary case — profile is committed in main, linked worktrees inherit)

When neither exists, apply.sh exits 0 silently (apply.sh:67–70 with `--if-profile-exists`). When cwd is the main checkout (apply.sh:46–53), same silent-exit path. Both cases produce `ISOLATE_APPLIED=skipped, ISOLATE_REASON=no-profile` from x-worktree's perspective — identical from the caller's point of view.

## Envelope additions

Always present in the success envelope **unless** the user passed `--no-isolate`:

```
ISOLATE_APPLIED=true|false|skipped
ISOLATE_REASON=<one-line, ≤200 chars>     # required when false; advisory when skipped
ISOLATE_HINT=<one-line>                    # only when false
```

### Tri-state semantics

| Value | When emitted | `ISOLATE_REASON` | `ISOLATE_HINT` |
|---|---|---|---|
| `true` | apply.sh exited 0 AND `<worktree>/.worktree-isolate/state.local.json` exists with `schema == 1` | omitted | omitted |
| `false` | apply.sh exited non-zero OR timed out (exit 124) OR exited 0 but state file missing/malformed | required, sanitized one-line ≤200 chars | required, single line |
| `skipped` | apply did not run, or `--if-profile-exists` short-circuited | one of: `no-profile`, `binary-missing`, `env-disabled` | omitted |
| *(line absent)* | user passed `--no-isolate` | n/a | n/a |

### Skip reasons

- `no-profile` — apply.sh exited 0 without writing state.local.json. Profile not committed in main, OR cwd was the main checkout (rare for x-worktree which always cd's into a linked worktree first).
- `binary-missing` — `command -v x-worktree-isolate` returned non-zero. User has not run `bin/setup`, or `~/.local/bin` not on PATH.
- `env-disabled` — `XWI_AUTO_ISOLATE=0` in process env. Persistent escape hatch.

### Failure reasons (non-exhaustive)

- `apply-timeout-5s` — apply hung > 5s. Hint: re-run apply manually to debug.
- `state-parse-failed` — apply exited 0 but state.local.json missing or malformed.
- `schema-mismatch` — state.local.json has `schema != 1`. (Treat as `false` — caller cannot trust the file.) The JSON key and the reason label both use `schema` for consistency.
- Any other non-zero exit — apply.sh stderr sanitized through `LC_ALL=C tr -cd '\11\12\15\40-\176' | tr '\n\r\t' ' ' | head -c 200` (drops ANSI escapes / control chars before collapsing to single line + truncating).

## Caller read pattern (port + project info)

When `ISOLATE_APPLIED=true`, callers MUST read `state.local.json` to get docker context. The envelope deliberately omits port/project info — caching it would lie when the user later edits `.env` or re-runs apply with new ports.

```bash
# Validate schema before reading any other field.
state_file="$WORKTREE_PATH/.worktree-isolate/state.local.json"
[ -f "$state_file" ] || fail "ISOLATE_APPLIED=true but state.local.json missing"

schema=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("schema",0))' "$state_file")
[ "$schema" = "1" ] || fail "state.local.json schema mismatch (got $schema, want 1)"

compose_project=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["compose_project_name"])' "$state_file")
ports=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(", ".join(f"{k}={v}" for k,v in d["allocated_ports"].items()))' "$state_file")
data_dir=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["data_dir_path"])' "$state_file")
```

## state.local.json schema v1

| Field | Type | Notes |
|---|---|---|
| `schema` | int | Always `1` in v1. Refuse on mismatch. |
| `slot` | int | 0-based slot index in the per-repo registry. |
| `branch` | string | Branch name at apply time. |
| `compose_project_name` | string | Sanitized slug; safe to use as `COMPOSE_PROJECT_NAME`. |
| `allocated_ports` | object | `<VAR>` → host port (int). |
| `data_dir_var` | string | First per-worktree data-dir var name (empty string if none). |
| `data_dir_path` | string | Absolute host path of the first per-worktree data dir (empty string if none). |
| `applied_at` | string | ISO8601 UTC. Only field that changes between idempotent re-applies. |

Re-applying the same worktree (same path, same registry slot) produces byte-identical content modulo `applied_at`. Ports come from the registry's prior claim (apply.sh:135–164, `existing_ports` lookup).

## Failure semantics + slot-leak cleanup

apply.sh writes `state.local.json` BEFORE claiming the registry slot (apply.sh:382 → :406). On timeout SIGTERM between write and claim, the state file exists without a registry entry. To prevent the next x-worktree run from falsely reporting `ISOLATE_APPLIED=true` (state file present but stale), x-worktree's step 6.5 always runs on apply non-zero exit:

```
xwi_rel_stderr="$(mktemp -t xwi-rel.XXXXXX)"
rm -f "$WORKTREE_PATH/.worktree-isolate/state.local.json"
x-worktree-isolate release --quiet 2>"$xwi_rel_stderr" || true
```

`release` is idempotent (no-ops when no claim exists). On its own failure (e.g., concurrent registry lock contention), the stderr is appended to `ISOLATE_HINT`.

## Idempotence guarantee

Running `/x-skills:x-worktree main same-branch` twice produces:

- Same `WORKTREE_PATH` (existing-worktree fallback in step 4 of x-worktree)
- Same `state.local.json` modulo `applied_at`
- Same `compose.override.yml`
- Same `.env.worktree`
- Same registry entry (slot reuse)
- Both runs: `ISOLATE_APPLIED=true`

This relies on apply.sh's port-reuse logic (apply.sh:135–164) which preassigns ports from the existing registry entry when the worktree path matches.

## Interaction with raw `wt.toml` hooks

Both paths can coexist. apply.sh acquires a 5×retry/200ms POSIX `mkdir` lock around registry mutation. First writer wins; second writer either:
- Sees its own prior claim and reuses ports byte-for-byte (`existing_ports` path), OR
- Fails to acquire the lock after 5 retries → exits 1 → x-worktree reports `ISOLATE_APPLIED=false, ISOLATE_REASON=...could not acquire registry lock...`.

Recommendation for new repos: drop the wt.toml hook, use `/x-skills:x-worktree` exclusively. Existing wt.toml hooks remain safe.

## --no-isolate vs XWI_AUTO_ISOLATE=0 precedence

| Setting | Scope | Effect |
|---|---|---|
| `--no-isolate` flag on x-worktree | per invocation | Envelope omits `ISOLATE_APPLIED` line entirely. Apply NOT called. |
| `XWI_AUTO_ISOLATE=0` env var | persistent (shell session) | Envelope emits `ISOLATE_APPLIED=skipped, ISOLATE_REASON=env-disabled`. Apply NOT called. |

**Flag wins over env.** When both are set, the flag's "omit line" semantics apply. Rationale: flag is per-invocation and explicit; env is sticky and easy to forget.

Callers passing `--wt-no-isolate` translate it to `--no-isolate` on the inner x-worktree call. They MUST NOT also strip env vars — that's the user's choice.

## See also

- `caller-integration.md` — how x-do / x-bugfix consume `ISOLATE_APPLIED` and build the DOCKER CONTEXT block.
- `../../x-worktree-isolate/SKILL.md` — the underlying skill, schema details, registry mechanics.
- `../../x-shared/context-envelope.md` — formal DOCKER CONTEXT block spec.
