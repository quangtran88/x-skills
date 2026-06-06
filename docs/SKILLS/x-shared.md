# x-shared — Shared Infrastructure

> **Type:** Reference library (NOT an invokable skill)  
> **Purpose:** Cross-cutting concerns consumed by all other skills via relative paths (`../x-shared/<file>.md`).

---

## Key Files

| File | Purpose | Consumers |
|------|---------|-----------|
| `capability-loading.md` | Bootstrap-pinned capability contract. "Detect once at setup. Pin at bootstrap. Never re-check per dispatch." | All skills |
| `invocation-guide.md` | Tool invocation patterns + 9-layer prompt precedence ladder + orchestration primitives (`handoff`/`assign`) | All skills |
| `workflow-chains.md` | Common cross-skill chain sequences | All skills |
| `context-envelope.md` | Handoff context block format for chaining | All skills |
| `completion-cascade.md` | x-verify cascade specification (5 steps: SCOPE GATE → ABORT → EXPLICIT FAILURE → VERIFICATION → MANDATORY FALLBACK → HUMAN-APPROVAL) | x-do, x-verify |
| `mcp-toolbox.md` | Plugin-local MCP decision matrix (perplexity / exa / deepwiki / context7) | x-research, x-bugfix |
| `severity-guide.md` | Finding severity scale (CRITICAL/HIGH/MEDIUM/LOW) | x-review, x-bugfix, x-api-pentest |
| `omo-routing.md` | Signal → OMO agent routing table | x-do, x-research |
| `slot-schema.md` | Slot-fill schema for skills (v1: `workspace`, `verifier`) | All skills |
| `reactions-vocabulary.md` | Cross-skill reaction signals | All skills |
| `common-gotchas.md` | Cross-skill operational pitfalls | All skills |

---

## Prompt Assembly — Precedence Ladder (9 Layers)

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

---

## Orchestration Primitives

Every subagent dispatch picks ONE primitive explicitly:

| Primitive | Semantics | When to Use |
|-----------|-----------|-------------|
| **`handoff`** | Sync delegation — dispatch, wait for result, continue | Task B depends on Task A's output. Must include context envelope. |
| **`assign`** | Async fan-out — dispatch N subagents in ONE message, wait for all, synthesize | 2+ independent tasks. All calls must be in a single message. |

---

## Why No SKILL.md

The Claude Code skill loader registers a directory as a skill only when it contains a `SKILL.md`. Omitting that file keeps `x-shared/` invisible to skill discovery while the files remain reachable via relative paths from sibling skills.
