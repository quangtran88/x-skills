# x-skills — Intelligent Skill Routers for Claude Code

11 skills that classify user intent and route to the optimal executor. Ships with optional multi-model orchestration via OpenCode.

## Skills

| Skill | Purpose | Requires |
|-------|---------|----------|
| **x-do** | Build, implement, fix, execute | Best with: opencode, OMC, superpowers |
| **x-research** | Research, investigate, understand | Best with: opencode, MCP servers |
| **x-review** | Code review, plan review, PR review | Best with: opencode, OMC, superpowers |
| **x-verify** | Run the completion cascade ("am I done?") | Standalone |
| **x-bugfix** | Debug, investigate failures, fix bugs | Best with: opencode, OMC |
| **x-design** | Apply visual design systems | Standalone |
| **x-api-pentest** | API security testing (OWASP Top 10) | External security CLIs |
| **x-omo** | OpenCode multi-model bridge | opencode CLI |
| **x-skill-review** | Audit skill quality | Optional: claude-mem |
| **x-skill-improve** | Improve skills from session data | Optional: claude-mem |
| **x-shared** | Shared references (not invokable) | None |

## Feature Gates

Skills auto-detect available dependencies at bootstrap and route accordingly. No dependency is strictly required — skills degrade gracefully.

**Full capability** = opencode + oh-my-claudecode + superpowers + MCP servers (perplexity, deepwiki, exa, context7, morph-mcp)
**Claude-only mode** = works with zero external deps, uses native Claude Code agents and tools

### Bootstrap Protocol

Every skill that dispatches to external agents MUST:

1. Read `~/.config/x-skills/capabilities.json` (written by `bin/setup`)
2. If the file is missing, assume Claude-only mode
3. Route based on what's available — see `lib/feature-gate.md` for fallback table

### omo-agent Binding

The `omo-agent` script bridges Claude Code skills to OpenCode's multi-model agents. Setup:

```bash
./bin/setup
```

This creates a symlink at `~/.local/bin/omo-agent` and writes `~/.config/x-skills/capabilities.json`.

Skills reference omo-agent by name (not path) — it must be on PATH or the skill falls back to Claude-only routing.

### Claude-Only Fallback Routing

When opencode is unavailable, skills substitute:

| OMO Agent | Claude-Only Replacement |
|-----------|------------------------|
| `oracle` (GPT-5.4) | `Agent` tool with `model=opus` |
| `explore` (Gemini Flash) | `Agent` tool with `subagent_type=Explore` |
| `librarian` (Gemini Flash) | `Agent` tool with web search |
| `multimodal-looker` (Gemini Pro) | `Read` tool (Claude is multimodal) |
| `--model codex` | `Agent` tool with `model=opus` |

When OMC plugin is unavailable:
| OMC Agent | Claude-Only Replacement |
|-----------|------------------------|
| `executor` | `Agent` tool with `mode=auto` |
| `code-reviewer` | `Agent` tool with review prompt |
| `debugger` | `Agent` tool with debug prompt |

## Setup

Run `bin/setup` after installation to configure the omo-agent binding and detect capabilities:

```bash
# Full setup
./bin/setup

# Check mode (no changes)
./bin/setup --check

# Remove binding
./bin/setup --uninstall
```

Or invoke the setup skill: `/x-skills-setup`

## Instruction Precedence

The skills in this repo resolve conflicting instructions via the precedence ladder in `skills/x-shared/invocation-guide.md` § "Prompt Assembly — Precedence Ladder".

TL;DR: inviolable principles > user in-prompt > project `CLAUDE.md` > **this file** > advisory memory > `~/.claude/CLAUDE.md` > skill frontmatter > skill body > harness.

When editing this file, remember it sits at priority 3 — specific enough to override a user's global defaults for anyone working on this repo, weak enough that a single project can override for its own needs.
