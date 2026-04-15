# momus — UNAVAILABLE

> ⚠ **DO NOT DISPATCH to `momus`.** This agent is currently UNAVAILABLE due to a known opencode + oh-my-opencode plugin compat bug. Any `omo-agent momus "..."` call will hard-fail fast with an error.

## Replacement

Use **`omo-agent --model gpt "<blocker-finder prompt>"`** for plan review / blocker-finding. You're routing directly to GPT-5.4 — you supply the blocker-finder framing in the prompt.

```bash
omo-agent --model gpt "You are a plan blocker-finder. Review the plan at <plan-path>. Return at most 3 blockers ranked by severity, then OKAY or REJECT. Focus on: missing dependencies, ambiguous success criteria, hidden scope, and verification gaps."
```

Note: unlike the former `momus` agent, `--model gpt` does not auto-load `.sisyphus/plans/*.md` paths. Either embed the plan content in the prompt or pass the plan file via `--file <path>`:

```bash
omo-agent --file /abs/path/to/plan.md --model gpt "<blocker-finder prompt>"
```

## Historical role

`momus` was the OMO plan-reviewer / blocker-finder role agent: max 3 issues, OKAY/REJECT verdict, hard-coded to read plans from `.sisyphus/plans/`. That charter is now handled by `--model gpt` with an explicit blocker-finder prompt.

## Re-check

Re-probe with `cd /tmp && timeout 30 opencode run --agent momus "ping"` after any `opencode upgrade` or oh-my-opencode version bump. See `../gotchas.md` for the full writeup.
