# Bootstrap and Capability System

The capability system is the foundation of x-skills. It answers the question: "What tools and agents are available right now?" and ensures skills make routing decisions against a consistent, pinned snapshot.

## Core Principle

> **Detect once at setup. Pin at bootstrap. Never re-check per dispatch.**

`bin/setup` writes the manifest. The SessionStart hook injects a one-line snapshot. Skills' Bootstrap step reads either source. Routing tables are filtered against the pinned set on entry — no capability checks before each tool dispatch.

## Capability Manifest

Location: `~/.config/x-skills/capabilities.json`

```json
{
  "version": "1.0.0",
  "generated_at": "2026-05-03T10:00:00Z",
  "plugin_dir": "/abs/path",
  "omo_agent": "/abs/path/bin/omo-agent",
  "capabilities": {
    "opencode": true,
    "omo_plugin": "partial",
    "omo_mode_all": true,
    "gemini_cli": true,
    "mcp": {
      "perplexity": true,
      "deepwiki": true,
      "exa": true,
      "context7": true
    },
    "plugins": {
      "oh_my_claudecode": true,
      "superpowers": true
    },
    "companion_skills": {
      "ui_ux_pro_max": true,
      "x_skill_review": false
    },
    "security_tools": {
      "schemathesis": true,
      "nuclei": true,
      "sqlmap": true,
      "spectral": true,
      "interactsh": false
    }
  }
}
```

### Fields

| Field | Meaning |
|-------|---------|
| `opencode` | OpenCode CLI installed and reachable |
| `omo_plugin` | `oh-my-openagent` plugin status: `full` (all agents work), `partial` (some broken), `false` |
| `omo_mode_all` | Role agents configured with `mode: all` in `oh-my-openagent.json` |
| `gemini_cli` | `gemini` CLI installed and on PATH |
| `mcp.*` | MCP servers detected in Claude Code settings |
| `plugins.*` | Peer Claude Code plugins installed |
| `companion_skills.*` | User-level skills in `~/.omc/skills/` or `~/.claude/skills/` |
| `security_tools.*` | External security CLIs for `x-api-pentest` |

## Sources of Truth (Precedence)

1. **Project override** — `.x-skills/capabilities.json` in the project root (optional, subtractive only)
2. **User manifest** — `~/.config/x-skills/capabilities.json` (written by `bin/setup`)
3. **Plugin defaults** — Empty set, all lanes unavailable, fallback rows used everywhere

Project overrides are **subtractive only**: a project file can disable a capability the user has, but cannot grant new capabilities. This bounds trust — a hostile repo cannot upgrade routing posture by lying. The hook also caps the project file at 16 KiB to prevent SessionStart DoS.

## SessionStart Hook Injection

The `inject-capabilities.sh` hook reads the manifest and injects a one-line snapshot into the conversation context:

```
[x-skills/capabilities] opencode, omo_plugin, gemini_cli, mcp_perplexity, mcp_deepwiki, mcp_exa, mcp_context7, plugin_oh_my_claudecode, plugin_superpowers
```

Skills parse this line at bootstrap. If absent, they fall back to reading `~/.config/x-skills/capabilities.json` directly with `jq`.

## Skill Bootstrap Sequence

Every skill follows this exact sequence before dispatching anything:

### Step 0: Pin Capabilities

```markdown
**MANDATORY first step — do this BEFORE anything else:**

0. Pin capabilities for the session per `../x-shared/capability-loading.md`.
   Filter routing tables against the pinned set; do NOT re-check per dispatch.
```

Implementation:
1. Search conversation context for `[x-skills/capabilities]` line
2. Parse comma-separated active set
3. If absent, read `~/.config/x-skills/capabilities.json` once with `jq`
4. Trust the active set for the entire session

### Step 1: Load Reference Files

Skills load reference files relevant to their domain:
- `../x-omo/SKILL.md` — OMO agent catalog + Bash invocation patterns
- `../x-gemini/SKILL.md` — Gemini CLI bridge (for research skills)
- `../x-shared/mcp-toolbox.md` — MCP decision matrix
- `../x-shared/invocation-guide.md` — Tool invocation patterns
- `gotchas.md` — Known failure patterns for this skill

**Bootstrap shortcut**: If the task is a Standard-Mode local-only direct read with no agent dispatch, some reference loads may be skipped.

### Step 2: Filter Routing Tables

Using the pinned capability set, the skill filters its routing tables:
- Drop lanes whose tools/agents are unavailable
- Pick fallback rows when primary is unavailable
- Surface unavailable lanes to the user if they asked for them explicitly

Example (x-research signal→tool table):
```markdown
| Signal | Primary | Escalation |
| Local code | OMO `explore` | native `Grep` |
| Public repo internals | `deepwiki` → `ask_question` | `gh search code` → OMO `librarian` |
| Library API usage | `context7` → `query-docs` | `exa` → `get_code_context_exa` |
```

If `opencode` is false, the "Local code" row drops OMO `explore` and falls back to native `Grep`.

### Step 3: Classify and Route

With filtered routing tables, classify the user's request and dispatch to the best available executor.

## Capability Detection in `bin/setup`

The setup script detects capabilities in this order:

### 1. omo-agent binding
- Makes `bin/omo-agent` executable
- Creates symlink at `~/.local/bin/omo-agent`
- Verifies `~/.local/bin` is on PATH

### 2. gemini-agent binding
- Makes `bin/gemini-agent` executable
- Creates symlink at `~/.local/bin/gemini-agent`
- Detects `gemini` CLI and `timeout`/`gtimeout`

### 3. OpenCode CLI
- Detects `opencode` binary
- Lists available models
- Detects `oh-my-openagent` plugin via config and node_modules
- Checks if role agents resolve (`opencode agent list`)
- Audits `mode=all` in `oh-my-openagent.json`

### 4. MCP Servers
Checks Claude Code settings for:
- `perplexity` — web search + reasoning
- `deepwiki` — OSS repo documentation
- `exa` — code context + web crawling
- `context7` — library API docs

Detection method: grep `settings.json`, `.mcp.json`, and plugin cache `.mcp.json` files.

### 5. Peer Plugins
Checks `installed_plugins.json` for:
- `oh-my-claudecode` — multi-agent orchestration
- `superpowers` — workflow skills

### 6. Companion Skills
Checks `~/.omc/skills/` and `~/.claude/skills/` for:
- `ui-ux-pro-max` — design-system MASTER.md generator
- `x-skill-review` — skill quality auditor

### 7. Security Tools
Checks PATH for:
- `schemathesis`, `nuclei`, `sqlmap`, `spectral`, `interactsh-client`

## Writing the Manifest

After detection, `bin/setup` writes `capabilities.json` with all detected flags. In `--check` mode, it reports what would be written without modifying files.

## Skill Readiness Report

At the end of setup, a readiness report is printed:

```
x-do           — full capability
x-research     — full capability
x-review       — degraded (missing: superpowers)
x-bugfix       — full capability
x-design       — full capability
x-api-pentest  — degraded (missing: security-tools)
x-omo          — full capability
x-gemini       — full capability
```

This tells the user which skills are fully operational and which are running in degraded mode.

## Drift Handling

If a tool errors at runtime despite being marked available:

1. Surface: `[x-skills] <tool> failed despite capability pin. Re-run: ./bin/setup --check`
2. Pick the next fallback row in the routing table
3. Continue the session — do not re-snapshot mid-session

This handles the case where a CLI was uninstalled or an MCP server stopped after setup ran.

## Opt-Out

Users can mute a capability without uninstalling the underlying tool:

```json
// .x-skills/capabilities.json
{ "capabilities": { "mcp": { "perplexity": false } } }
```

Project override > user manifest. Useful for:
- Cost control (mute `perplexity_research`)
- CI environments (mute interactive tools)
- Testing fallback paths

## `--fix` Mode

`bin/setup --fix` offers to install missing dependencies interactively:

1. **CLI tools**: opencode, gemini, jq, coreutils, security tools
2. **MCP servers**: Via `claude mcp add` (requires API keys for some)
3. **Companion skills**: Via `git clone`
4. **Claude Code plugins**: Outputs install commands (must run inside Claude Code)

The install commands are keyed by name in a static dispatch table — no `eval` on data-derived strings.
