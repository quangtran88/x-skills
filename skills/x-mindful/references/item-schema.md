# Item Schema (v2 — architect-review taxonomy)

Every extracted impact item conforms to this YAML shape. The schema is intentionally **architect-level**: no function names, no parameter lists, no field names, no file paths. If you can't say it without code-level identifiers, re-cast it or drop it.

```yaml
id: TRADEOFF-001                # required, ^(TRADEOFF|ASSUMPTION|BLIND-SPOT|SHAPE|FUTURE-DEBT)-\d{3}$
category: TRADEOFF              # required, one of the five categories below
title: "Picked async event-driven inventory propagation"   # required, ≤ 80 chars

# Architect-level narrative — NO code-level identifiers
what_ai_did: |                  # required, ≤ 240 chars
  Replaced the synchronous inventory write path with a message-bus
  publish; consumers project state asynchronously.

tradeoff_picked: |              # required for TRADEOFF; optional for others
  Optimized for write-path throughput; took on eventual-consistency cost
  on the read path and a new operational surface (broker + consumer lag).

assumption: |                   # required for ASSUMPTION; optional for others
  Assumes traffic volume justifies a message bus and that consumers can
  tolerate out-of-order events. Neither claim is stated in the plan.

blind_spot: |                   # required for BLIND-SPOT and SHAPE; optional for others
  No failure-mode narrative for broker outage; no consumer back-pressure
  story; no read-after-write guarantee for the UI; no owner named for
  the new broker or its dashboards.

alternatives: |                 # required for TRADEOFF; optional for others
  - Outbox pattern — keep sync write, emit event in same DB transaction
  - CDC from the inventory table — zero service-side change
  - Stay synchronous, add caching for read amplification

future_debt: |                  # required for ALL items, ≤ 240 chars
  Backing out of the message bus once N consumers exist is months of work.
  Stale-read debugging across consumers will be a recurring 3am issue.

evidence_anchor: |              # required, ≤ 240 chars, verbatim quote
  "We will switch the inventory write path to event-driven (kafka topic
  inventory.updated) in Phase 2."
not_in_plan: false              # required boolean; true when entirely second-order

severity: HIGH                  # required, CRITICAL | HIGH | MEDIUM (extractor's first guess; ranker recomputes)
reversibility: costly           # required, reversible | costly | one-way
surface: service                # required, internal | service | public
scope_note: |                   # required, ≤ 160 chars; 1-line narrative
  Affects 3 downstream consumers and every UI surface reading inventory.

senior_weigh_in: true           # required, boolean — see Filter Rule below

notes: ""                       # optional, free-form, ≤ 240 chars
```

## The Five Categories

| Category | What it surfaces |
|---|---|
| **TRADEOFF** | A fork in the road. AI picked side X without naming the cost on the other axis (cost, blast radius, reversibility, on-call burden, vendor lock-in, second-order effects, build-vs-buy, sync-vs-async, monolith-vs-split). |
| **ASSUMPTION** | A load-bearing claim AI silently relied on (scale, NFRs, environment, human capacity, "this won't exceed X", trust boundaries). |
| **BLIND-SPOT** | What's NOT in the plan that a senior reviewer would expect (failure modes, rollback strategy, observability, migration safety, runbook, owner team, threat model). Includes what used to be BREAK and SEC when there's no mitigation story. |
| **SHAPE** | The solution shape doesn't fit the constraints. Either **over-engineered** (modular mirage, premature abstraction, microservice for a tiny domain, indirection without variability) or **under-engineered** (missing idempotency, retries, observability, dead-letter handling). |
| **FUTURE-DEBT** | What gets harder later — paints-into-corner choices, hardcoded region/tenant/currency, deep vendor coupling, coupling debt, cost curves that grow with usage, org-fit assumptions that won't hold. |

If an item fits two categories, pick the one a senior would name *first* — usually the one closer to "did AI even consider this?"

## Hard Rule: No Code-Level Details

**Drop or re-cast** any item whose `title`, `what_ai_did`, or other narrative field reaches for:

- Function names, method names, class names
- Parameter lists, return types, field names
- File paths, line numbers, module imports
- Variable names, constant values, SQL column names

The human is reviewing direction, not implementation. AI follows common best practice when picking names; that's not what the human needs to weigh in on.

**Re-cast examples:**

| ❌ Code-level | ✅ Architect-level |
|---|---|
| `Rename getUser() → fetchUser()` | `Break a public function-call contract used by external consumers` |
| `Add column users.legacy_id NOT NULL` | `Schema migration with no backfill or rollback path` |
| `Replace axios with fetch in apiClient.ts` | `Swap HTTP client library — no behavioral parity check against existing retries` |
| `Set timeout=5000 in checkoutHandler` | `Pick a hard timeout for a user-facing payment flow — no degradation path` |

## Filter Rule: `senior_weigh_in`

Every item must declare `senior_weigh_in: true | false`. The ranker (Step 03) drops items with `false`. An item earns `true` only when a senior staff/principal engineer would want to weigh in on the direction — not just the implementation.

Set `senior_weigh_in: false` when:

- The decision is purely local (one file, one function, no contract crossed)
- The "tradeoff" is between two equivalent best-practice options where AI's pick is fine either way
- The "blind spot" is something AI's own best practice would catch in implementation (input validation, error handling, log levels)
- The item is a restatement of plan prose with no second-order signal

Set `senior_weigh_in: true` when:

- The decision shapes how the system fails, scales, or evolves
- The decision crosses a team / service / public boundary
- The decision is hard to reverse later
- The blind spot would cost a real on-call incident, migration failure, or rewrite
- A reasonable senior engineer might choose differently and the choice matters

## Field Rules

- `id` — monotonic within category prefix. Reserved bundle id: `LOW-bundle` (used by ranker only).
- `category` — exactly one. An item that hits two categories must be split, with cross-references in `notes`.
- `title` — imperative, architect-level, no trailing period.
- `what_ai_did` — what the plan proposes, expressed at architect level. Strip identifiers.
- `tradeoff_picked` — the dimension AI optimized + what cost it accepted. This is the highest-signal field for TRADEOFF items.
- `assumption` — the load-bearing claim. State it as AI would have to defend it. "Assumes that …".
- `blind_spot` — the thing a senior expects but the plan doesn't address. Use senior-eng vocabulary: failure mode, rollback, observability, runbook, owner, threat model.
- `alternatives` — 1-3 *real* options AI didn't surface (not strawmen).
- `future_debt` — "what gets harder later." Architect framing, not code framing.
- `evidence_anchor` — verbatim plan quote. For `not_in_plan: true`, prefix with `inferred from:` and quote the nearest related text.
- `reversibility` —
  - `reversible`: revert restores prior behavior in < 1 day
  - `costly`: multi-day rollback, data migration forward then back, coordinated multi-service deploy, stakeholder sign-off
  - `one-way`: data loss, dropped columns, deleted resources, published events consumed by others, sent emails / webhooks, rotated keys without backup
- `surface` — the widest boundary the change crosses (not where code lives).
- `scope_note` — 1-line architect narrative of what's affected. NO file counts, caller counts, or service counts as the only content — use words ("affects 3 downstream consumers and the UI read path") not numbers in isolation.
- `severity` — extractor's first guess; ranker (Step 03) recomputes against the rubric. Do not let the hint anchor the ranker.

## JSON Variant (for OMO agents)

When dispatching to OMO `--model codex` or `oracle`, demand the same fields in JSON. Output contract:

```json
{
  "items": [
    {
      "id": "TRADEOFF-001",
      "category": "TRADEOFF",
      "title": "...",
      "what_ai_did": "...",
      "tradeoff_picked": "...",
      "assumption": "",
      "blind_spot": "",
      "alternatives": "...",
      "future_debt": "...",
      "evidence_anchor": "...",
      "not_in_plan": false,
      "severity": "HIGH",
      "reversibility": "costly",
      "surface": "service",
      "scope_note": "...",
      "senior_weigh_in": true,
      "notes": ""
    }
  ]
}
```

Empty strings for fields that aren't required by the item's category are acceptable.

Reject any output that is not valid JSON or contains code-level identifiers in the narrative fields — re-prompt once with the schema + the Hard Rule above, then fall back to claude-direct extraction.
