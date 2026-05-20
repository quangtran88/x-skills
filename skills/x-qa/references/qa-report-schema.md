# QA_REPORT.md Schema

Markdown with embedded YAML front-matter for machine-readability.

## Front-matter (YAML)

| Field | Type | Notes |
|---|---|---|
| `run_id` | string | Matches envelope. |
| `feature` | string | From TEST_PLAN.md. |
| `entry_point` | string | From TEST_PLAN.md. |
| `verdict` | enum | `pass` \| `fail`. |
| `total` | int | All cases. |
| `passed` | int | |
| `failed` | int | |
| `flaky` | int | Cases that failed once but passed retry. |
| `flaky_rate` | float | `flaky / total`. |
| `started_at` | ISO-8601 | |
| `duration_s` | float | |
| `cases` | CaseResult[] | One per executed case. |

## CaseResult

| Field | Type | Notes |
|---|---|---|
| `id` | string | From plan. |
| `verdict` | enum | `pass` \| `fail` \| `flaky-recovered`. |
| `runner` | enum | `gemini-flash` \| `claude-sonnet` \| `claude-haiku`. |
| `attempts` | int | 1 + retries used. |
| `evidence` | object | Inline raw evidence (request/response/steps). Schema differs by simple vs complex runner — see `case-runner-prompts.md`. |
| `duration_ms` | int | Final attempt duration. |
| `error` | string | Empty on pass. |

> **Note:** The aggregator emits the full case JSON inside `cases[]` of the front-matter. Large evidence blobs (>4KB serialized) are spilled to `<run-dir>/cases/<id>.json` and `evidence` is replaced with `{ "spilled": "<rel-path>" }` to keep the report scannable. Spill threshold lives in `aggregate-results.sh` as `EVIDENCE_INLINE_MAX_BYTES=4096`.

## Body (markdown)

After front-matter, render:
1. Verdict banner (`✓ PASS` / `✗ FAIL`).
2. Summary table (counts + duration).
3. Failed cases with full evidence excerpts.
4. Flaky cases (pass-on-retry) — informational.
5. Per-category breakdown.

## Quality Gates

When the run evaluated quality gates (plan-level `gates:` or profile defaults), `QA_REPORT.md` includes a `## Quality Gates` section listing each gate with its measured value and status:

```markdown
## Quality Gates

| Metric | Bound | Measured | Status |
|---|---|---|---|
| `tests.passRate` | ≥ 100 | 100 | ✅ pass |
| `tests.flakyRate` | ≤ 5 | 7 | ⚠ warn (non-blocking) |
| `performance.p95_ms` | ≤ 500 | 400 | ✅ pass |
| `security.critical` | ≤ 0 | — | ⚠ unmeasured (blocking) |
```

`unmeasured` rows are flagged for human attention but do NOT flip the verdict — see `references/quality-gates.md § Missing metric handling`.

## Example skeleton

```markdown
---
run_id: 2026-05-10-1623-abc123
feature: user-avatar-upload
verdict: fail
total: 12
passed: 10
failed: 2
flaky: 1
flaky_rate: 0.083
started_at: 2026-05-10T16:23:00Z
duration_s: 18.4
cases:
  - id: tc-001
    verdict: pass
    runner: gemini-flash
    attempts: 1
    duration_ms: 142
    error: ""
    evidence:
      request: { method: GET, url: "http://localhost:3000/health" }
      response: { status: 200 }
      latency_ms: 142
---

# QA Report — user-avatar-upload

## ✗ FAIL (10/12 passed)

| Category | Passed | Failed |
|---|---|---|
| happy | 3 | 0 |
| edge | 3 | 1 |

## Failed Cases

### tc-007 [edge]: 2MB exact boundary
... evidence ...
```
