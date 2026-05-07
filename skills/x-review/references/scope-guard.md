# Scope Guard

Prepend this block VERBATIM to every reviewer prompt (Agent code-reviewer, omo-agent oracle, omo-agent --model gpt, requesting-code-review). Do not summarize, paraphrase, or partially include — paste the whole block.

```
SCOPE: Report only (1) bugs that affect correctness, (2) security issues, (3) false
assumptions where the spec/plan/code claims something the implementation contradicts,
(4) deviations from the stated plan/PR intent.

DO NOT report: new features, alternative approaches, performance suggestions
unless they are user-visible bugs, refactor/restructuring proposals, style/naming,
test-coverage suggestions for code that already has tests, architectural redesigns,
"future-proofing" or extensibility the spec did not ask for, documentation polish.

If a finding does not name a concrete bug, security flaw, or false assumption,
omit it. Do not downgrade out-of-scope findings to LOW — drop them.

Test for every finding: "If we shipped this as-is and a user hit it, would
something break, leak, or behave wrong?" If no → drop it.

NEEDS_DIRECTION flag (use sparingly): For an IN-SCOPE finding (bug / security /
false-assumption / plan-deviation) where two or more valid fixes exist and the
choice has a user-visible, security, or product tradeoff that the implementer
should not pick alone, append `NEEDS_DIRECTION: <one-line reason>` to that
finding and list the candidate fixes briefly (1 line each, named A/B/...).

Output format example:
  Severity: HIGH
  Finding: foo() returns null when input cache is cold; callers deref unchecked.
  NEEDS_DIRECTION: two valid patches; product impact differs.
    A) Fail-fast — throw at foo(); callers see explicit error.
    B) Default empty — return [] at foo(); silent recovery, may hide upstream bug.

DO NOT use NEEDS_DIRECTION for refactor proposals, architecture redesigns,
style preferences, or "I'd do this differently" — those are out of scope and
must still be dropped. The flag is for ambiguous fixes to real bugs, not for
surfacing design debates.
```

## Why paste-verbatim

Inlining the block as `<SCOPE_GUARD>` placeholder risks lossy paraphrase. The reviewers (oracle, gpt, code-reviewer) calibrate their output to the literal wording. Partial inclusion = partial scope filter = scope creep returns.

If you find yourself rewriting the block "in your own words" before sending the prompt, STOP — re-read this file and paste it whole.
