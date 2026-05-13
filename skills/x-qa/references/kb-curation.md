# KB Curation Rules

How entries enter, age out of, and get rejected from `.x-skills/x-qa/kb/`.
Curation runs at the END of every `run` (after aggregate, before envelope
emit) — driven by `scripts/kb-promote.sh`.

## Tunables (env vars, all optional)

| Env var | Default | Meaning |
|---|---|---|
| `X_QA_KB_PROMOTE_AFTER`        | `3`  | Consecutive green runs before a generated case auto-promotes. |
| `X_QA_KB_DEMOTE_AFTER`         | `3`  | Consecutive `fail` (non-flaky) runs before a promoted case demotes. |
| `X_QA_KB_BASELINE_WINDOW`      | `50` | Rolling window size for latency / flaky-rate / shape stats. |
| `X_QA_KB_FLOW_MIN_LENGTH`      | `2`  | Minimum chain length for a flow to be promotable. |
| `X_QA_KB_LEDGER_RETAIN`        | `200`| Max lines kept by `kb-prune.sh --ledger`. |
| `X_QA_KB_DISABLE_AUTO_PROMOTE` | unset| When set, no auto-promotion runs. Manual only. |

Override per-run with flags: `--kb-promote-after N`,
`--kb-disable-auto-promote`. Persistent overrides live in
`profile.json.metadata.x_qa_kb` (free-form per profile-schema.md).

## Case Promotion

A `generated` case in a run-local plan is a **candidate** when:

1. Its verdict is `pass` (not `flaky-recovered`).
2. Its body hash matches the prior run's hash for the same case ID
   (i.e. the case definition is stable across the streak).
3. `consecutive_pass >= X_QA_KB_PROMOTE_AFTER`.

`consecutive_pass` is derived from `kb/.ledger.jsonl`. The first run a
case appears in is `consecutive_pass = 1`. A `fail` or `flaky-recovered`
verdict resets the counter to 0.

Promotion writes:
- `kb/cases/tc-<slug>.yaml` with provenance fields filled in.
- `kb/index.json.cases.<id>` with `green_streak`, `promoted_at`,
  `promoted_from_run`.
- A line in `kb/.ledger.jsonl` marking the promotion event (separate
  from the run summary line).

## Case Demotion

A promoted case demotes when it accumulates `X_QA_KB_DEMOTE_AFTER`
consecutive `fail` verdicts (flaky-recovered does NOT count).

Demotion does NOT delete the YAML. It moves the entry into
`kb/index.json.cases.<id>.demoted_at` and `quarantined: true`. The
planner skips quarantined cases until the user explicitly runs
`kb-promote --force tc-<id>` to clear the flag.

Hand-edited corpus YAMLs are detected separately: `doctor.sh` compares
the file's sha256 against the index's `checksum` and emits a warning.
v1 does NOT auto-demote on checksum drift — review and either accept
the edit (`kb-promote --force <id>` to refresh the recorded checksum)
or revert it.

## Flow Promotion

Flows are observed, not generated directly. The aggregator emits a
`flow_observations[]` array in each ledger line containing every
`depends_on` chain that ran AND every case in the chain passed.

A chain promotes to `kb/flows/fl-<slug>.yaml` when:

1. The same exact case-ID sequence appears in `>=
   X_QA_KB_PROMOTE_AFTER` consecutive runs with `all_pass: true`.
2. Every case in the chain is itself a promoted KB case.
3. Chain length `>= X_QA_KB_FLOW_MIN_LENGTH`.

Capture/inject directives are not inferred. The first flow promotion
emits a flow YAML with empty `capture`/`inject` blocks; subsequent
manual edits add them. A future v2 pass can infer captures from
response-to-request data dependencies.

## Baseline Update Rules

Run after every test case (regardless of verdict):

1. **`status_codes`** — increment the count for the observed status.
2. **`latency_ms`** — push the observed latency into the rolling
   window. Recompute `p50` / `p95` / `p99` / `max` over the window.
   Update `ewma` as `ewma = 0.2 * observed + 0.8 * ewma_prev`.
3. **`response_shape`** — ONLY on `verdict == pass`. Merge the
   observed shape into the stored JSON Schema via additive union
   (new keys widen the schema; never narrow on a single sample).
4. **`flaky_rate`** — recompute `fails / samples` and
   `flaky_recovered / samples` over the window.

The window evicts oldest sample when `samples > window`.

## Drift Signals

Computed AFTER baseline update, written into the baseline's
`drift_signals` block, and propagated into `QA_REPORT.md` notes.

| Signal | Trigger |
|---|---|
| `new_status_code_seen` | First time a status code appears for this endpoint. |
| `shape_added_required_field` | A `pass` response contained a new `required` field absent from prior shape. |
| `latency_p95_regression_pct` | `(p95_current - p95_prev) / p95_prev` if positive, else 0. Surface when `>20%`. |
| `flaky_rate_spike` | `flaky_rate` doubled vs prior window snapshot. |

Drift signals are informational. They do NOT flip the run verdict.
Teams who want to gate on drift can set
`X_QA_KB_FAIL_ON_DRIFT=p95,shape` (comma-separated) to escalate to
`fail`.

## Endpoint Rename Handling

When a case references an endpoint not in `profile.json`'s scanned
catalog, doctor flags the case as `endpoint-stale`. The planner skips
endpoint-stale cases. `kb-prune.sh --orphans` lists them for human
review — never auto-deletes (the endpoint may have just been moved).

## Manual Override Commands

All shell-script entry points; see `scripts/`:

| Command | Effect |
|---|---|
| `kb-promote --force <case-id>` | Promote regardless of streak. Clears `quarantined` if set. |
| `kb-demote <case-id>` | Mark quarantined manually. |
| `kb-promote --dry-run` | Print what would auto-promote, no writes. |
| `kb-inspect <case-id>` | Pretty-print case + ledger history. |
| `kb-prune --orphans` | List files with no index entry, or index entries with no file. |
| `kb-prune --baselines --older-than 90d` | Drop baselines untouched for 90+ days. |
| `kb-prune --ledger` | Trim ledger to `X_QA_KB_LEDGER_RETAIN` lines. |
| `kb-export <path>` | Tar+gz the KB for transfer to another repo / share with another team. |
| `kb-import <tarball>` | Merge a KB tarball into the current KB. Refuses on ID collisions; `--rename-collisions` suffixes them. |

## Auto-Promotion Trigger Point

`run` invokes `kb-promote.sh --auto` AFTER aggregate emits its envelope.
The auto-promote pass:

1. Reads `kb/.ledger.jsonl` (the last `2 * PROMOTE_AFTER` lines).
2. Computes promotion candidates per the rules above.
3. Writes new YAML + index entries.
4. Emits a one-line summary the orchestrator appends to the envelope:
   `KB_PROMOTED=<n>` and `KB_DEMOTED=<n>`.

Failure of auto-promote does NOT fail the run — it logs to stderr and
sets `KB_PROMOTE_STATUS=error` in the envelope.

## Why Auto-Promote (and the Risk)

The user chose auto-promote-on-N-green-runs over explicit promotion.
Tradeoffs:

- **Pro**: zero ceremony — corpus grows naturally as QA runs catch on.
- **Con**: a flaky-but-passing case can sneak in. Mitigation: rule (1)
  requires PASS, not flaky-recovered. Rule (2) requires checksum stability
  — a planner that keeps re-rolling the same case will eventually stick.
- **Con**: corpus drift if endpoints rename. Mitigation: doctor flags
  `endpoint-stale`, prune surfaces them.

Teams uncomfortable with auto-promote can set
`X_QA_KB_DISABLE_AUTO_PROMOTE=1` in their profile and run
`kb-promote --dry-run` periodically as a review queue.
