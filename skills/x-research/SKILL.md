---
name: x-research
description: Use when the user asks to research, investigate, look up, or understand something — orchestrates morph, MCP servers (perplexity/exa/deepwiki/context7), gemini-agent, and OMO agents (explore/librarian/oracle/multimodal-looker) with optional Max Mode for parallel multi-lane synthesis
---

# x-research — Universal Research Orchestrator

x-research is a router. It classifies the question by **information-source signal**, picks the best tool/MCP/agent, and synthesizes findings. It does not redefine tool invocation — those live in linked skills.

## Bootstrap (MANDATORY)

Before dispatching anything, load:

0. `../x-shared/capability-loading.md` — pin the active capability set for this session. Skills MUST NOT re-verify per dispatch; trust the bootstrap-pinned set.
1. `../x-omo/SKILL.md` — OMO agent catalog + Bash invocation patterns. **Do NOT dispatch to `hephaestus`, `atlas`, `prometheus`, `metis`, or `momus` — UNAVAILABLE due to plugin compat bug. Use `--model codex` (autonomous deep work) or `--model gpt` (planning) instead.**
2. `../x-gemini/SKILL.md` — direct Gemini CLI bridge (Google Search grounding, gemini-3.x, `--file`, `--resume`).
3. `../x-shared/mcp-toolbox.md` — plugin-local MCP decision matrix (perplexity / exa / deepwiki / context7 / morph).
4. `gotchas.md` — known failure patterns.

**Bootstrap shortcut:** if the question is a Standard-Mode local-only direct read with no agent dispatch, you may skip step 1 (OMO) and step 2 (gemini). Steps 3 + 4 are always required.

## Mode

| Mode | Trigger | Behavior |
|---|---|---|
| **Standard** | default | Pick the single best tool per signal; escalate only if insufficient |
| **Max** | first/last token `max` or `prism`, OR `--max` flag, OR `ultraresearch` | Fan out across all relevant lanes in parallel; synthesize with reconciliation |

See `references/max-mode.md` for full Max Mode dispatch matrix and synthesis template.

## Depth Calibration (Standard Mode)

Announce depth before dispatching:

| Depth | Signal | Action |
|---|---|---|
| **Light** | Single concept, known area | Direct file reads or one MCP call |
| **Targeted** | Specific investigation, one knowledge domain | Single tool/agent with focused prompt |
| **Deep** | Multi-faceted, cross-domain, ambiguous | Parallel dispatch (escalate to Max Mode) |

Surface as one line: `Depth: Targeted — single-repo architectural overview, one knowledge domain.`

## Detection — Signal → Primary Tool

Pick by **what kind of source** answers the question. Escalation = next column only if primary output is read and judged insufficient.

| Signal | Primary | Escalation |
|---|---|---|
| Local code: "how does our X work" | `morph-mcp` → `codebase_search` | OMO `explore` |
| Local cross-repo (3+ modules tangled) | `morph` + OMO `explore` parallel | — |
| Public repo internals: "how does repo X do Y" | `deepwiki` → `ask_question` | `morph` → `github_codebase_search` → OMO `librarian` |
| Library API usage: "how to call X" | `context7` → `query-docs` | `exa` → `get_code_context_exa` |
| Library current state ("still maintained?", recent changes) | `gemini-agent` (Google Search) | `perplexity_ask` |
| Quick factual lookup: "what is X" | `perplexity_ask` | `gemini-agent` |
| Fresh news / current events | `gemini-agent` | `perplexity_ask` w/ recency filter |
| X vs Y tradeoff (web-grounded) | `perplexity_reason` | OMO `oracle` for arch depth |
| Architecture decision (no web needed) | OMO `oracle` (GPT-5) | + `perplexity_reason` |
| Pre-planning (requirements + risks + code) | OMO `oracle` ∥ `morph` ∥ `perplexity_ask` | — |
| Visual single file (image/PDF/screenshot) | Claude `Read` (small) OR `gemini-agent --file` | OMO `multimodal-looker` |
| Visual cross-file vision reasoning | OMO `multimodal-looker` | — |
| Exhaustive audit (security / architecture review) | `perplexity_research` | + OMO `oracle` |
| Dense code examples from web | `exa` → `get_code_context_exa` | OMO `librarian` |

**Cheapest-viable-first.** Free/instant tools (morph, deepwiki, context7) before token-billed (perplexity, exa) before agent-billed (omo, gemini).

**⛔ HARD GATE — sequencing matters (Standard Mode):** for any signal whose primary is morph or deepwiki, you MUST call the primary AND read its output BEFORE dispatching any agent. Firing agents "in parallel with the primary, just in case" is a violation. "Insufficient" means you READ the output and judged it inadequate. **Max Mode is exempt** — its whole purpose is parallel multi-lane fan-out where the user has accepted the cost.

**Parallel only when axes differ:** morph (local code) ∥ perplexity (web) is fine. morph ∥ OMO `explore` "just in case" is waste.

For prompt templates per tool, see `references/prompt-templates.md`.
For Type A variants (multi-repo, comparison, version upgrade), see `references/type-a-notes.md`.

## Max Mode

Trigger: `/x-research max <question>`, `/x-research prism <question>`, or `/x-research <question> --max`.

Max Mode fans out across all relevant lanes for the question class, then reconciles findings (similar to x-review's multi-reviewer synthesis).

**Cost guard (MANDATORY before dispatch):**

```
Max Mode: <N> lanes — <lane list with rough cost/latency>.
Proceed? [Y/n/standard]
```

User may downgrade to Standard. Skip the prompt only when the user explicitly types `prism!` or `--max-yes`.

See `references/max-mode.md` for the full fan-out matrix per question class and the reconciled-synthesis report template.

## Parallel Execution Rules

Any dispatch of 2+ agents fires `run_in_background: true`. **Wait for every dispatch to reach a terminal state (complete, error, or 5+ minute timeout) before synthesizing** — see `../x-shared/invocation-guide.md` § "Collect All Background Results".

When synthesizing after a partial failure, include only succeeded lanes' findings, name which lanes failed and what is missing, and offer to retry or proceed without.

## Model Routing

Role agents (catalog in `../x-omo/SKILL.md`) cover 95% of needs. Use `omo-agent --model <name>` only for edge cases — see x-omo for current names.

## Synthesis

Standard Mode: see `references/synthesis-rules.md`.
Max Mode: same rules + reconciliation template in `references/max-mode.md`.

## Follow-Up Rounds

- **Refinement** (same signal, narrower scope): answer inline from existing context. No re-dispatch.
- **New axis** (different signal): re-classify and dispatch as needed.
- **System consistency:** within one follow-up round, don't mix OMO and OMC for the same axis.

## After This Skill

If research was preparation for implementation:

> Research complete. Ready to act?
> **[Y]** Start `/x-do` **[P]** Plan first (`superpowers:writing-plans`) **[N]** More research

**Quick-action exception:** when research surfaces a single obvious small fix (<10 lines, one file, no ambiguity) and the user approves inline ("ok", "do it"), apply directly. TS/JS still needs tsc + eslint.

See `../x-shared/workflow-chains.md` and include a `../x-shared/context-envelope.md` block (waived for inline quick-actions and for `[P]` handoffs where synthesis already serves as context).

## Dependencies

- `../x-omo/SKILL.md` — OMO agent runtime (required for any OMO dispatch)
- `../x-gemini/SKILL.md` — gemini-agent runtime (required for Gemini lanes)
- `../x-shared/mcp-toolbox.md` — MCP decision matrix (plugin-local, portable)
- `../x-shared/invocation-guide.md`, `workflow-chains.md`, `context-envelope.md`, `common-gotchas.md`
- Downstream chains: `/x-do`, `superpowers:writing-plans` (research → implementation paths only — `x-skill-improve` does not consume research output)

## Gotchas

See `gotchas.md`.

Task: {{ARGUMENTS}}
