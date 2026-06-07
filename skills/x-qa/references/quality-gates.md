# Quality Gates

Optional declarative thresholds attached to a TEST_PLAN. Evaluated after Phase 13 (retries) by `scripts/lib/verdict.sh`. Result feeds the Run Envelope's `QA_VERDICT`.

## Tuple Shape

```yaml
{ metric: <string>, threshold: <number>, max: <number>, blocking: <bool> }
```

- Exactly one of `threshold` (lower bound, value MUST be ≥) or `max` (upper bound, value MUST be ≤) MUST be set. Both → reject.
- `blocking: true` → failure flips `QA_VERDICT` to `fail`.
- `blocking: false` → failure surfaces as `warn` in the verdict if no `fail` already present.
- Missing `blocking` defaults to `false`.

## Per-Category Metric Vocabulary

| Metric | Source | Direction | Default |
|---|---|---|---|
| `tests.passRate` | passed / total * 100 | threshold | 100 (blocking) |
| `tests.flakyRate` | flaky / total * 100 | max | 5 (non-blocking) |
| `tests.skippedRate` | skipped / total * 100 | max | 10 (non-blocking) |
| `performance.p50_ms` | median case duration | max | not enforced unless declared |
| `performance.p95_ms` | p95 case duration | max | not enforced unless declared |
| `security.critical` | count of critical findings | max | 0 (blocking when present) |
| `kb.regressions` | gap-analyzer regression count | max | 0 (blocking) |
| `evals.failRate` | eval cases with verdict==fail / eval total * 100 | max | 0 (blocking) |
| `evals.advisoryFails` | count of would-fail eval cases downgraded to advisory | max | 0 (non-blocking) |
| `evals.uncalibrated` | count of eval cases scored by an uncalibrated/low-κ judge | max | 0 (non-blocking) |

Custom metrics may be declared in `profile.json.gates.custom_metrics`.

## Evaluation Order

1. Compute all gate values from aggregate results.
2. Apply gates in declaration order.
3. **Fail-fast on blocker** — the first blocking failure flips verdict to `fail`. Continue evaluating to collect all warnings (do NOT short-circuit).
4. **Missing metric handling.** When a declared gate references a metric the aggregator did not populate (common for `security.critical` when no security scanner ran):
   - `blocking: true` AND missing → gate status `unmeasured`; the run verdict is **not** flipped to `fail`, but `gate_results[]` records `status: "unmeasured"` and `QA_REPORT.md`'s Quality Gates section surfaces it as `⚠ unmeasured (blocking)` for human attention.
   - `blocking: false` AND missing → gate status `unmeasured`; verdict unaffected.
   - Rationale: blocking-on-absence would crash every default run that doesn't ship every optional scanner. The honest signal is "we couldn't tell," not "fail" and not "pass."
5. **Non-numeric metric value.** Validate every metric value matches `^-?[0-9]+(\.[0-9]+)?$` before numeric comparison. Non-numeric (including JSON `null`, strings, objects) → gate status `unmeasured`, same treatment as missing.
6. Final verdict:
   - any blocking failure → `fail`
   - else any non-blocking failure → `warn`
   - else → `pass` (unmeasured gates do not lower the verdict by themselves; they surface as warnings on the report)

## Precedence (single canonical rule)

There is exactly one precedence rule. Both `references/quality-gates.md` and the wiring in Task 2.5 Step 9 MUST state it identically:

1. If `TEST_PLAN.yml` declares a `gates:` block, it **fully replaces** profile defaults — no merging.
2. Else if `profile.json.gates.defaults` is present, those defaults apply.
3. Else no gates run; `aggregate-results.sh` falls back to its pre-Phase-2 behavior of computing only the flaky-rate against `--allow-flaky-rate`.

The legacy "always run flaky-rate as a parallel verdict source" path is **removed** — `tests.flakyRate` is now a regular gate metric. Repos that previously relied on the legacy path get the same coverage by declaring `{ metric: tests.flakyRate, max: <pct>, blocking: false }` in either the plan or profile defaults.

## Example

```yaml
# In TEST_PLAN.yml
gates:
  - { metric: tests.passRate, threshold: 100, blocking: true }
  - { metric: tests.flakyRate, max: 5, blocking: false }
  - { metric: performance.p95_ms, max: 500, blocking: true }
  - { metric: kb.regressions, max: 0, blocking: true }
```

A run with `passRate=100, flakyRate=7, p95=400, regressions=0`:
- passRate ✅ · flakyRate ⚠ (non-blocking) · p95 ✅ · regressions ✅
- → `QA_VERDICT=warn`

## Default Profile-Level Gates

```json
{
  "gates": {
    "defaults": [
      { "metric": "tests.passRate", "threshold": 100, "blocking": true },
      { "metric": "tests.flakyRate", "max": 5, "blocking": false },
      { "metric": "kb.regressions", "max": 0, "blocking": true }
    ]
  }
}
```

Plan-level `gates:` block fully replaces profile defaults — no merging — for predictability.

## Eval κ-gate semantics

For eval cases, the judge's verdict is gated by meta-evaluation (`scripts/evals/meta-gate.sh`):
a judge sets a hard `fail` **only** when its Cohen's κ vs the human gold set is ≥ 0.90.
In `[0.85, 0.90)` or uncalibrated, a would-fail is downgraded to advisory (`evals.advisoryFails`
/ `evals.uncalibrated`, non-blocking → `warn`). When no plan/profile gates are declared but
eval cases ran, `aggregate-results.sh` synthesizes the three `evals.*` default gates above.
