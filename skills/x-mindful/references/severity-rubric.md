# Severity Rubric

x-mindful uses the shared severity scale (`../../x-shared/severity-guide.md`) but adds gating-specific qualifiers. The ranker in Step 03 must apply this rubric — extractor hints are advisory only.

## Severity Definitions (gate-tuned)

| Severity | Qualifies when ANY of … |
|---|---|
| **CRITICAL** | Data loss path · Auth / authz bypass · Public contract break that cannot be hidden behind a deprecation alias · Irreversible migration with no documented rollback · Secret exposure · Cross-tenant data leak |
| **HIGH** | Cross-service or cross-package contract break (even if reversible) · New attack surface (file upload, deserialization, eval, dynamic SQL) · Cost cliff (estimated > 1.5× current spend) · Shared-state change with concurrent-write risk · Auth-adjacent change (cookie attrs, CORS, CSRF) without a security review |
| **MEDIUM** | Internal-package interface change with multiple callers · Schema change with reversible deploy · Perf regression possible but bounded · New scheduled job · Non-trivial new dependency |
| **LOW** | Local cleanup confined to one module · Dependency-version bump with no API change · Test-only changes · Logging / tracing additions |

## Reversibility Definitions

| Level | Examples |
|---|---|
| **reversible** | Behind a feature flag at 0%; pure code revert restores prior behavior; config change with documented rollback |
| **hard** | Requires migrating data forward then back; coordinated multi-service deploy; needs stakeholder sign-off; > 1 day rollback window |
| **irreversible** | Dropped columns / tables; deleted external resource; broken external integration; published-and-consumed event schema; sent emails / webhooks; rotated keys without backup |

## Score Formula (mirrored from Step 03)

```
score = severity_weight × surface_weight × reversibility_weight
severity:    CRITICAL=8, HIGH=4, MEDIUM=2, LOW=1
surface:     public=4, service=3, package=2, internal=1
reversibility: irreversible=3, hard=2, reversible=1
range:       [1, 96]
```

## Worked Examples

| Item | Sev | Surface | Rev | Score | Why |
|---|---|---|---|---|---|
| Drop `users.legacy_id` column | CRITICAL | service | irreversible | 96 | Data loss + irreversible + public-DB |
| Rename `getUser` → `fetchUser` (no alias) | HIGH | public | hard | 32 | Public consumer break, partial recovery via republish |
| Add Redis cache for product list | MEDIUM | service | reversible | 6 | New cache layer, can be removed |
| Switch UUIDs to ULIDs in new tables | LOW | internal | reversible | 1 | Greenfield, contained |
| Move auth check to middleware | HIGH | service | reversible | 12 | Auth-adjacent, but flag-gated rollout |
| Add `X-Tenant-Id` requirement to all APIs | CRITICAL | public | hard | 64 | Cross-tenant break, hard rollback |

## Severity Inflation Guard

If extraction produces > 30% of items at CRITICAL, the rubric is mis-applied. Re-rank with strict CRITICAL gating: only items that hit a CRITICAL qualifier above keep the label. Demote the rest to HIGH.

## Pruning Threshold

After scoring, items with `score < 2 AND category != SEC` get bundled into the trailing `LOW-bundle` — the user can confirm-all in one tap rather than waste turns on cleanup-tier items. SEC items never bundle, even at LOW severity.
