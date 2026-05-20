# x-qa Profile Schema (v1)

`schema: 1` — strict version pin. Tools refuse mismatched schema with a migration message.

## Top-level

| Field | Type | Required | Notes |
|---|---|---|---|
| `schema` | int | yes | Always `1` for v1. |
| `version` | string | yes | Semver of profile content (e.g. `"1.0.0"`). Bumped on user/auto edits. |
| `generated_at` | string (ISO-8601) | yes | Timestamp of last write. |
| `generated_by` | string (open) | yes | Tool that wrote this. Canonical values: `x-qa-init`, `x-qa-update`, `manual`. Open-ended — third-party tools may write their own identifier. |
| `repo_root` | string (abs path) | yes | Repo root at write-time. Doctor refuses if drifted. |
| `primary_entry_point` | string | yes | Name of one `entry_points[].name`. Default target for `run` when `--service` absent. |
| `entry_points` | EntryPoint[] | yes | At least 1 entry. |
| `fixtures` | Fixtures | no | DB seed/reset commands. |
| `ignore_paths` | string[] | no | Globs excluded from PR-surface derivation. |
| `metadata` | object | no | Free-form: framework, language, package_manager. |

## EntryPoint

| Field | Type | Required | Notes |
|---|---|---|---|
| `name` | string (slug) | yes | Unique within profile. Used as `--service <name>`. |
| `type` | enum | yes | `http` \| `cli` \| `grpc` \| `graphql` \| `worker` \| `websocket`. v1 `run` executes `http` only. |
| `description` | string | no | Human-readable. |
| `auto_managed` | bool | yes | If `true`, `update` may overwrite. If `false`, `update` preserves user edits. Default `true` from init. |
| `launch` | Launch | yes | How to start the service. |
| `base_url_template` | string | http only | URL template, supports `${ISOLATE_PORT_<NAME>}` interpolation. |
| `base_url_fallback` | string | http only | Used when isolate state absent. |
| `health` | Health | http only | Health probe. |
| `auth` | Auth | no | Auth strategy. |
| `openapi_spec` | string (path) | no | Relative path to OpenAPI/Swagger spec. |
| `args_schema` | string | cli only | Human-readable arg pattern. |
| `queue_inspect` | string | worker only | Command to inspect queue depth. |
| `primary` | bool | one-of | Mirrors top-level `primary_entry_point`. Exactly one entry across the profile MUST have `primary: true`; all other entries omit the field or set it to `false`. |
| `verified` | bool | yes | Last smoke check passed. |
| `verified_at` | string (ISO-8601) | no | When `verified` was last set. |

## Launch

| Field | Type | Required | Notes |
|---|---|---|---|
| `kind` | enum | yes | `docker-compose` \| `command` \| `npm-script` \| `makefile-target`. |
| `command` | string | yes | The actual command to execute. |
| `teardown` | string | no | Command to stop the service (e.g. `docker compose down`). |
| `working_dir` | string | no | Relative to repo root. Default `.`. |
| `uses_isolate_profile` | bool | no | If `true`, x-qa reads `<worktree>/.worktree-isolate/state.local.json` for ports. |

## Health

| Field | Type | Required | Notes |
|---|---|---|---|
| `method` | enum | yes | `GET` \| `POST`. |
| `path` | string | yes | URL path (resolved against `base_url_template`). |
| `expected_status` | int | yes | e.g. `200`. |
| `timeout_s` | int | no | Total wait timeout in seconds. Default 60. |
| `interval_ms` | int | no | Poll interval. Default 1000. |

## Auth

If the parent `auth` block is present, `kind` is required. All other fields are optional and depend on `kind`.

| Field | Type | Required | Notes |
|---|---|---|---|
| `kind` | enum | yes | `none` \| `bearer` \| `cookie` \| `api-key` \| `oauth-flow`. |
| `token_source` | string | when `kind != none` | `env:<NAME>` or `file:<path>`. **Literal tokens rejected** (security). |
| `fixture_user` | string | no | Optional username/email of seed user. |

## Fixtures

The `fixtures` block itself is optional (top-level). When present, `reset_strategy` is required so the runtime knows when to call `reset_command`.

| Field | Type | Required | Notes |
|---|---|---|---|
| `seed_command` | string | no | Run before first case in a run. |
| `reset_command` | string | when `reset_strategy != none` | Run between cases per `reset_strategy`. |
| `reset_strategy` | enum | yes | `per-case` \| `per-category` \| `none`. |

## Validation Rules (enforced by `doctor.sh`)

1. `schema == 1`.
2. `entry_points` non-empty.
3. Exactly one entry has `primary: true` (and it equals top-level `primary_entry_point`).
4. Each entry has `auto_managed` set explicitly (no implicit default at validation time).
5. `name` slug: lowercase alphanumeric + dash, 1-40 chars.
6. `auth.token_source` matches `^(env:|file:)[A-Za-z0-9_./-]+$`. Literal tokens rejected.
7. `launch.command` non-empty.
8. `launch.working_dir` resolves under `repo_root`.
9. For `type: http`: `base_url_template` and `base_url_fallback` and `health` all present.
10. `repo_root` matches `git rev-parse --show-toplevel` at validation time.

## Schema Migration

`x-qa init --migrate-from v0` reserved for future. v1 has no predecessor.

## Examples

See `skills/x-qa/templates/profile.example.json` (full) and `profile.minimal.json` (http-only starter).

### `auth_case_id` (string | null)

The case ID of the canonical login/authentication flow for the service under test. When set, the planner attaches this case as a default `precondition_case_id` for every case whose `tags` include `requires-auth` (or whose `endpoint` is not in `profile.public_endpoints`).

```json
{
  "schema": 1,
  "auth_case_id": "tc-login-bearer-default-admin",
  "public_endpoints": ["GET /health", "GET /api/version"],
  ...
}
```

**Set during `init` interview** when the scanner detects an auth endpoint. `null` = no auth required, or auth handled externally (service mesh).

**Override.** A case may opt out by setting `precondition_case_id: ""`. A plan-level override is possible via `--no-auth`.
