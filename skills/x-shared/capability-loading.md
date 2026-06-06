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
      "gitnexus": true,
      "agentmemory": true
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

## Shared GitNexus Indexed+Fresh Probe (session-pinned, derived state — F3)

This is the single canonical definition of the indexed+fresh signal that **x-research, x-do, and x-review all consume identically** from their Bootstrap. It is NOT a `bin/setup` capability — it is a runtime-derived session pin. The later Bootstrap-consumption edits in those three skills (US-003/004/005) reference this section; they do not redefine the derivation.

### Capability key vs. derived probe (do not conflate)

Two distinct things, deliberately separate:

- `mcp.gitnexus` — a **boolean capability key**. Lives in `~/.config/x-skills/capabilities.json`, written by `bin/setup`, pinned in the bootstrap-active set. Answers "is the gitnexus MCP server available?"
- The **indexed+fresh probe result** — a **runtime-derived session state**. Built from a live `gitnexus list` call. Answers "which repos are indexed, and is each one's index fresh?" It is **NOT** a `bin/setup` capability key and **does NOT appear in `~/.config/x-skills/capabilities.json`** under any name.

The probe is *gated by* `mcp.gitnexus` being pinned, but is itself a separate derived artifact with its own session pin.

### Derivation (run once, then session-pinned)

At the first Bootstrap (across x-research / x-do / x-review) that needs the signal in a session:

1. **Gate:** `mcp.gitnexus` must be in the bootstrap-active set. If it is not, **skip entirely** — see the no-op note below.
2. Make one read-only `gitnexus list` call (the `list_repos` MCP response — `mcp__gitnexus__list_repos` in Claude Code). Never call `gitnexus analyze`/index from this probe; it is read-only.
3. Parse the returned array of repo objects into a derived, session-pinned record:
   - **(a) indexed-path set** — the set of indexed repo paths reported by the response.
   - **(b) per-repo freshness** — for each indexed repo, its `staleness.commitsBehind`.
4. Pin this record for the rest of the session. **It runs exactly once.** x-research, x-do (Depth Calibration grounding), and x-review (step-01 enrichment) all read this single pinned record — **none re-probes per dispatch, and none runs its own independent `gitnexus list`.**

This mirrors the established parse idiom in `skills/x-api-pentest/steps/step-01-recon.md:104` ("`gitnexus list` reports `SOURCE_REPO` as indexed" — gated on `mcp.gitnexus` in the bootstrap-active set, membership read from the `gitnexus list` response). This section is the shared/session-pinned generalization of that per-step check.

### Observed `gitnexus list` shape (live-captured this session, cite — do not guess)

The `list_repos` response is an array of repo objects. Confirmed live via `mcp__gitnexus__list_repos` and matching the source citation `gitnexus/src/mcp/local/local-backend.ts:536, 578-579` (`StalenessInfo { isStale, commitsBehind, hint? }`):

- A **stale** repo object includes `"staleness": { "commitsBehind": <number>, "hint": "<string>" }`. Observed: the `x-skills` entry carried `staleness.commitsBehind = 23`.
- A **fresh** repo object has **no `staleness` key at all**. Observed: the `openclaw` entry had no `staleness` key.

### Freshness semantics (C3)

Per inviolable constraint **C3**:

- `staleness` key **ABSENT** OR `commitsBehind === 0` ⇒ **fresh**.
- `staleness` key **present** with `commitsBehind > 0` ⇒ **stale** (`commitsBehind` is the staleness magnitude).

The probe yields BOTH indexed-set membership AND freshness from this one response — consumers do not hunt per-response keys. Use-class asymmetry (correctness-sensitive consumers **hard-degrade to fallback** on stale; advisory consumers **proceed with a one-line staleness note**) is defined once in C3 and the `mcp-toolbox.md` GitNexus use-class index — this section does not redefine it; consumers resolve a tool's class there.

### Unpinned no-op (regression guard)

**With `mcp.gitnexus` NOT pinned in the bootstrap-active set, this probe is a no-op** — it is never run, nothing is derived or pinned, and consumers fall straight to their fallback rows. Non-gitnexus sessions have **zero behavior change**; the probe adds no calls and no branching on those paths.

## Shared agentmemory.server_up Probe (session-pinned, derived state)

Same shape as the GitNexus probe above — solves the same problem (a single capability boolean cannot distinguish "MCP wired" from "remote backend reachable") for a different MCP.

### Capability key vs. derived probe

- `mcp.agentmemory` — boolean capability key written by `bin/setup`. Answers "is the agentmemory MCP transport available?" When true, the 7 **standalone tools** (`memory_smart_search`, `memory_save`, `memory_recall`, `memory_sessions`, `memory_audit`, `memory_export`, `memory_governance_delete`) are callable.
- `agentmemory.server_up` — runtime-derived session pin. Answers "is the agentmemory HTTP backend reachable at `${AGENTMEMORY_URL:-http://localhost:3111}`?" When true, the MCP shim enters **proxy mode** — `tools/list` returns the upstream's **curated** MCP tool list (empirically against v0.9.21 with `AGENTMEMORY_FORCE_PROXY=1`: 4 standalone survivors + 4 server-tier additions = 8 tools total — `memory_smart_search`, `memory_save`, `memory_recall`, `memory_sessions`, `memory_diagnose`, `memory_consolidate`, `memory_lesson_save`, `memory_reflect`). NOTE: `tools/list` does NOT include `memory_audit`/`memory_export`/`memory_governance_delete` in proxy mode (they're standalone-only — verify with `agentmemory:forget` skill if needed), and the proxy MCP catalog does NOT include the file/commit/patterns/timeline/graph/facet/vision tools (those remain HTTP-only at `/agentmemory/<route>` per `mcp-toolbox.md`). Unknown MCP tool calls are forwarded to `/agentmemory/mcp/call` per `standalone.ts:354-357`. When false, only the 7 IMPLEMENTED_TOOLS work locally — every other `memory_*` MCP call returns `Unknown tool`.

The probe is gated by `mcp.agentmemory` being pinned. Without the capability key, no probe runs.

**Important:** The shim has TWO modes, controlled by backend reachability (verified at `research/rohitg00/agentmemory/src/mcp/standalone.ts:343-415`):
- **Standalone mode** (backend NOT reachable): only the 7 IMPLEMENTED_TOOLS at `standalone.ts:16-24` are callable via MCP. Server-tier tools return `Unknown tool`.
- **Proxy mode** (backend reachable): `tools/list` returns the upstream's curated MCP catalog (empirically 8 tools against v0.9.21, NOT a strict superset of standalone — see the tool enumeration above), AND any non-standalone tool call is forwarded to `/agentmemory/mcp/call`. Server-tier tools that ARE in that curation (`memory_diagnose`, `memory_consolidate`, `memory_lesson_save`, `memory_reflect`) become callable as `mcp__plugin_agentmemory_agentmemory__*`. Server-tier tools that are NOT (file_history, commit_lookup, patterns, timeline, graph_query, facet_query, vision_search) are reachable ONLY via direct HTTP per `mcp-toolbox.md`.

Direct HTTP access to `${AGENTMEMORY_URL}/agentmemory/<route>` is also possible (routes live under `/agentmemory/*`, never `/api/*`; verified at `src/triggers/api.ts`), and is documented in `mcp-toolbox.md` as a fallback for non-MCP consumers (CLI scripts, integration tests). The probe itself MUST use HTTP `/agentmemory/livez` (not MCP) because the probe runs before the MCP shim's mode is settled.

### Derivation (run once, then session-pinned)

At the first Bootstrap (across any x-skill that needs server-tier memory tools) in a session:

1. **Gate:** `mcp.agentmemory` must be in the bootstrap-active set. If not, **skip entirely** — `agentmemory.server_up = false`, all server-tier rows fall through to their fallback.
2. Probe out-of-band via HTTP — do NOT use an MCP tool call:

   ```bash
   curl -fsS --max-time 3 "${AGENTMEMORY_URL:-http://localhost:3111}/agentmemory/livez"
   ```

   Why HTTP and not MCP: `memory_diagnose` is server-tier-only and is never registered in the MCP transport (see "Important" note above). The `livez` endpoint is the upstream's own server-health convention, returns `{"service":"agentmemory","status":"ok"}` in ~3 ms when reachable, and works without any env vars when the backend is on its default port.
3. Pin the result for the rest of the session.
   - HTTP 2xx with `status: "ok"` in the body ⇒ `agentmemory.server_up = true`.
   - Non-zero curl exit, timeout, or any non-ok body ⇒ `agentmemory.server_up = false`.
4. **It runs exactly once per session.** All consuming skills read the pinned record.

### Use-class asymmetry

- **Correctness-sensitive consumers** (e.g., `x-bugfix` regression bisect via `memory_commit_lookup`) **hard-degrade to fallback** when `agentmemory.server_up = false`. Never call server-tier endpoints speculatively.
- **Advisory consumers** (e.g., `x-research` enrichment via `memory_patterns`) proceed with a one-line note: `[x-skills] agentmemory server not reachable; standalone tools only.`

### Unpinned no-op

With `mcp.agentmemory` NOT pinned in the bootstrap-active set, this probe is a no-op — never run, nothing derived. Consumers fall straight to their non-memory fallback rows. Sessions without agentmemory have **zero behavior change**.

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
