# Phase 2 Routing Matrix — Reference

Decision matrix for picking the ingest route. Step 2 quotes the routing tree; this file is authoritative.

## Decision Matrix

| input.type | size_estimate | gemini_cli active | mcp.{perplexity,exa,deepwiki} active | Route |
|---|---|---|---|---|
| `vague` | n/a | any | any (≥1 helps) | x-research |
| `file` / `dir` / `url` / `paste` | ≤ 50k tokens | any | any | Claude direct |
| `file` / `dir` / `url` / `paste` | > 50k, ≤ 150k | yes | any | x-gemini |
| `file` / `dir` / `url` / `paste` | > 50k, ≤ 150k | no | any | Claude direct |
| `file` / `dir` / `url` / `paste` | > 150k | yes | any | x-gemini |
| `file` / `dir` / `url` / `paste` | > 150k | no | any | Claude direct + warn user once |

## Size Estimation

| Source type | Method |
|---|---|
| `file` | byte size; tokens ≈ bytes / 4 |
| `dir` | sum byte size of code/markdown/text files; skip binaries, lockfiles, `node_modules`, `.git` |
| `url` | unknown until fetched; treat as > 50k by default unless URL is a small known doc |
| `paste` | character count / 4 |
| `vague` | not applicable — always routes to x-research |

## Why Not Always-x-research?

x-research is multi-source synthesis (web + repo + MCP, multi-lane). For a known-local input the user already supplied, that is overkill — slower, more tokens, more web lanes than needed. x-gemini is single-source long-context ingest (1M context, gemini-3.x). It is the right tool when "summarize this big thing I gave you" is the job. x-research already wraps x-gemini internally for vague-target lanes, so we are not duplicating logic — we are skipping unnecessary lanes.

## Capability Gates

Per `../../x-shared/capability-loading.md`. Read once at session start from the `[x-skills/capabilities]` SessionStart line; do not re-check per dispatch.

| Capability | Used for | Fallback when missing |
|---|---|---|
| `gemini_cli` | x-gemini ingest of large input | Claude direct; warn if size > 150k |
| `mcp.perplexity` / `mcp.exa` / `mcp.deepwiki` | x-research vague-target lanes (web sources) | x-research falls back to repo-only Agent(Explore) lanes |
| `omo_plugin` + `oracle` | Optional `q deep` accuracy cross-check (Phase 4) | Skip cross-check, note in part footer |

Per-part teaching prose stays Claude-native regardless of capability set — pedagogy voice matters most.
