# Extraction Prompts (per category)

Use these prompts in Phase 2. They work both for claude-direct extraction and for OMO dispatch (`oracle`, `--model codex`). When dispatching to OMO, append `references/item-schema.md` and the JSON output contract.

## Universal Preamble

```
You are extracting decision-grade impact items from a plan / spec / PRD.
Each item must be load-bearing — a decision the user should consciously
approve before code is written. DO NOT restate plan prose. Surface what
changes downstream that the plan does not make explicit.

Use the schema in references/item-schema.md. Output JSON only.
Empty categories are fine — DO NOT pad.

Plan content follows between <plan> tags.
```

## ARCH — Architectural Decisions

```
Find decisions about HOW the system is structured. Look for:
  - Pattern choices: sync vs async, monolith vs split, event-driven vs RPC
  - Data store choices: new DB, new queue, new cache, new file store
  - Public-vs-internal boundary changes (new exported surface, dropped surface)
  - Framework or major-version dependency upgrades
  - New top-level modules or packages
  - Cross-cutting concerns: logging, tracing, feature flags, config strategy

For each decision, record the alternatives the plan rejected (or did not
consider). If alternatives are missing, set alternatives: [] and add a note.

Skip decisions that are purely local (one function rewrite, one file move).
```

## BREAK — Breaking Changes

```
Find changes that break a contract a consumer relies on. Look for:
  - Renamed / removed / re-shaped exported symbols (functions, types, constants)
  - Schema migrations: column adds with NOT NULL, drops, type changes,
    constraint changes, default changes
  - URL / route changes; HTTP method changes; status-code changes
  - Wire format / protocol / serialization changes
  - Behavior changes consumers depend on (timing, ordering, idempotency)
  - CLI flag changes; env var renames; config-file shape changes

Even when the plan says "internal-only refactor, no API change", run the
exports check anyway. List anything moved across the public boundary.
```

## SEC — Security / Auth

```
Find changes that affect the security or auth posture. Look for:
  - Auth flow changes (login, refresh, session, 2FA)
  - Permission model changes (RBAC roles added / removed, RLS policy changes)
  - New endpoints — flag any that lack an auth annotation
  - Secret handling: new secrets, new vaults, new rotation needs
  - New attack surface: file uploads, deserialization, eval, shell-out, SQL
    string interpolation, raw HTML rendering
  - CORS / CSRF / cookie attributes / SameSite / HSTS changes
  - Tenant isolation: cross-tenant query risk, shared cache keys, shared
    file paths

Flag any "behind a feature flag" claim that bypasses existing checks even
at 0% rollout.
```

## PERF — Performance / Cost

```
Find changes that move performance or infra cost in a non-obvious way. Look for:
  - New hot paths or new I/O per request
  - New query patterns missing an index
  - Fan-out, full scans, backfills
  - New scheduled jobs / crons / queues
  - Cache strategy changes (new cache, removed cache, invalidation gap)
  - Memory or CPU steps (new in-memory cache, new event loop work)
  - Cost cliffs: new managed services, new egress, new storage tiers
  - Initialization side effects (loaded even at 0% flag rollout)

Flag any "tiny migration" claim that touches > 1M rows or holds a write
lock — these need explicit rollback plans.
```

## Cross-Category Heuristic

```
After producing items per category, scan once for cross-category items.
A schema change is often BREAK + PERF + SEC simultaneously (contract,
backfill cost, RLS implications). When that happens, split into one
item per category and cross-reference in notes.
```

## Failure-Recovery Prompt (re-prompt on bad JSON)

```
Your previous output was not valid JSON or did not conform to the schema.
Re-emit using EXACTLY the schema in references/item-schema.md. JSON only,
no prose, no code fences.
```
