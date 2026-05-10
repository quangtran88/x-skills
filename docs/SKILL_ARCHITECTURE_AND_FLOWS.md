# X-Skills Internal Architecture & Flow Documentation

> **Generated:** 2026-05-04  
> **Scope:** Complete internal flow documentation for all x-skills, their routing logic, step architectures, and inter-skill dependencies.  
> **Audience:** Skill authors, contributors, and power users who need to understand how the system works under the hood.

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Shared Infrastructure (x-shared)](#2-shared-infrastructure-x-shared)
3. [Execution Router (x-do)](#3-execution-router-x-do)
4. [Research Router (x-research)](#4-research-router-x-research)
5. [Review Orchestrator (x-review)](#5-review-orchestrator-x-review)
6. [Bugfix Workflow (x-bugfix)](#6-bugfix-workflow-x-bugfix)
7. [Completion Verifier (x-verify)](#7-completion-verifier-x-verify)
8. [OpenCode Bridge (x-omo)](#8-opencode-bridge-x-omo)
9. [Design System Router (x-design)](#9-design-system-router-x-design)
10. [API Pentest (x-api-pentest)](#10-api-pentest-x-api-pentest)
11. [Gemini Bridge (x-gemini)](#11-gemini-bridge-x-gemini)
12. [Skill Improvement (x-skill-improve)](#12-skill-improvement-x-skill-improve)
13. [Cross-Skill Chains](#13-cross-skill-chains)
14. [Appendix: Skill File Structure](#14-appendix-skill-file-structure)

---

## 1. System Overview

X-Skills is a **plugin-based skill routing system** for Claude Code. It consists of 10 specialized skills (x-do, x-research, x-review, x-bugfix, x-design, x-api-pentest, x-omo, x-gemini, x-skill-improve, x-verify) plus a shared reference library (x-shared) that classify user intent and dispatch to the optimal executor — either native Claude tools, OpenCode multi-model agents (OMO), oh-my-claudecode agents (OMC), or external CLI tools.

### Core Philosophy

- **Router, not executor:** Each skill classifies and routes; it does not (usually) perform the work itself.
- **Stateless:** Skills do not keep state between sessions. No session pools, no activity DBs.
- **Capability-aware:** Skills detect available tools at bootstrap and degrade gracefully when dependencies are missing.
- **Role-separated:** Router, reviewer, and verifier roles have explicit forbid blocks to prevent role leakage.

### Plugin Structure

```
x-skills/
├── .claude-plugin/
│   ├── plugin.json           # Plugin manifest
│   └── marketplace.json      # Marketplace registration
├── bin/
│   ├── omo-agent             # OpenCode multi-model wrapper
│   ├── setup                 # Setup script (binding + detection)
│   └── find-plugin-dir       # Plugin path resolver
├── commands/
│   └── setup.md              # /x-skills:setup command
├── lib/
│   └── feature-gate.md       # Fallback routing reference
├── skills/
│   ├── x-do/                 # Execution router
│   ├── x-research/           # Research router
│   ├── x-review/             # Review orchestrator
│   ├── x-verify/             # Completion cascade verifier
│   ├── x-bugfix/             # Debugging workflow
│   ├── x-mindful/            # Pre-implementation impact gate
│   ├── x-design/             # Design system integration
│   ├── x-api-pentest/        # API security testing
│   ├── x-qa/                 # Profile-driven E2E QA
│   ├── x-team/               # Multi-feature team orchestrator
│   ├── x-worktree/           # Isolated git worktree provisioner
│   ├── x-worktree-isolate/   # Per-worktree docker-compose isolation
│   ├── x-omo/                # OpenCode bridge
│   ├── x-gemini/             # Gemini CLI bridge
│   ├── x-guide/              # Progressive comprehension-gated tutor
│   ├── x-skill-improve/      # Session-based alignment analyzer
│   └── x-shared/             # Shared references (NOT a skill)
├── docs/                     # Architecture documentation
└── README.md
```

### Invocation Patterns

All skills follow a standard frontmatter contract:

```yaml
---
name: x-do
description: "Use when the user asks to build, implement, fix, or execute a plan..."
role: router                    # (04) router | reviewer | verifier
slots:                          # (05) pluggable dependencies
  workspace: current-dir
  verifier: x-verify
reactions:                      # (02) declarative event handlers
  research-needed:
    action: route
    to: x-research
    auto: true
---
```

---

## 2. Shared Infrastructure (x-shared)

`x-shared/` is a **reference library**, not an invokable skill. It contains cross-cutting concerns consumed by all other skills via relative paths (`../x-shared/<file>.md`).

### Key Files

| File | Purpose | Consumers |
|------|---------|-----------|
| `capability-loading.md` | Bootstrap-pinned capability contract. "Detect once at setup. Pin at bootstrap. Never re-check per dispatch." | All skills |
| `invocation-guide.md` | Tool invocation patterns + 9-layer prompt precedence ladder + orchestration primitives (`handoff`/`assign`) | All skills |
| `workflow-chains.md` | Common cross-skill chain sequences | All skills |
| `context-envelope.md` | Handoff context block format for chaining | All skills |
| `completion-cascade.md` | x-verify cascade specification (5 steps: SCOPE GATE → ABORT → EXPLICIT FAILURE → VERIFICATION → MANDATORY FALLBACK → HUMAN-APPROVAL) | x-do, x-verify |
| `mcp-toolbox.md` | Plugin-local MCP decision matrix (perplexity / exa / deepwiki / context7 / morph) | x-research, x-bugfix |
| `severity-guide.md` | Finding severity scale (CRITICAL/HIGH/MEDIUM/LOW) | x-review, x-bugfix, x-api-pentest |
| `omo-routing.md` | Signal → OMO agent routing table | x-do, x-research |
| `slot-schema.md` | Slot-fill schema for skills (v1: `workspace`, `verifier`) | All skills |
| `reactions-vocabulary.md` | Cross-skill reaction signals | All skills |
| `common-gotchas.md` | Cross-skill operational pitfalls | All skills |

### Prompt Assembly — Precedence Ladder (9 Layers)

When instructions conflict, higher layers win:

1. **Priority 0 — Inviolable principles** (memory files marked `principle: true`)
2. **User's explicit in-prompt instructions**
3. **Project `CLAUDE.md`** (working directory)
4. **Repo `CLAUDE.md`** (x-skills repo policy)
5. **Memory feedback files** (advisory; non-principle)
6. **`~/.claude/CLAUDE.md`** (user's global)
7. **Skill frontmatter** (`role:`, `slots:`, `reactions:`)
8. **Skill body** (markdown below frontmatter)
9. **Claude Code harness + superpowers defaults**

### Orchestration Primitives

Every subagent dispatch picks ONE primitive explicitly:

| Primitive | Semantics | When to Use |
|-----------|-----------|-------------|
| **`handoff`** | Sync delegation — dispatch, wait for result, continue | Task B depends on Task A's output. Must include context envelope. |
| **`assign`** | Async fan-out — dispatch N subagents in ONE message, wait for all, synthesize | 2+ independent tasks. All calls must be in a single message. |

---

## 3. Execution Router (x-do)

**Role:** `router`  
**Purpose:** Universal work command — classifies tasks into modes and dispatches through optimal workflows.

### Detection (6 Modes)

| Mode | Detect When | Route |
|------|-------------|-------|
| **A: Existing Plan** | User references a plan/spec/doc file | Execute plan directly |
| **B: New Feature** | Something to build/add/create, no existing plan | Brainstorm → Plan → Execute |
| **C: Bug Fix** | Error, stack trace, failure description | Delegate to `/x-bugfix` |
| **D: Quick Task** | Trivial change, < 5 min, no ambiguity | Direct execution |
| **E: Visual Input** | PDF, image, screenshot, diagram | Analyze visual → route to A/B/C |
| **F: Refactor** | Structural code change, not bug or new feature | Delegate to `/refactor` |

### Research Gate (Before Detection)

Before classifying mode, check: **does this task need research first?**

| Signal | Action |
|--------|--------|
| Unfamiliar library/API/framework | → `/x-research` (Type B or D) first, then return here |
| Vague requirements spanning 3+ modules | → `/x-research` (Type F) first, then return here |
| "How does X work in our codebase?" before fixing/building | → `/x-research` (Type A) first, then return here |
| Clear requirements, known codebase area | → Skip, proceed to Detection |

**Return path:** If x-research just completed in the same session and provided findings/context, skip this gate entirely — research is already done. Proceed directly to Detection.

### Pre-Flight Checklist (MANDATORY)

Before starting any mode, complete ALL of these checks:

1. **Resume detection:** Check for in-progress state (paths in `config.json`):
   - `ralph_state` — incomplete stories → offer to resume
   - `specs_dir` — uncommitted design docs → offer to continue
   - Draft plan files (`spec-wip.md`) → offer to continue
2. **Gotchas:** Read `gotchas.md` for known failure patterns before starting
3. **Depth check:** Assess complexity to calibrate ceremony (see below)

---
### Workflow (4 Steps)

```
Step 1: Gather (step-01-gather.md)
  ├─ Fire oracle (OMO pre-planning) + OMC Explore (codebase context) IN PARALLEL
  ├─ Collect both results
  ├─ Synthesize findings
  └─ Present to user for validation

Step 2: Plan (step-02-plan.md)
  ├─ Route A: superpowers:writing-plans (TDD-oriented)
  ├─ Route B: --model gpt (complex dependency graph)
  └─ Route C: Inline plan (2-3 tasks)

Step 3: Review (step-03-review.md)
  └─ Cross-model review (Claude + GPT perspectives)

Step 4: Execute (step-04-execute.md)
  └─ Dispatch to executor subagent (OMC executor, ralph, or --model codex)
```

### Depth Calibration

Before entering mode guidance, assess task along 4 dimensions (Scope, Risk, Novelty, Dependencies) to decide ceremony level:

- **Light** → Skip brainstorming, skip plan review, 1 reviewer post-impl
- **Standard** → Brief brainstorm, plan if 3+ tasks, full 3-reviewer post-impl
- **Heavy** → Full pipeline: brainstorm → plan → plan review → execute → post-impl review

### Reactions Block

```yaml
reactions:
  research-needed:      { action: route, to: x-research, auto: true }
  plan-needed:          { action: route, to: superpowers:writing-plans, auto: true }
  test-failed:          { action: route, to: x-bugfix, retries: 2, auto: true }
  lint-failed:          { action: route, to: x-bugfix, auto: true }
  typecheck-failed:     { action: route, to: x-bugfix, auto: true }
  verification-failed:  { action: re-review, to: x-verify, auto: true }
  implementation-complete: { action: menu, options: [commit, x-review, plan-next, done], auto: false }
  stagnation-detected:  { action: menu, options: [alternative-A, alternative-B, alternative-C, abort], auto: false }
  human-approval-needed: { action: notify, auto: false }
```

### Completion (Mandatory)

Before claiming done, resolve the `verifier` slot (3-layer cascade):
1. User in-prompt override
2. Skill frontmatter `slots: verifier: x-verify`
3. Schema default (`verification-before-completion`)

Then dispatch `Skill tool: x-verify` and honor its verdict (`done`, `failed`, `needs-user-review`, `aborted`, `waiting-for-user`).

### Role Forbid Block

```
x-do MUST NOT (Modes A, B, E, F):
- Call Edit/Write directly → dispatch to executor subagent
- Call Bash to run mutating commands → dispatch to verifier/executor

Exceptions:
- Mode D (Quick Task): < 10 lines, no ambiguity → direct Edit/Write allowed
- Post-execution correction: ≤ 3 files, clear instructions → direct correction allowed
```

### Dependencies

- **Shared:** `invocation-guide.md`, `severity-guide.md`, `workflow-chains.md`, `context-envelope.md`
- **External skills:** `x-omo`, `x-bugfix`, `refactor`, `superpowers:brainstorming`, `superpowers:writing-plans`, `superpowers:test-driven-development`, `superpowers:verification-before-completion`, `superpowers:finishing-a-development-branch`, `superpowers:requesting-code-review`, `oh-my-claudecode:ralph`

---

## 4. Research Router (x-research)

**Purpose:** Universal research orchestrator — classifies questions by information-source signal and dispatches to optimal tools/agents.

### Modes

| Mode | Trigger | Behavior |
|------|---------|----------|
| **Standard** | default | Pick single best tool per signal; escalate only if insufficient |
| **Max** | `max` / `prism` / `--max` / `ultraresearch` | Fan out across all relevant lanes in parallel; synthesize with reconciliation |

### Signal → Primary Tool Matrix

| Signal | Primary | Escalation |
|--------|---------|------------|
| Local code: "how does our X work" | `morph-mcp` → `codebase_search` | OMO `explore` |
| Local cross-repo (3+ modules) | `morph` + OMO `explore` parallel | — |
| Public repo internals | `deepwiki` → `ask_question` | `morph` → `github_codebase_search` → OMO `librarian` |
| Library API usage | `context7` → `query-docs` | `exa` → `get_code_context_exa` |
| Quick factual lookup | `perplexity_ask` | `gemini-agent` |
| Fresh news / current events | `gemini-agent` | `perplexity_ask` w/ recency filter |
| X vs Y tradeoff | `perplexity_reason` | OMO `oracle` |
| Architecture decision | OMO `oracle` | + `perplexity_reason` |
| Pre-planning | OMO `oracle` ∥ `morph` ∥ `perplexity_ask` | — |
| Visual single file | Claude `Read` OR `gemini-agent --file` | OMO `multimodal-looker` |
| Visual cross-file | OMO `multimodal-looker` | — |
| Exhaustive audit | `perplexity_research` | + OMO `oracle` |
| Dense code examples | `exa` → `get_code_context_exa` | OMO `librarian` |

### Cost Guard (Max Mode)

Before dispatch, announce: `Max Mode: <N> lanes — <lane list with rough cost/latency>. Proceed? [Y/n/standard]`

### Synthesis Rules

- Lead with the answer — conclusion first, details after
- Cite evidence — reference specific facts, URLs, file paths
- Flag uncertainty — note hedging or contradictions
- If agent modified files, verify (tests, diagnostics)
- Contradictions between agents = flag for user decision

### Dependencies

- `../x-omo/SKILL.md` — OMO agent runtime
- `../x-gemini/SKILL.md` — gemini-agent runtime
- `../x-shared/mcp-toolbox.md` — MCP decision matrix
- Downstream chains: `/x-do`, `superpowers:writing-plans`

---

## 5. Review Orchestrator (x-review)

**Role:** `reviewer`  
**Purpose:** Code/plan/PR review orchestrator — cross-model review with Claude + GPT perspectives, structured verdicts.

### Role Forbid Block

```
x-review MUST NOT:
- Call Edit or Write during review phase (steps 1-3)
- Propose "while I'm here, let me just fix this" inline fixes
- Run mutating Bash during review phase

Exception — Fix Mode: When user explicitly requests fixes after REQUEST_CHANGES,
enter Fix Mode (step 4). Edit/Write/mutating Bash permitted via receiving-code-review workflow.
```

### Workflow (4 Steps)

```
Step 1: Prepare (step-01-prepare.md)
  ├─ Detect target type:
  │   A: Plan/Spec (.md in specs/plans/docs)
  │   B: Code/Files (file paths)
  │   C: Git Diff ("last commit", "staged", "this PR")
  │   D: No Target (auto-detect from git state)
  └─ Construct content/diff for review

Step 2: Review (step-02-review.md)
  ├─ **Target A (Plan/Spec):** Launch 3 reviewers in ONE MESSAGE:
  │   1. Agent tool: subagent_type="oh-my-claudecode:code-reviewer", model="opus" — Claude perspective
  │   2. Bash tool: omo-agent --model gpt "<plan blocker-finder prompt>" — GPT-5.4 blocker-finder (OKAY/REJECT). Replaces UNAVAILABLE `momus`.
  │   3. Skill tool: superpowers:requesting-code-review — structured review workflow
  │   (Optional 4th: omo-agent oracle for architecture-sensitive plans)
  ├─ **Targets B/C/D (Code/Files/Diff):** Launch 3 reviewers in ONE MESSAGE:
  │   1. Agent tool: subagent_type="oh-my-claudecode:code-reviewer", model="opus" — Claude perspective
  │   2. Bash tool: omo-agent oracle "<review prompt with diff/file content>" — GPT perspective
  │   3. Skill tool: superpowers:requesting-code-review — structured review workflow
  ├─ Wait for ALL background notifications
  └─ Collect all results before proceeding
  ├─ Launch 3 reviewers in ONE MESSAGE (all tool calls in single response):
  │   1. Agent tool: subagent_type="oh-my-claudecode:code-reviewer", model="opus" — Claude perspective
  │   2. Bash tool: omo-agent oracle "<review prompt>" — GPT perspective
  │   3. Skill tool: superpowers:requesting-code-review — structured review workflow
  ├─ Wait for ALL background notifications
  └─ Collect all results before proceeding

Step 3: Synthesize (step-03-synthesize.md)
  ├─ Verify findings
  ├─ Synthesize cross-model perspectives
  └─ Present structured verdict

Step 4: Act (step-04-act.md)
  ├─ Additional passes menu
  ├─ Verdict routing
  └─ Fix Mode (if user requests fixes)
```

### Cross-Model Review Pattern

The **one-message launch** is critical for compliance. All 3 reviewers must be dispatched in a single assistant response.

**Target A (Plan/Spec):**
```
Tool: Agent(subagent_type="oh-my-claudecode:code-reviewer", model="opus", run_in_background=true)
Tool: Bash(command="omo-agent --model gpt '<plan blocker-finder prompt>'", run_in_background=true, timeout=600000)
Tool: Skill(skill="superpowers:requesting-code-review")
```

**Targets B/C/D (Code/Files/Diff):**
```
Tool: Agent(subagent_type="oh-my-claudecode:code-reviewer", model="opus", run_in_background=true)
Tool: Bash(command="omo-agent oracle '<review prompt>'", run_in_background=true, timeout=600000)
Tool: Skill(skill="superpowers:requesting-code-review")
```

The **one-message launch** is critical for compliance. All 3 reviewers must be dispatched in a single assistant response:

```
Tool: Agent(subagent_type="oh-my-claudecode:code-reviewer", model="opus", run_in_background=true)
Tool: Bash(command="omo-agent oracle '...'", run_in_background=true, timeout=600000)
Tool: Skill(skill="superpowers:requesting-code-review")
```

### Dependencies

- **x-omo** — bootstrap + oracle agent for GPT perspective
- **x-shared** — severity-guide, invocation-guide, context-envelope, workflow-chains
- **superpowers** — code-reviewer, requesting-code-review, receiving-code-review, verification-before-completion, finishing-a-development-branch

---

## 6. Bugfix Workflow (x-bugfix)

**Purpose:** Structured debugging — routes through investigation, hypothesis testing, and verified fix with evidence collection.

### Iron Law

> **NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST.** If you can't state the root cause in one sentence, you haven't investigated enough.

### Detection (4 Modes)

| Mode | Detect When | Route |
|------|-------------|-------|
| **Q: Quick Fix** | Trivial: lint error, type error, syntax fix, single obvious typo | Read error → locate → fix → verify |
| **A: Quick Bug** | Clear error, single component, obvious root cause | Streamlined investigate → fix |
| **B: Deep Investigation** | Ambiguous, causal, multi-component, intermittent | Read `references/mode-b-deep.md` |
| **C: System/Infra** | CI/CD, deployment, performance, server/DB issues | Read `references/mode-c-system.md` |

### Pre-Flight Checklist

1. Capture baseline: Record exact error messages, failing test output, stack traces (copy-paste, not paraphrase)
2. Read error messages carefully — don't skip stack traces
3. Read `gotchas.md` for known failure patterns
4. `git log --oneline -10 -- <affected-files>` — regression = root cause is in the diff

### Mode A: Quick Bug Workflow

```
Investigate
  ├─ Use morph-mcp codebase_search as FIRST search tool
  ├─ Fall back to OMO explore only for parallel multi-tool investigation
  ├─ Consult references/backward-tracing.md for deep call stacks
  ├─ Consult references/pattern-catalog.md to narrow search space
  └─ Output: root cause hypothesis (specific and testable)

Hypothesize & Test
  ├─ Scientific method — one variable at a time
  ├─ Instrumentation Pivot (after 2 failed iterations): STOP speculating, add logs, monitor live system
  └─ 3-Strike Rule: 3 iterations without progress → delegate to OMO oracle

Fix & Verify
  ├─ Write regression test that FAILS without the fix
  ├─ Implement single fix addressing root cause (minimal diff)
  ├─ Run test suite — no regressions
  ├─ Fresh verification — reproduce original scenario, confirm fixed
  └─ Prevention gate — read references/prevention-gate.md, apply defense-in-depth
```

### Post-Fix Verification

- TS/JS projects: `npx tsc --noEmit` + `npx eslint <changed-files>` + full test suite
- Debug report: Output per `references/debug-report-template.md`
- Append root cause summary to `debug-log.jsonl` for cross-session pattern tracking

### Completion Status

| Status | When |
|--------|------|
| **DONE** | Root cause found, fix applied, tests pass, prevention in place |
| **DONE_WITH_CONCERNS** | Fixed but cannot fully verify (intermittent, needs staging) |
| **BLOCKED** | Root cause unclear after investigation, or fix exceeds safe scope |
| **NEEDS_CONTEXT** | Missing information to proceed |

### Dependencies

- `../x-omo/SKILL.md` — OMO agent catalog
- `../x-shared/invocation-guide.md`, `workflow-chains.md`, `context-envelope.md`
- `../x-do/references/iteration-patterns.md` — 3-Strike Rule + Instrumentation Pivot
- `references/{mode-b-deep,mode-c-system,backward-tracing,pattern-catalog,prevention-gate,debug-report-template,evidence-hierarchy}.md`

---

## 7. Completion Verifier (x-verify)

**Role:** `verifier`  
**Purpose:** Single entry point for answering "am I done?" reliably. Every long-running x-skill dispatches here instead of running ad-hoc checks.

### Completion Cascade (5 Steps)

```
SCOPE GATE (short-circuit check)
  ├─ Only-reads invocation? → return done immediately
  ├─ Docs-only changes? → return done
  ├─ Non-code tree? → return done
  └─ Code project with real config? → proceed to Step 1

Step 1: ABORT check
  ├─ User said abort/cancel/stop? → return aborted
  ├─ Stagnation menu fired AND user picked D? → return aborted
  └─ Otherwise → proceed

Step 2: EXPLICIT FAILURE check
  ├─ Last tool call returned fatal error? → return failed
  └─ Otherwise → proceed

Step 3: VERIFICATION check (primary)
  ├─ Discover test/lint/typecheck commands from project config
  ├─ Run resolved commands in order
  ├─ Any non-zero? → return failed
  ├─ All clean? → return done
  └─ All "no-config"? → proceed to Step 4

Step 4: MANDATORY FALLBACK — dispatch verifier
  ├─ Primary: Agent tool with subagent_type="oh-my-claudecode:code-reviewer"
  ├─ Fallback (OMC unavailable): Agent tool with generic review prompt
  └─ Verdict: pass → done, fail → failed, uncertain → needs-user-review

Step 5: HUMAN-APPROVAL check
  └─ Surface ambiguous status menu to user, wait for input
```

### Verdicts

| Verdict | Meaning | Next Action |
|---------|---------|-------------|
| `done` | All checks passed | Proceed to handoff menu |
| `failed` | Test/lint/typecheck failed or verifier rejected | Fire `verification-failed` reaction |
| `aborted` | User chose abort or stagnation option D | Exit workflow immediately |
| `waiting-for-user` | Stagnation menu open, needs user choice | Pause, do NOT loop |
| `needs-user-review` | All verification inconclusive | Surface menu: [A] mark done, [B] re-verify, [C] abort |

### Rollout State

| Skill | Apply Cascade? | Status |
|-------|---------------|--------|
| `x-do` | **Yes** | **Live** |
| `x-bugfix` | No (yet) | Deferred — inline verification is current contract |
| `x-research` | No | Research has "synthesis done", not "completion" |
| `x-review` | No | Reviews return verdicts, not "done" |
| `x-design` | No (yet) | Deferred |
| `x-api-pentest` | No (yet) | Deferred |

---

## 8. OpenCode Bridge (x-omo)

**Purpose:** Bridges Claude Code to non-Claude models via OpenCode CLI. Routes by agent role, not by model.

### Agent Catalog

| Agent | Role | Model | Cost | Best For |
|-------|------|-------|------|----------|
| `oracle` | Read-only strategic advisor | GPT-5.4 max | EXPENSIVE | Architecture/debugging advice |
| `explore` | Contextual codebase search | Configured in `oh-my-openagent.json` | FREE | Find code in codebase |
| `librarian` | External docs & OSS research | Configured in `oh-my-openagent.json` | CHEAP | Look up library docs |
| `multimodal-looker` | Visual & document analysis | Gemini 3.1 Pro | CHEAP | Analyze images/PDFs/diagrams |

### Model Routing

```bash
omo-agent --model <alias> "<prompt>"
```

| Alias | Resolves To | Best For |
|-------|-------------|----------|
| `gemini-pro` | Gemini 3.1 Pro | Visual/UI work, multimodal, creative |
| `gemini-flash` | Gemini 3 Flash | Fast search, lightweight tasks |
| `codex` | GPT-5.3 Codex | Deep implementation, autonomous coding |
| `gpt` | GPT-5.4 | Architecture, reasoning, review |

### Invocation Rules

- All agents invoked via **Bash** with `omo-agent` wrapper
- **Never use `spawn_agent`** — it only uses Claude
- Timeout: Always set Bash timeout to **600000** (10 min)
- **Parallel agents (max 3 concurrent):** Fire multiple Bash calls with `run_in_background: true`
- Collect ALL results before synthesizing

### Standard Parallel Patterns

| Pattern | Agents | When |
|---------|--------|------|
| Research | `explore` + `librarian` | Need both codebase + external docs |
| Visual + context | `multimodal-looker` + `explore` | Image/PDF input + related code |
| Code review | OMC code-reviewer + `--model gpt` | Claude + GPT-5.4 cross-model review |

### Gotchas

- `hephaestus`, `atlas`, `prometheus`, `metis`, `momus` are **UNAVAILABLE** due to plugin compat bug
- Use `--model codex` (replaces `hephaestus`) or `--model gpt` (replaces `prometheus`/`momus`) instead
- `omo-agent` requires `--pure` flag for model mode when default agent not found

---

## 9. Design System Router (x-design)

**Purpose:** Resolves user design intent to a curated `DESIGN.md` file from `VoltAgent/awesome-design-md` and installs it into the current project.

### Workflow (8 Steps)

```
1. Resolve target directory
   └─ Confirm cwd is project root (has .git, package.json, etc.)

2. Resolve slug from intent
   ├─ Named brand: direct slug lookup in catalog
   ├─ Descriptive intent: match against intent tags → propose 2-3 candidates
   └─ Listing: print category section from catalog

3. Preview before install
   └─ Show slug + site name + category + preview URL + one-liner. Ask for confirmation.

4. Fetch the DESIGN.md
   └─ curl -fsSL "https://raw.githubusercontent.com/VoltAgent/awesome-design-md/<commit>/design-md/<slug>/DESIGN.md"

5. Report
   ├─ File location + byte count
   ├─ Brand name + one-liner
   ├─ Philosophy-first framing: read sections 1, 5, 7 first
   ├─ First paragraph of section 9 "Agent Prompt Guide"
   ├─ Stack-aware hint (Tailwind, Vue, Svelte, Flutter, vanilla)
   └─ AI slop warning (top 3-4 pitfalls)

6. Offer ui-ux-pro-max handoff
   └─ Generate design-system/MASTER.md with enforceable rules

7. Offer shadcn MCP handoff
   └─ Find and install matching components (conditional on shadcn detection)

8. Optionally hint the project CLAUDE.md
   └─ Append one-line reference to DESIGN.md/MASTER.md (ask first, default false)
```

### Three-Stage Pipeline

1. `x-design` fetches `DESIGN.md` — brand vision (the *what*)
2. `ui-ux-pro-max` generates `design-system/MASTER.md` — enforceable rules (the *constraints*)
3. `shadcn` MCP finds and installs matching components — execution (the *how*)

Each stage is opt-in. Stages 2 and 3 are skipped only if the user explicitly declines. When `ui-ux-pro-max` is not installed, the install pointer is surfaced once (do NOT silently no-op). When `shadcn` registries are absent, a non-shadcn framework advisory is offered instead.

### Dependencies

- `curl` — fetches raw files from GitHub
- `config.json` — pinned commit + URL templates
- `references/catalog.md` — 58-site index
- Optional: `ui-ux-pro-max` skill (external), `shadcn` MCP

---

## 10. API Pentest (x-api-pentest)

**Purpose:** Black-box dynamic security testing of a live HTTP API using its OpenAPI/Swagger spec as the attack surface map.

### Scope

**DOES:** dynamic black-box testing, OWASP API Top 10 (2023), BOLA/BFLA/mass assignment/SSRF/injection/rate-limit/business logic, markdown + SARIF output.

**DOES NOT:** static code review, secret/dependency scanning, network/infra pentest, social engineering, unauthorized testing.

### Workflow (6 Steps)

```
Step 1: Recon (step-01-recon.md)
  ├─ Spec lint, attack surface, role mapping
  └─ Consent gate (NON-NEGOTIABLE — no active scans without explicit target confirmation)

Step 2: Auth Baseline (step-02-auth-baseline.md)
  └─ Validate 2 user tokens + admin token

Step 3: Automated Sweep (step-03-automated-sweep.md)
  └─ Parallel Schemathesis + RESTler (opt-in) + Nuclei

Step 4: Targeted Tests (step-04-targeted-tests.md)
  └─ BOLA/BFLA, mass assignment, SSRF, velocity, business logic, LLM injection

Step 5: Synthesize (step-05-synthesize.md)
  └─ Dedupe, severity, chain-impact reasoning

Step 6: Report (step-06-report.md)
  └─ Markdown + SARIF, handoff
```

### Safe Execution Environment

- Target must match `safety.allowed_target_patterns` (localhost, RFC1918, `*.staging.*`, `*.test.*`, `*.local`)
- Prefer egress-isolated container (Docker Compose with `internal: true`, `cap_drop: ALL`)
- Credentials only via environment variables — never read tokens from committed files

### config.json Safety Details

```json
{
  "safety": {
    "require_target_confirmation": true,
    "allowed_target_patterns": ["localhost", "127.0.0.1", "10.*", "172.16.*", ..., "*.staging.*", "*.test.*", "*.local"],
    "denied_target_patterns": ["*.gov", "*.mil"],
    "require_allow_unsafe_target_flag": true,
    "max_requests_per_second": 50,
    "max_total_requests": 5000
  }
}
```

**Key rules:**
- `require_target_confirmation`: Must be explicitly confirmed before active scans
- `allowed_target_patterns`: Default covers localhost, RFC1918, `*.staging.*`, `*.test.*`, `*.local`
- `denied_target_patterns`: `*.gov` and `*.mil` are permanently denied (no override)
- Override outside allowlist requires `allow_unsafe_target=true` + explicit env var confirmation (`CONFIRMED_TARGET_URL`)
- Rate caps: 50 req/s, 5000 total requests max

### Target Allowlist Check Algorithm

Step 01 enforces the allowlist via a **Python script** (not bash glob — a prior bash-glob implementation failed open on `10.evil.com`):

- Parse URL with Python `urllib.parse`
- Denylist check first (`*.gov`, `*.mil`) — fnmatch, no override
- IP path: use `ipaddress` module for CIDR membership (127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16)
- Hostname path: fnmatch against `localhost`, `*.staging.*`, `*.test.*`, `*.local`
- Override: if `allow_unsafe_target=true` set, HALT and require `CONFIRMED_TARGET_URL='$url'` env var to proceed

### Oracles and Integrations

```json
{
  "oracles": {
    "bola": true,
    "bfla": true,
    "mass_assignment": true,
    "ssrf": true,
    "velocity": true,
    "business_logic": true,
    "llm_endpoints": "auto"
  },
  "integrations": {
    "prefer_hexstrike": false,
    "blind_verification": true,
    "blind_verification_min_severity": "High"
  }
}
```

- `prefer_hexstrike`: STUB ONLY — not implemented. When false (default), all tools invoked via direct CLI.
- `blind_verification`: Every Critical/High finding is re-verified with a fresh curl request
- `blind_verification_min_severity`: Only findings at High or above trigger blind re-verification

### Noise Filters (from gotchas.md)

These patterns must **NOT** be emitted as findings:

- Missing security headers alone (without exploit impact) → Info only, never Medium+
- Generic rate-limiting complaints without demonstrated brute-force/enumeration payoff
- Self-XSS requiring victim to paste into own console
- Verbose error messages disclosing non-sensitive internals → Info only
- Test/demo/fixture endpoints under `/test`, `/demo`, `/sample`, `/_internal/debug`
- CORS misconfigurations without demonstrated credential-bearing exploit
- Local-only code paths where scanner cannot prove network reachability
- CI/CD injection vectors — out of scope
- TLS 1.1 warnings — infrastructure scope, not API scope

**Rule of thumb:** "Can I write a one-line curl that demonstrates impact?" If no, it's noise.

### sqlmap Risk Guardrails

- Default: `--level 2 --risk 1` (configured in `config.json`)
- **Never** raise to `--level 5 --risk 3` against unknown targets — destructive
- Must obtain explicit approval before raising sqlmap risk above default
### Severity Scale (Extended)

Extends canonical x-skills severity with an additional **Info** tier:
- Title-case inside skill outputs: `Critical / High / Medium / Low / Info`
- Crossover to generic pipeline: Title-case → UPPER-case, Info → LOW

### Dependencies

- External tools: schemathesis, nuclei, sqlmap, spectral, interactsh-client
- `superpowers:verification-before-completion` — every Critical/High finding needs curl repro

---

## 11. Gemini Bridge (x-gemini)

**Purpose:** Direct Google Gemini CLI bridge — bypasses OpenCode entirely, uses Google Ultra subscription (no API key), native Google Search grounding.

### When to Use

| Use Case | Why x-gemini, not x-omo / x-research |
|----------|-------------------------------------|
| Need fresh web facts with citations | Gemini has native Google Search |
| Quick factual lookup, want low latency | Skips opencode routing layer |
| Want `gemini-3.1-pro-preview` specifically | Default opencode config may not expose it |
| Multi-turn research session | `--resume` keeps conversation context |
| Analyze a workspace file | `@file` reference works for any file under CWD |

### Models

| Alias | Resolves To | Best For |
|-------|-------------|----------|
| `flash` (default) | `gemini-2.5-flash` | Fast lookups, classification, summaries |
| `pro` | `gemini-3.1-pro-preview` | Reasoning, deep analysis, multimodal |

### Invocation Patterns

```bash
gemini-agent "Research topic X"
gemini-agent --model pro "Complex reasoning task"
gemini-agent --file ./README.md "Summarize this project"
gemini-agent --resume "Follow-up: how does it differ from approach Y?"
```

### Dependencies

- `gemini` CLI (required) — https://github.com/google-gemini/gemini-cli
- `timeout` (required) — `brew install coreutils`
- `jq` (required for JSON mode) — `brew install jq`
- Google Ultra subscription (recommended)

---

## 12. Skill Improvement (x-skill-improve)

**Purpose:** Evaluates how well an x-skill was followed during a real session, then improves the skill based on findings.

### Workflow (5 Steps)

```
Step 1: Locate Session
  ├─ Use session_search MCP tool to find sessions where target skill was invoked
  ├─ Parse arguments per references/argument-parsing.md
  └─ Search and extract per references/session-discovery.md

Step 2: Load Skill Files
  ├─ Read full skill directory (SKILL.md, steps/, references/, gotchas.md, config.json)
  └─ Build instruction inventory — list of every rule, gate, checklist, workflow step

Step 3: Analyze Alignment
  ├─ Walk instruction inventory
  ├─ Classify each item: Followed / Deviated / Skipped / Worked Around / N/A
  └─ Focus on high-signal misalignments (mandatory gates skipped, repeated patterns)

Step 4: Dual-Perspective Findings
  ├─ For each misalignment:
  │   - What the skill says (quote instruction)
  │   - What the session did (describe actual behavior)
  │   - Verdict: UPDATE SKILL or COMPLIANCE GAP
  │   - Recommendation: specific proposed change

Step 5: Present Report
  └─ Use template from references/output-template.md
```

### Verdict Types

| Verdict | Meaning |
|---------|---------|
| **UPDATE SKILL** | The skill is wrong, incomplete, or too rigid. The execution was reasonable. |
| **COMPLIANCE GAP** | The skill is right. The execution should have followed it. |

### Applying Fixes

- For `x-*` skills: edit the **source repo** (never plugin cache)
- Default edit tool: `morph-mcp edit_file`
- UPDATE SKILL: Make targeted edits (add exceptions, add gotchas, add missing guidance)
- COMPLIANCE GAP: No skill change; optionally add to gotchas.md as reminder

### Source-Repo Resolution Precedence

When loading skill files for analysis, resolve location using this precedence:

1. **Skill name starts with `x-`** → check **plugin source repo** first:
   - `${X_SKILLS_PLUGIN_ROOT:-}/skills/<name>/` if env var set
   - Directory of an x-skills git checkout (detect via `git -C "$dir" config --get remote.origin.url | grep -q x-skills` for candidates from `~/Codes`, `~/code`, `~/src`, `$HOME`)
   - `~/.claude/plugins/cache/x-skills-marketplace/x-skills/*/skills/<name>/` (read-only — never edit here)
2. **Fallback for non-x skills** → `~/.claude/skills/<name>/`
3. **Plugin cache** → read-only reference, never edit

**Skill directory read order:**
```
<resolved-path>/<skill-name>/
├── SKILL.md          # Always read
├── steps/            # Read all if present
├── references/       # Read all if present
├── gotchas.md        # Read if present
└── config.json       # Read if present
```

Build an **instruction inventory** — a list of every rule, gate, checklist item, and workflow step in the skill.
### Persistence

Append summary line to `data/alignment-log.jsonl`:
```json
{"skill":"x-bugfix","sessionId":"f7035623","date":"2026-04-01","findings":8,"updateSkill":3,"complianceGap":5,"applied":true}
```

### Dependencies

- `session_search` MCP tool from oh-my-claudecode plugin (falls back to JSONL-direct read)
- `../x-shared/invocation-guide.md`, `severity-guide.md`, `workflow-chains.md`

---

## 13. Cross-Skill Chains

Common sequences across x-skills (from `x-shared/workflow-chains.md`):

| Workflow | Sequence |
|----------|----------|
| **Bug Fix** | `/x-bugfix` (Mode A/B/C) → `/x-review` → merge |
| **Deep Bug Investigation** | `/x-research` (Type A) → `/x-bugfix` (Mode B) → `/x-review` → merge |
| **New Feature** | `/x-research` (Type F) → `/x-do` (Mode B) → `/x-review` → merge |
| **Skill Audit** | `/x-skill-review` → `/x-do` (Mode A) → `/x-skill-review` (re-audit) |
| **Skill Improve** | Use x-skill → paste session → `/x-skill-improve` → apply fixes → `/x-skill-review` |
| **Quick Fix** | `/x-do` (Mode D) → `/x-review` (Target C: last commit) |
| **Architecture Decision** | `/x-research` (Type C) → `/x-do` (Mode B) |

### Handoff Context Format

When chaining skills, include a context envelope block:

```markdown
## Handoff Context
- **From:** [skill name] | **Type/Mode:** [classification used]
- **Key finding:** [one-liner summary of what was learned/decided]
- **Agents used:** [list of agents that contributed]
- **Recommendation:** [next skill + mode/type to use]
- **Artifacts:** [file paths of any documents produced]
```

---

## 14. Appendix: Skill File Structure

### Standard Skill Directory Layout

```
skills/<name>/
├── SKILL.md              # Entry point — frontmatter + workflow instructions (MANDATORY)
├── config.json           # Skill configuration (paths, flags, defaults)
├── gotchas.md            # Known failure patterns — update when new ones encountered
├── steps/                # Sequential step files (for step-file architecture skills)
│   ├── step-01-xxx.md
│   ├── step-02-xxx.md
│   └── ...
├── references/           # Reference documentation loaded on-demand
│   ├── mode-b-deep.md
│   ├── backward-tracing.md
│   └── ...
└── data/                 # Optional runtime data (e.g., alignment-log.jsonl)
```

### Frontmatter Schema

```yaml
---
name: x-example                      # Skill name
description: "One-line description"  # What it does
role: router                         # (04) router | reviewer | verifier
slots:                               # (05) pluggable slots
  workspace: current-dir
  verifier: x-verify
reactions:                           # (02) declarative event handlers
  implementation-complete:
    action: menu
    options: [commit, review, done]
    auto: false
triggers:                            # (optional) Fuzzy trigger phrases
  - "keyword"
matching: fuzzy                      # Trigger matching mode
---
```

### Skill Discovery Rules

- Claude Code skill loader registers a directory as a skill **only when it contains a `SKILL.md`**
- `x-shared/` intentionally omits `SKILL.md` to stay invisible to skill discovery
- Skills reference sibling skills via relative paths: `../x-shared/<file>.md`, `../x-omo/SKILL.md`

---

*End of X-Skills Internal Architecture & Flow Documentation*
