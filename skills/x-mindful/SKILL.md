---
name: x-mindful
description: Use BEFORE implementation when AI has produced a plan, spec, design doc, PRD, or code-bearing proposal and you want a senior-engineer architect-review pass — walks the user through the decisions, tradeoffs, assumptions, blind spots, shape mismatches, and future-debt AI silently embedded. Surfaces "what AI did, what it picked over alternatives, what it took on, and what gets harder later" one item at a time with confirm / modify / reject / skip gates. Hard-blocks code-level details so the human stays at architectural direction.
role: pre-implementation-architect-review-gate
slots:
  verifier: x-verify
---

# x-mindful — Architect-Review Walkthrough for AI-Generated Work

x-mindful is a **gate**, not an executor. AI is now fast and cheap at producing plans, specs, and code. What it misses is the senior-engineer instinct: the bigger picture, the tradeoffs it silently picked, the assumptions it embedded, the blind spots, the overengineering and underengineering, the future-debt that will haunt you in 6-12 months.

x-mindful walks the user through an AI-generated plan / spec / design doc / proposed feature at **architect-review level** — never code-level. It extracts what AI decided, what alternatives it didn't surface, what assumptions it baked in, what a senior would expect that's missing, and what gets harder later. It ranks those items by severity × blast-radius × reversibility, drops anything below the "would a senior want to weigh in?" threshold, then walks the user through the survivors one at a time with a confirm / modify / reject / skip gate. The output is a decision envelope the next skill (typically `x-do` Mode A) consumes.

This skill is the inverse of `x-review`: x-review judges work after the fact; x-mindful gates work before it starts. It is also the inverse of `x-guide`: x-guide teaches; x-mindful warns.

## What x-mindful Surfaces (the taxonomy)

| Category | What it surfaces |
|---|---|
| **TRADEOFF** | A fork in the road. AI picked side X without naming the cost on the other axis (sync vs async, monolith vs split, build vs buy, vendor-specific vs portable, one-way vs two-way door). |
| **ASSUMPTION** | A load-bearing claim AI silently relied on (scale, NFRs, environment, human capacity, trust boundaries). |
| **BLIND-SPOT** | What's NOT in the plan that a senior expects (failure modes, rollback, observability, runbook, owner, threat model, migration safety). |
| **SHAPE** | The solution shape doesn't fit the constraints. Either over-engineered (modular mirage, premature abstraction, microservice for a tiny domain) or under-engineered (missing idempotency, retries, observability, dead-letter handling). |
| **FUTURE-DEBT** | What gets harder later — paints-into-corner choices, deep vendor coupling, cost curves that grow with usage, org-fit assumptions that won't hold. |

**Hard rule:** items are presented at architect level. No function names, parameter lists, field names, file paths, or variable identifiers in any narrative field. AI follows common best practice when picking those — the human reviews direction, not implementation. The extractor (Step 02) drops or re-casts code-level findings.

## Bootstrap (MANDATORY)

Before any phase, load:

0. `../x-shared/capability-loading.md` — pin the active capability set for this session. Trust the bootstrap-pinned set; do not re-verify per dispatch.
1. `gotchas.md` — known failure patterns. Read once at start.
2. **Memory recall** (only when `mcp.basic_memory` pinned in bootstrap-active set): one `mcp__basic-memory__search_notes({ query: "<plan-slug + architectural keywords>", page_size: 5 })` call. Surface prior architectural lessons relevant to this plan as context for the extraction phase — leads, not verdicts. When `mcp.basic_memory` is not pinned, **skip silently** — Claude's native auto-memory file still applies.

Lazy-load only when the phase needs it:
- `references/extraction-prompts.md` — when Phase 2 dispatches extraction.
- `references/severity-rubric.md` — when Phase 3 ranks items.
- `references/walkthrough-menu.md` — when Phase 4 enters the gate loop.
- `references/item-schema.md` — when emitting / consuming items.
- `../x-omo/SKILL.md` — only if Phase 2 routes to OMO agents (`oracle`, `--model codex`).

## Impact Tool Preference

When `mcp.gitnexus` is pinned in the bootstrap-active set, prefer the GitNexus `impact` MCP tool over heuristic ranking when scoring blast-radius for TRADEOFF and BLIND-SPOT items that touch existing symbols. The graph-derived blast radius (depth 1 = WILL BREAK, depth 2 = LIKELY AFFECTED) informs the `scope_note` and the `surface` field; the categorical narrative still comes from the extraction prompts. ASSUMPTION, SHAPE, and FUTURE-DEBT items are judgment calls about the plan itself — `gitnexus impact` doesn't help there.

When the capability is NOT pinned, fall back to the existing extraction + scoring pipeline. Either way, surface the chosen path inline (e.g., `Impact source: gitnexus.impact` or `Impact source: heuristic ranking`) so the user can audit the routing decision.

## Anti-Triggers

Route elsewhere and stop if the request is closer to:

| User intent | Route to |
|---|---|
| "Review this code / PR / diff" (judging existing work) | `x-review` |
| "Walk me through and teach me this doc" (comprehension) | `x-guide` |
| "Investigate / find how X works" (open research) | `x-research` |
| "Just build it" with no plan content provided | `x-do` (it will gather requirements) |
| "Audit / improve this skill itself" | `x-skill-review` / `x-skill-improve` |
| "Pick names / refactor names / clean up code" | `x-do` Mode E or `refactor` skill |

## When x-mindful Triggers

**Manual:** user invokes `/x-skills:x-mindful` (or phrases like "be mindful about this plan", "what could break", "walk me through the impacts before we build", "what tradeoffs did AI silently pick", "architect-review this plan", "what assumptions is this making", "what gets harder later").

**Auto-gate from x-do Mode A:** x-do invokes x-mindful before plan execution when the plan content matches any of these architect-level signals (broader than v1):

- **Tradeoff signals:** `async`, `event-driven`, `message bus`, `queue`, `outbox`, `CDC`, `microservice`, `split`, `monolith`, `serverless`, `lambda`, `kafka`, `kinesis`, `sqs`, `CQRS`, `event sourcing`, `hexagonal`, `saga`, `dual-write`, `sync vs async`, `eventual consistency`, `strong consistency`
- **Boundary / contract signals:** `breaking change`, `deprecate`, `remove`, `rename`, `replace …with`, `migrate`, `migration`, `schema change`, `drop column`, `drop table`, `BC break`, `incompatible`, `public API`, `shared library`, `published`, `consumer`, `feature flag rollout`, `traffic split`, `canary`
- **Trust / security signals:** `auth`, `authn`, `authz`, `permission`, `RBAC`, `RLS`, `session`, `token`, `secret`, `CORS`, `CSRF`, `public endpoint`, `tenant`, `multi-tenant`, `audit log`, `threat model`
- **Operational / cost signals:** `index`, `full scan`, `backfill`, `N+1`, `fan-out`, `cron`, `scheduled job`, `SLO`, `SLA`, `on-call`, `runbook`, `pager`, `observability`, `metrics`, `tracing`, `cost`, `quota`, `rate limit`, `vendor`, `lock-in`, `region`, `multi-region`
- **Architectural-decision keywords:** `architecture`, `design doc`, `RFC`, `PRD`, `spec`, `proposal`, `pattern`, `tradeoff`, `alternative`, `rationale`

x-do may skip the gate when ALL of: scope is single-file, no shared interface touched, plan has < 3 tasks, none of the above signals appear, AND no public surface / data-layer touched. In that case x-do continues directly.

## Phase Dispatch

x-mindful runs five phases in order. Each phase has a step file under `steps/`. Read the step file for that phase before executing it.

| Phase | Step file | Purpose |
|---|---|---|
| 1 | `steps/step-01-detect.md` | Locate plan content (file vs. paste vs. handoff envelope), classify size, refuse if no content |
| 2 | `steps/step-02-extract.md` | Scan content for TRADEOFF / ASSUMPTION / BLIND-SPOT / SHAPE / FUTURE-DEBT items; hard-block code-level findings; route to claude-direct, gemini, oracle, or `--model codex` based on size + capability set |
| 3 | `steps/step-03-rank.md` | Apply `senior_weigh_in` filter, score remaining items by severity × surface × reversibility, produce ordered queue |
| 4 | `steps/step-04-walkthrough.md` | Render the "Plan at Architect Level" opener, then loop one item at a time: confirm / modify / reject / skip / quit, track decisions in-memory |
| 5 | `steps/step-05-handoff.md` | Emit decision envelope (confirmed / modified / rejected / skipped) for x-do or for direct user use; offer next-skill chain |

Phase 4 is the core loop. Phases 1-3 and 5 are linear.

## State (in-memory, transient)

x-mindful does **not** write a `.x-mindful/` directory by default. All state lives in the active session:

- Extracted items list (Phase 2 → Phase 3 → Phase 4)
- Ranked queue (Phase 3, after `senior_weigh_in` filter)
- Decisions map: `{ item_id → confirm | modify | reject | skip }` plus the modification text when modify (Phase 4)
- Final envelope (Phase 5)

Reasons for transient: most plans are reviewed once, immediately before x-do execution. The decision envelope lives in the x-do handoff context for the rest of the session. If the user asks to persist (e.g., "save this for later"), drop the envelope into `.x-mindful/<slug>/IMPACTS.md` as a one-shot export — but do not maintain progress.json across sessions. Always offer a final markdown summary the user can copy.

## Output Contract — Decision Envelope

Phase 5 emits the following block (Markdown, copy-paste safe). x-do Mode A reads `x-mindful-envelope v1` for backward compatibility; the new taxonomy v2 is signaled by the item id prefixes and the `taxonomy: v2` marker. The section layout (`Confirmed / Modified / Rejected / Skipped / Pending`) is unchanged so existing consumers keep working.

```markdown
<!-- x-mindful-envelope v1 -->
<!-- taxonomy: v2 (TRADEOFF / ASSUMPTION / BLIND-SPOT / SHAPE / FUTURE-DEBT) -->
**Source:** <path-or-paste-id>
**Items reviewed:** N (C confirmed / M modified / R rejected / S skipped)

### Confirmed (proceed as written)
- [TRADEOFF-001] Adopt event-driven inventory propagation — severity: HIGH
- [BLIND-SPOT-002] Add threat model for the new public endpoint — severity: CRITICAL

### Modified (revise plan before executing)
- [BLIND-SPOT-001] Break a public function-call contract
  - **Original plan:** rename in one shot, all callers updated in same PR
  - **User direction:** add deprecation alias for two releases, then remove

### Rejected (drop from plan)
- [SHAPE-002] Add Redis cache for product list
  - **Reason:** out of scope this sprint

### Skipped (revisit later)
- [FUTURE-DEBT-001] Hardcode single-region routing
<!-- /x-mindful-envelope -->
```

x-do Mode A MUST honor this envelope: confirmed items proceed, modified items revise the plan first, rejected items are removed, skipped items go on a follow-up list.

## References

- `references/item-schema.md` — extracted-item shape, required fields, hard-rule against code-level details
- `references/extraction-prompts.md` — per-category extraction prompts (TRADEOFF / ASSUMPTION / BLIND-SPOT / SHAPE / FUTURE-DEBT)
- `references/severity-rubric.md` — scoring formula, category exemplars, `senior_weigh_in` filter
- `references/walkthrough-menu.md` — Phase 4 opener ("Plan at Architect Level"), per-item render template, menu commands
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
