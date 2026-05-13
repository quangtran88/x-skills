#!/usr/bin/env bash
# kb-writeback.sh — invoked by aggregate-results.sh after verdict computation.
# Walks <run-dir>/cases/*.json + the plan, then:
#   1. Updates kb/baselines/<endpoint-slug>.json (per-endpoint stats, rolling window).
#   2. Computes drift signals against prior baseline.
#   3. Appends a run-summary line to kb/.ledger.jsonl with cases[] + flow_observations[].
#
# Outputs (stdout, one per line):
#   KB_DRIFT=<n>
#
# Usage: kb-writeback.sh --run-dir <path> --plan <path>
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/lib/kb-common.sh"

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
drift_count=0

# Build a per-case enriched record we can replay into the ledger.
# We combine plan metadata (endpoint, category, depends_on, body_path) with
# the run-local case result JSON (verdict, latency, status code).
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

# ---- Per-case baseline update ---------------------------------------------
LEDGER_CASES='[]'
while IFS= read -r tc; do
  cid=$(jq -r '.id'        <<<"$tc")
  ep=$(jq  -r '.endpoint'  <<<"$tc")
  cat=$(jq -r '.category'  <<<"$tc")
  result_file="$RUN_DIR/cases/$cid.json"

  if [[ ! -f "$result_file" ]] || ! jq -e . "$result_file" >/dev/null 2>&1; then
    verdict="fail"; status=""; latency_ms=0
  else
    verdict=$(jq -r '.verdict // "fail"'                  "$result_file")
    status=$(jq  -r '.evidence.response.status // empty'  "$result_file")
    latency_ms=$(jq -r '.evidence.latency_ms // .duration_ms // 0' "$result_file")
  fi

  # Append a per-case entry to the ledger array.
  LEDGER_CASES=$(jq --arg id "$cid" --arg v "$verdict" --arg ep "$ep" --arg c "$cat" \
                    --arg body "$(jq -r '.body_path' <<<"$tc")" \
    '. + [{id:$id, verdict:$v, endpoint:$ep, category:$c, body_path:$body}]' \
    <<<"$LEDGER_CASES")

  # --- Baseline update ---
  slug=$(kb_endpoint_slug "$ep")
  bfile="$BASELINES_DIR/$slug.json"
  if [[ ! -f "$bfile" ]]; then
    jq -n --arg ep "$ep" --arg now "$NOW" --argjson w "$X_QA_KB_BASELINE_WINDOW" '{
      schema: 1,
      endpoint: $ep,
      first_seen_at: $now,
      last_seen_at: $now,
      window: $w,
      samples: 0,
      response_shape: null,
      status_codes: {},
      latency_ms: { samples: 0, p50:0, p95:0, p99:0, max:0, ewma:0, _window:[] },
      flaky_rate: { window: $w, samples: 0, fails: 0, flaky_recovered: 0, rate: 0 },
      drift_signals: { new_status_code_seen:false, shape_added_required_field:false, latency_p95_regression_pct:0, flaky_rate_spike:false }
    }' > "$bfile"
  fi

  # Drift is only meaningful once a baseline has been seen at least once
  # before. On the very first observation, status_codes is {} and prior_p95
  # is 0 — both would otherwise trip "drift" on every endpoint at adoption.
  prior_samples=$(jq -r '.samples' "$bfile")
  prior_p95=$(jq -r '.latency_ms.p95 // 0' "$bfile")
  prior_status_codes=$(jq -c '.status_codes // {}' "$bfile")

  new_status_seen="false"
  if [[ -n "$status" && "$prior_samples" -gt 0 ]]; then
    has_status=$(jq -r --arg s "$status" 'has($s)' <<<"$prior_status_codes")
    [[ "$has_status" == "false" ]] && new_status_seen="true"
  fi

  fail_inc=0
  flaky_inc=0
  case "$verdict" in
    fail)             fail_inc=1 ;;
    flaky-recovered)  flaky_inc=1 ;;
  esac

  _apply_baseline() {
    local tmp; tmp=$(mktemp)
    jq --arg now "$NOW" --arg status "$status" \
       --argjson lat "$latency_ms" \
       --argjson fail_inc "$fail_inc" \
       --argjson flaky_inc "$flaky_inc" \
       --argjson w "$X_QA_KB_BASELINE_WINDOW" \
       --argjson new_status_seen "$([[ "$new_status_seen" == "true" ]] && echo true || echo false)" \
    '
      def push_window($x; $w):
        (._window // []) + [$x] | .[-$w:];
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
          | .samples = (._window | length)
          | .p50 = (._window | percentile(50))
          | .p95 = (._window | percentile(95))
          | .p99 = (._window | percentile(99))
          | .max = (._window | (max // 0))
          | .ewma = (if .ewma == 0 then $lat else (0.2 * $lat + 0.8 * .ewma) end)
        )
      | .flaky_rate.samples = (.flaky_rate.samples + 1)
      | .flaky_rate.fails = (.flaky_rate.fails + $fail_inc)
      | .flaky_rate.flaky_recovered = (.flaky_rate.flaky_recovered + $flaky_inc)
      | .flaky_rate.rate = (if .flaky_rate.samples == 0 then 0 else (.flaky_rate.fails / .flaky_rate.samples) end)
      | .drift_signals.new_status_code_seen = $new_status_seen
    ' "$bfile" > "$tmp"
    mv "$tmp" "$bfile"
  }
  kb_with_lock "$bfile" _apply_baseline

  # Drift: latency p95 regression > 20% — only after baseline has prior data.
  new_p95=$(jq -r '.latency_ms.p95' "$bfile")
  if [[ "$prior_samples" -gt 0 ]] && (( $(awk "BEGIN {print ($prior_p95 > 0 && $new_p95 > $prior_p95 * 1.2) ? 1 : 0}") )); then
    pct=$(awk "BEGIN {printf \"%.2f\", ($new_p95 - $prior_p95) / $prior_p95 * 100}")
    _apply_p95() {
      local tmp; tmp=$(mktemp)
      jq --argjson pct "$pct" '.drift_signals.latency_p95_regression_pct = $pct' "$bfile" > "$tmp"
      mv "$tmp" "$bfile"
    }
    kb_with_lock "$bfile" _apply_p95
    drift_count=$((drift_count + 1))
  fi
  if [[ "$new_status_seen" == "true" ]]; then
    drift_count=$((drift_count + 1))
  fi

  # Index baselines entry — locked, since concurrent runs may touch it.
  samples=$(jq -r '.samples' "$bfile")
  _apply_idx_baseline() {
    local tmp; tmp=$(mktemp)
    jq --arg ep "$ep" --arg slug "$slug" --arg now "$NOW" \
       --argjson w "$X_QA_KB_BASELINE_WINDOW" --argjson samples "$samples" \
      '.baselines[$ep] = { file: ("baselines/" + $slug + ".json"), samples: $samples, window: $w, last_seen_at: $now }' \
      "$INDEX" > "$tmp"
    mv "$tmp" "$INDEX"
  }
  kb_with_lock "$INDEX" _apply_idx_baseline

done < <(jq -c '.' "$ENRICHED")

# ---- Flow observations -----------------------------------------------------
# A "chain" = a maximal linear depends_on path that was fully executed in
# this run. v1 detects only linear chains (each case has 0 or 1 upstream).
# DAG branches are legal in plans but not promoted as flows (v2).
#
# consecutive_pass counts the current run + the trailing run of prior ledger
# lines that observed the same chain with all_pass:true. A miss resets to 1.
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

# Leaves = ids that nobody depends_on.
downstreams = set(v for v in upstream_by_id.values() if v)
ids_with_linear_or_none = set(verdict_by_id) - {i for i, u in upstream_by_id.items() if u is None}
leaves = [i for i in ids_with_linear_or_none if i not in downstreams]

obs = []
for leaf in leaves:
    chain = [leaf]
    cur = leaf
    while cur in upstream_by_id and upstream_by_id[cur] is not None:
        cur = upstream_by_id[cur]
        if cur in chain:  # cycle guard (should not happen — topo-order.sh refuses)
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

# ---- Append run-summary line to ledger ------------------------------------
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
' >> "$LEDGER"

echo "KB_DRIFT=$drift_count"
