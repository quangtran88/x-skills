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
```

## Why paste-verbatim

Inlining the block as `<SCOPE_GUARD>` placeholder risks lossy paraphrase. The reviewers (oracle, gpt, code-reviewer) calibrate their output to the literal wording. Partial inclusion = partial scope filter = scope creep returns.

If you find yourself rewriting the block "in your own words" before sending the prompt, STOP — re-read this file and paste it whole.
