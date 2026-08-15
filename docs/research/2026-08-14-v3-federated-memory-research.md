---
title: v3 federated-memory research — drop basic-memory, index over sources
slug: v3-federated-memory-research
type: research
status: done
created: 2026-08-14
updated: 2026-08-14
related: [x-skills-v3, x-skills-v3-decisions, v3-memory-store-research]
---

# v3 federated-memory research — the user's drop-basic-memory proposal, verified

**Question (user, 2026-08-14):** drop basic-memory; use Claude native memory + repo `docs/` as
primary context and long-term memory; build a light search engine over both sources. Verify.

**Verdict:** the proposal's shape is right and the field has converged on it — with one
amendment the evidence forced on the writes side, later resolved by the user's direction to
**remove the durable-memory write requirement entirely** rather than relocate it (DEC-028).
Sequel to `[MEM]` (`2026-08-13-v3-memory-store-research.md`); method identical — 4 research
lanes, a judge scoring architectures 0–10 on a 10-criterion rubric, 3 adversarial verifiers, all
sources fetched live 2026-08-14/15.

## §1 The engine: adopt, not build — tobi/qmd

`tobi/qmd` (Tobi Lütke) is a near-exact match for "light local search engine over multiple
markdown roots": MIT, 28,851★, pushed the day before research, hybrid BM25(FTS5) + sqlite-vec +
RRF + local LLM rerank, **fully local** (three auto-downloaded GGUF models ≈2GB, zero API keys,
no daemon — MCP stdio is a subprocess), named multi-root collections, an official Claude Code
plugin, and `get`/`multi_get` returning **full bodies with line numbers** (read-forward built
in). The BM25 tier needs **zero models** — `qmd update` + `qmd search` work with nothing
downloaded, which makes it the headless default. Index is a disposable cache
(`~/.cache/qmd/index.sqlite`).

Verified caveats (adversarial pass, none disqualifying): npm lags main by ~2.5 months (v2.5.3
vs v2.6.3 on main, open issue #895) — pin the npm build and treat CLI churn as shim risk; open
silent embedding-corruption bug #897 (≥512-token chunks store garbage vectors — **BM25 lane
unaffected**, another reason BM25-only is the default); Apple Silicon Metal deadlock #735
(`QMD_FORCE_CPU` mitigates; the user is on macOS); MCP HTTP server serializes behind in-flight
queries #762 (relevant to 9-parallel-session workflows — prefer stdio-per-session);
`qmd update` refreshes FTS only — embedding is a separate `qmd embed` step needing an explicit
policy; bus factor effectively 1 (tobi 510 commits vs next-highest 10; real external PR flow but
67% of merges are tobi). Alternatives: run-llama/semtools (single Rust binary, static local
embeddings — minimal-footprint fallback, snippets-only, quiet since 2026-03); LEANN
(Python/PyTorch-heavy, vector-only); zilliztech/claude-context disqualified (requires
Milvus/Zilliz + embedding key); the md-search MCP long tail is uniformly 1–2★ bus-factor-1.

## §2 The substrate: native memory is indexable, not writable

Claude Code's auto-memory dir is documented-but-unversioned and under active monthly mutation:
format semantics changed **6+ times Mar–Jul 2026**; a session-cleanup bug **deleted memory-folder
contents until v2.1.228** (2026-08-11); curation merge-or-drop under the 200-line/25KB index cap
is by design; `memory/team/` is server-authoritative ("server wins"); zero official guidance on
external tools writing into the dir; **no memory search/API/export shipped through v2.1.233**;
#39195 (cross-project memory) open with zero maintainer engagement; Anthropic's platform bet is
the beta Memory Stores API (managed agents; CRUD + versions, **no search endpoint**) — building
write paths on the local layout is building on churn; **indexing it read-only is defensible**.

Two corrections to prior rounds (steelman verifier, live docs): plain `claude -p` **does** load
auto-memory today — only `--bare` skips it (but "--bare will become the default for -p in a
future release" — the forward risk stands, and subagents never load it); `autoMemoryDirectory`
is a **documented** setting honored from any scope — what remains unblessed is only the
multi-project *sharing* semantics.

## §3 Prior art: the proposal's shape is the 2026 mainstream

Docs-as-memory (CLAUDE.md/AGENTS.md always-loaded + docs/ADRs on demand) is the documented
mainstream pattern; index-over-sources has convergent OSS implementations (agentkb, ki, riffle,
local-index, mdkb) sharing one architecture — sources stay normal files, indexes are disposable
caches, search is a small hybrid CLI. **No major coding harness ships semantic search over its
own memory as of Aug 2026** (Claude Code, Codex, Cursor, Windsurf, opencode, Amp all load
markdown at session start) — the gap is filled by third-party overlays, i.e. a thin owned search
tool is exactly the shape the ecosystem is building. Benchmarks favor files+full-reads over
curated stores: Letta's LoCoMo run — filesystem agent 74.0% vs Mem0 68.5%; LongMemEval-V2 —
trajectories-as-files + coding agent 72.5% vs strongest RAG 48.5% (verified real; external
validity for cross-repo invariant recall is suggestive, not proven).

## §4 The writes side — the one hole, and how it closed

With no global store, a cross-repo invariant learned in repo A has no coherent durable home:
origin-repo `docs/` dies with the checkout and is unwritable in consulted third-party repos;
native memory fails on curation collision + per-repo scope + no stable citation (§2); the
`autoMemoryDirectory` shared dir makes Claude's curation a concurrent writer to ONE capped index
across 9+ parallel sessions — a data race by design. The judge's ranking reflected this:
**E "drop the MCP, keep `~/basic-memory` as a plain governed write folder, qmd federated over
it + docs/ + native memory" scored 9.1**; C (same, unhardened) 8.5; D augment 6.2 (strictly
dominated — two unreconciled search systems); A status quo 6.0 (sound but leaves docs/ and
native memory unsearchable and the measured 8% follow-through unfixed); **B user-strict 3.0**
(writes-side elimination). The steelman verifier reached PARTIAL: every workable strict variant
re-instantiates a machine-global chain-writable folder under another name.

**Resolution (user, 2026-08-14): remove the requirement instead of relocating it.** x-skills
writes **no memory store at all** — the `docs/` append is the chain's only durable write. This
deletes DEC-016's stub-write, RED→GREEN persist, write-time overlap lint, and slug-normalizer
port from the build; one writer per store (native memory stays Claude's alone); the user is
retiring the v2-era global content pipeline (session hooks, bm-curator) that fed `~/basic-memory`,
so the store freezes regardless — v3 treats it as a **read-only legacy corpus** the federated
index still searches (1,157/1,157 notes carry `permalink:` frontmatter, so existing `memory://`
citations in spec docs resolve by grep/qmd without the MCP). DEC-022's own falsifier ("if recall
never pre-answers, the write path is ceremony — drop the basic-memory half and keep the doc
append") is thereby exercised early on telemetry (`[MEM §8]`-class evidence: 5.4% session touch,
8% read follow-through, 2:1 write:read sink) rather than awaiting S3–S7.

## §5 What DEC-028 adopts (see the DEC for normative wording)

Recall = federated + read-only: optional `tool.qmd` capability behind a thin `bin/` shim
(DEC-026 pattern) with collections over `~/basic-memory` (legacy) + the current repo's `docs/`
+ `~/.claude/projects/*/memory/`; **mandatory read-forward** (full bodies of top 1–2 hits before
any hit becomes a claim — the mechanical attack on the 8% baseline); headless default BM25-only
(`--no-rerank`, no models needed); `tool.qmd` absent → `rg` over the same roots; both absent →
no recall, chain proceeds (advisory, never a gate). Accepted risks, each with a falsifier and
owner in the DEC: ambient-capture dependence (native memory is now the only place a transferable
can land), substrate drift (`--bare`-default trajectory; layout churn), engine health (bus
factor 1 — `rg` is the insurance; the folder, not the engine, is load-bearing).

**Postscript (same day):** DEC-028 was amended hours after acceptance to remove the
`~/basic-memory` legacy root from the recall contract — it is the author's personal store, and
x-skills ships to other users; a user-specific home path must not appear in a distributed
plugin's spec. Recall roots are repo `docs/` + native memory dirs only; personal corpora are
user-side qmd collections (config, not spec). §5 above records the pre-amendment shape.
