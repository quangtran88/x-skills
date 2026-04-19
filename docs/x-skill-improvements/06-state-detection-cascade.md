# 06 — Mandatory Completion Cascade for Long-Running Skills

**Tier:** 2 (apply after Tier 1 stable)
**Source:** Composio Agent Orchestrator `getActivityState` cascade (`~/.claude/research/orchestration/agent-orchestrator/docs/03-patterns.md` § 4)
**Scope:** this repo only — `/Users/randytran/Codes/x-skills/`
**Touches (initial ship):** `skills/x-shared/completion-cascade.md` (new), `skills/x-verify/SKILL.md` (new), `skills/x-do/SKILL.md` (add Completion section), `CLAUDE.md` (add x-verify to skill table)
**Deferred:** rollout to `x-bugfix` + `x-design`, `verifier` slot retrofit (post-05), `x-skill-review` checklist (external), `ralph`/`ultrawork` (external, upstream-only)
**Status:** applied 2026-04-19 (initial ship — x-do pilot; x-bugfix/x-design rollout deferred)
**Estimated effort:** 2–3 hours for the initial ship (pilot on x-do)
**Depends on:** Proposal 02 Phase 1 applied (reactions block exists in x-do frontmatter — the cascade cites triggers by name). Proposal 05 is **NOT** a hard dependency for the initial ship — per `00-overview.md:102`, step 4 dispatches `code-reviewer` via `Agent` tool directly with `subagent_type: "oh-my-claudecode:code-reviewer"`. The `verifier` slot retrofit lands later, once 05 v1 is stable.

## Problem

Long-running skills need to answer "am I done?" reliably. Today the answer is a single check that varies by skill:

- `x-do` checks "did the last edit succeed?"
- `x-bugfix` checks "did the hypothesis verify?"
- `superpowers:verification-before-completion` checks "did tests pass + lint pass + tsc pass?"
- `ralph` / `ultrawork` check "did the boulder move?" (external plugins, out of scope here)

**Three concrete problems:**

1. **Single-check detection is fragile.** If the check has one failure mode not covered (e.g., "no test command configured" → skip test check → claim done), the skill declares success prematurely. `feedback_xreview_compliance.md` lists "verification-before-completion skipped" as a recurring gap — exactly this failure mode.

2. **Different skills check different things.** No shared vocabulary for "done." `x-do` can say done when `x-bugfix` wouldn't, because they're asking different questions.

3. **No mandatory fallback.** If the primary check returns "don't know" (missing tool, missing config, timeout), skills typically default to "assume done." Composio AO documented the real-world version of this bug: their OpenCode plugin's native activity detector returned null due to an unrelated bug, and **without a mandatory fallback, the entire activity flow returned null and the dashboard silently showed nothing for the session's whole lifetime**. That's the same failure shape as "verification silently skipped" in the compliance gaps.

## Pattern (from Composio AO)

Composio AO's `getActivityState` method enforces a **mandatory 5-step cascade**:

```typescript
async getActivityState(session, readyThresholdMs?): Promise<ActivityDetection | null> {
  // 1. PROCESS CHECK — always first
  if (!running) return { state: "exited", timestamp };

  // 2. ACTIONABLE STATES (waiting_input / blocked) — from JSONL
  const actionable = checkActivityLogState(activityResult);
  if (actionable) return actionable;

  // 3. NATIVE SIGNAL — agent-specific session API

  // 4. JSONL ENTRY FALLBACK — ALWAYS IMPLEMENT
  const fallback = getActivityFallbackState(activityResult, activeWindow, threshold);
  if (fallback) return fallback;

  // 5. Return null only if no data at all
}
```

**Step 4 is mandatory.** Skipping it caused the real production bug. The load-bearing discipline: multiple data sources, strict cascade order, **one step in the middle marked mandatory** — can't skip even if it seems redundant, because the earlier steps' silent failures are exactly what it catches.

Applied to x-skills: every long-running skill evaluates completion via a canonical cascade with a mandatory fallback that catches the primary check's silent failures.

## Enforcement honesty

Claude Code's Skill tool doesn't enforce that a skill calls x-verify before claiming done — the Completion section is self-applied prose. Same enforcement class as 02's reactions, 04's roles, 07's precedence ladder. Value comes from:
- A single canonical cascade doc authors can reference instead of reinventing.
- A thin dispatcher skill (`x-verify`) skills can invoke by name.
- The SCOPE GATE preventing the cascade from firing on docs PRs or scratch dirs.

If the model skips the Completion section, the discipline fails. `x-skill-review` (deferred external) would be the audit surface.

## Proposal

### Part A — Canonical completion cascade (new doc)

Create `skills/x-shared/completion-cascade.md`:

```markdown
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

**Rationale:** The mandatory step 4 fallback exists to catch code projects whose verification commands silently fail to run. It should not fire on a docs PR, a scratch directory, a plain-text repo, or a fresh `npm init -y` project that hasn't been wired up yet. An earlier draft embedded this as a mid-cascade "step 3.5" substep; it was promoted to a leading scope gate after cross-model review flagged that a sub-numbered step reads as optional refinement, while this check is load-bearing — the cascade is actively harmful without it.

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

- Call the project's canonical verification commands in order:
  1. **Test** — `npm test` / `pytest` / project-specific. If not configured (including "default placeholder" detected by the SCOPE GATE above), mark "test: no-config" and continue.
  2. **Lint** — `eslint` / `ruff` / project-specific. If not configured, mark "lint: no-config" and continue.
  3. **Typecheck** — `tsc --noEmit` / `mypy`. If not configured, mark "typecheck: no-config" and continue.
- If any ran and returned non-zero → return `failed`.
- If all ran clean → return `done`.
- **Special case: all three returned "no-config"** → go to step 4. (The SCOPE GATE already ruled out projects where this would cause menu fatigue — any un-tooled project that reaches step 3 is one that has real code-project markers AND real code surface, so step 4 is appropriate.)

### 4. MANDATORY FALLBACK — dispatch verifier

This is the step that closes the silent-failure hole.

**Initial ship (this application):** dispatch `code-reviewer` directly via `Agent` tool with `subagent_type: "oh-my-claudecode:code-reviewer"`. Hard-coded. Do not invent a `verifier` slot yet — proposal 05 v1 hasn't shipped.

**Later retrofit (post-05 v1):** route through the `verifier` slot (declared in skill frontmatter). Slot type will need to be `skill-or-agent` since `code-reviewer` is an OMC agent, not a skill — resolve that in the 05 v1 spec, not here.

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
- **Verifier dispatch (step 4):** hard-coded `code-reviewer` via `Agent` tool for the initial ship. Retrofit to the `verifier` slot once 05 v1 is stable.
- **SCOPE GATE behavior:** runs before step 1; short-circuits when the project has no verifiable surface (no code markers, docs-only, only-reads).
```

### Part B — Wrap `superpowers:verification-before-completion` via a new `x-verify` skill

**Constraint:** `feedback_no_external_deps.md` rules out editing `superpowers:verification-before-completion` directly.

**Approach:** Create a local wrapper skill (`x-verify`) in this repo. It runs the cascade and *calls* `verification-before-completion` as part of step 3. The cascade is an x-skill concern, not a superpowers concern.

Create `skills/x-verify/SKILL.md`:

```markdown
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

**Verifier dispatch (step 4, initial ship):** call `Agent` tool with `subagent_type: "oh-my-claudecode:code-reviewer"`. Hard-coded. A future retrofit will route this through the `verifier` slot once proposal 05 v1 ships.

Drift between this pointer and the canonical file is a bug. `x-skill-review` should grep this skill for any expanded re-documentation of cascade steps and flag it (follow-up, since x-skill-review is external to this repo).

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
```

**Note on frontmatter:** this skill declares `name` / `description` / `role` only. Earlier drafts included a `slots: verifier: code-reviewer` block, but that was aspirational — 05 hasn't shipped, so `slots:` has no resolution mechanism. Add `slots:` in a later retrofit once 05 v1 is stable.

### Part C — Wire x-verify into `x-do` (pilot)

**Placement rule (per proposal 04 Part C):** the Completion section MUST be prominent — near the top of the skill body or mirrored as a HARD RULE callout. Buried "Completion" sections at the bottom are exactly the skimmable prose that enables silent-skip compliance gaps.

Add this section to `skills/x-do/SKILL.md` (position: near the top of the body, after the existing "## Role: router" section):

```markdown
## Completion (MANDATORY)

Before claiming done, dispatch x-verify via the Skill tool:

```
Skill tool: x-verify
```

x-verify runs the completion cascade (see `../x-shared/completion-cascade.md`). Honor its verdict:

- `verdict: done` → proceed to the handoff menu
- `verdict: failed` → fire `verification-failed` reaction (routes to re-review, then re-execute if approved)
- `verdict: needs-user-review` → surface x-verify's menu to the user, wait for input

**Do not claim done without calling x-verify.** This is the single biggest compliance-gap closer.
```

x-bugfix and x-design get the same section on follow-up rollout, not in this application.

### Part D — Register x-verify in the repo `CLAUDE.md`

Creating a new skill means updating the repo's skill table. In `CLAUDE.md`, add a row after `x-review`:

```markdown
| **x-verify** | Run the completion cascade ("am I done?") | Standalone |
```

Update the count in the opening sentence from "10 skills" to "11 skills" (or adjust the phrasing to avoid a hard count).

### Deferred — follow-up rollout

**Once the x-do pilot succeeds:**

- Wire `x-verify` into `x-bugfix/SKILL.md` Completion section
- Wire `x-verify` into `x-design/SKILL.md` Completion section
- Retrofit step 4 to use the `verifier` slot (after 05 v1 ships with `skill-or-agent` slot type)
- Extend `x-skill-review` with checklist item "Does this long-running skill call x-verify before claiming done?" (external — belongs in a PR against the skill's home)

## Migration steps

All steps in this application edit files in this repo only.

**Step 1** — Create `skills/x-shared/completion-cascade.md` (Part A). Pure documentation.

**Step 2** — Create `skills/x-verify/SKILL.md` (Part B). New skill, no existing file modified.

**Step 3** — Add the Completion section to `skills/x-do/SKILL.md` (Part C). Preserve existing frontmatter (including `role: router` + `reactions:` block added by 02) and all other body sections.

**Step 4** — Update `CLAUDE.md` skill table to include x-verify (Part D).

**Step 5** — Dry-run pilot: pick a task that historically would have declared done prematurely (easy edit in a project with no test command). Run x-do on it with the new Completion section. Verify:
- x-verify gets invoked
- SCOPE GATE evaluates correctly
- If the project has no real config, verdict is `needs-user-review`, not `done`

**Exit gate for promoting beyond pilot:** the x-do pilot succeeds once (a) completion-cascade.md + x-verify SKILL.md + x-do's Completion section are wired and dry-run-audited, (b) one real session shows x-do invoking x-verify before its done claim. Only then extend to x-bugfix and x-design.

## Validation

**Test 1 — Files exist and cross-reference correctly.** After Step 1+2, `completion-cascade.md` exists, x-verify's SKILL.md exists, and x-verify's execution section points at the canonical cascade doc (does not re-document it).

**Test 2 — x-do's Completion section is prominent.** After Step 3, x-do's body has a Completion section near the top, not buried at the bottom. It names x-verify by skill-invocation form.

**Test 3 — SCOPE GATE short-circuits docs-only runs.** In a live session, x-do is invoked to edit a `docs/foo.md` file. x-verify is called, SCOPE GATE returns `done` without reaching step 3 or 4.

**Test 4 — Mandatory fallback fires on configured code project.** In a project with code markers but no configured test/lint/typecheck, x-verify reaches step 4 and dispatches `code-reviewer`. Verdict is one of `done` / `failed` / `needs-user-review` — **never silently `done` based on step 3's empty result.**

**Test 5 — CLAUDE.md table entry is correct.** After Step 4, x-verify appears in the skill table and the count matches actual skills.

**Success metric:** the "verification-before-completion skipped" compliance gap stops recurring in x-do sessions. Validation becomes structurally hard to skip.

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Agent skips x-verify by claiming done inline | Medium | Completion section is prominent and mandatory. Self-check: "if you're about to claim done, have you called x-verify? If no, STOP." |
| **Menu fatigue in un-tooled projects** — cascade fires on every docs PR or scratch-dir edit | **High without the SCOPE GATE** | Mitigated by the SCOPE GATE. Do not ship this cascade without the gate. If you find yourself editing out the gate, stop and surface to the user. |
| Step 4 (fallback) is expensive (dispatches a subagent) | Medium | Only fires when steps 1–3 are inconclusive AND the SCOPE GATE judged the project needs verification. In un-tooled non-code trees, the gate short-circuits to `done`. |
| `code-reviewer` hard-coded dispatch becomes stale when 05 v1 ships | Low | Part B + Part A both explicitly call out the retrofit path. The `verifier` slot replaces the hard-coded call in one edit once 05 lands. |
| Ambiguous `needs-user-review` verdict interrupts the user too often | Low-Medium | Only fires when verification is genuinely inconclusive AND the gate said the project has code surface. If it fires often on real code projects, the project lacks basic verification and the user *should* be prompted. |
| Wrapping `superpowers:verification-before-completion` instead of replacing it feels redundant | Low | The wrapper adds the mandatory fallback and the SCOPE GATE; the wrapped skill is still the primary check. Wrapping respects `feedback_no_external_deps.md`. |
| Backward compat — old x-do invocations don't call x-verify | Low | Migration adds Completion section to each skill. Skills without it continue to work (just without the cascade). No breakage. |
| `x-verify` and `completion-cascade.md` become two sources of truth | Low-Medium | Policy: cascade is canonical, x-verify is a thin dispatcher. `x-skill-review` (deferred) greps for re-documentation drift. |
| 02 Phase 2 dependencies in cascade steps 1/2 (reaction-fired abort/skip) never materialize | Medium | Annotated in-line. Until 02 Phase 2 ships, those cascade bullets are no-ops; user-in-prompt abort is the only active signal. |

**Rollback plan:** delete the Completion section from x-do, delete `x-verify/SKILL.md`, delete `completion-cascade.md`, revert the `CLAUDE.md` table edit. Skill falls back to previous verification approach.

## Patterns considered and rejected

**Embed the cascade in every skill** — rejected. Duplicates the cascade N times; each copy drifts; violates DRY.

**Cascade as a slash command** — rejected. Slash commands are user-invoked; we need auto-fire.

**Cascade as a Claude Code hook** — rejected. No such event ("skill about to claim done") exists in the harness.

**Runtime state to track cascade progress** — rejected. Stateless principle. Cascade is per-invocation, not per-session.

**Replace `verification-before-completion` instead of wrapping** — rejected. Violates `feedback_no_external_deps.md`.

**Ship with slot-resolved verifier from day 1** — rejected. Proposal 05 v1 hasn't shipped; inventing a slot mechanism here would fork infrastructure. Hard-code and retrofit later.

**Make x-verify re-document the cascade inline (skip the shared doc)** — rejected. Two sources of truth is the exact drift failure mode x-skill-review exists to catch.

## Out of scope

- **Cross-skill cascade composition** — x-verify is a leaf; it doesn't compose further.
- **Per-step timeouts** — optimization for later.
- **Cascade telemetry** (count of step 4 fires vs step 3) — requires state. Log to claude-mem if desired.
- **Project-specific cascade variants** — cascade is canonical. Projects override via the future `verifier` slot, not the cascade structure.
- **Partial verdicts** (e.g., "mostly done except edge case") — verdicts are terminal: done / failed / needs-user-review.
- **`verifier` slot retrofit** — deferred until 05 v1 ships.
- **`x-skill-review` checklist item** — external (skill lives outside this repo).
- **`ralph` / `ultrawork`** — external OMC plugin-cache skills.

## References

- Source pattern: `~/.claude/research/orchestration/agent-orchestrator/docs/03-patterns.md` § "4. The mandatory `getActivityState` cascade"
- The real production bug: `~/.claude/research/orchestration/agent-orchestrator/docs/02-key-components.md` § "Agent Plugin Contract — `getActivityState`" (the OpenCode plugin story)
- Compliance gap closed: 1 of 6 ("verification-before-completion skipped"). Per `00-overview.md:75` primary-owner table.
- Related proposals: 01 (stagnation feeds into step 1 ABORT check), 02 Phase 1 applied — cascade uses the `verification-failed` trigger from x-do's reactions block; 02 Phase 2 deferred — reaction-driven abort/skip in cascade steps 1/2 are gated on Phase 2 shipping; 04 (roles — x-verify's `role: verifier` forbids Edit/Write); 05 v1 deferred — `verifier` slot retrofit happens post-05; 07 applied — precedence ladder governs how per-project cascade overrides resolve once 05 v2 lands.
