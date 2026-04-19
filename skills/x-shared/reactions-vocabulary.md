# Reactions Vocabulary (Canonical Triggers)

The canonical set of triggers an x-skill's `reactions:` block may fire. Skills only fire triggers from this vocabulary. If a skill needs a new trigger, add it here — do not invent ad hoc.

See proposal `docs/x-skill-improvements/02-reactions-block.md` for the full schema and design rationale.

## Trigger list

| Trigger | Fires when |
|---|---|
| `research-needed` | skill classified the task as needing research before acting (routes to x-research) |
| `plan-needed` | skill classified the task as needing a plan before executing (routes to writing-plans) |
| `research-complete` | x-research synthesis done |
| `plan-complete` | writing-plans skill finished a plan doc |
| `plan-approved` | user said yes to a plan |
| `implementation-complete` | all code changes for one mode complete |
| `test-failed` | test runner returned non-zero |
| `test-passed` | test runner returned zero after at least one test ran |
| `lint-failed` | lint tool reported errors (not warnings) |
| `lint-warning` | lint tool reported warnings only |
| `typecheck-failed` | tsc / mypy / etc reported errors |
| `typecheck-passed` | type checker clean |
| `verification-failed` | verification-before-completion cascade returned fail |
| `verification-passed` | verification cascade clean |
| `review-approved` | reviewer (x-review or code-reviewer) returned approve |
| `review-changes-requested` | reviewer returned non-approve with specific issues |
| `stagnation-detected` | from proposal 01 — 3 iterations no progress |
| `human-approval-needed` | skill hit a blocking decision requiring user input |
| `skill-done` | terminal state reached, ready to hand back to user |

## Trigger × role cross-reference

Not every trigger applies to every skill. Use this table to find which triggers your role MUST handle vs may ignore.

| Trigger | Required for | Optional for | N/A for |
|---|---|---|---|
| `research-needed` | router | — | reviewer, verifier |
| `plan-needed` | router | — | reviewer, verifier, researcher |
| `research-complete` | router | — | reviewer, verifier |
| `plan-complete` | router | — | reviewer, verifier |
| `plan-approved` | router | — | reviewer, verifier |
| `implementation-complete` | router | — | researcher, verifier |
| `test-failed` | router | — | researcher |
| `test-passed` | router | verifier | researcher |
| `lint-failed` | router | — | researcher |
| `typecheck-failed` | router | — | researcher |
| `verification-failed` | router | — | researcher |
| `verification-passed` | router | verifier | researcher |
| `review-approved` | reviewer | router | researcher, verifier |
| `review-changes-requested` | reviewer | router | researcher, verifier |
| `stagnation-detected` | router | — | reviewer, researcher |
| `human-approval-needed` | all roles | — | — |
| `skill-done` | all roles | — | — |

**Guidance for new skills:** start with triggers marked "Required for" your role. Add "Optional for" triggers only when your workflow explicitly references them. Ignore "N/A" triggers — declaring them in your reactions block is noise. Role taxonomy is currently `router | reviewer | verifier`; additional roles (e.g., orchestrator, bugfixer) will be added to this table when declared by a live skill.

## Reaction schema (for reference)

```yaml
reactions:
  <trigger-name>:
    action: route | inline-fix | re-review | menu | notify | skip | abort | continue
    to: <skill-name>          # required for action: route or re-review
    retries: <int>            # default 0
    auto: <bool>              # default true; false = require user approval
    options: [opt1, opt2]     # required for action: menu
    escalateAfter: <duration> # e.g., 30m — escalate if not complete
```

## Phase status (as of 2026-04-19)

- **Phase 1 (documentation surface):** reactions blocks are declarative prose the model self-reads. No runtime execution contract — the prose in the skill body is still authoritative. Pilot skill: `x-do`.
- **Phase 2 (execution contract):** deferred. Will add self-check discipline (evaluate triggers after every tool call, respect `auto: false`, never silently skip). Do not ship until Phase 1 has a real-session track record in 3+ skills.
