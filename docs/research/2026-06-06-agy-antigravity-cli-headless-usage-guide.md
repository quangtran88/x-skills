# Using `agy` (Antigravity CLI) Effectively — Headless Usage Guide

> Research date: **2026-06-06** · Binary probed: **agy v1.0.6** (`~/.local/bin/agy`, 138 MB, rebuilt today) · Repo: `google-antigravity/antigravity-cli` (closed-source binary; 890★, 266 open issues, pushed 2026-06-06)
> Purpose: ground the planned `bin/agy-agent` wrapper (see `[[project-x-gemini-agy-migration]]`) in **verified** facts, not LLM extrapolation.

## Source-reliability note (read first)

agy has **no public granular docs**. The official site (antigravity.google/docs) is a JS-SPA that can't be scraped; the GitHub repo is changelog + README + TUI examples only; DeepWiki has overview text only; a `perplexity_research` lane **timed out at 240s**; and a Google-grounded `gemini-agent` lane **hallucinated non-existent flags** (`--json`, `--grounding`, `--output-format`, exit codes `429`/`130`, `.antigravityignore`). Every one of those was **refuted directly against the binary**. → **Trust order: the installed binary + live behavior tests + the embedded `agy changelog` > everything else.** Anything below marked "⚠ unverified" was not confirmable against ground truth.

---

## 1. Headless invocation (VERIFIED via `agy --help` + live runs)

```bash
agy -p "<prompt>"                         # --print: one-shot, prints response to stdout, then exits
agy --model "<name>" -p "<prompt>"        # per-call model selection (added in 1.0.5)
agy --add-dir <path> -p "<prompt>"        # mount a directory into the workspace (repeatable)
agy -c -p "<follow-up>"                   # --continue most recent conversation
agy --conversation <id> -p "<follow-up>"  # resume a specific conversation by id
agy --print-timeout <dur> -p "<prompt>"   # wait cap for print mode (default 5m0s, e.g. 120s)
agy --sandbox -p "<prompt>"               # terminal restrictions (now propagates in -p as of 1.0.6)
agy --dangerously-skip-permissions -p ... # auto-approve ALL tool/edit confirmations (YOLO)
agy --log-file <path> -p "<prompt>"       # override CLI log path
```

- **There is NO structured/JSON output.** Print mode emits **markdown/plain text only**. `--json` / `--output-format` do **not exist** (refuted: `flags provided but not defined: -json`). Any downstream parser must consume plain text.
- **Output chrome is prompt-controlled.** With a normal prompt agy may append a `### Work Summary` block; an explicit "Output ONLY the list, no preamble or summary" suppresses it (live-verified). A wrapper must either instruct-to-suppress or strip trailing chrome.
- **Permission hang is conditional, not universal.** Pure text/Q&A in `-p` returns fine **without** `--dangerously-skip-permissions` (live-verified). Read-only tools (Google Search, file reads via `--add-dir`) also auto-run. The hang risk is only when the agent wants **shell exec or file edits** in a non-TTY → it blocks forever on a hidden Y/N. For a read-only advisor wrapper, do **not** pass `--dangerously-skip-permissions`; for autonomous build/test tasks, you must.

## 2. Models (VERIFIED via `agy models`)

```
Gemini 3.5 Flash (Medium|High|Low)     # fast tier; "Medium" is the practical default
Gemini 3.1 Pro (Low|High)              # reasoning tier
Claude Sonnet 4.6 (Thinking)           # cross-provider — not available in bare gemini CLI
Claude Opus 4.6 (Thinking)
GPT-OSS 120B (Medium)
```

- The thinking level is **baked into the model string** (e.g. `"Gemini 3.5 Flash (Low)"`), not a separate flag. This *is* the headless determinism/latency knob — pick the level by choosing the string.
- Pass the **exact display string** to `--model` (quote it). Default model for headless = the `model` key in settings.json (§4).
- Cross-provider menu (Claude + GPT-OSS) is a genuine advantage over the bare `gemini` CLI.

## 3. Google Search grounding + browser (VERIFIED live + binary protobuf)

- Grounding is **prompt/agent-driven, NOT a flag** (`--grounding` refuted). Including "Use Google Search" / "Use web search" in the prompt triggers it; the model also self-elects when the question needs fresh facts. Live test returned a correctly cited answer (Bun v1.3.14, source URLs).
- The binary embeds a first-class `GoogleSearch` tool (`google_search` protobuf field) **and a full CDP/Chrome browser** (`cdp.Browser`, `BROWSER_OPEN`, `web_search_url`, `browser_page/text`) — so agy can *browse and scrape pages*, not just hit the Search grounding API. Richer than gemini CLI's search-only grounding.
- Cost of grounding: latency. Grounded flash-medium took **105s** vs the gemini wrapper's **29s** on the same query (one sample).

## 4. settings.json (`~/.gemini/antigravity-cli/settings.json`) — keys VERIFIED from binary strings + changelog

```jsonc
{
  "model": "Gemini 3.5 Flash (Medium)",   // default model for headless runs — set this to avoid relying on --model
  "colorScheme": "dark",                   // set/strip ANSI when parsing stdout
  "statusLine": { "type": "", "command": "", "enabled": true, "stack_with_default": false },
  "trustedWorkspaces": ["/abs/path", ...], // dirs agy trusts without the trust prompt — REQUIRED for non-interactive use
  "mcpServers": { ... },                   // inline MCP block — key present in binary; relationship to config/mcp_config.json (§5) is ⚠ unverified (both exist; precedence untested)
  "hooks": { ... },                        // hooks key present in binary; ⚠ exact schema/semantics unverified
  "UseG1Credits": true                     // overflow to Google One (G1) credits when Ultra quota is exhausted (1.0.3)
}
```

- **`trustedWorkspaces` is the load-bearing one for automation** — agy prompts to "trust" an unknown workspace interactively; pre-seeding the path (or `--skip-trust` in the bare gemini equivalent) avoids a hang. This machine already trusts `~`, `~/Codes/x-skills`, `~/Codes/oneclaw`.
- Permissions are now a merged system (1.0.5 `/permissions`): CLI `settings.json` + user settings shared with Antigravity GUI + project-level. ⚠ exact `permissions` sub-schema unverified.

## 5. MCP servers — `~/.gemini/config/mcp_config.json` (DISK-VERIFIED)

- **Confirmed on disk:** the live CLI MCP config is `~/.gemini/config/mcp_config.json` (296 B, present). There is **no** `~/.gemini/antigravity-cli/config/` dir — the `config/mcp_config.json` the changelog refers to is the shared `~/.gemini/config/` tree, not an agy-local one. (The GUI variants keep their own copies at `~/.gemini/antigravity{,-ide,-backup}/mcp_config.json`; agy CLI runtime state is separate under `~/.gemini/antigravity-cli/mcp/`.)
- Path migrated to `config/mcp_config.json` (changelog 1.0.3: writing to the legacy bare path silently no-ops). Supports **stdio** servers (`command`/`args`) and, since 1.0.5, **`url`** remote/SSE servers. Parallel init since 1.0.4.

## 6. Plugins / skills / agents (changelog 1.0.1/1.0.2 + `agy plugin --help`)

```bash
agy plugin import gemini   # non-destructively port gemini-cli plugins/extensions/MCP/themes
agy plugin import claude   # same for claude
agy plugin install <name>@<marketplace>   # marketplace install
agy plugin list | enable <n> | disable <n> | uninstall <n> | validate [path]
```

- Installed plugins/skills live in the **shared** `~/.gemini/config/` (1.0.2 fix — *not* `~/.gemini/antigravity-cli/plugins/`, which the hallucinated guide claimed). **DISK-VERIFIED:** `~/.gemini/config/skills/` exists with ~924 entries (each a skill directory, e.g. `wordpress-plugin-development/`); this is the same shared tree gemini-cli uses.
- agy auto-discovers **skills and specialized subagents** from installed plugin dirs (1.0.1) and supports fallback skill discovery in standalone mode (1.0.2). ⚠ The authoring **format** ("Markdown SKILL.md blueprint") came from the unreliable web lane and is **unverified** — only the *directory location* above is confirmed. The `agy plugin import gemini` reply on this machine was "No gemini extensions found", i.e. it imports gemini-cli *extensions/skills*, not the gemini binary/flags.
- **Note:** since agy imports gemini-cli & claude plugins/skills, x-skills' own skills could in principle be surfaced to agy — worth a follow-up probe if we ever want agy to run x-skills natively.

## 7. Conversations / resume (changelog 1.0.4)

- Conversation store is **SQLite** (`.db` / `.db-wal`, changelog 1.0.4) under **`~/.gemini/antigravity-cli/conversations/`** (DISK-VERIFIED: dir present with ~23 entries). Print-mode metadata writes to `~/.gemini/antigravity-cli/cache` (1.0.5 fix — previously polluted CWD). Logs at `~/.gemini/antigravity-cli/log/` (symlinked as `cli.log`).
- Resume the latest with `-c`; resume a specific id with `--conversation <id>`. Subagent conversations are excluded from the `/resume` picker (1.0.6). ⚠ how to *capture* the conversation id from a headless `-p` run is unverified (bare gemini prints a session UUID; agy's headless id surfacing is unconfirmed — likely needs reading the SQLite store or log).

## 8. Auth & quota

- OAuth via system keyring → Google Sign-In fallback (README). No `GEMINI_API_KEY`-style env for the consumer path. Enterprise = connect a GCP project / Gemini Code Assist license during onboarding.
- This machine: `~/.gemini/antigravity-cli/cache/onboarding.json` shows `consumerOnboardingComplete` **and** `enterpriseOnboardingComplete` = true → headless runs work without re-auth. **⚠ Caveat:** because enterprise onboarding is complete here, the live latency/success numbers in this doc may draw on **enterprise (Gemini Code Assist) quota**, not the **Ultra-only** path the migration actually targets. An Ultra-only user could see different quota/rate-limit behavior — re-benchmark on an Ultra-only profile before trusting these figures for the consumer case.
- **G1 credit overflow** (`UseG1Credits: true`): when the weekly Ultra quota is exhausted, agy falls back to Google One AI credits instead of hard-failing — directly relevant to headless reliability. `/usage` `/quota` `/credits` are interactive-only.
- Strategic context: the bare `gemini` CLI stops serving Ultra/Pro/free on **2026-06-18**; agy is the successor (`[[project-x-gemini-agy-migration]]`). Enterprise onboarding here means agy is not dependent on the dying Ultra-serving path.

## 9. Error handling in headless mode (VERIFIED behavior + prior-session finding)

- Success exits **0** with the response on stdout (verified). The hallucinated `429`/`130` exit codes are **not** real (`--bogus` control proves undefined-flag handling; no evidence of HTTP-style exit codes).
- **agy historically returns exit 0 even on failures** (prior session: exit 0 on "invalid project ID" / "not authenticated"). → **Do not rely on exit codes for failure detection.** A robust wrapper must: (a) treat **empty/whitespace stdout** as failure, and (b) tail `--log-file` for `auth` / `quota` / `PlannerResponse` / `panic` markers. This is the single biggest wrapper-hardening requirement.
- One transient empty-stream failure was observed on the *bare gemini* path (`-m gemini-2.5-flash`), not agy — but the empty-output failure mode exists on both; the wrapper's empty-stdout guard covers it.

## 10. Gotchas for headless / CI

1. **No JSON** → parse plain text; strip ANSI (`colorScheme`) and any trailing `### Work Summary` chrome.
2. **Exit 0 lies** → gate on empty-stdout + log-tail, never exit code (§9).
3. **Trust prompt** → pre-seed `trustedWorkspaces` or the run hangs on first use of an untrusted dir.
4. **Permission hang** → only when the agent wants shell/edit in non-TTY; pass `--dangerously-skip-permissions` for autonomous tasks, omit it for read-only advisory.
5. **Latency** → grounded/agentic flash runs are 3–5× the gemini wrapper (105–146s vs 29s, small N). Budget `--print-timeout` accordingly; route bulk/no-tool work to a `(Low)` model.
6. **Scope creep** → with the whole repo trusted, agy ranged *beyond* `--add-dir` into other dirs during a review (live-observed). Constrain via prompt + a minimal trusted set if scope matters.
7. **Fast-moving target** → 266 open issues, binary rebuilt the same day; pin behavior with live smoke tests, don't assume changelog == current.

## 11. Implications for `bin/agy-agent` (the payoff)

A drop-in-shaped wrapper is feasible but must rebuild what the JSON path gave gemini:

| gemini-agent feature | agy equivalent | wrapper work |
|---|---|---|
| `.response` extraction | plain stdout | trivial (use stdout) — but strip chrome |
| stats / session-id / thoughts-answer counts (JSON) | none | **drop**; lose thinking-starvation telemetry |
| thinking-starvation mitigation (`thinkingLevel` in settings) | model string `(Low/Medium/High)` | re-express as model-alias map |
| `--model flash/pro` | `--model "Gemini 3.5 Flash (Medium)"` / `"Gemini 3.1 Pro (High)"` | alias map |
| `--system <file>` | none (uses plugin/skill model) | **gap** — emulate by prepending to prompt |
| `--file` inline `@file` | `--add-dir <dir>` | switch to dir mount |
| exit-code error classes | exit 0 always | **rebuild**: empty-stdout + log-tail parser |
| `--resume` (gemini `-r latest`) | `-c` / `--conversation <id>` | map; solve id capture (§7) |
| Google Search grounding | prompt-driven (no flag) | inject "Use Google Search" when grounding wanted |

**Recommended wrapper shape:** dual-track behind capability flag `agy_cli` (keep `gemini-agent` default until 2026-06-18), model-alias map (`flash`→`Gemini 3.5 Flash (Medium)`, `flash-low`→`(Low)`, `pro`→`Gemini 3.1 Pro (High)`, plus optional `claude`/`gpt-oss`), empty-stdout+log-tail failure detection, chrome-stripping, `trustedWorkspaces` preflight, and `--system` emulated via prompt prepend.

> **Side-fix for the *existing* gemini wrapper (independent of agy):** `skills/x-gemini/SKILL.md`'s Models table is stale on **both** aliases. Observed live: `gemini-agent --model flash` AND `--model pro` both resolved to `model=gemini-3-flash-preview` (stderr), and an explicit `-m gemini-2.5-flash` *failed* (empty stream). So `flash → gemini-2.5-flash` and `pro → gemini-3.1-pro-preview` no longer match reality — Gemini 3 model IDs have shifted and `pro` may be silently downgrading to flash. Re-pin both aliases (and verify `pro` actually serves a Pro-tier model) before relying on the gemini path in its remaining ~12 days.

---

### Appendix — claims REFUTED against ground truth (do not re-trust)
- `--json` / `--output-format` flag — **does not exist** (no structured output).
- `--grounding` flag — **does not exist** (grounding is prompt-driven).
- exit codes `429` / `130` — **not real**; agy exits 0 even on failure.
- `.antigravityignore` file, `verbosity` setting — **unconfirmed**, no binary/changelog evidence.
- plugins in `~/.gemini/antigravity-cli/plugins/` — **wrong**; they live in `~/.gemini/config/`.
- "Minimal" thinking level for Flash — `agy models` lists only Low/Medium/High for Flash.
