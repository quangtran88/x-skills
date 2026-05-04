# x-research — Research Router

> **Purpose:** Universal research orchestrator — classifies questions by information-source signal and dispatches to optimal tools/agents.

---

## Bootstrap (MANDATORY)

Before dispatching anything, load:

0. `../x-shared/capability-loading.md` — pin the active capability set for this session. Skills MUST NOT re-verify per dispatch; trust the bootstrap-pinned set.
1. `../x-omo/SKILL.md` — OMO agent catalog + Bash invocation patterns. **Do NOT dispatch to `hephaestus`, `atlas`, `prometheus`, `metis`, `momus` — UNAVAILABLE due to plugin compat bug.**
2. `../x-gemini/SKILL.md` — direct Gemini CLI bridge.
3. `../x-shared/mcp-toolbox.md` — plugin-local MCP decision matrix.
4. `gotchas.md` — known failure patterns.
5. **Bootstrap shortcut:** if the question is a Standard-Mode local-only direct read with no agent dispatch, you may skip step 1 (OMO) and step 2 (gemini). Steps 3 + 4 are always required.

---

## Hard Sequencing Rule

**⛔ HARD GATE:** for any signal whose primary is `morph` or `deepwiki`, you MUST call the primary AND read its output BEFORE dispatching any agent. Firing agents "in parallel with the primary, just in case" is a violation. "Insufficient" means you READ the output and judged it inadequate.
**Max Mode is exempt** — its whole purpose is parallel multi-lane fan-out where the user has accepted the cost.

**Parallel only when axes differ:** morph (local code) ∥ perplexity (web) is fine. morph ∥ OMO `explore` "just in case" is waste.

---

## Modes

| Mode | Trigger | Behavior |
|------|---------|----------|
| **Standard** | default | Pick single best tool per signal; escalate only if insufficient |
| **Max** | `max` / `prism` / `--max` / `ultraresearch` | Fan out across all relevant lanes in parallel; synthesize with reconciliation |

---

## Signal → Primary Tool Matrix

| Signal | Primary | Escalation |
|--------|---------|------------|
| Local code: "how does our X work" | `morph-mcp` → `codebase_search` | OMO `explore` |
| Local cross-repo (3+ modules) | `morph` + OMO `explore` parallel | — |
| Public repo internals | `deepwiki` → `ask_question` | `morph` → `github_codebase_search` → OMO `librarian` |
| Library API usage | `context7` → `query-docs` | `exa` → `get_code_context_exa` |
| Quick factual lookup | `perplexity_ask` | `gemini-agent` |
| Fresh news / current events | `gemini-agent` | `perplexity_ask` w/ recency filter |
| X vs Y tradeoff | `perplexity_reason` | OMO `oracle` |
| Architecture decision | OMO `oracle` | + `perplexity_reason` |
| Pre-planning | OMO `oracle` ∥ `morph` ∥ `perplexity_ask` | — |
| Visual single file | Claude `Read` OR `gemini-agent --file` | OMO `multimodal-looker` |
| Visual cross-file | OMO `multimodal-looker` | — |
| Exhaustive audit | `perplexity_research` | + OMO `oracle` |
| Dense code examples | `exa` → `get_code_context_exa` | OMO `librarian` |

---

## Cost Guard (Max Mode)

Before dispatch, announce: `Max Mode: <N> lanes — <lane list with rough cost/latency>. Proceed? [Y/n/standard]`

---

## Synthesis Rules

- Lead with the answer — conclusion first, details after
- Cite evidence — reference specific facts, URLs, file paths
- Flag uncertainty — note hedging or contradictions
- If agent modified files, verify (tests, diagnostics)
- Contradictions between agents = flag for user decision

---

## Dependencies

- `../x-omo/SKILL.md` — OMO agent runtime
- `../x-gemini/SKILL.md` — gemini-agent runtime
- `../x-shared/mcp-toolbox.md` — MCP decision matrix
- Downstream chains: `/x-do`, `superpowers:writing-plans`
