# Invocation Guide (Shared)

How to invoke tools from any x-skill.

| What | Tool | Notes |
|------|------|-------|
| **Invoking a skill** (superpowers, oh-my-claudecode, x-*) | `Skill` tool | Never `Read` to *invoke* a skill — Skill tool loads it properly and runs its workflow |
| **Loading a skill file as reference** (e.g., x-omo agent catalog during bootstrap) | `Read` tool | Allowed — reads the markdown for inline reference without triggering invocation |
| **OMO agents** (explore, oracle, etc.) | `Bash` tool, timeout **600000** | Never Agent/Task tool — silently downgrades to Claude instead of using the target model |
| **OMC agents** (code-reviewer, executor, etc.) | `Agent` tool with `subagent_type` | e.g., `subagent_type="oh-my-claudecode:code-reviewer"` |

## OMO Agent Invocation

```bash
# Role agent
omo-agent <agent-name> "<prompt>"

# Model routing
omo-agent --model <alias> "<prompt>"

# Attach files
omo-agent --file /path/to/file oracle "<prompt>"
```

For the full agent catalog, see the [OMO skill](../x-omo/SKILL.md).

## MANDATORY: Collect All Background Results Before Final Output

When launching agents with `run_in_background: true`, you **MUST** wait for **ALL** agents to complete and collect **ALL** results before generating any synthesis or final output.

**Do NOT:**
- Generate a final answer after only some agents return
- Skip collecting results from slower agents
- Synthesize partial results as the "final" output
- Proceed to the next workflow step until every background agent has returned

**How to collect:**
- **Agent tool** (OMC agents): You receive a notification when each background agent completes. Wait for ALL notifications before proceeding.
- **Bash tool** (OMO agents): Background commands notify on completion. Wait for ALL notifications before proceeding.

**If an agent is slow:** Wait. Do not generate interim results and call them final. The user expects a complete synthesis from all perspectives.

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
| 6 | **Skill frontmatter** (`role:`, `slots:`, `reactions:`) | e.g., `role: router` on `x-do` | Per-skill |
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

## Orchestration Primitives — Pick One Explicitly

Every subagent dispatch in an x-skill picks one of these two primitives. The author names which primitive they're using. Unnamed = bug.

### 1. `handoff` — Sync delegation (default for pipelines)

**Semantics:** Dispatch a subagent, **wait** for the result, continue with that result.
**Use when:** Task B depends on Task A's output.
**How:** Single `Agent` tool call. Next step runs only after it returns.

**Context envelope requirement:** Every `handoff` dispatch MUST include a handoff-context block conforming to the format in `context-envelope.md` (From / Type/Mode / Key finding / Agents used / Recommendation / Artifacts). Skipping the envelope is the "handoff context missing" compliance gap — the sole failure mode this primitive claims to close. If the envelope is missing, the handoff itself is wrong, not just stylistically incomplete.

```
Example:
  handoff → code-reviewer subagent with the diff + context envelope
  wait for review result
  handoff → executor subagent with the review + original task + context envelope
```

**Rule:** Handoffs are sequential. If you can express the same work as parallel, use `assign` instead.

### 2. `assign` — Async fan-out (default for independent work)

**Semantics:** Dispatch **N subagents at once in a single message**, then wait for **all** of them to finish before synthesizing.
**Use when:** You have 2+ tasks that don't depend on each other.
**How:** Multiple `Agent` tool calls **in the same message**. All calls go in one tool-use block.

```
Example:
  assign → [explore agent, librarian agent, oracle agent] in ONE message
  wait for all three to complete (see "Collect All Background Results" above)
  synthesize
```

**HARD RULE (from feedback_xreview_compliance.md):**
All fan-out `Agent` calls **MUST be in a single message**. If you write one Agent call, send it, then write another — STOP. That's sync handoff disguised as fan-out. Re-do as one message.

**Detection check:** Before dispatching, ask "could any of these agents depend on another's result?" If no → use `assign`. If yes → that's `handoff`.

### 3. `send_message` — DEFERRED, not part of the canonical vocabulary

**Status:** **Dropped from the canonical vocabulary.** In Claude Code's subagent model, agents are request-response — there is no stable "send a message to a running subagent's inbox" primitive. Every attempt to use `send_message` either maps to (a) a fresh `handoff` or `assign`, or (b) inline iteration within one `Agent` call that was always a single call.

If a future platform capability makes true iterative steering available (e.g., a subagent continuation API), revisit this primitive and add it to the vocabulary. Until then, the canonical set is **two primitives: `handoff` and `assign`.** Authors who think they need `send_message` should re-read the problem — they almost always mean `handoff` (sync) or `assign` (parallel).

**Do NOT** invent an ad-hoc `send_message` in a skill's dispatch code. If you think you need iterative steering, surface the need and discuss — don't paper over it with a primitive name that has no runtime meaning.

### Primitive Selection Table

| Signal | Primitive |
|---|---|
| Single task whose result the caller needs | `handoff` |
| N tasks, independent, caller needs all results before synthesizing | `assign` (one message) |
| N tasks, first result wins (speculative) | `assign` + ignore slower results |
| Chained pipeline (A → B → C) | `handoff` ×3 |
| Research fan-out (e.g., codebase + librarian + oracle) | `assign` (one message) |
| Cross-model second opinion | `handoff` to x-omo Bash invocation |
| Long-running task that needs mid-course nudge | **Not supported in this environment** — re-express as `handoff` (sync waits until done) or `assign` (parallel re-dispatch of a refined follow-up). See "3. `send_message`" above. |
| Follow-up question to an already-dispatched research agent | `assign` again — dispatch a fresh subagent with the refined question; do not try to nudge an existing one |

### Violation Checks (self-check before dispatching)

Before every dispatch, answer these. Getting any wrong = re-do:

1. **"What primitive am I using?"** — If you can't name `handoff` or `assign`, re-read this section. If you think you need `send_message`, re-read § "3. `send_message`" above — you almost certainly mean `handoff` or `assign`.
2. **"If `assign`, are all calls in ONE message?"** — If you're about to send a second message to dispatch agent #2, STOP. Re-do as one message.
3. **"If `handoff`, does the next step actually need the first step's result?"** — If no, use `assign`.
4. **"If `handoff`, did I include a context envelope?"** — If no, the handoff is wrong. See `context-envelope.md`.

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

> "🔴 Slot `verifier` resolved to `veriifcation-before-completion` (typo?). Valid values: verification-before-completion, x-verify, x-skill-review, code-reviewer, custom:<skill>. Which did you mean?"

Do not silently fall back to a different slot when the resolution is ambiguous — pause and ask.

### `skill-or-agent`-typed slot dispatch (verifier, reviewer, executor)

When the resolved value is a `skill-or-agent` type, check which kind the identifier names:

- **Skill** (e.g., `verification-before-completion`, `x-verify`, `x-skill-review`) → dispatch via `Skill` tool.
- **OMC agent** (e.g., `code-reviewer`) → dispatch via `Agent` tool with `subagent_type: "oh-my-claudecode:<name>"`.

Do not confuse the two. This is exactly the distinction proposal 06 step 4 hard-codes today (Agent → code-reviewer); once the verifier-slot retrofit lands post-v1, x-verify will consult this resolution cascade instead of hard-coding.
