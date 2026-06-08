---
name: x-gemini
description: Direct Google Gemini CLI bridge — uses Google Ultra subscription (no API key), native Google Search grounding, and gemini-3.x models without the OpenCode layer
triggers:
  - "x-gemini"
  - "ask gemini directly"
  - "gemini-3.1-pro"
matching: fuzzy
---

# x-gemini — Direct Gemini CLI Bridge

## Bootstrap (MANDATORY first step)

0. Pin capabilities for the session per `../x-shared/capability-loading.md`. The `agy_cli` flag gates this skill.
1. If `agy-agent` or `agy` is not on PATH, instruct the user: **run `/x-skills:setup` inside Claude Code**. Do not tell them to run `bin/setup` directly — the slash command is the canonical entry point.

---

Wraps the official `agy` (Antigravity) CLI for headless invocation from Claude Code skills. Bypasses OpenCode entirely — no `oh-my-openagent.json`, no plugin compat bugs, no API key. Uses your Google Ultra subscription and prompt-driven Google Search grounding.

## Quick Dispatch

If `{{ARGUMENTS}}` is non-empty, invoke immediately via Bash:

```
/x-gemini "prompt"                              → agy-agent "prompt"
/x-gemini --model pro "prompt"                  → agy-agent --model pro "prompt"
/x-gemini --resume "follow-up"                  → agy-agent --resume "follow-up"
/x-gemini --add-dir /abs/dir "explain this"     → agy-agent --add-dir /abs/dir "explain this"
/x-gemini --grounded "latest version of X?"     → agy-agent --grounded "latest version of X?"
```

The wrapper lives at `bin/agy-agent` (symlinked to `~/.local/bin/agy-agent` by `bin/setup`).

---

## When to Use

| Use Case | Why x-gemini, not x-omo / x-research |
|---|---|
| Need fresh web facts with citations | `--grounded` triggers Google Search; opencode-routed Gemini does not always trigger it |
| Quick factual lookup, want low latency | Skips the opencode → gemini routing layer |
| Want `Gemini 3.1 Pro` specifically | Default opencode config may not expose the agy pro tier |
| Multi-turn research session | `--resume` keeps conversation context across calls |
| Analyze a workspace dir | `--add-dir DIR` mounts a scoped subtree into the workspace |
| Cross-provider models | agy also serves Claude (`claude-sonnet`/`claude-opus`) and `gpt-oss` — opencode-free |

## When NOT to Use

| Situation | Use Instead |
|---|---|
| Need GPT/Codex models | `x-omo --model gpt|codex` |
| Need OMO role agent (oracle, explore, librarian) | `x-omo <agent>` |
| Need codebase search across repo | native `Grep` (or OMO `explore` for semantic) first, then `x-omo explore` |
| Need to write/edit files | This is a **read-only** advisor; use executor |

---

## Models

| Alias | agy model (display string) | Best For |
|---|---|---|
| `flash` (default) | `Gemini 3.5 Flash (Medium)` | Fast lookups, classification, summaries |
| `flash-low` / `flash-high` | `Gemini 3.5 Flash (Low)` / `(High)` | bulk / harder fast-tier |
| `pro` | `Gemini 3.1 Pro (High)` | Reasoning, deep analysis |
| `pro-low` | `Gemini 3.1 Pro (Low)` | cheaper reasoning |
| `claude-sonnet` / `claude-opus` | `Claude Sonnet 4.6 (Thinking)` / `Claude Opus 4.6 (Thinking)` | cross-provider (agy-only advantage) |
| `gpt-oss` | `GPT-OSS 120B (Medium)` | cross-provider |

**Note:** agy is **plain-text only** (no JSON surface). The wrapper **synthesizes a real exit code** (agy exits 0 even on failure). Pass `--grounded` — it is **required** for "what's current / latest version" questions; without it agy trusts the repo over live docs and returns stale identifiers.

---

## Invocation

```bash
# Basic
agy-agent "Research topic X"

# Specific model
agy-agent --model pro "Complex reasoning task"

# Custom system prompt (prepended to the prompt to constrain behavior)
agy-agent --system /path/to/system.md "Analyze this"

# Mount a scoped workspace dir (replaces the old per-file attach)
agy-agent --add-dir ./src/feature "Summarize this module"

# Grounded lookup — REQUIRED for "what's current / latest version" questions
agy-agent --grounded "Latest stable version of X? cite URLs"

# Resume last conversation (multi-turn research)
agy-agent --resume "Follow-up: how does it differ from approach Y?"

# Resume a specific conversation by id
agy-agent --conversation <id> "Continue from there"

# Autonomous tool execution (yolo mode — no approvals required)
# DANGER: agy gets unrestricted shell access. Only use when caller
# explicitly approves.
agy-agent --yolo "Set up the project and run tests"

# Raw passthrough (skip the optional Work Summary chrome strip)
agy-agent --raw "Plain text response"
```

### Env Vars

| Var | Effect |
|---|---|
| `X_AGY_DEFAULT_MODEL` | Default model alias when `--model` not passed (e.g. `pro`, `flash`) |
| `AGY_TIMEOUT` | Override default 600s timeout (seconds) |
| `X_AGY_AUTO_TRUST` | `=1` auto-appends CWD to `trustedWorkspaces` (avoids trust-prompt hang) |
| `X_AGY_STRIP_SUMMARY` | `=1` strips a trailing `### Work Summary` chrome block from the response |
| `X_AGY_NO_LOG` | `=1` disables persisting the raw log |

**Timeout:** Set Bash timeout to **600000** (10 min). A single scoped grounded call returns in ~80s; bulk/`pro` work runs longer. agy buffers output to the end — never set a short timeout, it truncates to 0 bytes.

**Output format:** agy is **plain text only** — there is no JSON/structured-output surface. The wrapper emits the text directly to stdout; stats (model, duration, status) go to stderr.

---

## Output

`stdout`:
```
<agy's response, plain text / markdown>
```

`stderr` (last line):
```
[agy-agent] pro | duration=79s | status=success | log=~/.cache/x-skills/agy/agy-agent-...log
```

Use `--resume` (latest conversation) or `--conversation <id>` for multi-turn. The persisted run log is at the `log=` path.

---

## Error Handling

agy itself exits **0 even on failure**. The wrapper re-derives a real exit code from empty stdout + the noise-stripped `--log-file` tail — trust the wrapper's code, not agy's.

| Exit Code | Meaning | Recovery |
|---|---|---|
| `0` | success | continue |
| `1` | empty output / `auth_error` / `empty_output` / `planner_empty` | check `log=` path; for auth run `agy` interactively |
| `124` | timeout (killed by `timeout` cmd) | raise `AGY_TIMEOUT=1200 ...`; never lower it (truncates to 0 bytes) |
| `1` + status=`quota_error` | rate limited | wait or switch to `flash-low` |

> The log always contains `not logged into Antigravity` / `failed to set auth token` (auxiliary caches) even on success — that is **noise**, not an auth failure. The wrapper's `status=` is the signal.

## Dependencies

- **`agy` CLI** (required) — install: https://antigravity.google/cli; auth via `agy` interactive (Google account login)
- **`timeout`** (required) — `brew install coreutils` on macOS, or use `gtimeout`
- **`jq`** (recommended) — `brew install jq` (used by the `trustedWorkspaces` preflight)
- **Google Ultra subscription** (recommended) — quota-friendly access

`bin/setup` detects all of these and writes capability flags to `~/.config/x-skills/capabilities.json`.

## Gotchas

See `gotchas.md` for known failure patterns — update it when you encounter new ones.

Task: {{ARGUMENTS}}
