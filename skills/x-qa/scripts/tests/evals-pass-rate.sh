#!/usr/bin/env bash
set -euo pipefail
DIR=$(cd "$(dirname "$0")/.." && pwd)
SUT="$DIR/evals/pass-rate.sh"
fail=0
check() { # name expected actual
  if [[ "$2" != "$3" ]]; then echo "FAIL: $1 — expected [$2] got [$3]"; fail=1; else echo "ok: $1"; fi
}

# All three samples >= 0.8 → pass_rate 1, raw_pass true (default min 1.0)
out=$(echo '{"scores":[0.9,0.85,0.8],"threshold":0.8}' | "$SUT")
check "pass_rate all-pass" "1" "$(jq -r '.pass_rate' <<<"$out")"
check "raw_pass all-pass" "true" "$(jq -r '.raw_pass' <<<"$out")"

# One below threshold → pass_rate 2/3, raw_pass false at default min 1.0
# (tolerance check — jq float formatting differs across 1.6/1.7)
out=$(echo '{"scores":[0.9,0.7,0.85],"threshold":0.8}' | "$SUT")
pr=$(jq -r '.pass_rate' <<<"$out")
awk "BEGIN{d=$pr-0.6667; exit !(d<0.001 && d>-0.001)}" && echo "ok: pass_rate one-fail ($pr)" || { echo "FAIL: pass_rate one-fail got $pr"; fail=1; }
check "raw_pass one-fail-strict" "false" "$(jq -r '.raw_pass' <<<"$out")"

# Relaxed min pass-rate 0.6 → 2/3 passes the bar
out=$(X_QA_MIN_PASS_RATE=0.6 sh -c "echo '{\"scores\":[0.9,0.7,0.85],\"threshold\":0.8}' | '$SUT'")
check "raw_pass relaxed" "true" "$(jq -r '.raw_pass' <<<"$out")"

# Empty scores → raw_pass false, reason set
out=$(echo '{"scores":[],"threshold":0.8}' | "$SUT")
check "empty raw_pass" "false" "$(jq -r '.raw_pass' <<<"$out")"

exit $fail
