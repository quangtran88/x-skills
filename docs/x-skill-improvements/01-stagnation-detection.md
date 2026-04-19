# 01 — Stagnation Detection: Strengthen Existing Mechanisms

**Tier:** 1 (apply first)
**Source:** OpenCode Orchestrator (`~/.claude/research/orchestration/opencode-orchestrator/docs/03-patterns.md` § 4)
**Touches:** `x-do/references/iteration-patterns.md`, `x-do/references/delegation-and-scaling.md`, `x-bugfix/SKILL.md` (local x-skills only). `ralph`/`ultrawork` are OMC-plugin-cache skills — `feedback_no_external_deps.md` forbids editing them.
**Status:** applied: 2026-04-09
**Estimated effort:** 30–45 minutes (targeted amendments to 3 existing files)

## Problem

Long-running loop skills (`ralph`, `ultrawork`, `autopilot`, `x-do` in iterative mode) can loop on impossible problems. The loop condition is "until done," but when the agent makes zero progress, it doesn't notice.

**Evidence:**
- `ralph` and `ultrawork` loop until done with no ceiling
- The failure mode is silent: the user only notices after 30+ tool calls without progress
- This is the #1 reason users cancel long-running workflows prematurely (loss of trust)

## Existing coverage (why a new section is unnecessary)

Research revealed that stagnation handling already exists in 3 places:

| Mechanism | Location | What it does |
|---|---|---|
| **Stuck Detection** | `x-do/references/iteration-patterns.md` §2 | 3 failures → review; 5 → pivot; 10 → STOP |
| **Delegation table** | `x-do/references/delegation-and-scaling.md:10` | >3 iterations → delegate to `--model codex` (replaces UNAVAILABLE `hephaestus`) |
| **3-Strike Rule** | `x-bugfix/SKILL.md:70` | 3 failed hypotheses → delegate to `oracle` |
| **Delegation table** | `x-bugfix/SKILL.md:103` | Stalled >3 iterations → `--model codex` (replaces UNAVAILABLE `hephaestus`) |
| **Gotchas warning** | `x-bugfix/gotchas.md:11` | "Oracle delegation too late at 3+ iterations" |

The original v1 proposal claimed "no existing skill has a 'give up and escalate' clause" — that was factually incorrect for x-bugfix.

**What's genuinely missing** from these existing mechanisms:
1. No concrete definition of "progress" — what counts as a failure vs. progress?
2. No concrete definition of "iteration" — vibes-based, self-gameable
3. No structured diagnostic checklist — just "review what failed"

## Proposal (revised): Amend existing, don't layer

Instead of adding a new 60-line "Stagnation Guard" section that overlaps with 3 existing mechanisms, **strengthen the existing mechanisms** with the novel parts from the OpenCode Orchestrator pattern.

### Change 1: Add progress signals and iteration definition to `iteration-patterns.md` §2

Replace the current §2 "Stuck Detection" (lines 14-22) with:

```markdown
## 2. Stuck Detection

Track consecutive iterations without progress. When an approach isn't working, pivot instead of grinding.

### What counts as progress

| Signal | Counts as progress when |
|---|---|
| **Test state** | Any test moved red→green or green→red since last iteration |
| **File state** | Any file was modified with a non-empty diff |
| **Error state** | A previously-failing tool call succeeded, OR a new distinct error message appeared |

If **none** of these changed → that iteration produced no progress.

### What counts as an iteration

One iteration = one mutating tool call (`Edit`/`Write` or mutating `Bash`) + one verification call (test/lint/tsc or reading the edited file). Read-only exploration doesn't count — the guard only tracks mutate+verify pairs.

### Escalation ladder

| No-progress iterations | Action |
|---|---|
| 3 | **Pause.** Re-read last 5 tool outputs in full (no summarization). State the actual blocker in one sentence, plain English. If you can name a different approach, try it. |
| 5 | **Pivot.** Delegate to `oracle` or `--model codex` (replaces UNAVAILABLE `hephaestus`) for a fresh perspective. State what you tried and why it failed. |
| 7 | **STOP.** Surface to user: state the blocker, list what was tried, propose 2-3 genuinely different alternatives. Wait for user input before continuing. |

*Threshold rationale:* 3 is lenient enough to avoid false positives on slow-but-valid work. 7 is the hard stop — beyond that, the agent is burning tokens. If 3 triggers too often on healthy runs, raise to 4. If stagnation is caught too late, lower 7 to 5. Re-evaluate after one week of usage.
```

### Change 2: Align x-do delegation table

In `x-do/references/delegation-and-scaling.md`, update the stalled-iterations row to reference the escalation ladder:

```markdown
| Implementation stalled (see iteration-patterns.md §2 escalation ladder) | `oracle` at 5, `--model codex` if oracle insufficient (replaces UNAVAILABLE `hephaestus`) | Different model, different approach |
```

### Change 3: Align x-bugfix 3-Strike Rule

In `x-bugfix/SKILL.md`, update the 3-Strike Rule to use progress signal definitions:

```markdown
**3-Strike Rule:** 3 hypothesis iterations (mutating tool call + verification — see `../x-do/references/iteration-patterns.md` §2 for definitions) without any progress signal changing → STOP. Delegate to OMO `oracle` for a fresh perspective. If oracle confirms architectural issue → escalate to user.
```

And update the delegation table row:

```markdown
| Stalled >3 iterations (per iteration-patterns.md §2 definitions) | `--model codex` | Deep autonomous worker (replaces UNAVAILABLE `hephaestus`) |
```

## Migration steps

**Step 1** — Apply Change 1 to `x-do/references/iteration-patterns.md`. This is the canonical definition that other files reference.

**Step 2** — Apply Change 2 to `x-do/references/delegation-and-scaling.md`. One-line update to reference the canonical source.

**Step 3** — Apply Change 3 to `x-bugfix/SKILL.md`. Two edits: 3-Strike Rule wording + delegation table row.

**Step 4** — Run a real task to validate (see below).

**No Step 4 for ralph/ultrawork** — they live in plugin cache. The pattern is documented here for upstream contribution if/when it makes sense.

## Validation

**Test case 1 — Force stagnation deliberately:**
Give `x-do` a task with a hard-coded contradiction (e.g., "make this test pass" where the test is impossible without editing the test). Expected: at iteration 3, agent pauses and re-reads outputs. At iteration 5, delegates to oracle. At iteration 7, surfaces to user.

**Test case 2 — Real-world task:**
Run `x-do` on a genuine stuck task. Expected: escalation ladder fires before the user needs to cancel manually.

**Test case 3 — Happy path (no false positives):**
Run `x-do` on a normal multi-step task. Expected: progress signals keep changing, escalation never fires.

**Success metric:** On a stuck task, the agent surfaces to the user within 7 iterations instead of 15+. The 3-iteration pause catches most issues before delegation is needed.

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| False positive on slow-but-valid progress | Medium | Read-only exploration excluded from iteration count. Agent must mutate+verify to tick the counter. |
| Agent "cheats" by making trivial edits | Medium | Better than looping — the trivial edits show up in tool history. Monitor and tighten if observed. |
| Cross-file reference fragility (x-bugfix → iteration-patterns.md) | Low | One canonical source is better than 3 divergent copies. If the reference breaks, the x-bugfix 3-Strike Rule still works standalone. |

**Rollback plan:** Revert the 3 files to their previous state. Changes are additive — no existing behavior is removed, only refined.

## What changed from v1

The original v1 proposed a 60-line "Stagnation Guard" section copy-pasted into both x-do and x-bugfix. Research found:

1. **3 existing mechanisms already cover ~80% of the value** — the "no give up clause" claim was wrong
2. **Copy-pasting creates 4 overlapping mechanisms** with conflicting thresholds and actions
3. **The novel value is in concrete definitions** (progress signals, iteration = tool-call pairs), not in a new section

Revised approach: amend 3 existing files with the concrete definitions, keep one canonical source (`iteration-patterns.md`), align references. Same value, ~1/4 the surface area.

## Patterns we considered and rejected

**Full Stagnation Guard section (v1 of this proposal)** — a 60-line mandatory section with 7-step diagnostic checklist, user menu with 3 alternatives + abort. Rejected because:
- Overlaps with 3 existing mechanisms at the same thresholds
- Copy-paste into 2 skills violates DRY when `iteration-patterns.md` already exists as a shared reference
- The 7-step diagnostic checklist is more ceremony than needed — the 3-step escalation ladder (pause → delegate → stop) achieves the same outcome with less cognitive load
- User menu with alternatives is good but belongs at step 7 (hard stop), not step 3

**Speculative planning during idle time** (from OpenCode Orchestrator) — rejected in v1, still rejected. x-skills don't have an "idle CPU" problem.

**Diagnostic mode as a separate skill** — rejected in v1, still rejected. Adds indirection without clarity.

## Out of scope

- **Measuring whether progress is "good" progress** — that's code review, not stagnation detection
- **Automatic recovery** — the ladder escalates to delegation and then to user; it never auto-picks alternatives
- **Persistent stagnation history** — would require state, violating stateless principle

## References

- Source pattern: `~/.claude/research/orchestration/opencode-orchestrator/docs/03-patterns.md` § "4. Adaptive intelligence loop (stagnation → diagnostic mode)"
- Existing mechanisms: `x-do/references/iteration-patterns.md` §2, `x-do/references/delegation-and-scaling.md:10`, `x-bugfix/SKILL.md:70,103`
- Related skills: `ralph`, `ultrawork`, `x-do`, `x-bugfix`, `autopilot`
