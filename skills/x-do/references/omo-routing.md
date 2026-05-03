# OMO Agent Routing for x-do

For the full agent catalog, cost tiers, parallel patterns, OMO tool access, and the unavailable-agent list, see the **[shared routing table](../../x-shared/omo-routing.md)**. This file holds only x-do-specific routing deltas — do not duplicate the shared content here.

## x-do-Specific Routing

| Situation | Route | Why |
|---|---|---|
| Requirements are ambiguous or open-ended | `oracle` (or `superpowers:brainstorming`) | Strategic pre-plan consult on GPT-5.4 (replaces UNAVAILABLE `metis`) |
| Need structured plan with tasks + deps | `--model gpt` with a plan-author prompt | GPT-5.4 raw for plan authoring (replaces UNAVAILABLE `prometheus`) |
| Review plan for blockers before execution | `--model gpt` with a blocker-finder prompt | Max 3 issues, OKAY/REJECT verdict (replaces UNAVAILABLE `momus`) |
| 1-2 standalone complex implementation tasks | `--model codex` | GPT-5.3 Codex for autonomous deep work (replaces UNAVAILABLE `hephaestus`) |
| Fresh perspective after stalled debugging | `oracle` | Read-only strategic advice |
