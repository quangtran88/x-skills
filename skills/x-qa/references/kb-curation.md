# KB Curation Rules

How entries enter and age out of `.x-skills/x-qa/kb/`. Curation runs at the
END of every `run` (after aggregate, before envelope emit) — driven by
`scripts/kb-promote.sh`.

## Tunables (env vars)

| Env var | Default | Meaning |
|---|---|---|
| `X_QA_KB_PROMOTE_AFTER`        | `3`  | Consecutive green runs before a generated case auto-promotes. |
| `X_QA_KB_DISABLE_AUTO_PROMOTE` | unset| When set, no auto-promotion runs. Manual only. |

Other thresholds (window=50 for baseline percentiles, flow-min-length=2)
are hardcoded. They were originally env tunables but cut as anticipatory
configuration — adjust the source when a real need surfaces.

Override per-run with flags: `--kb-promote-after N`, `--kb-disable-auto-promote`.

## Case Promotion

A `generated` case in a run-local plan is a **candidate** when:

1. Its verdict is `pass` (not `flaky-recovered`).
2. Its body hash matches the prior run's hash for the same case ID
   (i.e. the case definition is stable across the streak).
3. `consecutive_pass >= X_QA_KB_PROMOTE_AFTER`.

`consecutive_pass` is derived from `kb/.ledger.jsonl`. The first run a
case appears in is `consecutive_pass = 1`. A `fail` verdict resets the
counter to 0; `flaky-recovered` leaves it unchanged.

Promotion writes:
- `kb/cases/tc-<slug>.yaml` with provenance fields filled in.
- `kb/index.json.cases.<id>` with `green_streak`, `promoted_at`,
  `promoted_from_run`, `checksum`.

## Manual Demotion (v1: by hand)

A promoted case that goes bad is removed by hand:

```
git rm .x-skills/x-qa/kb/cases/tc-foo.yaml
jq 'del(.cases["tc-foo"])' .x-skills/x-qa/kb/index.json > /tmp/idx \
  && mv /tmp/idx .x-skills/x-qa/kb/index.json
```

A `kb-demote.sh` subcommand and quarantine lifecycle were cut as
speculative — bring them back if/when auto-promotion produces enough
bad entries to justify a dedicated workflow.

Hand-edited corpus YAMLs are detected separately: `doctor.sh` compares
the file's sha256 against the index's `checksum` and emits a warning.
v1 does NOT auto-act on checksum drift — review and either accept the
edit (`kb-promote --force <id>` to refresh the recorded checksum) or
revert it.

## Flow Promotion

Flows are observed, not generated directly. The aggregator emits a
`flow_observations[]` array in each ledger line containing every
`depends_on` chain that ran AND every case in the chain passed.

A chain promotes to `kb/flows/fl-<slug>.yaml` when:

1. The same exact case-ID sequence appears in `>=
   X_QA_KB_PROMOTE_AFTER` consecutive runs with `all_pass: true`.
2. Every case in the chain is itself a promoted KB case.
3. Chain length `>= 2`.

Capture/inject directives are not inferred. The first flow promotion
emits a flow YAML with empty `capture`/`inject` blocks; subsequent
manual edits add them.

## Baseline Update Rules

Run after every test case (regardless of verdict). Baselines are
**passive memory** — they record what was seen, not regression signals.

1. **`status_codes`** — increment the count for the observed status.
2. **`latency_ms`** — push the observed latency into the rolling
   window (size 50). Recompute `p50` / `p95` over the window.
3. **`last_seen_at`** / **`samples`** — bump.

The original baselines layer also computed p99/max/EWMA, an additive
response-shape JSON Schema union, flaky-rate, and drift signals. All
were cut as scope creep — they served a regression-monitoring goal
that the user did not ask for. The slim version above is the floor
that still meets "maintain knowledge across runs."

## Endpoint Rename Handling

When a case references an endpoint not in `profile.json`'s scanned
catalog, doctor flags the case as `endpoint-stale`. The planner skips
endpoint-stale cases. `kb-prune.sh --orphans` lists them for human
review — never auto-deletes (the endpoint may have just been moved).

## Manual Override Commands

| Command | Effect |
|---|---|
| `kb-promote --force <case-id>` | Promote regardless of streak. |
| `kb-promote --dry-run` | Print what would auto-promote, no writes. |
| `kb-inspect <case-id>` | Pretty-print case + ledger history. |
| `kb-prune --orphans` | List files with no index entry, or index entries with no file. |
| `kb-prune --orphans --apply` | Same, but remove. |

## Auto-Promotion Trigger Point

`run` invokes `kb-promote.sh --auto` AFTER aggregate emits its envelope.
The auto-promote pass:

1. Reads the recent tail of `kb/.ledger.jsonl`.
2. Computes promotion candidates per the rules above.
3. Writes new YAML + index entries.
4. Emits a one-line summary the orchestrator appends to the envelope:
   `KB_PROMOTED=<n>` and `KB_PROMOTE_STATUS=ok|disabled|error`.

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
