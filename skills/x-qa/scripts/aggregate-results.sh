#!/usr/bin/env bash
# aggregate-results.sh — merge cases/*.json into QA_REPORT.md + emit envelope.
# When --kb is set (default true unless --no-kb), also invokes kb-writeback.sh
# (baselines + ledger) and kb-promote.sh --auto (corpus promotion).
# Usage: aggregate-results.sh --run-dir <path> --plan <path> [--allow-flaky-rate <pct>] [--no-kb]
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

RUN_DIR=""
PLAN=""
ALLOW_FLAKY_RATE="0"
ENTRY_POINT=""
SERVICE_LAUNCHED="false"
EVIDENCE_INLINE_MAX_BYTES=4096
KB_ENABLED=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-dir) RUN_DIR="$2"; shift 2 ;;
    --plan) PLAN="$2"; shift 2 ;;
    --allow-flaky-rate) ALLOW_FLAKY_RATE="$2"; shift 2 ;;
    --entry-point) ENTRY_POINT="$2"; shift 2 ;;
    --service-launched) SERVICE_LAUNCHED="$2"; shift 2 ;;
    --no-kb) KB_ENABLED=false; shift ;;
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

# --- Quality gates evaluation (replaces legacy flaky-rate verdict) ----------
passRate=$(awk "BEGIN { if ($total == 0) print 0; else printf \"%.2f\", $passed * 100 / $total }")
flakyRatePct=$(awk "BEGIN { if ($total == 0) print 0; else printf \"%.2f\", $flaky * 100 / $total }")

metrics_json=$(jq -n \
  --argjson pr "$passRate" --argjson fr "$flakyRatePct" \
  '{tests: {passRate: $pr, flakyRate: $fr}}')

# Pull gates: plan first, then profile defaults, then empty.
gates_json='[]'
plan_gates=$(yq eval -o=json '.gates // []' "$PLAN" 2>/dev/null || echo '[]')
if [[ "$(jq 'length' <<<"$plan_gates")" -gt 0 ]]; then
  gates_json="$plan_gates"
else
  PROFILE_PATH="$(git rev-parse --show-toplevel 2>/dev/null)/.x-skills/x-qa/profile.json"
  if [[ -f "$PROFILE_PATH" ]]; then
    prof_gates=$(jq '.gates.defaults // []' "$PROFILE_PATH" 2>/dev/null || echo '[]')
    if [[ "$(jq 'length' <<<"$prof_gates")" -gt 0 ]]; then
      gates_json="$prof_gates"
    fi
  fi
fi

if [[ "$(jq 'length' <<<"$gates_json")" -gt 0 ]]; then
  verdict_input=$(jq -n --argjson m "$metrics_json" --argjson g "$gates_json" '{metrics: $m, gates: $g}')
  verdict_out=$(echo "$verdict_input" | "$SCRIPT_DIR/lib/verdict.sh")
  verdict=$(jq -r '.verdict' <<<"$verdict_out")
  gate_results=$(jq -c '.gate_results' <<<"$verdict_out")
  # Compute verdict_reason
  if [[ "$verdict" == "fail" ]]; then
    verdict_reason=$(jq -r '.gate_results | map(select(.status == "fail"))[0] | "\(.gate.metric) \(.value) (gate \(.gate))"' <<<"$verdict_out")
  elif [[ "$verdict" == "warn" ]]; then
    verdict_reason=$(jq -r '.gate_results | map(select(.status == "warn"))[0] | "\(.gate.metric) \(.value) (gate \(.gate))"' <<<"$verdict_out")
  else
    verdict_reason="all gates passed"
  fi
else
  verdict="pass"
  if [[ "$failed" -gt 0 ]]; then
    verdict="fail"
  fi
  verdict_reason="no gates declared"
  gate_results='[]'
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
  # Notes from scout phase — SKILL.md §15 promises open_questions surface in
  # the report; emit them verbatim so a fail isn't silently missing context.
  if [[ -f "$RUN_DIR/scope.json" ]]; then
    open_questions=$(jq -r '.open_questions // [] | .[]' "$RUN_DIR/scope.json" 2>/dev/null || true)
    if [[ -n "$open_questions" ]]; then
      echo "## Notes — Scout Open Questions"
      echo
      while IFS= read -r q; do
        [[ -n "$q" ]] && echo "- $q"
      done <<<"$open_questions"
      echo
    fi
  fi
  echo "## Failed Cases"
  echo
  jq -r '.[] | select(.verdict == "fail") | "### \(.id)\n\nError: \(.error)\n\n"' <<<"$results"
} > "$report_path"

if [[ "$(jq 'length' <<<"$gate_results")" -gt 0 ]]; then
  {
    echo
    echo "## Quality Gates"
    echo
    echo "| Metric | Bound | Measured | Status |"
    echo "|---|---|---|---|"
    jq -r '.[] | "| `\(.gate.metric)` | \(.gate.threshold // .gate.max // "—") | \(.value // "—") | \(.status) |"' <<<"$gate_results"
  } >> "$report_path"
fi

# KB write-back + auto-promote (skipped on --no-kb).
kb_promoted=0
kb_status="disabled"
kb_reused=0
kb_generated=0
if [[ "$KB_ENABLED" == true ]]; then
  # Read planner counters via safe KEY=value parse — NEVER source(.) the file.
  # A planner that interpolates an unsafe value (e.g. KB_REUSED=$(cmd)) must
  # not execute as shell here.
  if [[ -f "$RUN_DIR/kb-counters.env" ]]; then
    kb_reused=$(awk -F= '/^KB_REUSED=/{gsub(/[^0-9]/,"",$2); print $2; exit}' "$RUN_DIR/kb-counters.env")
    kb_generated=$(awk -F= '/^KB_GENERATED=/{gsub(/[^0-9]/,"",$2); print $2; exit}' "$RUN_DIR/kb-counters.env")
    : "${kb_reused:=0}"
    : "${kb_generated:=0}"
  fi
  # Emit per-case history into kb/history/<slug>.jsonl via kb-writeback --stdin.
  # Coverage signature comes from kb/index.json.cases[id].coverage_signature;
  # falls back to "<endpoint> :: <category>" when index has no entry.
  KB_INDEX="$(git rev-parse --show-toplevel 2>/dev/null)/.x-skills/x-qa/kb/index.json"
  HIST_TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  while IFS= read -r case_json; do
    cid=$(jq -r '.id' <<<"$case_json")
    cverdict=$(jq -r '.verdict' <<<"$case_json")
    cdur_ms=$(jq -r '.duration_ms // 0' <<<"$case_json")
    cerr=$(jq -r '.error // empty' <<<"$case_json")
    # Lookup case in plan for endpoint+category
    cep=$(jq -r --arg id "$cid" '.[] | select(.id == $id) | (.endpoint // ((.request.method // "GET") + " " + (.request.path // "/")))' <<<"$all_cases")
    ccat=$(jq -r --arg id "$cid" '.[] | select(.id == $id) | (.category // "unknown")' <<<"$all_cases")
    csig=""
    if [[ -f "$KB_INDEX" ]]; then
      csig=$(jq -r --arg id "$cid" '.cases[$id].coverage_signature // empty' "$KB_INDEX" 2>/dev/null || true)
    fi
    [[ -z "$csig" ]] && csig="$cep :: $ccat"
    cdur_s=$(awk "BEGIN { printf \"%.3f\", $cdur_ms / 1000 }")
    line=$(jq -c -n \
      --arg run "$run_id" --arg ts "$HIST_TS" --arg sig "$csig" \
      --arg result "$cverdict" --argjson dur "$cdur_s" --arg cid "$cid" \
      --arg reason "$cerr" \
      '{run_id:$run, timestamp:$ts, signature:$sig, result:$result, duration_s:$dur, case_id:$cid} + (if $reason == "" then {} else {failure_reason:$reason} end)')
    echo "$line" | "$SCRIPT_DIR/kb-writeback.sh" --stdin || true
  done < <(jq -c '.[]' <<<"$results")
  if ! writeback_out=$("$SCRIPT_DIR/kb-writeback.sh" --run-dir "$RUN_DIR" --plan "$PLAN" 2>&1); then
    echo "$writeback_out" >&2
    kb_status="error"
  fi
  if [[ "$kb_status" != "error" ]]; then
    if promote_out=$("$SCRIPT_DIR/kb-promote.sh" --auto 2>&1); then
      kb_promoted=$(awk -F= '/^KB_PROMOTED=/{print $2}' <<<"$promote_out")
      kb_status=$(awk   -F= '/^KB_PROMOTE_STATUS=/{print $2}' <<<"$promote_out")
      : "${kb_promoted:=0}"; : "${kb_status:=ok}"
    else
      echo "$promote_out" >&2
      kb_status="error"
    fi
  fi
fi

# Emit envelope
echo "✓ x-qa run complete"
echo "QA_VERDICT=$verdict"
echo "QA_VERDICT_REASON=$verdict_reason"
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
echo "KB_REUSED=$kb_reused"
echo "KB_GENERATED=$kb_generated"
echo "KB_PROMOTED=$kb_promoted"
echo "KB_PROMOTE_STATUS=$kb_status"
