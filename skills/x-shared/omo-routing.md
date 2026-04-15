# OMO Agent Routing (Shared)

Canonical routing table for all x-skills. For full agent catalog and invocation syntax, see the [OMO skill](~/.claude/skills/x-omo/SKILL.md).

> ⚠ **DO NOT DISPATCH to `hephaestus`, `atlas`, `prometheus`, `metis`, `momus`.** These 5 agents are UNAVAILABLE due to a known opencode + oh-my-opencode plugin compat bug and will hard-fail with an explicit error. The **only** OMO role agents safe to call are the four listed below. For the tasks those broken agents used to handle, use direct model routing: `--model codex` (autonomous deep work, formerly hephaestus/atlas), `--model gpt` (plan review / blocker-finder, formerly momus; strategic planning, formerly prometheus/metis), or fall through to `oracle` for strategic advice. See `~/.claude/skills/x-omo/gotchas.md` for the root cause and upstream-fix watch.

## Agent Catalog

| Agent | Role | Cost | Best For |
|---|---|---|---|
| `explore` | Contextual codebase search | FREE | Find code patterns, conventions, file paths |
| `librarian` | External docs & OSS research | CHEAP | Library docs, API patterns, OSS internals |
| `oracle` | Read-only strategic advisor | EXPENSIVE | Architecture trade-offs, debugging advice, plan review |
| `multimodal-looker` | Visual & document analysis | CHEAP | Image, PDF, screenshot, diagram input |

## Model Routing (replaces broken role agents)

When you would have reached for a broken role agent, use direct model routing instead:

| Former role agent | Replacement | Why |
|---|---|---|
| `metis` (pre-planning / intent) | `oracle` or `--model gpt` | Strategic pre-plan consult |
| `prometheus` (structured planner) | `--model gpt` or `oracle` | GPT-5.4 for plan authoring |
| `momus` (plan reviewer / blocker-finder) | `--model gpt` | GPT-5.4 raw with blocker-finder prompt |
| `hephaestus` (autonomous deep worker) | `--model codex` | GPT-5.3 Codex for deep implementation |
| `atlas` (plan executor) | `--model codex` | GPT-5.3 Codex for multi-task execution |

Invocation: `~/.claude/skills/x-omo/omo-agent --model <alias> "<prompt>"` — see `~/.claude/skills/x-omo/models-routing.md`.

## OMO Tool Access (Verified via `opencode mcp list`)

**MCP servers:** exa (full suite), perplexity (full suite), engram. **Built-in tools:** grep, glob, bash, read, write, edit, webfetch, websearch, codesearch. `explore` agent is read-only.

**Not available:** deepwiki, morph-mcp, context7 (skill-level, uncertain loading), playwright, github MCP, atlassian, shadcn, pm2, webstorm. Use OMC agents (Agent tool) for these.

## Cost Tiers

| Tier | Meaning | Examples |
|------|---------|----------|
| **FREE** | Uses Claude's native tools only | `explore` |
| **CHEAP** | External API call, <$0.01, <30s | `librarian`, `multimodal-looker` |
| **EXPENSIVE** | Specialized agent or top-tier model, 1-5 min, >$0.10 | `oracle`, `--model gpt`, `--model codex` |

## Parallel Combinations

These are independent and can run simultaneously (`run_in_background: true`, max 3 concurrent):

| Pattern | Agents | When |
|---|---|---|
| Research | `explore` + `librarian` | Codebase + external docs needed |
| Pre-planning | `oracle` + `explore` | Strategic framing + codebase context |
| Plan review | `--model gpt` + OMC `code-reviewer` | Cross-model review of a complex plan |
| Visual + context | `multimodal-looker` + `explore` | Image input + related code lookup |
| Code review | OMC `code-reviewer` + `--model gpt` | Claude + GPT cross-model review |

## Sequential Dependencies (Never Parallelize)

- Any review → fixes based on its findings
- `--model codex` implementation → verification pass
