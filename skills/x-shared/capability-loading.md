# Capability Loading

Single contract for how x-skills routers learn what's available. Borrowed from BMAD-METHOD's manifest pattern + obra/superpowers' bootstrap injection + oh-my-openagent's typed snapshot.

## Principle

**Detect once at setup. Pin at bootstrap. Never re-check per dispatch.**

`bin/setup` writes the manifest. SessionStart hook injects a one-line snapshot. Skills' Bootstrap step reads either source. Routing tables are filtered against the pinned set on entry — no jq calls before each tool dispatch.

## Sources of Truth (precedence high → low)

1. **Project override** — `.x-skills/capabilities.json` in the project root (optional, lets project mute lanes). Project root is resolved as `$CLAUDE_PROJECT_DIR` first, then `git rev-parse --show-toplevel`, then cwd.
2. **User manifest** — `~/.config/x-skills/capabilities.json` (written by `bin/setup`)
3. **Plugin defaults** — empty set, all lanes treated as unavailable, fallback rows used everywhere

Project overrides are **subtractive only**: a project file can disable a capability the user has, but cannot grant new capabilities. This bounds trust — a hostile repo cannot upgrade routing posture by lying. The hook also caps the project file at 16 KiB to prevent SessionStart DoS.

## Schema

```json
{
  "version": "1.0.0",
  "plugin_version": "1.4.0",
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
      "morph": true,
      "gitnexus": true
    },
    "cli": {
      "gitnexus": true
    },
    "plugins": {
      "oh_my_claudecode": true,
      "superpowers": true
    },
    "companion_skills": {
      "ui_ux_pro_max": true,
      "x_skill_review": true
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

`capabilities.*` is the boolean lookup map (skill-friendly), the single canonical source. `version` is the manifest schema version; `plugin_version` mirrors `plugin.json` and drives `check-version.sh` freshness detection.

## Skill Bootstrap Pattern

When a skill needs to dispatch external tools:

1. Look for the most recent `[x-skills/capabilities]` line in the conversation context (injected by SessionStart hook). Parse the comma-separated active set.
2. If absent, read `~/.config/x-skills/capabilities.json` once with jq.
3. The SessionStart hook already merged `.x-skills/capabilities.json` (resolved against the project root, subtractive only). Skills do not need to re-merge — trust the active set in the snapshot line.
4. Filter the skill's routing/fan-out tables against the active set. Drop unavailable lanes silently. Pick fallback row when primary unavailable.
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
