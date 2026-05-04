# Verification and Completion

Every long-running x-skill must evaluate completion via the **completion cascade**. Skipping any step is a silent failure that reproduces the "verification-before-completion skipped" compliance gap.

## Where the Cascade Lives

- **Canonical definition**: `skills/x-shared/completion-cascade.md`
- **Dispatcher**: `x-verify` skill — a thin dispatcher that invokes the cascade in order
- **Per-skill invocation**: Each long-running skill references `x-verify` in its "Completion" section

Skills do NOT reimplement the cascade locally. They dispatch to `x-verify` or reference `completion-cascade.md`.

## SCOPE GATE

This gate runs **BEFORE step 1** and can short-circuit the entire cascade. It exists because step 4 dispatches a verifier subagent, which is expensive and would fire on every run in any project without configured test/lint/typecheck.

### Short-Circuit Conditions

| Condition | Action |
|-----------|--------|
| **Only-reads invocation** | Return `done` immediately. Nothing changed, nothing to verify. |
| **Docs-only changes** | Return `done` with note "no executable changes; verification not applicable". |
| **Non-code tree** | Return `done`. Project has no code-project markers. |
| **Fresh/no-op test config** | Return `done` with note "test script is the default npm-init placeholder; treat as no-config". |
| **Code project with real config** | **Proceed to step 1.** |

## The Cascade

Execute in order. First match wins.

### Step 1: ABORT Check

- Did the user say abort / cancel / stop (direct in-prompt)?
- Did the stagnation menu fire AND the user pick option D (abort)?
  - **Note**: stagnation firing alone is NOT an abort — it surfaces a menu that may route to an alternative via A/B/C. Only option D converts stagnation into `aborted`.
- If the menu is waiting for user input, return `waiting-for-user`, not `aborted`.
- If **yes** → return `aborted`. Do not continue.

### Step 2: EXPLICIT Failure Check

- Did the last tool call return a fatal error (non-zero exit, exception, network timeout)?
- If **yes** → return `failed`. Fire the `verification-failed` trigger. Do not claim done.

### Step 3: VERIFICATION Check (Primary)

**Command discovery** (first match wins per tool):

1. `package.json` `scripts.<test|lint|typecheck>` — if present, use it
2. Project-specific config detected:
   - test: `pytest` (pytest.ini), `cargo test` (Cargo.toml), `go test ./...` (go.mod)
   - lint: `eslint <changed-files>` (eslint.config.*), `ruff check`, `golangci-lint run`
   - typecheck: `tsc --noEmit` (tsconfig.json), `mypy`, `pyright`
3. Neither present — mark "<tool>: no-config" and continue

**Call the resolved verification commands in order**:
1. **Test** — If no command resolves, mark "test: no-config" and continue
2. **Lint** — Same rule
3. **Typecheck** — Same rule

- If any ran and returned non-zero → return `failed`
- If all ran clean → return `done`
- **Special case**: all three returned "no-config" → go to step 4

### Step 4: MANDATORY FALLBACK — Dispatch Verifier

This is the step that closes the silent-failure hole.

**Primary dispatch**: `Agent` tool with `subagent_type: "oh-my-claudecode:code-reviewer"`

**Claude-only fallback**: If OMC is unavailable, fall back to `Agent` tool with a generic review prompt (no `subagent_type`, `mode: auto`). Note the fallback inline so the user can see which path was taken.

The verifier reads the diff and performs semantic verification by inspection:
- Are the changes internally consistent?
- Do the new functions have the right signatures?
- Do tests that *should* exist for this change exist?
- Are there obvious regressions (null dereferences, unhandled promises, dangling references)?

The verifier returns one of:
- `pass` → return `done`
- `fail` → return `failed`, surface findings
- `uncertain` → return `needs-user-review`, surface menu

**You MUST execute step 4 whenever step 3 cannot produce a verdict AND the SCOPE GATE did not short-circuit.** Skipping step 4 when step 3 was inconclusive is exactly the "verification-before-completion skipped" compliance gap.

### Step 5: HUMAN-APPROVAL Check

If none of the above returned a verdict, the skill is in an ambiguous state. Surface to user:

```
🟡 Completion status: ambiguous
- Test: <status>
- Lint: <status>
- Typecheck: <status>
- Verifier: <status>

What should I do?
[A] Mark as done (skip verification)
[B] Re-run verification
[C] Abort
```

Wait for user input. Do not silently claim done.

## Output Format

x-verify returns one of these verdicts:

### `done`

```yaml
verdict: done
reason: all-checks-passed
details:
  test: passed
  lint: clean
  typecheck: clean
  fallback: (not invoked)
```

### `failed`

```yaml
verdict: failed
reason: test-failed
details:
  test: FAIL (3 failures)
  lint: clean
  typecheck: clean
  findings: [ ... ]
```

### `aborted`

```yaml
verdict: aborted
reason: user-abort           # or stagnation-option-D
details: { ... }
```

### `waiting-for-user`

```yaml
verdict: waiting-for-user
reason: stagnation-menu-open # or human-approval-needed
details: { ... }
menu: [A] alternative-A, [B] alternative-B, [C] alternative-C, [D] abort
```

### `needs-user-review`

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

## When to Apply the Cascade

| Skill | Apply cascade? | Rollout state |
|-------|---------------|---------------|
| `x-do` | Yes | **Live** — dispatches `Skill tool: x-verify` |
| `x-bugfix` | No (yet) | **Deferred.** Runs own post-fix verification inline (tsc + eslint + tests + debug-report). Do NOT silently dispatch x-verify. |
| `x-research` | No | Research has "synthesis done", not "completion". |
| `x-review` | No | Reviews return verdicts, not "done". |
| `x-design` | No (yet) | **Deferred.** Completion is file landing + advisory. |
| `x-skill-improve` | No (yet) | **Deferred.** Validated via optional `/x-skill-review` handoff. |
| `x-api-pentest` | No (yet) | **Deferred.** Step-05/06 synthesis + curl repro substitute today. |
| `x-omo` | No | Routes to other CLIs; completion is the target CLI's responsibility. |
| `x-gemini` | No | Read-only advisor; no completion concept. |

**Half-state notice**: The cascade is the canonical contract but only `x-do` ships with it wired today. The "deferred" rows are an honest in-progress signal, not silent drift.

## Role: Verifier

**x-verify is a verifier.** It reports completion status; it does not apply fixes.

**x-verify MUST NOT**:
- Call `Edit` or `Write` — if fixes are needed, return findings and let the caller route to an executor
- Call mutating `Bash` commands — only read-only verification
- Claim "done" when the verification cascade didn't actually complete

## x-verify Slot Resolution

x-do's frontmatter declares:
```yaml
slots:
  verifier: x-verify
```

Before claiming done, x-do resolves the verifier slot per the 3-layer cascade:
1. User in-prompt override? → wins
2. Skill frontmatter `slots:` block → `x-verify`
3. Schema default → `verification-before-completion`

x-do surfaces the resolution inline before dispatching:
> "Dispatching verifier slot → resolved to x-verify via skill frontmatter default"

## Post-Implementation Verification (MANDATORY)

After completing implementation in any TS/JS project, run before claiming done:

1. **TypeScript check**: `npx tsc --noEmit` (or project-specific typecheck command)
2. **ESLint check**: `npx eslint <changed-files>` (or project-specific lint command)

Fix all errors before proceeding to review or completion.

## x-do Reactions Block

x-do's frontmatter declares reactions that fire based on cascade outcomes:

```yaml
reactions:
  test-failed:
    action: route
    to: x-bugfix
    retries: 2
    auto: true
  lint-failed:
    action: route
    to: x-bugfix
    auto: true
  typecheck-failed:
    action: route
    to: x-bugfix
    auto: true
  verification-failed:
    action: re-review
    to: x-verify
    auto: true
  implementation-complete:
    action: menu
    options: [commit, x-review, plan-next, done]
    auto: false
  stagnation-detected:
    action: menu
    options: [alternative-A, alternative-B, alternative-C, abort]
    auto: false
  human-approval-needed:
    action: notify
    auto: false
```

- `test-failed` / `lint-failed` / `typecheck-failed` → auto-route to `x-bugfix` (up to 2 retries)
- `verification-failed` → re-review via `x-verify`
- `implementation-complete` → show handoff menu (commit, review, plan-next, done)
- `stagnation-detected` → show stagnation menu (alternatives or abort)
- `human-approval-needed` → notify user, wait for input

## Prevention Gate (x-bugfix)

After fixing a bug, x-bugfix applies a **prevention gate**:

1. Defense-in-depth layers
2. Type safety improvements
3. Error handling enhancements

Prevent the bug *class*, not just this instance. Include a "Prevention Measures" section in the debug report.
