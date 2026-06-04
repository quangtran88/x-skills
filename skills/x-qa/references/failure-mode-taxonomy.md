# Failure-Mode Taxonomy

The checklist a real QA reasons through. The scout (`scout-prompt.md`) picks the
modes that *apply to this domain* and emits them as `fmode:<area>:<mode>`
obligations; the planner writes a case per obligation; `coverage-check.sh`
enforces it. Two halves — probe for crashes **and** probe for wrong answers.

## A. Failure-Probing Modes (provoke an error or rejection)

| Area | Mode | Apply when | Example obligation id |
|---|---|---|---|
| input | boundary | any numeric/size/length limit | `fmode:upload:boundary` |
| input | null-empty-missing | any optional/required field | `fmode:profile:null-empty-missing` |
| input | type-format | typed/format-constrained field | `fmode:profile:type-format` |
| input | malformed-payload | any JSON/multipart body | `fmode:api:malformed-payload` |
| input | oversize | any size-bounded resource | `fmode:upload:oversize` |
| authz | auth-missing-expired | any authenticated route | `fmode:auth:missing-expired` |
| authz | bypass | any owner/role-scoped resource | `fmode:auth:bypass` |
| writes | idempotency-duplicate | non-idempotent POST/charge | `fmode:order:idempotency-duplicate` |
| writes | concurrency-race | shared mutable resource | `fmode:wallet:concurrency-race` |
| writes | ordering | order-dependent operations | `fmode:ledger:ordering` |
| writes | partial-failure-rollback | multi-step write / transaction | `fmode:checkout:partial-failure-rollback` |
| reads | pagination-cursor | list/cursor endpoints | `fmode:feed:pagination-cursor` |
| infra | rate-limit | rate-limited endpoint | `fmode:api:rate-limit` |
| security | injection | any value reaching a query/shell/path | `fmode:search:injection` |
| encoding | unicode-emoji | free-text fields | `fmode:comment:unicode-emoji` |
| time | timezone-dst | date/time logic | `fmode:booking:timezone-dst` |
| money | rounding-precision | monetary/decimal fields | `fmode:invoice:rounding-precision` |
| state | illegal-transition | any state machine | covered by `xtrans:<from>-><to>` |

## B. Semantic Correctness (the "false case": 200 but WRONG)

A real QA does not stop at "it returned 200". The most dangerous production bug
is the **false case** — a success response carrying a wrong result. Every
`invariant` obligation (`inv:<slug>`) is verified here, by asserting on the
**success** response and/or the resulting state, not by provoking an error.

| Check | What to assert on the SUCCESS path |
|---|---|
| invariant-holds | the business rule still holds (`inv:<slug>`) — e.g. balance never negative |
| side-effect-verified | the write actually happened (re-read / DB row changed), not just acked |
| computed-field-correct | derived/computed values are right (totals, tax, counts) |
| referential-integrity | related rows are consistent after the op (no orphans) |
| no-data-leak | the response exposes only the caller's data (ties to `inv:owner-only`) |
| idempotent-result-equal | replaying an idempotent op yields the same result, not a duplicate |

## How the scout uses this

1. For each entity/endpoint in the domain model, walk column A and keep the
   modes that *apply* (skip `money` if there is no monetary field, etc.).
2. For each invariant, add a column-B `inv:` obligation asserted on success.
3. Mark security/authz and acceptance-derived modes `required`; breadth probes
   `recommended`.

Over-enumeration is waste; under-enumeration misses prod bugs. When unsure
whether a mode applies, include it as `recommended` (reported, non-blocking).
