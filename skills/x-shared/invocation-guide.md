# Invocation Guide (Shared)

How to invoke tools from any x-skill.

| What | Tool | Notes |
|------|------|-------|
| **Skills** (superpowers, oh-my-claudecode, x-*) | `Skill` tool | Never `Read` on skill files — Skill tool loads them properly |
| **OMO agents** (explore, oracle, etc.) | `Bash` tool, timeout **600000** | Never Agent/Task tool — silently downgrades to Claude instead of using the target model |
| **OMC agents** (code-reviewer, executor, etc.) | `Agent` tool with `subagent_type` | e.g., `subagent_type="oh-my-claudecode:code-reviewer"` |

## OMO Agent Invocation

```bash
# Role agent
omo-agent <agent-name> "<prompt>"

# Model routing
omo-agent --model <alias> "<prompt>"

# Attach files
omo-agent --file /path/to/file oracle "<prompt>"
```

For the full agent catalog, see the [OMO skill](../x-omo/SKILL.md).

## MANDATORY: Collect All Background Results Before Final Output

When launching agents with `run_in_background: true`, you **MUST** wait for **ALL** agents to complete and collect **ALL** results before generating any synthesis or final output.

**Do NOT:**
- Generate a final answer after only some agents return
- Skip collecting results from slower agents
- Synthesize partial results as the "final" output
- Proceed to the next workflow step until every background agent has returned

**How to collect:**
- **Agent tool** (OMC agents): You receive a notification when each background agent completes. Wait for ALL notifications before proceeding.
- **Bash tool** (OMO agents): Background commands notify on completion. Wait for ALL notifications before proceeding.

**If an agent is slow:** Wait. Do not generate interim results and call them final. The user expects a complete synthesis from all perspectives.
