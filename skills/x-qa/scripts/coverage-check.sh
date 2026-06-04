#!/usr/bin/env bash
# coverage-check.sh — enforce that every `required` obligation in scope.json is
# covered by ≥1 test case's covers[] in the plan. The LLM enumerates obligations
# (judgment); this script enforces coverage (determinism). Plan may be YAML/JSON.
set -euo pipefail

SCOPE="" PLAN=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --scope) SCOPE="$2"; shift 2 ;;
    --plan)  PLAN="$2";  shift 2 ;;
    *) echo "COVERAGE_ERROR=unknown arg: $1" >&2; exit 2 ;;
  esac
done
[[ -f "$SCOPE" ]] || { echo "COVERAGE_ERROR=scope not found: $SCOPE" >&2; exit 2; }
[[ -f "$PLAN"  ]] || { echo "COVERAGE_ERROR=plan not found: $PLAN"  >&2; exit 2; }

# Normalize the plan to JSON (yq handles YAML or JSON input).
plan_json=$(yq eval -o=json '.' "$PLAN" 2>/dev/null) \
  || { echo "COVERAGE_ERROR=plan not parseable: $PLAN" >&2; exit 2; }

required=$(jq -c '[.obligations[]? | select(.severity=="required") | .id] | unique' "$SCOPE")
covered=$(jq -c  '[.test_cases[]?.covers[]?] | unique' <<<"$plan_json")
uncovered=$(jq -cn --argjson req "$required" --argjson cov "$covered" '$req - $cov')

req_n=$(jq 'length' <<<"$required")
unc_n=$(jq 'length' <<<"$uncovered")
cov_n=$(( req_n - unc_n ))

jq -n --argjson required "$required" --argjson uncovered "$uncovered" \
  --argjson rn "$req_n" --argjson cn "$cov_n" \
  '{ required:$rn, covered:$cn, uncovered:$uncovered,
     verdict:(if ($uncovered|length)==0 then "pass" else "fail" end) }'

[[ "$unc_n" -eq 0 ]]
