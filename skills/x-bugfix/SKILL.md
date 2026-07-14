---
name: x-bugfix
description: Use when the user reports a bug, error, test failure, or unexpected behavior — routes through investigation, hypothesis testing, and verified fix with structured evidence collection
---

# x-bugfix — Universal Bugfix Command

Smart entry point for bugs and investigations. Detects severity, routes through the optimal debugging workflow, and produces verified fixes with evidence.

## Bootstrap

**MANDATORY first step — do this BEFORE anything else:**

0. Pin capabilities for the session per `../x-shared/capability-loading.md`. Filter routing tables against the pinned set; do NOT re-check per dispatch.
1. Read `../x-omo/SKILL.md` to load the OMO agent catalog, invocation commands, and model routing. This ensures you know how to invoke OMO agents (`oracle`, `explore`, `librarian`, `multimodal-looker`) via Bash — they are NOT OMC agents. For the canonical list of UNAVAILABLE role agents and their replacements, see [`../x-shared/omo-routing.md § Unavailable Agents`](../x-shared/omo-routing.md#unavailable-agents).
2. Read `../x-gemini/SKILL.md` if `agy_cli` capability is pinned. Agy's 1M context, Google Search grounding (opt-in via `--grounded`), and multimodal `--add-dir` flag handle three bug scenarios that OMO/MCP cannot: large-log analysis, screenshot/mockup-driven bugs, and fresh CVE/regression web facts.

## Invocation

For how to invoke skills, OMO agents, and OMC agents, see `../x-shared/invocation-guide.md`.

## Dependencies

This skill references shared infrastructure and sibling skills:
- `../x-omo/SKILL.md` — OMO agent catalog (loaded in Bootstrap)
- `../x-gemini/SKILL.md` — direct Gemini CLI bridge (large logs, multimodal, fresh-web grounding)
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

- [ ] **`--wt` flag detection:** Scan the user prompt for `--wt` (with optional `<target_branch>` and optional `<new_branch>`). Also scan for `--wt-no-isolate` (caller-side flag — translates to passing `--no-isolate` through to x-worktree, suppressing auto-isolation). If present:
  1. Strip the `--wt …` segment AND any `--wt-no-isolate` token from the prompt before mode detection.
  2. Dispatch via `Skill: x-skills:x-worktree` with parsed args (empty string for omitted slots). Append `--no-isolate` to the inner args when `--wt-no-isolate` was set.
  3. Parse the result envelope; pin `WORKTREE_PATH` for the whole bugfix flow.
  4. Every mutating dispatch (Bash / Agent / OMC `debugger` / `tracer` / OMO) must run inside `WORKTREE_PATH` per `../x-worktree/SKILL.md` § "CWD propagation". The regression test, the fix, and the verification commands ALL run in the worktree — not the original cwd.
  5. **Parse `ISOLATE_APPLIED` and act on it** (see `../x-worktree/references/auto-isolation.md` for the full contract):
     - `ISOLATE_APPLIED=true` → Read `$WORKTREE_PATH/.worktree-isolate/state.local.json`, validate `schema == 1` (refuse on mismatch), build the DOCKER CONTEXT block per `../x-worktree/references/caller-integration.md` § "DOCKER CONTEXT propagation". Prepend that block to **every** subsequent executor / Agent / OMC `debugger` / `tracer` / OMO dispatch for the rest of the bugfix flow. Reconstruct `Launch:` line at each dispatch from `[ -f $WORKTREE_PATH/.env ]` — never cache the rendered block.
     - `ISOLATE_APPLIED=false` → Surface `ISOLATE_REASON` + `ISOLATE_HINT` to the user via AskUserQuestion (2 options, default abort): `(1) abort and let me retry isolate manually` / `(2) proceed without isolation, I accept docker collisions with my other worktrees`. Default = abort.
     - `ISOLATE_APPLIED=skipped` → Proceed normally. No DOCKER CONTEXT block.
     - `ISOLATE_APPLIED` line absent (because `--no-isolate` / `--wt-no-isolate` was set) → Proceed normally. No DOCKER CONTEXT block.
  6. If x-worktree returns `✗ Worktree FAILED`, abort and report — never silently continue in the original repo.
- [ ] **Capture baseline:** Record exact error messages, failing test output, and stack traces (copy-paste, not paraphrase). This becomes the before/after comparison for verification.
  - **Behavioral bug?** (duplication, wrong output, timing issue — no error/stack trace exists): Capture expected vs. actual behavior as the baseline instead. Document what the user observes and what correct behavior looks like.
- [ ] Read error messages carefully — don't skip stack traces
- [ ] Read `gotchas.md` for known failure patterns
- [ ] **Memory recall** (only when `mcp.basic_memory` pinned in bootstrap-active set): one `mcp__basic-memory__search_notes({ query: "<symptom keywords + framework>", page_size: 5 })` call. If results include prior bug-fix lessons touching the same symptom or files, surface them in the Investigate step as candidate root-cause hypotheses (do not auto-apply — these are leads, not verdicts). **Apply consumer rules from `../x-shared/mcp-toolbox.md § Consumer rules`.** When `mcp.basic_memory` is not pinned, **skip silently** — Claude's native auto-memory file still applies.
- [ ] `git log --oneline -10 -- <affected-files>` — regression = root cause is in the diff

## Available Tools

For MCP tool selection (search, edit, web facts, library docs), see the canonical decision matrix at **`../x-shared/mcp-toolbox.md`**. The table below covers only bugfix-specific tools (debugging skills, OMC investigation agents, OMO escalation paths) — do not duplicate MCP rows here.

| Tool | When It Helps | How |
|------|--------------|-----|
| `superpowers:systematic-debugging` | Bug with unclear root cause | Skill — 4-phase discipline |
| `superpowers:test-driven-development` | Writing the regression test | Skill |
| `superpowers:verification-before-completion` | **Always** — before claiming fixed | Skill |
| OMC `debugger` | Complex multi-component investigation | Agent |
| OMC `tracer` | Competing hypotheses (Mode B) | Agent |
| OMO `oracle` | Fresh perspective after instrumentation pivot + 3 failed attempts | Bash (omo-agent) |
| OMO `explore` | Codebase search when `mcp-toolbox.md` primary (native `Grep`) insufficient — needs parallel multi-tool search | Bash (omo-agent) |
| `agy-agent --add-dir <log-dir>` | Large log/trace (>50k tokens) — single-shot analysis without paging | Bash (1M context, gemini-3-pro) |
| `agy-agent --add-dir <screenshot-dir>` | Visual bug input (screenshot, mockup, design ref) | Bash (multimodal pro) |
| `agy-agent --model pro --grounded` | Fresh web facts (CVE advisory, recent regression, library current state) | Bash (Google Search grounding via `--grounded`) |

## Mode A: Quick Bug

### Investigate

Gather evidence before forming hypotheses. Reproduce the bug, check recent changes, trace the data flow backward from symptom to source. **Use native `Grep` (or OMO `explore` for semantic) as your first search tool** for tracing call chains, finding related code, and locating error origins. Fall back to OMO `explore` only when you need parallel multi-tool investigation. For deep call stacks, use the backward tracing technique in `references/backward-tracing.md`. Consult `references/pattern-catalog.md` to narrow the search space. When `mcp.basic_memory` is pinned (per `../x-shared/capability-loading.md`), one `mcp__basic-memory__search_notes({ query: "<affected file basenames + symptom>", page_size: 5 })` call can surface prior lessons touching the same files; treat each hit as a regression-candidate lead ranked by relevance. basic-memory has no file-touch/commit-linkage history — for actual file history use `git log -p -- <file>`.

If no pattern matches, search for the error: sanitize first (strip hostnames, IPs, file paths, SQL, customer data), then search "{framework} {sanitized error type}". If the error is too specific to sanitize safely, skip the search.

Output: a **root cause hypothesis** — specific and testable.

### Hypothesize & Test

Scientific method — one variable at a time. Form a single hypothesis, test minimally, verify. If wrong, form a NEW hypothesis — don't stack fixes.

**Hypothesis must be evidence-backed (rule 3 of `../x-shared/instrument-and-verify.md`).** The hypothesis MUST cite a real artifact: a stack frame, a log line, a test output, a `file:line`, or a doc URL. If you can only say "probably X" or "I think Y is the issue", that is a STOP signal — go produce evidence first (rule 2: run a scratch script, add a log, read the lib source) and return with a citation. Speculation without evidence is the #1 reason debugging stalls.

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
2. Implement a **single fix** addressing root cause — minimal diff. **Ship logs in the same diff (rule 1 of `../x-shared/instrument-and-verify.md`).** Add structured logs at decision points on the affected call chain (entry/exit, branches, state transitions, error catches). Log decision variables (IDs, flags, lengths), not just "got here" markers. These logs STAY after the fix lands — downgrade to debug level if noisy, but do NOT strip them. Rationale: the same call chain will break again, and the next debugger should not have to re-instrument from scratch.
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
| Codebase search needed (simple) | native `Grep` / OMO `explore` | Fast literal/semantic search, no agent overhead |
| Codebase search needed (complex, multi-tool) | `explore` | Parallel multi-tool search |
| Stalled >3 iterations (per iteration-patterns.md §2 definitions) | `--model codex` | Deep autonomous worker |
| Unfamiliar library in stack | `librarian` OR `agy-agent --model pro --grounded` | External docs specialist; agy for fresh web grounding |
| Log/trace >50k tokens | `agy-agent --add-dir <log-dir>` | 1M context single-shot beats paging |
| Visual bug (screenshot/mockup) | `agy-agent --add-dir <image-dir>` | Multimodal pro |
| Fresh CVE / library regression | `agy-agent --model pro --grounded` | Google Search (`--grounded`) beats stale training cutoff |

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
- [ ] **Persist lesson** (only when `mcp.basic_memory` pinned): one `mcp__basic-memory__write_note({ title: "<symptom-token>", directory: "lessons/<project-slug>", content: "<one-sentence root cause> → <one-sentence fix>\n\nFiles: <touched paths>", tags: ["<project-slug>", "x-bugfix", "<area>"] })` call (project-slug = basename of cwd — see `../x-shared/mcp-toolbox.md § Consumer rules`). Skip silently when not pinned.

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
