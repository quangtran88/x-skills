# Step 4: Act on Verdict

**Progress: Step 4 of 4** — Final step

## Rules

- **READ COMPLETELY** before acting
- Step 3 (synthesis + findings table) must be complete before this step
- **HALT at the passes menu** — do not auto-proceed to verdict routing

## Offer Additional Passes (MANDATORY HALT)

**STOP here.** After presenting findings in step 3, you MUST:

1. Show the full additional passes menu from `references/review-passes.md` — do not inline a subset
2. **WAIT for user input** — do NOT auto-proceed to "Act on Verdict"
3. Only after the user selects passes (or says Done/N) should you continue

S, P, X are read-only and can run in parallel. D modifies files — run it last, never in parallel.

**NEVER skip this gate.** Even if the verdict is REQUEST_CHANGES with obvious fixes, the user may want additional passes first. Auto-invoking `receiving-code-review` without offering this menu is a known compliance gap.

## Act on Verdict

### APPROVE
Offer: **[F]** Finish branch (`superpowers:finishing-a-development-branch`) | **[D]** Done

### REQUEST CHANGES

#### Review-Only Mode (reviewing someone else's PR)

When the reviewer is posting findings to a PR they don't own — not fixing locally:
1. Verify findings against actual code (mandatory — same as step 3)
2. Post review to PR with structured findings
3. Skip the fix/receiving-code-review/verification checklist below — offer to fix only if user requests it

**Review-only completion checklist (ALL required):**
- [ ] Every CRITICAL/HIGH finding verified against actual code
- [ ] Review posted to PR with structured inline comments
- [ ] Handoff context block included (see `../x-shared/context-envelope.md`)

#### Fix Mode (own code or user requests fixes)

**Default edit tool:** Use `morph-mcp edit_file` for all fix application — partial edits with `// ... existing code ...` markers are faster and preserve context better than full rewrites. Use `morph-mcp codebase_search` to locate targets before editing. Fall back to native `Edit` only if `edit_file` errors.

**Checklist (ALL required before marking complete):**

- [ ] Fix CRITICAL + HIGH findings immediately
- [ ] Invoke `superpowers:receiving-code-review` for structured fix workflow — do NOT skip even if user says "fix all"
- [ ] After fixes: invoke `superpowers:verification-before-completion` with evidence — manual checks (tsc, lint, build) are insufficient alone
- [ ] Offer re-review if CRITICAL/HIGH findings were fixed (significant changes = re-review)
- [ ] Handoff context block included (see `../x-shared/context-envelope.md`)

## Completion Checklist (ALL required before finishing)

- [ ] Every CRITICAL/HIGH finding verified against actual code
- [ ] Synthesis table includes Source + Verified columns
- [ ] Verdict stated: APPROVE or REQUEST_CHANGES
- [ ] Handoff context block included (see `../x-shared/context-envelope.md`)

**Do NOT mark review complete until every box is checked.**

## After This Skill

Review passed? Offer: **[F]** Finish branch (`superpowers:finishing-a-development-branch`) | **[D]** Done.
Issues found? Invoke `superpowers:receiving-code-review` for structured fixes, then re-review.

Include a [handoff context](../x-shared/context-envelope.md) block.
