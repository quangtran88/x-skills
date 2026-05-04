# x-gemini — Gemini Bridge

> **Purpose:** Direct Google Gemini CLI bridge — bypasses OpenCode entirely, uses Google Ultra subscription (no API key), native Google Search grounding.

---

## When to Use

| Use Case | Why x-gemini, not x-omo / x-research |
|----------|-------------------------------------|
| Need fresh web facts with citations | Gemini has native Google Search |
| Quick factual lookup, want low latency | Skips opencode routing layer |
| Want `gemini-3.1-pro-preview` specifically | Default opencode config may not expose it |
| Multi-turn research session | `--resume` keeps conversation context |
| Analyze a workspace file | `@file` reference works for any file under CWD |

---

## Models

| Alias | Resolves To | Best For |
|-------|-------------|----------|
| `flash` (default) | `gemini-2.5-flash` | Fast lookups, classification, summaries |
| `pro` | `gemini-3.1-pro-preview` | Reasoning, deep analysis, multimodal |

---

## Invocation Patterns

```bash
gemini-agent "Research topic X"
gemini-agent --model pro "Complex reasoning task"
gemini-agent --file ./README.md "Summarize this project"
gemini-agent --resume "Follow-up: how does it differ from approach Y?"
```

---

## Dependencies

- `gemini` CLI (required) — https://github.com/google-gemini/gemini-cli
- `timeout` (required) — `brew install coreutils`
- `jq` (required for JSON mode) — `brew install jq`
- Google Ultra subscription (recommended)
