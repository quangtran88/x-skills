---
name: x-qa
description: Use when the user wants end-to-end QA testing for a feature, branch, or PR — scans the project for entry points, generates a TEST_PLAN.md with edge cases, launches the service in an isolated container, and dispatches parallel test runners (cheap gemini for simple HTTP cases, claude for complex flows). Profile-driven: `init` once, then `run` repeatedly.
role: qa-orchestrator
---

# x-qa — Profile-Driven E2E QA Orchestrator

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
| `/x-skills:x-qa doctor` | Validate profile against repo state. |
| `/x-skills:x-qa generate <feature-spec> [--persist <path>] [--force]` | Plan only. Uses profile catalog. |
| `/x-skills:x-qa run [opts]` | Default action. Generate-or-read plan, launch service, dispatch fanout, aggregate. |

`run` flags: `--worktree <path>`, `--service <name>`, `--plan <path>`, `--no-launch`, `--max-bg <N>` (default 8), `--retry-flaky <N>` (default 2), `--allow-flaky-rate <pct>`, `--verdict-only`, `--skip-doctor`, `--no-profile`, `--pr <num>`, `--branch <name>`.

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
- `doctor`: `references/doctor-checks.md` + `scripts/doctor.sh`
- `generate`: `references/test-plan-schema.md` (LLM-generated inline; `scripts/plan-generate.sh` is a v2 placeholder, not shipped in v1)
- `run`: see "Run Phases" below

## Run Phases

1. Bootstrap (above).
2. Auto-doctor (skippable via `--skip-doctor`).
3. Resolve target: `--service <name>` or `profile.primary_entry_point`. Refuse if entry point's `type != http` (v1 limitation).
4. Plan: read `--plan <path>` if given, else generate per `references/test-plan-schema.md` using profile catalog as ground truth.
5. Launch service via `scripts/launch-entry-point.sh` (skipped on `--no-launch` or `--service <ext-url>`).
6. Health wait via `scripts/health-wait.sh`.
7. Classify cases per `references/classification-rules.md` (simple vs complex).
8. Dispatch fanout — capped at `--max-bg`, all `run_in_background: true`. Templates in `references/case-runner-prompts.md`.
9. Collect every dispatch terminal state (mandatory per `~/.claude/rules/background-agents.md`). Never `background_cancel(all=true)` before collection.
10. Retry flaky inline up to `--retry-flaky`.
11. Teardown via launch entry's `launch.teardown` (skipped if Phase 5 was skipped).
12. Aggregate via `scripts/aggregate-results.sh` → `QA_REPORT.md`.
13. Emit envelope.

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
