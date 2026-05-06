# Step 2: INGEST — Route to gemini / research / claude

**Progress: Step 2 of 5** — Next: Step 3 OUTLINE

## Goal

Produce a digested representation of the source that Phase 3 can use to build a TOC. Cache the result to `_ingest.md` so re-runs (resume, regenerate-outline) don't re-fetch.

## Rules

- **TRUST** the bootstrap-pinned capability set. Do NOT probe for tools per dispatch.
- **CACHE** every non-direct ingest into `.x-guide/<slug>/_ingest.md`.
- **NEVER** block on a missing capability — fall back per the matrix below.

## Routing Tree

Compute `size_estimate` first:

| Source type | Size proxy |
|---|---|
| `file` | byte size; rough tokens ≈ bytes / 4 |
| `dir` | sum of byte sizes of code/markdown/text files (skip binaries, lockfiles, `node_modules`, `.git`) |
| `url` | unknown until fetched; treat as >50k by default unless the URL is a small known doc page |
| `paste` | character count / 4 |
| `vague` | not applicable |

Then route:

```
input.type == "vague"
  → x-research (multi-source synthesis)
input.type in {file, dir, url, paste} AND size_estimate > 50_000
  → if `gemini_cli` capability active:
        x-gemini ingest
    else:
        Claude direct (warn user once if size_estimate > 150_000)
input.type in {file, dir, url, paste} AND size_estimate <= 50_000
  → Claude direct (no _ingest.md cache)
```

The full decision matrix lives in `../references/routing-matrix.md` — if the tree above ever drifts from the reference, the reference wins.

## Per-Route Behavior

### Route A: x-research (vague target)

1. Read `../../x-research/SKILL.md` (Bootstrap step) only now if not already loaded.
2. Dispatch x-research with a focused brief: "Build a teaching outline for: <vague phrase>. Target audience: a developer who wants to understand it well enough to work on it. Surface concepts, layers, edges, gotchas, and the most relevant local files."
3. Capture the synthesized result.
4. Write to `.x-guide/<slug>/_ingest.md` with a header:

```markdown
# Ingest cache

Source: vague — "<phrase>"
Method: x-research
Ingested at: <ISO timestamp>

---

<synthesized content>
```

5. Set `progress.json.source.ingest_method = "x-research"`.

### Route B: x-gemini ingest (large local input)

1. Read `../../x-gemini/SKILL.md` (Bootstrap) only now if not already loaded.
2. Dispatch x-gemini with prompt:
   ```
   Produce a teaching skeleton of the attached source. Output sections:
   - Top-level purpose (1 paragraph)
   - Major concepts / building blocks (bullet list)
   - Layered structure (foundations → mechanics → edges)
   - Concrete entry points or "where to start reading" (file:line if code)
   - Vocabulary the reader needs (term: 1-line definition)
   - Subtle behaviors / edges worth covering
   No tutorial prose yet — just the skeleton.
   ```
3. Pass the source via `--file` (file/dir) or stdin (paste).
4. Write the gemini output to `.x-guide/<slug>/_ingest.md` with the same header format as Route A but `Method: x-gemini`.
5. Set `progress.json.source.ingest_method = "x-gemini"`.

### Route C: Claude direct (small input or gemini unavailable)

1. Read the source directly (`Read` for files, `WebFetch` for URLs, paste already in chat).
2. Hold the content in working memory; do NOT write `_ingest.md` (the source itself is the cache).
3. Set `progress.json.source.ingest_method = "claude-direct"`.

## Stale-Cache Handling (resume + regenerate-outline only)

If `_ingest.md` already exists when Phase 2 runs:

- For `file`/`dir` sources: compare source `mtime` to `_ingest.md` `mtime`.
- If source is newer → prompt user: `re-ingest now / keep cached / abort`. Default action on no-input is `keep cached`.
- For `url`/`paste`/`vague` sources: keep cached unless the user explicitly requests re-ingest.

## Output of Phase 2

A reference to ingested content (in-memory for Route C, file path for A/B) plus a recorded `ingest_method`. Phase 3 uses this to draft the TOC.
