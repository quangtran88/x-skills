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

## Present Findings

```
### Review: [target description]
**Verdict:** APPROVE | REQUEST_CHANGES

| # | Severity | Finding | Source |
|---|----------|---------|--------|
| 1 | CRITICAL | ... | Claude |
| 2 | HIGH | ... | GPT |
| 3 | MEDIUM | ... | Claude + GPT |
```

## Next Step

Read fully and follow `step-04-act.md`.
