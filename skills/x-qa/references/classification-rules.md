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
