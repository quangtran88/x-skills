# metis — UNAVAILABLE

> ⚠ **DO NOT DISPATCH to `metis`.** This agent is currently UNAVAILABLE due to a known opencode + oh-my-opencode plugin compat bug. Any `omo-agent metis "..."` call will hard-fail fast with an error.

## Replacement

Use **`omo-agent oracle "<pre-planning consult prompt>"`** for pre-planning intent classification and scope-risk analysis. `oracle` runs on GPT-5.4 max and gives you read-only strategic advice — effectively the same role as metis with a broader charter. If you want raw GPT without oracle's framing, use `omo-agent --model gpt "<prompt>"`.

```bash
omo-agent oracle "Analyze this request before planning: '<user request>'. Current context: <codebase/stack/constraints>. What hidden requirements, scope risks, and AI-slop patterns should we address before planning?"
```

## Historical role

`metis` was the OMO pre-planning consultant role agent: intent classification, scope analysis, hidden-requirement surfacing before a plan was authored. That charter now belongs to `oracle` (which is structurally read-only and well-suited to strategic consult).

## Re-check

Re-probe with `cd /tmp && timeout 30 opencode run --agent metis "ping"` after any `opencode upgrade` or oh-my-opencode version bump. See `../gotchas.md` for the full writeup.
