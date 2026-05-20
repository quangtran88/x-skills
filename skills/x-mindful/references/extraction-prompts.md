# Extraction Prompts (per category)

Use these prompts in Phase 2. They work both for claude-direct extraction and for OMO dispatch (`oracle`, `--model codex`). When dispatching to OMO, append `references/item-schema.md` and the JSON output contract.

## Universal Preamble

```
You are extracting architect-review-grade impact items from an AI-generated
plan / spec / PRD / design doc. Your reader is a senior staff/principal
engineer who has 10 minutes to decide whether the direction is sound.

You are NOT reviewing code. You are surfacing the decisions, assumptions,
tradeoffs, blind spots, shape mismatches, and future-debt that AI silently
embedded — the things a senior would want to weigh in on BEFORE any code
is written.

HARD RULE — no code-level identifiers in any narrative field:
  - No function names, method names, class names
  - No parameter lists, return types, field names, SQL column names
  - No file paths, line numbers, module imports
  - No variable names or constant values

If you find yourself reaching for one of those, re-cast the item at
architect level ("breaks a public function-call contract used by external
consumers") or drop it. AI follows common best practice when picking
names; that is not what the human needs to weigh in on.

Use the schema in references/item-schema.md. Output JSON only.
Empty categories are fine — DO NOT pad. Quality over quantity.

Every item must declare senior_weigh_in: true|false. Items with false
will be dropped by the ranker. An item earns true only when a senior
would actually want to weigh in on the direction.

Plan content follows between <plan> tags.
```

## TRADEOFF — Forks in the Road AI Picked Silently

```
Find decisions where AI picked side X of a real tradeoff without naming
the cost on the other axis or surfacing the alternatives. Look for:

  - Sync vs async (RPC vs message bus vs CDC vs outbox)
  - Monolith vs split (new service when a module would do)
  - Build vs buy (new code where a managed service exists, or vice versa)
  - Strong vs eventual consistency
  - Optimistic vs pessimistic concurrency
  - Eager vs lazy initialization
  - Vendor-specific feature vs portable abstraction
  - One-way door (Amazon Type 1) vs two-way door (Type 2)
  - Pattern picks: microservices, event sourcing, CQRS, k8s, Kafka,
    serverless — when the choice is presented as a default rather than
    justified against the workload

For each TRADEOFF item, REQUIRED fields beyond the schema basics:
  - tradeoff_picked: the axis AI optimized + the cost it accepted
  - alternatives: 1-3 real options AI didn't surface (no strawmen)
  - future_debt: what gets harder later if this turns out wrong

Re-cast filter: if the only way to describe the tradeoff is to name a
function or field, you're at code level — drop it or re-cast.
```

## ASSUMPTION — Load-Bearing Claims Never Stated

```
Find claims AI silently relied on but did not state. Look for:

  - Non-functional requirements: scale, latency, availability,
    consistency tolerance, data retention — guessed or omitted
  - Environment assumptions: cloud provider features available, single
    region, no air-gapped/regulated deployment, uniform runtime versions
  - Trust boundaries: input is benign, internal services mutually trusted,
    secrets management "handled elsewhere"
  - Organizational capacity: on-call teams can absorb new services,
    teams can ramp on new tech without burn
  - Volume claims: "this table won't exceed N rows", "low-volume endpoint",
    "internal-only callers" — anything that, if wrong, changes the design

For each ASSUMPTION item, REQUIRED:
  - assumption: state the load-bearing claim as AI would have to defend it
  - future_debt: what breaks the design if the assumption fails

Pattern to watch: a plan that mentions traffic, scale, or users without
giving numbers is making an assumption. So is a plan that picks a
managed service without naming the cost model.
```

## BLIND-SPOT — What a Senior Expects but the Plan Skips

```
Find things a senior reviewer would expect in any production design that
the plan does not address. Look for:

  - Failure modes — "how does this fail?" never answered for major
    dependencies (DB, message bus, cache, third parties, identity)
  - Rollback / back-out — destructive or one-way steps with no plan
  - Observability — new component without metrics, logs, traces, alerts
  - Runbook & owner — new service/queue/job with no on-call owner,
    no expected incident classes, no runbook
  - Migration safety — schema or data change without backfill, dual-write,
    or verification strategy
  - Threat model — new endpoint, new attack surface, multi-tenant
    isolation, audit logging never discussed
  - Recovery & repair — no story for detecting and correcting data
    inconsistencies
  - Backpressure / degradation — system behavior under load or partial
    failure never named

This is the catch-all for what used to be BREAK (contract break with no
deprecation story) and SEC (auth-touching change with no threat narrative)
when the issue is "the plan doesn't address it at all" rather than "the
plan picks a tradeoff."

For each BLIND-SPOT item, REQUIRED:
  - blind_spot: name the missing piece using senior-eng vocabulary
  - future_debt: the incident, migration failure, or rewrite this implies
```

## SHAPE — Over-Engineering or Under-Engineering

```
Find places where the solution shape doesn't fit the problem shape.

OVER-ENGINEERED signals:
  - Microservice (or several) for a small bounded context
  - Event-driven pattern for CRUD-scale work
  - Indirection layers (adapters, generic repos, factories) with one
    use-site and no real variation
  - New queue, new cache, new service introduced when an existing
    component could absorb the work
  - "Modular Mirage": many small modules with hidden coupling via
    shared DB tables, shared utilities, or implicit ordering
  - Pattern cargo-culting (CQRS, hexagonal, event sourcing) without
    naming the property the pattern is buying

UNDER-ENGINEERED signals:
  - Missing idempotency on operations that will retry
  - Missing retries / circuit breakers / timeouts on cross-service calls
  - Missing dead-letter handling on async paths
  - Missing rate limiting on a publicly-exposed entry point
  - "Just a quick script" handling user-money / user-PII paths
  - One-pass migration where dual-write / verification is the norm

For each SHAPE item, REQUIRED:
  - blind_spot: name what's added without payoff OR what's missing
  - future_debt: ongoing operational cost OR the incident class implied
```

## FUTURE-DEBT — What Gets Harder Later

```
Find choices that paint the system into a corner — choices that look fine
today but compound in cost as the system grows. Look for:

  - Hardcoded assumptions about region, tenant, currency, locale,
    timezone, single-user, single-org
  - Vendor-specific feature embedded in domain logic (SDK calls,
    proprietary IDs, vendor-specific event shapes) with no abstraction
  - Cost curves that grow with usage (per-request vendor fees,
    storage growth, log volume) not modeled in the plan
  - Org-fit assumptions: "Team X will maintain this adapter forever",
    cross-team coordination that won't happen in practice
  - Coupling debt: shared library or shared schema used by N consumers
    that becomes a coordination bottleneck
  - Topology lock-in: sync RPC web that makes future async refactor
    very expensive

For each FUTURE-DEBT item, REQUIRED:
  - future_debt: the expanded-form narrative — what the world looks like
    in 6-12 months if this design ships and is successful
  - reversibility: usually `costly` or `one-way` — set accordingly

This category is the "future-you" axis. The pattern: a senior engineer
looks at the plan and asks "if this succeeds, what will we regret?"
```

## Cross-Category Heuristic

```
After producing items per category, scan once for items that hit two
categories. Common overlaps:

  - TRADEOFF + FUTURE-DEBT (a fork that locks in topology)
  - ASSUMPTION + SHAPE (assumption about scale that justifies the shape)
  - BLIND-SPOT + SHAPE (missing operational scaffolding makes the shape
    fragile)

When that happens, pick the category a senior would name FIRST — usually
the one closer to "did AI even consider this?" Put the other category in
notes ("also affects: SHAPE").
```

## Anti-Patterns to Drop

These items should be dropped at extraction time, NOT passed to the ranker:

- **Plan re-summarization.** "The plan adds a payments service." That's not an item, that's a summary. Items must surface something the plan does NOT make obvious.
- **Code-level findings.** "Function X should be renamed to Y." Re-cast at architect level or drop.
- **Best-practice reminders.** "Make sure to add input validation." AI follows common best practice in implementation; the human reads plan-level direction.
- **Speculation without anchor.** Items without an `evidence_anchor` (or `inferred from:` for `not_in_plan: true`) are speculation.
- **Padded categories.** If a category has zero real signal, leave it empty. Do NOT invent an item to fill the slot.

## Failure-Recovery Prompt (re-prompt on bad JSON or code-level slip)

```
Your previous output was either not valid JSON, did not conform to the
schema, OR contained code-level identifiers (function names, parameter
lists, field names, file paths) in narrative fields.

Re-emit using EXACTLY the schema in references/item-schema.md. JSON only,
no prose, no code fences. Re-cast any code-level finding at architect
level, or drop it.
```
