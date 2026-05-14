#!/usr/bin/env bash
# kb-writeback.sh — invoked by aggregate-results.sh after verdict computation.
# Walks <run-dir>/cases/*.json + the plan, then:
#   1. Updates kb/baselines/<endpoint-slug>.json — slim per-endpoint memory
#      (samples + rolling p50/p95 + status-code histogram + last_seen_at).
#   2. Appends a run-summary line to kb/.ledger.jsonl with cases[] +
#      flow_observations[] for the streak counter in kb-promote.sh.
#
# Usage: kb-writeback.sh --run-dir <path> --plan <path>
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/lib/kb-common.sh"

# Rolling window for baseline percentiles. Hardcoded — the depth here is
# intentionally shallow (samples + p50/p95). The original tunable
# X_QA_KB_BASELINE_WINDOW was cut as anticipatory configuration.
BASELINE_WINDOW=50

RUN_DIR=""; PLAN=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-dir) RUN_DIR="$2"; shift 2 ;;
    --plan)    PLAN="$2";    shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done
[[ -d "$RUN_DIR" && -f "$PLAN" ]] || { echo "✗ kb-writeback: bad args" >&2; exit 2; }

kb_ensure_layout
INDEX=$(kb_index_path)
LEDGER=$(kb_ledger_path)
BASELINES_DIR=$(kb_baselines_dir)
RUN_ID=$(basename "$RUN_DIR")
NOW=$(kb_now)

ENRICHED=$(mktemp)
trap 'rm -f "$ENRICHED"' EXIT

yq eval -o=json '.test_cases // []' "$PLAN" \
  | jq -c --arg run "$RUN_ID" --arg dir "$RUN_DIR" '
      .[] as $tc
      | {
          id:            $tc.id,
          endpoint:      ($tc.endpoint // (($tc.request.method // "GET") + " " + ($tc.request.path // "/"))),
          category:      ($tc.category // "unknown"),
          depends_on:    ($tc.depends_on // []),
          body_path:     ($dir + "/plan-cases/" + $tc.id + ".yaml"),
          run_id:        $run
        }
    ' > "$ENRICHED"

# ---- Per-case baseline update (slim) --------------------------------------
LEDGER_CASES='[]'
while IFS= read -r tc; do
  cid=$(jq -r '.id'        <<<"$tc")
  ep=$(jq  -r '.endpoint'  <<<"$tc")
  cat=$(jq -r '.category'  <<<"$tc")
  result_file="$RUN_DIR/cases/$cid.json"

  # Track whether this case produced a real measurement. Missing or invalid
  # result files must NEVER push a fake `0ms` sample into the baseline
  # percentile window (would silently report p50/p95 = 0 for endpoints that
  # never responded). Verdict still lands in the ledger as a fail.
  has_measurement=0
  if [[ ! -f "$result_file" ]] || ! jq -e . "$result_file" >/dev/null 2>&1; then
    verdict="fail"; status=""; latency_ms=0
  else
    verdict=$(jq -r '.verdict // "fail"'                  "$result_file")
    status=$(jq  -r '.evidence.response.status // empty'  "$result_file")
    latency_ms=$(jq -r '.evidence.latency_ms // .duration_ms // 0' "$result_file")
    has_measurement=1
  fi

  LEDGER_CASES=$(jq --arg id "$cid" --arg v "$verdict" --arg ep "$ep" --arg c "$cat" \
                    --arg body "$(jq -r '.body_path' <<<"$tc")" \
    '. + [{id:$id, verdict:$v, endpoint:$ep, category:$c, body_path:$body}]' \
    <<<"$LEDGER_CASES")

  # Skip baseline writes when there's no real sample — verdict-only.
  if [[ "$has_measurement" -eq 0 ]]; then
    continue
  fi

  slug=$(kb_endpoint_slug "$ep")
  bfile="$BASELINES_DIR/$slug.json"
  if [[ ! -f "$bfile" ]]; then
    jq -n --arg ep "$ep" --arg now "$NOW" --argjson w "$BASELINE_WINDOW" '{
      schema: 1, endpoint: $ep, window: $w, samples: 0,
      first_seen_at: $now, last_seen_at: $now,
      status_codes: {},
      latency_ms: { p50: 0, p95: 0, _window: [] }
    }' > "$bfile"
  fi

  tmp=$(mktemp)
  jq --arg now "$NOW" --arg status "$status" \
     --argjson lat "$latency_ms" --argjson w "$BASELINE_WINDOW" '
    def push_window($x; $w): (._window // []) + [$x] | .[-$w:];
    def percentile($p):
      length as $n
      | sort
      | if $n == 0 then 0 else .[ ([ ($n - 1) * $p / 100 | floor, $n - 1 ] | min) ] end;

    .last_seen_at = $now
    | .samples = (.samples + 1)
    | (if ($status | length) > 0
        then .status_codes[$status] = ((.status_codes[$status] // 0) + 1)
        else . end)
    | .latency_ms = (
        .latency_ms
        | ._window = push_window($lat; $w)
        | .p50 = (._window | percentile(50))
        | .p95 = (._window | percentile(95))
      )
  ' "$bfile" > "$tmp"
  mv "$tmp" "$bfile"

  samples=$(jq -r '.samples' "$bfile")
  tmp=$(mktemp)
  jq --arg ep "$ep" --arg slug "$slug" --arg now "$NOW" \
     --argjson samples "$samples" \
    '.baselines[$ep] = { file: ("baselines/" + $slug + ".json"), samples: $samples, last_seen_at: $now }' \
    "$INDEX" > "$tmp"
  mv "$tmp" "$INDEX"

done < <(jq -c '.' "$ENRICHED")

# ---- Flow observations ----------------------------------------------------
# A "chain" = maximal linear depends_on path. consecutive_pass counts this
# run + trailing prior-run streak. A miss resets to 1.
PLAN_JSON=$(yq eval -o=json '.test_cases // []' "$PLAN")
LEDGER_PRIOR=$(if [[ -s "$LEDGER" ]]; then jq -s '.' "$LEDGER"; else echo "[]"; fi)
FLOW_OBS=$(python3 - "$PLAN_JSON" "$LEDGER_CASES" "$LEDGER_PRIOR" <<'PY'
import json, sys
plan        = json.loads(sys.argv[1])
cases       = json.loads(sys.argv[2])
ledger_prior = json.loads(sys.argv[3])

verdict_by_id = {c["id"]: c["verdict"] for c in cases}
upstream_by_id = {}
for tc in plan:
    deps = tc.get("depends_on") or []
    if len(deps) == 1:
        upstream_by_id[tc["id"]] = deps[0]
    elif len(deps) > 1:
        upstream_by_id[tc["id"]] = None  # branching — skip from linear chain detection

downstreams = set(v for v in upstream_by_id.values() if v)
ids_with_linear_or_none = set(verdict_by_id) - {i for i, u in upstream_by_id.items() if u is None}
leaves = [i for i in ids_with_linear_or_none if i not in downstreams]

obs = []
for leaf in leaves:
    chain = [leaf]
    cur = leaf
    while cur in upstream_by_id and upstream_by_id[cur] is not None:
        cur = upstream_by_id[cur]
        if cur in chain:
            break
        chain.append(cur)
    chain.reverse()
    if len(chain) < 2:
        continue
    all_pass = all(verdict_by_id.get(c) == "pass" for c in chain)
    consec = 0
    if all_pass:
        consec = 1
        for line in reversed(ledger_prior):
            matched = any(fo.get("chain") == chain and fo.get("all_pass") for fo in line.get("flow_observations", []))
            if matched:
                consec += 1
            else:
                break
    obs.append({"chain": chain, "all_pass": all_pass, "consecutive_pass": consec})

json.dump(obs, sys.stdout)
PY
)

total=$(jq 'length' <<<"$LEDGER_CASES")
passed=$(jq '[.[] | select(.verdict == "pass")] | length' <<<"$LEDGER_CASES")
failed=$(jq '[.[] | select(.verdict == "fail")] | length' <<<"$LEDGER_CASES")
flaky=$(jq  '[.[] | select(.verdict == "flaky-recovered")] | length' <<<"$LEDGER_CASES")
overall="pass"
[[ "$failed" -gt 0 ]] && overall="fail"

jq -c -n \
  --arg run "$RUN_ID" --arg ts "$NOW" --arg v "$overall" \
  --argjson cases "$LEDGER_CASES" --argjson flows "$FLOW_OBS" \
  --argjson total "$total" --argjson passed "$passed" --argjson failed "$failed" --argjson flaky "$flaky" '
  { run_id: $run, started_at: $ts, verdict: $v,
    total: $total, passed: $passed, failed: $failed, flaky: $flaky,
    cases: $cases, flow_observations: $flows }
' > "$ENRICHED.line"

# Atomic append under flock — multi-KB ledger lines exceed POSIX PIPE_BUF
# (~4 KiB) so concurrent `>>` appends from parallel x-team runs can interleave
# and corrupt JSON lines. Once corrupted, kb-promote's strict `jq -s '.'`
# aborts on the bad line and auto-promotion stalls silently.
#
# `flock` is available on Linux by default; on macOS it ships with util-linux
# via Homebrew. Fall back to a python fcntl.lockf wrapper if neither is found.
if command -v flock >/dev/null 2>&1; then
  ( flock -x 9; cat "$ENRICHED.line" >>"$LEDGER" ) 9>"$LEDGER.lock"
else
  python3 - "$LEDGER" "$LEDGER.lock" "$ENRICHED.line" <<'PY'
import fcntl, sys
ledger, lockf, src = sys.argv[1:]
with open(lockf, "a") as l:
    fcntl.lockf(l, fcntl.LOCK_EX)
    with open(src) as s, open(ledger, "a") as out:
        out.write(s.read())
PY
fi
rm -f "$ENRICHED.line"
