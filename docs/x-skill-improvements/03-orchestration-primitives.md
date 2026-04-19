# 03 — Two Orchestration Primitives: `handoff` / `assign` (plus `send_message`, deferred)

> **Title fixed 2026-04-09 per cross-model review.** The earlier title advertised three primitives but the body drops `send_message` from the canonical vocabulary. The canonical set is two: `handoff` (sync single-target) + `assign` (parallel fan-out in one message). `send_message` is documented as deferred / future-capability only.
>
> **Naming collision disclosure:** `handoff` is also the name of an existing user-invocable skill (`handoff — Create a detailed context summary for continuing work in a new session`). In this proposal, "handoff" always refers to the **dispatch primitive**, never to the skill. Skill authors referencing the primitive in prose should write "handoff primitive" or "handoff (dispatch)" on first mention in each section to avoid ambiguity. If collision proves confusing in practice, fallback rename candidates (for a future proposal) are `delegate` (sync) and `fanout` (parallel) — tracked here as an advisory, not applied now.
>
> **`assign` naming note:** `assign` is weaker than `fanout` for conveying "parallel in one message" — if a future rewrite renames primitives, prefer `fanout`. For now, the proposal body + (eventual) `x-skill-review` checklist language compensate with explicit "one message" language everywhere.

**Tier:** 1 (apply first)
**Source:** AWS CLI Agent Orchestrator (`~/.claude/research/orchestration/cli-agent-orchestrator/docs/03-patterns.md` § 3)
**Scope:** this repo only — `/Users/randytran/Codes/x-skills/`
**Touches (this application):** `skills/x-shared/invocation-guide.md` (Part A only)
**Deferred:** per-skill retrofit (Part B), `x-skill-review` checklist (Part C — skill lives outside this repo)
**Status:** applied 2026-04-19 (Part A only; Part B retrofit + Part C checklist deferred)
**Estimated effort:** 1–2 hours (docs pass only; retrofit is a later step per `00-overview.md` migration order)

## Problem

Your x-skills currently use a single implicit dispatch pattern: "spawn a subagent and wait for it." This conflates three distinct patterns that should be different:

1. **Sync handoff** — A depends on B's result. Caller blocks waiting.
2. **Async fan-out** — N independent things can happen in parallel. Caller dispatches all and waits for all.
3. **Iterative messaging** — A long-running agent receives nudges or refinements from the supervisor mid-execution.

**Evidence that this is a real problem:**

- `feedback_xreview_compliance.md` lists "one-message launch" as a recurring gap. That's literally "the agent did serial dispatch when it should have done parallel fan-out." The current skill language doesn't force the author to pick a pattern, so the default is "sequential" — which is wrong for fan-out.
- `x-research` Type D (codebase + librarian parallel) is the clearest fan-out case, and it often gets implemented as two sequential dispatches instead of one parallel message.
- `x-bugfix` hypothesis testing is fan-out in theory but often done serially.
- `x-review` multi-reviewer passes are fan-out but frequently implemented one reviewer at a time.

The root cause isn't bad authors — it's missing vocabulary. When the skill prose just says "dispatch a subagent," the author has no forcing function to name whether this is sync or async. **Missing vocabulary = accidental default = bug.**

## Pattern (from CAO)

CAO exposes three orchestration verbs as distinct MCP tools, not one flexible "delegate":

| Verb | Semantics | When to use |
|---|---|---|
| `handoff` | Spawn agent, send task, **wait for completion**, return output, auto-exit agent | Sequential pipelines (plan → review → ship) |
| `assign` | Spawn agent, send task with callback instructions, **return immediately**. Agent reports back via `send_message` when done. Messages queued if supervisor busy. | Fan-out parallelism (N analysts in parallel) |
| `send_message` | Send a message to an existing terminal's inbox. Delivered when target is idle. | Iterative coordination with long-running agents |

**Why naming matters:** Each verb corresponds to a different correctness requirement:
- `handoff` — caller needs the result to continue. Blocking is correct.
- `assign` — caller can't make progress until N results are in. Blocking on the first one serializes unnecessarily.
- `send_message` — caller wants to nudge an agent without spawning a new one.

Conflating them forces every workflow into the most restrictive pattern. Separating them lets authors compose them in one workflow.

**In our context (x-skills inside one Claude Code session), the mapping is:**

| CAO verb | x-skill equivalent |
|---|---|
| `handoff` | Single `Agent` tool call, wait for result before continuing |
| `assign` | Multiple `Agent` tool calls **in one message**, then wait for all results |
| `send_message` | Not available — Claude Code subagents are request-response; there is no stable "message a running subagent" primitive |

The two supported verbs are already technically possible in Claude Code. What's missing is the **named vocabulary** that tells skill authors which one they're using.

## Enforcement honesty

Claude Code's Skill tool only parses `name:` and `description:` from frontmatter. The primitives are **a vocabulary contract the model self-applies** when writing dispatch code. No runtime checks that every dispatch is labelled, no refusal to dispatch unlabelled work.

**What this proposal provides:** a named vocabulary + self-check prompts that authors and the runtime model can use to identify whether a dispatch is sync (`handoff`) or fan-out (`assign`). Same enforcement class as 02's reactions, 04's roles, 05's slots, and 07's precedence ladder.

**What this proposal does NOT provide:** runtime guarantees that every `Agent` call is preceded by a primitive name, or that `assign` calls always land in a single message. A later checklist in `x-skill-review` (deferred to a follow-up, since that skill is external to this repo) would be the audit surface.

## Proposal

### Part A — Add primitives to `skills/x-shared/invocation-guide.md`

Append a new section to `skills/x-shared/invocation-guide.md` (after the "Prompt Assembly — Precedence Ladder" section appended by proposal 07):

```markdown
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

### Primitive Selection Table (for routing decisions)

Use this table to pick which primitive applies to your dispatch. Canonical vocabulary is **two primitives**.

| Signal | Primitive |
|---|---|
| Single task whose result the caller needs | `handoff` |
| N tasks, independent, caller needs all results before synthesizing | `assign` (one message) |
| N tasks, first result wins (speculative) | `assign` + ignore slower results |
| Chained pipeline (A → B → C) | `handoff` ×3 |
| Research fan-out (e.g., codebase + librarian + oracle) | `assign` (one message) |
| Cross-model second opinion | `handoff` to x-omo Bash invocation |
| Long-running task that needs mid-course nudge | **Not supported in this environment** — re-express as `handoff` (sync waits until done) or `assign` (parallel re-dispatch of a refined follow-up). See "3. `send_message`" section above. |
| Follow-up question to an already-dispatched research agent | `assign` again — dispatch a fresh subagent with the refined question; do not try to nudge an existing one |

### Violation Checks (agent self-checks before dispatching)

Before every dispatch, the agent answers these. Getting any wrong = re-do:

1. **"What primitive am I using?"** — If you can't name `handoff` or `assign`, stop and re-read this section. If you think you need `send_message`, re-read § "3. `send_message`" above — you almost certainly mean `handoff` or `assign`.
2. **"If `assign`, are all calls in ONE message?"** — If you're about to send a second message to dispatch agent #2, STOP. Re-do as one message.
3. **"If `handoff`, does the next step actually need the first step's result?"** — If no, you should be using `assign`.
4. **"If `handoff`, did I include a context envelope?"** — If no, the handoff is wrong. See `context-envelope.md`.
5. **"Am I respecting the reactions block?"** — See proposal 02 (when it ships). Dispatches that ignore frontmatter reactions are always wrong.
```

### Part B — Per-skill retrofit — DEFERRED

Per `00-overview.md:98` migration order, 03 ships as a docs pass first. The per-skill retrofit (naming the primitive at every dispatch site in `x-do`, `x-research`, `x-bugfix`, `x-review`) is deferred to a later step, after proposal 04's role forbid blocks are in place — retrofitting dispatch sites with forbid blocks already present is cheaper and catches role violations as a side effect.

For future reference when the retrofit runs, here are the intended before/after patterns.

**`x-research` Type D (codebase + external docs):**

Before:
```markdown
### Type D: Codebase + External Docs
Route to: morph-mcp codebase_search + librarian parallel
```

After:
```markdown
### Type D: Codebase + External Docs
Primitive: **`assign`** (fan-out, one message)
Dispatch: morph-mcp codebase_search + librarian subagent in a single message
Synchronization: wait for both before synthesis (see `x-shared/invocation-guide.md` § "Collect All Background Results")
```

**`x-do` plan-execute pipeline:**

Before:
```markdown
Step 1: Create plan via writing-plans skill
Step 2: Execute plan via executor
Step 3: Verify via verification-before-completion
```

After:
```markdown
Step 1: **`handoff`** → writing-plans skill, wait for plan file path
Step 2: **`handoff`** → executor agent with the plan, wait for completion
Step 3: **`handoff`** → verification-before-completion, wait for result
```

**`x-bugfix` hypothesis testing:**

Before:
```markdown
For each hypothesis, dispatch a subagent to verify it
```

After:
```markdown
**`assign`** → dispatch ALL hypothesis-verifier subagents in ONE message
Wait for all results, then synthesize which hypothesis the evidence supports
```

### Part C — `x-skill-review` checklist — DEFERRED (external)

`x-skill-review` lives at `~/.claude/skills/x-skill-review/`, outside this repo. Extending its checklist is valuable but crosses the "don't edit external deps" boundary (`feedback_no_external_deps.md`).

**Intended checklist items** (for when this ships — either in a follow-up proposal against the skill's home, or as an `x-skill-review` rewrite inside this repo):

```markdown
- [ ] **Orchestration primitives named** — Every dispatch names one of `handoff` / `assign`. Unnamed dispatches are bugs. `send_message` is NOT in the canonical vocabulary; flag authors who use it. (Reference: `x-shared/invocation-guide.md` § "Orchestration Primitives")
- [ ] **`assign` fan-outs are one-message** — Any `assign` dispatch must be in a single message with all Agent calls. Separate messages = sync handoff in disguise.
- [ ] **`handoff` chains are actually sequential** — Any `handoff` step's next step must actually need the previous result. If not, it should be `assign`.
- [ ] **Every `handoff` has a context envelope** — Per `context-envelope.md`. Missing envelope = wrong handoff, not stylistically incomplete.
```

Note: the earlier draft of this proposal listed `send_message` as one of the primitives to name in the checklist. That was inconsistent with the canonical-two decision in the preamble and has been removed.

### Part D — Reconciliation with `00-overview.md`

`00-overview.md:98` says step 4 of the migration is "add Parts A and C of the proposal to `x-shared/invocation-guide.md`." Part A lands in `invocation-guide.md` (this proposal, applied now). Part C's natural home is `x-skill-review/SKILL.md`, which is external. Two options:

1. **Leave Part C deferred.** Once `x-skill-review` is in this repo (or a follow-up proposal targets its home repo), apply Part C there. `00-overview.md` step 4 should be amended to say "Part A only; Part C deferred with x-skill-review."
2. **Co-locate Part C's checklist prose in `invocation-guide.md`** as a fallback, so `x-skill-review` can reference it when it eventually audits.

**Recommendation:** option 1. Co-locating review-checklist prose in an invocation guide muddies the doc's purpose. Amend `00-overview.md` to reflect the split.

## Migration steps

All steps edit files in this repo only.

**Step 1** — Append Part A's "Orchestration Primitives" section to `skills/x-shared/invocation-guide.md` (after the precedence ladder). Pure addition.

**Step 2** — Amend `00-overview.md:98` to split Part A (landing now) from Part C (deferred external). Remove the "Parts A and C" wording.

**Step 3** — Dry-run audit: read one skill (recommend `x-research`) and confirm its dispatch sites are understandable through the new vocabulary. If Type D already dispatches in a single message, the primitive is implicitly `assign`; if not, file a follow-up retrofit. Do NOT fix in this pass (that's the deferred retrofit).

## Validation

**Test 1 — Read-back.** After Step 1, the new section is appended to `invocation-guide.md`, names the two canonical primitives, and marks `send_message` as deferred.

**Test 2 — Overview reconciled.** After Step 2, `00-overview.md:98` no longer promises "Part C in invocation-guide.md"; step 4's scope is clearly Part A only.

**Test 3 — Live behavior change (deferred).** The behavior tests (fan-out actually parallelizes, handoff is actually sequential, one-message dispatch is enforced) can only be meaningfully run once Part B (retrofit) lands and names primitives at dispatch sites. Track for the retrofit step.

**Success metric:** the "one-message launch" gap from `feedback_xreview_compliance.md` stops recurring after retrofit. Track via `x-skill-improve` alignment log. This proposal's docs-pass-only step is a prerequisite; the behavior change arrives with the retrofit.

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Agent reads the primitive name but still defaults to sequential | Medium | Part A's "Violation Checks" gives the agent a self-check. The future `x-skill-review` checklist (Part C deferred) is the audit surface; until it lands, authors audit by hand. |
| Author forgets to name the primitive in new skill code | Medium | Part A's "Unnamed = bug" language is the forcing function. Until Part C lands, authors self-audit. |
| Vocabulary drift (author invents `parallel-dispatch` instead of `assign`) | Low | Canonical vocabulary is two words. Easy to enforce via code review. |
| Authors add `send_message` back into dispatches | Low | Section 3 is explicit; violation checks call it out. |
| Breaking existing skill invocations | Low | Part A is pure addition to a doc; no skill dispatch behavior changes until the deferred retrofit. |
| Overview wording ("Parts A and C") stays out of sync with reality | High if Step 2 skipped | Step 2 reconciles. Do not ship Step 1 without Step 2. |

**Rollback plan:** Revert the Part A append in `invocation-guide.md` and the edit in `00-overview.md`. Nothing else changed.

## Patterns considered and rejected

**Adding `handoff` / `assign` as first-class tools in Claude Code** — Out of scope. We work within the existing `Agent` tool. Naming is sufficient; we don't need new infrastructure.

**A fourth primitive: `broadcast`** (fire to all agents, don't wait for any) — Rejected because no current x-skill needs it. Could be added later as an extension.

**Reaction-based dispatch** (reactions block encodes the primitive) — Useful but orthogonal. Reactions (proposal 02) say *what* happens on a trigger; primitives (this proposal) say *how* to dispatch. They compose.

**CAO's actual inbox mechanism** — Rejected for x-skills because Claude Code subagents don't need inbox queueing; they're always ready to accept follow-up turns. The inbox watchdog pattern is for tmux-isolated processes, not same-session subagents.

**Co-locate Part C's checklist in `invocation-guide.md`** — Rejected (see Part D). Mixing review-checklist prose with an invocation guide confuses the file's purpose.

## Out of scope

- **Automatic primitive detection** — authors name primitives explicitly; auto-detection would hide bugs.
- **Per-primitive cost/latency budgets** — optimization work for later.
- **Primitives for MCP tool dispatches** — MCP tools are called inline, not via subagents, so the primitive vocabulary doesn't apply cleanly. Keep it subagent-scoped.
- **Real-time progress signals between primitives** — CAO has this via inbox; we don't need it because Claude Code's subagent model is request-response.
- **Extending `x-skill-review`** — deferred (skill lives outside this repo).
- **Per-skill retrofit** — deferred per `00-overview.md:98` migration order.

## References

- Source pattern: `~/.claude/research/orchestration/cli-agent-orchestrator/docs/03-patterns.md` § "3. Three orchestration primitives, not one"
- Compliance gaps closed (once retrofit lands): **2 of 6** — "one-message launch" (via `assign` primitive) and "handoff context missing" (via the context envelope requirement on every `handoff`, Part A § 1). See `00-overview.md` § "Compliance gap coverage" for the full gap-ownership table. This docs-pass-only application does not close gaps on its own — it establishes the vocabulary the retrofit will use.
- Related proposals: 02 (reactions block — reactions use primitive verbs for their `action:` field), 04 (role separation — roles constrain which primitives a skill can use), 07 (precedence ladder — determines how primitive-naming conflicts resolve across layers).
