# Step 4: Act on Verdict

**Progress: Step 4 of 4** — Final step

## Rules

- **READ COMPLETELY** before acting
- Step 3 (synthesis + findings table) must be complete before this step
- **HALT at the passes menu** — do not auto-proceed to verdict routing

## Plan-Target Routing (Target A — runs FIRST, short-circuits the rest of this step)

If step-01 detected **Target A: Plan/Spec**, this step takes a short path:

1. The passes menu (`[S][P][C][X][V][D][A][N]`) targets **code**. Skip it entirely for plans.
2. The Clarification Gate is for **fix-time** decisions on code patches. For plans, the "fix" is upstream plan revision by the caller — skip the gate.
3. Fix Mode does not apply — `Edit`/`Write` against a `.md` plan is the **caller's** responsibility (e.g., x-do revises the plan and may re-dispatch review).

**Plan-target completion (replaces all sections below for Target A):**

- **APPROVE** → return the verdict + findings table to the caller. Done. No menu.
- **REQUEST_CHANGES** → return the verdict + findings table to the caller. The caller decides whether to revise the plan, re-dispatch review, or proceed under user override. Do NOT enter Fix Mode.

**Plan-mode handoff envelope (mandatory — surface at the end of the response):**

```
<!-- x-review plan-mode envelope v1 -->
target: plan
target_path: <absolute plan path>
verdict: APPROVE | REQUEST_CHANGES
findings_count: <N>
critical: <N>
high: <N>
medium: <N>
low: <N>
needs_direction_count: <N>   # informational only; caller resolves at plan-revision time
```

Skip everything below this section for Target A. The completion checklist at the bottom still applies (verified findings, synthesis table, verdict, envelope, handoff context) — except the `NEEDS_DIRECTION` row, which is N/A for plan-mode because the Clarification Gate is skipped (`needs_direction_count` surfaces in the envelope only; the caller resolves at plan-revision time).

## Offer Additional Passes (MANDATORY HALT)

**STOP here.** After presenting findings in step 3, you MUST:

1. Show the passes line (compact format from `../../x-shared/done-format.md § Passes Line`) — emit on one line after the verdict summary
2. **WAIT for user input** — do NOT auto-proceed to "Act on Verdict"
3. Only after the user selects passes (or says Done/N) should you continue

S, P, X are read-only and can run in parallel. D modifies files — run it last, never in parallel.

**NEVER skip this gate.** Even if the verdict is REQUEST_CHANGES with obvious fixes, the user may want additional passes first. Auto-invoking `receiving-code-review` without offering this menu is a known compliance gap.

**Letter assignments are fixed. Do not redefine them.** `[S]=Security`, `[P]=Performance`, `[C]=Complexity`, `[X]=Cross-model`, `[V]=Visual`, `[D]=Deslop`, `[A]=All of S/P/C/D`, `[N]=Done`. Any other meaning for these letters is a deviation.

**Passes line (required — use exactly):**

```
Passes: [S]ec [P]erf [C]omplex [X]cross [V]isual [D]eslop · [N] done
```

**Scope-expander rule:** `[P]`, `[C]`, `[D]` widen the review past the bug/security/false-assumption contract. Never auto-run them. If the user picks `[A]`, confirm once: "All passes includes refactor + perf suggestions beyond bugs/security — proceed?" before launching.

## Clarification Gate (MANDATORY HALT — runs after passes menu, before Act on Verdict)

If the synthesis table from step 3 contains ANY row tagged `NEEDS_DIRECTION = ✓`, you MUST halt here and collect user direction BEFORE entering Fix Mode.

**Why this gate exists:** Architectural decisions, ambiguous tradeoffs, and conflicting reviewer recommendations cannot be resolved by the model alone. Auto-fixing one direction silently locks the user out of the other. One user prompt is cheaper than an unwanted refactor.

**Procedure:**

1. **Display the Big Picture header** drafted in step 3 — verbatim, before any clarification block. If missing, halt and demand step 3 produce it before proceeding.
2. **Surface each DECIDE block** using the compact format from `../../x-shared/done-format.md § Shape 3 — DECIDE`, **one at a time** — surface the first, wait for user reply, then surface the next. Do NOT display all blocks at once. Safety rules from step-03 carry through into every DECIDE block: axis-aware Decider footer, security/compliance deferral restriction (option C must say "Fix in immediate follow-up PR" not "keep as-is"), effort label omitted for security/compliance axis. Verify each DECIDE block has a numbered heading and Bottom line before surfacing — if missing, re-draft from step 3's "Draft Clarification Block" template.
3. **Display the meta-finding** if step 3 emitted one (`META: Plan scope mismatch`). Pause for user reaction before listing per-finding choices.
4. **Display the Follow-up options menu** (paste-verbatim block below) AFTER the last clarification block and BEFORE the per-decision prompt. The menu gives the user a top-level route choice; the per-decision prompt only applies if they pick `[P]`.

   **Follow-up options line (from `../../x-shared/done-format.md § Follow-up Options Line` — emit on one line):**

   ```
   → [Y] all recommended · [P] per-decision · [R] review-only · [S] skip flagged · [X] re-dispatch · [N] done
   ```

   **Branching:**
   - `[Y]` Yolo — Before launching: build a one-line summary `"Yolo will apply Recommended for #2:A, #4:A, #7:B and enter Fix Mode — confirm?"` and **WAIT for explicit confirm** (single round-trip). On confirm, lock the recommended option per finding and skip step 5's per-decision prompt. Yolo guardrails:
     - If any Recommended is a deferral (`C` / `skip` / `v2`) on a `security` or `compliance` axis → REJECT yolo, force `[P]`, restate why deferral is forbidden for that axis.
     - If any clarification block lacks an explicit `Recommended:` line → REJECT yolo, force `[P]` for that finding.
     - If meta-finding `META: Plan scope mismatch` is present → REJECT yolo, force `[P]` (plan scope cannot be auto-resolved).
     - Yolo still routes through `superpowers:receiving-code-review` + `superpowers:verification-before-completion` — it skips the prompt, NOT the fix workflow.
   - `[P]` Pick per-decision — fall through to step 5 (the existing per-decision prompt below).
   - `[R]` Review-only — skip Fix Mode entirely. Use the Review-Only Mode checklist under "Act on Verdict / REQUEST CHANGES". Mark every NEEDS_DIRECTION row as `Awaiting author direction` in the handoff context.
   - `[S]` Skip NEEDS_DIRECTION — record every flagged row as `Deferred — awaiting direction` (require `Follow-up tracker:`, `Owner:`, `Deadline:` from user before continuing; same enforcement as option `C` deferral). Fix only unambiguous CRITICAL/HIGH rows. Same axis-aware tracker enforcement applies — `security`/`compliance` rows with dead-gate / open-surface outcome cannot be skipped.
   - `[X]` Re-dispatch — Halt here. Tell the user: "Push or paste the patched diff, then I'll re-run reviewers (step 2) on the new state." Do NOT enter Fix Mode.
   - `[N]` Done — stop. Emit final handoff context block. No fixes, no PR post.

5. **Prompt the user (per-decision)** — only reached if user picked `[P]` above. Use this exact line after the last clarification block:

   ```
   Resolve the decisions above. Reply with the decision number + your pick:
     2: A                       (pick option A for Decision #2)
     5: B                       (pick option B for Decision #5)
     5.a: A                     (sub-decision when one finding has 5.a / 5.b blocks)
     6: C
        Follow-up required: JIRA-123
        Owner: alice
        Deadline: 2026-05-15    (defer with required fields — colon-separated, on their own lines)
     7: skip                    (defer this finding — excluded from Fix Mode)
     3: <free text>             (describe a custom direction)
   Multiple answers in one message OK. Decision numbers match the finding numbers in the table above.
   ```

6. **WAIT for user input.** Do NOT proceed. Do NOT propose answers on the user's behalf. Do NOT auto-pick the recommended option (except via explicit `[Y]` Yolo confirmation in step 4).
7. **Lock direction.** When the user replies, record the chosen option per finding. `skip` removes that finding from Fix Mode scope (note it in the handoff context as deferred). For Yolo: log every locked option as `recommended (yolo)` in the handoff context so the audit trail shows the user accepted recommendations en bloc rather than per-decision.
8. **Tracker enforcement (axis-aware).** If the chosen option is a deferral (C / skip / "v2" / explicit follow-up):
   - For axis = `security` or `compliance` with a dead-gate / open-surface outcome → REJECT the choice, restate why deferral is forbidden for this axis, re-prompt.
   - For axis = `impl` or `product` → require the user provide `Follow-up tracker:`, `Owner:`, `Deadline:` before continuing. If absent, re-prompt with the three fields explicitly listed.
9. **Reject-framing handling (option D).** If user picks D on any finding, halt the entire Fix Mode flow. Surface back: "You're saying the plan itself should change. Restate the new plan goal, then re-run review against it." Do NOT enter Fix Mode for any finding until plan is restated and confirmed.
10. **Split handling (option E).** If user picks E on any finding, fix only that finding in this PR; record other findings as deferred with tracker fields.
11. **Only after every NEEDS_DIRECTION row has an answer or skip (and any tracker fields filled)** may you continue to "Act on Verdict".

**Rules:**

- If the user asks a follow-up question instead of choosing, answer it (read more code if needed), then re-prompt the choice. Do not assume silence = recommendation.
- If the user picks a custom direction not in A/B/C/D/E, restate the chosen direction in plain language and confirm before fixing.
- If the user says "you decide" or "pick the best" on a `product` or `compliance` axis finding: refuse softly. Reply: "This axis needs the [decider] to pick — not me. I can recommend, but you should loop them in." Surface the recommendation again, do not auto-act.
- If the user says "you decide" on `impl` axis: still surface recommendation + tradeoff once more, get explicit ack ("yes go with recommended"). Do not silently take initiative.
- Skipped findings still appear in the final handoff context block as `Deferred — awaiting direction` with axis and tracker fields recorded.

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
- [ ] Handoff context block included (see `../../x-shared/context-envelope.md`)

#### Fix Mode (own code or user requests fixes)

**Default edit tool:** Use `morph-mcp edit_file` for all fix application — partial edits with `// ... existing code ...` markers are faster and preserve context better than full rewrites. Use `morph-mcp codebase_search` to locate targets before editing. Fall back to native `Edit` only if `edit_file` errors.

**Checklist (ALL required before marking complete):**

- [ ] Every NEEDS_DIRECTION row resolved (user picked A/B/C/custom or skipped) — Clarification Gate passed
- [ ] Fix CRITICAL + HIGH findings immediately, using the locked direction from the Clarification Gate
- [ ] Invoke `superpowers:receiving-code-review` for structured fix workflow — do NOT skip even if user says "fix all"
- [ ] After fixes: invoke `superpowers:verification-before-completion` with evidence — manual checks (tsc, lint, build) are insufficient alone
- [ ] Offer re-review if CRITICAL/HIGH findings were fixed (significant changes = re-review)
- [ ] Handoff context block included (see `../../x-shared/context-envelope.md`)

## Completion Checklist (ALL required before finishing)

- [ ] Every CRITICAL/HIGH finding verified against actual code
- [ ] Synthesis table includes Source, Verified, and NEEDS_DIRECTION columns
- [ ] Every NEEDS_DIRECTION row has a recorded user decision (chosen option or skip) — N/A for Target A plan-mode (Clarification Gate skipped; `needs_direction_count` surfaces in envelope)
- [ ] Verdict stated: APPROVE or REQUEST_CHANGES
- [ ] Handoff context block included (see `../../x-shared/context-envelope.md`)

**Do NOT mark review complete until every box is checked.**

## After This Skill

Review passed? Offer: **[F]** Finish branch (`superpowers:finishing-a-development-branch`) | **[D]** Done.
Issues found? Invoke `superpowers:receiving-code-review` for structured fixes, then re-review.

Include a [handoff context](../../x-shared/context-envelope.md) block.
