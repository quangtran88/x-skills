# Gap Analyzer

A pure-bash phase between KB Consult (Phase 6) and Plan (Phase 7). Reads `kb/history/` and `kb/index.json`, emits `<run-dir>/coverage_gaps.json`, which the planner injects as a `## Coverage Gaps` block.

## Inputs

- `kb/index.json` — authoritative list of cases + signatures
- `kb/history/<slug>.jsonl` — per-signature run history
- `scope.json` (when scout ran) — current run's endpoint scope, passed via `--scope-file <path>`. When provided, the analyzer filters signatures to those whose `endpoint` is in `scope.json.touched_endpoints` (or the equivalent flat list). When omitted, all signatures are evaluated.
- `--staleness-days <N>` (default: 7) — how old before "stale"

## Categories

| Category | Detection rule |
|---|---|
| `untested` | signature is in scope but has no history file, OR the file is empty |
| `stale` | most recent history entry's timestamp is older than `staleness_days` |
| `recent-failure` | history[-1].result in {fail, error} |
| `regression` | history[-2].pass AND history[-1].fail (per `kb-writeback.sh --check-regression`) |
| `fresh` | none of the above (NOT emitted; planner doesn't need to know) |

## Output: `coverage_gaps.json`

```jsonc
{
  "schema": 1,
  "staleness_days": 7,
  "scope_signatures_total": 42,
  "gaps": {
    "untested":       [{"signature": "...", "endpoint": "...", "category": "..."}],
    "stale":          [{"signature": "...", "last_tested": "...", "days_old": 41}],
    "recent_failure": [{"signature": "...", "last_failure_reason": "503"}],
    "regression":     [{"signature": "...", "regressed_at": "..."}]
  },
  "summary": "12 untested, 3 stale, 1 recent-failure, 1 regression"
}
```

## Planner Prompt Injection

Immediately before `## Task`:

```markdown
## Coverage Gaps (focus reruns here, do not re-run green cases)

{{coverage_gaps.json formatted as a compact summary table}}
```

If `gaps == {}` (all categories empty):

```markdown
## Coverage Gaps

> (none — all in-scope signatures are fresh)
```

## Configuration

`profile.json` may override defaults:

```json
{
  "gap_analyzer": {
    "staleness_days": 14,
    "skip_categories": ["recent-failure"]
  }
}
```
