# OMO Agent Routing for x-do

For the full agent catalog, cost tiers, parallel patterns, OMO tool access, and the unavailable-agent list, see the **[shared routing table](../../x-shared/omo-routing.md)**. This file holds only x-do-specific routing deltas — do not duplicate the shared content here.

## x-do-Specific Routing

> Replacement mapping for UNAVAILABLE role agents (`metis`, `prometheus`, `momus`, `hephaestus`) lives in **[../../x-shared/omo-routing.md § Unavailable Agents](../../x-shared/omo-routing.md#unavailable-agents)**. Do not re-inline that mapping here.

| Situation | Route | Why |
|---|---|---|
| Requirements are ambiguous or open-ended | `oracle` (or `superpowers:brainstorming`) | Strategic pre-plan consult on GPT-5.4 |
| Need structured plan with tasks + deps | `--model gpt` with a plan-author prompt | GPT-5.4 raw for plan authoring |
| Review plan for blockers before execution | `--model gpt` with a blocker-finder prompt | Max 3 issues, OKAY/REJECT verdict |
| 1-2 standalone complex implementation tasks | `--model codex` | GPT-5.3 Codex for autonomous deep work |
| Fresh perspective after stalled debugging | `oracle` | Read-only strategic advice |
