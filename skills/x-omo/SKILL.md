---
name: x-omo
description: OpenCode multi-model agents — route to non-Claude models via opencode CLI
triggers:
  - "omo"
  - "opencode agent"
  - "opencode oracle"
  - "opencode explore"
  - "opencode librarian"
  - "use oracle"
  - "use gemini"
  - "use codex"
  - "ask gpt"
  - "ask gemini"
  - "ask codex"
  - "ask opencode"
  - "multi-model"
matching: fuzzy
---

# OMO Agents — OpenCode Multi-Model Bridge

OMO bridges Claude Code to non-Claude models via OpenCode's agent system. Each agent has a specialized role, prompt structure, and output format. This skill routes by agent role, not by model.

## Quick Dispatch

If `{{ARGUMENTS}}` starts with an agent name or `--model`, invoke it immediately via Bash — no deliberation needed:

```
/omo oracle "prompt"              → Bash: omo-agent oracle "prompt"
/omo explore "search query"       → Bash: omo-agent explore "search query"
/omo --model gpt "prompt"         → Bash: omo-agent --model gpt "prompt"
/omo --file img.png oracle "prompt" → Bash: omo-agent --file img.png oracle "prompt"
/omo                              → show agent catalog below for selection
```

**Rule:** If the first arg matches an agent name (`oracle`, `explore`, `librarian`, `multimodal-looker`) or is `--model`/`--file`, run `~/.claude/skills/x-omo/omo-agent` with all args directly. Do not ask which agent — the user already chose.

---

## Agent Catalog

| Agent | Role | Model | Cost | Reference |
|---|---|---|---|---|
| `oracle` | Read-only strategic advisor | GPT-5.4 max | EXPENSIVE | [agents/oracle.md](agents/oracle.md) |
| `explore` | Contextual codebase search | Gemini 3 Flash | FREE | [agents/explore.md](agents/explore.md) |
| `librarian` | External docs & OSS research | Gemini 3 Flash | CHEAP | [agents/librarian.md](agents/librarian.md) |
| `multimodal-looker` | Visual & document analysis | Gemini 3.1 Pro | CHEAP | [agents/multimodal-looker.md](agents/multimodal-looker.md) |

---

## When to Use Which Agent

| You Need | Agent | Why |
|---|---|---|
| Find code in the codebase | `explore` | Parallel multi-tool search, returns absolute paths |
| Look up library docs / OSS source | `librarian` | Classifies request type, uses optimal tool chain |
| Architecture/debugging advice | `oracle` | Read-only, pragmatic minimalism, effort-tagged |
| Analyze images/PDFs/diagrams | `multimodal-looker` | Gemini vision, extracts specific info from media |
| Use a specific non-Claude model | `--model <alias>` | Direct model access, you control the prompt |

### User Intent Routing

| User Says | Route To | Why |
|---|---|---|
| "ask gemini about our code/codebase" | `explore` | Codebase search specialist |
| "ask gemini about [library/framework]" | `librarian` | External docs specialist |
| "ask gemini to build/implement ..." | `--model gemini-pro` | Direct model for implementation |
| "ask codex to build/implement ..." | `--model codex` | Direct model for autonomous coding |
| "ask gpt about architecture/design" | `oracle` | Strategic advisor on GPT-5.4 max |
| "use [model] for this" | `--model <alias>` | Direct model access |

---

## Model Routing

Use when you need a **specific model** rather than a role-based agent.

```bash
~/.claude/skills/x-omo/omo-agent --model <alias> "<prompt>"
```

| Alias | Resolves To | Best For |
|---|---|---|
| `gemini-pro` | Gemini 3.1 Pro | Visual/UI work, multimodal, creative |
| `gemini-flash` | Gemini 3 Flash | Fast search, lightweight tasks |
| `codex` | GPT-5.3 Codex | Deep implementation, autonomous coding |
| `gpt` | GPT-5.4 | Architecture, reasoning, review |
| Any partial ID | Fuzzy-matched via `opencode models` | e.g., `gpt-5.4-mini`, `big-pickle` |
| Full `provider/model` | Passthrough | e.g., `openai/gpt-5.4` |

See `~/.claude/skills/x-omo/models-routing.md` for detailed task-to-model mapping.

---

## How to Invoke

All agents are invoked via Bash with the `omo-agent` wrapper. **Do not use `spawn_agent`** — it only uses Claude and cannot access OMO's non-Claude models.

### Run Command

```bash
# Role agent
~/.claude/skills/x-omo/omo-agent <agent-name> "<prompt>"

# Model routing
~/.claude/skills/x-omo/omo-agent --model <alias> "<prompt>"

# Attach files
~/.claude/skills/x-omo/omo-agent --file /path/to/file.pdf oracle "<prompt>"

# Attach skill directory
~/.claude/skills/x-omo/omo-agent --skill /path/to/skill/ oracle "<prompt>"
```

**Timeout:** Always set Bash timeout to **600000** (10 min). Agents routinely take 1-5 minutes.

### Parallel Agents (max 3 concurrent)

Fire multiple Bash tool calls simultaneously with `run_in_background: true`. Always collect all results before synthesizing.

**Standard parallel patterns:**

| Pattern | Agents | When |
|---|---|---|
| Research | `explore` + `librarian` | Need both codebase + external docs |
| Visual + context | `multimodal-looker` + `explore` | Image/PDF input + related code |
| Code review | OMC code-reviewer + `--model gpt` | Claude + GPT-5.4 cross-model review |

```bash
# Example: parallel research
~/.claude/skills/x-omo/omo-agent explore "<prompt>"    # run_in_background: true
~/.claude/skills/x-omo/omo-agent librarian "<prompt>"  # run_in_background: true
# Collect both results before synthesizing
```

**Never parallelize sequential deps:**
- Any review → fixes based on its findings

### Execution Mode (Foreground vs Background)

When invoking a single agent, choose execution mode based on the task shape:

| Signal | Mode | Why |
|---|---|---|
| Single focused question (oracle, librarian) | **Foreground** | Fast, bounded, result needed immediately |
| Quick codebase search (explore) | **Foreground** | Usually <60s |
| Parallel agents (any 2+) | **Background** (`run_in_background: true`) | Always background for parallelism |

**User override:** If the user says `--background` or `--wait`, respect that over the heuristic.

**x-skill default:** When an x-skill dispatches agents, it should use foreground for single-agent queries and background only for parallel dispatch or explicitly long-running runs (e.g. `--model codex` autonomous deep work).

### Model Routing Prompt Tips

When using `--model`, include output instructions in your prompt:

```
"[Your task description].

OUTPUT: Return ONLY the final answer as structured markdown. Do not include intermediate tool output. Do not delegate to other agents — answer directly."
```

### Prompt Composition (Optional)

For complex or multi-step prompts, compose from reusable XML blocks instead of writing ad-hoc instructions. See [references/prompt-blocks.md](references/prompt-blocks.md) for the full block library and task-type selection guide.

**Quick reference — which blocks for which task:**

| Sending to | Task | Blocks to add |
|---|---|---|
| `oracle` | Debug escalation | `task` + `completeness_contract` + `verification_loop` + `missing_context_gating` |
| `oracle` | Architecture advice | `task` + `grounding_rules` + `compact_output_contract` |
| `librarian` | Research | `task` + `research_mode` + `citation_rules` |
| `--model gpt` | Code review | `task` + `grounding_rules` + `structured_output_contract` + `dig_deeper_nudge` |
| `--model codex` | Implementation | `task` + `action_safety` + `default_follow_through_policy` + `completeness_contract` |

These blocks are guidance for prompt construction — they do NOT replace the `[OUTPUT FORMAT]` suffix that omo-agent auto-appends.

### Error Handling

- Exit 0 = success, non-zero = failure
- "agent not found" / "is a subagent" = agent name issue → use one of: oracle, explore, librarian, multimodal-looker
- "Unknown agent" = not in valid list → see Agent Catalog above
- "default agent not found" = plugin compat issue → model mode uses `--pure` to avoid this
- Timeout = prompt too broad → break into smaller prompts

### After Collecting Results

- **Synthesize** — extract key findings, never dump raw output
- **Lead with the answer** — conclusion first, details after
- **Cite evidence** — reference specific facts, URLs, file paths
- **Flag uncertainty** — note hedging or contradictions
- If an agent modified files, verify (tests, diagnostics)
- Contradictions between agents = flag for user decision

---

Task: {{ARGUMENTS}}
