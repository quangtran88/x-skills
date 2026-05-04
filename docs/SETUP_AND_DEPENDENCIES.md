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

## Lazy Dependency System (Design Document)

See `docs/DEPENDENCY_SYSTEM_DESIGN.md` for the full specification. Summary:

### Problem

x-skills relies on multiple external plugins (`superpowers`, `oh-my-claudecode`). Installing full plugins is heavyweight and pulls in 50+ unused skills.

### Solution

A **lazy dependency system** that:
- Downloads only the specific skills/agents x-skills needs
- Stores them on the user's machine (not in this repo)
- Provides version pinning via lock files
- Offers a simple CLI for dependency management

### Key Principle

Dependencies are **extracted prompts and agent definitions** stored as flat `.md` files, invoked via `Read` + `Agent` tools rather than `Skill` tool with namespace prefixes.

### Architecture

```
User runs /plugin install x-skills
    │
SessionStart hook triggers
    │
Hook calls: bin/setup --pull-deps
    │
Setup reads dependencies/registry.json
    │
For each dependency:
    - Check if already downloaded
    - Download from source (git sparse checkout or raw URL)
    - Store in ~/.claude/plugins/cache/x-skills-marketplace/x-skills/deps/
    - Record SHA in lock file
    │
Skills reference deps via Read tool
    │
If dependency missing → fallback to generic prompt
```

### Directory Structure (on User's Machine)

```
~/.claude/plugins/cache/x-skills-marketplace/x-skills/
├── skills/                    # X-Skills native skills
├── deps/                      # Downloaded dependencies
│   ├── prompts/               # Skill prompts
│   │   ├── superpowers-writing-plans.md
│   │   └── superpowers-verification-before-completion.md
│   └── agents/                # Agent definitions
│       ├── superpowers-code-reviewer.md
│       └── oh-my-claudecode-code-reviewer.md
├── dependencies/
│   ├── registry.json          # Source of truth (shipped in repo)
│   └── lock.json              # Installed versions (generated on user machine)
└── bin/
    └── xskill-deps            # Dependency management CLI
```

### Registry Format

```json
{
  "version": "1.0.0",
  "format": "xskill-dep-v1",
  "sources": {
    "superpowers": {
      "repo": "https://github.com/obra/superpowers.git",
      "ref": "main",
      "type": "plugin",
      "artifacts": {
        "writing-plans": {
          "type": "prompt",
          "path": "skills/writing-plans/SKILL.md",
          "needed_by": ["x-do"]
        },
        "code-reviewer": {
          "type": "agent",
          "path": "skills/code-reviewer/SKILL.md",
          "needed_by": ["x-review"],
          "model": "claude-opus-4",
          "mode": "auto"
        }
      }
    }
  }
}
```

### CLI Reference (`xskill-deps`)

| Command | Description | Options |
|---------|-------------|---------|
| `pull` | Download artifacts from registry | `--provider`, `--artifact`, `--force` |
| `update` | Update artifacts to latest | `<artifact-path>`, `--all`, `--verify` |
| `check` | Check for available updates | `--provider` |
| `add` | Add artifact to registry | `--provider`, `--artifact`, `--type`, `--path`, `--needed-by` |
| `remove` | Remove artifact from registry | `<artifact-path>` |
| `list` | List registered artifacts | `--verbose`, `--provider`, `--missing-only` |
| `clean` | Remove downloaded artifacts not in registry | `--dry-run` |
| `verify` | Verify integrity of downloaded artifacts | `--provider`, `--artifact` |

### Resolution Cascade

When a skill needs an external dependency:

1. **Check if artifact exists** in `deps/`:
   - Yes → Use it (`Read` the `.md` file)
   - No → Continue to fallback

2. **Fallback** (when dependency not downloaded):
   - For agents → Use `Agent` tool with generic prompt
   - For prompts → Use inline simplified instructions
   - Log: "Using fallback — dependency X not available"

3. **Update available** (when lock SHA differs from registry):
   - Log: "Dependency X has update available"
   - Continue with current version
   - Suggest: `xskill-deps update`

### Implementation Plan

| Phase | Tasks | Timeline |
|-------|-------|----------|
| **Phase 1** | Registry + `pull` command, integrate with x-review, update `bin/setup` | Week 1 |
| **Phase 2** | `update`, `check`, `list`, lock file generation, SHA verification | Week 2 |
| **Phase 3** | `add`, `remove`, `clean`, dependency audit in x-skill-improve | Week 3 |
| **Phase 4** | `diff`, `fork`, `vendor`, automatic update checking | Week 4+ |

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
