# prometheus — UNAVAILABLE

> ⚠ **DO NOT DISPATCH to `prometheus`.** This agent is currently UNAVAILABLE due to a known opencode + oh-my-opencode plugin compat bug. Any `omo-agent prometheus "..."` call will hard-fail fast with an error.

## Replacement

Use **`omo-agent --model gpt "<plan-author prompt>"`** for structured plan authoring. You're routing directly to GPT-5.4 — supply the plan-author framing (context, requirements, constraints, output structure with tasks + dependencies) in the prompt.

```bash
~/.claude/skills/x-omo/omo-agent --model gpt "Create an implementation plan for: <feature description>. Context: <codebase context, existing patterns, constraints>. Requirements: <specific requirements>. Output a task DAG with: task IDs, descriptions, dependencies, and verification steps for each task."
```

## Historical role

`prometheus` was the OMO strategic-planner role agent: authored structured plans with task DAGs and dependencies, typically consumed by `atlas` for execution. That charter is now handled by `--model gpt` with an explicit plan-author prompt.

## Re-check

Re-probe with `cd /tmp && timeout 30 opencode run --agent prometheus "ping"` after any `opencode upgrade` or oh-my-opencode version bump. See `~/.claude/skills/x-omo/gotchas.md` for the full writeup.
