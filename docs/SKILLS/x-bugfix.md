# x-bugfix — Bugfix Workflow

> **Purpose:** Structured debugging — routes through investigation, hypothesis testing, and verified fix with evidence collection.

---

## Iron Law

> **NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST.** If you can't state the root cause in one sentence, you haven't investigated enough.

---

## Detection (4 Modes)

| Mode | Detect When | Route |
|------|-------------|-------|
| **Q: Quick Fix** | Trivial: lint error, type error, syntax fix, single obvious typo | Read error → locate → fix → verify |
| **A: Quick Bug** | Clear error, single component, obvious root cause | Streamlined investigate → fix |
| **B: Deep Investigation** | Ambiguous, causal, multi-component, intermittent | Read `references/mode-b-deep.md` |
| **C: System/Infra** | CI/CD, deployment, performance, server/DB issues | Read `references/mode-c-system.md` |

---

## Pre-Flight Checklist

1. Capture baseline: Record exact error messages, failing test output, stack traces (copy-paste, not paraphrase)
2. Read error messages carefully — don't skip stack traces
3. Read `gotchas.md` for known failure patterns
4. `git log --oneline -10 -- <affected-files>` — regression = root cause is in the diff

---

## Mode A: Quick Bug Workflow

```
Investigate
  ├─ Use native `Grep` / OMO `explore` as FIRST search tool
  ├─ Fall back to OMO explore only for parallel multi-tool investigation
  ├─ Consult references/backward-tracing.md for deep call stacks
  ├─ Consult references/pattern-catalog.md to narrow search space
  └─ Output: root cause hypothesis (specific and testable)

Hypothesize & Test
  ├─ Scientific method — one variable at a time
  ├─ Instrumentation Pivot (after 2 failed iterations): STOP speculating, add logs, monitor live system
  └─ 3-Strike Rule: 3 iterations without progress → delegate to OMO oracle

Fix & Verify
  ├─ Write regression test that FAILS without the fix
  ├─ Implement single fix addressing root cause (minimal diff)
  ├─ Run test suite — no regressions
  ├─ Fresh verification — reproduce original scenario, confirm fixed
  └─ Prevention gate — read references/prevention-gate.md, apply defense-in-depth
```

---

## Post-Fix Verification

- TS/JS projects: `npx tsc --noEmit` + `npx eslint <changed-files>` + full test suite
- Debug report: Output per `references/debug-report-template.md`
- Append root cause summary to `debug-log.jsonl` for cross-session pattern tracking

---

## Completion Status

| Status | When |
|--------|------|
| **DONE** | Root cause found, fix applied, tests pass, prevention in place |
| **DONE_WITH_CONCERNS** | Fixed but cannot fully verify (intermittent, needs staging) |
| **BLOCKED** | Root cause unclear after investigation, or fix exceeds safe scope |
| **NEEDS_CONTEXT** | Missing information to proceed |

---

## Dependencies

- `../x-omo/SKILL.md` — OMO agent catalog
- `../x-shared/invocation-guide.md`, `workflow-chains.md`, `context-envelope.md`
- `../x-do/references/iteration-patterns.md` — 3-Strike Rule + Instrumentation Pivot
- `references/{mode-b-deep,mode-c-system,backward-tracing,pattern-catalog,prevention-gate,debug-report-template,evidence-hierarchy}.md`
