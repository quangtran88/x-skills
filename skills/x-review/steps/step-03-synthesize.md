# Step 3: Synthesize

**Progress: Step 3 of 4** — Next: Act

## Rules

- **READ COMPLETELY** before acting
- ALL reviewer results must be collected before this step
- CRITICAL + HIGH findings must be addressed before marking review complete

## Scope Filter (MANDATORY — runs BEFORE verification)

Reviewers will return out-of-scope findings even with the Scope Guard. Drop them before verifying.

For every raw finding from any reviewer, ask:

1. Does it name a **concrete bug** (logic defect, null deref, race, broken control flow, mishandled error that hides failure)?
2. Does it name a **security issue** (injection, authn/authz hole, secret leak, SSRF, traversal, missing input validation at a trust boundary)?
3. Does it name a **false assumption** (spec/plan/code claim that contradicts the actual implementation, missing dep the plan presumes, fabricated API/file/symbol, success criterion that can't be measured)?
4. Does it name a **deviation from the stated plan/PR intent**?

If the answer to all four is **no** → **drop the finding entirely.** Do not include it. Do not downgrade to LOW.

**Drop these patterns regardless of how the reviewer worded them:**
- "Consider extracting…", "Could be refactored…", "Would be cleaner if…"
- "For better performance, use…" (unless the current code is a user-visible bug)
- "You might also want to add…", "It would be nice to support…"
- "Add tests for X" when X already has tests, unless a missing test would have caught a real in-scope finding
- "Improve naming", "Add JSDoc", "Reformat", "Reorganize files"
- "Future-proof for…", "Make this configurable", "Support library Y as alternative"
- "Architectural improvement: split into…", "Adopt pattern Z"
- New-feature suggestions of any kind

**When in doubt, ask the user before including:** "Reviewer flagged X — looks like a refactor/perf suggestion outside the bug-and-security scope. Include?" Default = drop.

Record the count of dropped-as-out-of-scope findings in synthesis (e.g., `Filtered 7 out-of-scope findings (refactor/perf/style)`) so the user can ask to see them if needed.

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

## Tag NEEDS_DIRECTION (MANDATORY — narrow criteria)

NEEDS_DIRECTION only applies to **in-scope findings** (bugs, security, false assumptions, plan deviations) where the **fix itself** is ambiguous. It is NOT a hook for architectural redesign or scope expansion.

Tag a finding when ANY of these apply to the **fix for a confirmed bug/security/false-assumption finding**:

1. **Two valid fixes exist for the same bug** — e.g., null-check at caller vs callee, retry vs fail-fast for a known race
2. **Product/UX implication for an in-scope bug** — error message wording, what value to default to when the previous default was wrong, opt-in vs opt-out for a security toggle
3. **Reviewers disagree on the minimal fix** — both proposals address the same in-scope finding, but pick different patches

**Do NOT tag (these are out-of-scope and should already be dropped by the Scope Filter):**
- "Should we refactor…" — out of scope
- "Sync vs async architecture" — out of scope unless it's the cause of a confirmed bug
- "Library swap, schema redesign, layer-boundary shift" — out of scope
- "Perf vs readability tradeoff" — out of scope
- "Minimal patch vs root-cause refactor" — default is minimal patch; refactor is out of scope

If you're tempted to tag a finding NEEDS_DIRECTION because it raises a design question rather than a fix question, the finding itself is out of scope — drop it via the Scope Filter instead of asking the user to make a design decision.

## Draft Clarification Block (per NEEDS_DIRECTION finding)

For every NEEDS_DIRECTION row, draft an explainer block now (you have full context loaded; step 4 will not). Use plain language — assume reader is product owner, not deep technical expert. Define jargon inline.

**Use this template ONLY when two valid patches exist for the SAME confirmed in-scope finding (bug / security / false-assumption / plan-deviation).** Do NOT use it to surface architectural choices, refactor options, or scope-expanding decisions — those are out of scope and should already be dropped by the Scope Filter. If the options below describe "how to redesign X" rather than "which patch fixes bug Y", you've drifted out of scope: drop the row, do not draft this block.

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
