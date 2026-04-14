---
name: x-research
description: Use when the user asks to research, investigate, look up, or understand something — auto-routes to OMO/OMC agents (explore, librarian, oracle, metis) with parallel execution and synthesis
---

# x-research — Universal Research Command

Smart research that classifies the question and routes to the optimal agent(s).

## Bootstrap

**MANDATORY first step — do this BEFORE anything else:**

### 1. Feature Gate — detect capabilities

```bash
cat ~/.config/x-skills/capabilities.json 2>/dev/null || echo '{"capabilities":{}}'
```

Parse the result to determine available capabilities. If the file doesn't exist, assume Claude-only mode. See `../../lib/feature-gate.md` for the full fallback table.

**Key checks:**
- `capabilities.opencode == true` → OMO agents available, load x-omo catalog (step 2)
- `capabilities.opencode == false` → Claude-only mode, use fallback routing:
  - Replace `explore` → `Agent` tool with `subagent_type=Explore`
  - Replace `librarian` → `Agent` tool with web search MCP tools (perplexity, exa)
  - Replace `oracle` → `Agent` tool with `model=opus`
  - Replace `multimodal-looker` → `Read` tool directly (Claude is multimodal)
- MCP availability is checked per-server — degrade gracefully per missing MCP

### 2. Load OMO catalog (skip if Claude-only)

Read the OMO skill file (`config.json` → `omo_skill`) **and** `gotchas.md` to load the full agent catalog, invocation commands, model routing, and known failure patterns. This ensures you know how to invoke OMO agents (explore, librarian, oracle, metis, multimodal-looker) via Bash — they are NOT OMC agents — and avoid recurring pitfalls.

**Exception — when OMO bootstrap can be skipped:**

| Scenario | Bootstrap needed? |
|----------|-------------------|
| Type A direct reads, no agents dispatched | No — Claude reads files directly |
| Multi-repo Type A with OMC Explore agents | No — OMC agents don't use OMO config |
| Type E with OMC Explore + deepwiki MCP | No — OMC agents don't use OMO config |
| Claude-only mode (opencode unavailable) | No — all routing uses native Agent tool |
| Any workflow dispatching OMO agents | **Yes** — always bootstrap first |

## Invocation

For how to invoke skills, OMO agents, and OMC agents, see `../x-shared/invocation-guide.md`.

## Depth Calibration

Before classifying, assess question complexity to right-size research effort:

| Depth | Signal | Dispatch |
|-------|--------|----------|
| **Light** | Single concept, known area, quick lookup | Direct reads or single focused agent |
| **Targeted** | Specific investigation, one knowledge domain | Single agent with focused prompt |
| **Deep** | Multi-faceted, cross-domain, ambiguous | Parallel agents + supplementary tools |

Don't over-research simple questions. A "light" question answered in 30 seconds is better than a "deep" investigation that takes 5 minutes for the same answer.

**Announce the depth.** Before dispatching anything, surface your assessment in one line so the user (and the execution trace) can see it:

> `Depth: Targeted — single-repo architectural overview, one knowledge domain.`

This makes over-research auditable. A single-repo "what is this?" question declared as Deep with 2 parallel agents is a flag to reconsider.

## Detection

Classify the user's question:

| Type | Detect When | Route To |
|------|------------|----------|
| **A: Codebase** | About existing code, patterns, how something works | `morph-mcp codebase_search` first; `explore` only if semantic search insufficient (see note below) |
| **B: External Docs** | About a library, framework, API, tool | `librarian` |
| **C: Architecture** | Trade-offs, system design, "should we" | `oracle` |
| **D: Both** | Codebase + external best practices | `morph-mcp codebase_search` + `librarian` parallel |
| **E: OSS Internals** | How an open-source project implements something | `morph-mcp github_codebase_search` first; OMC Explore w/ `deepwiki` MCP for deeper understanding (see note below) |
| **F: Pre-Planning** | Requirements, scope, risks before building | `metis` + `morph-mcp codebase_search` parallel |
| **G: Visual** | Image, PDF, diagram, screenshot analysis | `multimodal-looker` |

**Morph-first principle:** For Types A, D, E, and F, try `morph-mcp codebase_search` (or `github_codebase_search` for external repos) before spawning agents. It's semantic, instant, and free — no agent overhead. Escalate to explore/librarian agents only when morph results are insufficient (too broad, need multi-tool investigation, or require cross-referencing with external docs).

**⛔ HARD GATE — sequencing matters:** For Types A/D/E/F, you MUST have called morph AND observed its results before dispatching any agent. Firing agents "in parallel with morph, just in case" is a violation — it wastes tool calls and defeats the point of the principle. "Insufficient" means you READ morph's output and judged it inadequate; it does NOT mean "failed auth" or "might be better with an agent."

### Type E: OSS Internals Routing

**First:** Try `morph-mcp github_codebase_search` — it provides semantic code search across public GitHub repos without cloning. Fast and often sufficient for "where does repo X do Y?" questions.

**STOP** — Before proceeding below, confirm you actually called morph and read its output. Do not dispatch agents "in parallel with morph, just in case."

**Deeper:** If morph results are genuinely insufficient (not just "maybe an agent would be better"), dispatch an **OMC Explore agent** (`Agent` tool, `subagent_type: "Explore"`, `run_in_background: true`) with instructions to use `mcp__deepwiki__ask_question`. deepwiki has pre-indexed AI documentation for public GitHub repos — it answers "how does repo X implement Y?" in seconds with architectural understanding.

**Fallback:** If both morph and deepwiki are insufficient, fall back to **OMO `librarian`** with TYPE B hint. Librarian clones repos and greps source — slower but works for any public repo and provides exact GitHub permalinks.

For morph auth-error handling (distinct from "insufficient results"), see `gotchas.md`.

For prompt templates per type, see `references/prompt-templates.md`.

For Type A variants (local repos, multi-repo, comparison, version upgrade), see `references/type-a-notes.md`.

## Parallel Execution

Any dispatch of 2+ agents fires simultaneously (`run_in_background: true`). Common multi-agent combos: D (explore + librarian), F (metis + explore), multi-repo Type A, and mixed types like B+C (librarian + oracle).

**⛔ MANDATORY — wait for every agent to reach a terminal state before synthesizing.** A terminal state is one of: **complete** (notification received, output collected), **error** (agent returned a failure), or **timeout** (no response after 5+ minutes). Do NOT generate synthesis while any agent is still in "running" state. See `../x-shared/invocation-guide.md` § "Collect All Background Results."

When synthesizing after a failure/timeout, include **only** the succeeded agents' findings, note which agents failed and what information is missing, and offer to retry the failed agent or answer without it. Partial synthesis is allowed, but only after each dispatched agent has a known terminal state.

Example: `omo-agent explore "find auth patterns"` (Bash tool, timeout 600000)

## Model Routing

Role agents (Types A-G) cover 95% of research. Use `--model` only for edge cases — check the OMO skill file (`config.json` → `omo_skill`) for current model names and capabilities.

## Supplementary External Research

For deeper research, dispatch OMC agents (Agent tool, `subagent_type: "Explore"`) in parallel with primary OMO agents to access MCP tools that OMO agents cannot reach. OMO agents only have 3 built-in MCPs (context7, websearch_exa, grep_app). OMC agents have access to ALL session MCP tools.

| Research Need | MCP Tool | Dispatch Via | When to Add |
|---|---|---|---|
| OSS repo internals | `mcp__deepwiki__ask_question` | OMC Explore agent | Type E primary (see above) |
| Dense code examples | `mcp__exa__get_code_context_exa` | OMC Explore agent | Types B, D, E when real-world usage examples needed |
| X vs Y tradeoff | `mcp__perplexity__perplexity_reason` | OMC Explore agent | Type C supplement for web-grounded comparison |
| Quick factual check | `mcp__perplexity__perplexity_ask` | OMC Explore agent | Any type, fast verification of claims |
| Exhaustive analysis | `mcp__perplexity__perplexity_research` | OMC Explore agent | Security/architecture audits only (slow, 60-120s) |

**Rules:**
- Run supplements **in parallel** with primary agents — don't block on them
- Supplements are additive — they enrich primary agent findings, not replace them
- `perplexity_ask` handles 80% of supplementary queries — use `perplexity_research` sparingly
- OMC agents need `ToolSearch` to fetch MCP tool schemas before invoking them — include this in the agent prompt
- See `~/.claude/rules/external-search.md` for the full MCP tool decision matrix

## Synthesis

After collecting agent results, follow the rules in `references/synthesis-rules.md`.

## Follow-Up Rounds

When the user asks iterative follow-up questions within a single research session:

- **Refinement** (same Type, narrower scope — e.g., "tell me more about X from your findings"): Answer inline from existing context. Don't re-dispatch agents.
- **New question axis** (requires a new Type classification — e.g., shifting from Type B to Type A): Dispatch new agents as needed. Apply the same type classification and agent selection rules.
- **Agent system consistency:** Within a single follow-up round, don't mix OMO and OMC agents for the same research type. If the first round used OMO librarian, follow-ups on the same axis should also use OMO librarian (not OMC Explore).

After each synthesis round, briefly offer the [Y]/[P]/[N] handoff menu if the research could support implementation. The user may decline and continue researching — that's fine.

## After This Skill

If the research was preparation for implementation:
> Research complete. Ready to act on this?
> **[Y]** Start `/x-do` **[P]** Create a plan first (`superpowers:writing-plans`) **[N]** More research needed

**Quick-action exception:** When research surfaces a single obvious small fix (<10 lines, one file, no ambiguity) and the user approves inline ("ok", "do it", "yes apply that"), apply directly without full x-do handoff. Still require tsc + eslint verification for TS/JS changes. If verification fails, fix inline if trivial (typo, missing import); otherwise escalate to `/x-do` Mode D. Context envelope is waived for inline quick-actions.

See `../x-shared/workflow-chains.md` for common sequences. Include a [handoff context](../x-shared/context-envelope.md) block — except when the user chooses **[P]**, where the synthesis itself serves as the handoff context (a separate envelope is redundant), or when using the quick-action exception above.

## Dependencies

- **`x-omo`** (required) — OMO agent runtime; `config.json` points to `omo_skill` and `omo_agent`. Without it, agent dispatch via Bash fails.
- **`x-shared/*`** — shared infra: `invocation-guide.md`, `workflow-chains.md`, `context-envelope.md`, `severity-guide.md`, `common-gotchas.md`.
- **`~/.claude/rules/external-search.md`** — MCP tool decision matrix for supplementary research.
- **Downstream chains:** `/x-do` (implementation handoff), `superpowers:writing-plans` (plan handoff), `/x-skill-improve` (alignment feedback).

## Gotchas

See `gotchas.md` for known failure patterns — update it when you encounter new ones.

Task: {{ARGUMENTS}}
