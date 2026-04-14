# Argument Parsing

## Positional Arguments

Args can appear in any order. Flags (`--session`, `--project`) also still work as aliases.

| Argument | Detection | Maps to |
|----------|-----------|---------|
| Skill name | Matches `supported_skills` in config.json | Search query patterns (see search-patterns.md) |
| Project dir | Starts with `/`, `~`, or `.` | `workingDirectory` param in `session_search` |
| Session ID(s) | UUID-like pattern (hex chars + dashes, no `/`) — one or more | `sessionId` param — skip discovery, go direct. Multiple = analyze each then cross-session synthesis |
| `--since <duration>` | Flag-based only | `since` param (e.g., `2d`, `1w`, `2026-03-30`) |

## Resolution Rules

- No skill name + session ID provided → auto-detect skill from session content
- No args → ask which skill, then search

## Direct Targeting

When project dir and/or session ID(s) are provided, pass them through to every `session_search` call (both discovery and deep extraction). When session ID(s) are provided, skip discovery entirely.

## Multiple Sessions

When multiple session IDs are provided, run deep extraction for each session in parallel. Analyze each independently (steps 2-4), then add a cross-session synthesis section to the report highlighting patterns — repeated deviations across sessions carry more weight than one-off issues.
