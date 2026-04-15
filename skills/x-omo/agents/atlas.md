# atlas — UNAVAILABLE

> ⚠ **DO NOT DISPATCH to `atlas`.** This agent is currently UNAVAILABLE due to a known opencode + oh-my-opencode plugin compat bug. Any `omo-agent atlas "..."` call will hard-fail fast with an error.

## Replacement

Use **`omo-agent --model codex "<structured plan execution prompt>"`** for plan execution / multi-task orchestration. You'll need to structure the prompt with the plan path, task list, and execution order yourself — `--model codex` does not auto-load `.sisyphus/plans/` paths.

```bash
omo-agent --model codex "<plan execution prompt with embedded plan content>"
```

For plans with many independent tasks, prefer `oh-my-claudecode:ralph` (persistence loop with TDD/verification per story) or `superpowers:subagent-driven-development` (fresh subagent per task).

## Historical role

`atlas` was the OMO plan-executor / orchestrator role agent: consumed plans under `.sisyphus/plans/*.md` and executed them with category-based delegation. That behavior is now accessible through `--model codex` with the plan embedded in the prompt, or (usually better) through native OMC execution skills.

## Re-check

Re-probe with `cd /tmp && timeout 30 opencode run --agent atlas "ping"` after any `opencode upgrade` or oh-my-opencode version bump. See `../gotchas.md` for the full writeup.
