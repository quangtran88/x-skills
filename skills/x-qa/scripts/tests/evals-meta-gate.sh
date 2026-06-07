#!/usr/bin/env bash
set -euo pipefail
DIR=$(cd "$(dirname "$0")/.." && pwd)
SUT="$DIR/evals/meta-gate.sh"
fail=0
j() { jq -r "$1" <<<"$2"; }
check() { if [[ "$2" != "$3" ]]; then echo "FAIL: $1 — expected [$2] got [$3]"; fail=1; else echo "ok: $1"; fi }

# raw_pass true → pass regardless of kappa
out=$(echo '{"raw_pass":true,"scorer":"judge","kappa":0.4,"calibrated":true}' | "$SUT")
check "pass-through verdict" "pass" "$(j .verdict "$out")"
check "pass-through advisory" "false" "$(j .advisory "$out")"

# would-fail, deterministic scorer → hard fail (no kappa needed)
out=$(echo '{"raw_pass":false,"scorer":"deterministic","kappa":null,"calibrated":false}' | "$SUT")
check "det fail" "fail" "$(j .verdict "$out")"

# would-fail, calibrated kappa>=0.90 → hard fail
out=$(echo '{"raw_pass":false,"scorer":"judge","kappa":0.92,"calibrated":true}' | "$SUT")
check "kappa>=0.90 fail" "fail" "$(j .verdict "$out")"
check "kappa>=0.90 not-advisory" "false" "$(j .advisory "$out")"

# would-fail, 0.85<=kappa<0.90 → advisory pass (warn)
out=$(echo '{"raw_pass":false,"scorer":"judge","kappa":0.87,"calibrated":true}' | "$SUT")
check "kappa-band verdict" "pass" "$(j .verdict "$out")"
check "kappa-band advisory" "true" "$(j .advisory "$out")"
check "kappa-band uncal" "false" "$(j .uncalibrated "$out")"

# would-fail, calibrated but kappa<0.85 → advisory + uncalibrated flag
out=$(echo '{"raw_pass":false,"scorer":"judge","kappa":0.5,"calibrated":true}' | "$SUT")
check "low-kappa verdict" "pass" "$(j .verdict "$out")"
check "low-kappa uncal" "true" "$(j .uncalibrated "$out")"

# would-fail, no calibration → advisory + uncalibrated
out=$(echo '{"raw_pass":false,"scorer":"judge","kappa":null,"calibrated":false}' | "$SUT")
check "uncal verdict" "pass" "$(j .verdict "$out")"
check "uncal flag" "true" "$(j .uncalibrated "$out")"

exit $fail
