#!/usr/bin/env bash
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
FIX="$SKILL_DIR/scripts/tests/fixtures/gates-pass-warn-fail.json"

VERDICT=$("$SKILL_DIR/scripts/lib/verdict.sh" < "$FIX" | jq -r '.verdict')
[[ "$VERDICT" == "warn" ]] || { echo "FAIL: expected warn, got $VERDICT"; exit 1; }

ALL_PASS=$(jq '.metrics.tests.flakyRate = 3' "$FIX" | "$SKILL_DIR/scripts/lib/verdict.sh" | jq -r '.verdict')
[[ "$ALL_PASS" == "pass" ]] || { echo "FAIL: expected pass, got $ALL_PASS"; exit 1; }

HARD_FAIL=$(jq '.metrics.tests.passRate = 90' "$FIX" | "$SKILL_DIR/scripts/lib/verdict.sh" | jq -r '.verdict')
[[ "$HARD_FAIL" == "fail" ]] || { echo "FAIL: expected fail, got $HARD_FAIL"; exit 1; }

echo "verdict smoke: PASS"
