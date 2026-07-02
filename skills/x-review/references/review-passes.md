# Review Passes

Different analytical methods find different defect classes. A checklist finds what it checks for; path tracing finds what happens at boundaries; adversarial review finds what you assumed was fine.

Cross-model review (`[X]`) is now built into the default flow for both plan and code reviews. After the default cross-model pass, offer additional specialized passes.

**Scope note:** Default x-review reports only bugs, security issues, false assumptions, and plan deviations (see SKILL.md → Scope Contract). Passes marked `[scope-expander]` widen the review beyond that contract — they are **opt-in only** and should never auto-run. The user must explicitly pick them.

```
Additional passes available:
[S] Security — deeper threat modeling (STRIDE/OWASP) on top of default security findings
[P] Performance — perf path tracing  [scope-expander: includes non-bug optimization suggestions]
[C] Complexity — structural analysis  [scope-expander: includes refactor candidates]
[X] Cross-model — adversarial (skip if oracle already ran in primary pass)
[V] Visual — compare screenshots to specs
[D] Deslop — code archaeology  [scope-expander: includes refactor / dead-code edits]
[A] All of S, P, C, D  [warning: P/C/D are scope-expanders]
[N] Done
```

## Pass Details

| Pass | Methodology | Invocation | Finds |
|------|------------|------------|-------|
| **Primary** | Spec compliance + quality heuristics | Agent: `subagent_type: "oh-my-claudecode:code-reviewer"`, `model: "<parent session model>"` | Logic defects, spec deviations, quality issues |
| **S** Security | Threat modeling (STRIDE/OWASP) | Agent: `subagent_type: "oh-my-claudecode:code-reviewer"`, `model: "<parent session model>"` + STRIDE/OWASP prompt | Vulnerabilities, injection vectors, hardcoded secrets |
| **P** Performance | Path tracing (hot paths, complexity) | Agent: `subagent_type: "oh-my-claudecode:code-reviewer"`, `model: "<parent session model>"` + performance prompt | N+1 queries, missing indexes, O(n²) loops, memory leaks |
| **C** Complexity | Structural analysis (function sizes, coupling, duplication) | Agent: `subagent_type: "oh-my-claudecode:code-reviewer"`, `model: "sonnet"` + complexity prompt | Large functions, high coupling, refactor candidates, duplication |
| **X** Cross-model | Adversarial (different model's perspective) | Bash: `<omo_agent from config.json> oracle "<prompt>"` | Blind spots, alternative approaches, logic errors |
| **V** Visual | UI deviation detection | Bash: `<omo_agent from config.json> multimodal-looker --file screenshot "<prompt>"` | Visual regressions, spec mismatches |
| **D** Deslop | Code archaeology (AI pattern detection) | Agent: `subagent_type: "oh-my-claudecode:code-reviewer"`, `model: "<parent session model>"` + deslop prompt | Over-abstraction, dead code, unnecessary complexity |

## Parallel Execution

S, P, C, and X are read-only and independent — launch all selected passes in ONE message with `run_in_background: true` (max 3 concurrent). Same rule as step-02: all tool calls in a single response for true parallelism.

D (deslop) must run **after** all other passes because it modifies files. Never parallelize D with other passes.
