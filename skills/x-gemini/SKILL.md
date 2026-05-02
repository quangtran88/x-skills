---
name: x-gemini
description: Direct Google Gemini CLI bridge — uses Google Ultra subscription (no API key), native Google Search grounding, and gemini-3.x models without the OpenCode layer
triggers:
  - "gemini cli"
  - "gemini-cli"
  - "ask gemini directly"
  - "use gemini cli"
  - "gemini direct"
  - "google search grounding"
  - "gemini-3.1-pro"
  - "gemini-3-pro"
  - "x-gemini"
matching: fuzzy
---

# x-gemini — Direct Gemini CLI Bridge

## Bootstrap (MANDATORY first step)

Before dispatching, verify `gemini-agent` is on PATH. If missing, the user has not run setup yet (or upgraded without re-running):

```bash
command -v gemini-agent &>/dev/null || {
  echo "gemini-agent not on PATH. Run /x-skills:setup to install the symlink."
  exit 1
}
command -v gemini &>/dev/null || {
  echo "gemini CLI not installed. Install: npm install -g @google/gemini-cli, then run /x-skills:setup"
  exit 1
}
```

If either check fails, instruct the user: **run `/x-skills:setup` inside Claude Code** (do NOT tell them to run `bin/setup` directly — the slash command is the canonical entry point).

---

Wraps the official `gemini` CLI for headless invocation from Claude Code skills. Bypasses OpenCode entirely — no `oh-my-openagent.json`, no plugin compat bugs, no API key. Uses your Google Ultra subscription and Gemini's native Google Search grounding.

**Not a replacement for `x-omo`.** OMO routes to multiple model providers (GPT, Codex, Gemini-via-opencode). x-gemini is the direct path when you specifically need:

- `gemini-3.1-pro-preview` (not always exposed via opencode)
- Native Google Search grounding in the answer
- Workspace `@file` references
- Session resume across invocations
- Lower latency (no opencode plumbing)

## Quick Dispatch

If `{{ARGUMENTS}}` is non-empty, invoke immediately via Bash:

```
/x-gemini "prompt"                              → gemini-agent "prompt"
/x-gemini --model pro "prompt"                  → gemini-agent --model pro "prompt"
/x-gemini --resume "follow-up"                  → gemini-agent --resume "follow-up"
/x-gemini --file /abs/file.md "explain this"    → gemini-agent --file /abs/file.md "explain this"
```

The wrapper lives at `bin/gemini-agent` (symlinked to `~/.local/bin/gemini-agent` by `bin/setup`).

---

## When to Use

| Use Case | Why x-gemini, not x-omo / x-research |
|---|---|
| Need fresh web facts with citations | Gemini has native Google Search; opencode-routed Gemini does not always trigger it |
| Quick factual lookup, want low latency | Skips opencode → gemini routing layer |
| Want `gemini-3.1-pro-preview` specifically | Default opencode config may not expose pro-preview |
| Multi-turn research session | `--resume` keeps conversation context across calls |
| Analyze a workspace file | `@file` reference works for any file under CWD |

## When NOT to Use

| Situation | Use Instead |
|---|---|
| Need GPT/Codex models | `x-omo --model gpt|codex` |
| Need OMO role agent (oracle, explore, librarian) | `x-omo <agent>` |
| Need codebase search across repo | `morph-mcp codebase_search` first, then `x-omo explore` |
| Need to write/edit files | This is a **read-only** advisor; use executor |

---

## Models

| Alias | Resolves To | Best For |
|---|---|---|
| `flash` (default) | `gemini-2.5-flash` | Fast lookups, classification, summaries |
| `pro` | `gemini-3.1-pro-preview` | Reasoning, deep analysis, multimodal |
| Full ID | passthrough | e.g., `gemini-2.5-flash-lite` |

**Architecture note:** Every Gemini call uses TWO models — `gemini-2.5-flash-lite` (utility router that decides tool calls) plus the main responder. Both are billed against your Google Ultra subscription.

---

## Invocation

```bash
# Basic
gemini-agent "Research topic X"

# Specific model
gemini-agent --model pro "Complex reasoning task"

# Custom system prompt (constrains behavior)
gemini-agent --system /path/to/system.md "Analyze this"

# Workspace file
gemini-agent --file ./README.md "Summarize this project"

# Resume last session (multi-turn research)
gemini-agent --resume "Follow-up: how does it differ from approach Y?"

# Streaming for long tasks (JSONL events)
gemini-agent --stream "Deep research with multiple tool calls..."

# Tool execution allowed (plan mode — auto-approves plan tools only)
gemini-agent --approval-mode plan "List files in current dir"

# Autonomous tool execution (yolo mode — no approvals required)
# DANGER: Gemini gets unrestricted shell access. Only use when caller
# explicitly approves. Pattern borrowed from OMC's `omc ask`.
gemini-agent --yolo "Set up the project and run tests"

# Raw text passthrough (skip JSON parsing)
gemini-agent --raw "Plain text response"
```

### Env Vars

| Var | Effect |
|---|---|
| `X_GEMINI_DEFAULT_MODEL` | Default model when `--model` not passed (e.g. `pro`, `flash`) |
| `GEMINI_TIMEOUT` | Override default 600s timeout (seconds) |
| `GEMINI_SYSTEM_MD` | Set internally by `--system` flag — do not set externally |

**Timeout:** Set Bash timeout to **600000** (10 min). Most calls return in 5-30s; `--model pro` with tool use can take 1-3 min.

**Output format:** By default, the wrapper parses Gemini's `--output-format json` and emits only `.response`. Stats (model, tools, session ID) go to stderr.

---

## Output

`stdout`:
```
<gemini's response, plain markdown>
```

`stderr` (last line):
```
[gemini-agent] pro | duration=12s | status=success | model=gemini-3.1-pro-preview | tools=2 | session=<uuid> | raw=/tmp/gemini-agent-...log
```

Capture the session ID from stderr if you want to `--resume` later. The full raw JSON is at the `raw=` path.

---

## Error Handling

| Exit Code | Meaning | Recovery |
|---|---|---|
| `0` | success | continue |
| `1` | generic failure | check raw log |
| `42` | empty prompt (input error) | non-issue, validation |
| `124` | timeout (killed by `timeout` cmd) | shorten prompt or `GEMINI_TIMEOUT=1200 ...` |
| non-zero + log mentions "exhausted/quota" | rate limited | wait or switch to `flash` |
| non-zero + log mentions "auth/sign in" | not logged in | run `gemini` interactively to auth |

## Integration with Other Skills

- **`x-research`** — for general research questions, prefer `x-research` (it routes to morph + librarian + oracle as appropriate). Reach for `x-gemini` only when you specifically need Google Search grounding or `gemini-3.1-pro-preview`.
- **`x-omo`** — `x-gemini` is the **non-opencode** Gemini path. If you need any non-Gemini model, use `x-omo`.
- **`x-do`** — `x-gemini` is read-only / advisor. Hand findings to `x-do` for execution.

## Dependencies

- **`gemini` CLI** (required) — install: https://github.com/google-gemini/gemini-cli; auth via `gemini` interactive (Google account login)
- **`jq`** (required for default JSON mode) — `brew install jq`
- **Google Ultra subscription** (recommended) — quota-friendly access to gemini-3.x

The `bin/setup` script detects all three and writes capability flags to `~/.config/x-skills/capabilities.json`.

## Gotchas

See `gotchas.md` for known failure patterns — update it when you encounter new ones.

Task: {{ARGUMENTS}}
