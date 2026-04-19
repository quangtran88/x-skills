# 02 — Declarative `reactions:` Block in Skill Frontmatter

**Tier:** 1 (apply first)
**Source:** Composio AO (`~/.claude/research/orchestration/agent-orchestrator/docs/03-patterns.md` § 3)
**Scope:** this repo only — `/Users/randytran/Codes/x-skills/`
**Touches (Phase 1 pilot, per `00-overview.md:100`):** `skills/x-shared/reactions-vocabulary.md` (new), `skills/x-do/SKILL.md` (frontmatter extension only)
**Deferred:** Phase 1 rollout to `x-bugfix` + `x-review`, Phase 2 execution contract, `omc-reference` cross-link (external), `x-skill-review` checklist (external)
**Status:** Phase 1 pilot applied 2026-04-19 (x-do only; full rollout + Phase 2 deferred)
**Estimated effort:** Phase 1 pilot: 1–2 hours (docs + one frontmatter edit). Phase 2 execution contract: only after Phase 1 proves the agent honors declarative reactions in real sessions — don't ship Phase 2 until Phase 1 has a track record.

## Problem

Right now, what-happens-after-the-work is encoded imperatively in skill prose. Examples:

> "If tests fail, route to x-bugfix"
> "After implementation, offer the handoff menu [Y]/[P]/[N]"
> "If the reviewer requests changes, run another pass"

This has five concrete problems:

1. **Invisible from outside** — to know what `x-do` does on test failure, you have to read its markdown. There's no "table of reactions" a reader can skim.
2. **Hard to override per-project** — if a project wants different behavior (e.g., "on test failure, notify Slack instead of routing to x-bugfix"), the user has to fork the skill.
3. **Easily skipped by the agent** — imperative prose gets summarized, rushed, or misread. `feedback_xreview_compliance.md` lists 3 gaps in the reactions family ("verification-before-completion skipped", "passes menu not offered", "re-review after changes not triggered"). These aren't 3 different bugs — they're all "imperative reaction logic didn't fire." (A 4th gap — "handoff context missing" — is NOT closed by this proposal; 03 owns it via the context envelope.)
4. **Not composable** — you can't write a project `CLAUDE.md` that says "add this one extra reaction without re-implementing everything."
5. **Reactions aren't named consistently** — some skills say "after X, do Y," others say "if X, Y," others just assume it. No vocabulary.

## Pattern (from Composio AO)

Composio AO's defining automation feature is a YAML `reactions:` block:

```yaml
reactions:
  ci-failed:
    auto: true
    action: send-to-agent
    retries: 2
  changes-requested:
    auto: true
    action: send-to-agent
    escalateAfter: 30m
  approved-and-green:
    auto: false
    action: notify
```

The Lifecycle Manager consults this table on every state change and dispatches accordingly. Key properties:

1. **Declarative** — the full automation surface is readable in one block.
2. **Overridable per project** — the yaml lives in `agent-orchestrator.yaml` which is per-project.
3. **Safety levers built in** — `auto: false` lets you start in "notify only" mode and promote to `auto: true` once trusted.
4. **Named triggers** — `ci-failed`, `changes-requested`, `approved-and-green` are a stable vocabulary.

We borrow this pattern into x-skill frontmatter. The x-skill equivalent runs entirely in markdown + Claude Code's existing tool dispatch — no runtime changes needed.

## Enforcement honesty

Claude Code's Skill tool only parses `name:` and `description:` from frontmatter as schema fields (verified against `superpowers:writing-skills/SKILL.md`). Every current x-skill uses only those two plus the `role:` field added by proposal 04 — which is itself self-applied prose, not harness-enforced. The `reactions:` block is **prominently-formatted prose the model self-reads when invoking the skill** — it is NOT runtime-validated by the harness.

This is the same mechanism as imperative prose, just with a tabular shape that's harder to skim past. The value comes from:
- Forcing the author to enumerate the reaction surface.
- Giving `x-skill-review` a concrete audit target (block vs. surrounding prose).
- Self-check discipline (Phase 2 only).

Same enforcement class as proposals 04's roles, 05's slots, and 07's precedence ladder. If the model ignores the block, the block is decoration.

## Proposal

### Part A — Extend skill frontmatter schema

Add a `reactions:` field to skill frontmatter. It accepts a map of trigger → response objects.

**New frontmatter schema (with existing `role:` from proposal 04):**

```yaml
---
name: x-do
description: Use when the user asks to build, implement, fix, or execute a plan — detects context (existing plan, new feature, bug, quick task, visual input) and routes through brainstorming, planning, debugging, or execution workflows
role: router
reactions:
  test-failed:
    action: route
    to: x-bugfix
    retries: 2
    auto: true
  lint-failed:
    action: inline-fix
    auto: true
  implementation-complete:
    action: menu
    options: [commit, x-review, plan-next, done]
    auto: false
---
```

**Schema definition:**

| Field | Type | Required | Meaning |
|---|---|---|---|
| trigger | string (the map key) | yes | Named event that fires this reaction |
| `action` | enum | yes | `route` / `inline-fix` / `re-review` / `menu` / `notify` / `skip` / `abort` / `continue` (stay in loop, try next hypothesis) |
| `to` | skill name | conditional | Required when `action` is `route` or `re-review` |
| `retries` | int | no | Default 0. Max times to retry the reaction on continued failure. |
| `auto` | bool | no | Default true. If false, require user approval before firing. |
| `options` | array | conditional | Required when `action` is `menu` |
| `escalateAfter` | duration | no | If reaction doesn't complete within this window, escalate to user |

### Part B — Named trigger vocabulary (new file in repo)

Create `skills/x-shared/reactions-vocabulary.md` with the canonical trigger list:

| Trigger | Fires when |
|---|---|
| `research-needed` | skill classified the task as needing research before acting (routes to x-research) |
| `plan-needed` | skill classified the task as needing a plan before executing (routes to writing-plans) |
| `research-complete` | x-research synthesis done |
| `plan-complete` | writing-plans skill finished a plan doc |
| `plan-approved` | user said yes to a plan |
| `implementation-complete` | all code changes for one mode complete |
| `test-failed` | test runner returned non-zero |
| `test-passed` | test runner returned zero after at least one test ran |
| `lint-failed` | lint tool reported errors (not warnings) |
| `lint-warning` | lint tool reported warnings only |
| `typecheck-failed` | tsc / mypy / etc reported errors |
| `typecheck-passed` | type checker clean |
| `verification-failed` | verification-before-completion cascade returned fail |
| `verification-passed` | verification cascade clean |
| `review-approved` | reviewer (x-review or code-reviewer) returned approve |
| `review-changes-requested` | reviewer returned non-approve with specific issues |
| `stagnation-detected` | from proposal 01 — 3 iterations no progress |
| `human-approval-needed` | skill hit a blocking decision requiring user input |
| `skill-done` | terminal state reached, ready to hand back to user |

Skills only fire triggers from this vocabulary. If a skill needs a new trigger, it gets added here, not invented ad hoc.

#### Trigger × role cross-reference

Not every trigger applies to every skill. Use this table to find which triggers your role MUST handle vs may ignore:

| Trigger | Required for | Optional for | N/A for |
|---|---|---|---|
| `research-needed` | router, orchestrator | — | reviewer, verifier |
| `plan-needed` | router, orchestrator | — | reviewer, verifier, researcher |
| `research-complete` | orchestrator | router | reviewer, verifier |
| `plan-complete` | orchestrator | router | reviewer, verifier |
| `plan-approved` | orchestrator | router | reviewer, verifier |
| `implementation-complete` | router, orchestrator | — | researcher, verifier |
| `test-failed` | router, orchestrator, bugfixer | — | researcher |
| `test-passed` | router, orchestrator, bugfixer | verifier | researcher |
| `lint-failed` | router, orchestrator | — | researcher |
| `typecheck-failed` | router, orchestrator | — | researcher |
| `verification-failed` | router, orchestrator | — | researcher |
| `verification-passed` | router, orchestrator | verifier | researcher |
| `review-approved` | reviewer | router, orchestrator | researcher, verifier |
| `review-changes-requested` | reviewer | router, orchestrator | researcher, verifier |
| `stagnation-detected` | router, orchestrator, bugfixer | — | reviewer, researcher |
| `human-approval-needed` | all roles | — | — |
| `skill-done` | all roles | — | — |

**Guidance for new skills:** start with triggers marked "Required for" your role; add "Optional for" triggers only when your workflow explicitly references them; ignore "N/A" triggers (declaring them is noise).

### Part C — Execution contract ships in two phases

**Phase 1 — Documentation only (this application):** the `reactions:` block is a readable summary of what each skill does on common events. The skill prose references the triggers in its workflow sections; the block makes the surface auditable. **No retry counting, no depth tracking, no terminal-state enforcement.** Phase 1 is a pure refactor: take the reactions that are already scattered through skill content and list them in the block, so a reader can see the surface without reading the whole file.

**Phase 2 — Execution contract (deferred):** once Phase 1 has a track record of being honored, upgrade to the full execution contract. Phase 2 asks the agent to carry retry counts, enforce terminal states, and prevent reaction loops — invariants the agent must hold across a multi-tool-call session. This is load-bearing self-check discipline; if Phase 1 is routinely skipped, Phase 2 won't land either.

**Do not ship Phase 2 until:** (a) reactions blocks exist in at least 3 skills in this repo, (b) `x-skill-review` has caught at least one drift between block and prose on a real skill, (c) the agent has been observed reading the block during a live session. Otherwise Phase 2 is adding invariants to a pattern the agent is already ignoring.

---

**Phase 2 contract (for reference; do NOT implement yet):**

Append to `skills/x-shared/invocation-guide.md` a new section:

```markdown
## Reactions — Executing Declarative Responses

When a skill's frontmatter contains a `reactions:` block, the agent MUST honor the **core 3 invariants** below. (An earlier draft asked for 5 interacting invariants; cross-model review flagged that as too many for reliable self-check without runtime support. The other two — retry tracking, terminal-state enforcement — are deferred to Phase 3 or to future platform support.)

1. **Evaluate triggers after every tool call** that could produce one (e.g., Bash running tests → check `test-failed`/`test-passed`; Edit → check `lint-failed`/`typecheck-failed` if the project has those tools configured). Multiple triggers can fire in one tool call; process them in declaration order.

2. **Respect `auto: false`.** If a reaction has `auto: false`, surface to the user before firing. Use this format:
   ```
   🔔 Reaction: <trigger>
   Proposed action: <action> <to>
   Approve? [Y/N]
   ```

3. **Never silently skip a reaction.** If a trigger fires but the reaction can't execute (missing tool, missing skill), surface the error and ask the user. If a trigger fires and the reaction has `action: skip`, that is an explicit skip (allowed). Omitting a triggered reaction without surfacing it is the primary failure mode.

**Deferred (Phase 3 / platform support):**
- **Retry tracking** (`retries` field) — adds a counter the agent must carry across a multi-tool-call session without runtime support. Defer until Phase 2's core 3 invariants hold.
- **Terminal-state enforcement** ("never claim done until...") — better handled by proposal 06's x-verify completion cascade. Reactions fire events; x-verify enforces terminal states. Don't double up.
```

### Part D — Reference implementation in `x-do` (Phase 1 pilot)

Update `skills/x-do/SKILL.md` frontmatter.

**Before (current state, post-04):**
```yaml
---
name: x-do
description: Use when the user asks to build, implement, fix, or execute a plan — detects context (existing plan, new feature, bug, quick task, visual input) and routes through brainstorming, planning, debugging, or execution workflows
role: router
---
```

**After (Phase 1 pilot):**
```yaml
---
name: x-do
description: Use when the user asks to build, implement, fix, or execute a plan — detects context (existing plan, new feature, bug, quick task, visual input) and routes through brainstorming, planning, debugging, or execution workflows
role: router
reactions:
  research-needed:
    action: route
    to: x-research
    auto: true
  plan-needed:
    action: route
    to: superpowers:writing-plans
    auto: true
  test-failed:
    action: route
    to: x-bugfix
    retries: 2
    auto: true
  lint-failed:
    action: inline-fix
    auto: true
  typecheck-failed:
    action: inline-fix
    auto: true
  verification-failed:
    action: re-review
    auto: true
  implementation-complete:
    action: menu
    options: [commit, x-review, plan-next, done]
    auto: false
  stagnation-detected:
    action: menu
    options: [alternative-A, alternative-B, alternative-C, abort]
    auto: false
  human-approval-needed:
    action: notify
    auto: false
---
```

**What stays the same:** the existing "## Role: router" forbid block (body, post-04) and all workflow prose. Phase 1 does NOT remove or rewrite the imperative prose; it mirrors it as declarative frontmatter. Phase 2 is where the prose might get pruned.

### Deferred — Phase 1 rollout + Phase 2 infrastructure

**Once the x-do pilot meets its success criteria, extend Phase 1 to:**

**`x-bugfix`:**
```yaml
reactions:
  hypothesis-confirmed:
    action: route
    to: x-do
  hypothesis-rejected:
    action: continue
  root-cause-unclear:
    action: menu
    options: [widen-investigation, ask-user, abort]
  stagnation-detected:
    action: menu
    options: [alternative-A, alternative-B, alternative-C, abort]
```

**`x-review`:**
```yaml
reactions:
  changes-requested:
    action: re-review
    to: x-do
    retries: 3
  review-approved:
    action: menu
    options: [commit, next-pass, done]
  reviewer-blocked:
    action: notify
    auto: false
```

**External (out of scope for this repo):**
- Document the pattern in `~/.claude/skills/omc-reference/SKILL.md` — cross-link for OMC users; belongs in an OMC PR, not this repo.
- Extend `~/.claude/skills/x-skill-review/SKILL.md` with a reactions-audit checklist — same "external skill" boundary as proposal 03 Part C.

## Migration steps

**Phase 1 pilot (this application) — 3 steps, all in-repo:**

**Step 1** — Create `skills/x-shared/reactions-vocabulary.md` with the canonical trigger list (Part B above) including the trigger × role cross-reference.

**Step 2** — Add the reactions block to `skills/x-do/SKILL.md` frontmatter (Part D "After"). Preserve the existing `role: router` field and all body content. This is the only skill touched in Phase 1 pilot per `00-overview.md:100`.

**Step 3** — Dry-run audit: read `x-do/SKILL.md` end-to-end and confirm each declared reaction corresponds to existing imperative prose somewhere in the body. If a reaction has no matching prose, that's a drift — either the prose is missing or the reaction shouldn't be declared. File any drifts as follow-ups; do not fix in this pass (the goal is audit surface, not rewriting).

**Exit gate for promoting beyond pilot:** the x-do pilot succeeds once (a) the reactions-vocabulary doc exists and is referenced by at least the invocation guide or a skill body, (b) x-do's block is dry-run-audited with no drifts (or drifts filed as follow-ups), and (c) one real session shows the agent reading the block when invoking x-do. Only then extend Phase 1 to x-bugfix and x-review.

**Phase 2 (deferred) — execution contract:** do not start until the exit gate above is met AND the three Phase 2 preconditions (see Part C "Do not ship Phase 2 until") are met.

## Validation

**Phase 1 — audit surface only:**

**Test 1 — Vocabulary doc exists and is coherent.** After Step 1, `skills/x-shared/reactions-vocabulary.md` exists, lists all triggers from Part B, and includes the role cross-reference.

**Test 2 — x-do frontmatter is well-formed.** After Step 2, x-do's frontmatter parses, preserves `role: router`, and the reactions block lists only triggers that appear in the vocabulary doc.

**Test 3 — No drift between block and prose.** The dry-run audit in Step 3 finds each declared reaction has corresponding prose somewhere in x-do's body (or a follow-up is filed).

**Phase 1 success metric:** a reader can see x-do's full reaction surface in under 30 seconds by reading the frontmatter. `x-skill-review` has a concrete audit target (block vs. prose).

**Phase 2 — execution contract (deferred):**

The behavior tests below require Phase 2's execution contract and CANNOT be satisfied by Phase 1 docs alone.

- **Reaction fires correctly:** run x-do on a task where tests will fail. Expected: test failure detected, x-do fires `test-failed: route to x-bugfix` (or explicitly menus user), retry budget respected.
- **`auto: false` respected:** `human-approval-needed` pauses for approval.
- **Compliance gaps closed:** `review-approved` fires the menu (closes "passes menu not offered"), `changes-requested` routes back to x-do (closes "re-review after changes not triggered"). **Note:** these are Phase 2 gap closures. Phase 1 closes zero gaps.
- **Overridable per project:** requires proposals 07 (applied ✓) AND 05 v2 (project override, deferred Tier 3) to work end-to-end.

### Split success metrics by phase

**Phase 1 success metric (documentation surface):**
- A reader can see the full reaction surface of any skill in under 30 seconds without reading the whole body
- `x-skill-review` has a concrete audit target (block vs. prose)
- At least one real drift has been caught by `x-skill-review` during a live audit (gate for promoting to Phase 2)
- The agent has been observed reading the block during a live session
- **NO gap-closure claims in Phase 1.** Phase 1 is audit surface only.

**Phase 2 success metric (execution contract):**
- "Passes menu not offered" gap stops recurring in real x-review sessions
- "Re-review after changes not triggered" gap stops recurring in real x-review sessions
- "Verification-before-completion skipped" remains owned by proposal 06, not 02

**What 02 owns:** 2 of 6 compliance gaps ("passes menu not offered" + "re-review after changes not triggered"), both in Phase 2. If Phase 2 never ships, 02 closes zero gaps even though the declarative block exists. That is the honest framing.

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Agent ignores the reactions block (reads frontmatter but doesn't enforce it) | Medium (Phase 1) / High relevance (Phase 2) | Phase 1 doesn't try to enforce — that's Phase 2. If Phase 2 ships and the agent still ignores, tighten the language or add a bootstrap pre-check. |
| Reactions block gets out of sync with skill prose | Medium | `x-skill-review` checks frontmatter against prose — primary value of Phase 1. |
| Reaction loops — reaction A triggers reaction B triggers reaction A | Not applicable in Phase 1 | Phase 1 reactions are documentation-only and do not fire programmatically. Mitigation (max depth 3) is a Phase 2 invariant; do not list as active until Phase 2 ships. |
| Trigger naming drift — skills invent new triggers instead of using the vocabulary | Low | `x-skill-review` validates triggers against the vocabulary doc. |
| Backward compat — existing skill invocations break | Low | Reactions block is purely additive. Old invocations keep working. |
| Frontmatter schema validation fails silently in Claude Code's Skill tool | **Inherent** | No runtime validation exists. The harness ignores unknown frontmatter fields. `x-skill-review` can flag malformed blocks during audit but cannot gate skill loading. Mitigation is self-check + human review, not runtime refusal. |

**Rollback plan:** delete the `reactions:` block from x-do's frontmatter and delete `reactions-vocabulary.md`. Skills fall back to their imperative prose. No downstream effects.

## Patterns considered and rejected

**Reactions as a separate file** (e.g., `reactions.yaml` next to the skill) — rejected. Separating reactions from skill prose makes them easier to forget; frontmatter is the natural home.

**Reactions as a runtime hook registry** — rejected. Adds runtime state (violates stateless principle); needs a platform feature.

**Reactions as Claude Code hooks** — rejected for now. Hooks fire on tool-use events, not skill-level semantic events like `test-failed`. Mapping hooks to reactions would need a translation layer. Could be added later as a performance optimization; the core pattern should live in frontmatter.

**Per-reaction cost budget** (e.g., `max-tokens: 5000`) — rejected as premature.

## Out of scope

- **Global reactions config** (`~/.claude/reactions.yaml`) — adds precedence complexity. Start with per-skill frontmatter; revisit once the pattern is stable.
- **Reactions that call non-x-skills** — reactions currently route only to other x-skills and superpowers skills. Wiring to arbitrary shell commands or MCP tools is out of scope.
- **Reactions for MCP tool events** — MCP tools don't have a stable event vocabulary we can map.
- **Analytics on which reactions fire most often** — requires state. Log to claude-mem if desired; don't build into the reactions system.
- **`omc-reference/SKILL.md` cross-link** — external to this repo; belongs in an OMC PR.
- **`x-skill-review` reactions-audit checklist** — external to this repo; same boundary as 03 Part C.

## References

- Source pattern: `~/.claude/research/orchestration/agent-orchestrator/docs/03-patterns.md` § "3. Reactions config as the automation surface"
- Composio AO reaction config example: `~/.claude/research/orchestration/agent-orchestrator/docs/00-overview.md` § "Configuration"
- Compliance gaps closed: **2 of 6 in Phase 2 only** — "passes menu not offered" and "re-review after changes not triggered". Phase 1 closes **zero** gaps (pure documentation / audit surface). "Verification-before-completion skipped" is owned by 06 per `00-overview.md` § "Compliance gap coverage"; 02 merely names the `verification-failed` event. "Handoff context missing" is owned by 03.
- Related proposals: 03 (primitives) — reactions use primitive verbs for their `action:` field; 04 (roles, applied) — `role:` is already in x-do's frontmatter and must be preserved when adding `reactions:`; 06 (state cascade) — enforces the `verification-failed` reaction; 07 (precedence ladder, applied) — allows future project overrides once 05 v2 lands.
