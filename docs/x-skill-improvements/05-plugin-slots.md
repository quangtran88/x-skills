# 05 — Plugin Slots in Skill Frontmatter (v1 — defaults-only)

**Tier:** 2 (apply after Tier 1 is stable)
**Source:** Composio Agent Orchestrator (`~/.claude/research/orchestration/agent-orchestrator/docs/03-patterns.md` § 1)
**Scope:** this repo only — `/Users/randytran/Codes/x-skills/`
**Touches (v1 initial ship):** `skills/x-shared/slot-schema.md` (new), `skills/x-shared/invocation-guide.md` (add Slot Resolution section), `skills/x-do/SKILL.md` (add `slots:` to frontmatter — pilot)
**Deferred (v2):** project `CLAUDE.md` `## Slots` override, `.agent-rules.md` layer, remaining 5 slots (`model`, `reviewer`, `executor`, `researcher`, `planner`), rollout to x-bugfix/x-research/x-review/x-design, `verifier`-slot retrofit of 06 step 4, `x-skill-review` slot-vocabulary audit (external)
**Status:** applied 2026-04-19 (v1 — x-do pilot; v2 + rollout deferred)
**Estimated effort:** 2–3 hours for v1 (schema + pilot frontmatter + one invocation-guide section)
**Depends on:** Proposal 04 applied (roles declared on x-do and x-review — slots use roles as the natural boundary; an `executor: inline` slot contradicts any non-executor role, which the schema encodes as a hard conflict). Proposal 07 applied (v1's 3-layer cascade plugs into the prompt-assembly ladder; v2's project-CLAUDE.md layer plugs in at ladder priority 2).

## Problem

Right now, every x-skill hard-codes its choices in prose:

- **Which model** — "use Opus for complex work, Sonnet for standard." This lives in prose and gets re-derived per execution.
- **Which workspace** — current directory, git worktree, temp dir. Implicit, never discussed.
- **Which verifier** — `verification-before-completion`? `x-skill-review`? Custom? Varies by skill.
- **Which reviewer** — `x-review`? `code-reviewer` subagent? A cross-model pass via x-omo? Depends on what the skill happens to say.

**Five concrete problems:**

1. **Not overridable per project** — if a project needs stricter verification (e.g., security-critical code), you'd have to fork the skill. (v1 does NOT close this — v2 does.)
2. **Hard to reason about** — to know what tooling a skill uses, you read the prose end-to-end.
3. **Duplication across skills** — the same "use Opus for hard work, Sonnet for simple" logic is replicated in multiple skill files.
4. **Can't A/B test** — you can't easily swap "use x-review" for "use cross-model-review" to compare.
5. **Violates DRY** — choices that *should* be configurable are baked into content.

**What v1 actually closes:** problems 2, 3, 5 (by giving those choices a declarative home). Problem 1 and 4 need v2's project-override layer.

## Pattern (from Composio AO)

Composio AO's defining architectural choice: **everything is a plugin slot**. Their 8 slots:

| Slot | Default | Alternatives |
|---|---|---|
| Runtime | tmux | process |
| Agent | claude-code | codex, aider, opencode |
| Workspace | worktree | clone |
| Tracker | github | linear, gitlab |
| SCM | github | gitlab |
| Notifier | desktop | slack, discord, composio, webhook |
| Terminal | iterm2 | web |
| Lifecycle | (core, non-pluggable) | - |

The core engine knows nothing about specific implementations — only the 8 interfaces. Plugins are npm packages with a `manifest + create + detect` contract. YAML decides which plugin fills each slot.

**The key insight:** separate *what the skill does* from *how it does it*. The "what" lives in the skill content. The "how" lives in slots that can be swapped without touching the content.

**For x-skills in a stateless markdown system, the applicable slot vocabulary is:**

| x-skill slot | Default | Purpose | v1? |
|---|---|---|---|
| `model` | (agent-managed) | LLM for the skill's primary reasoning | v2 |
| `workspace` | `current-dir` | Code isolation strategy | **v1** |
| `verifier` | `verification-before-completion` | Post-impl verification | **v1** |
| `reviewer` | `code-reviewer` (OMC agent) | Code review pass | v2 |
| `executor` | `executor` (OMC agent) | Applies code changes | v2 |
| `researcher` | `x-research` | Researches dependencies/context | v2 |
| `planner` | `superpowers:writing-plans` | Produces structured plans | v2 |

**We're not building a runtime plugin registry.** These slots are *configuration keys* that the agent reads from frontmatter and honors during dispatch. Zero new runtime infrastructure.

## Enforcement honesty (read this first)

The Skill tool does not parse a `slots:` field from frontmatter — only `name:` and `description:` are schema. This proposal's slot block is **prominently-formatted prose that the model must self-read and honor at dispatch time**. There is no loader-level validation, no runtime refusal, and no way to "gate" a skill's execution on invalid slot values.

**v1 is therefore declarative-only**, in the same enforcement class as:
- Proposal 02 Phase 1 (reactions block)
- Proposal 04 (role forbids)
- Proposal 07 (precedence ladder)
- Proposal 06 (completion cascade)

Slot resolution is a self-check discipline, not a runtime contract. `x-skill-review` (external, deferred) can audit slot blocks on demand but cannot block skill loading. Read "the skill refuses" / "never silently fall back" language below as self-check commitments from the model, not platform guarantees.

## v1 scope (inverted per cross-model review 2026-04-09)

**v1 ships frontmatter-defaults-only. Project CLAUDE.md overrides are deferred to v2.**

The earlier draft of this proposal led with the full mechanism (skill bootstrap reads `<cwd>/CLAUDE.md`, greps for `## Slots`, parses YAML-in-markdown, merges against frontmatter defaults) and offered a "fallback position" for dropping the project-override story if the mechanism proved unreliable. All three reviewers (Claude constraint audit, Claude ergonomics audit, GPT-5.4 oracle architectural review) independently reached the same conclusion: **invert the framing**. The CLAUDE.md parser is the "closest thing in this set to sneaking in a config runtime" (oracle) and is asking the LLM to reliably Read → grep → parse YAML → merge → log on every skill invocation, which is the most fragile new discipline in the proposal.

**v1 scope (what ships in this migration):**
- Slot schema + canonical defaults (Part A below) — vocabulary covers all 7 slots for future-proofing, but only `workspace` and `verifier` are **emitted** by any skill in v1
- Skill frontmatter `slots:` declaration on x-do only (Part B)
- Observability self-check at dispatch: "Dispatching verifier slot → resolved to <value> via skill frontmatter default"
- 3-layer resolution cascade: **user-in-prompt > skill frontmatter > canonical default** (see Part C)

**v2 (deferred — do not ship on initial migration path):**
- Project-level `CLAUDE.md` `## Slots` block
- Skill-bootstrap Read/parse/merge mechanism
- User-in-prompt override beat-everything layer runtime tests (depends on proposal 07 precedence ladder — already applied, so this is a doc-alignment question, not a new mechanism)
- Remaining 5 slots (`model`, `reviewer`, `executor`, `researcher`, `planner`) emitted by any skill
- Rollout to x-bugfix, x-research, x-review, x-design
- Retrofit of 06 step 4 (verifier dispatch currently hard-codes `Agent` tool → `oh-my-claudecode:code-reviewer`) to resolve through the `verifier` slot
- `.agent-rules.md` layer (still reserved per 07 — not part of v2 either until a separate proposal introduces the convention)

v2 reference material (§ "v2 reference — project CLAUDE.md mechanism" near the end of Part A) is **reference-only for v1**, not actionable. A v1 reader should skim it, understand the long-run shape, then apply only the v1 scope above.

## Proposal

### Part A — Define the slot schema

Create `skills/x-shared/slot-schema.md`:

```markdown
# x-skill Plugin Slots (v1)

Skills declare their pluggable dependencies via frontmatter `slots:` block. v1 honors user-in-prompt overrides and skill-frontmatter defaults only. Project-level overrides are deferred to v2.

## Canonical slots (vocabulary)

| Slot | Type | Default | Purpose | Emitted in v1? |
|---|---|---|---|---|
| `model` | model-id | (agent-managed) | LLM for the skill's primary reasoning | No |
| `workspace` | workspace-strategy | `current-dir` | Code isolation strategy | **Yes** |
| `verifier` | **skill-or-agent** | `verification-before-completion` | Post-implementation verification. Type is `skill-or-agent` because valid values include both skills (e.g., `verification-before-completion`) and OMC subagents (e.g., `code-reviewer`). Callers must check which kind resolved and dispatch via `Skill` tool or `Agent` tool accordingly. | **Yes** |
| `reviewer` | **skill-or-agent** | `code-reviewer` | Code review pass. Same `skill-or-agent` rationale as `verifier`. | No |
| `executor` | skill-or-agent | `executor` (OMC agent) | Applies code changes | No |
| `researcher` | skill-name | `x-research` | Researches dependencies/context | No |
| `planner` | skill-name | `superpowers:writing-plans` | Produces structured plans | No |

"Emitted in v1" means a skill's frontmatter in this repo declares it. Non-emitted slots stay in the vocabulary for future use; no skill should add them until a follow-up proposal pilots them.

## Valid values

### `model` slot (vocabulary only — not emitted in v1)
- `claude-opus-4-6` — deep reasoning, architecture, complex debugging
- `claude-sonnet-4-6` — standard work (default)
- `claude-haiku-4-5` — quick lookups, trivial classification
- `gpt-5` — cross-model perspective (routes via x-omo Bash)
- `gemini` — cross-model perspective, multimodal (routes via x-omo Bash)
- `auto` — let the skill pick based on task complexity (default behavior)

### `workspace` slot (v1)
- `current-dir` — operate in the current working directory (default)
- `worktree` — create a git worktree via `superpowers:using-git-worktrees`, operate there
- `temp` — create a temporary directory, operate there, discard after

### `verifier` slot (v1)
**Type:** `skill-or-agent`. A verifier can be either a Skill-tool target or an Agent-tool subagent target — dispatch differs between the two, callers must check which kind of identifier resolved.
- `verification-before-completion` — superpowers default cascade (skill — dispatch via `Skill` tool)
- `x-verify` — local completion-cascade dispatcher (skill — dispatch via `Skill` tool; x-verify internally runs the cascade from 06)
- `x-skill-review` — when verifying a skill modification (skill, external — dispatch via `Skill` tool)
- `code-reviewer` — OMC agent (dispatch via `Agent` tool with `subagent_type: "oh-my-claudecode:code-reviewer"`)
- `custom:<skill-name>` — project-specific verifier (skill — dispatch via `Skill` tool)
- `none` — skip verification (DANGEROUS; requires explicit user approval inline before proceeding)

### `reviewer` slot (vocabulary only — not emitted in v1)
- `code-reviewer` — OMC code-reviewer subagent (default for code)
- `x-review` — full x-review skill with cross-model
- `cross-model-review` — shorthand for x-review with cross-model mandatory
- `none` — skip review (only for read-only research tasks)

### `executor` slot (vocabulary only — not emitted in v1)
- `executor` — dispatch to OMC executor subagent (**default**; routers cannot apply edits inline per proposal 04's role forbids)
- `inline` — current session applies edits. **⚠ Currently not usable by any x-skill.** Proposal 04 declares "No x-skill should declare `role: executor`" — therefore no x-skill can legally carry a role that permits `inline`. This value is retained in the vocabulary for future executor-role skills (if any are ever introduced). Setting `executor: inline` on a router, reviewer, or any other current x-skill is a **hard contradiction**: the skill must surface the conflict inline and refuse to dispatch. `x-skill-review` (external) should flag any `executor: inline` declaration as a role/slot conflict.
- `x-omo:<model>` — route edits through a non-Claude CLI (rare)

## Slot precedence (v1 — 3-layer cascade)

When resolving a slot value, check in order (first match wins):

1. **User's explicit request in the current prompt** — "use x-review this time" / "skip verification" → wins.
2. **Skill frontmatter `slots:` block** — the skill's declared default.
3. **Canonical default from this schema** — ultimate fallback.

If no layer specifies a slot, use the default.

**Why only 3 layers in v1:**
- v1 does **not** read project `CLAUDE.md` for a `## Slots` block. That mechanism is v2.
- `.agent-rules.md` is reserved per proposal 07 but not active — no file by that name exists and skills do not read it. Until a separate proposal introduces the convention (file format, discovery mechanism from arbitrary cwd, parse-failure handling), slot resolution uses the 3-layer cascade above. Do not cite `.agent-rules.md` in code paths that expect it to be a working override.

Proposal 07's full 9-layer precedence ladder governs how *instructions* resolve. The 3-layer slot cascade plugs into that ladder at two points: user-in-prompt = ladder priority 1, skill frontmatter = ladder priority 6. Canonical default is the implicit fallback (not a ladder layer).

## Slot resolution example (v1)

User prompt: "refactor this module"
Skill: `x-do` with `slots: { workspace: current-dir, verifier: verification-before-completion }`
Resolution:
- workspace: `current-dir` (from skill frontmatter; no user override)
- verifier: `verification-before-completion` (from skill frontmatter; no user override)

User prompt: "refactor this module, but skip the verifier this time"
Resolution:
- workspace: `current-dir` (from skill frontmatter)
- verifier: `none` (user-in-prompt override — requires x-do to surface the "DANGEROUS; explicit approval needed" prompt before proceeding)

## v2 reference — project CLAUDE.md mechanism

**⚠ Not shipped in v1. Reference only.** v2 will add a layer between 1 and 2:

1. User's explicit request in current prompt
2. **(v2) Project `CLAUDE.md` `## Slots` block** — per-project slot overrides
3. Skill frontmatter `slots:` block
4. Canonical default

The planned v2 mechanism: at skill bootstrap, call `Read` on `<cwd>/CLAUDE.md`. Look for a fenced code block or top-level heading `## Slots` followed by a YAML-shaped block. Parse it as a flat map of `slot-name: value`. Merge parsed values over skill-frontmatter defaults. On parse failure, surface the error inline and ask the user whether to use skill defaults or abort. One file per invocation; no directory walk.

v2 will need its own proposal covering: exact discovery contract (cwd only? repo root? ancestor walk?), parse-failure handling, interaction with monorepos (sub-projects each needing their own CLAUDE.md or one at root winning), and a dry-run audit pattern. Do not act on this section in v1.
```

### Part B — Extend skill frontmatter schema (v1 pilot: x-do only)

Update `skills/x-do/SKILL.md` frontmatter to add a `slots:` block. **Preserve everything else** — the existing `name`, `description`, `role: router`, and `reactions:` block (from 02 Phase 1) all stay exactly as-is.

**Placement rule:** `slots:` goes *after* `role:` and *before* `reactions:`, matching the intra-frontmatter precedence (`role` > `slots` > `reactions` per `00-overview.md` § "Intra-frontmatter precedence").

**Before (current x-do frontmatter, post-02 Phase 1):**

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
  # ... (remaining 8 triggers unchanged)
---
```

**After (v1 pilot — adds `slots:` between `role:` and `reactions:`):**

```yaml
---
name: x-do
description: Use when the user asks to build, implement, fix, or execute a plan — detects context (existing plan, new feature, bug, quick task, visual input) and routes through brainstorming, planning, debugging, or execution workflows
role: router
slots:
  workspace: current-dir                   # Override to `worktree` per-task for isolation
  verifier: verification-before-completion # x-do's Completion section dispatches x-verify, which internally runs this cascade
reactions:
  research-needed:
    action: route
    to: x-research
    auto: true
  # ... (remaining 8 triggers unchanged)
---
```

**Notes:**
- v1 emits only `workspace` and `verifier`. Do not add the other 5 slots.
- The `verifier` value declares intent — x-do's Completion section still dispatches `x-verify` (per 06), and x-verify internally runs `verification-before-completion` as step 3 of the cascade. Retrofit of 06 step 4 to resolve through this slot is explicitly deferred to the post-v1 rollout.
- No body edits. The slot block is declarative; it does not change x-do's workflow prose in v1.

**Other skills (x-research, x-review, x-bugfix, x-design, x-verify, x-api-pentest, x-omo, x-skill-review, x-skill-improve, x-shared):** no changes in v1. They will receive slot blocks in the v2 rollout.

### Part C — Slot resolution at dispatch time

Add a new section to `skills/x-shared/invocation-guide.md` (placement: after the "Orchestration Primitives — Pick One Explicitly" section added by 03, before the Dependencies footer if any). Title: "Slot Resolution — How to Pick Which Implementation (v1)".

```markdown
## Slot Resolution — How to Pick Which Implementation (v1)

When a skill is about to dispatch to one of its slots (`workspace`, `verifier` in v1), resolve the slot value using this 3-layer cascade:

### 1. Check user override in current prompt

Did the user say "use x-review this time" / "skip verification" / "run in a worktree"? That wins. Name the override inline before dispatching.

### 2. Check skill frontmatter `slots:` block

Whatever the skill declares is the next-most-authoritative source.

### 3. Fall back to default from `slot-schema.md`

Canonical defaults live in `x-shared/slot-schema.md`. Use if neither step 1 nor step 2 supplied a value.

**Not in v1:** `.agent-rules.md` (reserved per 07, not active), project `CLAUDE.md` `## Slots` block (v2).

### When dispatching, name the resolved slot (self-check observability)

When the skill fires off a subagent or sub-skill, be explicit about which slot and which resolution wins:

> "Dispatching verifier slot → resolved to `x-verify` via skill frontmatter default"

This makes slot resolution observable by surfacing the resolution source in the skill's own output. Users can see *why* a particular implementation was picked. Skip this log line and the slot might as well not exist — observability IS the v1 discipline.

### Surfacing an invalid slot (no runtime refusal)

If a slot resolves to a value not in `slot-schema.md` (typo, unknown skill), the skill cannot "refuse to load" — the harness has already loaded it. What it *can* do is surface the error inline and ask the user before dispatching:

> "🔴 Slot `verifier` resolved to `veriifcation-before-completion` (typo?). Valid values: verification-before-completion, x-verify, x-skill-review, code-reviewer, custom:<skill>, none. Which did you mean?"

Do not silently fall back to a different slot when the resolution is ambiguous — pause and ask.

### `skill-or-agent`-typed slot dispatch (verifier, reviewer, executor)

When the resolved value is a `skill-or-agent` type, check which kind the identifier names:

- **Skill** (e.g., `verification-before-completion`, `x-verify`, `x-skill-review`) → dispatch via `Skill` tool.
- **OMC agent** (e.g., `code-reviewer`) → dispatch via `Agent` tool with `subagent_type: "oh-my-claudecode:<name>"`.

Do not confuse the two. This is exactly the distinction proposal 06 step 4 hard-codes today (Agent → code-reviewer); once the verifier-slot retrofit lands post-v1, x-verify will consult this resolution cascade instead of hard-coding.
```

### Part D — Migration steps

All steps in this application edit files in this repo only.

**Step 1** — Create `skills/x-shared/slot-schema.md` (Part A). Pure documentation.

**Step 2** — Add Part C's "Slot Resolution" section to `skills/x-shared/invocation-guide.md`. Placement: after the "Orchestration Primitives — Pick One Explicitly" section added by 03.

**Step 3** — Edit `skills/x-do/SKILL.md` frontmatter to add the `slots:` block (Part B). Preserve `name`, `description`, `role: router`, and the entire `reactions:` block from 02 Phase 1. Placement: between `role:` and `reactions:`.

**Step 4** — Dry-run audit: verify that (a) `slot-schema.md` exists, (b) invocation-guide has the Slot Resolution section, (c) x-do's frontmatter round-trips through any YAML-aware tool without parse errors (the `slots:` block is a simple flat map; no nesting).

**Step 5** — Update status in `00-overview.md` step 7 row and this proposal's `Status:` header to "applied 2026-04-19 (v1 — x-do pilot; v2 + rollout deferred)".

**Exit gate for promoting to v2:** v1 is stable once (a) one real x-do session shows the "Dispatching <slot> → resolved to …" self-check emitting, (b) at least one user-in-prompt override is observed being honored, (c) no invalid-slot false positives have been reported. Only then draft a v2 proposal covering project CLAUDE.md parsing, `.agent-rules.md` activation (if anyone wants it), and rollout to the remaining skills.

### Part E — What v1 deliberately does NOT ship

- Project `CLAUDE.md` `## Slots` parsing — v2
- `.agent-rules.md` layer — still reserved per 07
- Rollout to x-bugfix, x-research, x-review, x-design, x-verify — v2
- Emission of `model`, `reviewer`, `executor`, `researcher`, `planner` slots by any skill — v2 per slot
- Retrofit of 06 step 4 (x-verify's MANDATORY FALLBACK) to use the `verifier` slot — post-v1 follow-up
- `x-skill-review` slot-vocabulary audit checklist items — external, defer until x-skill-review comes in-repo
- JSON-Schema validation of slot blocks — future optimization, not v1
- Slot composition / inheritance / dynamic re-resolution — rejected; see "Patterns considered and rejected"

## Validation (v1 only)

**Test 1 — Schema file exists and is complete.** After Step 1, `skills/x-shared/slot-schema.md` contains the canonical-slot table (7 slots), valid-values per slot, 3-layer cascade, v2 reference cordon, and the role/executor hard-contradiction rule.

**Test 2 — Invocation-guide has the Slot Resolution section.** After Step 2, `skills/x-shared/invocation-guide.md` has a "Slot Resolution — How to Pick Which Implementation (v1)" section placed after the Orchestration Primitives section. It documents only the 3-layer cascade and the `skill-or-agent` dispatch rule.

**Test 3 — x-do frontmatter is valid and minimal.** After Step 3, x-do's frontmatter has `slots: { workspace: current-dir, verifier: verification-before-completion }` and nothing else in the slots block. `role: router` and the reactions block are unchanged. No body edits.

**Test 4 — Skill-frontmatter default resolves correctly (self-check).** In a dry-run, if x-do is invoked and reaches a point where a `workspace` or `verifier` slot would dispatch, the agent's self-check logs "Dispatching <slot> → resolved to <value> via skill frontmatter default". If no log line appears, the skill is not honoring the slot block.

**Test 5 — User-in-prompt override is honored (self-check).** User prompt: "run x-do but skip the verifier this time." Expected: x-do's Completion section either (a) surfaces "Dispatching verifier slot → resolved to `none` via user-in-prompt override; DANGEROUS — confirm before proceeding", or (b) declines the override if the skill judges it unsafe. Either behavior is v1-compliant; silent fallback to the default verifier is NOT compliant.

**Test 6 — Invalid slot value surfaces (self-check).** If a hypothetical edit introduced `slots: { verifier: x-typo-name }`, on next dispatch the skill surfaces an inline error naming the typo and pausing for user input. v1 does not ship this test as a live fixture (would require editing x-do frontmatter to a broken state); the behavior is documented in Part C as a self-check expectation.

**Success metric:** v1 is a vocabulary + declarative-placement migration. Success is:
- Schema doc ships
- x-do frontmatter emits 2 slots without breaking existing frontmatter features (name/desc/role/reactions)
- The invocation-guide documents how to read the cascade
- One real x-do session demonstrates the self-check log line firing (proves the discipline is internalized, not just documented)

Problem-closure for problem #1 (project override) and problem #4 (A/B testing) arrives in v2 only. Do not claim v1 closes them.

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Slot resolution logic grows complex in v1 | Low | Only 3 layers and 2 slots in v1. Documented in one place. |
| Over-slotting — author adds all 7 slots to x-do "because they can" | Medium | Part B explicitly limits v1 to 2 slots. Schema table's "Emitted in v1?" column blocks drift. |
| Slot vocabulary drift — skills invent new slot names | Low-Medium | Canonical list in `slot-schema.md`. `x-skill-review` (external) would flag; until then, reviewers catch at PR time. |
| Self-check log line never fires in practice (slot block is inert decoration) | **Medium** | Test 4 + Test 5 are specifically about observing the log. If a real session doesn't produce it, v1 has failed its exit gate. Do not promote to v2 until this is observed. |
| Agent confuses Skill-tool vs Agent-tool dispatch for `skill-or-agent` typed slots | Medium | Part C's "`skill-or-agent`-typed slot dispatch" section enumerates both cases with concrete examples (code-reviewer via Agent tool; verification-before-completion via Skill tool). |
| Backward compat — existing skill invocations stop working | Low | Slots are additive. x-do's frontmatter gains a field; every existing field and body section is preserved. Skills without slots (all others in v1) work exactly as before. |
| Conflict with existing frontmatter (intra-precedence drift) | Low | `00-overview.md` § "Intra-frontmatter precedence" already codifies `role > slots > reactions`. Part B's placement rule honors this. |
| User expects project CLAUDE.md override to work (reads earlier-draft 05 from history or research notes) | Medium | v1 scope is signposted heavily in this doc. Part A's "v2 reference" cordon is explicit. If confusion reaches the user, surface the v1-vs-v2 distinction inline. |
| 06 step 4's hard-coded code-reviewer dispatch becomes stale once verifier slot exists | Low | Deferred as a named follow-up item. Retrofit is a one-line change once the cascade-consumer side is wired. |

**Rollback plan:** Delete the `slots:` block from x-do's frontmatter. Delete the Slot Resolution section from `invocation-guide.md`. Delete `slot-schema.md`. x-do falls back to hard-coded choices in prose. No downstream effects because no other skill emits slots in v1.

## Patterns considered and rejected

**Runtime slot registration** (skills call `registerSlot(name, impl)` at load time) — Out of scope. Adds runtime state. Frontmatter declaration is sufficient.

**Slot validation via JSON Schema** — Rejected for v1. `slot-schema.md` is a markdown contract; validation is the author's job (at PR time) and `x-skill-review`'s job (async, external). Moving to JSON Schema is a future optimization if the vocabulary grows beyond 7 slots.

**Plugin marketplace** (skills installed like npm packages, each providing slot implementations) — Way out of scope.

**Slot composition** (`verifier: [verification-before-completion, x-skill-review]` — run both) — Rejected as premature. If a skill needs multiple verifiers, dispatch both explicitly in content. Don't make slots accept arrays.

**Slot inheritance** (one skill inherits another's slots) — Rejected as premature. Skills are flat; inheritance adds complexity without clear benefit.

**First-class `auto` resolution** (the `model: auto` value resolved at runtime by a classifier) — Kept as a default value in the vocabulary for v2, but the resolution logic lives in skill prose, not in a new runtime. `auto` means "skill picks based on its own rules."

**Ship v1 with project CLAUDE.md overrides active** — Rejected per three-reviewer consensus (2026-04-09). The CLAUDE.md Read/parse/merge mechanism is the most fragile discipline in the full proposal; splitting it to v2 lets v1 prove the lighter-weight piece first.

**Pilot on multiple skills in v1** — Rejected. x-do is the most complex skill (router + reactions + Completion section); if slots compose cleanly with that frontmatter, rollout to simpler skills is mechanical. Piloting across multiple skills risks drift and fragments review attention.

**Pilot on x-verify instead of x-do** — Considered and rejected. x-verify's step 4 currently hard-codes `Agent` tool dispatch (per 06); making x-verify consume a verifier slot requires threading the slot through its cascade, which is a second hop of complexity. Retrofit 06 step 4 as a separate follow-up once v1 proves the pattern works declaratively.

## Out of scope for v1

- **Slot values from external configs** (environment variables, JSON files) — v2 or later
- **Slot overrides via command-line flags** — skills are invoked via the Skill tool; no CLI flags
- **Dynamic slot re-resolution mid-skill** — slots resolve once at skill start, not continuously
- **Slots for non-skill tools** (Bash commands, MCP tools) — slots are for skill/agent dispatch, not tool calls
- **Cross-skill slot sharing** — each skill has its own slots; no shared pool
- **Slots inside x-shared's own contents** (helper docs don't have frontmatter that Skill tool reads)
- **Project overrides of any form** — v2

## References

- Source pattern: `~/.claude/research/orchestration/agent-orchestrator/docs/03-patterns.md` § "1. Plugin slots as first-class architectural decision"
- Composio AO 8-slot architecture: `~/.claude/research/orchestration/agent-orchestrator/docs/01-architecture.md` § "The 8 plugin slots"
- Related proposals in this repo:
  - **04 applied** — roles declared on x-do and x-review; slots complement roles (roles define *what* the skill does; slots define *how*). Hard contradictions are surfaced as role/slot conflicts.
  - **07 applied** — 9-layer precedence ladder. v1's 3-layer slot cascade plugs into the ladder at priorities 1 (user-in-prompt) and 6 (skill frontmatter).
  - **06 applied** — x-verify's MANDATORY FALLBACK hard-codes `Agent` → `oh-my-claudecode:code-reviewer`. Retrofit to resolve through the `verifier` slot is a post-v1 follow-up.
  - **02 Phase 1 applied** — reactions block on x-do. Part B preserves it exactly.
  - **03 applied** — orchestration primitives (handoff / assign). Part C placement sits after the primitives section in invocation-guide.
