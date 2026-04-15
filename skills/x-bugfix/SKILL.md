---
name: x-bugfix
description: Use when the user reports a bug, error, test failure, or unexpected behavior — routes through investigation, hypothesis testing, and verified fix with structured evidence collection
---

# x-bugfix — Universal Bugfix Command

Smart entry point for bugs and investigations. Detects severity, routes through the optimal debugging workflow, and produces verified fixes with evidence.

## Bootstrap

**MANDATORY first step — do this BEFORE anything else:**
Read `~/.claude/skills/x-omo/SKILL.md` to load the OMO agent catalog, invocation commands, and model routing. This ensures you know how to invoke OMO agents (`oracle`, `explore`, `librarian`, `multimodal-looker`) via Bash — they are NOT OMC agents. **Do NOT dispatch to `hephaestus`, `atlas`, `prometheus`, `metis`, or `momus` — they are UNAVAILABLE due to a plugin compat bug. Use `--model codex` (autonomous deep work) or `--model gpt` (strategic / review) instead. See `~/.claude/skills/x-omo/gotchas.md`.**

## Invocation

For how to invoke skills, OMO agents, and OMC agents, see `../x-shared/invocation-guide.md`.

## Dependencies

This skill references shared infrastructure and sibling skills:
- `~/.claude/skills/x-omo/SKILL.md` — OMO agent catalog (loaded in Bootstrap)
- `../x-shared/invocation-guide.md` — tool invocation patterns
- `../x-shared/workflow-chains.md` — cross-skill chaining (handoff to `/x-review`)
- `../x-shared/context-envelope.md` — handoff context block format
- `../x-do/references/iteration-patterns.md` — iteration definitions for the 3-Strike Rule and Instrumentation Pivot
- `references/{mode-b-deep,mode-c-system,backward-tracing,pattern-catalog,prevention-gate,debug-report-template,evidence-hierarchy}.md` — mode routes, protocols, and templates
- `gotchas.md` — known failure patterns
- `config.json` — `omo_agent` path and `state_dir` for `debug-log.jsonl`

## Iron Law

**NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST.** If you can't state the root cause in one sentence, you haven't investigated enough.

## Detection

Classify the bug into ONE mode:

| Mode | Detect When | Route |
|------|------------|-------|
| **Q: Quick Fix** | Trivial: lint error, type error, syntax fix, single obvious typo | Read error → locate file → fix → typecheck/lint only |
| **A: Quick Bug** | Clear error, single component, obvious root cause path | Streamlined investigate → fix below |
| **B: Deep Investigation** | Ambiguous, causal, multi-component, intermittent | Read `references/mode-b-deep.md` |
| **C: System/Infra** | CI/CD, deployment, performance, server/DB issues | Read `references/mode-c-system.md` |

## Pre-Flight (MANDATORY)

- [ ] **Capture baseline:** Record exact error messages, failing test output, and stack traces (copy-paste, not paraphrase). This becomes the before/after comparison for verification.
  - **Behavioral bug?** (duplication, wrong output, timing issue — no error/stack trace exists): Capture expected vs. actual behavior as the baseline instead. Document what the user observes and what correct behavior looks like.
- [ ] Read error messages carefully — don't skip stack traces
- [ ] Read `gotchas.md` for known failure patterns
- [ ] `git log --oneline -10 -- <affected-files>` — regression = root cause is in the diff

## Available Tools

| Tool | When It Helps | How |
|------|--------------|-----|
| `morph-mcp` → `codebase_search` | **First choice** for tracing code flow, finding callers, locating related code | MCP tool — semantic search, faster than spawning agents |
| `morph-mcp` → `edit_file` | **Default** for applying fixes — partial edits with `// ... existing code ...` markers | MCP tool |
| `morph-mcp` → `github_codebase_search` | Investigating how an external library works internally | MCP tool |
| `superpowers:systematic-debugging` | Bug with unclear root cause | Skill — 4-phase discipline |
| `superpowers:test-driven-development` | Writing the regression test | Skill |
| `superpowers:verification-before-completion` | **Always** — before claiming fixed | Skill |
| OMC `debugger` | Complex multi-component investigation | Agent |
| OMC `tracer` | Competing hypotheses (Mode B) | Agent |
| OMO `oracle` | Fresh perspective after instrumentation pivot + 3 failed attempts | Bash (omo-agent) |
| OMO `explore` | Codebase search when morph `codebase_search` insufficient (multi-tool parallel) | Bash (omo-agent) |

## Mode A: Quick Bug

### Investigate

Gather evidence before forming hypotheses. Reproduce the bug, check recent changes, trace the data flow backward from symptom to source. **Use `morph-mcp codebase_search` as your first search tool** for tracing call chains, finding related code, and locating error origins — it's semantic and faster than spawning explore agents. Fall back to OMO `explore` only when you need parallel multi-tool investigation. For deep call stacks, use the backward tracing technique in `references/backward-tracing.md`. Consult `references/pattern-catalog.md` to narrow the search space.

If no pattern matches, search for the error: sanitize first (strip hostnames, IPs, file paths, SQL, customer data), then search "{framework} {sanitized error type}". If the error is too specific to sanitize safely, skip the search.

Output: a **root cause hypothesis** — specific and testable.

### Hypothesize & Test

Scientific method — one variable at a time. Form a single hypothesis, test minimally, verify. If wrong, form a NEW hypothesis — don't stack fixes.

**Instrumentation Pivot (after 2 failed iterations) — MANDATORY before another guess:** When two trial fixes haven't moved the needle, STOP speculating and instrument the system before the next attempt. Add targeted debug logs along the suspected call chain, run the live system to reproduce, then read the logs in chronological order. Form the next hypothesis from observed state, not assumptions.

- **Cover the full chain, don't be selective.** Log every entry point, branch, state transition, callback boundary, and error catch on the suspected path. Selective logging hides the gap you can't see — the bug always lives in the branch you didn't instrument.
- **Log decision variables.** IDs, flags, lengths, set membership, payload sizes — anything that drives control flow. "It got here" is much weaker than "it got here with `streamStopped=true, sending=false, bufferLen=23`."
- **Run the live system.** Logs without reproduction are noise. Trigger the bug end-to-end (chat bot, async pipeline, real Slack/HTTP traffic — whatever the bug requires) and capture the full log timeline before reading.
- **Observation beats speculation.** Real-world evidence: ~10 hours of speculative Slack-streaming fixes were resolved within one logging-and-monitor cycle once the full call chain was instrumented at every branch. Adding 5–10 log lines feels like overkill until it isn't.
- **Then resume.** Form a fresh hypothesis from log evidence and continue Hypothesize & Test. Clean up the logs after the fix lands (or downgrade the most useful ones to permanent debug-level if the bug class recurs).

**3-Strike Rule:** 3 hypothesis iterations (mutating tool call + verification — see `../x-do/references/iteration-patterns.md` §2 for definitions) without any progress signal changing → STOP. The instrumentation pivot above must have already run by this point. If instrumentation has happened and you still can't form a confident root cause, delegate to OMO `oracle` for a fresh perspective. If oracle confirms architectural issue → escalate to user.

### Fix & Verify

1. Write a regression test that **fails** without the fix
   - **No test harness?** If the affected component has no test infrastructure: note "NO_TEST_HARNESS" in the debug report, write a manual verification protocol (exact steps to confirm the fix works), and add a TODO comment in the code for future test coverage. Do not skip silently.
   - **Behavioral/runtime bug requiring live system?** If a unit-level regression test isn't feasible (e.g., requires running chat bot, async pipeline, external service), note "LIVE_SYSTEM_REQUIRED" in the debug report and document: (1) the code-path trace showing before/after behavior, (2) why a unit test isn't feasible, (3) what integration test would cover it. Do not silently skip the test step.
2. Implement a **single fix** addressing root cause — minimal diff
3. Run test suite — no regressions (if no suite exists for the component, run the nearest available suite for regression safety)
4. Fresh verification — reproduce original scenario using captured baseline, confirm fixed with before/after comparison
   - **Behavioral/runtime bug?** If reproduction requires a running system (chat bot, server, async pipeline), trace the code path manually: walk through the fix with concrete input values, document the expected before/after behavior change in the debug report. This substitutes for live reproduction, not for verification itself.
5. **Prevention gate (MANDATORY)** — read `references/prevention-gate.md` and apply: defense-in-depth layers, type safety, error handling as applicable. Prevent the bug *class*, not just this instance. Include a "Prevention Measures" section in the debug report.

**Blast radius:** Fix touches >5 files? Flag it and ask the user before proceeding.

## Mode Q: Quick Fix

For trivial issues where root cause is self-evident from the error message.

1. Read the error message — lint error, type error, or syntax fix
2. Locate the affected file(s) — usually named in the error
3. Fix directly — no hypothesis testing needed
4. Verify: `npx tsc --noEmit` + `npx eslint <changed-files>` (or project equivalents)
5. Compare against captured baseline — confirm error is gone

Skip: hypothesis testing, pattern catalog, OMO delegation, debug report. Still requires pre-flight baseline capture and before/after comparison.

## Proactive OMO Delegation

| Signal | Delegate To | Why |
|--------|------------|-----|
| **2 failed hypotheses** | **Instrumentation pivot** (add logs + monitor live system) | Observation beats speculation; reveals actual state vs. assumed state |
| 3+ failed hypotheses (after instrumentation) | `oracle` | Fresh perspective from a different model |
| Codebase search needed (simple) | `morph-mcp codebase_search` | Semantic search, no agent overhead |
| Codebase search needed (complex, multi-tool) | `explore` | Parallel multi-tool search |
| Stalled >3 iterations (per iteration-patterns.md §2 definitions) | `--model codex` | Deep autonomous worker (replaces UNAVAILABLE `hephaestus`) |
| Unfamiliar library in stack | `librarian` | External docs specialist |

## Red Flags — STOP and Reinvestigate

If thinking: "quick fix for now", "just try X", "probably X", "one more attempt" (after 2+), or each fix reveals problems elsewhere — return to investigation.

## Debug Report (MANDATORY)

After every fix, output a report per `references/debug-report-template.md`. Use a status label as the report header: **DONE**, **DONE_WITH_CONCERNS**, **BLOCKED**, or **NEEDS_CONTEXT** (see completion status table below).

Append the root cause summary to `debug-log.jsonl` in the skill's state directory (`config.json` → `state_dir`) for cross-session pattern tracking:
```jsonl
{"date":"YYYY-MM-DD","bug_class":"<category>","root_cause":"<one-line>","files":["<paths>"],"prevention":"<measures>"}
```

## Post-Fix Verification (MANDATORY)

In TS/JS projects: `npx tsc --noEmit` + `npx eslint <changed-files>` + full test suite. Fix all errors before claiming done.

## After This Skill

Report completion status:

| Status | When | Format |
|--------|------|--------|
| **DONE** | Root cause found, fix applied, tests pass, prevention in place | Standard debug report |
| **DONE_WITH_CONCERNS** | Fixed but cannot fully verify (intermittent, needs staging) | Debug report + list concerns |
| **BLOCKED** | Root cause unclear after investigation, or fix exceeds safe scope | `BLOCKED: [reason]. Attempted: [what]. Recommendation: [next step]` |
| **NEEDS_CONTEXT** | Missing information to proceed | `NEEDS_CONTEXT: [what's missing]. Attempted: [what]` |

Then offer next steps:
> **[R]** Review the changes (`/x-review`) **[D]** Done **[M]** More investigation needed

See `../x-shared/workflow-chains.md`. If the user continues to another skill (e.g., `/x-review`), include a [handoff context](../x-shared/context-envelope.md) block. Skip if the user commits/deploys directly.

## Gotchas

See `gotchas.md` for known failure patterns — update it when you encounter new ones.

Task: {{ARGUMENTS}}
