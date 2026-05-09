---
name: x-mindful
description: Use BEFORE implementation when the user has a plan, spec, design doc, PRD, or pasted requirement set and you need to surface critical architectural decisions, breaking changes, security/auth impacts, and performance/cost shifts — extracts impact items, ranks them by severity × blast-radius × reversibility, then walks the user through one-at-a-time with confirm / modify / reject / skip gates and emits a decision envelope for downstream execution
role: pre-implementation-impact-gate
slots:
  verifier: x-verify
---

# x-mindful — Pre-Implementation Impact Walkthrough

x-mindful is a **gate**, not an executor. Given a plan / spec / PRD / pasted requirement set, it extracts the load-bearing decisions and risks the user should consciously approve before any code runs. It walks them ranked-most-important-first, one item at a time, with a confirm / modify / reject / skip menu, and emits a decision envelope the next skill (typically `x-do` Mode A) consumes.

This skill is the inverse of `x-review`: x-review judges work after the fact; x-mindful gates work before it starts. It is also the inverse of `x-guide`: x-guide teaches; x-mindful warns.

## Bootstrap (MANDATORY)

Before any phase, load:

0. `../x-shared/capability-loading.md` — pin the active capability set for this session. Trust the bootstrap-pinned set; do not re-verify per dispatch.
1. `gotchas.md` — known failure patterns. Read once at start.

Lazy-load only when the phase needs it:
- `references/extraction-prompts.md` — when Phase 2 dispatches extraction.
- `references/severity-rubric.md` — when Phase 3 ranks items.
- `references/walkthrough-menu.md` — when Phase 4 enters the gate loop.
- `references/item-schema.md` — when emitting / consuming items.
- `../x-omo/SKILL.md` — only if Phase 2 routes to OMO agents (`oracle`, `--model codex`).

## Anti-Triggers

Route elsewhere and stop if the request is closer to:

| User intent | Route to |
|---|---|
| "Review this code / PR / diff" (judging existing work) | `x-review` |
| "Walk me through and teach me this doc" (comprehension) | `x-guide` |
| "Investigate / find how X works" (open research) | `x-research` |
| "Just build it" with no plan content provided | `x-do` (it will gather requirements) |
| "Audit / improve this skill itself" | `x-skill-review` / `x-skill-improve` |

## When x-mindful Triggers

**Manual:** user invokes `/x-skills:x-mindful` (or "be mindful about this plan", "what could break", "walk me through the impacts before we build", "what are the breaking changes here").

**Auto-gate from x-do Mode A:** x-do invokes x-mindful before plan execution when the plan content matches any of these high-risk signals:

- Breaking-change keywords: `breaking change`, `deprecate`, `remove`, `rename`, `replace …with`, `migrate`, `migration`, `schema change`, `drop column`, `drop table`, `BC break`, `incompatible`
- Auth / security keywords: `auth`, `authn`, `authz`, `permission`, `RBAC`, `RLS`, `session`, `token`, `secret`, `CORS`, `CSRF`, `public endpoint`
- Cross-boundary keywords: `public API`, `shared library`, `published`, `consumer`, `tenant`, `multi-tenant`, `feature flag rollout`, `dual-write`, `traffic split`
- Cost / capacity keywords: `index`, `full scan`, `backfill`, `N+1`, `fan-out`, `queue`, `cron`, `scheduled job`

x-do may skip the gate when ALL of: scope is single-file, no shared interface touched, plan has < 3 tasks, none of the above keywords appear. In that case x-do continues directly.

## Phase Dispatch

x-mindful runs five phases in order. Each phase has a step file under `steps/`. Read the step file for that phase before executing it.

| Phase | Step file | Purpose |
|---|---|---|
| 1 | `steps/step-01-detect.md` | Locate plan content (file vs. paste vs. handoff envelope), classify size, refuse if no content |
| 2 | `steps/step-02-extract.md` | Scan content for ARCH / BREAK / SEC / PERF items; route to claude-direct, gemini, oracle, or `--model codex` based on size + capability set |
| 3 | `steps/step-03-rank.md` | Score each item by severity × blast-radius × reversibility, produce ordered queue |
| 4 | `steps/step-04-walkthrough.md` | Render-menu-command loop: one item at a time, confirm / modify / reject / skip / quit, track decisions in-memory |
| 5 | `steps/step-05-handoff.md` | Emit decision envelope (confirmed / modified / rejected / skipped) for x-do or for direct user use; offer next-skill chain |

Phase 4 is the core loop. Phases 1-3 and 5 are linear.

## State (in-memory, transient)

x-mindful does **not** write a `.x-mindful/` directory by default. All state lives in the active session:

- Extracted items list (Phase 2 → Phase 3 → Phase 4)
- Ranked queue (Phase 3)
- Decisions map: `{ item_id → confirm | modify | reject | skip }` plus the modification text when modify (Phase 4)
- Final envelope (Phase 5)

Reasons for transient: most plans are reviewed once, immediately before x-do execution. The decision envelope lives in the x-do handoff context for the rest of the session. If the user asks to persist (e.g., "save this for later"), drop the envelope into `.x-mindful/<slug>/IMPACTS.md` as a one-shot export — but do not maintain progress.json across sessions. Always offer a final markdown summary the user can copy.

## Output Contract — Decision Envelope

Phase 5 emits the following block (Markdown, copy-paste safe). x-do Mode A reads it before plan review.

```markdown
<!-- x-mindful-envelope v1 -->
**Source:** <path-or-paste-id>
**Items reviewed:** N (C confirmed / M modified / R rejected / S skipped)

### Confirmed (proceed as written)
- [ARCH-001] Adopt event-driven inventory updates — severity: high
- [SEC-002] Move auth check to middleware — severity: critical

### Modified (revise plan before executing)
- [BREAK-001] Rename `getUser` → `fetchUser`
  - **Original plan:** rename in one shot, all callers updated in same PR
  - **User direction:** add deprecation alias for two releases, then remove

### Rejected (drop from plan)
- [PERF-002] Add Redis cache for product list
  - **Reason:** out of scope this sprint

### Skipped (revisit later)
- [ARCH-003] Switch to ULIDs from UUIDs
<!-- /x-mindful-envelope -->
```

x-do Mode A MUST honor this envelope: confirmed items proceed, modified items revise the plan first, rejected items are removed, skipped items go on a follow-up list.

## References

- `references/item-schema.md` — extracted-item shape and required fields
- `references/extraction-prompts.md` — category-by-category extraction prompts (ARCH / BREAK / SEC / PERF)
- `references/severity-rubric.md` — scoring formula and category exemplars
- `references/walkthrough-menu.md` — Phase 4 command table
- `gotchas.md` — known failure patterns

## Completion (MANDATORY)

Before claiming done, resolve the `verifier` slot per `../x-shared/slot-schema.md`:

1. **User in-prompt override?** ("skip verification") → wins.
2. **Skill frontmatter `slots:` block** (this skill declares `verifier: x-verify`).
3. **Schema default** — only if 1 and 2 silent.

Surface inline before dispatch, e.g. `Dispatching verifier slot → resolved to x-verify via skill frontmatter`. Then dispatch via the Skill tool.

x-mindful's "done" is narrow: every queued item has a decision (confirm / modify / reject / skip), the envelope is rendered, and the user has either chosen a next skill or explicitly stopped. x-verify confirms that envelope state, not implementation correctness — there is no implementation here.

## Dependencies

- `../x-shared/capability-loading.md` — capability pinning
- `../x-shared/slot-schema.md` — slot precedence
- `../x-shared/severity-guide.md` — shared severity scale (CRITICAL / HIGH / MEDIUM / LOW)
- `../x-shared/context-envelope.md` — handoff format
- `../x-shared/invocation-guide.md` — tool invocation patterns
- Optional: `../x-omo/SKILL.md` — OMO agents for large-spec extraction
- Optional: `../x-gemini/SKILL.md` — gemini ingest for very large specs

## After This Skill

Decisions made → typically chain into `/x-do` Mode A (execute the revised plan) or stop here if many items rejected. Include a handoff envelope per `../x-shared/context-envelope.md`.

**Workflow chain:**
- Plan → `/x-mindful` → revised plan → `/x-do` Mode A → `/x-review` → merge

If the user wants to save the envelope as a permanent artifact, write it to `.x-mindful/<slug>/IMPACTS.md` once. Do not silently re-create it on later runs.
