# x-qa Knowledge Base Schema (v1)

The KB lives at `.x-skills/x-qa/kb/` and is **git-tracked**. It is the
team-shared, persistent layer that lets future runs extend prior knowledge
instead of regenerating from scratch.

```
.x-skills/x-qa/
├── profile.json           # existing — service catalog
├── kb/
│   ├── index.json         # fast lookup, single source of truth for IDs
│   ├── cases/             # reusable test cases (one YAML per case)
│   │   └── tc-<slug>.yaml
│   ├── flows/             # composed sequences (one YAML per flow)
│   │   └── fl-<slug>.yaml
│   ├── baselines/         # per-endpoint passive memory (one JSON per endpoint)
│   │   └── <method>__<path-slug>.json
│   ├── history/            # NEW — one .jsonl per coverage_signature, trimmed to 20
│   │   └── <signature-slug>.jsonl
│   └── .ledger.jsonl      # append-only run history (one line per run)
└── runs/<run-id>/         # transient per-run artifacts (existing layout)
```

> `kb/.ledger.jsonl` MAY be `.gitignore`d by teams who do not want per-run
> noise in history. `kb/index.json`, `kb/cases/`, `kb/flows/`, and
> `kb/baselines/` MUST be checked in to make sharing possible.

## `kb/index.json`

Authoritative manifest. Refused on `schema != 1`.

```jsonc
{
  "schema": 1,
  "version": "1.0.0",
  "generated_at": "2026-05-12T10:00:00Z",
  "repo_root": "/abs/path/at/write-time",

  "cases": {
    "tc-avatar-happy-jpeg": {
      "file": "cases/tc-avatar-happy-jpeg.yaml",
      "endpoint": "POST /api/users/me/avatar",
      "category": "happy",
      "coverage_signature": "POST /api/users/me/avatar :: happy-jpeg-upload",  // NEW
      "promoted_at": "2026-04-30T12:00:00Z",
      "promoted_from_run": "2026-04-30-1142-9f0c",
      "green_streak": 7,
      "last_run_id": "2026-05-12-0900-aa11",
      "last_verdict": "pass",
      "checksum": "sha256:..."   // hash of YAML body, surfaces hand-edit drift via doctor
    }
  },

  "flows": {
    "fl-user-signup-then-avatar": {
      "file": "flows/fl-user-signup-then-avatar.yaml",
      "case_ids": ["tc-signup-happy", "tc-login-bearer", "tc-avatar-happy-jpeg"],
      "promoted_at": "2026-05-01T09:00:00Z",
      "promoted_from_run": "2026-05-01-0830-44de",
      "green_streak": 4,
      "last_verdict": "pass",
      "checksum": "sha256:..."
    }
  },

  "baselines": {
    "POST /api/users/me/avatar": {
      "file": "baselines/post__api_users_me_avatar.json",
      "samples": 42,
      "last_seen_at": "2026-05-12T09:00:42Z"
    }
  }
}
```

**`coverage_signature` (string, required for v2)** — A stable abstract
identifier emitted by the planner the first time a case is minted.
Survives endpoint renames + case-ID churn. Format:
`"<verb> <path> :: <category>-<intent-slug>"`. Two cases with the same
signature MUST refer to the same behavioral contract; `kb-prune.sh`
surfaces duplicates.

Back-compat: cases minted before v2 have no signature. The promote step
back-fills via `coverage_signature: "<endpoint> :: <category>"` and emits
a WARN in the ledger so a human can refine later.

**Invariants:**
1. Every `cases/*.yaml`, `flows/*.yaml`, `baselines/*.json` on disk MUST
   have a matching index entry. Orphans are surfaced by `kb-prune.sh`.
2. Every index entry MUST point at a real file. Dangling refs are
   `doctor.sh` failures.
3. Case IDs and flow IDs are STABLE across runs and across team members.
   A planner producing a new case MUST first look for an existing ID via
   the lookup table; only if no match is found does it mint a new
   `tc-<slug>` / `fl-<slug>` ID.

## `kb/cases/tc-<slug>.yaml`

Reusable case body — superset of the TEST_PLAN.md `TestCase` schema with
provenance fields. The planner can splice these directly into a generated
plan without re-emitting fields.

```yaml
schema: 1
id: tc-avatar-happy-jpeg
provenance:
  source: generated            # generated | seeded | manual
  first_seen_run: 2026-04-12-1023-7e3f
  promoted_from_run: 2026-04-30-1142-9f0c
  promoted_at: 2026-04-30T12:00:00Z
  author: x-qa-planner         # x-qa-planner | <git-user> | external
category: happy                # happy | edge | error | auth | concurrency | regression
complexity: simple             # simple | complex
description: "Avatar upload accepts a 200KB JPEG"
endpoint: "POST /api/users/me/avatar"
setup: ""
request:
  method: POST
  path: /api/users/me/avatar
  headers:
    Content-Type: multipart/form-data
  body:
    file: "@fixtures/avatar-200k.jpg"
assertions:
  - { kind: status, expr: "", op: eq, value: 200 }
  - { kind: body-jsonpath, expr: "$.url", op: matches, value: "^https?://" }
teardown: ""
timeout_ms: 5000
tags: [upload, multipart]
```

**Promotion rule** (full detail in `kb-curation.md`):

A case auto-promotes when it accumulates `green_streak >= PROMOTE_AFTER`
(default 3) consecutive `pass` verdicts across distinct run IDs.

## `kb/flows/fl-<slug>.yaml`

A composed sequence — multiple cases chained, with the dependency
contract baked in. Flows are how recurring multi-step journeys (login →
create → mutate → verify) become reusable.

```yaml
schema: 1
id: fl-user-signup-then-avatar
provenance:
  source: generated
  first_seen_run: 2026-04-25-1500-22aa
  promoted_from_run: 2026-05-01-0830-44de
  promoted_at: 2026-05-01T09:00:00Z
  author: x-qa-planner
description: "New user signs up, logs in, sets avatar"
endpoint_set: ["POST /auth/signup", "POST /auth/login", "POST /api/users/me/avatar"]
steps:
  - case_id: tc-signup-happy
  - case_id: tc-login-bearer
    depends_on: [tc-signup-happy]
    capture:                   # values to extract from response, available to later steps
      - { from: "$.token", as: BEARER }
  - case_id: tc-avatar-happy-jpeg
    depends_on: [tc-login-bearer]
    inject:                    # values to substitute into the case's request
      headers:
        Authorization: "Bearer ${BEARER}"
tags: [auth, upload, golden-path]
```

**Promotion rule:** a flow auto-promotes when its `depends_on` chain
appears in `PROMOTE_AFTER` consecutive passing runs AND every constituent
case is itself promoted. Synthesised by `kb-promote.sh` from the run
ledger.

## `kb/baselines/<method>__<path-slug>.json`

Per-endpoint **passive memory** — what the endpoint looked like across
recent runs. Path slug rule: lowercase, `/` → `_`, non-alphanumeric → `_`.
E.g. `POST /api/users/me/avatar` → `post__api_users_me_avatar.json`.

```jsonc
{
  "schema": 1,
  "endpoint": "POST /api/users/me/avatar",
  "first_seen_at": "2026-04-12T10:23:00Z",
  "last_seen_at": "2026-05-12T09:00:42Z",
  "window": 50,
  "samples": 42,
  "status_codes": { "200": 38, "400": 3, "413": 1 },
  "latency_ms": {
    "p50": 142,
    "p95": 388,
    "_window": [/* last <=50 raw observations, used to compute p50/p95 */]
  }
}
```

Baselines record what was seen, not regression signals. The original
draft also tracked p99/max/EWMA, an additive response-shape JSON Schema
union, flaky-rate, and drift signals; those layers were cut as a separate
regression-monitoring feature the user did not ask for. Bring them back
if/when monitoring becomes an explicit goal.

## `kb/history/<signature-slug>.jsonl`

Append-only history of the last 20 runs for a given `coverage_signature`. One JSON object per line. Slug = signature lowercased, non-alphanumerics replaced with `-`, truncated to 80 chars.

```jsonc
{
  "run_id": "2026-05-12-0900-aa11",
  "timestamp": "2026-05-12T09:00:42Z",
  "result": "pass | fail | error | skipped",
  "duration_s": 1.42,
  "failure_reason": null,
  "case_id": "tc-avatar-happy-jpeg"
}
```

**Trim policy.** `kb-writeback.sh` keeps the last 20 lines. Older history is dropped — for full audit, consult `.ledger.jsonl`.

**Regression check.** Regression for signature S is detected when `history[-2].result == "pass" AND history[-1].result in {"fail", "error"}`. Emitted as `regression: true` in the run report. `kb-prune.sh --orphans` removes history files whose signature is no longer in `index.json.cases`.

## `kb/.ledger.jsonl`

Append-only, one JSON object per line. Each line is a run summary used
by `kb-promote.sh` to decide promotion candidacy.

```jsonc
{ "run_id": "2026-05-12-0900-aa11", "started_at": "...", "verdict": "pass",
  "total": 12, "passed": 12, "failed": 0, "flaky": 0,
  "cases": [
    { "id": "tc-avatar-happy-jpeg", "verdict": "pass", "endpoint": "POST /api/users/me/avatar",
      "category": "happy", "body_path": "/abs/path/to/plan-cases/tc-avatar-happy-jpeg.yaml" }
  ],
  "flow_observations": [
    { "chain": ["tc-signup-happy","tc-login-bearer","tc-avatar-happy-jpeg"],
      "all_pass": true, "consecutive_pass": 3 }
  ]
}
```

## Stable ID Derivation

When the planner mints a new case ID:

1. Slugify `<category>-<endpoint-path>-<short-desc>` to lowercase
   alphanumeric + dash, max 60 chars.
2. Prefix with `tc-`.
3. If a collision is detected in `kb/index.json.cases`, suffix `-2`,
   `-3`, … until unique.

Flow IDs use the `fl-` prefix and slugify
`<first-case-endpoint>-then-<last-case-endpoint>`.

## Cross-Team Sharing

The KB is designed to be checked into the same repo as the code under
test. Three patterns work:

1. **Single repo, single KB** (default). The KB lives in the app repo.
2. **Monorepo with per-service KB.** Each service has its own
   `<service>/.x-skills/x-qa/kb/`. Scoped naturally by `repo_root`.
3. **Shared KB across repos.** A central QA repo holds the KB; consuming
   repos add it as a submodule under `.x-skills/x-qa/kb/`.

Tarball export/import was originally part of v1 and was cut — git
already covers the sharing channel.
