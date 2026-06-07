#!/usr/bin/env bash
# cohens-kappa.sh — Cohen's kappa for paired binary labels.
# stdin: JSON array of { "judge": "pass"|"fail", "human": "pass"|"fail" }
# stdout: { n, agreement, kappa }  (kappa null when n==0)
# Degenerate case: when expected agreement pe==1 (all one class) and observed
# agreement po==1, kappa is defined as 1.0 (perfect).
set -euo pipefail
INPUT=$(cat)
jq -e 'type == "array"' >/dev/null <<<"$INPUT" || { echo "cohens-kappa: expected JSON array on stdin" >&2; exit 2; }
jq -n --argjson d "$INPUT" '
  ($d | length) as $n
  | if $n == 0 then { n:0, agreement:null, kappa:null, reason:"empty" }
    else
      ([$d[] | select(.judge == .human)] | length) as $agree
      | ([$d[] | select(.judge == "pass")] | length) as $jp
      | ([$d[] | select(.human == "pass")] | length) as $hp
      | ($n - $jp) as $jf | ($n - $hp) as $hf
      | ($agree / $n) as $po
      | ((($jp/$n)*($hp/$n)) + (($jf/$n)*($hf/$n))) as $pe
      | { n:$n, agreement:$po,
          kappa:(if (1 - $pe) == 0 then (if $po == 1 then 1.0 else 0.0 end)
                 else (($po - $pe) / (1 - $pe)) end) }
    end'
