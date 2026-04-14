# OMO Agent Routing (Shared)

Canonical routing table for all x-skills. For full agent catalog and invocation syntax, see the [OMO skill](../x-omo/SKILL.md).

## Agent Catalog

| Agent | Role | Cost | Best For |
|---|---|---|---|
| `explore` | Contextual codebase search | FREE | Find code patterns, conventions, file paths |
| `librarian` | External docs & OSS research | CHEAP | Library docs, API patterns, OSS internals |
| `oracle` | Read-only strategic advisor | EXPENSIVE | Architecture trade-offs, debugging advice |
| `momus` | Plan reviewer (blocker-finder) | EXPENSIVE | Max 3 issues, OKAY/REJECT verdict |
| `metis` | Pre-planning consultant | EXPENSIVE | Intent classification, scope analysis |
| `hephaestus` | Autonomous deep worker | EXPENSIVE | 1-2 standalone complex implementation tasks |
| `prometheus` | Strategic planner | EXPENSIVE | Structured plans with tasks + deps |
| `atlas` | Plan executor / orchestrator | EXPENSIVE | Multi-task plan execution |
| `multimodal-looker` | Visual & document analysis | CHEAP | Image, PDF, screenshot, diagram input |

## OMO Tool Access (Verified via `opencode mcp list`)

**MCP servers:** exa (full suite), perplexity (full suite), engram. **Built-in tools:** grep, glob, bash, read, write, edit, webfetch, websearch, codesearch. `explore` agent is read-only.

**Not available:** deepwiki, morph-mcp, context7 (skill-level, uncertain loading), playwright, github MCP, atlassian, shadcn, pm2, webstorm. Use OMC agents (Agent tool) for these.

## Cost Tiers

| Tier | Meaning | Examples |
|------|---------|----------|
| **FREE** | Uses Claude's native tools only | `explore` |
| **CHEAP** | External API call, <$0.01, <30s | `librarian`, `multimodal-looker` |
| **EXPENSIVE** | Specialized agent, 1-5 min, >$0.10 | `oracle`, `metis`, `prometheus`, `momus`, `hephaestus`, `atlas` |

## Parallel Combinations

These agents are independent and can run simultaneously (`run_in_background: true`, max 3 concurrent):

| Pattern | Agents | When |
|---|---|---|
| Research | `explore` + `librarian` | Codebase + external docs needed |
| Pre-planning | `metis` + `explore` | Vague requirements + codebase context |
| Plan review | `momus` + OMC `code-reviewer` | Reviewing a complex plan |
| Visual + context | `multimodal-looker` + `explore` | Image input + related code lookup |
| Code review | OMC `code-reviewer` + `--model gpt` | Claude + GPT cross-model review |

## Sequential Dependencies (Never Parallelize)

- `metis` → `prometheus` (prometheus needs metis output)
- `prometheus` → `momus` (momus needs the plan)
- Any review → fixes based on its findings
