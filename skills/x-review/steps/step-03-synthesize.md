# Step 3: Synthesize

**Progress: Step 3 of 4** — Next: Act

## Rules

- **READ COMPLETELY** before acting
- ALL reviewer results must be collected before this step
- CRITICAL + HIGH findings must be addressed before marking review complete

## Verify Each Finding (MANDATORY)

Before synthesizing, **spot-check every CRITICAL and HIGH finding** against the actual code:

1. **Read the referenced file/line** — does it actually exist? Is the code what the reviewer claims?
2. **Confirm the issue is real** — not a hallucination, outdated reference, or misread
3. **Drop false positives** — if the code doesn't match the claim, discard the finding
4. **Downgrade if overstated** — if the issue exists but severity is inflated, adjust it

For MEDIUM/LOW findings: spot-check at least 2-3 representative ones. If any are wrong, check them all.

**If >30% of findings fail verification:** note this in the output — the reviewer's results are unreliable for this codebase.

## Synthesis

1. **Deduplicate** — merge overlapping findings from different reviewers
2. **Rank by severity** — CRITICAL > HIGH > MEDIUM > LOW (see `../../x-shared/severity-guide.md`)
3. **Flag contradictions** — when reviewers disagree, present both perspectives for user decision
4. **Cite sources** — attribute each finding to its reviewer (Claude, GPT, etc.)
5. **Mark verified** — indicate which findings were confirmed against actual code
6. **Tag NEEDS_DIRECTION** — mark any finding that requires user input before fixing (see criteria below)

## Tag NEEDS_DIRECTION (MANDATORY)

A finding requires user direction BEFORE any fix when ANY of these apply:

1. **Reviewers disagree on direction** — e.g., "extract module" vs "inline", "add cache" vs "remove cache"
2. **Architectural choice** — sync vs async, schema redesign, breaking API change, library swap, layer boundary shift
3. **Tradeoff with no clear winner** — perf vs readability, coupling vs duplication, type safety vs flexibility
4. **Ambiguous fix scope** — minimal patch vs root-cause refactor, single-call-site vs cross-cutting change
5. **Product/UX implication** — error message wording, default values, opt-in vs opt-out behavior

If unsure whether to tag → tag it. False positives cost one user prompt; false negatives cost wrong fixes.

## Draft Clarification Block (per NEEDS_DIRECTION finding)

For every NEEDS_DIRECTION row, draft an explainer block now (you have full context loaded; step 4 will not). Use plain language — assume reader is product owner, not deep technical expert. Define jargon inline.

```
### Decision needed: [short title]

**What's happening**
[2-3 plain sentences. Explain the code area, why it matters, what behavior
or product capability it controls. No assumed deep knowledge.]

**The choice**
You can go in different directions. Each has tradeoffs:

  A) [Option name] — [one-line description in plain language]
     ✓ Pros: [...]
     ✗ Cons: [...]
     Effort: S / M / L

  B) [Option name] — [...]
     ✓ Pros: [...]
     ✗ Cons: [...]
     Effort: S / M / L

  C) Keep as-is — [why deferring may be acceptable, or what risk remains]

**Recommended: [A / B / C]**
[1-2 sentences. Reference concrete signals from the code — file size, test
coverage, upstream callers, deadline, stated goals. Be honest if the
recommendation is weak or context-dependent.]

**What I need from you**
Pick A / B / C, or describe a different direction.
```

**Rules for the block:**
- Always 2+ real options (never a single binary). Always include a "keep as-is / defer" option.
- Always include an explicit recommendation with reasoning. No neutral hedging.
- Effort tag (S = under 1h, M = 1-4h, L = >4h) so user weighs cost vs benefit.
- Keep each block short — long blocks won't get read.
- Stash the drafted blocks below the findings table so step 4 can present them verbatim.

## Present Findings

**Two valid verdicts only: APPROVE or REQUEST_CHANGES.** Do NOT invent intermediate states like `APPROVE_WITH_FIXES`, `APPROVE_WITH_CONCERNS`, or `CONDITIONAL_APPROVE`. If any blocker (CRITICAL or HIGH) exists, the verdict is REQUEST_CHANGES — severity tiers in the findings table communicate the rest.

```
### Review: [target description]
**Verdict:** APPROVE | REQUEST_CHANGES

| # | Severity | Finding | Source | Verified | NEEDS_DIRECTION |
|---|----------|---------|--------|----------|-----------------|
| 1 | CRITICAL | ... | Claude | ✓ | — |
| 2 | HIGH | ... | GPT | ✓ | ✓ |
| 3 | MEDIUM | ... | Claude + GPT | ✓ | — |
```

If any row has `NEEDS_DIRECTION = ✓`, append the drafted clarification blocks (one per flagged row) immediately after the table under a `### Clarification needed before fix` heading.

## Next Step

Read fully and follow `step-04-act.md`.
