#!/usr/bin/env bash
# aggregate-results.sh — merge cases/*.json into QA_REPORT.md + emit envelope
# Usage: aggregate-results.sh --run-dir <path> --plan <path> [--allow-flaky-rate <pct>]
set -euo pipefail

RUN_DIR=""
PLAN=""
ALLOW_FLAKY_RATE="0"
ENTRY_POINT=""
SERVICE_LAUNCHED="false"
EVIDENCE_INLINE_MAX_BYTES=4096

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-dir) RUN_DIR="$2"; shift 2 ;;
    --plan) PLAN="$2"; shift 2 ;;
    --allow-flaky-rate) ALLOW_FLAKY_RATE="$2"; shift 2 ;;
    --entry-point) ENTRY_POINT="$2"; shift 2 ;;
    --service-launched) SERVICE_LAUNCHED="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

# Resolve ENTRY_POINT from plan if not passed explicitly (back-compat)
if [[ -z "$ENTRY_POINT" && -f "$PLAN" ]]; then
  ENTRY_POINT=$(yq eval '.entry_point // ""' "$PLAN" 2>/dev/null || echo "")
fi

cases_dir="$RUN_DIR/cases"
[[ -d "$cases_dir" ]] || { echo "REASON=cases dir missing: $cases_dir" >&2; exit 2; }

# Collect every case file (graceful with missing entries)
all_cases=$(yq eval -o=json '.test_cases // []' "$PLAN")
total=$(jq -r 'length' <<<"$all_cases")

# Decision #13:A — empty plan = strict fail. Refuse before any awk arithmetic.
if [[ "$total" -eq 0 ]]; then
  run_id=$(basename "$RUN_DIR")
  echo "✗ x-qa run FAILED"
  echo "REASON=plan has no test_cases (empty plan — planner regression or surface filter dropped all endpoints)"
  echo "PHASE=aggregate"
  echo "QA_RUN_ID=$run_id"
  exit 2
fi

started_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
run_started_epoch=$(date +%s)
results='[]'

while IFS= read -r case_id; do
  result_file="$cases_dir/$case_id.json"
  if [[ -f "$result_file" ]]; then
    if jq -e . "$result_file" > /dev/null 2>&1; then
      # Spill oversized evidence to a sidecar file so the report stays scannable
      size=$(wc -c < "$result_file" | tr -d ' ')
      if (( size > EVIDENCE_INLINE_MAX_BYTES )); then
        spill_rel="cases/${case_id}.json"
        results=$(jq --slurpfile r "$result_file" --arg spill "$spill_rel" \
          '. + ($r | map(. + {evidence: {spilled: $spill}}))' <<<"$results")
      else
        results=$(jq --slurpfile r "$result_file" '. + $r' <<<"$results")
      fi
    else
      # Invalid JSON — quarantine and synthesise failure
      mv "$result_file" "$cases_dir/$case_id.raw" 2>/dev/null || true
      results=$(jq --arg id "$case_id" '. + [{
        id: $id, verdict: "fail", runner: "unknown", attempts: 1,
        duration_ms: 0, error: "invalid json output", evidence: {}
      }]' <<<"$results")
    fi
  else
    results=$(jq --arg id "$case_id" '. + [{
      id: $id, verdict: "fail", runner: "unknown", attempts: 0,
      duration_ms: 0, error: "runner did not produce result file", evidence: {}
    }]' <<<"$results")
  fi
done < <(jq -r '.[].id' <<<"$all_cases")

passed=$(jq '[.[] | select(.verdict == "pass")] | length' <<<"$results")
failed=$(jq '[.[] | select(.verdict == "fail")] | length' <<<"$results")
flaky=$(jq '[.[] | select(.verdict == "flaky-recovered")] | length' <<<"$results")
flaky_rate=$(awk "BEGIN { if ($total == 0) print \"0.0000\"; else printf \"%.4f\", $flaky / $total }")
duration_s=$(awk "BEGIN { printf \"%.2f\", $(date +%s) - $run_started_epoch }")

# Verdict logic
if [[ $failed -gt 0 ]]; then
  verdict="fail"
elif [[ $flaky -gt 0 ]]; then
  if (( $(awk "BEGIN { print ($flaky_rate > $ALLOW_FLAKY_RATE) }") )); then
    verdict="fail"
  else
    verdict="pass"
  fi
else
  verdict="pass"
fi

# Build report — emit cases via jq -> YAML so quoting is safe
report_path="$RUN_DIR/QA_REPORT.md"
feature=$(yq eval '.feature' "$PLAN")
entry_point=$(yq eval '.entry_point' "$PLAN")
run_id=$(basename "$RUN_DIR")

cases_yaml=$(jq -r '.[] |
  "  - id: \(.id | tojson)\n" +
  "    verdict: \(.verdict | tojson)\n" +
  "    runner: \(.runner | tojson)\n" +
  "    attempts: \(.attempts)\n" +
  "    duration_ms: \(.duration_ms)\n" +
  "    error: \(.error | tojson)\n" +
  "    evidence: \(.evidence | tojson)"' <<<"$results")

{
  echo "---"
  echo "run_id: $run_id"
  echo "feature: $feature"
  echo "entry_point: $entry_point"
  echo "verdict: $verdict"
  echo "total: $total"
  echo "passed: $passed"
  echo "failed: $failed"
  echo "flaky: $flaky"
  echo "flaky_rate: $flaky_rate"
  echo "started_at: $started_at"
  echo "duration_s: $duration_s"
  echo "cases:"
  echo "$cases_yaml"
  echo "---"
  echo
  if [[ "$verdict" == "fail" ]]; then
    echo "# QA Report — $feature"
    echo
    echo "## ✗ FAIL ($passed/$total passed)"
  else
    echo "# QA Report — $feature"
    echo
    echo "## ✓ PASS ($passed/$total passed)"
  fi
  echo
  echo "## Failed Cases"
  echo
  jq -r '.[] | select(.verdict == "fail") | "### \(.id)\n\nError: \(.error)\n\n"' <<<"$results"
} > "$report_path"

# Emit envelope
echo "✓ x-qa run complete"
echo "QA_VERDICT=$verdict"
echo "QA_TOTAL=$total"
echo "QA_PASSED=$passed"
echo "QA_FAILED=$failed"
echo "QA_FLAKY=$flaky"
echo "QA_FLAKY_RATE=$flaky_rate"
echo "QA_REPORT=$report_path"
echo "QA_PLAN=$PLAN"
echo "QA_RUN_ID=$run_id"
echo "DURATION_S=$duration_s"
echo "ENTRY_POINT=$ENTRY_POINT"
echo "SERVICE_LAUNCHED=$SERVICE_LAUNCHED"
