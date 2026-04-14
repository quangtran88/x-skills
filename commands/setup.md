---
description: "Configure x-skills plugin — sets up omo-agent binding, detects dependencies, and offers to install missing ones. Safe to run repeatedly."
---

# x-skills Setup

Idempotent setup — safe to run any number of times. Each run detects current state and only acts on what's missing or changed.

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

## Step 3: Decide what to do based on current state

Parse the capabilities JSON. There are three possible outcomes:

### Case A: Everything is available
All capabilities are `true`. Report "all skills at full capability" and stop. No action needed.

### Case B: Some dependencies missing
Some capabilities are `false`. Present **only the missing items** as a numbered menu. Do NOT offer to install things that are already present.

**Before offering to install a plugin**, check if it's already installed:
```bash
grep -c '"<plugin-name>' "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/installed_plugins.json" 2>/dev/null
```
If the count is >0, the plugin is already installed — skip it from the menu.

**Before offering to install a CLI tool**, check if it's on PATH:
```bash
command -v <tool> &>/dev/null && echo "installed" || echo "missing"
```

### Case C: First run (no capabilities file before step 1)
Same as Case B but the setup script just created the file in step 1.

## Step 4: Install missing dependencies (if user approves)

Only install what the user selected. Skip anything already present.

**For CLI tools** (opencode, security tools):
- Run the install command via Bash
- These are idempotent — reinstalling an existing tool is harmless but wasteful, so check first

**For Claude Code plugins**, install via shell commands. Always check before installing:

```bash
# Check if already installed before attempting
if ! grep -q '"oh-my-claudecode' "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/installed_plugins.json" 2>/dev/null; then
  claude plugin marketplace add Yeachan-Heo/oh-my-claudecode 2>&1
  claude plugin install oh-my-claudecode@omc 2>&1
fi
```

| Plugin | Check name | Marketplace | Install |
|--------|-----------|------------|---------|
| oh-my-claudecode | `oh-my-claudecode` | `Yeachan-Heo/oh-my-claudecode` | `oh-my-claudecode@omc` |
| superpowers | `superpowers` | `obra/superpowers-marketplace` | `superpowers@superpowers-marketplace` |
| claude-mem | `claude-mem` | `thedotmack/claude-mem` | `claude-mem@thedotmack` |

**For MCP servers**, provide config guidance (cannot auto-install):
- **perplexity**: Requires API key from perplexity.ai, configure in `.mcp.json`
- **deepwiki**: Free, configure in `.mcp.json` with `npx -y @anthropic-ai/deepwiki-mcp`
- **exa**: Requires API key from exa.ai, configure in `.mcp.json`
- **context7**: Free, configure in `.mcp.json` with `npx -y @anthropic-ai/context7-mcp`
- **morph**: Requires morph account, configure in `.mcp.json`

## Step 5: Post-install actions

After installing anything:

1. **Tell user to run `/reload-plugins`** if any plugins were installed

2. **Check for required post-install setup** — only mention these for plugins that were JUST installed in this run, not for plugins that were already present:

| Plugin | Post-install command | When to mention |
|--------|---------------------|-----------------|
| oh-my-claudecode | `/oh-my-claudecode:omc-setup` | Only if OMC was installed in THIS run |
| claude-mem | Check claude-mem docs for MCP setup | Only if claude-mem was installed in THIS run |
| superpowers | None needed | Never |

3. **Re-run `bin/setup`** to update capabilities manifest with newly installed deps:
```bash
"$PLUGIN_DIR/bin/setup"
```

## Step 6: Report final state

Summarize concisely:
- **If everything is available**: "All skills at full capability. No action needed."
- **If some things were just installed**: List what was installed, what the user still needs to do (reload, post-setup commands), and remaining gaps.
- **If things are still missing**: List remaining missing deps and their impact.

Do NOT re-list things that are already working — only report changes and gaps.
