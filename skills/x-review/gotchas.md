# x-review Gotchas

Known failure patterns specific to x-review. For shared OMO patterns, see `../x-shared/common-gotchas.md`.

## Dispatch & launch

- **All 3 reviewers MUST launch in ONE message.** Agent (code-reviewer) + Bash (omo-agent oracle) + Skill (requesting-code-review) in a single response. Separate messages = sequential execution, not true parallelism. This is a step-02 checklist item.
- **Self-grep is NOT the Claude code-reviewer.** When the parent context is already opus, the model is tempted to skip the Agent code-reviewer dispatch and self-verify with `Read`/`Bash grep`. This is a step-02 violation. The Agent runs in a separate context window with no exposure to the parent's reasoning bias — its findings differ. Always dispatch all 3 reviewers regardless of parent model. Evidence: session 1ba866d1 (Apr 30, 2026) launched only `omo-agent --model gpt`, substituted self-grep for code-reviewer, missed the all-3-in-one-message gate entirely.
- **`--model gpt` is for plan review only — code/diff review uses `oracle`.** Step-02 routes Target A (plans) to `omo-agent --model gpt` (blocker-finder, OKAY/REJECT verdict) and Targets B/C/D (code/diff) to `omo-agent oracle`. The two are NOT interchangeable — they have different prompts, different output shapes, and different cost profiles. The model conflates them because both are "the GPT perspective." If you are reviewing a PR, file, or diff, your Bash command MUST be `omo-agent oracle "..."`, never `omo-agent --model gpt "..."`. Evidence: session 9ba4f817 (Apr 30, 2026) reviewed PR #151 (Target C) with `--model gpt`, naming the output file `/tmp/oracle-review.out` despite never invoking the oracle agent. Earlier evidence: session 1ba866d1 had a related substitution.
- **Auto-detect (Target D) can pick up unrelated uncommitted changes.** If the user is reviewing specific work, ask them to narrow the scope rather than reviewing everything.
- **code-reviewer opus is slow on large codebases.** For quick reviews of small changes, sonnet is sufficient. Reserve opus for complex/risky reviews.

## Agent failures & limits

- **Large diffs overwhelm OMO agents.** If the diff exceeds ~500 lines, summarize the key changes rather than passing the full diff. Focus the prompt on the riskiest areas.
- **Large PRs (30+ files) can timeout even with summarized prompts.** For PRs with 30+ files or 3000+ changed lines, split the oracle into 2 focused calls (e.g., frontend + backend) rather than one omnibus prompt. Each gets its own 600s budget. A single ~3000-char summary covering 7+ review areas timed out in practice (PR #113, 41 files, exit code 124).
- **Oracle timeout is not a dead end.** If oracle times out, check the output file for partial results. Partial output with at least one severity-rated finding + file reference is usable — note `(partial)` in synthesis. See step-02 "Handling Agent Failures" for the full protocol.
- **Oracle can exhaust context and produce no findings (primary or supplementary).** Despite omo-agent's budget prefix instruction, the oracle may read all prompted files then keep exploring until it runs out of tokens without writing `<result>` tags. The output is then empty after noise stripping. Mitigation: embed key content summaries in the prompt instead of listing files to read, and limit the focus to 2-3 specific areas. For supplementary [X] passes, a truncated pass is not a blocker — note it in synthesis and move on. For the **primary oracle in step 2**: check output after ~5 minutes; if still empty after ~10 minutes, proceed with Claude-only findings and note the oracle gap in synthesis. Do not wait indefinitely.
- **code-reviewer agent can exhaust budget exploring without producing findings.** On large codebases, the opus code-reviewer may spend all its tokens reading files and never synthesize a summary. Mitigation: include the diff/content directly in the prompt rather than asking it to explore, and end the prompt with "Output your findings as a severity-ranked table — do not spend tokens exploring beyond what is provided."

## Output quality

- **Cross-model review (GPT-5.4) sometimes flags Claude-style patterns as issues.** Use judgment — if the flagged pattern matches the project's existing conventions, it's not a real finding.
- **Security reviewer can be noisy on internal-only code.** If the code never faces user input or external traffic, some OWASP findings are false positives. Note the context when presenting findings.

## Verdict & synthesis

- **`APPROVE_WITH_FIXES` is not a valid verdict.** Step-03 mandates binary APPROVE | REQUEST_CHANGES. If blockers exist, verdict is REQUEST_CHANGES — severity tiers communicate that some findings are minor. Inventing a third state ("APPROVE_WITH_FIXES", "APPROVE_WITH_CONCERNS", "APPROVE_WITH_NITS", "APPROVE WITH NITS", "CONDITIONAL_APPROVE") collapses the gate that triggers receiving-code-review and the passes menu. Evidence: session 9ba4f817 (Apr 30, 2026) wrote `Verdict: APPROVE WITH NITS` for a MEDIUM-only finding set, then offered a custom `[D] Fix Mode / [F] Finish / [N] Done` menu instead of the canonical passes menu. Binary verdict is non-negotiable regardless of how minor the findings feel.
- **Invoke `verification-before-completion` after REQUEST_CHANGES fixes.** Running tsc + tests manually is not enough — the skill provides structured verification with evidence collection. Step-03 explicitly requires it.
- **Offer re-review after significant fixes.** If you fixed CRITICAL or HIGH findings, offer to re-run the review. Step-03 explicitly requires this for REQUEST_CHANGES verdicts.

## Passes menu & fix mode

- **Additional passes menu must be shown before acting on verdict.** The session will naturally want to auto-invoke `receiving-code-review` after a REQUEST_CHANGES verdict. Step 3 requires showing the S/P/C/X/V/D/A/N menu and waiting for user input FIRST. This gate was added after a session skipped it entirely (ea578ff4).
- **Letter redefinition in the passes menu is forbidden.** `[D]` means Deslop. It does NOT mean "Done", "Fix Mode", "Apply diff", or anything else. `[F]` is reserved for finishing-a-development-branch (post-APPROVE), not for inserting fix-mode triggers. If you find yourself rewriting the menu with new letter meanings, STOP — paste the canonical menu from `references/review-passes.md` verbatim. Evidence: session 9ba4f817 redefined `[D]` as "Fix Mode" and dropped `[S][P][C][X][V][A]` entirely.
- **[X] pass is redundant after default cross-model.** When oracle already ran as one of the 3 primary reviewers, the [X] pass adds marginal value. Use [C] Complexity instead for structural analysis, or ask the user whether they want a second GPT perspective with a different prompt.
- **Deslop after other passes, never in parallel.** Deslop modifies files — running it alongside other review passes causes conflicts or stale findings.
- **"Apply all" / "fix all" / "1" is the receiving-code-review trigger, not a bypass.** When the user picks the "apply fixes" option after a REQUEST_CHANGES verdict, the natural pull is to skip straight to `morph-mcp edit_file`. Step-04 explicitly forbids this: invoke `superpowers:receiving-code-review` first for the structured fix workflow, then edit. The user choosing "fix all" is the EXACT trigger this rule warns about — not an exception to it.
- **Terse "Done" summaries skip the handoff envelope.** When fixes land cleanly, the model wants to wrap up with a bullet list and "Done." Step-04 completion checklist requires a handoff context block (see `../x-shared/context-envelope.md`). Paste the envelope template even when output looks complete — bullet recap is not a substitute.

## Architecture

- **Rigid step structure is deliberate.** The step-file architecture uses NEVER/ALWAYS language because flexible versions caused models to skip critical steps (merging review/synthesis, dropping verification gates). If you're tempted to skip or reorder steps, check here first — the rigidity prevents real failures.
