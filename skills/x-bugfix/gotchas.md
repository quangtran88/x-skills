# x-bugfix Gotchas

Known failure patterns specific to x-bugfix. For shared OMO patterns, see `../x-shared/common-gotchas.md`.

- **Jumping to fix before understanding.** The #1 failure mode. If you're writing code before you can state the root cause in one sentence, stop and investigate more.
- **Stacking fixes.** Testing multiple changes at once makes it impossible to isolate what worked. One hypothesis, one change, one test. Always.
- **Confusing symptoms for root cause.** A TypeError at line 50 is a symptom. The null value that propagated from line 12 in a different file is the root cause. Trace backward, fix at the source.
- **Mode B overkill on simple bugs.** Not every bug needs 3 competing hypotheses. If the stack trace points to one file and the error is clear, use Mode A.
- **Forgetting the regression test.** A fix without a failing test is a fix that will regress. Write the test BEFORE implementing the fix to prove it's meaningful.
- **Guessing without observability.** After 2 failed fix attempts, the next move is NOT another guess — it's the **Instrumentation Pivot** (see SKILL.md → Mode A → Hypothesize & Test). If you're tempted to "just try one more thing", instrument first. The bug always lives in the branch you didn't log.
- **Selective logging hides the bug.** When you instrument, cover the FULL call chain — entries, branches, state mutations, exits — and log decision variables (IDs, flags, lengths, set membership), not just "got here" markers. The "obvious suspect" path is rarely where the bug actually lives, otherwise you'd have already fixed it.
- **Oracle delegation too early.** Don't delegate to oracle after the first failed attempt. Give yourself 2 honest tries with different hypotheses first — and run the instrumentation pivot before escalating.
- **Oracle delegation too late.** If you've been grinding for 3+ iterations on the same issue (and instrumentation has already happened), you're past the point of productive solo debugging. Delegate.
- **Sanitize before web search.** Strip hostnames, IPs, file paths, SQL, customer data before searching for error patterns. Search the error category, not the raw message.
- **Blast radius creep.** If your "bug fix" is touching 10+ files, it's probably a refactor disguised as a fix. Flag it and discuss scope with the user.
- **Skipping the prevention gate.** The prevention gate (`references/prevention-gate.md`) is mandatory but easy to forget after a successful fix. Even if your fix incidentally includes defense-in-depth, explicitly read and evaluate the gate — it catches categories you didn't think of.
- **ESLint skip after tsc passes.** TypeScript compilation passing doesn't mean lint passes. Always run both: `npx tsc --noEmit` AND `npx eslint <changed-files>`. They catch different classes of issues.
- **Skipping the debug report template.** After a successful fix + review cycle, it's tempting to skip the formal report. The template (`references/debug-report-template.md`) forces you to document regression test status, blast radius, and prevention measures — all commonly skipped when the fix "obviously works." Output the template even when the fix is clean.
