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
   Also pin `X_QA_EXPLORE_MODE` (`team` when team orchestration / `plugin.omc` is pinned, else `bg-fanout`) and `X_QA_EXPLORER` (the exploratory worker subagent) per the Exploratory Team Routing table.
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

`run` flags: `--worktree <path>`, `--service <name>`, `--channel <name>`, `--plan <path>`, `--no-launch`, `--max-bg <N>` (default 8), `--no-bg` (force synchronous dispatch), `--staleness-days <N>` (default 7), `--retry-flaky <N>` (default 2), `--allow-flaky-rate <pct>`, `--verdict-only`, `--skip-doctor`, `--no-profile`, `--pr <num>`, `--branch <name>`, `--no-kb` (skip corpus + baseline + auto-promote), `--kb-promote-after <N>`, `--kb-disable-auto-promote`, `--allow-coverage-gaps` (downgrade the coverage gate to a warning), `--no-explore` (skip the exploratory bug-hunt) / `--explore` (force it even in CI)

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
| `/x-skills:x-qa kb eval-calibrate --rubric-id <id> [--threshold 0.8]` | Run the judge over `kb/evals/gold/<id>.jsonl`, compute Cohen's κ, write `kb/evals/calibration/<id>.json`. Required before a judge can hard-fail a run. (Routes to `calibrate-judge.sh --gold <repo>/.x-skills/x-qa/kb/evals/gold/<id>.jsonl --rubric-id <id> --out-dir <repo>/.x-skills/x-qa/kb/evals/calibration/ [--threshold 0.8]`.) |

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

### Exploratory Team Routing (Arc C)

| Pinned | `X_QA_EXPLORE_MODE` | `X_QA_EXPLORER` |
|---|---|---|
| team orchestration (`plugin.omc`) | `team` (shared bug-board) | `oh-my-claudecode:qa-tester` (sonnet) |
| otherwise | `bg-fanout` (background `Agent`) | `Explore` (sonnet) |

Bootstrap pins `X_QA_EXPLORE_MODE` and `X_QA_EXPLORER` for Phase 13.5. See
`references/explore-team.md` (mode gate, bounded swarm) and
`references/explorer-prompts.md` (worker prompt).

## Run Envelope (machine-readable, stable)

Success:
```
✓ x-qa run complete
QA_VERDICT=pass|warn|fail
QA_VERDICT_REASON=<one-line>   # first blocking failure, or first warning, or "all gates passed"
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
COVERAGE_REQUIRED=<n>   # required obligations from scope.json
COVERAGE_COVERED=<n>    # required obligations satisfied by a case
COVERAGE_UNCOVERED=<csv> # uncovered required obligation ids ("" when none)
EXPLORE_RAN=true|false        # false when skipped (CI / --no-explore / no service)
EXPLORE_FINDINGS=<n>          # unique suspected findings on the bug-board
EXPLORE_CONFIRMED=<n>         # findings that survived triage
EXPLORE_CASES_MINTED=<n>      # confirmed findings minted into kb cases
EXPLORE_OBLIGATIONS_ADDED=<n> # novel obligations minted from "none" findings
CHANNELS_TESTED=<csv>         # channels selected for execution (names)
CHANNELS_SKIPPED=<name:reason,...>  # skipped channels + reason (stateful-not-owned / stateful-unverifiable / stateful-owned-chat-driver-deferred)
```

> `QA_VERDICT` is ternary as of v2. `warn` = non-blocking gates failed, no blocking ones did. Consumers branching on `pass|fail` should treat `warn` as `pass` for back-compat OR opt into ternary semantics via `QA_VERDICT_REASON`.

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
   - [ ] **Memory recall** (only when `mcp.agentmemory` pinned in bootstrap-active set): one `mcp__plugin_agentmemory_agentmemory__memory_smart_search({ query: "<test path or framework + 'flake'>", limit: 10 })` call. Surface prior flake notes as test-history context for case classification — not autopilot. **Apply consumer rules from `../x-shared/mcp-toolbox.md § Consumer rules` — drop hits where `tags` includes `auto-import` OR `confidence < 0.5` before treating them as precedent.** When `mcp.agentmemory` is not pinned, **skip silently** — Claude's native auto-memory file still applies.
2. Auto-doctor (skippable via `--skip-doctor`).
3. **Classify intent.** Run `scripts/classify-intent.sh "{{ARGUMENTS}}"`, persist to `<run-dir>/intent.json`. If `confidence == "low"` OR multiple candidates surface, ask the user ONE question per `references/intent-detection.md § Ask-When-Ambiguous`, then rewrite intent.json with `confidence: high`.
4. Resolve target from intent: `service` → entry name; `branch`/`pr` → PR-surface derivation (`references/pr-surface-derivation.md`); `spec`/`artifact`/`artifact-dir`/`prose` → trigger Phase 5 (Scout). Refuse if resolved entry's `type != http` (v1 limitation).
   - **Channel resolution.** If `intent.json.resolved.channel` (or `--channel`)
     is set, resolve it against `profile.json.channels[]` and pin
     `X_QA_CHANNEL` + `X_QA_DRIVER`. Read the driver's feature-gate per
     `references/channel-drivers.md`:
     - `http` → execute (Phases 8–15 as today, against the channel's `base_url`).
     - `browser` / `computer-use` → if the gating capability is absent, emit
       `CHANNEL_SKIPPED=<name> reason=driver '<driver>' not executable` and stop
       with a clear notice (capture-only in this release). Do NOT fall back to a
       different channel silently.
     - **Stateless-first default (no `--channel`).** Run `scripts/lib/channel-select.sh
       --profile <profile> --worktree <worktree> [--channel <name>]` → persist
       `<run-dir>/channels.json`. With no `--channel`, it defaults to **stateless**
       channels (`singleton_id == null`) on the primary entry point. No `channels[]`
       at all → the implicit primary `http` channel (back-compat).
     - **Stateful resolution** (ownership from `feature-overrides.local.json` only, R2):
       - owned here AND `driver == http` → **EXECUTE** via the existing http runner path.
       - owned here AND driver ∈ {browser, computer-use} → skip
         `CHANNEL_SKIPPED reason=stateful-owned-chat-driver-deferred`.
       - not owned (the default) → skip `CHANNEL_SKIPPED reason=stateful-not-owned`.
       - isolate not set up → skip `CHANNEL_SKIPPED reason=stateful-unverifiable`
         (never test a stateful channel blind).
       `channels.json.tested` drives Phases 8-15; `channels.json.skipped` feeds the
       envelope's `CHANNELS_SKIPPED`.
5. **Scout (conditional).** Only when intent ∈ {`spec`, `artifact`, `artifact-dir`, `prose`}: dispatch `$X_QA_SIMPLE_RUNNER` inline per `references/scout-prompt.md`. Persist `<run-dir>/scope.json`. On invalid JSON / timeout, use whole-profile coverage and warn. The scout also performs **Domain Research** (`references/scout-prompt.md § Domain Research`) — code-first modeling of entities/constraints/invariants/transitions — and emits `domain_model` + `obligations[]` into `scope.json`. When intent is not scout-eligible (`branch`/`pr`/`service`), `obligations[]` is absent and Phase 7.5 is a no-op.
6. **KB consult (skipped on `--no-kb`).** Read `kb/index.json`. For every endpoint in scope (from scout or PR-surface), collect matching `kb/cases/*.yaml` (not `quarantined`) and `kb/flows/*.yaml`. Pass this corpus to the planner.
6.5. **Gap analyze** (skipped on `--no-kb`). Run `scripts/gap-analyze.sh --scope-file <run-dir>/scope.json` when scout produced a scope (otherwise run without `--scope-file` and analyze the full index). Persist to `<run-dir>/coverage_gaps.json`. Inject as a `## Coverage Gaps` block in the planner prompt per `references/gap-analyzer.md`. Default `--staleness-days 7`; override via `profile.json.gap_analyzer.staleness_days`.
7. Plan: read `--plan <path>` if given, else generate per `references/test-plan-schema.md § Corpus Reuse` using profile catalog + `scope.json` + KB corpus as ground truth. The planner SHALL prefer corpus IDs over fresh generation when the endpoint+category already has a green case. Cases requiring auth inherit `profile.json.auth_case_id` as a default `precondition_case_id` per `references/kb-schema.md § precondition_case_id` and `references/case-runner-prompts.md § Precondition Chaining`.
7.5. **Coverage gate** (skipped when `scope.json` has no `obligations[]`, or on `--allow-coverage-gaps`). Run `scripts/coverage-check.sh --scope <run-dir>/scope.json --plan <plan>`. If `verdict == fail`, refuse the plan with `PHASE=plan` and `REASON=uncovered required obligations: <ids>` — the planner must add cases for the named obligations and re-emit. `--allow-coverage-gaps` downgrades the refusal to a warning (uncovered ids surfaced in `QA_REPORT.md` notes). Fold `COVERAGE_REQUIRED` / `COVERAGE_COVERED` / `COVERAGE_UNCOVERED` into the run envelope.
8. Launch service via `scripts/launch-entry-point.sh` (skipped on `--no-launch` or `--service <ext-url>`).
9. Health wait via `scripts/health-wait.sh`.
10. Classify cases per `references/classification-rules.md` (simple vs complex).
11. **Compute dispatch waves.** Pipe plan JSON through `scripts/lib/topo-order.sh`. Refuse plan on cycle (exit 2) or unknown dependency id (exit 1). Each wave dispatches in parallel (capped at `--max-bg`); the next wave starts when every case in the current wave reaches terminal state. Cases whose deps failed are marked `skipped`, not `fail`. Templates in `references/case-runner-prompts.md`. Each case's full precondition chain is pre-resolved by `scripts/run/resolve-preconditions.sh` (depth cap 4) into `X_QA_PRECONDITION_STEPS` before dispatch.

    **Background-execution gate (CI vs local).** Dispatch is `run_in_background: true` only when the environment looks interactive (`[[ -z "$CI" && -z "$GITHUB_ACTIONS" && -z "$BUILDKITE" && -z "$GITLAB_CI" ]]`). In CI, dispatch synchronously so the runner's stdout/stderr land in the build log and the run does not complete before agents finish. The `--no-bg` flag forces synchronous dispatch unconditionally.
12. Collect every dispatch terminal state (mandatory per `~/.claude/rules/background-agents.md`). Never `background_cancel(all=true)` before collection.
13. Retry flaky inline up to `--retry-flaky`.
13.5. **Exploratory bug-hunt (team)** — *default on a local run; **skipped in CI**; `--no-explore` opts out, `--explore` forces it.* Gate on the Phase-11 CI predicate. Requires the service to be up (skip if Phase 8 was skipped). When `scope.json.obligations[]` is present, partition it into ≤6 clusters (`scripts/explore/cluster-partition.sh --max-workers 6`); otherwise cluster by reachable endpoints (skip if neither). Dispatch one **Exploratory Worker** per cluster (`references/explorer-prompts.md`) via `X_QA_EXPLORE_MODE` (native team + shared bug-board, or background fanout — `references/explore-team.md`), each bounded to a ≤15-probe budget, writing to `<run-dir>/explore/board.jsonl`. Then dedup by signature (`scripts/explore/finding-merge.sh`), **triage** each unique finding independently (`references/triage-verify.md`), and mint a **red repro stub** per `confirmed` finding (`scripts/explore/finding-to-case.sh`) for the `x-bugfix` route + the report. **Do NOT KB-promote these** — the KB is the green corpus and Phase 16 auto-promotes only green cases; a repro stub becomes a regression case only after the fix lands and it goes green (via the existing auto-promote path). Count `EXPLORE_CONFIRMED` from the **triaged** set (this step), NOT from `finding-merge.sh` output (which runs pre-triage, when every finding is still `suspected`). Fold `EXPLORE_*` counters into the envelope.
14. Teardown via launch entry's `launch.teardown` (skipped if Phase 8 was skipped).
15. Aggregate via `scripts/aggregate-results.sh` → `QA_REPORT.md`. Propagate `scope.json.open_questions` into the report's notes section. **KB write-back** (skipped on `--no-kb`): update `kb/baselines/<endpoint>.json` for every case, append a run summary line to `kb/.ledger.jsonl`, compute drift signals.
16. **KB auto-promote** (skipped on `--no-kb` or `--kb-disable-auto-promote`). Invoke `scripts/kb-promote.sh --auto`. Emits `KB_PROMOTED=` / `KB_DEMOTED=` for the envelope.
17. Emit envelope.

## Real-QA Contract (MANDATORY)

`run` tests the system the way a QA engineer drives it —
it **never executes the repository's own test suites**. The runner MUST NOT
invoke `npm test`,
`npm run test:e2e`, `pytest`, `playwright test`, `cypress run`, `go test`,
`vitest`, or any project test command. Instead it drives the actual channel:
issue real requests (curl for `http`), adjust fixture/mock data, and mint cases
from `QA_MEMORY.md` + the KB corpus. `launch.command` starts the *service only*
(`references/service-launch.md`); it is never a test command. This holds across
every driver.

**Eval class (v1).** LLM/agentic features are tested with eval scorers (`llm-rubric`,
`semantic-similarity`) — x-qa scores outputs *itself* via the native judge-runner
(`scripts/evals/score-case.sh`); it MUST NOT shell out to external eval frameworks
(`deepeval`, `promptfoo`) any more than it runs the repo's test suites. The judge model
SHOULD differ from the model behind the system-under-test (operator responsibility — not
machine-enforced in v1; x-qa cannot infer the SUT's model). A judge may set `QA_VERDICT=fail`
only when validated against a human gold set (κ ≥ 0.90); otherwise it is advisory (`warn`). See
`references/eval-scorers.md`.

## After This Skill

If invoked by `x-team`: emit envelope only, x-team consumes via Skill return value.
If invoked by user: print envelope + path to `QA_REPORT.md` + summary table.
On `fail`: surface offer to route into `/x-skills:x-bugfix` with the failed cases as input.
Confirmed exploratory findings (`EXPLORE_CONFIRMED > 0`) are also offered to `/x-skills:x-bugfix`, each carrying its minted case as the reproduction.

- [ ] **Persist test pattern** (only when `mcp.agentmemory` pinned): one `mcp__plugin_agentmemory_agentmemory__memory_save({ content: "<test pattern or flake observation>", type: "lesson", concepts: "x-qa,<framework>,<pattern-kind>,slot:test-plan" })` call. The `slot:` token in `concepts` substitutes for the upstream slot-store API (not present in agentmemory v0.9.21 — convention, not contract; `memory_save` silently drops unknown top-level fields, so a `category` arg would be invisible — verified at `research/rohitg00/agentmemory/src/mcp/standalone.ts:104-114`). Skip silently when not pinned.

## Dependencies

- `../x-shared/capability-loading.md`, `invocation-guide.md`, `context-envelope.md`
- `../x-omo/SKILL.md` (if gemini_cli/plugin.omc pinned)
- `../x-gemini/SKILL.md` (if gemini_cli pinned)

## Gotchas

See `gotchas.md`.

Task: {{ARGUMENTS}}
