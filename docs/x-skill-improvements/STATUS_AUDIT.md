# x-skill-improvements Status Audit

> **Audit date:** 2026-05-04  
> **Auditor:** Sisyphus  
> **Scope:** Compare `docs/x-skill-improvements/` claims against actual skill files in `skills/`

---

## Executive Summary

**Status: PARTIALLY RESOLVED, NOT OUTDATED.**

All 7 proposals were applied to the degree claimed in `00-overview.md`. However, **significant deferred work remains** — particularly the full rollout of `role:`, `slots:`, and `reactions:` frontmatter to skills beyond x-do/x-review, and Phase 2 of the reactions execution contract. The docs accurately track this state; nothing is stale.

---

## Proposal-by-Proposal Verification

### 01 — Stagnation Detection (`applied 2026-04-09`)

| Claim | Evidence | Status |
|-------|----------|--------|
| `iteration-patterns.md` §2 updated | `skills/x-do/references/iteration-patterns.md` exists | ✅ |
| `delegation-and-scaling.md` aligned | Referenced in x-do SKILL.md | ✅ |
| `x-bugfix/SKILL.md` 3-Strike Rule aligned | x-bugfix has Instrumentation Pivot + 3-Strike Rule | ✅ |

**Verdict:** Fully applied. No drift.

---

### 02 — Reactions Block (`Phase 1 pilot applied 2026-04-19`, x-do only)

| Claim | Evidence | Status |
|-------|----------|--------|
| `reactions:` frontmatter on x-do | `skills/x-do/SKILL.md` lines 8-45 | ✅ |
| `reactions-vocabulary.md` created | `skills/x-shared/reactions-vocabulary.md` exists | ✅ |
| Phase 2 (execution contract) shipped | No evidence in any skill | ⏳ DEFERRED |
| Rollout to 3+ skills | Only x-do has `reactions:` | ⏳ DEFERRED |

**Verdict:** Phase 1 applied exactly as claimed. Phase 2 explicitly deferred per overview § "If 02 Phase 2 never ships, these two gaps remain open." Doc is honest about this.

---

### 03 — Orchestration Primitives (`applied 2026-04-19`, Part A only)

| Claim | Evidence | Status |
|-------|----------|--------|
| Part A: `handoff`/`assign` in `invocation-guide.md` | `skills/x-shared/invocation-guide.md` lines 95-163 | ✅ |
| Part B: Per-skill retrofit | Only x-do references primitives inline | ⏳ DEFERRED |
| Part C: `x-skill-review` checklist | Skill lives outside repo | ⏳ DEFERRED |

**Verdict:** Part A applied. B and C deferred as documented.

---

### 04 — Role Separation (`applied 2026-04-09`, pilot only)

| Claim | Evidence | Status |
|-------|----------|--------|
| `role: router` on x-do | `skills/x-do/SKILL.md` line 4 | ✅ |
| `role: reviewer` on x-review | `skills/x-review/SKILL.md` line 4 | ✅ |
| `role: verifier` on x-verify | `skills/x-verify/SKILL.md` line 4 | ✅ |
| Full rollout to remaining skills | **MISSING** — no `role:` on: x-research, x-bugfix, x-design, x-api-pentest, x-omo, x-gemini, x-skill-improve | ⏳ DEFERRED |

**Verdict:** Pilot applied (3 skills). Full rollout to 7 remaining skills is Tier 3 deferred work.

---

### 05 — Plugin Slots (`applied 2026-04-19`, v1 x-do only)

| Claim | Evidence | Status |
|-------|----------|--------|
| `slot-schema.md` created | `skills/x-shared/slot-schema.md` exists | ✅ |
| `slots:` block on x-do (`workspace`, `verifier`) | `skills/x-do/SKILL.md` lines 5-7 | ✅ |
| Slot Resolution section in `invocation-guide.md` | `skills/x-shared/invocation-guide.md` lines 164-197 | ✅ |
| v2: Project overrides via `CLAUDE.md` | No evidence | ⏳ DEFERRED |
| Rollout to other skills (model, reviewer, executor, planner slots) | Only x-do emits slots | ⏳ DEFERRED |

**Verdict:** v1 applied exactly as claimed. v2 and rollout deferred.

---

### 06 — State Detection Cascade (`applied 2026-04-19`, initial ship x-do only)

| Claim | Evidence | Status |
|-------|----------|--------|
| `completion-cascade.md` created | `skills/x-shared/completion-cascade.md` exists | ✅ |
| `x-verify/SKILL.md` created | `skills/x-verify/SKILL.md` exists | ✅ |
| x-do Completion section dispatches x-verify | `skills/x-do/SKILL.md` lines 69-91 | ✅ |
| Hard-coded `code-reviewer` fallback (intermediate state) | `completion-cascade.md` line 65: "hard-coded target; retrofit to the verifier slot is a deferred follow-up" | ✅ |
| Rollout to x-bugfix, x-design, x-api-pentest | No cascade dispatch in those skills | ⏳ DEFERRED |

**Verdict:** Initial ship applied. Rollout and verifier-slot retrofit deferred.

---

### 07 — Prompt Assembly Layers (`applied 2026-04-18`)

| Claim | Evidence | Status |
|-------|----------|--------|
| 9-layer precedence ladder in `invocation-guide.md` | `skills/x-shared/invocation-guide.md` lines 43-94 | ✅ |
| Root `CLAUDE.md` updated | Repo `CLAUDE.md` references x-skills | ✅ |
| External targets (omc-reference, user global CLAUDE.md, x-skill-review checklist) | Out of repo | ⏳ DEFERRED |

**Verdict:** Repo-scoped pass applied. External targets deferred.

---

## What's Actually Missing (Deferred Work Summary)

| Deferred Item | Owner Proposal | Why It's Still Relevant |
|---------------|---------------|------------------------|
| `role:` frontmatter on 7 remaining skills | 04 | Prevents role leakage across the fleet |
| `slots:` frontmatter beyond x-do | 05 | Enables per-project overrides for all skills |
| `reactions:` frontmatter beyond x-do | 02 | Declarative event handling everywhere |
| 02 Phase 2: execution contract | 02 | Closes "passes menu not offered" and "re-review not triggered" gaps |
| 03 Part B: per-skill primitive retrofit | 03 | Ensures every dispatch names its primitive |
| 06 rollout to x-bugfix/x-design/x-api-pentest | 06 | Closes "verification skipped" gap for those skills |
| 06 verifier-slot retrofit (replace hard-coded code-reviewer) | 05+06 | Makes cascade pluggable per skill |
| 05 v2: project CLAUDE.md overrides | 05 | Lets users customize slots per project |

---

## Is Anything Outdated?

**No.** The `00-overview.md` accurately reflects the current codebase state:

- Every "applied" claim is verified in the actual skill files.
- Every "deferred" claim is acknowledged in the overview.
- The phased rollout strategy (Tier 1 → Tier 2 → Tier 3) is still the correct approach.
- None of the design constraints have been violated.

**One minor cosmetic issue:** `00-overview.md` says "Generated: 2026-04-09" at the top, but the latest applied date in the table is 2026-04-19. This is not functionally outdated — it just means the file was first generated on the 9th and updated with applied statuses through the 19th.

---

## Recommendation

The docs are **accurate and should not be archived**. If you want to drive them to 100% resolved, the next concrete tasks are:

1. **Roll out `role:` frontmatter** to x-research, x-bugfix, x-design, x-api-pentest, x-omo, x-gemini, x-skill-improve ( Proposal 04 full rollout)
2. **Roll out `slots:` + `reactions:`** to the same set (Proposals 02 + 05)
3. **Implement 02 Phase 2** — execution contract with retries/depth/terminal states
4. **Retrofit 06 step 4** to use the `verifier` slot instead of hard-coded `code-reviewer`
5. **Roll out completion cascade** to x-bugfix, x-design, x-api-pentest
