# OMO Agent Routing for x-do

For the full agent catalog, cost tiers, and parallel patterns, see the [shared routing table](../../x-shared/omo-routing.md).

## OMO Tool Access (Verified via `opencode mcp list`)

OMO agents have these tools:

**MCP servers (configured in opencode.json):**
| MCP | Tools | Notes |
|-----|-------|-------|
| exa | web_search_exa, get_code_context_exa, crawling_exa | Web search + code context |
| perplexity | perplexity_ask, perplexity_search, perplexity_reason, perplexity_research | AI-synthesized web search |
| engram | agent memory | Cross-session memory |

**Built-in OpenCode tools (not MCPs):**
- grep, glob, list, bash, read, write, edit, webfetch, websearch, codesearch

**Agent-level permissions:** `explore` is read-only (no write/edit). Other agents have broader access.

**Not available to OMO agents:** deepwiki, morph-mcp, context7 (skill-level MCP, may not load for all agents), playwright, github MCP, atlassian, shadcn, pm2, webstorm. For tasks requiring these, use OMC agents (Agent tool) which inherit all session MCPs.

## x-do-Specific Routing

| Situation | Agent | Why |
|---|---|---|
| Requirements are ambiguous or open-ended | `metis` | Intent classification before planning |
| Need structured plan with tasks + deps | `prometheus` | After requirements are clear |
| Review plan for blockers before execution | `momus` | Max 3 issues, OKAY/REJECT verdict |
| 1-2 standalone complex implementation tasks | `hephaestus` | Autonomous deep worker, explores before acting |
| Fresh perspective after stalled debugging | `oracle` | Read-only strategic advice |
