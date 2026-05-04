# Shared Infrastructure (x-shared)

`x-shared` is a reference library used by all other x-skills via relative paths (`../x-shared/<file>.md`). It is **not invokable** as a skill — it has no `SKILL.md`.

## Why No SKILL.md

The Claude Code skill loader registers a directory as a skill only when it contains a `SKILL.md`. Omitting that file keeps `x-shared/` invisible to skill discovery while the files remain reachable via relative paths from sibling skills.

## Contents

| File | Purpose | Consumed By |
|------|---------|-------------|
| `capability-loading.md` | Bootstrap-pinned capability contract | All skills |
| `invocation-guide.md` | Tool invocation patterns + precedence ladder | All skills |
| `workflow-chains.md` | Common cross-skill chain sequences | All skills |
| `completion-cascade.md` | x-verify cascade specification | x-do (live), x-verify (dispatcher); rollout to x-bugfix, x-design, x-api-pentest, x-skill-improve is deferred |
| `context-envelope.md` | Handoff context block format | All skills |
| `severity-guide.md` | Finding severity scale (CRITICAL/HIGH/MEDIUM/LOW) | x-review, x-bugfix, x-api-pentest |
| `slot-schema.md` | Slot-fill schema for skills | All skills with slots |
| `mcp-toolbox.md` | Plugin-local MCP decision matrix with fallbacks | x-research, x-bugfix |
| `omo-routing.md` | Signal → OMO agent routing table | All skills |
| `reactions-vocabulary.md` | Cross-skill reaction signals | All skills with reactions |
| `common-gotchas.md` | Cross-skill operational pitfalls | All skills |

## Capability Loading (`capability-loading.md`)

Defines the single contract for how skills learn what's available.

**Principle**: Detect once at setup. Pin at bootstrap. Never re-check per dispatch.

**Sources of truth** (high → low):
1. Project override — `.x-skills/capabilities.json` (subtractive only)
2. User manifest — `~/.config/x-skills/capabilities.json`
3. Plugin defaults — empty set

**Skill bootstrap pattern**:
1. Look for `[x-skills/capabilities]` line in conversation context
2. If absent, read `~/.config/x-skills/capabilities.json` once with `jq`
3. Filter routing tables against the pinned set
4. Do not re-check per dispatch

## Invocation Guide (`invocation-guide.md`)

### Tool Invocation Matrix

| What | Tool | Notes |
|------|------|-------|
| Invoking a skill (superpowers, oh-my-claudecode, x-*) | `Skill` tool | Never `Read` to *invoke* a skill |
| Loading a skill file as reference | `Read` tool | Allowed — reads markdown without triggering invocation |
| OMO agents (explore, oracle, etc.) | `Bash` tool, timeout **600000** | Never Agent/Task tool — silently downgrades to Claude |
| OMC agents (code-reviewer, executor, etc.) | `Agent` tool with `subagent_type` | e.g., `subagent_type="oh-my-claudecode:code-reviewer"` |

### Mandatory: Collect All Background Results

When launching agents with `run_in_background: true`, you **MUST** wait for **ALL** agents to complete before generating synthesis or final output.

**Do NOT**:
- Generate a final answer after only some agents return
- Skip collecting results from slower agents
- Synthesize partial results as "final"

### Prompt Assembly — Precedence Ladder

When instructions conflict, the higher-priority layer wins. This is the canonical order that every x-skill assumes.

| Priority | Layer | Example | Scope |
|----------|-------|---------|-------|
| **0** | **Inviolable principles** | "never edit plugin cache" / "x-skills are routers" | Cannot be overridden |
| 1 | User's explicit in-prompt instructions | "skip the review this time" | Current turn |
| 2 | Project `CLAUDE.md` | Per-project rules | Current project |
| 3 | Repo `CLAUDE.md` (this repo's policy) | "x-skills are routers; no persistence" | This repo |
| 4 | Memory feedback files (advisory) | `feedback_xreview_compliance.md` | Global, advisory |
| 5 | `~/.claude/CLAUDE.md` (user's global) | "always use morph-mcp" | User's defaults |
| 6 | Skill frontmatter (`role:`, `slots:`, `reactions:`) | `role: router` on `x-do` | Per-skill |
| 7 | Skill body (markdown below frontmatter) | The actual skill instructions | Per-skill |
| 8 | Claude Code harness + superpowers defaults | Baseline behavior | Runtime |

**How conflicts resolve**: Walk the ladder from top to bottom. First layer that addresses the conflict wins.

**Example**: Skill body says "use native Grep". `~/.claude/CLAUDE.md` says "always use morph-mcp". No project or repo override.
- Priority 0–4: silent
- Priority 5: **user global wins** → use morph-mcp
- Skill body (priority 7) loses

### Orchestration Primitives

#### `handoff` — Sync Delegation

- **Semantics**: Dispatch a subagent, **wait** for result, continue with that result
- **Use when**: Task B depends on Task A's output
- **Requirement**: Must include a handoff context block

#### `assign` — Async Fan-Out

- **Semantics**: Dispatch **N subagents at once in a single message**, then wait for **all** before synthesizing
- **Use when**: You have 2+ tasks that don't depend on each other
- **Hard rule**: All calls must be in **ONE message**

#### `send_message` — DROPPED

This primitive is **not part of the canonical vocabulary**. In Claude Code's subagent model, there is no stable "send a message to a running subagent's inbox" primitive. The canonical set is **two primitives: `handoff` and `assign`**.

### Slot Resolution (v1)

When a skill is about to dispatch to one of its slots (`workspace`, `verifier`), resolve using this 3-layer cascade:

1. **User override in current prompt**: "use x-review this time" / "skip verification" → wins
2. **Skill frontmatter `slots:` block**: Declared default
3. **Canonical default from `slot-schema.md`**: Ultimate fallback

When dispatching, name the resolved slot for observability:
> "Dispatching verifier slot → resolved to `x-verify` via skill frontmatter default"

### `skill-or-agent`-typed slot dispatch

When the resolved value is a `skill-or-agent` type, check which kind the identifier names:
- **Skill** (e.g., `verification-before-completion`, `x-verify`) → dispatch via `Skill` tool
- **OMC agent** (e.g., `code-reviewer`) → dispatch via `Agent` tool with `subagent_type`

## Workflow Chains (`workflow-chains.md`)

Common sequences across x-skills:

| Workflow | Sequence |
|----------|----------|
| **Bug Fix** | `/x-bugfix` (Mode A/B/C) → `/x-review` → merge |
| **Deep Bug Investigation** | `/x-research` (Type A) → `/x-bugfix` (Mode B) → `/x-review` → merge |
| **New Feature** | `/x-research` (Type F) → `/x-do` (Mode B) → `/x-review` → merge |
| **Skill Audit** | `/x-skill-review` → `/x-do` (Mode A) → `/x-skill-review` (re-audit) |
| **Skill Improve** | Use x-skill → paste session into `/x-skill-improve` → apply fixes → `/x-skill-review` |
| **Quick Fix** | `/x-do` (Mode D) → `/x-review` (Target C: last commit) |
| **Architecture Decision** | `/x-research` (Type C) → `/x-do` (Mode B) |

### When to Chain vs. Skip

- **Trivial change** → just `/x-do` Mode D, skip research and review
- **Clear bug with stack trace** → skip research, go straight to `/x-bugfix` Mode A
- **Ambiguous bug, multi-component** → `/x-bugfix` Mode B (or `/x-research` first)
- **Exploratory question** → `/x-research` only, no need to chain forward
- **Full feature** → full chain: research → do → review → merge

## Context Envelope (`context-envelope.md`)

Optional convention for passing context between skills. Include when the "After This Skill" section routes to the next skill.

### Format

```markdown
## Handoff Context
- **From:** [skill name] | **Type/Mode:** [classification used]
- **Key finding:** [one-liner summary of what was learned/decided]
- **Agents used:** [list of agents that contributed]
- **Recommendation:** [next skill + mode/type to use]
- **Artifacts:** [file paths of any documents produced]
```

### Example

```markdown
## Handoff Context
- **From:** x-research | **Type:** F (Pre-Planning)
- **Key finding:** Auth system needs RBAC, current implementation only has binary auth
- **Agents used:** oracle, explore
- **Recommendation:** x-do Mode B (new feature)
- **Artifacts:** none (findings synthesized above)
```

## Severity Guide (`severity-guide.md`)

All review and audit findings across x-skills use this consistent scale:

| Severity | Meaning | Action | Examples |
|----------|---------|--------|----------|
| **CRITICAL** | Security vulnerability, data loss risk, crash in production path | Fix immediately, block merge | SQL injection, exposed secrets, null deref in hot path, missing SKILL.md |
| **HIGH** | Logic defect, spec deviation, broken functionality | Fix before merge | Wrong return value, missing validation, race condition, no progressive disclosure |
| **MEDIUM** | Quality concern, maintainability issue, test gap | Should fix, can negotiate | Missing error handling, no test for edge case, no gotchas section, hardcoded paths |
| **LOW** | Style preference, minor improvement, documentation | Optional, author's call | Variable naming, comment wording, description not trigger-specific |

### Triage Rules

- **CRITICAL + HIGH** = must fix before marking review/audit complete
- **MEDIUM** = recommend fixing, but author can defer with justification
- **LOW** = note it, don't block on it
- If ambiguous, lean toward the higher severity

## Slot Schema (`slot-schema.md`)

### Canonical Slots (v1)

| Slot | Type | Default | Purpose | Emitted in v1? |
|------|------|---------|---------|---------------|
| `model` | model-id | (agent-managed) | LLM for primary reasoning | No |
| `workspace` | workspace-strategy | `current-dir` | Code isolation strategy | **Yes** |
| `verifier` | **skill-or-agent** | `verification-before-completion` | Post-implementation verification | **Yes** |
| `reviewer` | **skill-or-agent** | `code-reviewer` | Code review pass | No |
| `executor` | skill-or-agent | `executor` (OMC agent) | Applies code changes | No |
| `researcher` | skill-name | `x-research` | Researches dependencies/context | No |
| `planner` | skill-name | `superpowers:writing-plans` | Produces structured plans | No |

### Valid Values

**`workspace` slot (v1)**:
- `current-dir` — operate in the current working directory (default)
- `worktree` — create a git worktree, operate there
- `temp` — create a temporary directory, operate there, discard after

**`verifier` slot (v1)**:
- `verification-before-completion` — superpowers default cascade (skill)
- `x-verify` — local completion-cascade dispatcher (skill)
- `x-skill-review` — when verifying a skill modification (skill, external)
- `code-reviewer` — OMC agent (dispatch via `Agent` tool)
- `custom:<skill-name>` — project-specific verifier (skill)

## MCP Toolbox (`mcp-toolbox.md`)

Plugin-local reference for selecting MCP servers.

### Quick Decision Matrix

| Need | MCP → Tool | Fallback |
|------|-----------|----------|
| Quick factual question | `perplexity` → `perplexity_ask` | `gemini-agent` → web `WebFetch` |
| X vs Y tradeoff | `perplexity` → `perplexity_reason` | OMO `oracle` |
| Exhaustive multi-source audit | `perplexity` → `perplexity_research` | OMO `librarian` ∥ `gemini-agent` |
| Raw article content | `exa` → `web_search_exa` | `WebFetch` direct |
| Dense code snippets | `exa` → `get_code_context_exa` | OMO `librarian` |
| OSS repo internals | `deepwiki` → `ask_question` | `morph-mcp github_codebase_search` → OMO `librarian` |
| Library API docs | `context7` → `resolve-library-id` then `query-docs` | `exa get_code_context_exa` → OMO `librarian` |
| Local code semantic search | `morph-mcp` → `codebase_search` | native `Grep` → OMO `explore` |
| Local code edits | `morph-mcp` → `edit_file` | native `Edit` / `Write` |
| Public GitHub repo search | `morph-mcp` → `github_codebase_search` | `deepwiki ask_question` → `gh search code` |

### Disambiguations

- **perplexity vs exa**: perplexity = pre-synthesized answer with citations. exa = raw source material.
- **perplexity_ask vs perplexity_reason vs perplexity_research**: ask handles 80%; reason for complex tradeoffs; research only for exhaustive analysis.
- **deepwiki vs context7**: deepwiki = how a specific repo's code works. context7 = how to use a library's public API.
- **gemini-agent vs perplexity**: gemini-agent has native Google Search grounding (best for current events). perplexity_ask is faster for synthesized factual lookups.

## OMO Routing (`omo-routing.md`)

Canonical routing table for OMO agents. See [OMO_BRIDGE_AND_AGENTS.md](OMO_BRIDGE_AND_AGENTS.md) for full details.

Key rule: **DO NOT DISPATCH to `hephaestus`, `atlas`, `prometheus`, `metis`, `momus`.** These 5 agents are UNAVAILABLE. Use `--model codex` or `--model gpt` instead.

## Reactions Vocabulary (`reactions-vocabulary.md`)

The canonical set of triggers a skill's `reactions:` block may fire.

### Trigger List

| Trigger | Fires when |
|---------|-----------|
| `research-needed` | Skill classified task as needing research before acting |
| `plan-needed` | Skill classified task as needing a plan before executing |
| `test-failed` | Test runner returned non-zero |
| `lint-failed` | Lint tool reported errors |
| `typecheck-failed` | Type checker reported errors |
| `verification-failed` | Verification cascade returned fail |
| `stagnation-detected` | 3 iterations no progress (proposal 01) |
| `human-approval-needed` | Skill hit a blocking decision requiring user input |
| `implementation-complete` | All code changes for one mode complete |
| `skill-done` | Terminal state reached |

### Trigger × Role Cross-Reference

| Trigger | Required for | Optional for | N/A for |
|---------|-------------|--------------|---------|
| `research-needed` | router | — | reviewer, verifier |
| `test-failed` | router | — | researcher |
| `verification-failed` | router | — | researcher |
| `review-approved` | reviewer | router | researcher, verifier |
| `stagnation-detected` | router | — | reviewer, researcher |
| `human-approval-needed` | all roles | — | — |

### Reaction Schema

```yaml
reactions:
  <trigger-name>:
    action: route | inline-fix | re-review | menu | notify | skip | abort | continue
    to: <skill-name>          # required for action: route or re-review
    retries: <int>            # default 0
    auto: <bool>              # default true; false = require user approval
    options: [opt1, opt2]     # required for action: menu
```

**Phase 1 (current)**: reactions blocks are declarative prose the model self-reads. No runtime execution contract.
**Phase 2 (deferred)**: Will add self-check discipline (evaluate triggers after every tool call, respect `auto: false`).
