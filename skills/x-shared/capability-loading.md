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
    "agy_cli": true,
    "mcp": {
      "perplexity": true,
      "deepwiki": true,
      "exa": true,
      "context7": true,
      "gitnexus": true,
      "basic_memory": true
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

## basic-memory: single-tier, no derived probe

Unlike GitNexus above, `mcp.basic_memory` needs **no runtime-derived probe**. The basic-memory MCP server (`uvx basic-memory mcp`) is single-process over stdio — plain markdown files plus a local SQLite index, no separate HTTP backend to reach (verified at `research/basicmachines-co/basic-memory/src/basic_memory/cli/commands/mcp.py:28`, default transport `stdio`). One boolean answers everything:

- `mcp.basic_memory` — boolean capability key written by `bin/setup`. When pinned, all routed tools (`search_notes`, `write_note`, `build_context`, `recent_activity`, `read_note`, `edit_note`) are callable as `mcp__basic-memory__*`. When not pinned, consumers fall straight to their non-memory fallback rows (native Claude auto-memory). Sessions without basic-memory have **zero behavior change**.

A tool error despite the pin is ordinary setup drift — handle via § Drift Handling below, not a probe. The one runtime dimension a boolean cannot capture is **project targeting** (which knowledge base a call lands in when multiple are configured) — conventions for that live in `mcp-toolbox.md § basic-memory`.

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
