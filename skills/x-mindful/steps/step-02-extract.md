# Step 02 — Extract Impact Items

Goal: scan the plan and produce a list of items in four categories — ARCH, BREAK, SEC, PERF — using `references/item-schema.md`. Each item must be load-bearing: a decision the user should consciously approve, not a restatement of plan prose.

## Categories (extract all four; empty categories are fine)

| Code | Category | What to look for |
|---|---|---|
| ARCH | Architectural decisions | Tech-stack picks, pattern choices (event-driven, sync vs async, monolith vs split), data-store choices, framework upgrades, public-vs-internal boundary changes, new top-level modules |
| BREAK | Breaking changes | Renamed / removed / re-shaped public exports; schema migrations; URL or contract changes; behavior changes consumers rely on; protocol or wire-format changes |
| SEC | Security / auth | Auth flow changes, permission model shifts, new endpoints (especially unauthenticated), secret-handling shifts, new attack surface (file upload, deserialization, eval), CORS / CSRF / cookie changes, RLS or row-level access |
| PERF | Performance / cost | New hot paths, new I/O per request, missing index for a new query pattern, fan-out, full scans, backfills, scheduled jobs, queue depth shifts, cache invalidation, infra cost steps |

## Routing by Size Class (from Step 01)

Use the pinned capability set; if a primary route is unavailable, fall back to the next row.

| Size | Primary | Fallback (capability-aware) |
|---|---|---|
| Small | Claude direct (single turn) | — |
| Medium | Claude direct + `Agent: Explore` for cross-file evidence | Claude direct alone |
| Large | `omo-agent --model codex` (deep autonomous extraction) OR `oracle` if structured | `x-gemini` ingest → JSON-shaped extraction |
| XL | Already rejected in Step 01 | — |

When dispatching to OMO, attach the extraction prompt from `references/extraction-prompts.md` plus the JSON contract from `references/item-schema.md`. Demand JSON-only output.

## Evidence Requirement

Every extracted item MUST include:

- `evidence_anchor` — a short verbatim quote from the plan (or `pasted-content`) that justifies the item
- `not_in_plan` — `true` only when the item is a second-order impact the plan does not state but the change implies (e.g., plan says "add column X NOT NULL", impact item is "needs backfill before deploy"). Mark these honestly — they are the highest-value findings.

Items without evidence get dropped. No speculation without anchor.

## Cross-Cutting Heuristics

- **"No API change" claims:** any plan that says "internal-only refactor" still gets a BREAK pass that explicitly checks exports, public types, and OpenAPI / GraphQL schemas. Confirm or refute with `Grep` / `morph-mcp codebase_search`.
- **"Tiny migration" claims:** schema-changing plans always get BREAK + PERF entries (lock duration, rollback, dual-write window).
- **"Just behind a flag" claims:** flag rollouts need a SEC entry if the flagged code path bypasses existing checks, and a PERF entry if the flagged path adds load even at 0% rollout (initialization side effects).
- **Untested code paths:** if the plan touches code with no tests, add an ARCH item asking the user to consciously accept the risk OR add a TDD step.

## Per-Item Output Shape (mirror of `references/item-schema.md`)

```yaml
- id: ARCH-001            # category prefix + 3-digit number, monotonic per category
  category: ARCH | BREAK | SEC | PERF
  title: "<short imperative phrase>"
  proposed: "<what the plan proposes>"
  impact: "<what changes for users/operators/callers>"
  evidence_anchor: "<verbatim quote, ≤ 240 chars>"
  not_in_plan: false
  blast_radius:
    files: <int or 'unknown'>
    callers: <int or 'unknown'>
    services: <int or 'unknown'>
    surface: 'internal' | 'package' | 'service' | 'public'
  reversibility: 'reversible' | 'hard' | 'irreversible'
  severity_hint: 'CRITICAL' | 'HIGH' | 'MEDIUM' | 'LOW'   # extractor's first guess; ranker confirms
  alternatives: ['<optional alt 1>', '<optional alt 2>']  # may be empty
```

Ranker (Step 03) will recompute severity; the hint is just an extractor signal.

## Output of Step 02

In-memory list of items grouped by category. If a category yielded zero items, leave it empty — DO NOT pad. Pass to `step-03-rank.md`.
