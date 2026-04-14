# OMO Model Routing Reference

*Slim reference for Claude to pick the right `--model` alias. Full benchmarks: `~/.config/opencode/docs/models.md`*

## Quick Decision Matrix


| Task Type                          | Best Model (alias) | Why                                             | Runner-Up      |
| ---------------------------------- | ------------------ | ----------------------------------------------- | -------------- |
| Build React/UI component           | `gemini-flash`     | 218 TPS, cheapest, SWE-bench 78%               | `gemini-pro`   |
| Complex UI logic, SVG, design      | `gemini-pro`       | ARC-AGI-2 #1 (77.1%), strong visual reasoning  | `gemini-flash` |
| Debug backend crash                | `codex`            | Terminal-Bench 77.3%, SWE-bench ~80%            | `gpt`          |
| Deep implementation/refactor       | `codex`            | Agentic-native, 400K context, SWE-bench ~80%   | `gpt`          |
| Architecture review/second opinion | `gpt`              | GDPval 83.0% (#1), OSWorld 75% (#1, >human)    | `gemini-pro`   |
| Research/docs/OSS analysis         | `gemini-flash`     | 1M context, 218 TPS, cheapest                  | `gemini-pro`   |
| Refactor 50+ files                 | `gemini-pro`       | 1M context, MCP Atlas #1, SWE-bench 80.6%      | `gpt`          |
| Fix 100 linter errors (bulk)       | `gemini-flash`     | Fast, cheap, SWE-bench 78%                     | `codex`        |
| Novel logic/reasoning puzzles      | `gemini-pro`       | ARC-AGI-2: 77.1%, GPQA: 94.3%                  | `gpt`          |
| DevOps/Terraform/CI-CD             | `codex`            | Terminal-native, DevOps execution specialist    | `gpt`          |
| Plan review/critique               | `gpt`              | GDPval 83.0% (#1), GPQA ~92%                   | `gemini-pro`   |
| Quick trivial fix                  | Don't use OMO      | Claude Code is faster alone                     | —              |
| Image/PDF analysis                 | Don't use OMO      | Claude Read tool handles vision natively        | —              |


## Model Strengths & Warnings


| Alias          | Full ID        | Strengths                                                    | Avoid For                              |
| -------------- | -------------- | ------------------------------------------------------------ | -------------------------------------- |
| `gemini-pro`   | gemini-3.1-pro | ARC-AGI-2 #1, GPQA #1 (94.3%), MCP Atlas #1, 1M ctx, $2/1M | GDPval expert tasks (Claude leads)     |
| `gemini-flash` | gemini-3-flash | SWE-bench 78%, 218 TPS, $0.50/1M cheapest                   | Deep reasoning, premium quality        |
| `codex`        | gpt-5.3-codex  | Terminal-Bench 77.3%, SWE-bench ~80%, agentic-native, 400K ctx | Simple tasks (overkill)             |
| `gpt`          | gpt-5.4        | GDPval #1 (83.0%), OSWorld #1 (>human), GPQA ~92%, 1M ctx   | Budget work (expensive)                |


## When NOT to Route via OMO

- **Simple single-file edits** → Claude Code alone
- **Tasks needing Claude-specific behavior** → OMC native agents (executor, designer, architect)
- **Image/PDF/visual analysis** → Claude's native Read tool
- **Orchestration/planning** → Claude Code is the orchestrator

## Cost Tiers (input per 1M tokens)


| Tier     | Models               | Range       |
| -------- | -------------------- | ----------- |
| Budget   | gemini-flash         | $0.50       |
| Standard | codex, gemini-pro    | $1.75-$2.00 |
| Premium  | gpt                  | $2.50       |
