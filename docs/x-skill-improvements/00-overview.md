# x-skill Improvements — Overview & Index

**Generated:** 2026-04-09
**Source:** Synthesis of patterns from 4 orchestration tools cloned into `~/.claude/research/orchestration/`:
- `cli-agent-orchestrator` (AWS CAO)
- `opencode-orchestrator` (Commander/Planner/Worker/Reviewer hub)
- `AgentsMesh` (multi-tenant workforce platform)
- `agent-orchestrator` (Composio AO plugin fleet)

## What this folder is

Implementation-ready proposals for improving the x-skills router architecture. Each doc is a stand-alone spec: the problem, the borrowed pattern, the exact file changes, before/after examples, validation criteria, and risks.

**These are proposals, not live skill content.** They live under `~/.claude/plans/` so you can review and stage them before touching real skills. Each doc describes changes to specific files under `~/.claude/skills/x-*/` and `~/.claude/skills/x-shared/`.

## Design constraints (non-negotiable)

All proposals must satisfy the constraints you've already declared in memory:

1. **Stateless router principle** (`feedback_xskill_router_principle.md`) — x-skills route to existing tools; never reimplement. No new runtime infrastructure.
2. **No data dirs or persistence** (`feedback_stateless_skills.md`) — skills don't keep state between sessions. x-skill-improve's alignment log is the only exception.
3. **Don't edit external dependencies** (`feedback_no_external_deps.md`) — proposals touch only `~/.claude/skills/x-*/` and `x-shared/`, never plugin cache files.
4. **Verify TS/ESLint after implementation** (`feedback_verify_ts_eslint.md`) — not applicable here (markdown only) but proposals that touch running code must honor it.

Patterns that would violate these constraints (MVCC TODO files, session pools, AGENTS.md context files, token tracking) are explicitly excluded. See `03-orchestration-primitives.md` § "Patterns we deliberately skipped."

## The 7 improvements

### Tier 1 — Apply first (high impact, low effort, fits stateless principle)

| # | Doc | One-line | Status | Source | Touches |
|---|---|---|---|---|---|
| 01 | `01-stagnation-detection.md` | Strengthen existing stuck detection with concrete progress signals and iteration definitions | **applied 2026-04-09** | OpenCode Orchestrator | `x-do/references/iteration-patterns.md`, `x-do/references/delegation-and-scaling.md`, `x-bugfix/SKILL.md` |
| 02 | `02-reactions-block.md` | Declarative `reactions:` block in skill frontmatter | **Phase 1 pilot applied 2026-04-19** (x-do only; rollout + Phase 2 deferred) | Composio AO | `skills/x-shared/reactions-vocabulary.md` (new), `skills/x-do/SKILL.md` |
| 03 | `03-orchestration-primitives.md` | Explicit `handoff` / `assign` verbs (+ `send_message` deferred) | **applied 2026-04-19** (Part A only; retrofit + checklist deferred) | CAO | `skills/x-shared/invocation-guide.md` |
| 04 | `04-role-separation.md` | Role forbid blocks on x-do (router) and x-review (reviewer) — pilot only | **applied 2026-04-09** | OpenCode Orchestrator | `x-do`, `x-review` (pilot); remaining skills deferred |

### Tier 2 — Apply when Tier 1 is stable

| # | Doc | One-line | Status | Source | Touches |
|---|---|---|---|---|---|
| 05 | `05-plugin-slots.md` | Pluggable `model`/`workspace`/`verifier`/`reviewer` slots | **applied 2026-04-19** (v1 — x-do pilot with `workspace` + `verifier` only; v2 + rollout deferred) | Composio AO | `skills/x-shared/slot-schema.md` (new), `skills/x-shared/invocation-guide.md`, `skills/x-do/SKILL.md` |
| 06 | `06-state-detection-cascade.md` | Mandatory completion cascade for long-running skills | **applied 2026-04-19** (initial ship — x-do pilot; x-bugfix/x-design rollout deferred) | Composio AO | `skills/x-shared/completion-cascade.md` (new), `skills/x-verify/SKILL.md` (new), `skills/x-do/SKILL.md`, `CLAUDE.md` |
| 07 | `07-prompt-assembly-layers.md` | Document 9-layer prompt precedence explicitly (scoped to repo) | **applied 2026-04-18** | Composio AO | `skills/x-shared/invocation-guide.md`, `CLAUDE.md` |

## Intra-frontmatter precedence (role / slots / reactions)

Proposals 02, 04, and 05 each introduce a frontmatter block (`reactions:`, `role:`, `slots:` respectively). A fully-migrated x-do frontmatter can end up with all three, plus overlapping semantics (`slots.researcher: x-research` says the same thing as `reactions.research-needed: { action: route, to: x-research }`). Without a rule, authors have three places to put the same intent and no guidance on which wins.

**Canonical rule:** `role` > `slots` > `reactions`, in that order of authority, for any overlap.

| Block | Answers | Scope |
|---|---|---|
| `role` | "What kind of skill is this? What is it forbidden from doing?" | Architectural contract — cannot be overridden by slots or reactions. A reviewer role cannot declare `reactions.test-failed: { action: inline-fix }` — that would contradict the role's forbid block. |
| `slots` | "Which concrete implementation fills this role's dependency?" | Config — picks between candidate implementations (`verifier: code-reviewer` vs `verifier: x-review`). Cannot contradict `role` forbids. |
| `reactions` | "What happens when event X occurs?" | Event handling — names the trigger and the action, but the action's *target* comes from `slots` (the reaction `route to verifier` means "route to whatever `slots.verifier` resolved to"). |

**Resolution examples:**
- Skill declares `role: reviewer` + `reactions.test-failed: { action: inline-fix }` → conflict. Reviewer cannot fix inline (role forbids `Edit`/`Write`). The reaction is rejected; surface the contradiction to the user.
- Skill declares `slots.verifier: x-review` + `reactions.verification-failed: { action: re-review }` → compose. Reaction fires → routes to slot-resolved target (`x-review`).
- Skill declares `slots.researcher: x-research` + `reactions.research-needed: { action: route, to: x-research }` → redundant but consistent. The reaction's explicit `to:` takes precedence over the slot, but authors should prefer either/or to keep the surface clean.

**Rule of thumb for authors:** Start with `role`. Add `slots` only for things the user might legitimately want to override per-project. Add `reactions` only for events where the default flow isn't obvious from the skill's workflow prose. If you find yourself writing the same target in two blocks, delete one.

**`x-skill-review` checklist item (enforcement):** Flag any skill where `reactions` targets an action that's forbidden by its `role`. This is the primary drift failure mode.

## Compliance gap coverage (`feedback_xreview_compliance.md`)

Your existing memory file lists 6 recurring x-review compliance gaps. One **primary** proposal owns each gap; supporting proposals reinforce but do not claim primary credit.

| Compliance gap | Primary | Supporting |
|---|---|---|
| One-message launch (parallel dispatch violated) | **03** — `assign` primitive forces fan-out into one message | 04 — reviewer-role forbid reinforces |
| Reviewer #3 Skill tool not used | **04** — reviewer role forbids `Edit`/`Write`, must dispatch | — |
| Verification-before-completion skipped | **06** — mandatory completion cascade with fallback | 02 — names the `verification-failed` event but does NOT close the gap alone |
| Handoff context missing | **03** — context envelope citation at `03-orchestration-primitives.md:70` (already written) | — |
| Passes menu not offered | **02** — declares `implementation-complete: { action: menu }` | — |
| Re-review after changes not triggered | **02** — declares `changes-requested: re-review` | — |

**Six gaps, one primary per gap.** Tally by owner: **02** owns 2, **03** owns 2, **04** owns 1, **06** owns 1.

**Important caveat:** 02's two gap-closures are _declaration-only_ in 02 Phase 1 — they become real behavior only when enforced elsewhere:
- `verification-before-completion skipped` → enforcement lives in **06** (the completion cascade). 02 Phase 1 declares the reaction; 06 is what actually fires it. 02 does not claim this gap as primary.
- `passes menu not offered` and `re-review after changes not triggered` → enforcement requires **02 Phase 2** (execution contract). Phase 1 is the audit surface only. See 02 § "Phase 1 — Documentation only" and the phased success metrics.

If 02 Phase 2 never ships, these two gaps remain open — the declarative block is necessary but not sufficient. Honest framing: the compliance-gap closure arrives in **three waves** (Tier 1 primary, Tier 1 reinforcement, 02 Phase 2).

## Migration strategy

**Don't try to apply all 7 at once.** The proposals are designed to compose but also to ship independently. Recommended order (this section supersedes any earlier ordering language in individual proposal headers):

1. **01 (stagnation detection)** — lowest-risk, highest-value. Targeted amendments to 3 existing files: `iteration-patterns.md` §2 (canonical definitions), `delegation-and-scaling.md` (reference alignment), `x-bugfix/SKILL.md` (3-Strike Rule alignment). No new sections — strengthens existing mechanisms with concrete progress signals and iteration definitions. Rolls back by reverting 3 files. **Zero cross-proposal dependencies.**

2. **04 (role separation), pilot only** — add `role:` frontmatter + forbid block to `x-do` (with Mode D exception) and `x-review`. No shared role-vocabulary.md yet — defer until 3+ skills need it. Closes 1 primary compliance gap ("reviewer #3 Skill tool"). **Zero cross-proposal dependencies.**

3. **07 (prompt assembly layers)** — **applied 2026-04-18.** Pure documentation pass scoped to this repo: `skills/x-shared/invocation-guide.md` and root `CLAUDE.md`. External targets (`omc-reference/SKILL.md`, user's global `~/.claude/CLAUDE.md`, `x-skill-review` checklist) deferred as out-of-repo. **Must land before step 7** because 05 v1's slot-resolution story depends on the precedence ladder being documented.

4. **03 (orchestration primitives), docs pass only** — add **Part A only** of the proposal to `skills/x-shared/invocation-guide.md`. Part C (`x-skill-review` checklist) is deferred because that skill lives outside this repo; it will land when `x-skill-review` is brought in-repo or via a follow-up against its home. **Defer the per-skill retrofit (Part B)** until after step 2's forbid blocks are in place; retrofitting dispatch sites with forbid blocks already present is cheaper and catches role violations as a side effect.

5. **02 Phase 1 only (reactions block, docs-only refactor)** — extend the frontmatter schema and refactor scattered imperative "on X do Y" prose into declarative blocks. Pilot on `x-do`. **Do not ship 02 Phase 2** until Phase 1 has met its own exit criteria (blocks exist in 3+ skills, `x-skill-review` has caught a real drift, the agent has been observed reading the block during a live session).

6. **06 (state cascade) with hard-coded `code-reviewer` fallback** — **applied 2026-04-19.** Builds on 02's reaction vocabulary. Step 4 dispatches `code-reviewer` via `Agent` tool directly, NOT routed through a `verifier` slot (because 05 hasn't landed yet). This is the intended intermediate state; 06's `Depends on: 05` header is for the final slot-aware form, not the initial ship. **SCOPE GATE (leading short-circuit for un-tooled / docs-only / only-reads invocations) is MANDATORY** — without it, step 4 fires on every docs PR. Initial ship: `skills/x-shared/completion-cascade.md` + `skills/x-verify/SKILL.md` + x-do Completion section + `CLAUDE.md` table. Rollout to `x-bugfix`/`x-design` and the `verifier` slot retrofit are deferred.

7. **05 v1 only (plugin slots, frontmatter-defaults)** — **applied 2026-04-19.** Shipped the slot schema (`skills/x-shared/slot-schema.md`), skill-frontmatter defaults on x-do (`workspace: current-dir`, `verifier: verification-before-completion`), and the Slot Resolution self-check section in `invocation-guide.md`. Project-CLAUDE.md override story deferred to v2 per all three reviewers' consensus (see 05 Part A — Enforcement honesty). Other slots (`model`, `reviewer`, `executor`, `researcher`, `planner`) remain in the vocabulary but are NOT emitted by any skill in v1. Retrofit of 06 step 4 to use the `verifier` slot is a deferred post-v1 follow-up.

8. **Later (Tier 3 — only after everything above has a real-session track record):** 02 Phase 2 (execution contract with retries/depth/terminal states), 05 v2 (project overrides via CLAUDE.md), full 04 rollout to the remaining skills, full 03 retrofit across all dispatch sites, any fallback sub-phases for proposals whose Phase 1 didn't hold.

### What changed from earlier drafts (ordering notes for readers of individual proposals)

- **07 moved from "any time" to step 3** (before 05, which is its hard dependency).
- **06 ships with a hard-coded fallback instead of waiting for 05** — so compliance-gap closure doesn't block on the biggest architectural change.
- **05 split into v1 (defaults-only) and v2 (project overrides).** Only v1 is on the initial path; v2 is Tier 3.
- **02 split explicitly into Phase 1 (this migration) and Phase 2 (deferred).** Phase 2 has hard gates before it may ship.
- **04 split into "x-do + x-review pilot" and "full rollout."** Pilot is step 2; full rollout is Tier 3.

Individual proposal headers and references may still list looser dependency language — this section is the single source of truth for order.

## Minimum viable new skill (after all 7 land)

After all proposals ship, a new x-skill author must declare/honor ~10 discipline points. Without a copy-paste template, the author will reverse-engineer obligations from `x-do` (the most complex skill). Here is the minimal template — the smallest skill that satisfies all proposals:

```yaml
---
name: x-example
description: One-line description of what this skill routes
role: router
slots:
  workspace: current-dir
  verifier: verification-before-completion
reactions:
  implementation-complete:
    action: menu
    options: [commit, review, done]
    auto: false
  human-approval-needed:
    action: notify
    auto: false
---

## Role: router

> **HARD RULE:** This skill MUST NOT call `Edit`, `Write`, or mutating `Bash`.
> If you are about to, STOP — dispatch to an executor subagent via `Agent` tool.

See `../x-shared/role-vocabulary.md` for the full contract.

## Completion

Before claiming done, dispatch x-verify: `Skill tool: x-verify`.
Honor the verdict. Do not claim done without calling x-verify.

## Workflow

1. Classify the user's request
2. **`handoff`** → appropriate skill/subagent with context envelope
3. Collect result
4. Fire `implementation-complete` reaction → present menu

## On conflicts

See `../x-shared/invocation-guide.md` § "Prompt Assembly — Precedence Ladder".
```

**What this template demonstrates:** `role:` + forbid block (04), `slots:` (05), `reactions:` (02), named primitive `handoff` (03), x-verify call (06), precedence reference (07), and prompt placement (forbid block and completion section lead the skill body per 04 Part C placement rule). The stagnation escalation ladder (01) lives in `iteration-patterns.md` and applies automatically to any skill that runs iterative loops — no per-skill content needed.

## What success looks like

After all 7 improvements land, an x-skill should:

1. **Never loop forever on impossible problems** — stagnation detection catches it (01)
2. **Never silently skip verification** — reactions + mandatory cascade catch it (02, 06)
3. **Never mix roles** — role field + explicit forbids enforce separation (04)
4. **Never conflate parallelism with serialization** — named primitives force the author to pick (03)
5. **Be trivially overridable per project** — plugin slots let users swap model/workspace/verifier (05)
6. **Be predictable in precedence** — three-layer assembly is documented (07)

## What success does NOT look like

These proposals deliberately **do not**:

- Add runtime state to skills (no session pools, no activity DBs, no context files)
- Introduce new tools or binaries (no cao-server, no tmux requirement, no plugin registries)
- Break existing skill invocations — all changes are additive or documentation
- Require a new Claude Code feature — everything is markdown + existing hooks
- Touch external dependencies (superpowers, oh-my-claudecode, plugin cache dirs)

## How to use this folder

Each doc in this folder is structured the same way:

```
1. Problem — what's broken today, with evidence from your memory/compliance gaps
2. Pattern — which repo it came from and what it does there
3. Proposal — exact file changes with before/after
4. Migration steps — do this, then this, then this
5. Validation — how to know it worked
6. Risks — what can go wrong, rollback plan
7. Out of scope — what this doc deliberately doesn't cover
```

Read the docs in order (00 → 07). Each builds on the previous where relevant.

When you're ready to apply a proposal:
1. Read the doc end-to-end
2. Check the validation criteria
3. Make the file changes as specified
4. Run one real task through the modified skill
5. Compare behavior to the validation criteria
6. If success: update the doc's status to "applied: YYYY-MM-DD"
7. If failure: note the failure mode in the Risks section and decide rollback vs iterate

## Out of scope for this folder

**Tier 3 patterns we skipped** — documented in each doc's "Patterns we considered and rejected" section. For reference:

- MVCC for shared plan files (violates stateless)
- Session pool with warm reset (premature optimization)
- Hierarchical 4-tier memory (claude-mem already covers this)
- Token usage tracking per skill (adds state)
- AGENTS.md context propagation (adds state files)
- Sandbox plugins (`superpowers:using-git-worktrees` already exists)
- mTLS PKI (no security boundary inside one user machine)
- Control/data plane split (solves a problem we don't have)
- Speculative planning during background tasks (benefits unclear at our scale)
- RAII cleanup with shutdown manager (Claude Code manages subagents)
- Inbox watchdog for "deliver when ready" (synchronous subagents suffice)
- PATH wrapper for CLIs without native hooks (fragile and hacky)
- Bracketed paste for multi-line input (niche runtime detail)

**Tools we evaluated and chose not to install:**
- CAO, OpenCode Orchestrator, AgentsMesh, Composio AO — see the prior re-evaluation. The patterns above are the portable value; installing the tools themselves is not the right move for this stack.
