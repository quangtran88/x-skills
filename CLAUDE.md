# x-skills — Intelligent Skill Routers for Claude Code

10 plugin skills that classify user intent and route to the optimal executor, plus an external companion skill (`x-skill-review`, installed at `~/.claude/skills/`). Ships with optional multi-model orchestration via OpenCode.

## Skills

| Skill | Source | Purpose | Requires |
|-------|--------|---------|----------|
| **x-do** | plugin | Build, implement, fix, execute | Best with: opencode, OMC, superpowers |
| **x-research** | plugin | Research, investigate, understand | Best with: opencode, MCP servers |
| **x-review** | plugin | Code review, plan review, PR review | Best with: opencode, OMC, superpowers |
| **x-verify** | plugin | Run the completion cascade ("am I done?") | Standalone |
| **x-bugfix** | plugin | Debug, investigate failures, fix bugs | Best with: opencode, OMC |
| **x-design** | plugin | Apply visual design systems | Standalone |
| **x-api-pentest** | plugin | API security testing (OWASP Top 10) | External security CLIs |
| **x-omo** | plugin | OpenCode multi-model bridge | opencode CLI |
| **x-gemini** | plugin | Direct Gemini CLI bridge (Google Search, gemini-3.x, no API key) | gemini CLI + jq |
| **x-skill-improve** | plugin | Improve skills from session data | Optional: claude-mem |
| **x-shared** | plugin | Shared references (not invokable) | None |
| **x-skill-review** | external | Audit skill quality | User-level install at `~/.claude/skills/x-skill-review/`; optional: claude-mem |

## Feature Gates

Skills auto-detect available dependencies at bootstrap and route accordingly. No dependency is strictly required — skills degrade gracefully.

**Full capability** = opencode + oh-my-claudecode + superpowers + MCP servers (perplexity, deepwiki, exa, context7, morph-mcp)
**Claude-only mode** = works with zero external deps, uses native Claude Code agents and tools

### Bootstrap Protocol

Every skill that dispatches to external agents MUST follow the contract in `skills/x-shared/capability-loading.md`:

1. Look for the `[x-skills/capabilities]` line injected by the SessionStart hook (parsed once per session — do NOT re-check per dispatch)
2. If absent, read `~/.config/x-skills/capabilities.json` (written by `bin/setup`)
3. Merge `.x-skills/capabilities.json` from the project if present (project override > user manifest)
4. Filter routing tables against the pinned set; pick fallback rows when primary unavailable
5. If the manifest is missing entirely, assume Claude-only mode

Quick fallback reference for OMO/OMC agents lives in this file (tables below). Detailed schema, drift handling, and opt-out mechanics live in `skills/x-shared/capability-loading.md`.

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

Or invoke the setup skill: `/x-skills:setup`

## Instruction Precedence

The skills in this repo resolve conflicting instructions via the precedence ladder in `skills/x-shared/invocation-guide.md` § "Prompt Assembly — Precedence Ladder".

TL;DR: inviolable principles > user in-prompt > project `CLAUDE.md` > **this file** > advisory memory > `~/.claude/CLAUDE.md` > skill frontmatter > skill body > harness.
