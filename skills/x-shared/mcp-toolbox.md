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

## basic-memory (optional, when `mcp.basic_memory` pinned)

Persistent markdown knowledge base from `basicmachines-co/basic-memory` (vendored at `research/basicmachines-co/basic-memory`). Local-first: notes are plain markdown files indexed into SQLite; the MCP server runs single-process over stdio (`uvx basic-memory mcp`) — no separate backend, no health probe, **one tier** (see `capability-loading.md § basic-memory: single-tier, no derived probe`). Tool prefix: `mcp__basic-memory__*`. License: AGPL-3.0.

| Need | Primary tool | Fallback (when `mcp.basic_memory` not pinned) |
|---|---|---|
| Recall prior decisions/lessons on a topic | `basic-memory` → `search_notes` (`{ query, page_size }`) | Native Claude memory (`~/.claude/projects/<proj>/memory/MEMORY.md`) |
| Traverse related notes from a known hit | `basic-memory` → `build_context` (`{ url: "memory://<permalink>", depth, timeframe }`) | Native Claude memory grep |
| Save an insight, decision, or lesson | `basic-memory` → `write_note` (`{ title, directory, content, tags }`) | Append to native Claude memory |
| What changed recently (cross-session context) | `basic-memory` → `recent_activity` (`{ timeframe: "7d" }`) | Manual `ls ~/.claude/projects/` |
| Read / patch one known note | `basic-memory` → `read_note` / `edit_note` | n/a |

> Tool schemas accept common aliases (`limit` for `page_size`, `folder`/`dir` for `directory`, `q` for `query`) — verified in the vendored source at `src/basic_memory/mcp/tools/`. Prefer the canonical names above.

### Consumer rules — placement & cross-project tagging

These rules apply to ALL skill bootstraps that call `search_notes` / `write_note`:

**Placement on save.** `write_note` requires a `directory`. Route by note kind — `lessons/<project-slug>/` (gotchas, root causes, failed approaches), `decisions/<project-slug>/` (decisions + rationale), `notes/<project-slug>/` (durable facts, conventions). project-slug = basename of cwd (e.g. `x-skills`). These mirror the Basic Memory placement conventions already seeded in the store — do not invent new top-level folders.

**Tag on save.** Always include the project slug and the emitting skill in `tags` (e.g. `tags: ["x-skills", "x-research", "<topic>"]`). Tags are a keyword surface for ranking and cross-project lookup — **not** a recall filter (see § Memory Reflex → "Do NOT hard-filter recall by `tags`": a `tags` filter silently excludes every note that lacks the tag).

**Project targeting.** Every tool takes an optional `project` and resolves a session default when omitted. Omit it normally; pass it explicitly only when the user runs multiple knowledge bases. Wrong-project writes succeed silently into the wrong store — if a recall that should hit comes back empty, check `list_memory_projects` before concluding the note was never saved.

**No chaff filter needed.** Unlike the previous agentmemory backend, basic-memory has no regex auto-importer and no confidence scores — every note is deliberately written. Treat all hits as user-curated; rank by relevance, not confidence.

### Memory Reflex — the canonical recall→persist contract

Every work-producing skill runs the same two-beat reflex, gated solely on `mcp.basic_memory`.
Skills **reference this section** instead of restating the calls; each supplies only its own
**query hint** and **note kind** (the two things that legitimately vary per skill).

**Recall (before core work) — an always-run step, never an opt-in branch.**
Place it in the skill's Bootstrap / Pre-Flight so it fires on *every* path that does real
work, not just one mode. When `mcp.basic_memory` is pinned:

```
mcp__basic-memory__search_notes({ query: "<skill's query hint>", page_size: 5 })
```

**Keep `query` purely topical.** Never concatenate a literal repo name (e.g. `"x-skills"`)
into it — that only matches the authoring repo and injects a noise token everywhere else.

**Do NOT hard-filter recall by `tags`.** `search_notes({ tags: [...] })` is an *exclusion*
filter, not a re-rank: any note whose frontmatter lacks that exact tag disappears from the
results entirely. Notes written by `bm-remember` and the `memory-*` companion skills — and
plenty of hand-written ones — carry only topical tags, so a `tags: ["<project-slug>"]` filter
silently drops them even though they sit in `<kind>/<project-slug>/`. A missed hit is
indistinguishable from "no prior knowledge", so the failure is invisible. Scope by *reading*
the results instead: each hit's permalink carries its folder (`main/notes/<project-slug>/…`),
so prefer hits under this project's `<kind>/<project-slug>/` and treat the rest as weaker
leads. Precision is not the failure mode here — silent exclusion is.

Surface hits as **leads, not verdicts** — they inform the brainstorm / plan / investigation
but never auto-drive it (the established framing in x-research / x-bugfix). When
`mcp.basic_memory` is not pinned, **skip silently** — Claude's native auto-memory still applies.

**Persist (at completion) — an always-run step, never an opt-in branch.**
Place it in an unconditional completion step, not inside a "save on request" menu branch.

*Durability gate (apply before writing).* Ask one question per candidate note: **is this a
decision + rationale, a root cause, or a confirmed finding a future session would want — or a
routine run summary / build log?** Skip the write on "routine". Persist **durable output
only**; a successful-run outcome ("built X, tests pass") is NOT durable and must not be
written. When a candidate passes the gate and `mcp.basic_memory` is pinned:

```
mcp__basic-memory__write_note({ title, directory: "<kind>/<project-slug>", content, tags })
```

*Update over duplicate.* If this run's own recall already surfaced a note on the same fact,
update that note instead of accreting a near-duplicate:
`mcp__basic-memory__edit_note({ identifier: "<the permalink from the recall hit — exact match, no fuzzy>", operation: "append", content })`.
Caveat: `edit_note` takes no `tags` and no `directory` — it cannot retag or move a note. If the
surfaced note is missing the project-slug tag or sits in the wrong folder, write a fresh note
with the correct `directory` + `tags` rather than appending to the malformed one.

Route `directory` by note kind per § Consumer rules above — `lessons/` (root causes, failed
approaches), `decisions/` (decisions + rationale), `notes/` (durable facts, conventions).
Tag with the project slug + emitting skill. Skip silently when not pinned.

**The step always runs; only two things suppress a write.** Both beats fire on every path
where the skill produces work. The recall beat is gated solely on the `mcp.basic_memory` pin.
The persist beat always *evaluates* — the `mcp.basic_memory` pin and the durability gate above
are the only two things that stop it from *writing*. Nothing else suppresses the reflex: a
recall reachable on only some modes, or a persist buried under "on explicit request", is the
exact bug this contract exists to prevent.

### Tools NOT routed through x-skills

`canvas`, `list_directory`, `move_note`, `delete_note`, project management (`list_memory_projects` outside the empty-recall check, `create_memory_project`, `delete_project`, `list_workspaces`), schema tools (`schema_validate`, `schema_infer`, `schema_diff`), ChatGPT-compat `search`/`fetch`, `cloud_info`, `release_notes` — user-driven curation and lifecycle flows, owned by the upstream `basic-memory` plugin skills (`bm-remember`, `bm-setup`) and the `memory-*` companion skills.

### Disambiguation: basic-memory vs Claude's auto-memory file

Claude Code already injects `~/.claude/projects/<proj>/memory/MEMORY.md` into every session. That file is best for **the user's stable preferences and project facts**. basic-memory is best for **durable lessons, decisions with rationale, and cross-session knowledge** that benefits from full-text search and graph traversal (`memory://` links). Use both — they don't compete; never duplicate the same fact into both.
