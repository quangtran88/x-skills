# Step 03 — Rank Items by Importance

Goal: order the extracted items so the user reviews the most consequential decisions first.

Use the rubric in `references/severity-rubric.md`. Compute a score per item and sort descending. Ties break by category priority then irreversibility.

## Score Formula

```
score = severity_weight × blast_radius_weight × reversibility_weight
```

Weights:

| Field | Value | Weight |
|---|---|---|
| severity | CRITICAL | 8 |
|  | HIGH | 4 |
|  | MEDIUM | 2 |
|  | LOW | 1 |
| blast_radius.surface | public | 4 |
|  | service | 3 |
|  | package | 2 |
|  | internal | 1 |
| reversibility | irreversible | 3 |
|  | hard | 2 |
|  | reversible | 1 |

Final integer score in `[1, 96]`.

## Severity Re-evaluation

The extractor produced a `severity_hint`. Recompute it here using the rubric so reviewer-pressure or extractor-bias does not bleed through:

- **CRITICAL** requires at least one of: data loss path, authentication / authorization bypass, public contract break, irreversible migration without a documented rollback
- **HIGH** when the change crosses a service / package boundary OR introduces a new attack surface OR a non-obvious cost cliff
- **MEDIUM** for internal interface shifts, contained perf regressions, schema changes with reversible deploys
- **LOW** for local cleanup confined to one module with no external callers

If the recomputed severity differs from the hint, log the change in the item as `severity_changed_from_hint: <old>` for transparency in the final envelope.

## Tiebreakers (apply in order)

1. Higher severity wins
2. `irreversible` outranks `hard` outranks `reversible` (for equal severity)
3. Wider surface (`public` > `service` > `package` > `internal`)
4. Category priority: SEC > BREAK > ARCH > PERF (tunable later, but security comes first when else is equal)
5. Lexical id ascending (stable sort)

## Pruning

After ranking, prune:

- Items the score formula assigns `< 2` AND `category != SEC` — too small to be worth the gate. Bundle them into a single trailing `LOW-bundle` item the user can confirm-all-at-once.
- Duplicate items (same `proposed` text, different `id`) — keep the highest-scoring, drop the rest, note merged ids.

## Output of Step 03

Ranked queue in-memory:

```json
{
  "queue": [
    { "id": "SEC-002", "score": 96, "...": "..." },
    { "id": "BREAK-001", "score": 64, "...": "..." },
    { "id": "ARCH-003", "score": 24, "...": "..." }
  ],
  "low_bundle": [
    { "id": "PERF-004", "title": "...", "score": 1 }
  ],
  "summary": {
    "counts": { "CRITICAL": 1, "HIGH": 2, "MEDIUM": 4, "LOW": 3 },
    "by_category": { "ARCH": 3, "BREAK": 2, "SEC": 1, "PERF": 4 }
  }
}
```

Pass to `step-04-walkthrough.md`.

## What the User Sees Before Phase 4 Starts

Render a one-screen pre-flight summary so the user knows what's coming:

```
x-mindful — 7 items extracted
  CRITICAL: 1   HIGH: 2   MEDIUM: 4   LOW: 3 (bundled)
  by category: ARCH 3 · BREAK 2 · SEC 1 · PERF 4

Walking the queue most-important-first. For each item: [c]onfirm · [m]odify · [r]eject · [s]kip · [q]uit
```

Then enter Phase 4.
