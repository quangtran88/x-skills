# x-skill Completion Cascade

Every long-running x-skill MUST evaluate completion via this cascade. Skipping any step is a silent failure that reproduces the "verification-before-completion skipped" compliance gap.

## SCOPE GATE (read before running the cascade)

**This gate runs BEFORE step 1 and can short-circuit the entire cascade.** It exists because step 4 dispatches a verifier subagent, which is expensive and would fire on every run in any project without configured test/lint/typecheck. Without this gate, the cascade is a menu-fatigue bomb.

Before dispatching any cascade step, check whether the invocation has verifiable surface area:

- **Only-reads invocation** — Did this skill invocation call zero `Edit`/`Write` and zero mutating `Bash`? → return `done` immediately. Nothing changed, nothing to verify.
- **Docs-only changes** — Were all modified files in `docs/`, `*.md` outside source dirs, `README`, `CHANGELOG`, dotfiles outside code trees, or plain-text config? → return `done` with note "no executable changes; verification not applicable".
- **Non-code tree** — Does the project have no code-project markers (`package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `pom.xml`, `Gemfile`, etc.)? → return `done`.
- **Code project, but fresh/no-op test config** — Does `package.json` exist, but its `test` script is the default no-op pattern (`echo "Error: no test specified" && exit 1` or similar literal placeholder)? → return `done` with note "test script is the default npm-init placeholder; treat as no-config". Same rule for `pyproject.toml` with no configured runner, `Cargo.toml` with no test targets, etc.
- **Code project with real config** — Has code-project markers AND at least one of {configured test command, configured lint command, configured typecheck command} → **proceed to step 1.**

## The cascade (execute in order, first match wins)

### 1. ABORT check

- Did the user say abort / cancel / stop (direct in-prompt)?
- Did the stagnation menu (proposal 01) fire AND the user pick option D (abort)? **Note:** stagnation firing alone is NOT an abort — it surfaces a menu that may route to an alternative via A/B/C. Only option D converts stagnation into `aborted`. If the menu is waiting for user input, return `waiting-for-user`, not `aborted`.
- *(Requires 02 Phase 2)* Did a reaction with `action: abort` fire AND its `auto: false` precondition resolve (if any)? Until Phase 2 ships, user-in-prompt abort is the only signal this step reads.
- If **yes** → return `aborted`. Do not continue.

**Interaction protocol with proposal 01 (stagnation guard):**

| Stagnation state | x-do loop behavior | x-verify call behavior |
|---|---|---|
| Menu fires, waiting for user | x-do pauses. Does NOT call x-verify while menu is open. | N/A — not called |
| User picks A / B / C (alternative approach) | x-do resets iteration counters, resumes loop. Alternative applied in NEXT iteration. | Called at end of resumed iteration. Treats prior stagnation as resolved. |
| User picks D (abort) | x-do exits loop. | Called once during exit. Step 1 returns `aborted`. |
| Iteration completes normally, no stagnation | x-do calls x-verify per Completion section | Normal cascade |

This protocol prevents 01+06 from being wired inconsistently. x-verify step 1 reads the _outcome_ of the stagnation menu, never the raw signal.

### 2. EXPLICIT failure check

- Did the last tool call return a fatal error (non-zero exit, exception, network timeout)?
- *(Requires 02 Phase 2)* Did a reaction with `action: skip` fire or did a declared `retries` counter exceed? Until Phase 2 ships, only direct tool-call error signals are read here.
- If **yes** → return `failed`. Fire the `verification-failed` trigger (consumed by caller's reactions block). Do not claim done.

### 3. VERIFICATION check (primary)

**Command discovery (first match wins per tool):**
1. `package.json` `scripts.<test|lint|typecheck>` — if present, use it (e.g., `npm test`, `npm run lint`, `npm run typecheck`).
2. Project-specific config detected — fall through to the direct command:
   - test: `pytest` (pytest.ini, pyproject.toml `[tool.pytest]`), `cargo test` (Cargo.toml), `go test ./...` (go.mod).
   - lint: `eslint <changed-files>` (eslint.config.* or .eslintrc.*), `ruff check` (ruff config), `golangci-lint run` (golangci config).
   - typecheck: `tsc --noEmit` (tsconfig.json), `mypy` (mypy config), `pyright` (pyrightconfig.json).
3. Neither present — mark "<tool>: no-config" and continue. Do **not** invent a command.

Call the resolved verification commands in order:
  1. **Test** — If no command resolves (or the SCOPE GATE flagged a placeholder), mark "test: no-config" and continue.
  2. **Lint** — Same rule.
  3. **Typecheck** — Same rule.
- If any ran and returned non-zero → return `failed`.
- If all ran clean → return `done`.
- **Special case: all three returned "no-config"** → go to step 4. (The SCOPE GATE already ruled out projects where this would cause menu fatigue — any un-tooled project that reaches step 3 is one that has real code-project markers AND real code surface, so step 4 is appropriate.)

### 4. MANDATORY FALLBACK — dispatch verifier

This is the step that closes the silent-failure hole.

**Primary dispatch:** `Agent` tool with `subagent_type: "oh-my-claudecode:code-reviewer"`. Hard-coded target; retrofit to the `verifier` slot (declared in skill frontmatter) is a deferred follow-up. The slot is typed `skill-or-agent` since `code-reviewer` is an OMC agent, not a skill.

**Claude-only fallback (OMC unavailable):** If the `oh-my-claudecode:code-reviewer` subagent is not resolvable in the current harness, fall back to `Agent` tool with a generic review prompt (no `subagent_type`, `mode: auto`) per CLAUDE.md § "Claude-Only Fallback Routing". Note the fallback inline ("Used Claude-only fallback — OMC code-reviewer unavailable") so the user can see which path was taken.

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

### 5. HUMAN-APPROVAL check

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

## When to apply this cascade

| Skill | Apply cascade? |
|---|---|
| `x-do` | Yes — primary consumer, pilot target |
| `x-bugfix` | Yes — after fix is applied (**deferred** to follow-up rollout) |
| `x-research` | No — research has no "completion" in this sense; it has "synthesis done" |
| `x-review` | No — reviews return verdicts, not "done" |
| `x-design` | Yes — after design artifact is written (**deferred** to follow-up rollout) |
| `x-omo` | No — routes to other CLIs; completion is the target CLI's responsibility |
| `ralph` / `ultrawork` | **Out of scope** — external OMC plugin-cache skills; suggest upstream if at all. |

## Where the cascade lives (single source of truth)

- **Canonical definition:** this file (`x-shared/completion-cascade.md`).
- **x-verify role:** a thin dispatcher skill that invokes the cascade in order. x-verify does NOT re-document the cascade — it references this file. If you find yourself duplicating a step description in x-verify, stop and link here instead.
- **Per-skill invocation:** each long-running skill references `x-verify` in its "Completion" section. They do not reimplement the cascade locally.
- **Verifier dispatch (step 4):** hard-coded `code-reviewer` via `Agent` tool; retrofit to the `verifier` slot is a deferred follow-up.
- **SCOPE GATE behavior:** runs before step 1; short-circuits when the project has no verifiable surface (no code markers, docs-only, only-reads).
