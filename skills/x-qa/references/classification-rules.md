# Case Classification Rules

Plan-generator and runtime classifier both apply this rule.

## Simple Case

A case is `simple` if ALL of:

1. `request.method` in `[GET, POST, PUT, PATCH, DELETE]`
2. Single request (no multi-step flow)
3. Auth: none, or static token from fixture (no live login)
4. No state setup beyond seed fixtures
5. No websocket / SSE / streaming
6. No cross-service call within the case
7. `assertions.length <= 5`

## Complex Case

Anything failing the above. Examples:
- Login flow → token → use token in second request
- Concurrency tests (parallel requests, race assertions)
- File upload + verify-via-second-endpoint
- Long-poll / SSE
- Workflow spanning multiple services

## User Override

Plan author can set `complexity: simple` or `complexity: complex` per-case to override the auto-classifier. Manual override always wins.

## Classifier Output Bias

When ambiguous, prefer `complex`. Cost of misclassifying simple → complex: pay claude price for a gemini-suitable case (~10x cost). Cost of misclassifying complex → simple: gemini fails the case, retry escalates to flaky, eventual fail. Latter is worse (false negatives).

### `mode: ai_fallback` Steps

Any case containing one or more steps with `mode: ai_fallback` is classified `complex` regardless of other signals. The cheap runner cannot satisfy the `FallbackResponse` contract (see `references/fallback-contract.md`). When the dispatcher encounters such a step in v1, it rejects the plan with:

> `plan rejected: step uses 'mode: ai_fallback' but tier 2 fallback is not yet wired (forward-compat schema only). Remove the step or wait for browser entry type support.`

### Eval-kind assertions

Any case containing an `llm-rubric` or `semantic-similarity` assertion is classified
`complex` and routed to the **judge-runner** (`scripts/evals/score-case.sh`), regardless
of other signals. In v1 an eval case has exactly one eval assertion and no deterministic
assertions (mixing deferred to v2; **enforced** — `score-case.sh` exits non-zero on a
violation rather than silently dropping checks); the cheap HTTP runner cannot score eval
assertions. The
cost cascade is at the suite level — cheap deterministic HTTP cases run independently of the
expensive judge cases.