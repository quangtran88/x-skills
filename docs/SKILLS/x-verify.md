# x-verify — Completion Verifier

> **Role:** `verifier`  
> **Purpose:** Single entry point for answering "am I done?" reliably. Every long-running x-skill dispatches here instead of running ad-hoc checks.

---

## Completion Cascade (5 Steps)

```
SCOPE GATE (short-circuit check)
  ├─ Only-reads invocation? → return done immediately
  ├─ Docs-only changes? → return done
  ├─ Non-code tree? → return done
  └─ Code project with real config? → proceed to Step 1

Step 1: ABORT check
  ├─ User said abort/cancel/stop? → return aborted
  ├─ Stagnation menu fired AND user picked D? → return aborted
  └─ Otherwise → proceed

Step 2: EXPLICIT FAILURE check
  ├─ Last tool call returned fatal error? → return failed
  └─ Otherwise → proceed

Step 3: VERIFICATION check (primary)
  ├─ Discover test/lint/typecheck commands from project config
  ├─ Run resolved commands in order
  ├─ Any non-zero? → return failed
  ├─ All clean? → return done
  └─ All "no-config"? → proceed to Step 4

Step 4: MANDATORY FALLBACK — dispatch verifier
  ├─ Primary: Agent tool with subagent_type="oh-my-claudecode:code-reviewer"
  ├─ Fallback (OMC unavailable): Agent tool with generic review prompt
  └─ Verdict: pass → done, fail → failed, uncertain → needs-user-review

Step 5: HUMAN-APPROVAL check
  └─ Surface ambiguous status menu to user, wait for input
```

---

## Verdicts

| Verdict | Meaning | Next Action |
|---------|---------|-------------|
| `done` | All checks passed | Proceed to handoff menu |
| `failed` | Test/lint/typecheck failed or verifier rejected | Fire `verification-failed` reaction |
| `aborted` | User chose abort or stagnation option D | Exit workflow immediately |
| `waiting-for-user` | Stagnation menu open, needs user choice | Pause, do NOT loop |
| `needs-user-review` | All verification inconclusive | Surface menu: [A] mark done, [B] re-verify, [C] abort |

---

## Rollout State

| Skill | Apply Cascade? | Status |
|-------|---------------|--------|
| `x-do` | **Yes** | **Live** |
| `x-bugfix` | No (yet) | Deferred — inline verification is current contract |
| `x-research` | No | Research has "synthesis done", not "completion" |
| `x-review` | No | Reviews return verdicts, not "done" |
| `x-design` | No (yet) | Deferred |
| `x-api-pentest` | No (yet) | Deferred |

---

## Dependencies

- `../x-shared/completion-cascade.md` — canonical cascade specification (single source of truth)
- `oh-my-claudecode:code-reviewer` — primary verifier dispatch target
