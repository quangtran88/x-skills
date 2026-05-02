# Capability Loading

Single contract for how x-skills routers learn what's available. Borrowed from BMAD-METHOD's manifest pattern + obra/superpowers' bootstrap injection + oh-my-openagent's typed snapshot.

## Principle

**Detect once at setup. Pin at bootstrap. Never re-check per dispatch.**

`bin/setup` writes the manifest. SessionStart hook injects a one-line snapshot. Skills' Bootstrap step reads either source. Routing tables are filtered against the pinned set on entry — no jq calls before each tool dispatch.

## Sources of Truth (precedence high → low)

1. **Project override** — `.x-skills/capabilities.json` in repo root (optional, lets project mute lanes)
2. **User manifest** — `~/.config/x-skills/capabilities.json` (written by `bin/setup`)
3. **Plugin defaults** — empty set, all lanes treated as unavailable, fallback rows used everywhere

Skills MUST merge in this order. Project value wins over user value. Missing key = inherit from lower tier.

## Schema

```json
{
  "version": "1.0.0",
  "generated_at": "ISO-8601",
  "plugin_dir": "/abs/path",
  "omo_agent": "/abs/path/bin/omo-agent",
  "capabilities": {
    "opencode": true,
    "omo_plugin": "partial|full|false",
    "omo_mode_all": true,
    "gemini_cli": true,
    "mcp": {
      "perplexity": true,
      "deepwiki": true,
      "exa": true,
      "context7": true,
      "morph": true
    },
    "plugins": {
      "oh_my_claudecode": true,
      "superpowers": true,
      "claude_mem": true
    },
    "security_tools": {
      "schemathesis": true,
      "nuclei": true,
      "sqlmap": true,
      "spectral": true,
      "interactsh": false
    }
  },
  "dependencies": [
    { "name": "gemini", "required": false, "installed": true, "version": "0.5.0", "path": "/usr/local/bin/gemini" }
  ]
}
```

`capabilities.*` is the boolean lookup map (skill-friendly). `dependencies[]` is the typed audit trail (mirrors omo's `DependencyInfo`). Both written by setup; either is canonical.

## Skill Bootstrap Pattern

When a skill needs to dispatch external tools:

1. Look for the most recent `[x-skills/capabilities]` line in the conversation context (injected by SessionStart hook). Parse the comma-separated active set.
2. If absent, read `~/.config/x-skills/capabilities.json` once with jq.
3. Merge `.x-skills/capabilities.json` if present in current working dir.
4. Filter the skill's routing/fan-out tables against the merged set. Drop unavailable lanes silently. Pick fallback row when primary unavailable.
5. **Do not re-check the manifest per dispatch.** Trust the pinned set for the session.

## Drift Handling

A tool errors at runtime despite being marked available = setup drift (CLI uninstalled, MCP server stopped, etc). Skill MUST:

1. Surface the error with one line: `[x-skills] <tool> failed despite capability pin. Re-run: ./bin/setup --check`
2. Pick the next fallback row in the routing table for the current dispatch.
3. Continue the session — do not re-snapshot mid-session (other lanes may have already used the stale set).

## Opt-Out

User can mute a capability without uninstalling the underlying tool by editing `.x-skills/capabilities.json`:

```json
{ "capabilities": { "mcp": { "perplexity": false } } }
```

Project override > user manifest. Useful for cost control (mute `perplexity_research`), CI environments (mute interactive tools), or testing fallback paths.
