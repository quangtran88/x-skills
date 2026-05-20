# Step 02 — Extract Architect-Review Items

Goal: scan the plan and produce a list of items in five categories — TRADEOFF / ASSUMPTION / BLIND-SPOT / SHAPE / FUTURE-DEBT — using `references/item-schema.md`. Each item must be load-bearing for a senior reviewer; mechanical or code-level findings are dropped.

## Hard Rule — No Code-Level Details

Before extracting, internalize: **the human is reviewing architectural direction, not implementation.** AI follows common best practice when picking function names, parameters, fields, and file structure. The human doesn't need to weigh in on those.

Drop or re-cast any candidate item whose narrative reaches for:

- Function names, method names, class names
- Parameter lists, return types, field names, SQL column names
- File paths, line numbers, module imports
- Variable names, constant values

If you can only describe the issue using an identifier, re-cast at architect level ("breaks a public function-call contract") or drop the item. Items containing code-level identifiers in `title`, `what_ai_did`, `tradeoff_picked`, `assumption`, `blind_spot`, `alternatives`, or `future_debt` are rejected by the schema and forced through a re-prompt.

## Categories (extract all five; empty categories are fine — DO NOT pad)

| Code | Category | What to look for |
|---|---|---|
| TRADEOFF | Forks in the road AI picked silently | Sync vs async; monolith vs split; build vs buy; vendor-specific vs portable; pattern picks (microservices, event sourcing, CQRS) without naming the workload property they're buying; one-way vs two-way door choices |
| ASSUMPTION | Load-bearing claims never stated | NFRs (scale, latency, availability) guessed or omitted; environment assumptions (cloud features, single region); trust boundaries; human capacity (on-call, ramp); "this won't exceed N" claims |
| BLIND-SPOT | What a senior expects but the plan skips | Failure modes, rollback / back-out, observability, runbook & owner, migration safety, threat model, recovery story, backpressure / degradation. Covers what v1 called BREAK + SEC when the issue is "no narrative" |
| SHAPE | Over- or under-engineering | Modular Mirage, microservice for tiny domain, indirection without variability, pattern cargo-culting, OR missing idempotency / retries / dead-letter / rate limiting |
| FUTURE-DEBT | What gets harder later | Hardcoded region/tenant/currency; deep vendor coupling in domain logic; cost curves that grow with usage; coupling debt; topology lock-in; org-fit assumptions |

Full per-category prompts live in `references/extraction-prompts.md` — use them verbatim when dispatching to claude-direct or OMO.

## GitNexus capability gate (optional)

If `mcp.gitnexus` is in the active capability set AND the plan touches existing symbols (rename / move / signature change / contract shift), call `gitnexus impact({target: <symbol>, direction: "upstream"})` for each named symbol BEFORE extracting BLIND-SPOT items. The graph result informs `scope_note` and the `surface` field — translate it to architect-level language ("affects 3 downstream consumers and the read path") rather than copying caller counts verbatim. Skip this preflight when the plan only adds new code with no upstream dependents.

This gate informs blast-radius for TRADEOFF and BLIND-SPOT items only. ASSUMPTION, SHAPE, and FUTURE-DEBT are judgment calls about the plan itself — gitnexus doesn't help.

## Routing by Size Class (from Step 01)

Use the pinned capability set; if a primary route is unavailable, fall back to the next row.

| Size | Primary | Fallback (capability-aware) |
|---|---|---|
| Small | Claude direct (single turn) | — |
| Medium | Claude direct + `Agent: Explore` for cross-file evidence | Claude direct alone |
| Large | `omo-agent --model codex` (deep autonomous extraction) OR `oracle` if structured | `x-gemini` ingest → JSON-shaped extraction |
| XL | Already rejected in Step 01 | — |

When dispatching to OMO, attach the extraction prompts from `references/extraction-prompts.md` plus the JSON contract from `references/item-schema.md`. Demand JSON-only output AND no-code-level-identifiers as hard constraints.

## Evidence Requirement

Every extracted item MUST include:

- `evidence_anchor` — a short verbatim quote from the plan (or `pasted-content`) that justifies the item
- `not_in_plan` — `true` only when the item is a second-order impact the plan does not state but the change implies (e.g., plan picks event-driven without mentioning consumer back-pressure; the BLIND-SPOT item is "no consumer back-pressure story"). Mark these honestly — they are the highest-value findings.

Items without evidence get dropped. No speculation without anchor.

## Cross-Cutting Heuristics

- **"No API change" claims:** any plan that says "internal-only refactor" still gets a BLIND-SPOT pass that explicitly checks for crossed boundaries (public exports, OpenAPI/GraphQL schemas, published events). Confirm or refute with `Grep` / `morph-mcp codebase_search`.
- **"Tiny migration" claims:** schema-changing plans always get a BLIND-SPOT entry (rollback story, dual-write, verification) AND a FUTURE-DEBT entry if the schema becomes load-bearing.
- **"Just behind a flag" claims:** flag rollouts need a BLIND-SPOT entry if the flagged code path bypasses existing checks (threat model), and a SHAPE entry if the flagged path adds load even at 0% rollout (initialization side effects).
- **Pattern-name without justification:** any time the plan names a pattern (microservices, event sourcing, CQRS, hexagonal, k8s, Kafka, serverless) without naming the workload property it's buying, emit a TRADEOFF item.
- **Numbers-free scale claims:** "high-traffic", "low-volume", "small dataset" without numbers → ASSUMPTION item.

## Senior-Weigh-In Filter (set during extraction)

Every item carries `senior_weigh_in: true | false`. Set it during extraction, not after — the extractor sees the most context. Set `true` only when at least one of:

- The choice shapes how the system fails, scales, or evolves
- The choice crosses a team / service / public boundary
- The choice is `costly` or `one-way` to reverse
- The blind spot would cost a real on-call incident, migration failure, or rewrite
- A reasonable senior engineer might choose differently and it matters

The ranker (Step 03) drops `false` items. Target output: 5-12 `true` items per plan. If you produce more than 20, re-apply the filter more strictly.

## Per-Item Output Shape (mirror of `references/item-schema.md`)

```yaml
- id: TRADEOFF-001
  category: TRADEOFF | ASSUMPTION | BLIND-SPOT | SHAPE | FUTURE-DEBT
  title: "<short architect-level imperative phrase>"
  what_ai_did: "<architect-level — NO identifiers>"
  tradeoff_picked: "<required for TRADEOFF; else optional>"
  assumption: "<required for ASSUMPTION; else optional>"
  blind_spot: "<required for BLIND-SPOT and SHAPE; else optional>"
  alternatives: "<required for TRADEOFF; else optional>"
  future_debt: "<required for ALL items>"
  evidence_anchor: "<verbatim quote, ≤ 240 chars>"
  not_in_plan: false
  severity: 'CRITICAL' | 'HIGH' | 'MEDIUM'    # extractor's first guess; ranker confirms
  reversibility: 'reversible' | 'costly' | 'one-way'
  surface: 'internal' | 'service' | 'public'
  scope_note: "<1-line architect narrative, no file/caller counts in isolation>"
  senior_weigh_in: true | false
```

Ranker (Step 03) will recompute severity; the hint is just an extractor signal.

## Output of Step 02

In-memory list of items grouped by category. If a category yielded zero items, leave it empty — DO NOT pad. Pass to `step-03-rank.md`.
