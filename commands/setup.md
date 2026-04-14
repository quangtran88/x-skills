---
description: "Configure x-skills plugin — sets up omo-agent binding, detects dependencies, and reports skill readiness"
---

# x-skills Setup

Run the setup script to configure the omo-agent binding and detect available capabilities.

## Execution

Run the setup script. The plugin root must be resolved first since the install path is dynamic:

```bash
PLUGIN_DIR="$("$(dirname "$(dirname "$(readlink -f "$(command -v omo-agent 2>/dev/null || echo /dev/null)")")")/bin/find-plugin-dir" 2>/dev/null || "$HOME/x-skills/bin/find-plugin-dir" 2>/dev/null || echo "")"
if [[ -n "$PLUGIN_DIR" && -f "$PLUGIN_DIR/bin/setup" ]]; then
  "$PLUGIN_DIR/bin/setup"
else
  echo "Could not locate x-skills plugin. Trying common locations..."
  for d in "$HOME/x-skills" "$HOME/.claude/plugins/cache"/*/x-skills/*/; do
    [[ -f "$d/bin/setup" ]] && { "$d/bin/setup"; exit 0; }
  done
  echo "ERROR: x-skills plugin not found. Install it first."
fi
```

## After Setup

Read the capabilities manifest and report to the user:

```bash
cat ~/.config/x-skills/capabilities.json 2>/dev/null
```

Summarize:
- **Available**: list detected deps with checkmarks
- **Missing**: list with install instructions:
  - **opencode**: https://github.com/opencode-ai/opencode
  - **oh-my-claudecode**: `/plugin install oh-my-claudecode@omc`
  - **superpowers**: `/plugin install superpowers@superpowers-marketplace`
  - **claude-mem**: `/plugin install claude-mem@thedotmack`
  - **MCP servers**: Configure in `.mcp.json` or Claude Code settings
- **Skill readiness**: which skills are full vs degraded

If this is a first-time setup, suggest testing with:
```
/x-omo explore "what does this project do?"
```
