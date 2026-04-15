# hephaestus — UNAVAILABLE

> ⚠ **DO NOT DISPATCH to `hephaestus`.** This agent is currently UNAVAILABLE due to a known opencode + oh-my-opencode plugin compat bug (the plugin remaps the config key to a parenthesized display name that opencode's `--agent` lookup cannot resolve). Any `omo-agent hephaestus "..."` call will hard-fail fast with an error.

## Replacement

Use **`omo-agent --model codex "<structured prompt>"`** for autonomous deep implementation work. This gets you the same underlying model (GPT-5.3 Codex) without the broken plugin shim. Pass the full context, goal, constraints, existing code, expected output, verification steps, and output format in the prompt.

```bash
~/.claude/skills/x-omo/omo-agent --model codex "<structured prompt>"
```

## Historical role

`hephaestus` was the OMO autonomous deep-worker role agent: one-shot implementation of 1-2 standalone complex tasks, explores before acting, runs its own verification. All of that behavior is now accessible through `--model codex` with a structured prompt — the only thing lost is the agent-level system prompt the plugin used to inject.

## Re-check

Re-probe with `cd /tmp && timeout 30 opencode run --agent hephaestus "ping"` after any `opencode upgrade` or oh-my-opencode version bump. If it returns successfully, clear the `OMO_BROKEN_AGENTS` entry in `~/.claude/skills/x-omo/omo-agent` and remove this stub. See `~/.claude/skills/x-omo/gotchas.md` for the full writeup.
