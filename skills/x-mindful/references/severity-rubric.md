# Severity Rubric (v2 — architect-review)

x-mindful uses the shared severity scale (`../../x-shared/severity-guide.md`) re-tuned for the architect-review taxonomy. The ranker in Step 03 must apply this rubric — extractor hints are advisory only.

## Severity Definitions (gate-tuned)

| Severity | Qualifies when ANY of … |
|---|---|
| **CRITICAL** | Data-loss path · Auth / authz bypass · Public-contract break with no deprecation path · One-way migration with no rollback narrative · Secret exposure · Cross-tenant data leak · Vendor or topology lock-in on a mission-critical path |
| **HIGH** | Cross-service or cross-team contract break (even if reversible) · New attack surface (file upload, deserialization, eval, dynamic SQL, public endpoint) · Cost cliff (estimated > 1.5× current spend or non-linear growth) · Shared-state change with concurrent-write risk · Auth-adjacent change (cookie attrs, CORS, CSRF) without threat narrative · "Modular Mirage" — many new surfaces with hidden coupling · Pattern pick (microservices, event-driven, CQRS) without naming the workload property it's buying |
| **MEDIUM** | Internal contract change with multiple consumers · Schema change with reversible deploy · Bounded perf regression · New scheduled job, queue, or cron · Non-trivial new dependency · Single-surface tradeoff where reasonable engineers might disagree |
| (no LOW) | The senior-weigh-in filter (see below) drops items that would have been LOW. If you find yourself wanting LOW, the item probably has `senior_weigh_in: false` and the ranker drops it. |

## Reversibility Definitions

| Level | Examples |
|---|---|
| **reversible** | Behind a feature flag at 0%; code revert restores prior behavior in < 1 day; config change with documented rollback |
| **costly** | Requires migrating data forward then back; multi-service coordinated deploy; > 1 day rollback window; stakeholder sign-off needed; broker / topic / queue cleanup |
| **one-way** | Dropped columns / tables; deleted external resource; broken external integration; published-and-consumed event schema; sent emails / webhooks; rotated keys without backup; vendor onboarding that takes months to unwind |

## The Senior-Weigh-In Filter (HARD GATE)

Every extracted item declares `senior_weigh_in: true | false`. The ranker drops `false` items unconditionally — they don't enter the queue, they don't get scored, they don't appear in the envelope.

**`senior_weigh_in: true` requires** at least one of:

- The choice shapes how the system fails, scales, or evolves
- The choice crosses a team / service / public boundary
- The choice is `costly` or `one-way` to reverse
- The blind spot would cost a real on-call incident, migration failure, or rewrite
- A reasonable senior engineer might choose differently and the choice matters

**`senior_weigh_in: false` when:**

- The decision is purely local (one file, one function, no contract crossed)
- The "tradeoff" is between two equivalent best-practice options
- The "blind spot" is something AI's own best-practice implementation would catch (basic input validation, log levels, exception wrapping)
- The item is a restatement of plan prose with no second-order signal

**Why this gate exists:** the goal is to surface 5–12 items a senior actually wants to see, not 30+ items that drown the gate. If extraction returns more than 15 items after the filter, re-apply the filter more strictly — most plans don't have 15 senior-grade decisions.

## Score Formula (mirrored from Step 03)

```
score = severity_weight × surface_weight × reversibility_weight
severity:      CRITICAL=8, HIGH=4, MEDIUM=2
surface:       public=4, service=3, internal=1
reversibility: one-way=3, costly=2, reversible=1
range:         [2, 96]
```

(No LOW severity tier — those items are filtered by `senior_weigh_in` before scoring.)

## Worked Examples (architect-level only)

| Item (architect-level title) | Cat | Sev | Surface | Rev | Score | Why |
|---|---|---|---|---|---|---|
| One-way migration with no documented rollback | BLIND-SPOT | CRITICAL | service | one-way | 72 | Data-loss path + no rollback |
| Break a public function-call contract (no deprecation) | BLIND-SPOT | HIGH | public | costly | 32 | Public consumer break, partial recovery only |
| Add managed-broker dependency to write path | TRADEOFF | HIGH | service | costly | 24 | Picked async without naming the cost on read path |
| Microservice for a small bounded context | SHAPE | HIGH | service | costly | 24 | Over-engineered shape, ops cost grows |
| Hardcode single-region assumption into routing | FUTURE-DEBT | HIGH | service | one-way | 36 | Paints into corner; multi-region work later |
| Assume "low-volume internal endpoint" with no numbers | ASSUMPTION | MEDIUM | service | reversible | 6 | Load-bearing but recoverable when wrong |
| Add new public endpoint without threat model | BLIND-SPOT | CRITICAL | public | costly | 64 | Attack surface + no narrative |
| Cross-tenant data path with no isolation story | BLIND-SPOT | CRITICAL | service | costly | 48 | Tenant leak risk |

Notice: no item titles mention function names, columns, or files. If your extraction produces those, re-cast.

## Severity Inflation Guard

If more than 30% of items land at CRITICAL, the rubric is mis-applied. Re-rank with strict CRITICAL gating: only items that hit a CRITICAL qualifier above keep the label. Demote the rest to HIGH.

## Bundling

The v1 `LOW-bundle` is removed — the `senior_weigh_in` filter does the same job earlier in the pipeline. If you find yourself wanting a bundle, you have items that should have been filtered. Re-check `senior_weigh_in` on the small items.

The only exception: if extraction returns 5+ items in a single category at MEDIUM severity that are all the same KIND of issue (e.g., five separate "new scheduled job without runbook" items), bundle them into one SHAPE item titled "Operational scaffolding missing across N new jobs/services" with a `scope_note` listing the affected components. One walkthrough turn covers them all.
