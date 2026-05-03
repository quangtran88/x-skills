# x-gemini gotchas

## stderr corrupts JSON if not redirected

Gemini CLI prints `Ripgrep is not available. Falling back to GrepTool.` (and similar) to **stderr**. If you merge stderr into stdout (`2>&1`), it corrupts the JSON output.

**The wrapper handles this** — it always uses `2>/dev/null`. If you call `gemini` directly, always redirect.

```bash
# WRONG — JSON parser will choke
gemini -p "..." --output-format json

# RIGHT
gemini -p "..." --output-format json 2>/dev/null
```

## Dual-model billing

Every call uses **two** models:

- `gemini-2.5-flash-lite` — utility router (decides tool calls, cheap)
- `gemini-3.x` (or whatever `-m` selects) — main responder

The wrapper's stderr summary reports the main model. If you check `.stats.models` in raw JSON, expect two entries.

## Quota exhaustion mid-stream

Streaming mode can hit `You have exhausted your capacity on this model. Your quota will reset after 0s.. Retrying after 5266ms...`. Built-in auto-retry usually recovers within seconds.

If you see repeated quota errors:
- Drop to `flash` (cheaper, higher quota)
- Wait — quotas reset on 1-min / 1-hour windows depending on model
- Don't loop the wrapper expecting it to back off — it doesn't

## @file restricted to workspace

`@/path/to/file` only resolves files under the current workspace (CWD or `--include-directories`). Files outside return a graceful error, not a crash, but the model never sees them.

**Workaround:** copy the file into CWD first, or `cd` to its parent before invoking.

## Workspace = current working directory

Gemini's "workspace" defaults to wherever you launch the CLI. If your prompt references `@README.md`, that resolves to `$(pwd)/README.md`. The wrapper does not change CWD — caller is responsible.

## Empty prompt → exit 42

Gemini exits **42** (input error), not the usual 1, on empty prompts. The wrapper validates this upfront, but if you bypass the wrapper and `gemini -p ""`, expect 42.

## Session resume requires same workspace

`-r latest` resumes the most recent session **for the current workspace**. Switching directories silently starts a new session even with `-r latest`. To resume across dirs, capture the session UUID from the `[gemini-agent]` stderr line and pass it via `--resume <uuid>`.

## `--model pro` is the slow path

`gemini-3.1-pro-preview` is significantly slower than `flash`. Budget 30-180s for non-trivial prompts. Use `flash` for quick lookups, escalate to `pro` only for reasoning-heavy work.

## Output truncation at 50k chars

The wrapper truncates `.response` to the **last** 50k characters (≈12.5k tokens) if longer. The full raw JSON stays in the log file (`raw=` path on the stderr summary). If you need the full response programmatically, read that path.

## Logs persist the full prompt + response (may contain secrets)

By default the wrapper writes the raw response (which includes the prompt Gemini received) to `~/.cache/x-skills/gemini/gemini-agent-<ts>-<label>.log` with mode `0600`. If you paste secrets into a prompt (API keys in stack traces, credentials in error output), they end up in that log. Override with:

- `X_GEMINI_NO_LOG=1` — disable logging entirely
- `X_GEMINI_LOG_PROJECT=1` — write into `.omc/artifacts/x-gemini/` (project-local, opt-in only). Make sure `.omc/` is gitignored before enabling.

## No tool execution by default

Default approval mode is read-only — Gemini cannot run shell commands or write files. Pass `--approval-mode plan` to allow tool use. Never use `--approval-mode auto` from the wrapper without explicit user consent — it gives Gemini unrestricted shell access.

## Native Google Search vs opencode-routed Gemini

Direct `gemini` CLI triggers Google Search grounding for current-events queries. The same model called via `opencode --model gemini-pro` does **not** always trigger search — opencode's tool routing differs. If you need fresh web facts with citations, use `x-gemini` not `x-omo --model gemini-pro`.

## Claude session env vars stripped before invocation

The wrapper unsets `CLAUDECODE`, `CLAUDE_SESSION_ID`, `CLAUDECODE_SESSION_ID`, and `CLAUDE_CODE_ENTRYPOINT` before spawning `gemini`. This prevents Gemini from inheriting the Claude session ID or thinking it's running inside Claude Code.

If you need any of these vars inside Gemini for some reason, the wrapper does not provide a passthrough — modify the wrapper or call `gemini` directly.

## `--yolo` flag is autonomous tool execution

`--yolo` (alias for `--approval-mode yolo`) lets Gemini execute shell commands and write files without per-call approval. Equivalent to OMC's default for `omc ask`. **The wrapper defaults to read-only** — `--yolo` is opt-in only. Reasoning: a wrapper that grants shell access by default is a footgun. Callers must consciously opt in.

## Artifacts dir defaults to user cache

Raw JSON logs default to `~/.cache/x-skills/gemini/` (mode 0600, user-private). Set `X_GEMINI_LOG_PROJECT=1` to opt into the legacy `.omc/artifacts/x-gemini/` location. Set `X_GEMINI_NO_LOG=1` to disable logging entirely. The stderr summary's `raw=` field shows the actual path used (or `(disabled)`).

## Auth: Google login, not API key

`gemini` uses OAuth against your Google account (Ultra subscription recommended). There is **no `GEMINI_API_KEY` env var** for the CLI in this configuration. If you see "auth" / "sign in" errors, run `gemini` interactively once to complete the OAuth flow.
