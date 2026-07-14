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
4. **Cite sources** — attribute each finding to its reviewer (Claude, GPT, Gemini, etc.)
5. **Mark verified** — indicate which findings were confirmed against actual code
6. **Tag NEEDS_DIRECTION** — mark any finding that requires user input before fixing (see criteria below)
7. **Persist lesson** (only when `mcp.basic_memory` pinned): for each CRITICAL or HIGH finding ONLY, one `mcp__basic-memory__write_note({ title: "<severity>: <finding summary>", directory: "lessons/<project-slug>", content: "<finding summary> → <recommendation>\n\nFiles: <files cited in finding>", tags: ["<project-slug>", "x-review", "<severity>", "<area>"] })` call (project-slug = basename of cwd — see `../../x-shared/mcp-toolbox.md § Consumer rules`). Skip MEDIUM and LOW findings. Skip silently when not pinned.

## Tag NEEDS_DIRECTION (MANDATORY — narrow criteria)

NEEDS_DIRECTION only applies to **in-scope findings** (bugs, security, false assumptions, plan deviations) where the **fix itself** is ambiguous. It is NOT a hook for architectural redesign or scope expansion.

**Capture reviewer-flagged direction requests:** Reviewers may append `NEEDS_DIRECTION: <reason>` to in-scope findings (per `references/scope-guard.md`). When you see this tag in raw output:
1. Apply the Scope Filter first — if the finding itself is out of scope, drop it (the tag does not rescue an out-of-scope finding).
2. If the finding is in-scope, copy the reviewer's candidate options into the clarification block as starting points for A/B/C. You may add, merge, or reword options based on cross-reviewer evidence.
3. Always still apply the criteria below — a reviewer flag is a signal, not an automatic pass.

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

### Big Picture header (MANDATORY, once per review, before first block)

If ANY clarification block exists, prepend ONE `### Big Picture` section before the first block:

```
### Big Picture
**System:** [1 sentence — what the code does, who it serves]
**Users affected by these decisions:** [operators / end-users / SDK consumers / internal devs — name concretely]
**Plan goal:** [restate stated plan/PR intent in 1 sentence]
**Plan-scope sanity:** [✓ findings fit stated goal | ⚠ findings suggest plan scope is wrong — see meta-finding]
```

Without this header, user picks A/B/C blind. Block alone is not enough.

### Classify each clarification by axis (MANDATORY)

Tag each block with ONE axis. Axis controls template variant and who should answer:

| Axis | Means | Right decider | Effort label allowed? |
|------|-------|---------------|------------------------|
| `impl` | Two patches fix same bug, both in code | Implementer | Yes |
| `security` | Choice changes who can reach what / what auth/gate fires | Security owner + implementer | **No — suppress effort label, severity dominates** |
| `product` | Choice removes/keeps a user-facing capability or contract | Product owner / PM | Yes, but flag "needs non-implementer input" |
| `compliance` | Choice touches public schema, doc-claimed gate, audit surface | Owner of contract (legal/sec/PM) | No — "ship dead gate" forbidden |

If axis = `security` or `compliance`: a "keep as-is / defer" option that leaves a non-firing gate, dead config key, or open bind is **forbidden**. Replace with "fix now" and "fix in immediate follow-up PR with tracker link required".

If axis = `product`: clarification block MUST end with `**Decider:** product owner — implementer should not pick alone.`

### Per-option Impact line (MANDATORY)

Pros/cons phrased in code terms ("scope creep", "diff size", "shared seam") are insufficient. Every option MUST also carry an `Impact:` line written in user/operator/dev-consumer terms, with NO code symbols.

Examples of acceptable Impact:
- "Operator who deploys with default config gets a port open to LAN with no auth."
- "AG-UI client devs lose ability to pick model from request; CopilotKit demo breaks until v2."
- "End user sees error message change from `400 Bad Input` to `403 model_not_allowed`."

Examples that FAIL the rule (code-internal, reject and rewrite):
- "Adds a fourth shared seam"
- "Smallest diff"
- "Mirrors today's behavior"

### Always-present escape options

Every clarification block MUST list, in addition to the patch options:

- **D) Reject framing** — "These options assume the plan is right. Tell me if the plan should change instead." Always offered, never dropped.
- **E) Split this fix to its own PR / defer rest** — when ≥2 NEEDS_DIRECTION rows exist OR when one finding's fix is significantly larger than others.

### Deferral requires a tracker

Any option that defers work (including `Keep as-is`, `v2`, `follow-up`, `revisit`) MUST include:

```
Follow-up required: [issue tracker link OR placeholder `TBD before merge`]
Owner: [name OR `TBD before merge`]
Deadline: [date OR `TBD before merge`]
```

If user picks a deferral option without filling these in, step 4 must block until provided.

### Template

**Heading rule (MANDATORY):** Every clarification block heading MUST start with `### Decision #<N>:` where `<N>` is the **same finding number** from the synthesis table. Substitute the actual number — do NOT emit the literal `<N>`. This lets the user reply with `<N>: A` without cross-referencing the title. If a single finding raises multiple decisions, suffix with `.a`, `.b` (e.g. `### Decision #5.a:`, `### Decision #5.b:`). Do NOT drop the number.

Concrete example (substituted):
```
### Decision #2: Tool-call correlation strategy
**Bottom line:** ...
```

**Bottom line rule (MANDATORY):** Every block MUST include a `**Bottom line:**` one-liner immediately under the heading, written for a non-technical reader (product owner, operator, ops manager). It MUST name (a) the user-visible thing at stake and (b) the rough shape of the tradeoff in ≤2 short sentences. NO code symbols, NO file names, NO jargon. If you cannot write the bottom line in plain language, the block is too technical — rewrite "What's happening" first.

Examples of good Bottom line:
- Generic (null-deref): "Login crashes when a returning user has no saved profile. Pick: auto-create a default profile (silent fix, may hide real bugs) or show a sign-up prompt (extra step but explicit)."
- Domain (correlation): "Tool-call cards in the AG-UI panel may show wrong results when users run multiple tools at once. Pick: slow them down (safe), accept some wrong cards (fast), or limit which tools work (mixed)."
- Domain (security): "Anyone with the API key can pretend to be any user. Pick: per-user keys (most work, safest), signed proxy headers (medium work, safe-ish), or just warn operators (zero work, unsafe)."

Examples that FAIL (too technical, rewrite):
- "Single-flight invariant violation in onItemEvent FIFO" — code jargon
- "Choose between Mode A apiKey and Mode B TokenStore" — internal terms

```
### Decision #<N>: [short title]
**Bottom line:** [≤2 plain sentences naming the user-visible stake + tradeoff shape]
**Axis:** impl | security | product | compliance
**Severity inheritance:** [CRITICAL / HIGH / MEDIUM / LOW from parent finding]

**What's happening**
[2-3 plain sentences. Explain the code area, why it matters, what behavior
or product capability it controls. No assumed deep knowledge. NO code symbols
beyond file names.]

**The choice**
You can go in different directions. Each has tradeoffs:

  A) [Option name] — [one-line description in plain language]
     Impact: [user/operator/dev-consumer outcome, no code symbols]
     ✓ Pros: [...]
     ✗ Cons: [...]
     Effort: S / M / L      ← OMIT entirely if axis = security/compliance

  B) [Option name] — [...]
     Impact: [...]
     ✓ Pros: [...]
     ✗ Cons: [...]
     Effort: S / M / L      ← OMIT entirely if axis = security/compliance

  C) Defer / keep as-is — [why deferring may be acceptable, or what risk remains]
     Impact: [what stays broken / unclaimed in the meantime]
     Follow-up required: [tracker link OR `TBD before merge`]
     Owner: [name OR `TBD before merge`]
     Deadline: [date OR `TBD before merge`]
     ⚠ FORBIDDEN if axis = security or compliance leaves a dead gate / open surface.

  D) Reject framing — Tell me the plan itself should change. (Always offered.)

  E) Split this fix off — Ship it in its own smaller PR; defer the rest.
     (Offered when multiple NEEDS_DIRECTION rows exist or sizes diverge.)

**Recommended: [A / B / C / D / E]**
[1-2 sentences grounded in user-impact, NOT diff size. If axis=security,
recommend the secure option even when diff is larger. If axis=product,
state explicitly: "this needs product-owner sign-off, my recommend is
a tech-feasibility hint only."]

**What I need from you**
Pick A / B / C / D / E, or describe a different direction.
**Decider:** [implementer | product owner | security owner | mixed]
```

**Rules for the block:**
- 2+ real patch options + always D + conditionally E.
- Always include an explicit recommendation grounded in user impact.
- Effort tag forbidden when axis = security or compliance.
- "Ship dead gate" / "leave bind open" / "lying config" options are forbidden, not "hard no".
- Keep each block short — long blocks won't get read.
- Stash the drafted blocks internally for step 4 to surface one-at-a-time using `../../x-shared/done-format.md § Shape 3 — DECIDE`. Do NOT display them in step 3 output — the findings table is the only user-facing output from this step (per the rule below).

### Meta-finding: plan-scope mismatch (MANDATORY check)

After drafting all clarification blocks, scan them as a set:

- Do 2+ blocks raise questions the stated plan goal cannot answer?
- Does any block ask a question that belongs to a different phase / different PR / different decider than the plan covers?
- Does the plan title claim "no behavior change" while a block introduces a new gate, new surface, or new contract?

If YES to any, prepend a meta-finding to the findings table with severity HIGH:

```
META: Plan scope mismatch — [N] clarifications surface decisions outside the stated plan goal of "[plan goal]". Recommend rescoping the plan before merging fixes for these findings.
```

This finding always carries `NEEDS_DIRECTION = ✓` with axis = `product` and decider = product owner / plan author.

### Test-vs-runtime gap finding (MANDATORY check)

If any clarification option's Cons read like "unit test still passes but runtime gate is disabled" (or equivalent — test green while real-world behavior wrong), emit a SEPARATE finding (severity HIGH) named:

```
Test-vs-runtime gap: [parent finding]'s test exercises [X] but runtime path [Y] bypasses it. Tests give false confidence.
```

Do not bury this inside an option's con list. It is its own bug class.

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

If any row has `NEEDS_DIRECTION = ✓`, draft the DECIDE blocks internally (using the "Draft Clarification Block" template above) but do **NOT** display them here. Step 4 surfaces them one at a time using `../../x-shared/done-format.md § Shape 3 — DECIDE`. The findings table is the only user-facing output from this step.

## Next Step

Read fully and follow `step-04-act.md`.
