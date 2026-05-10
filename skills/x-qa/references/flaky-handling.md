# Flaky Test Handling

A case that fails on first attempt but passes on retry is `flaky-recovered`.

## Default Behavior

- `--retry-flaky 2` (default): each failed simple-runner case re-runs up to 2 times in foreground (same prompt, same runner).
- Complex-runner cases retry only once by default (more expensive).
- A case that passes any retry → final verdict `flaky-recovered`. Counted in `QA_FLAKY` envelope field.

## Verdict Implications

| Final state | Counts toward |
|---|---|
| All retries fail | `QA_FAILED` |
| First fail + retry pass | `QA_FLAKY` |
| First pass | `QA_PASSED` |

## --allow-flaky-rate

Default: `0` — any flaky case forces final verdict `fail`.
With `--allow-flaky-rate 0.10`: up to 10% of cases may be flaky-recovered without flipping verdict to `fail`.

## Anti-patterns

- Don't retry CONCURRENCY-category cases by default — they probe race conditions; flake hides bugs.
  Mark them with `retry: false` in TEST_PLAN.md to opt out.
- Don't retry cases where setup is non-idempotent (DB seed creates conflicting rows on rerun).

## Persistent Flake List

After a run with flaky cases, write `<run-dir>/flaky.txt` listing case IDs. Future runs (same plan) start with those flagged for visibility. Eventually feed into a stability dashboard (out of v1 scope).
