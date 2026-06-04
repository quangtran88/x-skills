# Triage & Adversarial Verification

Curiosity generates noise: a worker may flag intended behavior as a defect. A
finding becomes a reported bug ONLY after an independent verify pass — triage
never trusts the worker that raised it.

## The gate

For each unique finding on the merged board, dispatch a fresh verifier (a
different agent instance than the one that found it) to **independently verify**
the defect by reproducing it against the live service:

- Re-run the minimal repro from `evidence.request`.
- Confirm `observed` actually contradicts `expected` and the documented domain
  rule / invariant — not a misread of intended behavior.
- For a `false-case`, re-read the resulting state to confirm the wrong result
  persisted (not a stale read).

Verdict:
- reproduced + genuinely wrong → set `status: confirmed`.
- behaves as intended / cannot reproduce → set `status: rejected` (with reason).

Only `confirmed` findings are minted into cases (`scripts/explore/finding-to-case.sh`)
and surfaced in `QA_REPORT.md`. **Default to `rejected` when uncertain** — a false
bug report costs more team trust than a missed minor edge.

## Why a separate pass

Same rationale as the repo's reviewer/verifier separation (`~/.claude/CLAUDE.md`
"Keep authoring and review as separate passes"): the agent that hunted a bug is
biased toward believing it. A second, adversarial set of eyes filters false
positives before they reach the report.
