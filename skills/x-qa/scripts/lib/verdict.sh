#!/usr/bin/env bash
set -euo pipefail
INPUT=$(cat)

results='[]'
verdict='pass'

LEN=$(echo "$INPUT" | jq '.gates | length')
for i in $(seq 0 $((LEN - 1))); do
  G=$(echo "$INPUT" | jq -c ".gates[$i]")
  METRIC=$(echo "$G" | jq -r '.metric')
  THRESHOLD=$(echo "$G" | jq -r '.threshold // empty')
  MAX=$(echo "$G" | jq -r '.max // empty')
  BLOCKING=$(echo "$G" | jq -r '.blocking // false')

  # Reject syntactically dangerous metric names (defense-in-depth around jq path).
  if ! [[ "$METRIC" =~ ^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)*$ ]]; then
    results=$(echo "$results" | jq --argjson g "$G" --arg s "unmeasured" \
      '. + [{gate:$g, value:null, status:$s, reason:"invalid metric name"}]')
    continue
  fi

  # Use getpath so the dotted path is parsed once and safely.
  VALUE=$(echo "$INPUT" | jq -r --arg m "$METRIC" '.metrics | getpath($m | split(".")) // empty')

  # Missing OR non-numeric → unmeasured (never crash, never silently pass).
  if [[ -z "$VALUE" || "$VALUE" == "null" ]] || ! [[ "$VALUE" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
    results=$(echo "$results" | jq --argjson g "$G" --arg s "unmeasured" \
      '. + [{gate:$g, value:null, status:$s, reason:"metric missing or non-numeric"}]')
    continue
  fi

  STATUS='pass'
  if [[ -n "$THRESHOLD" ]] && (( $(echo "$VALUE < $THRESHOLD" | bc -l) )); then
    if [[ "$BLOCKING" == "true" ]]; then
      STATUS='fail'
    else
      STATUS='warn'
    fi
  elif [[ -n "$MAX" ]] && (( $(echo "$VALUE > $MAX" | bc -l) )); then
    if [[ "$BLOCKING" == "true" ]]; then
      STATUS='fail'
    else
      STATUS='warn'
    fi
  fi

  # Pass VALUE as a string and coerce inside jq — never as --argjson (which would
  # explode on anything non-JSON).
  results=$(echo "$results" | jq --argjson g "$G" --arg v "$VALUE" --arg s "$STATUS" \
    '. + [{gate:$g, value:($v | tonumber), status:$s}]')

  # Use if blocks (not && chains) to avoid set -e false-exit on comparison failure.
  if [[ "$STATUS" == "fail" ]]; then
    verdict='fail'
  fi
  if [[ "$STATUS" == "warn" && "$verdict" == "pass" ]]; then
    verdict='warn'
  fi
done

jq -n --arg v "$verdict" --argjson r "$results" '{verdict:$v, gate_results:$r}'
