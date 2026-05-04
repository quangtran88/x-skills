# Workflow Chains and Handoffs

x-skills are designed to chain together into complete workflows. This document describes the common chains, handoff conventions, and how skills transition between each other.

## Common Workflow Chains

### 1. Bug Fix Chain

```
User reports bug
    │
    ├─── Clear bug with stack trace ─────────────────────┐
    │                                                     │
    └─── Ambiguous bug, multi-component ───→ /x-research │
                  (Type A: codebase search)              │
                                                         │
    /x-bugfix (Mode A/B/C) ←─────────────────────────────┘
    │
    Post-fix verification (tsc + eslint + tests)
    │
    /x-review (post-fix review)
    │
    merge / commit
```

**When to use**: Any bug report, error, test failure, or unexpected behavior.

**Skip research when**: The bug is clear, has a stack trace, and the affected component is obvious.

### 2. New Feature Chain

```
User requests new feature
    │
    ├─── Requirements clear, known codebase ─────────────┐
    │                                                     │
    └─── Requirements vague or cross 3+ modules ──→ /x-research │
                  (Type F: pre-planning)                 │
                                                         │
    /x-do (Mode B: new feature) ←────────────────────────┘
    │
    Brainstorm → Plan → Plan Review (3 reviewers)
    │
    Execute (ralph or direct)
    │
    Post-Implementation Review (3 reviewers)
    │
    x-verify completion cascade
    │
    /x-review
    │
    merge / commit
```

**When to use**: Building something new, adding functionality, creating features.

**Skip research when**: Requirements are crystal clear and the codebase area is well-known.

### 3. Quick Fix Chain

```
User asks for trivial change
    │
    /x-do (Mode D: quick task)
    │
    Direct execution (single file, <10 lines)
    │
    tsc + eslint verification
    │
    /x-review (Target C: last commit, reduced to 1 reviewer)
```

**When to use**: Rename, config edit, single-line fix, trivial change clearly < 5 min.

**Skip review when**: The change is truly trivial and the user is in a hurry.

### 4. Refactor Chain

```
User requests structural change
    │
    /x-do (Mode F: refactor)
    │
    Detect: is /refactor skill available?
    ├─── Yes ─→ Delegate to /refactor with handoff context
    │            (6-phase workflow: intent → analysis → codemap →
    │             test assessment → plan → execute → final verification)
    │
    └─── No ─→ Fall back to Mode A (treat as multi-task plan)
    │
    Post-Refactor Review (cross-model, parallel)
    │
    x-verify completion cascade
    │
    merge / commit
```

**When to use**: "refactor", "restructure", "reorganize", "extract", "inline", "move to", "clean up" (multi-file).

### 5. Architecture Decision Chain

```
User asks for architecture advice
    │
    /x-research (Type C: architecture decision)
    │
    OMO oracle + perplexity_reason (parallel)
    │
    Synthesize findings
    │
    /x-do (Mode B: implement decision)
    │
    [Continue as New Feature Chain]
```

**When to use**: "Should we use X or Y?", "How should we structure Z?", architecture trade-offs.

### 6. Skill Improvement Chain

```
User runs a skill, wants to improve it
    │
    Use x-skill (e.g., /x-do for a feature)
    │
    Copy session into /x-skill-improve
    │
    Analyze alignment (instruction inventory vs. session behavior)
    │
    Apply fixes (UPDATE SKILL or COMPLIANCE GAP findings)
    │
    /x-skill-review (validate modified skill)
```

**When to use**: "Did the skill work right?", "Improve this skill from session", "skill alignment check".

### 7. API Security Test Chain

```
User provides OpenAPI spec
    │
    /x-api-pentest
    │
    Step 1: Recon (spec lint, attack surface, consent gate)
    Step 2: Auth baseline (validate tokens)
    Step 3: Automated sweep (Schemathesis + Nuclei)
    Step 4: Targeted tests (BOLA/BFLA, injection, business logic)
    Step 5: Synthesize (dedupe, severity, chain-impact)
    Step 6: Report (markdown + SARIF)
    │
    Handoff to security team or /x-review
```

**When to use**: OpenAPI/Swagger spec provided, request to pentest API, audit endpoints.

## Handoff Context

When chaining skills, include a handoff context block to help the next skill start faster.

### Format

```markdown
## Handoff Context
- **From:** [skill name] | **Type/Mode:** [classification used]
- **Key finding:** [one-liner summary of what was learned/decided]
- **Agents used:** [list of agents that contributed]
- **Recommendation:** [next skill + mode/type to use]
- **Artifacts:** [file paths of any documents produced]
```

### Examples

**After x-research (Type F: Pre-Planning)**:
```markdown
## Handoff Context
- **From:** x-research | **Type:** F (Pre-Planning)
- **Key finding:** Auth system needs RBAC, current implementation only has binary auth
- **Agents used:** oracle, explore
- **Recommendation:** x-do Mode B (new feature)
- **Artifacts:** none (findings synthesized above)
```

**After x-do (Mode B: New Feature)**:
```markdown
## Handoff Context
- **From:** x-do | **Mode:** B (New Feature)
- **Key finding:** RBAC implemented with 3 roles, 47 files changed
- **Agents used:** ralph (12 stories), code-reviewer
- **Recommendation:** x-review Target C (branch diff vs main)
- **Artifacts:** docs/superpowers/plans/2026-03-29-rbac.md
```

**After x-bugfix (Mode A: Quick Bug)**:
```markdown
## Handoff Context
- **From:** x-bugfix | **Mode:** A (Quick Bug)
- **Key finding:** Race condition in async pipeline, fixed with mutex + timeout
- **Agents used:** explore, OMC debugger
- **Recommendation:** x-review (post-fix review on commit abc123)
- **Artifacts:** debug-report.md (includes prevention measures)
```

### When to Include

- **Always** when routing to another skill explicitly
- **Always** when the next skill needs context about what was already done
- **Optional** for inline quick-actions where synthesis already serves as context
- **Optional** for `[P]` (plan first) handoffs where the user chose to plan

## Orchestration Primitives in Chains

### `handoff` — Sync Delegation

Use when the next skill depends on the previous skill's output.

```
handoff → x-research (Type F: pre-planning)
wait for synthesis
handoff → x-do (Mode B: new feature) with research findings
wait for implementation
handoff → x-verify
wait for verdict
handoff → x-review
```

### `assign` — Async Fan-Out

Use when multiple independent tasks can run in parallel.

```
assign → [explore agent, librarian agent, oracle agent] in ONE message
wait for all three
synthesize
handoff → x-do with synthesized findings
```

## When to Chain vs. Skip

| Situation | Chain | Skip |
|-----------|-------|------|
| Trivial change (rename, config edit) | — | Just `/x-do` Mode D |
| Clear bug with stack trace | `/x-bugfix` → `/x-review` | Skip research |
| Ambiguous bug, multi-component | `/x-research` → `/x-bugfix` → `/x-review` | — |
| Exploratory question | `/x-research` only | No need to chain forward |
| Full feature | Full chain: research → do → review → merge | — |
| Architecture question | `/x-research` → `/x-do` | — |
| Skill evaluation | `/x-skill-improve` → `/x-skill-review` | — |

## Skill Readiness and Degradation

When capabilities are missing, skills degrade gracefully:

| Missing Capability | Behavior |
|-------------------|----------|
| OpenCode / OMO | Fall back to Claude-native `Agent` tool with generic prompt |
| MCP servers | Use `WebFetch` or OMO `librarian` |
| OMC plugins | Use `Agent` tool without `subagent_type` |
| superpowers | Use inline simplified instructions |
| Security tools (x-api-pentest) | Skip the lane, inform user |

## Learner Hook

After a complex workflow completes (3+ steps, multi-agent, novel pattern) AND the OMC plugin is available, x-do offers:

> "This workflow succeeded. Save as a reusable skill? **[Y]** `/oh-my-claudecode:learner` **[N]** Skip"

Skip silently when OMC is unavailable — do not surface a slash command the user can't run.
