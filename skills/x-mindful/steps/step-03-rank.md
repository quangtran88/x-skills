# Step 03 — Filter & Rank Items

Goal: drop items below the senior-weigh-in threshold, then order the survivors so the user reviews the most consequential decisions first.

Use the rubric in `references/severity-rubric.md`. Compute a score per surviving item and sort descending. Ties break by category priority then reversibility.

## Filter Pass (HARD GATE)

Apply BEFORE scoring:

1. **`senior_weigh_in: false` → drop unconditionally.** No score, no queue, no envelope appearance.
2. **Code-level identifier in any narrative field → drop or re-prompt extraction.** No code-level items reach the user.
3. **No evidence_anchor → drop.** Speculation without quote is dropped.
4. **Duplicate (same `what_ai_did` text, different `id`) → keep the highest-severity, drop the rest, note merged ids.**

Target survivor count: **5-12 items.** If you have more than 15 after filtering, re-apply the senior-weigh-in filter more strictly — most plans don't have 15 senior-grade decisions and a long queue makes the user skim and rubber-stamp.

If you have zero survivors, render a "no senior-grade decisions found — direction looks routine" message instead of an empty queue and let the user override with `--no-filter` (recover all items including `senior_weigh_in: false`).

## Score Formula

```
score = severity_weight × surface_weight × reversibility_weight
```

Weights:

| Field | Value | Weight |
|---|---|---|
| severity | CRITICAL | 8 |
|  | HIGH | 4 |
|  | MEDIUM | 2 |
| surface | public | 4 |
|  | service | 3 |
|  | internal | 1 |
| reversibility | one-way | 3 |
|  | costly | 2 |
|  | reversible | 1 |

Final integer score in `[2, 96]`. (No LOW tier — those items are filtered before scoring.)

## Severity Re-evaluation

The extractor produced a `severity` hint. Recompute it here using the rubric so extractor-bias does not bleed through:

- **CRITICAL** requires at least one of: data-loss path, authentication / authorization bypass, public-contract break with no deprecation path, one-way migration without a documented rollback, secret exposure, cross-tenant data leak, vendor or topology lock-in on a mission-critical path
- **HIGH** when the change crosses a service / package boundary OR introduces a new attack surface OR a non-obvious cost cliff OR is a pattern pick without justification OR is a Modular Mirage
- **MEDIUM** for internal contract shifts, contained perf regressions, schema changes with reversible deploys, single-surface tradeoffs where reasonable engineers might disagree

If the recomputed severity differs from the hint, log the change in the item as `severity_changed_from_hint: <old>` for transparency in the final envelope.

## Tiebreakers (apply in order)

1. Higher severity wins
2. `one-way` outranks `costly` outranks `reversible` (for equal severity)
3. Wider surface (`public` > `service` > `internal`)
4. Category priority: BLIND-SPOT > TRADEOFF > ASSUMPTION > SHAPE > FUTURE-DEBT (BLIND-SPOT first because missing safety nets cause real incidents fastest; FUTURE-DEBT last because it's slower-burning)
5. Lexical id ascending (stable sort)

## Bundling (rare)

If extraction returned 5+ items in a single category at MEDIUM severity that are all the same KIND of issue (e.g., five separate "new scheduled job without runbook" SHAPE items), bundle them into one item titled "Operational scaffolding missing across N new jobs/services" with a `scope_note` listing the affected components. One walkthrough turn covers them all.

Otherwise: no bundling. The `senior_weigh_in` filter does the volume reduction the old `LOW-bundle` used to do.

## Output of Step 03

Ranked queue in-memory:

```json
{
  "queue": [
    { "id": "BLIND-SPOT-001", "score": 96, "...": "..." },
    { "id": "TRADEOFF-001", "score": 64, "...": "..." },
    { "id": "FUTURE-DEBT-001", "score": 36, "...": "..." }
  ],
  "filtered_out": {
    "senior_weigh_in_false": 8,
    "code_level_dropped": 2,
    "no_evidence": 1,
    "duplicate_merged": 0
  },
  "summary": {
    "counts": { "CRITICAL": 1, "HIGH": 3, "MEDIUM": 4 },
    "by_category": { "TRADEOFF": 2, "ASSUMPTION": 1, "BLIND-SPOT": 3, "SHAPE": 1, "FUTURE-DEBT": 1 }
  }
}
```

Pass to `step-04-walkthrough.md`.

## What the User Sees Before Phase 4 Starts

Render a one-screen pre-flight summary so the user knows what's coming. Include filter transparency.

```
x-mindful — 8 items for architect-level review
  Severity:  CRITICAL: 1   HIGH: 3   MEDIUM: 4
  Category:  TRADEOFF 2 · ASSUMPTION 1 · BLIND-SPOT 3 · SHAPE 1 · FUTURE-DEBT 1
  Filtered:  8 items dropped below senior-weigh-in threshold · 2 dropped as code-level

Walking the queue most-important-first.
Per item:  [c]onfirm · [m]odify · [r]eject · [s]kip · [q]uit
```

Then enter Phase 4 (which opens with the "Plan at Architect Level" 5-bullet framing per `references/walkthrough-menu.md`).
