---
description: "Configure x-skills plugin — sets up omo-agent binding, detects dependencies, and offers to install missing ones"
---

# x-skills Setup

Run the setup script and offer to install missing dependencies.

## Step 1: Find and run setup

Locate the plugin directory and run `bin/setup`:

```bash
PLUGIN_DIR="$(cat ~/.config/x-skills/capabilities.json 2>/dev/null | grep plugin_dir | head -1 | sed 's/.*: "//;s/".*//')"
if [[ -z "$PLUGIN_DIR" || ! -f "$PLUGIN_DIR/bin/setup" ]]; then
  for candidate in \
    "$(dirname "$(dirname "$(readlink ~/.local/bin/omo-agent 2>/dev/null)")")" \
    "$HOME/x-skills" \
    $(find "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/cache" -path "*/x-skills/*/bin/setup" 2>/dev/null | while read p; do dirname "$(dirname "$p")"; done); do
    if [[ -n "$candidate" && -f "$candidate/bin/setup" ]]; then
      PLUGIN_DIR="$candidate"
      break
    fi
  done
fi
[[ -n "$PLUGIN_DIR" && -f "$PLUGIN_DIR/bin/setup" ]] && "$PLUGIN_DIR/bin/setup" || echo "ERROR: x-skills plugin not found"
```

## Step 2: Read capabilities

```bash
cat ~/.config/x-skills/capabilities.json 2>/dev/null
```

## Step 3: Offer to install missing dependencies

After reading capabilities, check what's missing and offer to install. Present the user with a numbered menu of missing items.

**For missing CLI tools** (opencode, security tools):
- Run the install command via Bash if user approves
- Re-run `bin/setup` after installing to update capabilities

**For missing Claude Code plugins**, offer to install each one. These are installed via shell commands using `claude` CLI plugin management:

| Plugin | Marketplace | Install commands |
|--------|------------|-----------------|
| oh-my-claudecode | omc | Run in Bash: `claude plugin marketplace add Yeachan-Heo/oh-my-claudecode` then `claude plugin install oh-my-claudecode@omc` |
| superpowers | superpowers-marketplace | Run in Bash: `claude plugin marketplace add obra/superpowers-marketplace` then `claude plugin install superpowers@superpowers-marketplace` |
| claude-mem | thedotmack | Run in Bash: `claude plugin marketplace add thedotmack/claude-mem` then `claude plugin install claude-mem@thedotmack` |

**IMPORTANT:** After installing any Claude Code plugins, tell the user they need to restart the session or run `/reload-plugins` for the new plugins to take effect.

**For missing MCP servers**, these require manual configuration. Provide setup guidance:
- **perplexity**: Requires API key from perplexity.ai, configure in `.mcp.json`
- **deepwiki**: Free, configure in `.mcp.json` with `npx -y @anthropic-ai/deepwiki-mcp`
- **exa**: Requires API key from exa.ai, configure in `.mcp.json`
- **context7**: Free, configure in `.mcp.json` with `npx -y @anthropic-ai/context7-mcp`
- **morph**: Requires morph account, configure in `.mcp.json`

## Step 4: Re-run setup if anything was installed

If any CLI tools were installed, re-run `bin/setup` to update the capabilities manifest:

```bash
"$PLUGIN_DIR/bin/setup"
```

## Step 5: Report final state

Summarize what's now available, what's still missing, and which skills are at full capability.
