#!/usr/bin/env bash
# pass-rate.sh — N-sample eval aggregation.
# stdin: { "scores": [<float 0..1>...], "threshold": <float> }
# A sample passes if score >= threshold. pass_rate = passes / N.
# raw_pass = pass_rate >= X_QA_MIN_PASS_RATE (default 1.0 — all samples must pass).
# stdout: { samples, passes, pass_rate, threshold, raw_pass, mean }
set -euo pipefail
INPUT=$(cat)
MINPR="${X_QA_MIN_PASS_RATE:-1.0}"
jq -n --argjson d "$INPUT" --argjson minpr "$MINPR" '
  ($d.scores // []) as $s | ($d.threshold) as $t
  | ($s | length) as $n
  | if $n == 0 then
      { samples:0, passes:0, pass_rate:0, threshold:$t, raw_pass:false, mean:null, reason:"no scores" }
    else
      ([$s[] | select(. >= $t)] | length) as $p
      | { samples:$n, passes:$p, pass_rate:($p/$n), threshold:$t,
          raw_pass:(($p/$n) >= $minpr), mean:(($s|add)/$n) }
    end'
