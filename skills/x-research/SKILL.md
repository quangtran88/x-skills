---
name: x-research
description: Use when the user asks to research, investigate, look up, or understand something — orchestrates MCP servers (perplexity/exa/deepwiki/context7), agy-agent, and OMO agents (explore/librarian/oracle/multimodal-looker) with optional Max Mode for parallel multi-lane synthesis
---

# x-research — Universal Research Orchestrator

x-research is a router. It classifies the question by **information-source signal**, picks the best tool/MCP/agent, and synthesizes findings. It does not redefine tool invocation — those live in linked skills.

## Bootstrap (MANDATORY)

Before dispatching anything, load:

0. `../x-shared/capability-loading.md` — pin the active capability set for this session. Skills MUST NOT re-verify per dispatch; trust the bootstrap-pinned set.
0a. If `mcp.gitnexus` is pinned, consume the shared gitnexus indexed+fresh probe per `../x-shared/capability-loading.md` § "Shared GitNexus Indexed+Fresh Probe" (session-pinned, derived once — do NOT run a per-skill `gitnexus list`).
1. `../x-omo/SKILL.md` — OMO agent catalog + Bash invocation patterns. **For the unavailable-agent list and replacement model-routing (`--model codex`, `--model gpt`), see `../x-shared/omo-routing.md § Unavailable Agents`.**
2. `../x-gemini/SKILL.md` — direct agy (Antigravity) CLI bridge (Google Search grounding via `--grounded`, gemini-3.x, `--add-dir`, `--resume`). **Load only if `agy_cli` capability is pinned**; if not pinned, drop agy-agent rows from the routing table and pick the escalation column instead.
3. `../x-shared/mcp-toolbox.md` — plugin-local MCP decision matrix (perplexity / exa / deepwiki / context7).
4. `gotchas.md` — known failure patterns.
5. **Memory recall** (only when `mcp.agentmemory` pinned in bootstrap-active set): one `mcp__plugin_agentmemory_agentmemory__memory_smart_search({ query: <topic + signal keywords>, limit: 5 })` call. Surface any prior research sessions on the same topic as supplementary context for the synthesis — leads, not verdicts. **Apply consumer rules from `../x-shared/mcp-toolbox.md § Consumer rules` — drop hits where `tags` includes `auto-import` OR `confidence < 0.5` before treating them as precedent.** When `mcp.agentmemory` is not pinned, **skip silently** — Claude's native auto-memory file still applies.

**Bootstrap shortcut:** if the question is a Standard-Mode local-only direct read with no agent dispatch, you may skip step 1 (OMO) and step 2 (agy). Steps 3 + 4 are always required.

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
| Local code: "how does our X work" (target repo indexed) | `gitnexus` → `query` (process-grouped) | native `Grep` → OMO `explore` |
| Symbol callers+callees+flows (target repo indexed) | `gitnexus` → `context` | 2× native `Grep` (callers, then callees) → OMO `explore` |
| Local code: "how does our X work" | OMO `explore` | native `Grep` |
| Local cross-repo (3+ modules tangled) | OMO `explore` + native `Grep` parallel | — |
| Public repo internals: "how does repo X do Y" | `deepwiki` → `ask_question` | `gh search code` → OMO `librarian` |
| Library API usage: "how to call X" | `context7` → `query-docs` | `exa` → `get_code_context_exa` |
| Library current state ("still maintained?", recent changes) | `agy-agent --grounded` (Google Search) | `perplexity_ask` |
| Quick factual lookup: "what is X" | `agy-agent --grounded` (Google Search grounding) | `perplexity_ask` |
| Fresh news / current events | `agy-agent --grounded` | `perplexity_ask` w/ recency filter |
| Large local input (>50k tokens — log, dir, doc bundle) | `agy-agent --add-dir <dir>` (1M context) | OMO `explore` paged |
| Visual cross-file vision reasoning (screenshots, mockups, multi-image) | `agy-agent --add-dir <dir>` (multimodal pro) | OMO `multimodal-looker` |
| X vs Y tradeoff (web-grounded) | `perplexity_reason` | OMO `oracle` for arch depth |
| Architecture decision (no web needed) | OMO `oracle` (GPT-5) | + `perplexity_reason` |
| Pre-planning (requirements + risks + code) | `OMO oracle` ∥ `OMO explore` ∥ native `Grep` | + `perplexity_ask` (web-grounded escalation; Max Mode adds `perplexity_research` + one `agy-agent` lane) |
| Visual single file (image/PDF/screenshot) | Claude `Read` (small) OR `agy-agent --add-dir <dir>` | OMO `multimodal-looker` |
| Exhaustive audit (security / architecture review) | `perplexity_research` | + OMO `oracle` |
| Dense code examples from web | `exa` → `get_code_context_exa` | OMO `librarian` |

**GitNexus rows — graceful degradation (C3, advisory class).** The two `gitnexus` Detection rows apply ONLY when `mcp.gitnexus` is pinned AND the target repo is in the shared probe's indexed-path set (step 0a). **Not pinned OR not indexed → the row collapses to the existing native `Grep` / OMO `explore` behavior — zero behavior change for unindexed repos.** Indexed but stale (`staleness.commitsBehind > 0`) → still use `gitnexus` (`query`/`context` are advisory-class per `../x-shared/mcp-toolbox.md` use-class index) and append `(index N commits stale — results may lag HEAD)` to the synthesis. The native `Grep` / OMO `explore` rows below them are the fallback path — never delete them.

**Cheapest-viable-first.** Free/instant tools (native `Grep`, deepwiki, context7) before token-billed (perplexity, exa) before agent-billed (omo, gemini).

**⚠ Invocation form.** Wrappers are standalone CLIs (`agy-agent`, `omo-agent`). There is no `omo` binary, no `omo dispatch …`. On `command not found: omo`, retry once with the documented form. Canonical rule + forms: `../x-shared/invocation-guide.md` § Literal binaries.

**🟢 DEFAULT AGY FAN-OUT (Standard Mode):** when `agy_cli` capability is pinned, a **single** `agy-agent` lane runs in **parallel with the primary** on every Standard Mode dispatch as an intentional fan-out — NOT "just in case". This is exempt from the hard gate below. The primary lane is always non-agy (gitnexus / native search / MCP / OMO), so this is exactly **one agy process in flight** — safe. ⚠ **≤1 agy lane rule:** never start a second agy lane while this one is running; agy is a process-global singleton and concurrent agy calls hang. Rationale: agy-agent brings axes the primary cannot (Google Search grounding for stale-library/CVE detection via `--grounded`, 1M context for large diffs/docs via `--add-dir`, multimodal for screenshots). Model selection:
- Local-code rows (gitnexus / native-search primary) → `agy-agent --model pro --add-dir <key entrypoint dir or directory>` for an independent reading of the same code.
- Web/library/architecture/factual rows → `agy-agent --model pro --grounded "<question>"` for a Google-grounded second opinion (`--grounded` only on web-currency rows).
- Visual/large-input rows where agy is already primary → no extra lane needed (already running — and a second agy lane would violate the ≤1-agy rule).
- Pure symbol-graph rows (`gitnexus context`) → SKIP agy lane (call-graph data, nothing for agy to add).

Note the lane skip in synthesis when applicable; reconcile per `references/synthesis-rules.md`.

**⛔ HARD GATE — sequencing matters (Standard Mode):** for any signal whose primary is `deepwiki` (or `gitnexus`), you MUST call the primary AND read its output BEFORE dispatching any **OMO agent** (oracle/explore/librarian/multimodal-looker). Firing OMO agents "in parallel with the primary, just in case" is a violation. "Insufficient" means you READ the primary output and judged it inadequate. **Exempt from this gate:** (a) Max Mode (parallel multi-lane fan-out is the point); (b) Pre-planning Type F — the three lanes (`oracle`, `OMO explore`, native `Grep`) cover orthogonal axes; (c) the Default Agy Fan-Out above — the single agy-agent lane is intentionally parallel when pinned. See `references/prompt-templates.md` § Type F for the canonical fan-out.

**Parallel only when axes differ:** OMO `explore` (local code) ∥ perplexity (web) is fine. native `Grep` ∥ OMO `explore` "just in case" is waste.

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

- [ ] **Persist insight** (only when `mcp.agentmemory` pinned): one `mcp__plugin_agentmemory_agentmemory__memory_save({ content: "<one-line synthesis takeaway>", type: "insight", concepts: "<project-slug>:x-research,<signal>,<topic-token>" })` call (project-slug = basename of cwd, e.g. `x-skills`, `oneclaw` — see `../x-shared/mcp-toolbox.md § Consumer rules`). Skip silently when not pinned.

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
- `../x-gemini/SKILL.md` — agy-agent runtime (required for agy lanes)
- `../x-shared/mcp-toolbox.md` — MCP decision matrix (plugin-local, portable)
- `../x-shared/invocation-guide.md`, `workflow-chains.md`, `context-envelope.md`, `common-gotchas.md`
- Downstream chains: `/x-do`, `superpowers:writing-plans` (research → implementation paths only — `x-skill-improve` does not consume research output)

## Gotchas

See `gotchas.md`.

Task: {{ARGUMENTS}}
