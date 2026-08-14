---
title: v3 memory-store research — DEC-016 re-verification
slug: v3-memory-store-research
type: research
status: done
created: 2026-08-13
updated: 2026-08-14
related: [x-skills-v3, x-skills-v3-decisions]
---

# v3 memory-store research — is basic-memory worth keeping? (DEC-016 re-verification)

**Question (user, 2026-08-13):** is basic-memory necessary/worth using alongside the v3
ecosystem? Is Claude Code's builtin memory enough? Is any open-source tool a better fit?

**Verdict: KEEP.** DEC-016 survives an adversarial pass from three independent directions —
builtin memory is structurally insufficient for cross-repo recall, the 2026 OSS field fails on
shape (its growth architecture is the exact anti-pattern DEC-016 prohibits), and basic-memory
itself is healthy with a funded search-quality upgrade in flight. Four amendments were adopted
into DEC-016 (§7). All sources fetched live 2026-08-13; the AND/OR-fallback contradiction between
two verifiers was adjudicated by a direct read of the v0.22.1 tag source (§5).

## §1 Method

8-agent workflow: four parallel research lanes (basic-memory project health; Claude Code builtin
memory; OSS agent-memory landscape; MCP-registry sweep), a judge scoring 12 candidates 0–10
against a 10-criterion rubric derived from DEC-016's thin contract (cross-repo store, topical
search with miss-vs-empty distinguishability, stable citation permalink, local-first markdown,
zero standing infra, capability-gated absence, governed low-volume writes, license-for-use,
maintenance health, curated-notes fit), then three adversarial verifiers: one attacking the
builtin-memory claim (verdict PARTIAL — two edge mechanisms, neither rescues the contract), one
attacking the health lane (CONFIRMED with four minor corrections), one attacking the judge's
recommendation (PARTIAL — ranking holds, five evidence corrections, folded into §5–§7). Candidates
scored no points for unused power (graph traversal, vector recall, auto-capture) and lost points
for the infra that unused power costs.

## §2 Builtin Claude Code memory — refuted for cross-repo recall

Claude Code v2.1.229, docs + binary disassembly, adversarially re-verified:

- Main-conversation auto-memory is **per git repository** (`~/.claude/projects/<project>/memory/`;
  worktrees and subdirectories of one repo share, repos never do; project root outside git).
  Machine-local. `code.claude.com/docs/en/memory` § Storage location.
- **No supported cross-repo scope exists.** anthropics/claude-code#39195 ("shared memory across
  multiple projects") open since 2026-03-26; #36561 closed unshipped.
- Two edge mechanisms, both rejected: (a) subagent frontmatter `memory: user` →
  `~/.claude/agent-memory/<agent>/` is documented and cross-project, but tied to a named subagent
  (main session cannot use it), index-only recall with no search API, dead when auto-memory is
  off; (b) the `autoMemoryDirectory` setting is honored **verbatim** (binary-confirmed: no
  per-project subpath appended), so one shared dir works mechanically — but docs frame it purely
  as relocation, sharing semantics are undocumented, and every repo then funnels through a single
  MEMORY.md index hard-capped at 200 lines / 25KB.
- The API memory tool (`memory_20250818`) is client-side and not what Claude Code uses; the
  server-side Memory Stores API (`agent-memory-2026-07-22` beta) belongs to Managed Agents, and
  Claude Code's team-memory surface (`CLAUDE_MEMORY_STORES`, sync watcher) is undocumented,
  feature-flag-gated, and **per-repository scoped anyway**. `--bare`/headless mode disables auto
  memory entirely — fatal for a skill chain that must write.
- Against the contract: no topical search across repos, no stable citation permalinks (memory
  files are mutable markdown the model rewrites during curation — citations silently rot), no
  write/query API. **0 of 3 contract verbs.** CLAUDE.md / `~/.claude/rules` give cross-project
  persistence but are always-loaded guidance, not recallable notes.

## §3 The 2026 OSS field — refuted on shape

The field's growth architecture is hook-driven **auto-capture into databases** — DEC-016's named
anti-pattern — so adoption stars buy contract regressions (all counts GitHub API, 2026-08-13):

| Candidate | Stars | Why it fails the contract |
|---|---|---|
| claude-mem (thedotmack) | 90,584 | 5 lifecycle hooks auto-capturing everything; Bun worker daemon + Chroma; DB-internal storage |
| mem0 / OpenMemory | 63,162 | LLM API key required **just to write**; extracted facts in a vector DB, not notes; auto-capture hooks |
| cognee | 29,991 | Three embedded DBs + mandatory LLM/embedding key for ingest; SessionStart/PreCompact capture |
| Zep / Graphiti | 29,873 | Graph DB in Docker + two paid API deps; Zep Community Edition discontinued; MCP "experimental" |
| Letta (MemGPT) | 24.2k | Agent runtime, not a note service; exposes **no MCP server**; Postgres+pgvector |
| TencentDB Agent Memory | 20.8k | Docker multi-service team hub; license file NOASSERTION — disqualifying until resolved |
| engram | 6.0k | **Best external (4/10):** MIT, single Go binary, SQLite+FTS5 — but DB-internal storage breaks the human-editable markdown substrate; lossy import |
| @modelcontextprotocol/server-memory | ref impl | JSONL entities; search is case-insensitive substring `.includes()`; no permalinks |
| mneme | 2 | The *right* architecture (markdown ground truth + rebuildable FTS5 index, MCP) at 2 stars — a template to steal, not a dependency |

Judge ranking: **KEEP basic-memory 9 > FLAT-STORE 7.5** > engram 4 > mneme 3.5 > official KG 3 >
claude-mem 2.5 > mem0 2 = cognee 2 = BUILTIN-ONLY 2 > TencentDB 1.5 = Zep/Graphiti 1.5 > Letta 1.
FLAT-STORE (keep `~/basic-memory` + conventions, drop the MCP, use `rg`/Read/Write) is not a
competitor but the **degradation tier of the same substrate** — possible only because basic-memory
is file-first, and possible for no other candidate.

## §4 basic-memory health (basicmachines-co/basic-memory)

- Pinned **0.22.1 is the latest release** (2026-06-13); repo pushed the day of research
  (2026-08-13); 3,646★, 254 forks; **16 versioned releases Mar–Jun 2026**; recent bugs close in
  days — but see §5 for the nine-month counterexample.
- **Bus factor ~1:** phernandez ≈83% of top-contributor commits. License **AGPL-3.0** (LICENSE
  file read at main; fine for MCP-over-stdio use, noted for policy). Local mode free; cloud
  $15/seat — no OSS-starvation signals; the 2026 search overhaul lands in the OSS repo.
- **v0.23 is unreleased** (CHANGELOG dated "2026-08-XX") and is a **gated migration, not a
  drop-in**: FastMCP 4.0.0b1 (beta framework) + MCP SDK v2, five automatic DB migrations, removes
  three MCP tools (canvas, cloud_info, release_notes), breaking `edit_note` replace_section
  semantics (#1063), paginated `list_directory` (#1082). Its headline reranker (#1143) is
  **opt-in, default OFF**, needs a local FastEmbed ONNX cross-encoder or a Cohere/Jina/Voyage API
  key, at ~26× hybrid-search p95 latency (17.6ms → 463.8ms, PR #1233 harness). MRR claims vary by
  benchmark — #1143 0.438→0.642 ("directional evidence, not statistically significant"), #1233
  0.917→1.000, #1248 0.616→0.719 over reranker-off — cite a specific harness or none.

## §5 The pin's defects and query semantics (the load-bearing section)

Three silent-recall bugs are **fixed upstream but in no tagged release** at the 0.22.1 pin:

- **#354** — tag search returns empty (silent). Open **nine months** (2025-10-13 → 2026-07-15).
  Corroborates DEC-016's probed observation that a tag miss is byte-identical to an empty store;
  the "never tags" rule is now bug-backed, not just probe-backed. Related: #1068 (zero-vs-unknown
  totals) closed 2026-07-16; #1155 (retrieval inspector exposing filter-rejection reasons) open.
- **#1065** — FTS misses all content beyond ~6,000 chars. Measured against the live store:
  **83 of 1,102 notes (7.5%) exceed 6,000 bytes** — their tails are invisible to `search_notes`
  at the pin.
- **#1016** — file-watcher writes are not vector-embedded; externally-edited notes are silently
  missing from semantic search until reindex. Aggravated by parallel-session direct-file
  workflows.

**Query semantics, adjudicated.** Two verifiers contradicted each other (one: relaxed-OR fallback
exists at ≥3 tokens; the other: strict AND at every count, no fallback anywhere). Direct read of
the v0.22.1 tag settles it — **both are half-right, in different layers**:
`repository/sqlite_search_repository.py` `_prepare_single_term` emits `word* AND word*…` for every
multi-word query; `services/search_service.py` `_is_relaxed_fts_fallback_eligible` +
`_build_relaxed_fts_query` retry a strict-zero result with `" OR ".join(terms)` — gated on FTS
mode, no quotes, no boolean operators, no all-digit tokens, and **≥3 tokens**. Consequences:
a 2-word query is pure AND with no safety net; a ≥3-plain-word query gets the OR retry; tag
filters are metadata-only and **never** fall back, returning empty with zero diagnostics (the
tag's `mcp/tools/search.py` comments literally "return the empty result as normal").

**Lock-in measured low** (a point *for* keeping — cheap exit = low risk): 1,102/1,102 notes carry
`permalink:` frontmatter (rg-resolvable without the MCP), **0/1,102 contain `memory://` links**,
5.4% carry observation markup, 29.5% wiki-links.

## §6 What the adversarial pass corrected

Surviving corrections to the judge's case (folded into §4–§5 above): the "+17% relative MRR"
figure conflated three benchmarks; "bugs closed within days" is falsified by #354's nine months
(only 2026-era bugs close fast); the lock-in/citation-rot argument described a prospective
convention, not the current corpus (0 `memory://` links); "upgrade as soon as v0.23 tags" ignored
the beta-framework/migration/latency risks; and the verifier's own "3+ terms guidance is
backwards" charge was itself wrong — it read only the repository layer and missed the
service-layer OR retry (§5 adjudication). Minor: corpus is 1,102 notes not 1,101; 16 releases
Mar–Jun not 11; phernandez ≈83% not 86%.

## §7 Amendments adopted into DEC-016

1. **Pin-era query rules** (x-shared recall guidance, lands S2): ≥3 plain distinctive terms or
   explicit `OR`; never 2-word AND queries as the only probe; never tag filters; an empty result
   is **inconclusive** — retry as `rg` over `~/basic-memory` before concluding "no prior
   knowledge"; prefer `rg` for exhaustive recall over notes >6KB (#1065) and after any
   direct-file write (#1016), reserving `search_notes` for ranked topical lookup.
2. **Flat-store fallback formalized:** `mcp.basic_memory` absent ⇒ recall/write degrade to native
   `rg`/Read/Write over `~/basic-memory` with file-path citations. No other candidate store can
   offer this, because no other candidate is file-first.
3. **v0.23 upgrade is a gated migration** with a re-validation pass (§4), not an auto-upgrade.
4. **Risk ledger:** bus factor ~1, AGPL-3.0 (use-not-vendor). **Exit ramp** if the maintainer
   goes dark 6+ months or AGPL becomes a distribution problem: flat-store first (zero cost — the
   data is already local markdown), a ~200-line MIT FTS5-over-markdown MCP second (mneme
   pattern). The substrate outlives the tool — the deepest reason keeping it is safe.
