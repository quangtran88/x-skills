# OMO Agent Routing for x-do

For the full agent catalog, cost tiers, and parallel patterns, see the [shared routing table](../../x-shared/omo-routing.md).

> ⚠ **DO NOT DISPATCH to `hephaestus`, `atlas`, `prometheus`, `metis`, `momus`.** These 5 role agents are UNAVAILABLE (oh-my-opencode plugin compat bug). Use direct model routing instead — see the x-do-specific routing table below. Full writeup: `~/.claude/skills/x-omo/gotchas.md`.

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

| Situation | Route | Why |
|---|---|---|
| Requirements are ambiguous or open-ended | `oracle` (or `superpowers:brainstorming`) | Strategic pre-plan consult on GPT-5.4 (replaces UNAVAILABLE `metis`) |
| Need structured plan with tasks + deps | `--model gpt` with a plan-author prompt | GPT-5.4 raw for plan authoring (replaces UNAVAILABLE `prometheus`) |
| Review plan for blockers before execution | `--model gpt` with a blocker-finder prompt | Max 3 issues, OKAY/REJECT verdict (replaces UNAVAILABLE `momus`) |
| 1-2 standalone complex implementation tasks | `--model codex` | GPT-5.3 Codex for autonomous deep work (replaces UNAVAILABLE `hephaestus`) |
| Fresh perspective after stalled debugging | `oracle` | Read-only strategic advice |
