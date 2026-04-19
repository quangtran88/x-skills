---
name: x-verify
description: Use when a long-running skill needs to check "am I done?" — runs the canonical completion cascade with mandatory fallback to prevent silent success claims
role: verifier
---

# x-verify — Completion Cascade

## Purpose

Single entry point for answering "am I done?" reliably. Every long-running x-skill dispatches here instead of running its own ad-hoc checks.

See `../x-shared/completion-cascade.md` for the full cascade specification.

## Role: verifier

**This skill is a verifier.** It reports completion status; it does not apply fixes.

**x-verify MUST NOT:**
- Call `Edit` or `Write` — if fixes are needed, return findings and let the caller route to an executor
- Call mutating `Bash` commands — only read-only verification (tests, lint, typecheck, git log)
- Claim "done" when the verification cascade didn't actually complete

## Execution

Run the cascade from `../x-shared/completion-cascade.md` in order. **Do not re-document the cascade here** — that file is the single source of truth. If you are editing this file to change cascade logic, stop: edit `completion-cascade.md` instead.

High-level shape (pointer only, full detail in the canonical file):
1. **SCOPE GATE** — un-tooled or docs-only invocation short-circuits to `done`
2. **ABORT** → **EXPLICIT FAILURE** → **VERIFICATION** → **MANDATORY FALLBACK** → **HUMAN-APPROVAL**

**Verifier dispatch (step 4):** call `Agent` tool with `subagent_type: "oh-my-claudecode:code-reviewer"`. Claude-only fallback when OMC is unavailable: `Agent` tool with a generic review prompt (no `subagent_type`). See the canonical file for the fallback contract.

## Output format

Return one of these verdicts:

```yaml
verdict: done
reason: all-checks-passed
details:
  test: passed
  lint: clean
  typecheck: clean
  fallback: (not invoked)
```

```yaml
verdict: failed
reason: test-failed
details:
  test: FAIL (3 failures)
  lint: clean
  typecheck: clean
  findings: [ ... ]
```

```yaml
verdict: aborted
reason: user-abort           # or stagnation-option-D
details: { ... }
```

```yaml
verdict: waiting-for-user
reason: stagnation-menu-open # or human-approval-needed
details: { ... }
menu: [A] alternative-A, [B] alternative-B, [C] alternative-C, [D] abort
```

```yaml
verdict: needs-user-review
reason: all-verification-inconclusive
details:
  test: no-config
  lint: no-config
  typecheck: no-config
  fallback: uncertain (see findings)
  findings: [ ... ]
menu: [A] mark done, [B] re-verify, [C] abort
```

## Rationale

Closes the "verification-before-completion skipped" compliance gap documented in `feedback_xreview_compliance.md`. The mandatory fallback prevents skills from claiming done when they have no actual verification signal.
