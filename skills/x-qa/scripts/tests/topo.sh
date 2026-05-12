#!/usr/bin/env bash
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TOPO="$SKILL_DIR/scripts/lib/topo-order.sh"

# Plan with 3 cases: tc-003 depends on tc-002; tc-001 independent.
plan=$(cat <<'JSON'
{ "test_cases": [
  { "id": "tc-001", "depends_on": [] },
  { "id": "tc-002", "depends_on": [] },
  { "id": "tc-003", "depends_on": ["tc-002"] }
]}
JSON
)

out=$(echo "$plan" | "$TOPO")
echo "$out"

w0=$(echo "$out" | jq -c '.waves[0] | sort')
w1=$(echo "$out" | jq -c '.waves[1] | sort')
[[ "$w0" == '["tc-001","tc-002"]' ]] || { echo "FAIL wave0: $w0"; exit 1; }
[[ "$w1" == '["tc-003"]' ]]          || { echo "FAIL wave1: $w1"; exit 1; }

# Cycle: must exit 2.
cycle=$(cat <<'JSON'
{ "test_cases": [
  { "id": "a", "depends_on": ["b"] },
  { "id": "b", "depends_on": ["a"] }
]}
JSON
)
set +e
echo "$cycle" | "$TOPO" >/dev/null 2>&1; rc=$?
set -e
[[ $rc -eq 2 ]] || { echo "FAIL cycle exit: got $rc, want 2"; exit 1; }

# Dangling dep: z depends on "ghost" which does not exist — must exit 1, not 2.
dangling='{"test_cases":[{"id":"x","depends_on":[]},{"id":"z","depends_on":["ghost"]}]}'
set +e
echo "$dangling" | "$TOPO" >/dev/null 2>&1; rc=$?
set -e
[[ $rc -eq 1 ]] || { echo "FAIL dangling exit: got $rc, want 1"; exit 1; }

echo "topo smoke: OK"
