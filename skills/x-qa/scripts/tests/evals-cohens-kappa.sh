#!/usr/bin/env bash
set -euo pipefail
DIR=$(cd "$(dirname "$0")/.." && pwd)
SUT="$DIR/evals/cohens-kappa.sh"
fail=0
check() { if [[ "$2" != "$3" ]]; then echo "FAIL: $1 — expected [$2] got [$3]"; fail=1; else echo "ok: $1"; fi }

# Perfect agreement → kappa 1
out=$(echo '[{"judge":"pass","human":"pass"},{"judge":"fail","human":"fail"},{"judge":"pass","human":"pass"}]' | "$SUT")
check "perfect n" "3" "$(jq -r '.n' <<<"$out")"
check "perfect kappa" "1" "$(jq -r '.kappa' <<<"$out")"

# Total disagreement on balanced labels → kappa -1
out=$(echo '[{"judge":"pass","human":"fail"},{"judge":"fail","human":"pass"}]' | "$SUT")
check "disagree kappa" "-1" "$(jq -r '.kappa' <<<"$out")"

# Empty → null kappa, no crash
out=$(echo '[]' | "$SUT")
check "empty kappa" "null" "$(jq -r '.kappa' <<<"$out")"

# 90% agreement sanity: 9 agree / 1 disagree, balanced-ish → kappa between 0.7 and 0.85
out=$(echo '[{"judge":"pass","human":"pass"},{"judge":"pass","human":"pass"},{"judge":"pass","human":"pass"},{"judge":"pass","human":"pass"},{"judge":"pass","human":"pass"},{"judge":"fail","human":"fail"},{"judge":"fail","human":"fail"},{"judge":"fail","human":"fail"},{"judge":"fail","human":"fail"},{"judge":"pass","human":"fail"}]' | "$SUT")
k=$(jq -r '.kappa' <<<"$out")
awk "BEGIN{exit !($k>0.7 && $k<0.85)}" && echo "ok: 90pct kappa band ($k)" || { echo "FAIL: 90pct kappa band got $k"; fail=1; }

exit $fail
