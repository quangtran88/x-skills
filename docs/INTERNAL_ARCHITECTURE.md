# Internal Architecture

This document describes how x-skills works internally — from plugin loading to skill invocation to cross-skill handoff.

## Plugin Lifecycle

### 1. Installation

When a user runs `/plugin install x-skills@x-skills-marketplace`:

1. Claude Code downloads the plugin to `~/.claude/plugins/cache/x-skills-marketplace/x-skills/`
2. The plugin manifest (`.claude-plugin/plugin.json`) is registered
3. `/reload-plugins` makes the skills available as slash commands

### 2. SessionStart Hook

Every new Claude Code session triggers the `SessionStart` hook defined in `plugin.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/check-version.sh\"",
            "timeout": 3
          },
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/inject-capabilities.sh\"",
            "timeout": 3
          }
        ]
      }
    ]
  }
}
```

**`check-version.sh`**:
- Reads the plugin manifest version
- Compares against `~/.config/x-skills/capabilities.json` (written by `bin/setup`)
- If versions differ, warns: "Plugin upgraded — re-run `/x-skills:setup`"

**`inject-capabilities.sh`**:
- Reads `~/.config/x-skills/capabilities.json`
- Injects a one-line snapshot into the conversation context: `[x-skills/capabilities] opencode, omo_plugin, gemini_cli, mcp_perplexity, ...`
- Skills parse this line at bootstrap to know what's available

### 3. Skill Loading

Claude Code discovers skills by scanning for `SKILL.md` files in `~/.claude/skills/` and plugin cache directories. Each `SKILL.md` has YAML frontmatter:

```yaml
---
name: x-do
description: Use when the user asks to build, implement, fix, or execute...
role: router
slots:
  workspace: current-dir
  verifier: x-verify
reactions:
  test-failed:
    action: route
    to: x-bugfix
    retries: 2
    auto: true
---
```

The frontmatter declares:
- **name**: Slash command trigger (`/x-skills:x-do`)
- **description**: Intent-matching text for Claude's skill router
- **role**: Behavioral constraints (router, reviewer, verifier) — only some skills declare a role
- **slots**: Pluggable dependency points (workspace, verifier, etc.)
- **reactions**: Declarative trigger→action mapping (Phase 1: prose-only; Phase 2: execution contract)

## Skill Bootstrap Pattern

Every skill follows the same bootstrap sequence:

1. **Pin capabilities**: Parse the `[x-skills/capabilities]` snapshot or read `~/.config/x-skills/capabilities.json`
2. **Load references**: Read `../x-omo/SKILL.md` (agent catalog), `gotchas.md` (failure patterns), etc.
3. **Filter routing tables**: Drop unavailable lanes, pick fallback rows
4. **Classify**: Detect mode/type/signal from user input
5. **Route**: Dispatch to the best available executor

## Execution Flow

### Router Skills (x-do, x-research)

```
Bootstrap (capability pin + reference load)
    │
Detection/Classification
    │
┌───┴───┐
│ Mode A │──→ Plan review → Execute → Post-impl review → Verify
│ Mode B │──→ Brainstorm → Plan → Plan review → Execute → Post-impl review → Verify
│ Mode C │──→ Delegate to x-bugfix → Post-fix review → Verify
│ Mode D │──→ Direct execute → Verify
│ Mode E │──→ Visual analysis → Route to A/B/C
│ Mode F │──→ Delegate to refactor → Post-refactor review → Verify
└────────┘
```

### Reviewer Skills (x-review)

```
Bootstrap
    │
Step 1: Prepare (detect target, collect content)
    │
Step 2: Review (launch cross-model reviewers in parallel)
    │
Step 3: Synthesize (verify, reconcile findings, present verdict)
    │
Step 4: Act (menu, fix mode, additional passes)
```

### Bridge Skills (x-omo, x-gemini)

```
Parse arguments
    │
Quick dispatch? (agent name or --model flag) → Immediate Bash invocation
    │
Show catalog / help
```

## Tool Invocation Patterns

### Skill Tool
Invoke a skill by name. Loads the skill's workflow and runs it.

```
Skill("x-research", args="how does auth work in this codebase?")
```

### Agent Tool (OMC)
Dispatch to an OMC agent with a subagent type. Used for code-reviewer, executor, debugger.

```
Agent(subagent_type="oh-my-claudecode:code-reviewer", prompt="Review this diff...")
```

### Bash Tool (OMO)
Invoke OMO agents via the `omo-agent` wrapper. **Never** use `Agent` tool for OMO — it silently downgrades to Claude.

```bash
omo-agent oracle "Architecture advice for auth system"
```

### MCP Tools
Direct tool calls for perplexity, exa, deepwiki, context7. Availability gated by capability manifest.

```
mcp__perplexity__perplexity_ask(query="what is OAuth2 PKCE?")
```

## Orchestration Primitives

Every subagent dispatch picks one of two primitives explicitly:

### `handoff` — Sync Delegation
- **Semantics**: Dispatch, wait for result, continue with that result
- **Use when**: Task B depends on Task A's output
- **Requirement**: Must include a handoff context block (see `context-envelope.md`)

```
handoff → code-reviewer subagent with diff + context envelope
wait for review result
handoff → executor subagent with review + original task + context envelope
```

### `assign` — Async Fan-Out
- **Semantics**: Dispatch N subagents at once, wait for all, synthesize
- **Use when**: Tasks are independent
- **Rule**: All calls must be in **ONE message**

```
assign → [explore agent, librarian agent, oracle agent] in ONE message
wait for all three
synthesize
```

## Slot Resolution

Skills declare pluggable slots in their frontmatter. Resolution follows a 3-layer cascade:

1. **User override in current prompt**: "use x-review this time" → wins
2. **Skill frontmatter `slots:` block**: Declared default
3. **Canonical default from `slot-schema.md`**: Ultimate fallback

Example (x-do):
```yaml
slots:
  workspace: current-dir
  verifier: x-verify
```

The `verifier` slot is typed `skill-or-agent` — it can resolve to either a skill (dispatch via `Skill` tool) or an OMC agent (dispatch via `Agent` tool). The skill must check which kind resolved and dispatch accordingly.

## The 9-Layer Precedence Ladder

When instructions conflict, the higher-priority layer wins:

| Priority | Layer | Example |
|----------|-------|---------|
| **0** | **Inviolable principles** | "never edit plugin cache" / "x-skills are routers" |
| 1 | User's explicit in-prompt instructions | "skip the review this time" |
| 2 | Project `CLAUDE.md` | Per-project rules |
| 3 | Repo `CLAUDE.md` (this repo's policy) | "x-skills are routers; no persistence" |
| 4 | Memory feedback files (advisory) | `feedback_xreview_compliance.md` |
| 5 | `~/.claude/CLAUDE.md` (user's global) | "always use ripgrep (`rg`)" |
| 6 | Skill frontmatter (`role:`, `slots:`, `reactions:`) | `role: router` on `x-do` |
| 7 | Skill body (markdown below frontmatter) | The actual skill instructions |
| 8 | Claude Code harness + superpowers defaults | Baseline behavior |

Walk the ladder from top to bottom. First layer that addresses the conflict wins.

## Error Handling and Fallbacks

### Capability Drift
If a tool errors at runtime despite being marked available:
1. Surface: `[x-skills] <tool> failed despite capability pin. Re-run: ./bin/setup --check`
2. Pick the next fallback row in the routing table
3. Continue the session — do not re-snapshot mid-session

### Missing Dependencies
Skills must degrade gracefully:
- OMO agents unavailable → Use Claude-native `Agent` tool with generic prompt
- MCP servers unavailable → Use `WebFetch` or OMO `librarian`
- External tools unavailable → Skip the lane, inform user

### Agent Failures
- Exit 0 = success, non-zero = failure
- "agent not found" = agent name issue → use valid name from catalog
- "Unknown agent" = not in valid list → see Agent Catalog
- Timeout = prompt too broad → break into smaller prompts

## Persistence and State

x-skills is **stateless** by design:
- No state files between invocations
- No session memory beyond what Claude Code's conversation provides
- Handoff context blocks carry state between skills

The only persistent artifacts are:
- `~/.config/x-skills/capabilities.json` — capability manifest (rewritten by setup)
- `~/.config/x-skills/files-manifest.json` — freshness check for drift detection
- Skill-specific debug logs (e.g., `x-bugfix`'s `debug-log.jsonl`)

## File Freshness and Drift Detection

`bin/setup` writes a `files-manifest.json` that tracks SHA256 hashes of routing-critical files. On `--check`, it verifies:
- Files in manifest still exist
- Hashes match (no drift)
- No extra files on disk not in manifest

This catches "I forgot to re-run setup after upgrading" scenarios. It is a freshness signal, not a security control.

## Security Considerations

1. **Symlink verification**: `omo-agent` and `gemini-agent` symlinks are validated for ownership and permissions before creation. World-writable targets are refused.
2. **No arbitrary code execution**: Skills are markdown prompts, not executable scripts.
3. **Capability subtraction**: Project overrides can only disable capabilities, not grant new ones.
4. **Target confirmation**: `x-api-pentest` requires explicit authorization before scanning live APIs.
