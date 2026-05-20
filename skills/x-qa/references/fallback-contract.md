# Fallback Contract (Forward-Compat, Not Yet Wired)

Defines the response schema and call-budget rules for a future intelligent-retry tier that will replace the blind `--retry-flaky <N>` once x-qa supports browser/selector entry types. Schema is documented now so planner, runner templates, and aggregator are forward-compatible; the self-heal loop itself is **deferred** until vision/DOM signals are available.

> **Why not now?** In HTTP-only v1 the only signals on a 4xx/5xx are the request + response. Asking an LLM to "fix" a failed HTTP request collapses to mutating headers or body — indistinguishable from blind retry plus hallucination risk (e.g. silently adding an auth header to make a 401 pass). The current blind retry is honest. The vision-fallback tier is high-value only when there's a screenshot + DOM + console signal to ground it.

## Decision State Machine

```
case fails → tier 0 (blind retry up to --retry-flaky)
           ↓
        still fails → tier 1 (deterministic selector resolver — browser only;
                              for HTTP, skipped)
           ↓
        still fails → tier 2 (LLM-grounded fallback, bounded by call budget;
                              returns FallbackResponse)
           ↓
        decision ∈ {retry, adapt, skip, abort}
```

## `FallbackResponse` JSON Schema

```jsonc
{
  "decision": "retry | adapt | skip | abort",
  "new_request": {                  // for HTTP entry; null otherwise
    "method": "POST",
    "path": "/api/...",
    "headers": { ... },
    "body": { ... }
  },
  "new_selector": "css-string-or-null",   // for browser entry; null otherwise
  "new_action": {                          // for "adapt" decisions
    "action_type": "click | type | wait | navigate",
    "selector": "...",
    "value": null,
    "description": "Brief human description"
  },
  "reasoning": "one-sentence explanation"
}
```

**Field semantics.**
- `retry`: original action sound; selector/path needs correction. Use `new_selector` (browser) or `new_request` (HTTP). Counts against the call budget.
- `adapt`: page/state needs a different action first (dismiss modal, re-auth). Use `new_action`. Counts against the budget.
- `skip`: step cannot complete but the test can continue. Mark skipped, proceed. Does not count against retry budget; emits a `warn` in the case report.
- `abort`: test unrecoverable. Fail immediately.

**Prefer `skip` over `abort`** unless the test truly cannot produce meaningful results.

## Call Budget

`max_fallback_calls_per_case` (default 3). Once exceeded, the next failure is treated as `abort`. Configurable in `profile.json`:

```json
{
  "fallback": {
    "max_calls_per_case": 3,
    "model": "default-complex-runner",
    "tier_1_enabled": true,
    "tier_2_enabled": false   // default — turn on once browser entry types ship
  }
}
```

## System Prompt Skeleton (forward-compat, do NOT deploy yet)

```
You are an expert QA engineer AI assisting with automated testing. A test
step has encountered an unexpected state.

CRITICAL: Return ONLY valid JSON matching the FallbackResponse schema. No
markdown fences, no comments, no text before or after the JSON object.

Decision guidelines:
- retry: action sound but selector/path is wrong → provide new_selector or new_request
- adapt: page needs a different prerequisite action → provide new_action
- skip: step cannot complete but test can continue
- abort: test unrecoverable

Prefer skip over abort. Only abort if the test truly cannot produce
meaningful results.
```

## Signals Passed (when wired)

For browser entry types:
- screenshot (base64 PNG)
- DOM snippet (≤ 2000 chars, cropped around expected selector location)
- console errors (first 10)
- original action description + selector
- free-text test context

For HTTP entry types **(out of scope for v1; not deployed)**:
- request method + path + headers + body
- response status + headers + first 2KB of body
- expected status + expected schema
- free-text test context

## Integration Points (when wired)

- `references/flaky-handling.md` Tier 2 will reference this contract.
- `scripts/aggregate-results.sh` will distinguish `skip` (warn-level) from `abort` (fail-level).
- `references/quality-gates.md` may add a `fallback.calls_per_run` metric.

## Versioning

This schema is `fallback.v0` (draft). It becomes `fallback.v1` when the first browser entry type ships and the contract is exercised in a real run.
