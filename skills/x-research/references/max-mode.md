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
| **Codebase (local)** | native `Grep` ∥ OMO `explore` ∥ `gemini-agent --file <key entrypoint>` ∥ OMC Explore agent w/ `deepwiki` for similar OSS patterns |
| **Public repo / OSS internals** | `deepwiki ask_question` ∥ `gh search code` ∥ OMO `librarian` ∥ `gemini-agent` |
| **Web research / fresh facts** | `perplexity_research` ∥ `exa web_search_exa` ∥ `gemini-agent` (Google Search) ∥ OMO `librarian` (TYPE B) |
| **Library API** | `context7 query-docs` ∥ `exa get_code_context_exa` ∥ `gemini-agent` ∥ OMO `librarian` |
| **Architecture / X vs Y** | OMO `oracle` ∥ `perplexity_reason` ∥ `gemini-agent --model pro` ∥ OMC Explore w/ `exa get_code_context_exa` |
| **Pre-planning** | `OMO oracle` ∥ `OMO explore` ∥ native `Grep` ∥ `perplexity_research` ∥ `gemini-agent` |
| **Visual** | `gemini-agent --file` ∥ OMO `multimodal-looker` ∥ Claude `Read` direct |

Lane invocation lives in the linked skills (`x-omo/SKILL.md`, `x-gemini/SKILL.md`, `x-shared/mcp-toolbox.md`). Do NOT redefine here.

## Lane Selection Rules

- Lanes are pre-filtered against the bootstrap-pinned capability set (see `../../x-shared/capability-loading.md`). Drop unavailable lanes BEFORE building the dispatch list — never query the manifest per dispatch. Per-target unavailability (e.g., deepwiki repo not indexed) is a runtime error, not a capability check; mark the lane failed in synthesis.
- Cap at 5 lanes per dispatch — beyond that, returns diminish faster than tokens grow.
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
- [gemini] <Google grounding URLs>
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
