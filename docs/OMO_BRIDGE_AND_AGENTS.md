# OMO Bridge and Agents

The OMO (OpenCode Multi-Model Orchestration) bridge enables x-skills to dispatch work to non-Claude models (GPT-5.5, Gemini, Codex) via the OpenCode CLI. This is the primary mechanism for cross-model review, specialized reasoning, and autonomous deep work.

## Architecture

```
Claude Code skill
    │
    ├─── Skill tool ──→ Other skills
    ├─── Agent tool ──→ OMC agents (code-reviewer, executor)
    └─── Bash tool ──→ omo-agent ──→ OpenCode CLI ──→ GPT-5.5 / Gemini / Codex
```

**Critical rule**: OMO agents are invoked via `Bash` tool, not `Agent` tool. Using `Agent` tool for OMO silently downgrades to Claude instead of using the target model.

## Agent Catalog

Only these 4 role agents are safe to dispatch. Five other agents are **UNAVAILABLE** due to a known plugin compatibility bug.

| Agent | Role | Model | Cost | Best For |
|-------|------|-------|------|----------|
| `oracle` | Read-only strategic advisor | configurable | EXPENSIVE | Architecture trade-offs, debugging advice, plan review |
| `explore` | Contextual codebase search | Configured in `oh-my-openagent.json` | FREE | Find code patterns, conventions, file paths |
| `librarian` | External docs & OSS research | Configured in `oh-my-openagent.json` | CHEAP | Library docs, API patterns, OSS internals |
| `multimodal-looker` | Visual & document analysis | Gemini 3.1 Pro | CHEAP | Image, PDF, screenshot, diagram input |

### UNAVAILABLE Agents (Do Not Dispatch)

| Agent | Former Role | Replacement |
|-------|-------------|-------------|
| `hephaestus` | Autonomous deep worker | `--model codex` |
| `atlas` | Plan executor | `--model codex` |
| `prometheus` | Structured planner | `--model gpt` or `oracle` |
| `metis` | Pre-planning / intent analysis | `oracle` or `--model gpt` |
| `momus` | Plan reviewer / blocker-finder | `--model gpt` |

## Invocation Syntax

### Role Agents

```bash
# Basic role agent dispatch
omo-agent <agent-name> "<prompt>"

# With file attachment
omo-agent --file /path/to/file.pdf oracle "<prompt>"

# With skill directory attachment
omo-agent --skill /path/to/skill/ oracle "<prompt>"
```

### Model Routing

```bash
# Direct model access
omo-agent --model <alias> "<prompt>"

# With file attachment
omo-agent --file img.png --model gpt "<prompt>"
```

| Alias | Resolves To | Best For |
|-------|-------------|----------|
| `gemini-pro` | Gemini 3.1 Pro | Visual/UI work, multimodal, creative |
| `gemini-flash` | Gemini 3 Flash | Fast search, lightweight tasks |
| `codex` | GPT-5.3 Codex | Deep implementation, autonomous coding |
| `gpt` | GPT-5.5 | Architecture, reasoning, review |
| Any partial ID | Fuzzy-matched via `opencode models` | e.g., `gpt-5.5-pro` |
| Full `provider/model` | Passthrough | e.g., `openai/gpt-5.5` |

### Quick Dispatch in x-omo

If the user invokes `/x-omo` with an agent name or `--model` as the first argument, x-omo dispatches immediately without deliberation:

```
/omo oracle "prompt"              → Bash: omo-agent oracle "prompt"
/omo explore "search query"       → Bash: omo-agent explore "search query"
/omo --model gpt "prompt"         → Bash: omo-agent --model gpt "prompt"
/omo --file img.png oracle "prompt" → Bash: omo-agent --file img.png oracle "prompt"
```

## Execution Modes

| Signal | Mode | Why |
|--------|------|-----|
| Single focused question (oracle, librarian) | **Foreground** | Fast, bounded, result needed immediately |
| Quick codebase search (explore) | **Foreground** | Usually <60s |
| Parallel agents (any 2+) | **Background** (`run_in_background: true`) | Always background for parallelism |

**Timeout**: Always set Bash timeout to **600000** (10 min). Agents routinely take 1-5 minutes.

**User override**: If user says `--background` or `--wait`, respect that over the heuristic.

## Parallel Patterns

Max 3 concurrent OMO agents. Standard patterns:

| Pattern | Agents | When |
|---------|--------|------|
| Research | `explore` + `librarian` | Need both codebase + external docs |
| Visual + context | `multimodal-looker` + `explore` | Image/PDF input + related code |
| Code review | OMC `code-reviewer` + `--model gpt` | Claude + GPT-5.5 cross-model review |
| Pre-planning | `oracle` + `explore` | Strategic framing + codebase context |

**Never parallelize sequential deps**:
- Any review → fixes based on its findings
- `--model codex` implementation → verification pass

## Prompt Composition

For complex prompts, compose from reusable XML blocks:

| Sending to | Task | Blocks to add |
|------------|------|---------------|
| `oracle` | Debug escalation | `task` + `completeness_contract` + `verification_loop` + `missing_context_gating` |
| `oracle` | Architecture advice | `task` + `grounding_rules` + `compact_output_contract` |
| `librarian` | Research | `task` + `research_mode` + `citation_rules` |
| `--model gpt` | Code review | `task` + `grounding_rules` + `structured_output_contract` + `dig_deeper_nudge` |
| `--model codex` | Implementation | `task` + `action_safety` + `default_follow_through_policy` + `completeness_contract` |

These blocks live in `skills/x-omo/references/prompt-blocks.md`.

## Model Routing Prompt Tips

When using `--model`, include output instructions:

```
"[Your task description].

OUTPUT: Return ONLY the final answer as structured markdown. Do not include intermediate tool output. Do not delegate to other agents — answer directly."
```

## After Collecting Results

1. **Synthesize** — extract key findings, never dump raw output
2. **Lead with the answer** — conclusion first, details after
3. **Cite evidence** — reference specific facts, URLs, file paths
4. **Flag uncertainty** — note hedging or contradictions
5. **Verify changes** — if an agent modified files, run tests/diagnostics
6. **Flag contradictions** — between agents = flag for user decision

## Error Handling (x-omo)

| Symptom | Meaning | Recovery |
|---------|---------|----------|
| Exit 0 | success | continue |
| Exit non-zero | generic failure | check raw log |
| "agent not found" / "is a subagent" | agent name issue → use one of: oracle, explore, librarian, multimodal-looker | verify agent catalog |
| "Unknown agent" | not in valid list → see Agent Catalog above | use a valid agent name |
| "default agent not found" | plugin compat issue → model mode uses `--pure` to avoid this | use `--model` with `--pure` flag |
| Timeout | prompt too broad → break into smaller prompts | split prompt, reduce scope |

| Exit Code | Meaning | Recovery |
|-----------|---------|----------|
| `0` | success | continue |
| `1` | generic failure | check raw log |
| `42` | empty prompt | non-issue, validation |
| `124` | timeout | shorten prompt or increase `GEMINI_TIMEOUT` |
| non-zero + "exhausted/quota" | rate limited | wait or switch to `flash` |
| non-zero + "auth/sign in" | not logged in | run `gemini` interactively to auth |

## x-gemini — Direct Gemini CLI Bridge

x-gemini bypasses OpenCode entirely and wraps the official `gemini` CLI directly.

### Why x-gemini Instead of x-omo

| Use Case | Why x-gemini |
|----------|-------------|
| Need fresh web facts with citations | Native Google Search grounding |
| Quick factual lookup, want low latency | Skips opencode routing layer |
| Want `gemini-3.1-pro-preview` specifically | Direct model access |
| Multi-turn research session | `--resume` keeps conversation context |
| Analyze a workspace file | `@file` reference works for any file under CWD |

### Models

| Alias | Resolves To | Best For |
|-------|-------------|----------|
| `flash` (default) | `gemini-2.5-flash` | Fast lookups, classification, summaries |
| `pro` | `gemini-3.1-pro-preview` | Reasoning, deep analysis, multimodal |

### Invocation

```bash
# Basic
gemini-agent "Research topic X"

# Specific model
gemini-agent --model pro "Complex reasoning task"

# Custom system prompt
gemini-agent --system /path/to/system.md "Analyze this"

# Workspace file
gemini-agent --file ./README.md "Summarize this project"

# Resume last session
gemini-agent --resume "Follow-up: how does it differ from approach Y?"

# Streaming for long tasks
gemini-agent --stream "Deep research with multiple tool calls..."

# Tool execution allowed (plan mode)
gemini-agent --approval-mode plan "List files in current dir"

# Autonomous tool execution (yolo mode — DANGER)
gemini-agent --yolo "Set up the project and run tests"

# Raw text passthrough
gemini-agent --raw "Plain text response"
```

### Output

`stdout`: Gemini's response as plain markdown.

`stderr` (last line):
```
[gemini-agent] pro | duration=12s | status=success | model=gemini-3.1-pro-preview | tools=2 | session=<uuid> | raw=/tmp/gemini-agent-...log
```

Capture the session ID for `--resume`. Full raw JSON is at the `raw=` path.

### Error Handling (x-gemini)

| Exit Code | Meaning | Recovery |
|-----------|---------|----------|
| `0` | success | continue |
| `1` | generic failure | check raw log |
| `42` | empty prompt (input error) | non-issue, validation |
| `124` | timeout (killed by `timeout` cmd) | shorten prompt or `GEMINI_TIMEOUT=1200 ...` |
| non-zero + "exhausted/quota" | rate limited | wait or switch to `flash` |
| non-zero + "auth/sign in" | not logged in | run `gemini` interactively to auth |
## Cost Tiers

| Tier | Meaning | Examples |
|------|---------|----------|
| **FREE** | Uses Claude's native tools only | `explore` |
| **CHEAP** | External API call, <$0.01, <30s | `librarian`, `multimodal-looker`, `gemini-agent` |
| **EXPENSIVE** | Specialized agent or top-tier model, 1-5 min, >$0.10 | `oracle`, `--model gpt`, `--model codex` |

## OMO Tool Access

Verified via `opencode mcp list`:

**Available MCP servers**: exa (full suite), perplexity (full suite), engram.

**Built-in tools**: grep, glob, bash, read, write, edit, webfetch, websearch, codesearch.

**Not available in OMO**: deepwiki, context7, playwright, github MCP, atlassian, shadcn, pm2, webstorm. Use OMC agents (Agent tool) for these.
