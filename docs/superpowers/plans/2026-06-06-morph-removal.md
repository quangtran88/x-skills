# Plan: Full removal of morph-mcp from x-skills

**Date:** 2026-06-06
**Type:** Capability removal (semver: **MINOR** — every morph path already degrades to a native/OMO fallback, so no skill breaks; a capability simply disappears).
**Decision:** User chose full removal (over "demote to fallback" / "runtime opt-out only"). morph-mcp is dropped from the published plugin entirely: capability manifest, setup detection, routing tables, and all skill/doc references.

## Scope

54 files match `morph`. Split:
- **142 active refs** (~44 files) → changed.
- **32 historical-plan refs** (`docs/superpowers/plans/*` except this file) → **LEFT UNTOUCHED** (dated records; rewriting falsifies history). This new plan file legitimately contains "morph".

Success criterion: after the change, `git grep -i morph` matches ONLY `docs/superpowers/plans/*`.

## Canonical substitution table (LOCKED — apply verbatim for consistency)

| morph usage pattern | replacement |
|---|---|
| `morph[-mcp]` → `codebase_search` as **primary** local semantic search | OMO `explore` (semantic) → native `Grep` (literal) |
| `morph[-mcp]` → `edit_file` as **primary/default** editor | native `Edit` / `Write` |
| `morph[-mcp]` → `github_codebase_search` as **primary** public-repo search | `deepwiki` → `ask_question` → `gh search code` |
| morph as **deepwiki** fallback | `gh search code` → OMO `librarian` |
| morph as **gitnexus** `context`/`query` fallback | native `Grep` (callers, then callees) / OMO `explore` |
| morph as **gitnexus** `rename` fallback | native `Edit` per file (after `git grep` for call sites) |
| `"always use morph-mcp"` (precedence-ladder EXAMPLE only) | `"always use ripgrep (\`rg\`)"` (neutral tool-preference example) |
| morph token in an MCP-server enumeration list | delete the token |
| morph in a dispatch-isolation list (`Agent / OMC / OMO / morph`) | delete the `morph` token only |
| morph capability key / setup detection / manifest field | remove entirely |
| morph in "cheapest-viable-first" prose | reword to native `Grep` / OMO `explore` |
| morph-auth / morph-first-HARD-GATE prose (x-research) | drop morph; gate now applies to `deepwiki` (and `gitnexus`) primaries only |

## Phase A — load-bearing + semantic (done by lead, not delegated)

- `hooks/inject-capabilities.sh` — drop the `mcp.morph` emit line (keep jq array valid).
- `skills/x-shared/capability-loading.md` — drop `"morph": true` from example manifest.
- `lib/feature-gate.md` — delete morph row (:77); fix deepwiki fallback (:74) to `gh search code` / OMO `librarian`.
- `bin/setup` — delete: `morph)` install case, `check_mcp "morph"`, manifest field `"morph"`, `report_skill` case `morph)`, `morph` token in the 4 `report_skill` lines; genericize the `-mcp` naming comment; drop morph from the detection-summary list.
- `skills/x-shared/mcp-toolbox.md` — transform rows :15,:17,:18,:19,:39,:41,:42,:44,:45 per table.
- `skills/x-shared/omo-routing.md`, `invocation-guide.md`, `context-envelope.md` — per table.
- `CLAUDE.md` (:11,:115), `README.md` (:85), `commands/setup.md` (:15,:105).
- `skills/x-research/**` (SKILL.md, gotchas.md, references/*) — heaviest + HARD-GATE semantics.

## Phase B — mechanical leaf docs (delegated, substitution table supplied)

- `skills/x-do/**`, `skills/x-review/**`, `skills/x-bugfix/**`, `skills/x-qa/**`,
  `skills/x-gemini/SKILL.md`, `skills/x-mindful/**`, `skills/x-team/**`,
  `skills/x-worktree/**`, `skills/x-skill-improve/SKILL.md`
- `docs/**` (architecture/overview only — NOT `docs/superpowers/plans/*`)

## Phase C — verify

1. `git grep -in morph -- ':!docs/superpowers/plans'` → **0 hits**.
2. `bash -n bin/setup` + run `inject-capabilities.sh` against a sample manifest; diff emitted capability line is identical minus `mcp.morph`.
3. jq-validate the manifest JSON emitted by `bin/setup`.
4. Bump version 1.19.0 → **1.20.0** in the 3 manifests; add release note "Dropped morph-mcp routing/capability; native Edit/Grep + deepwiki/gh are the new defaults."
