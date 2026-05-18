# x-omo — OpenCode Bridge

> **Purpose:** Bridges Claude Code to non-Claude models via OpenCode CLI. Routes by agent role, not by model.

---

## Agent Catalog

| Agent | Role | Model | Cost | Best For |
|-------|------|-------|------|----------|
| `oracle` | Read-only strategic advisor | configurable | EXPENSIVE | Architecture/debugging advice |
| `explore` | Contextual codebase search | Configured in `oh-my-openagent.json` | FREE | Find code in codebase |
| `librarian` | External docs & OSS research | Configured in `oh-my-openagent.json` | CHEAP | Look up library docs |
| `multimodal-looker` | Visual & document analysis | Gemini 3.1 Pro | CHEAP | Analyze images/PDFs/diagrams |

---

## Model Routing

```bash
omo-agent --model <alias> "<prompt>"
```

| Alias | Resolves To | Best For |
|-------|-------------|----------|
| `gemini-pro` | Gemini 3.1 Pro | Visual/UI work, multimodal, creative |
| `gemini-flash` | Gemini 3 Flash | Fast search, lightweight tasks |
| `codex` | GPT-5.3 Codex | Deep implementation, autonomous coding |
| `gpt` | GPT-5.5 | Architecture, reasoning, review |

---

## Invocation Rules

- All agents invoked via **Bash** with `omo-agent` wrapper
- **Never use `spawn_agent`** — it only uses Claude
- Timeout: Always set Bash timeout to **600000** (10 min)
- **Parallel agents (max 3 concurrent):** Fire multiple Bash calls with `run_in_background: true`
- Collect ALL results before synthesizing

---

## Standard Parallel Patterns

| Pattern | Agents | When |
|---------|--------|------|
| Research | `explore` + `librarian` | Need both codebase + external docs |
| Visual + context | `multimodal-looker` + `explore` | Image/PDF input + related code |
| Code review | OMC code-reviewer + `--model gpt` | Claude + GPT-5.5 cross-model review |

---

## Gotchas

- `hephaestus`, `atlas`, `prometheus`, `metis`, `momus` are **UNAVAILABLE** due to plugin compat bug
- Use `--model codex` (replaces `hephaestus`) or `--model gpt` (replaces `prometheus`/`momus`) instead
- `omo-agent` requires `--pure` flag for model mode when default agent not found
