---
name: x-qa
description: Use when the user wants end-to-end QA testing for a feature, branch, or PR — scans the project for entry points, generates a TEST_PLAN.md with edge cases, launches the service in an isolated container, and dispatches parallel test runners (cheap gemini for simple HTTP cases, claude for complex flows). Profile-driven: `init` once, then `run` repeatedly.
---

# x-qa — Profile-Driven E2E QA Orchestrator

## Input Contract

`run` accepts a free-form `{{ARGUMENTS}}` — empty string, `PR #<n>`, an
entry-point name, a file path, a directory, or prose describing a feature.
The bootstrap classifier (Run Phase 3) resolves it. Explicit flags
(`--pr`/`--branch`/`--service`/`--plan`) override classification. Do NOT
add new user-facing flags for input source — the classifier handles it.

## Bootstrap (MANDATORY)

Before any subcommand:

1. Pin capabilities per `../x-shared/capability-loading.md`.
2. Read `../x-omo/SKILL.md` if `gemini_cli` or `plugin.omc` capability is pinned (needed for fanout).
3. Read `gotchas.md` for known failure modes.
4. Resolve repo root: `git rev-parse --show-toplevel`. Refuse outside a git repo.
5. **Pin runner pair (D10)** — derive `X_QA_SIMPLE_RUNNER` and `X_QA_COMPLEX_RUNNER` from the Capability Routing table below and export them for downstream phases. The runner template in `references/case-runner-prompts.md` reads these env vars rather than hardcoding a tool name.
6. **For `run` only (D9)** — invoke `scripts/doctor.sh` first. Refuse if the doctor fails. Skippable via `--skip-doctor`.

## Subcommand Surface

| Form | Purpose |
|---|---|
| `/x-skills:x-qa init [--non-interactive] [--skip-verify] [--profile-from <path>]` | One-time scan + interview, writes `.x-skills/x-qa/profile.json`. |
| `/x-skills:x-qa update [--non-interactive]` | Re-scan, diff vs profile, ask only about deltas. |
| `/x-skills:x-qa inspect` | Print profile + scan findings. No writes. |
| `/x-skills:x-qa doctor` | Validate profile + KB against repo state. |
| `/x-skills:x-qa generate <feature-spec> [--persist <path>] [--force]` | Plan only. Uses profile catalog + KB corpus. |
| `/x-skills:x-qa run [opts]` | Default action. Generate-or-read plan, launch service, dispatch fanout, aggregate, auto-promote KB. |
| `/x-skills:x-qa kb <subcmd>` | Knowledge-base ops. See "KB Subcommands". |

`run` flags: `--worktree <path>`, `--service <name>`, `--plan <path>`, `--no-launch`, `--max-bg <N>` (default 8), `--no-bg` (force synchronous dispatch), `--staleness-days <N>` (default 7), `--retry-flaky <N>` (default 2), `--allow-flaky-rate <pct>`, `--verdict-only`, `--skip-doctor`, `--no-profile`, `--pr <num>`, `--branch <name>`, `--no-kb` (skip corpus + baseline + auto-promote), `--kb-promote-after <N>`, `--kb-disable-auto-promote`.

## KB Subcommands

The KB (`.x-skills/x-qa/kb/`) is the team-shared, git-tracked layer that
makes future runs faster and lets teams reuse proven test scripts.
Full schema: `references/kb-schema.md`. Curation rules:
`references/kb-curation.md`.

| Form | Purpose |
|---|---|
| `/x-skills:x-qa kb list [--cases\|--flows\|--baselines]` | Tabulate KB contents. |
| `/x-skills:x-qa kb inspect <id>` | Pretty-print a case/flow + ledger history. |
| `/x-skills:x-qa kb promote [--force <id>] [--dry-run]` | Run auto-promotion pass manually, or force a single ID. |
| `/x-skills:x-qa kb prune --orphans [--apply]` | Reconcile filesystem vs index (orphan files / dangling entries). |

Cross-team sharing is the git-tracked KB itself (or a submodule when shared
across repos). Tarball export/import was cut as redundant with git.

## Capability Routing

| Pinned | Simple Runner | Complex Runner |
|---|---|---|
| `gemini_cli + plugin.omc` | x-gemini bg | Agent oh-my-claudecode:qa-tester (sonnet) bg |
| `gemini_cli` only | x-gemini bg | Agent Explore (sonnet) bg |
| `plugin.omc` only | Agent oh-my-claudecode:executor (haiku) bg | Agent oh-my-claudecode:qa-tester (sonnet) bg |
| neither | Agent Explore (haiku) bg | Agent Explore (sonnet) bg |

The bootstrap step pins the runner pair into env vars `X_QA_SIMPLE_RUNNER` and `X_QA_COMPLEX_RUNNER` (read by `case-runner-prompts.md`). Never hardcode an `Agent` subagent_type in the runner template — always reference the pinned env var.

## Run Envelope (machine-readable, stable)

Success:
```
✓ x-qa run complete
QA_VERDICT=pass|fail
QA_TOTAL=<n>
QA_PASSED=<n>
QA_FAILED=<n>
QA_FLAKY=<n>
QA_FLAKY_RATE=<float>
QA_REPORT=<abs path>
QA_PLAN=<abs path>
QA_RUN_ID=<id>
DURATION_S=<float>
ENTRY_POINT=<name>
SERVICE_LAUNCHED=true|false
KB_REUSED=<n>          # cases pulled from corpus (not regenerated)
KB_GENERATED=<n>       # cases minted this run
KB_PROMOTED=<n>        # cases auto-promoted to corpus this run
KB_PROMOTE_STATUS=ok|disabled|error
```

Failure:
```
✗ x-qa run FAILED
REASON=<one-line>
PHASE=<bootstrap|doctor|plan|launch|dispatch|collect|aggregate>
QA_RUN_ID=<id-if-allocated>
```

## Subcommand Routing

Refer to:
- `init`: `references/init-interview.md` + `scripts/init.sh`
- `update`: `references/update-diff-rules.md` + `scripts/update.sh`
- `inspect`: `scripts/inspect.sh` (read-only mode)
- `doctor`: `references/doctor-checks.md` + `scripts/doctor.sh` (validates both profile and `kb/index.json`)
- `generate`: `references/test-plan-schema.md` (LLM-generated inline; `scripts/plan-generate.sh` is a v2 placeholder, not shipped in v1). Planner MUST consult `kb/cases/` + `kb/flows/` first per the corpus contract in `references/test-plan-schema.md § Corpus Reuse`.
- `run`: see "Run Phases" below; intent via `references/intent-detection.md`; scout via `references/scout-prompt.md`; KB layer via `references/kb-schema.md` + `references/kb-curation.md`
- `kb <subcmd>`: dispatched to `scripts/kb-<subcmd>.sh`. No LLM in the loop — these are pure-shell maintenance commands.

## Run Phases

1. Bootstrap (above).
2. Auto-doctor (skippable via `--skip-doctor`).
3. **Classify intent.** Run `scripts/classify-intent.sh "{{ARGUMENTS}}"`, persist to `<run-dir>/intent.json`. If `confidence == "low"` OR multiple candidates surface, ask the user ONE question per `references/intent-detection.md § Ask-When-Ambiguous`, then rewrite intent.json with `confidence: high`.
4. Resolve target from intent: `service` → entry name; `branch`/`pr` → PR-surface derivation (`references/pr-surface-derivation.md`); `spec`/`artifact`/`artifact-dir`/`prose` → trigger Phase 5 (Scout). Refuse if resolved entry's `type != http` (v1 limitation).
5. **Scout (conditional).** Only when intent ∈ {`spec`, `artifact`, `artifact-dir`, `prose`}: dispatch `$X_QA_SIMPLE_RUNNER` inline per `references/scout-prompt.md`. Persist `<run-dir>/scope.json`. On invalid JSON / timeout, use whole-profile coverage and warn.
6. **KB consult (skipped on `--no-kb`).** Read `kb/index.json`. For every endpoint in scope (from scout or PR-surface), collect matching `kb/cases/*.yaml` (not `quarantined`) and `kb/flows/*.yaml`. Pass this corpus to the planner.
6.5. **Gap analyze** (skipped on `--no-kb`). Run `scripts/gap-analyze.sh --scope-file <run-dir>/scope.json` when scout produced a scope (otherwise run without `--scope-file` and analyze the full index). Persist to `<run-dir>/coverage_gaps.json`. Inject as a `## Coverage Gaps` block in the planner prompt per `references/gap-analyzer.md`. Default `--staleness-days 7`; override via `profile.json.gap_analyzer.staleness_days`.
7. Plan: read `--plan <path>` if given, else generate per `references/test-plan-schema.md § Corpus Reuse` using profile catalog + `scope.json` + KB corpus as ground truth. The planner SHALL prefer corpus IDs over fresh generation when the endpoint+category already has a green case.
8. Launch service via `scripts/launch-entry-point.sh` (skipped on `--no-launch` or `--service <ext-url>`).
9. Health wait via `scripts/health-wait.sh`.
10. Classify cases per `references/classification-rules.md` (simple vs complex).
11. **Compute dispatch waves.** Pipe plan JSON through `scripts/lib/topo-order.sh`. Refuse plan on cycle (exit 2) or unknown dependency id (exit 1). Each wave dispatches in parallel (capped at `--max-bg`); the next wave starts when every case in the current wave reaches terminal state. Cases whose deps failed are marked `skipped`, not `fail`. Templates in `references/case-runner-prompts.md`.

    **Background-execution gate (CI vs local).** Dispatch is `run_in_background: true` only when the environment looks interactive (`[[ -z "$CI" && -z "$GITHUB_ACTIONS" && -z "$BUILDKITE" && -z "$GITLAB_CI" ]]`). In CI, dispatch synchronously so the runner's stdout/stderr land in the build log and the run does not complete before agents finish. The `--no-bg` flag forces synchronous dispatch unconditionally.
12. Collect every dispatch terminal state (mandatory per `~/.claude/rules/background-agents.md`). Never `background_cancel(all=true)` before collection.
13. Retry flaky inline up to `--retry-flaky`.
14. Teardown via launch entry's `launch.teardown` (skipped if Phase 8 was skipped).
15. Aggregate via `scripts/aggregate-results.sh` → `QA_REPORT.md`. Propagate `scope.json.open_questions` into the report's notes section. **KB write-back** (skipped on `--no-kb`): update `kb/baselines/<endpoint>.json` for every case, append a run summary line to `kb/.ledger.jsonl`, compute drift signals.
16. **KB auto-promote** (skipped on `--no-kb` or `--kb-disable-auto-promote`). Invoke `scripts/kb-promote.sh --auto`. Emits `KB_PROMOTED=` / `KB_DEMOTED=` for the envelope.
17. Emit envelope.

## After This Skill

If invoked by `x-team`: emit envelope only, x-team consumes via Skill return value.
If invoked by user: print envelope + path to `QA_REPORT.md` + summary table.
On `fail`: surface offer to route into `/x-skills:x-bugfix` with the failed cases as input.

## Dependencies

- `../x-shared/capability-loading.md`, `invocation-guide.md`, `context-envelope.md`
- `../x-omo/SKILL.md` (if gemini_cli/plugin.omc pinned)
- `../x-gemini/SKILL.md` (if gemini_cli pinned)

## Gotchas

See `gotchas.md`.

Task: {{ARGUMENTS}}
