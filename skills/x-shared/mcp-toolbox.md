# MCP Toolbox — Decision Matrix

Plugin-local reference for selecting MCP servers when researching, debugging, or planning.
Availability is gated by the user's MCP setup; skills should fall back gracefully if a server is absent.

## Quick decision

| Need | MCP → Tool | Fallback (when primary unavailable) | Notes |
|---|---|---|---|
| Quick factual question | `perplexity` → `perplexity_ask` | `agy-agent` (Google Search) → web `WebFetch` | Synthesized answer + 8-15 citations, ~800 tokens, ~3s |
| X vs Y tradeoff reasoning | `perplexity` → `perplexity_reason` | OMO `oracle` (no web context) | Step-by-step web-grounded reasoning |
| Exhaustive multi-source audit | `perplexity` → `perplexity_research` | OMO `librarian` (TYPE B) parallel with `agy-agent` | 46+ citations, 5000+ words, 60-120s. Use sparingly. |
| Raw article content (no synthesis) | `exa` → `web_search_exa` | `WebFetch` direct on user-supplied URL | Frame queries as descriptions, not keywords |
| Dense code snippets from web/GitHub | `exa` → `get_code_context_exa` | OMO `librarian` (clones + greps) | Up to 50k tokens of code |
| OSS repo internals "how does it work" | `deepwiki` → `ask_question` | `gh search code` → OMO `librarian` | 90% of deepwiki use; `read_wiki_contents` is last resort |
| Library API docs / usage / migration | `context7` → `resolve-library-id` then `query-docs` | `exa get_code_context_exa` → OMO `librarian` | Resolve ID first; be specific |
| Local code semantic search | OMO `explore` (semantic) | native `Grep` (literal patterns only) | Default for exploratory codebase questions |
| Local code edits | native `Edit` / `Write` | — | Surgical partial edits; no MCP needed |
| Public GitHub repo semantic search | `deepwiki` → `ask_question` | `gh search code` | No clone needed |

## Disambiguations

- **perplexity vs exa:** perplexity = pre-synthesized answer with citations. exa = raw source material. Pick by whether you need a summary or the underlying content.
- **perplexity_ask vs perplexity_reason vs perplexity_research:** ask handles 80% of queries; reason for complex tradeoffs; research only for exhaustive analysis.
- **deepwiki vs context7:** deepwiki = how a specific repo's code works internally. context7 = how to use a library's public API.
- **agy-agent vs perplexity for fresh facts:** agy-agent has opt-in Google Search grounding (via `--grounded`; best for current events, "is X still maintained"). perplexity_ask is faster for synthesized factual lookups.

## Availability

Skills load the active capability set ONCE at bootstrap per the contract in `capability-loading.md`. Routing tables are filtered against the pinned set on entry — never re-check per dispatch. Each row below has a primary tool and a documented fallback that auto-applies when the primary is unavailable.

## GitNexus (optional, when `mcp.gitnexus` pinned)

Code-intelligence MCP server (`npm install -g gitnexus`). Provides precomputed call-graph and impact analysis. License: PolyForm Noncommercial — commercial users need a separate license from akonlabs.com.

| Need | Primary (when `mcp.gitnexus` pinned) | Fallback (when not pinned) |
|---|---|---|
| Blast radius before edits | `gitnexus` → `impact` (with `direction: upstream`, `minConfidence`) | OMO `oracle` qualitative scan; otherwise treat as warn-only |
| 360° symbol context (callers + callees + processes) | `gitnexus` → `context` | Two native `Grep` passes (callers, then callees) → OMO `explore` |
| Pre-commit / pre-PR scope check | `gitnexus` → `detect_changes` | `git diff` + manual analysis |
| Multi-file rename | `gitnexus` → `rename` (always `dry_run: true` first) | native `Edit` per file (after `git grep` for call sites) |
| Execution-flow-grouped search | `gitnexus` → `query` | native `Grep` / OMO `explore` (loses process grouping) |
| API route → handler → consumer mapping | `gitnexus` → `route_map` / `api_impact` / `shape_check` | Manual OpenAPI spec parse |
| Local structural / "how does X work" (advisory, indexed+any-freshness) | `gitnexus` → `query` (process-grouped) | native `Grep` / OMO `explore` |
| Symbol 360° (callers+callees+flows, advisory) | `gitnexus` → `context` | Two native `Grep` passes (callers, then callees) |
| Ceremony/severity grounding (correctness-sensitive, indexed+fresh) | `gitnexus` → `impact` — **counts only, never the risk label (C1)** | heuristic depth calibration / qualitative scan |
| Pre-commit scope + flow check (correctness-sensitive, indexed+fresh) | `gitnexus` → `detect_changes` (changed symbols + affected processes) | `git diff` (no flow membership) |

`impact` / `context` reflect the static call graph and may miss dynamic dispatch / reflection / string-keyed handlers (C2). Never present a 0-result as a safety guarantee.

**Use-class index (F2):** every GitNexus tool is classified exactly once. This is the canonical answer to "is tool X correctness-sensitive?" — downstream tasks resolve a tool's class from here, not by re-deriving it.
- **correctness-sensitive** (stale → hard-degrade to fallback): `impact`, `detect_changes`, `route_map`, `api_impact`, `shape_check`, `rename`
- **advisory** (stale → usable with a one-line staleness note): `query`, `context`

> `rename` is correctness-sensitive: a multi-file rename computed against a stale call graph silently misses call sites — the canonical silently-wrong-mapping hazard (same class as `detect_changes`). Always `dry_run: true` first regardless.

**Index freshness:** GitNexus tools may report a stale index. When they do, surface the warning and suggest `npx gitnexus analyze` — do NOT auto-run it (it rewrites `AGENTS.md` / `CLAUDE.md` and can take minutes on large repos).

**When NOT to use GitNexus rows even if pinned:**
- Repo not yet indexed by GitNexus → tools error; fall back row applies.
- Quick literal-string lookup → native `Grep` is still cheaper.

**Capability gate:** Every Primary row above is treated as the Fallback row UNLESS the three-part gate holds: `mcp.gitnexus` in the active capability set **AND** the target repo is indexed by GitNexus **AND** the index is fresh. If the pinned or indexed leg fails, the Fallback row applies unconditionally. **If only the freshness leg fails (pinned + indexed but stale), do NOT apply this blanket rule — defer to the Freshness gate below, which carves out advisory tools.** The substitution is automatic — skills should not branch on `mcp.gitnexus` ad-hoc, only consult this table.

**Freshness gate:** when the gate fails *only* on the freshness leg (pinned + indexed but the index is stale), the behavior depends on the tool's use class — resolved from the **Use-class index (F2) above, which is the single source of truth for class membership** (do NOT re-enumerate the tool lists here):
- Tools in the **correctness-sensitive** class: a stale index produces silently-wrong symbol/flow mappings — **hard-degrade to the Fallback row**. Do not use stale graph output.
- Tools in the **advisory** class: proceed using the stale index but **append a one-line staleness note** (e.g. `(index N commits stale — results may lag HEAD)`) to the surfaced result. Stale search beats no search; the user reads raw results.

## agentmemory (optional, when `mcp.agentmemory` pinned)

Persistent memory MCP from `rohitg00/agentmemory`. Two tiers — standalone (7 tools exposed through MCP, work without a running server) and server (46 more tools, reachable ONLY via the agentmemory HTTP backend at `${AGENTMEMORY_URL:-http://localhost:3111}`; server-tier tools are NOT registered through the MCP transport — see the `agentmemory.server_up` probe defined in `capability-loading.md`). License: Apache-2.0.

### Standalone tier (always available when `mcp.agentmemory` pinned)

| Need | Primary tool | Fallback (when `mcp.agentmemory` not pinned) |
|---|---|---|
| Recall prior decisions/observations on a topic | `agentmemory` → `memory_smart_search` (`{ query, limit }`) | Native Claude memory (`~/.claude/projects/<proj>/memory/MEMORY.md`) |
| Targeted recall with format + token budget | `agentmemory` → `memory_recall` (`{ query, format: 'compact', token_budget }`) | Native Claude memory grep |
| Save an insight, decision, or lesson | `agentmemory` → `memory_save` (`{ content, type, concepts, files }`) | Append to native Claude memory |
| List sessions for replay | `agentmemory` → `memory_sessions` | Manual `ls ~/.claude/projects/` |

> **Asymmetry in proxy mode:** When the shim is in proxy mode, the upstream's `tools/list` does NOT include `memory_audit`, `memory_export`, or `memory_governance_delete` — empirically verified against agentmemory v0.9.21. If you need user-driven export / audit / delete, the upstream `agentmemory:forget` and `agentmemory:export` skills (separate plugin) own those flows over HTTP. The standalone tier is the source of truth for these three tools; proxy mode is a NEAR-superset, not strict.

### Consumer rules — quality filtering & cross-project tagging

These rules apply to ALL skill bootstraps that call `memory_smart_search` / `memory_save`. They address two issues empirically observed in cross-project queries (912 lessons / 240 crystals / 1000 insights across the active store):

**Filter on query side.** `memory_smart_search` returns lessons emitted by the upstream `replay.ts` LESSON_PATTERNS regex auto-importer — stamped with `tags: ["auto-import"]` and `confidence: 0.4`. These are regex-extracted fragments from JSONL traces, not crystallized insights; in practice ~9 of 10 top lesson hits on a broad query are auto-import noise. When consuming results, **drop lessons where `tags` contains `"auto-import"` OR `confidence < 0.5`** before treating them as leads. Manual `memory_save` and `crystallize` entries (0.6–0.85 confidence) are the signal layer; everything below that threshold is regex chaff and must not be cited as prior precedent.

**Tag on save side.** When calling `memory_save`, prefix the project slug into the `concepts` string (e.g., `concepts: "x-skills:x-research,<signal>,<topic>"`). The daemon already records the project path automatically as a field on the record, but `concepts` is the keyword-indexed surface used by `memory_smart_search` — prefixing makes future cross-project queries filter-friendly (`memory_smart_search "x-skills:x-research"` then narrows to this project's saves). The prefix is additive; keep the human-readable concept tokens after it.

### Server tier (gated by `agentmemory.server_up` — extended MCP toolset, proxy-forwarded)

When the agentmemory backend is reachable, the `@agentmemory/mcp` shim enters **proxy mode** (verified at `research/rohitg00/agentmemory/src/mcp/standalone.ts:354-415`): `tools/list` returns the upstream server's curated tool list, and any unknown tool call is forwarded to `/agentmemory/mcp/call`. The proxy-mode tool list is **NOT a strict superset** of the standalone tools — empirically (against agentmemory v0.9.21 with `AGENTMEMORY_FORCE_PROXY=1`) the shim exposes 8 MCP tools total, three of the standalone seven disappear, and several documented "server-tier" capabilities remain HTTP-only. Direct HTTP routes are listed as the canonical interface for those.

#### MCP-callable in proxy mode (4 server-tier additions on top of 4 standalone survivors)

| Need | Primary MCP tool (proxy-forwarded when server up) | Direct HTTP route (fallback / non-MCP consumers) | Fallback when server down |
|---|---|---|---|
| Run health checks across all subsystems | `memory_diagnose({ categories? })` | n/a — proxy-only | n/a |
| Run the 4-tier memory consolidation pipeline | `memory_consolidate({ tier? })` | n/a — proxy-only | n/a |
| Save a lesson with confidence scoring | `memory_lesson_save({ content, confidence?, context?, project?, tags? })` | n/a — proxy-only | Skip — use `memory_save` instead |
| Traverse the knowledge graph and synthesize higher-order insights | `memory_reflect({ project?, maxClusters? })` | n/a — proxy-only | Skip — no fallback |

#### HTTP-only when server up (NOT exposed through MCP proxy)

| Need | Direct HTTP route | Fallback when server down |
|---|---|---|
| Past observations about specific files (regression hunt) | `POST ${AGENTMEMORY_URL}/agentmemory/file-context` (body: `{ files: ["..."], sessionId? }`) | `git log -p -- <file>` |
| Find the session that produced a commit | `GET ${AGENTMEMORY_URL}/agentmemory/session/by-commit?commit=<sha>` | `git show <sha>` + manual reconstruction |
| Recent commits with session linkage | `GET ${AGENTMEMORY_URL}/agentmemory/commits` | `git log --oneline` |
| Recurring patterns across sessions | `POST ${AGENTMEMORY_URL}/agentmemory/patterns` | Skip — manual review |
| Chronological observations around an anchor | `POST ${AGENTMEMORY_URL}/agentmemory/timeline` | `git log --since/--until` |
| Knowledge-graph traversal | `POST ${AGENTMEMORY_URL}/agentmemory/graph/query` | Skip — no fallback |
| Typed-dimension filtering | `POST ${AGENTMEMORY_URL}/agentmemory/facets/query` | Skip — manual triage |
| Image-similarity search (UI regression) | `POST ${AGENTMEMORY_URL}/agentmemory/vision-search` | Manual visual diff |
| Health probe (used for `server_up` derivation) | `GET ${AGENTMEMORY_URL}/agentmemory/livez` | n/a |

> Empirically verified set; backend versions other than 0.9.21 may expose different curations. Re-test with: ToolSearch `+memory agentmemory` after `memory_diagnose` succeeds, and grep `(.tools // []) | map(.name)` against `${AGENTMEMORY_URL}/agentmemory/mcp/tools`.

> Consumers should resolve the canonical request/response shape for each endpoint against the vendored upstream at `research/rohitg00/agentmemory`. MCP tool schemas live in `src/mcp/tools-registry.ts`; function_id ↔ HTTP route mapping lives in `src/triggers/api.ts`; the MCP→function_id dispatcher lives in `src/mcp/server.ts`. The endpoint paths above mirror the upstream's published REST routes (verified `grep -rn '"/agentmemory/' src/triggers/api.ts`).

### Tools NOT routed through x-skills

`memory_action_*`, `memory_sketch_*`, `memory_lease`, `memory_signal_*`, `memory_team_*`, `memory_mesh_sync`, `memory_routine_run`, `memory_sentinel_*`, `memory_checkpoint`, `memory_claude_bridge_sync` — workflow/multi-agent coordination overlapping with TodoWrite + `x-team` + `oh-my-claudecode:team`. Auto-deletion tools (`memory_governance_delete`, `memory_export`, `memory_obsidian_export`, `memory_audit`) — user-driven, owned by the upstream `agentmemory:forget` skill.

### Disambiguation: agentmemory vs Claude's auto-memory file

Claude Code already injects `~/.claude/projects/<proj>/memory/MEMORY.md` into every session. That file is best for **the user's stable preferences and project facts**. agentmemory is best for **per-session observations, decisions, and file-touch history** that's too granular for MEMORY.md and benefits from semantic search. Use both — they don't compete.
