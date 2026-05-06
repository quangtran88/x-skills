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

**Do NOT replace this menu with a custom one.** Wrong patterns seen in the wild:
- "1) Apply all fixes  2) HIGH-only  3) Stop" — invented fix-flow menu, skips the passes gate entirely
- Inlining only S/P/X — partial menu robs the user of [C]/[V]/[D]/[A]/[N] options
- Jumping straight to "Want me to fix?" — skips the menu altogether
- "[D] Fix Mode  [F] Finish  [N] Done" — letter-redefinition: `[D]` is Deslop, NOT Fix Mode. `[F]` belongs to APPROVE branch (finishing-a-development-branch), not the passes menu. Evidence: session 9ba4f817.

**Letter assignments are fixed. Do not redefine them.** `[S]=Security`, `[P]=Performance`, `[C]=Complexity`, `[X]=Cross-model`, `[V]=Visual`, `[D]=Deslop`, `[A]=All of S/P/C/D`, `[N]=Done`. Any other meaning for these letters is a deviation.

**Paste-verbatim rule.** Copy the menu block from `references/review-passes.md` exactly as written. Do not summarize, reorder, or substitute. If you are tempted to "tailor" the menu to the findings (e.g., "they only need [D]"), STOP — the user picks; the skill presents.

**Canonical menu (copy this block verbatim — do NOT re-derive):**

```
Additional passes available:
[S] Security — deeper threat modeling (STRIDE/OWASP)
[P] Performance — perf path tracing  [scope-expander: non-bug optimization suggestions]
[C] Complexity — structural analysis  [scope-expander: refactor candidates]
[X] Cross-model — adversarial (skip if oracle already ran in primary pass)
[V] Visual — compare screenshots to specs
[D] Deslop — code archaeology  [scope-expander: refactor / dead-code edits]
[A] All of S, P, C, D  [warning: P/C/D are scope-expanders]
[N] Done
```

**Scope-expander rule:** `[P]`, `[C]`, `[D]` widen the review past the bug/security/false-assumption contract. Never auto-run them. Never recommend "[A] All" — let the user pick. If the user picks `[A]`, confirm once: "All passes includes refactor + perf suggestions beyond bugs/security — proceed?" before launching.

The exact menu from `references/review-passes.md` is the only valid form. If you find yourself drafting a numbered fix menu, STOP — show the lettered passes menu first and wait for user input.

## Clarification Gate (MANDATORY HALT — runs after passes menu, before Act on Verdict)

If the synthesis table from step 3 contains ANY row tagged `NEEDS_DIRECTION = ✓`, you MUST halt here and collect user direction BEFORE entering Fix Mode.

**Why this gate exists:** Architectural decisions, ambiguous tradeoffs, and conflicting reviewer recommendations cannot be resolved by the model alone. Auto-fixing one direction silently locks the user out of the other. One user prompt is cheaper than an unwanted refactor.

**Procedure:**

1. **Re-display each clarification block** drafted in step 3 — verbatim, in finding-number order. Do NOT summarize, condense, or skip blocks even if "obvious."
2. **Prompt the user** with this exact line after the last block:

   ```
   Resolve the decisions above. For each finding number, reply:
     <#>: A | B | C   (or describe a custom direction)
     <#>: skip         (defer this finding — excluded from Fix Mode)
   You can answer multiple in one message.
   ```

3. **WAIT for user input.** Do NOT proceed. Do NOT propose answers on the user's behalf. Do NOT auto-pick the recommended option.
4. **Lock direction.** When the user replies, record the chosen option per finding. `skip` removes that finding from Fix Mode scope (note it in the handoff context as deferred).
5. **Only after every NEEDS_DIRECTION row has an answer or skip** may you continue to "Act on Verdict".

**Rules:**

- If the user asks a follow-up question instead of choosing, answer it (read more code if needed), then re-prompt the choice. Do not assume silence = recommendation.
- If the user picks a custom direction not in A/B/C, restate the chosen direction in plain language and confirm before fixing.
- If the user says "you decide" or "pick the best": still surface the recommendation and the tradeoff one more time, get explicit ack ("yes go with recommended"). Do not silently take initiative on architectural changes.
- Skipped findings still appear in the final handoff context block as `Deferred — awaiting direction`.

**Skip this gate ONLY if** the synthesis table has zero `NEEDS_DIRECTION = ✓` rows. Verify the column before skipping.

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

- [ ] Every NEEDS_DIRECTION row resolved (user picked A/B/C/custom or skipped) — Clarification Gate passed
- [ ] Fix CRITICAL + HIGH findings immediately, using the locked direction from the Clarification Gate
- [ ] Invoke `superpowers:receiving-code-review` for structured fix workflow — do NOT skip even if user says "fix all"
- [ ] After fixes: invoke `superpowers:verification-before-completion` with evidence — manual checks (tsc, lint, build) are insufficient alone
- [ ] Offer re-review if CRITICAL/HIGH findings were fixed (significant changes = re-review)
- [ ] Handoff context block included (see `../x-shared/context-envelope.md`)

## Completion Checklist (ALL required before finishing)

- [ ] Every CRITICAL/HIGH finding verified against actual code
- [ ] Synthesis table includes Source, Verified, and NEEDS_DIRECTION columns
- [ ] Every NEEDS_DIRECTION row has a recorded user decision (chosen option or skip)
- [ ] Verdict stated: APPROVE or REQUEST_CHANGES
- [ ] Handoff context block included (see `../x-shared/context-envelope.md`)

**Do NOT mark review complete until every box is checked.**

## After This Skill

Review passed? Offer: **[F]** Finish branch (`superpowers:finishing-a-development-branch`) | **[D]** Done.
Issues found? Invoke `superpowers:receiving-code-review` for structured fixes, then re-review.

Include a [handoff context](../x-shared/context-envelope.md) block.
