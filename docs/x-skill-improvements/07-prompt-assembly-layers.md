# 07 — Three-Layer Prompt Assembly, Made Explicit

**Tier:** 2 (apply alongside Tier 1 — cheap, high-clarity)
**Source:** Composio Agent Orchestrator (`~/.claude/research/orchestration/agent-orchestrator/docs/01-architecture.md` § "Prompt assembly (3 layers)")
**Scope:** this repo only — `/Users/randytran/Codes/x-skills/`
**Touches:** `skills/x-shared/invocation-guide.md`, `CLAUDE.md` (repo-level)
**Status:** applied 2026-04-18
**Estimated effort:** 30–60 min (pure documentation)
**Depends on:** None directly, but **required** for proposal 05 (plugin slots) to work

## Problem

Layered prompt assembly already exists implicitly in the environment these skills run in — it's just not documented, so drift happens and conflicts are silently resolved wrong.

**Layers the x-skills actually observe at runtime (not declared anywhere):**

1. Skill body + frontmatter (the skill invoked)
2. Repo `CLAUDE.md` (this repo's policy)
3. Project `CLAUDE.md` (wherever the user is working)
4. `~/.claude/CLAUDE.md` (user's global)
5. Memory files (`~/.claude/projects/.../memory/*.md`) — **includes principle-level architectural rules**
6. Claude Code harness (system prompt baked in)
7. `using-superpowers` skill (overrides system defaults, per its own docs)

**Problems this creates inside this repo:**

1. **Precedence is unclear.** When `~/.claude/CLAUDE.md` says "always use morph-mcp" and a skill body says "use native Grep", which wins? The repo's skills assume an answer but never state it.

2. **Inviolable principles are indistinguishable from advisory preferences.** `feedback_xskill_router_principle.md` declares an architectural axiom. `feedback_verify_ts_eslint.md` is an advisory preference. Both live in memory. The skills assume principles outrank everything, but nothing documents that.

3. **Slot overrides (proposal 05) have no foundation.** 05 says "project CLAUDE.md can override skill frontmatter slots." That only makes sense against a documented precedence ladder.

4. **The repo's `CLAUDE.md` is silent on precedence.** A new contributor reading `CLAUDE.md` learns about skills and feature gates but not which layer wins in a conflict.

## Pattern (from Composio AO)

Composio AO's prompt assembly is deliberately explicit:

```
Agent system prompt = Layer 1 (base)
                    + Layer 2 (project config)
                    + Layer 3 (per-task rules, optional)
```

Properties: ordered, scoped, bounded to 3 layers, documented in both README and CLAUDE.md. Later layers override earlier for conflicting keys.

We borrow the explicitness, not the 3-layer count — our environment already has more layers and we're documenting what exists, not redesigning it.

## Enforcement honesty

Claude Code's Skill tool only parses `name:` and `description:` from frontmatter. The precedence ladder is **a decision-making contract the model self-applies when instructions conflict**. There is no runtime layer that parses precedence, enforces priority, or refuses a skill that violates the ladder.

**What this proposal provides:** shared vocabulary for conflict resolution inside this repo — so that when a skill's frontmatter says one thing and a project's `CLAUDE.md` says another, there is exactly one documented rule for which wins, and `x-skill-review` can audit against it.

**What this proposal does NOT provide:** runtime guarantees. It does not make proposal 05 magically reliable — it only documents how the model _should_ resolve conflicts. Same enforcement class as 02's reactions, 04's roles, and 05's slots.

## Proposal

### Part A — Canonical precedence ladder (in `skills/x-shared/invocation-guide.md`)

Extend `skills/x-shared/invocation-guide.md` with a new top-level section. The file today is a short tactical guide for how to invoke Skills, OMO agents, and OMC agents. Adding "Prompt Assembly — Precedence Ladder" as a new section keeps the one-stop nature of the file: every x-skill already links here from its Invocation section.

Append this section to `skills/x-shared/invocation-guide.md`:

```markdown
## Prompt Assembly — Precedence Ladder

When instructions conflict, the higher-priority layer wins. This is the canonical order that every x-skill in this repo assumes.

### The 9 layers (highest to lowest priority)

| # | Layer | Example | Scope |
|---|---|---|---|
| **0** | **Inviolable principles** (memory files marked `principle: true`, e.g., `feedback_no_external_deps.md`, `feedback_stateless_skills.md`, `feedback_xskill_router_principle.md`) | "never edit plugin cache" / "x-skills are routers" | Cannot be overridden by any layer below |
| 1 | **User's explicit in-prompt instructions** | "skip the review this time" | Current turn |
| 2 | **Project `CLAUDE.md`** (the working directory the user invoked from) | Per-project rules | Current project |
| 3 | **Repo `CLAUDE.md`** (this repo's policy, shipped with the skills) | "x-skills are routers; no persistence" | This repo |
| 4 | **Memory feedback files** (advisory; non-principle) | `feedback_xreview_compliance.md`, `feedback_verify_ts_eslint.md` | Global, advisory |
| 5 | **`~/.claude/CLAUDE.md`** (user's global) | "always use morph-mcp" | User's defaults across all projects |
| 6 | **Skill frontmatter** (`role:`, `slots:`, `reactions:`) | From proposals 02, 04, 05 | Per-skill |
| 7 | **Skill body (markdown below the frontmatter)** | The actual skill instructions | Per-skill |
| 8 | **Claude Code harness + superpowers defaults** | Baseline behavior | Runtime |

**Priority 0 — Inviolable principles.** Some memory files capture architectural decisions that no project or skill should override (e.g., stateless router, no external deps). They can only be amended by editing the memory file itself — a project `CLAUDE.md` saying "in this project, skills can be stateful" does not override them.

**How a memory file declares itself a principle:** add `principle: true` to its frontmatter, or name it `feedback_*_principle.md`. Both are conventions — purely advisory, no runtime enforcement. When in doubt, treat a memory as advisory (priority 4); promote to principle only when a cross-project axiom emerges.

**Why repo `CLAUDE.md` (priority 3) outranks advisory memory (priority 4):** the repo's `CLAUDE.md` ships with the skills and defines how they must behave when shipped. A single-user memory that contradicts it is a signal that the memory is stale or the project is knowingly off-contract; the repo policy wins unless the user or project says otherwise.

**Why advisory memory (priority 4) outranks user global `~/.claude/CLAUDE.md` (priority 5):** memory files capture the user's deliberate, task-scoped learnings recorded over time. The global `CLAUDE.md` is the user's default; memory is an override on that default. If the two conflict, the more-specific record wins.

### How conflicts resolve

Walk the ladder from top (priority 0) to bottom (priority 8). First layer that addresses the conflict wins.

**Example 1 — Global vs skill body.** Skill body says "use native Grep". `~/.claude/CLAUDE.md` says "always use morph-mcp". No project or repo override.
- Priority 0–4: silent
- Priority 5: **user global wins** → use morph-mcp
- Skill body (priority 7) loses

**Example 2 — User in-prompt beats everything non-principle.** User says "just use whatever's fastest". Repo `CLAUDE.md` says "always post-impl review with x-review".
- Priority 0: (no principle blocks this)
- Priority 1: **user wins** → skip review this turn
- Surface the skipped step to the user so they know what was dropped

**Example 3 — Principle overrides project.** Project `CLAUDE.md` says "x-do may keep a state cache in `.xdo/`". Memory `feedback_stateless_skills.md` (marked `principle: true`) says skills must be stateless.
- Priority 0: **principle wins** → x-do does not create a state cache
- Surface the conflict: "project CLAUDE.md requested state, but `feedback_stateless_skills.md` is a principle — skipped."

### When layers don't conflict, they compose

All layers contribute instructions. Precedence only matters for *conflicts*. If skill body says "use worktrees" and `~/.claude/CLAUDE.md` says "run verify-ts after edits", both apply.

### Surface conflict resolution to the user

When a higher-priority layer overrides a lower one, say so in the response. Example: "Using native Grep per project `CLAUDE.md` override (user global default is morph-mcp)." Silent overrides are the failure mode this ladder exists to prevent.
```

### Part B — Point the repo `CLAUDE.md` at the ladder

Add a short section to `/Users/randytran/Codes/x-skills/CLAUDE.md` (this repo's root). This is the repo's policy file; it should state its place in the ladder explicitly and cite the canonical doc.

Append after the "Setup" section:

```markdown
## Instruction Precedence

The skills in this repo resolve conflicting instructions via the precedence ladder in `skills/x-shared/invocation-guide.md` § "Prompt Assembly — Precedence Ladder".

TL;DR: inviolable principles > user in-prompt > project `CLAUDE.md` > **this file** > advisory memory > `~/.claude/CLAUDE.md` > skill frontmatter > skill body > harness.

When editing this file, remember it sits at priority 3 — specific enough to override a user's global defaults for anyone working on this repo, weak enough that a single project can override for its own needs.
```

### Part C — Cross-link from each skill (optional, low value)

Every skill in this repo already links `skills/x-shared/invocation-guide.md` from its "Invocation" or "Dependencies" section (verified across `x-do`, `x-bugfix`, `x-research`, `x-review`). The precedence ladder rides free on those existing references — no per-skill edit is strictly required.

**Decision:** skip per-skill edits. Rely on the existing "For how to invoke skills, OMO agents, and OMC agents, see `../x-shared/invocation-guide.md`" breadcrumb. If a skill author wants readers to know precedence lives there too, they can add "(includes precedence ladder)" as a parenthetical — one-word edit, zero migration churn.

### Part D — Out of scope for this proposal

Deferred to a follow-up proposal (or a separate commit, if the user authors x-skill-review and chooses to extend it):

- **`x-skill-review` checklist item** — the review skill lives outside this repo (`~/.claude/skills/x-skill-review/`). Extending it to audit precedence compliance is valuable but crosses the "don't edit external deps" line for this repo's scope.
- **`omc-reference/SKILL.md` cross-reference** — OMC's catalog lives in the OMC plugin. Adding a precedence pointer there is a useful symmetry once 07 lands, but requires a PR against OMC, not an edit in this repo.
- **User global `~/.claude/CLAUDE.md` `<instruction_precedence>` block** — helpful for the user's personal setup, but outside this repo's remit. The user can copy-paste from Part B if they want it globally.

## Migration steps

All three steps edit files in this repo only.

**Step 1** — Append "Prompt Assembly — Precedence Ladder" to `skills/x-shared/invocation-guide.md` (Part A). Pure addition.

**Step 2** — Append "Instruction Precedence" to `CLAUDE.md` at the repo root (Part B). Pure addition.

**Step 3** — Do a dry-run audit: read one skill end-to-end (recommend `x-do`) and verify there's nothing in the body that contradicts the ladder it now transitively references. If there is, file it as a follow-up — don't fix in this pass.

## Validation

**Test 1 — Read-back.** Open `skills/x-shared/invocation-guide.md` after Step 1. The new section is appended, contains a 9-row table (priorities 0–8), and has three worked examples.

**Test 2 — Repo `CLAUDE.md` links correctly.** Open `CLAUDE.md` after Step 2. The TL;DR names all 9 layers in order; the link points at the invocation-guide section.

**Test 3 — No contradictions with current skills.** `x-do` SKILL.md currently declares `role: router` with a forbid block in the body. This matches precedence-ladder layer 6 (frontmatter) + 7 (body). Verify no skill body contradicts a higher layer. (Known clean as of 2026-04-09 after proposal 04.)

**Test 4 — Live conflict surface check.** Next time the agent applies a higher-priority override (e.g., a project `CLAUDE.md` that says "skip verify"), the response should name the override source. If it doesn't, the ladder is documentation-only and `x-skill-review` should flag it in a later pass.

**Success metric:** a new contributor can read `CLAUDE.md` + `invocation-guide.md` once and correctly predict who wins in a cross-layer conflict without opening any other file.

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| 9 layers (0–8) is too many to remember | Medium | Most conflicts resolve in layers 0–3. The table is the reference; memorization isn't required. |
| Agent doesn't walk the ladder during conflicts | Medium | The ladder is self-applied, not enforced. Add "surface the override source" to `x-skill-review` in a follow-up. |
| Priority 3 (repo `CLAUDE.md`) vs priority 4 (advisory memory) ordering surprises users | Low | Documented inline in Part A with rationale. |
| Proposal 05 (slots) breaks if this isn't applied | High (known) | 05 depends on this ladder. Ship 07 before 05. |
| Precedence conflicts between two memory files | Low | Memory files should not contradict. If they do, consolidate; don't patch the ladder. |

**Rollback plan:** revert the two appends. Nothing breaks — the ladder documents implicit behavior that existed before.

## Patterns considered and rejected

**Edit user global `~/.claude/CLAUDE.md` from this repo.** Rejected — crosses the repo boundary. The user can copy the TL;DR into their global file if they want it; we don't ship that edit.

**Edit `~/.claude/skills/omc-reference/SKILL.md`.** Rejected — that's the OMC plugin, external to this repo. Cross-linking from there is valuable but belongs in an OMC PR.

**Per-skill precedence breadcrumb (Part C).** Considered and made optional. Every skill already links `invocation-guide.md`; the ladder inherits that breadcrumb. Adding a dedicated "On conflicts:" line to 7 skill files is 7 edits for marginal clarity gain. Skip until someone complains.

**Merge `role:` / `slots:` / `reactions:` into one precedence layer.** Rejected — proposals 02/04/05 depend on them being distinct frontmatter blocks. Merging would destroy the audit surfaces each one creates.

**Precedence as a JSON file** (`precedence.json`). Rejected — conceptual ordering, not runtime config. Markdown reads and edits better.

**Precedence enforcement hook.** Rejected — hooks can't read skill frontmatter or walk the ladder. Self-applied decision contract is the only enforcement class available.

## Out of scope

- Precedence visibility in the Claude Code UI — out of our control.
- Cross-session precedence state — each session re-reads the ladder; no persistence.
- Runtime precedence inspection ("show me which layer won") — nice-to-have, not blocking.
- Precedence for skills outside this repo (superpowers, OMC, claude-mem) — each has its own ladder if any; we don't unify.

## References

- Source pattern: `~/.claude/research/orchestration/agent-orchestrator/docs/01-architecture.md` § "Prompt assembly (3 layers)"
- Superpowers' own precedence (user > skills > harness): embedded in `superpowers:using-superpowers` skill content — a subset of ours, no conflict
- Compliance gaps closed: none directly. Enables proposal 05 which closes slot-override gaps.
- Related proposals: **required by 05** (slots), supports 02 (reactions can be overridden per-project), supports 04 (role declarations can be honored project-wide).
