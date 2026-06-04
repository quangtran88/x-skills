# Exploratory QA Team — Coordination

The exploratory tier is a **team of curious workers** that hunts bugs in the live
service after the deterministic cases have run. It is the execution-layer
counterpart to Arc B: Arc B enumerates obligations; this team tries to break them
and surfaces the ones the scout missed.

## When it runs (mode: default-local, **skipped in CI**)

- Runs **by default on a local/dev run**.
- Is **skipped in CI** — reuses the Phase-11 CI predicate
  (`[[ -z "$CI" && -z "$GITHUB_ACTIONS" && -z "$BUILDKITE" && -z "$GITLAB_CI" ]]`).
- `--no-explore` opts out locally; `--explore` forces it even in CI.
- Skipped with a notice when the service was not launched (`--no-launch`) or when
  there are no obligations AND no reachable endpoints to cluster.

## Coordination (capability-gated)

| Mode | When | Mechanism |
|---|---|---|
| **native Claude team** (preferred) | team orchestration pinned (`plugin.omc`) | A **shared bug-board** task list (TeamCreate + a task per cluster). Workers claim a cluster, post findings live, and can see peers' findings — no duplicate hunting. |
| **background fanout** (fallback) | team orchestration absent | One **background** `Agent` per cluster (existing bg-dispatch), each appending to `<run-dir>/explore/board.jsonl`. No live cross-worker awareness; dedup happens at merge. |

Bootstrap pins `X_QA_EXPLORE_MODE` (`team`|`bg-fanout`) and `X_QA_EXPLORER`
(subagent_type). This lifts gotcha #13 ("no nested team") as a documented
capability upgrade — the fallback keeps Claude-only mode working.

## Bounded swarm (cost guard)

- **One worker per obligation-cluster**, **≤6 concurrent**.
- Each worker has a **fixed probe budget** (≤15 requests; see
  `references/explorer-prompts.md`).
- Clusters come from `scripts/explore/cluster-partition.sh --max-workers 6`
  (deterministic; partitions `scope.json.obligations[]`, optionally × channel).
- When `obligations[]` is absent (`branch`/`pr`/`service` intent), cluster by
  reachable endpoints instead; if neither exists, skip.

## Flow

1. Partition obligations → clusters (`cluster-partition.sh`).
2. Dispatch ≤6 workers (team or bg-fanout) → findings on the bug-board.
3. Dedup the board by signature (`scripts/explore/finding-merge.sh`).
4. **Triage** each unique finding independently (`references/triage-verify.md`) —
   only `confirmed` findings survive.
5. Mint a **red repro stub** per confirmed finding
   (`scripts/explore/finding-to-case.sh`) → the `x-bugfix` route (+ report). A
   repro is red/failing, so it is **NOT** KB-promoted; it becomes a regression
   case only after the fix lands and it goes green (existing auto-promote path).
6. Fold counters into the run envelope (`EXPLORE_*`). `EXPLORE_CONFIRMED` is
   counted from the triaged set (step 4), not from the pre-triage merge.
