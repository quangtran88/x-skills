# Setup and Dependencies

This document describes the setup script, dependency detection, and the proposed lazy dependency system.

## Setup Script (`bin/setup`)

The setup script is the canonical entry point for configuring x-skills. It:

1. Makes `omo-agent` and `gemini-agent` executable
2. Creates symlinks at `~/.local/bin/`
3. Detects available tools, plugins, MCP servers, and security tools
4. Writes a capability manifest to `~/.config/x-skills/capabilities.json`
5. Reports which skills are fully operational vs. degraded

### Usage

```bash
./bin/setup                # Full setup (install binding + detect deps)
./bin/setup --check        # Check-only mode (no modifications)
./bin/setup --fix          # Setup + offer to install missing dependencies
./bin/setup --uninstall    # Remove omo-agent binding
```

### What It Detects

#### 1. omo-agent binding
- Makes `bin/omo-agent` executable
- Creates symlink at `~/.local/bin/omo-agent`
- Verifies `~/.local/bin` is on PATH

#### 2. gemini-agent binding
- Makes `bin/gemini-agent` executable
- Creates symlink at `~/.local/bin/gemini-agent`
- Detects `gemini` CLI and `timeout`/`gtimeout`

#### 3. OpenCode CLI
- Detects `opencode` binary
- Lists available models
- Detects `oh-my-openagent` plugin via config and node_modules
- Checks if role agents resolve (`opencode agent list`)
- Audits `mode=all` in `oh-my-openagent.json`

#### 4. MCP Servers
- `perplexity` — web search + reasoning
- `deepwiki` — OSS repo documentation
- `exa` — code context + web crawling
- `context7` — library API docs
- `morph` — semantic codebase search + editing

Detection method: grep `settings.json`, `.mcp.json`, and plugin cache `.mcp.json` files.

#### 5. Peer Plugins
- `oh-my-claudecode` — multi-agent orchestration
- `superpowers` — workflow skills
- `claude-mem` — cross-session memory

#### 6. Companion Skills
- `ui-ux-pro-max` — design-system MASTER.md generator
- `x-skill-review` — skill quality auditor

#### 7. Security Tools
- `schemathesis`, `nuclei`, `sqlmap`, `spectral`, `interactsh-client`

### Skill Readiness Report

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

### `--fix` Mode

`bin/setup --fix` offers to install missing dependencies interactively:

1. **CLI tools**: opencode, gemini, jq, coreutils, security tools
2. **MCP servers**: Via `claude mcp add` (requires API keys for some)
3. **Companion skills**: Via `git clone`
4. **Claude Code plugins**: Outputs install commands (must run inside Claude Code)

Install commands are keyed by name in a static dispatch table — no `eval` on data-derived strings.

### File Freshness and Drift Detection

`bin/setup` writes a `files-manifest.json` that tracks SHA256 hashes of routing-critical files. On `--check`, it verifies:
- Files in manifest still exist
- Hashes match (no drift)
- No extra files on disk not in manifest

This catches "I forgot to re-run setup after upgrading" scenarios.

### Symlink Security

Before creating symlinks, `bin/setup` verifies:
- Target file is owned by current user
- Target file is not world-writable
- Target's parent directory is not world-writable

This bounds trust on the plugin-cache symlink target.

## Plugin Manifest (`.claude-plugin/plugin.json`)

```json
{
  "name": "x-skills",
  "version": "1.4.0",
  "description": "Intelligent skill routers for execution, research, review, debugging, design, and security testing",
  "author": { "name": "Randy Tran" },
  "license": "MIT",
  "keywords": ["claude-code", "plugin", "skills", "router", "multi-model"],
  "homepage": "https://github.com/quangtran88/x-skills",
  "repository": "https://github.com/quangtran88/x-skills",
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

### SessionStart Hooks

**`check-version.sh`**:
- Reads plugin manifest version
- Compares against `~/.config/x-skills/capabilities.json`
- Warns if versions differ: "Plugin upgraded — re-run `/x-skills:setup`"

**`inject-capabilities.sh`**:
- Reads `~/.config/x-skills/capabilities.json`
- Injects one-line snapshot into conversation context: `[x-skills/capabilities] opencode, omo_plugin, gemini_cli, ...`
- Skills parse this line at bootstrap

## Dependencies Summary

### Full Capability Tier

| Dependency | What it enables | Install |
|-----------|----------------|---------|
| OpenCode | Multi-model dispatch | `curl -fsSL https://opencode.ai/install \| bash` |
| oh-my-openagent | Role agents (oracle, explore, librarian) | `opencode plugin oh-my-openagent` |
| oh-my-claudecode | OMC agents (executor, code-reviewer, debugger) | `/plugin marketplace add Yeachan-Heo/oh-my-claudecode` |
| superpowers | Workflow skills | `/plugin marketplace add obra/superpowers-marketplace` |
| claude-mem | Cross-session memory | `/plugin marketplace add thedotmack/claude-mem` |
| MCP servers | perplexity, deepwiki, exa, context7, morph | Configure in `.mcp.json` |
| Gemini CLI | Direct Gemini access | `npm install -g @google/gemini-cli` |
| Security tools | schemathesis, nuclei, sqlmap, spectral | `pip install schemathesis sqlmap` / `brew install nuclei` |

### Capability Tiers

| Tier | What you have | Skill capability |
|------|--------------|-----------------|
| **Full** | OpenCode + oh-my-openagent + OMC + superpowers + MCP servers | Multi-model routing, cross-model review, full agent catalog |
| **Claude+Plugins** | OMC + superpowers (no OpenCode) | Claude-only routing with OMC agents and workflow skills |
| **Bare** | Just x-skills | Claude-only fallback — skills still work using native Agent tool |
