# MCP Toolbox — Decision Matrix

Plugin-local reference for selecting MCP servers when researching, debugging, or planning.
Availability is gated by the user's MCP setup; skills should fall back gracefully if a server is absent.

## Quick decision

| Need | MCP → Tool | Fallback (when primary unavailable) | Notes |
|---|---|---|---|
| Quick factual question | `perplexity` → `perplexity_ask` | `gemini-agent` (Google Search) → web `WebFetch` | Synthesized answer + 8-15 citations, ~800 tokens, ~3s |
| X vs Y tradeoff reasoning | `perplexity` → `perplexity_reason` | OMO `oracle` (no web context) | Step-by-step web-grounded reasoning |
| Exhaustive multi-source audit | `perplexity` → `perplexity_research` | OMO `librarian` (TYPE B) parallel with `gemini-agent` | 46+ citations, 5000+ words, 60-120s. Use sparingly. |
| Raw article content (no synthesis) | `exa` → `web_search_exa` | `WebFetch` direct on user-supplied URL | Frame queries as descriptions, not keywords |
| Dense code snippets from web/GitHub | `exa` → `get_code_context_exa` | OMO `librarian` (clones + greps) | Up to 50k tokens of code |
| OSS repo internals "how does it work" | `deepwiki` → `ask_question` | `morph-mcp github_codebase_search` → OMO `librarian` | 90% of deepwiki use; `read_wiki_contents` is last resort |
| Library API docs / usage / migration | `context7` → `resolve-library-id` then `query-docs` | `exa get_code_context_exa` → OMO `librarian` | Resolve ID first; be specific |
| Local code semantic search | `morph-mcp` → `codebase_search` | native `Grep` (literal patterns only) → OMO `explore` | Default for exploratory codebase questions |
| Local code edits | `morph-mcp` → `edit_file` | native `Edit` / `Write` | Prefer over native Edit for non-trivial changes |
| Public GitHub repo semantic search | `morph-mcp` → `github_codebase_search` | `deepwiki ask_question` → `gh search code` | No clone needed |

## Disambiguations

- **perplexity vs exa:** perplexity = pre-synthesized answer with citations. exa = raw source material. Pick by whether you need a summary or the underlying content.
- **perplexity_ask vs perplexity_reason vs perplexity_research:** ask handles 80% of queries; reason for complex tradeoffs; research only for exhaustive analysis.
- **deepwiki vs context7:** deepwiki = how a specific repo's code works internally. context7 = how to use a library's public API.
- **gemini-agent vs perplexity for fresh facts:** gemini-agent has native Google Search grounding (best for current events, "is X still maintained"). perplexity_ask is faster for synthesized factual lookups.

## Availability

Skills load the active capability set ONCE at bootstrap per the contract in `capability-loading.md`. Routing tables are filtered against the pinned set on entry — never re-check per dispatch. Each row below has a primary tool and a documented fallback that auto-applies when the primary is unavailable.

## GitNexus (optional, when `mcp.gitnexus` pinned)

Code-intelligence MCP server (`npm install -g gitnexus`). Provides precomputed call-graph and impact analysis. License: PolyForm Noncommercial — commercial users need a separate license from akonlabs.com.

| Need | Primary (when `mcp.gitnexus` pinned) | Fallback (when not pinned) |
|---|---|---|
| Blast radius before edits | `gitnexus` → `impact` (with `direction: upstream`, `minConfidence`) | OMO `oracle` qualitative scan; otherwise treat as warn-only |
| 360° symbol context (callers + callees + processes) | `gitnexus` → `context` | Two `morph-mcp codebase_search` calls (callers, then callees) |
| Pre-commit / pre-PR scope check | `gitnexus` → `detect_changes` | `git diff` + manual analysis |
| Multi-file rename | `gitnexus` → `rename` (always `dry_run: true` first) | `morph-mcp edit_file` per file |
| Execution-flow-grouped search | `gitnexus` → `query` | `morph-mcp codebase_search` (loses process grouping) |
| API route → handler → consumer mapping | `gitnexus` → `route_map` / `api_impact` / `shape_check` | Manual OpenAPI spec parse |
| Local structural / "how does X work" (advisory, indexed+any-freshness) | `gitnexus` → `query` (process-grouped) | `morph-mcp codebase_search` |
| Symbol 360° (callers+callees+flows, advisory) | `gitnexus` → `context` | Two `morph-mcp codebase_search` calls (callers, then callees) |
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
