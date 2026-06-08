# Max Mode — Parallel Multi-Lane Research

Max Mode fans out across all relevant tools/agents/MCPs for a question class in parallel, then reconciles findings into a single synthesis. Inspired by x-review's multi-reviewer pattern.

## Trigger

Match in `{{ARGUMENTS}}`, case-insensitive:

- First or last token: `max`, `prism`, `ultraresearch`
- Flag anywhere: `--max`
- Force-confirm (skip cost guard): `prism!`, `--max-yes`

## Cost Guard (MANDATORY)

Before dispatching, surface the plan and ask:

```
Max Mode: <N> lanes — <comma-separated lane summary with rough cost/latency>.
Proceed? [Y/n/standard]
```

Defaults: `Y` = proceed, `n` = abort, `standard` = downgrade to Standard Mode and re-route via SKILL.md detection.

## Fan-Out Matrix

All lanes dispatch with `run_in_background: true`. Wait for ALL terminal states before synthesizing.

| Question Class | Parallel Lanes |
|---|---|
| **Codebase (local)** | native `Grep` ∥ OMO `explore` ∥ `agy-agent --add-dir <key entrypoint dir>` ∥ OMC Explore agent w/ `deepwiki` for similar OSS patterns |
| **Public repo / OSS internals** | `deepwiki ask_question` ∥ `gh search code` ∥ OMO `librarian` ∥ `agy-agent` |
| **Web research / fresh facts** | `perplexity_research` ∥ `exa web_search_exa` ∥ `agy-agent --grounded` (Google Search) ∥ OMO `librarian` (TYPE B) |
| **Library API** | `context7 query-docs` ∥ `exa get_code_context_exa` ∥ `agy-agent` ∥ OMO `librarian` |
| **Architecture / X vs Y** | OMO `oracle` ∥ `perplexity_reason` ∥ `agy-agent --model pro` ∥ OMC Explore w/ `exa get_code_context_exa` |
| **Pre-planning** | `OMO oracle` ∥ `OMO explore` ∥ native `Grep` ∥ `perplexity_research` ∥ `agy-agent` |
| **Visual** | `agy-agent --add-dir <dir>` ∥ OMO `multimodal-looker` ∥ Claude `Read` direct |

Lane invocation lives in the linked skills (`x-omo/SKILL.md`, `x-gemini/SKILL.md`, `x-shared/mcp-toolbox.md`). Do NOT redefine here.

**⛔ ≤1 AGY LANE IN FLIGHT (load-bearing).** agy is a process-global singleton — concurrent agy processes hang. **At most one `agy-agent` lane may be in flight at any moment.** Each question class above lists only one `agy-agent` variant, so the normal fan-out is already compliant: dispatch that single agy lane in parallel with all the non-agy lanes (native `Grep`, OMO agents, perplexity/exa/deepwiki/context7 MCPs), which fan out freely. **If you ever construct a dispatch that would run more than one agy variant (e.g. an `--add-dir` reading AND a `--grounded` lookup for the same class), do NOT run them in parallel — run them sequentially (one agy process at a time) or collapse them into a single agy lane.** Non-agy lanes are never throttled by this rule.

## Lane Selection Rules

- Lanes are pre-filtered against the bootstrap-pinned capability set (see `../../x-shared/capability-loading.md`). Drop unavailable lanes BEFORE building the dispatch list — never query the manifest per dispatch. Per-target unavailability (e.g., deepwiki repo not indexed) is a runtime error, not a capability check; mark the lane failed in synthesis.
- Cap at 5 lanes per dispatch — beyond that, returns diminish faster than tokens grow. **Additionally, at most ONE of those lanes may be an `agy-agent` lane** (≤1-agy-lane rule above) — agy is a process-global singleton and concurrent agy calls hang; the other 4 slots are non-agy lanes that parallelize freely.
- For "Web research" class, demote `perplexity_research` to `perplexity_ask` if user budget signals are present (e.g., `--cheap` flag or prior Standard Mode in same session).

## Synthesis Template

After all lanes terminal, write the report in this shape:

```markdown
## Convergent findings  (lanes agree)
- <claim> — supported by <lane A>, <lane B>, <lane C>

## Divergent findings  (lanes disagree)
| Lane | Position |
| --- | --- |
| <lane A> | <position> |
| <lane B> | <different position> |
**Reconciliation:** <judgment + reasoning, citing higher-tier evidence per synthesis-rules.md>

## Unique insights  (single-lane, worth keeping)
- [<lane>] <claim> — why it is worth keeping despite being unsupported by other lanes

## Confidence map
| Claim | Lanes supporting | Confidence |
| --- | --- | --- |
| <claim> | <count>/<total> | <high|med|low> |

## Sources
- [perplexity] <citations>
- [agy] <Google grounding URLs>
- [librarian] <GitHub permalinks>
- [local search] <local file:line refs>
- [deepwiki] <repo + question>
- [context7] <library + section>

## Recommendation
<single synthesized recommendation, with confidence level>

## Lanes that failed or returned nothing
- <lane>: <reason> (<retry suggestion>)
```

This mirrors x-review's reviewer reconciliation: agreement first, then disagreement with explicit reconciliation, then unique value, then evidence trail.

## Verification (still applies)

All claims subject to the verification gate in `synthesis-rules.md`. Spot-check file paths, code claims, and external claims before presenting. Drop false positives.

## Failure Modes

See `../gotchas.md` § "Max Mode pitfalls" for cost overruns, rate limits, lane timeout cascade, and partial-failure synthesis rules.
