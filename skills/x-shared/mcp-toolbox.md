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
