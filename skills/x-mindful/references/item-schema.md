# Item Schema (v1)

Every extracted impact item conforms to this YAML shape. Required fields fail extraction if missing.

```yaml
id: ARCH-001                    # required, ^(ARCH|BREAK|SEC|PERF)-\d{3}$
category: ARCH                  # required, one of: ARCH | BREAK | SEC | PERF
title: "Adopt event-driven inventory updates"   # required, ≤ 80 chars, imperative
proposed: |                     # required, ≤ 400 chars, what the plan says
  Replace the synchronous PATCH /inventory call with a publish to
  inventory.updated and let consumers project state asynchronously.
impact: |                       # required, ≤ 600 chars, what changes downstream
  - Consumers must handle out-of-order events and idempotency
  - Read-after-write becomes eventually consistent
  - Existing /inventory GET callers may see stale data
evidence_anchor: |              # required, ≤ 240 chars, verbatim quote from plan
  "We will switch the inventory write path to event-driven (kafka topic
  inventory.updated) in Phase 2."
not_in_plan: false              # required boolean; true when the item is a second-order impact
blast_radius:                   # required
  files: 14                     # int or 'unknown'
  callers: 6                    # int or 'unknown'
  services: 3                   # int or 'unknown'
  surface: service              # required, one of: internal | package | service | public
reversibility: hard             # required, one of: reversible | hard | irreversible
severity_hint: HIGH             # required, one of: CRITICAL | HIGH | MEDIUM | LOW
alternatives:                   # optional, list of strings
  - "Outbox pattern — write event in same DB transaction"
  - "CDC from inventory table — no service code change"
notes: ""                       # optional, free-form, ≤ 240 chars
```

## Field Rules

- `id` — monotonic within its category prefix. Reserved bundle id: `LOW-bundle` (used by ranker only).
- `category` — exactly one. An item that hits two categories must be split into two items with cross-references in `notes`.
- `title` — imperative, no trailing period. Keep it grep-friendly.
- `proposed` — what the plan says verbatim or a faithful one-paragraph summary. No editorializing.
- `impact` — what *changes* for callers, operators, end-users, or future maintainers. This is the load-bearing field — most failures live here.
- `evidence_anchor` — quoted plan text. If the item is `not_in_plan: true`, anchor to the closest related quote and prefix with `inferred from:`.
- `blast_radius.surface` — match the widest boundary the change crosses, not where the code lives.
- `reversibility` —
  - `reversible`: can roll back with a config flip or a code revert in < 1 day
  - `hard`: rollback requires migrating data forward then back, coordinated deploys, or stakeholder sign-off
  - `irreversible`: data loss, deleted columns, dropped contracts, broken external integrations
- `severity_hint` — extractor's first guess; ranker (Step 03) recomputes against the rubric. Do not let the hint anchor the ranker.

## JSON Variant (for OMO agents)

When dispatching to OMO `--model codex` or `oracle`, demand the same fields in JSON. Output contract:

```json
{
  "items": [
    {
      "id": "...",
      "category": "...",
      "title": "...",
      "proposed": "...",
      "impact": "...",
      "evidence_anchor": "...",
      "not_in_plan": false,
      "blast_radius": { "files": 0, "callers": 0, "services": 0, "surface": "..." },
      "reversibility": "...",
      "severity_hint": "...",
      "alternatives": [],
      "notes": ""
    }
  ]
}
```

Reject any output that is not valid JSON — re-prompt once with the schema, then fall back to claude-direct extraction.
