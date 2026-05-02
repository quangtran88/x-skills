# Session Discovery & Extraction

## Discovery Search

See `search-patterns.md` for per-skill query patterns. Run all variants in parallel. Use `contextChars: 500`, `limit: 10` for discovery.

### Present Matches

- If multiple sessions match, show a numbered list: session ID, date, excerpt
- Let the user pick which to analyze
- If exactly one match, confirm and proceed
- If no matches found, use the **fallback ladder**:
  1. **JSONL-direct:** Read `~/.claude/projects/<project-key>/<sessionId>.jsonl` via Bash (grep for skill invocations, tool calls, key decisions). This is the most reliable fallback — session_search indexing can lag or miss sessions entirely.
  2. **Paste:** If JSONL file doesn't exist, offer: "No session data found. You can paste a transcript instead."

## Deep Extraction

Once a session is selected, run targeted searches within it (`sessionId` param) for:
- Skill invocation and mode/type detection
- Key decision points (plan review, agent dispatch, verification)
- Deviations or workarounds
- Error messages or retries

Use `contextChars: 1000` for deep extraction to capture full decision context. These params apply to `session_search` only — if using JSONL-direct fallback, use `grep` with targeted patterns instead.
