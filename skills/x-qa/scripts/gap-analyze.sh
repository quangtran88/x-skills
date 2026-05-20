#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/lib/kb-common.sh"

STALENESS_DAYS=7
SCOPE_FILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --staleness-days) STALENESS_DAYS="$2"; shift 2 ;;
    --scope-file)     SCOPE_FILE="$2";     shift 2 ;;
    *) shift ;;
  esac
done

KB_ROOT=$(kb_root)
INDEX="$KB_ROOT/index.json"
[[ -f "$INDEX" ]] || { echo '{"schema":1,"gaps":{}}'; exit 0; }

# Build scope endpoint set (empty = no filter).
SCOPE_SET=""
if [[ -n "$SCOPE_FILE" && -f "$SCOPE_FILE" ]]; then
  SCOPE_SET=$(jq -r '
    (.touched_endpoints // [])
    | map(if type=="object" then .endpoint else . end)
    | unique | .[]' "$SCOPE_FILE" | sort -u)
fi

CUTOFF=$(($(date +%s) - STALENESS_DAYS * 86400))

UNTESTED='[]'; STALE='[]'; FAILURE='[]'; REGRESSION='[]'

# Iterate (signature, endpoint) pairs so we can filter by scope.
while IFS=$'\t' read -r SIG ENDPOINT; do
  [[ -z "$SIG" ]] && continue
  if [[ -n "$SCOPE_SET" ]]; then
    grep -qxF "$ENDPOINT" <<<"$SCOPE_SET" || continue
  fi
  SLUG=$(kb_signature_slug "$SIG")
  HIST="$KB_ROOT/history/$SLUG.jsonl"
  if [[ ! -f "$HIST" ]] || [[ ! -s "$HIST" ]]; then
    UNTESTED=$(echo "$UNTESTED" | jq --arg s "$SIG" '. + [{signature:$s}]')
    continue
  fi
  # Read last line under shared lock to avoid partial-write reads.
  if command -v flock >/dev/null 2>&1; then
    LAST=$(flock -s "$HIST" tail -1 "$HIST")
  else
    LAST=$(tail -1 "$HIST")
  fi
  echo "$LAST" | jq -e . >/dev/null 2>&1 || {
    echo "gap-analyze: skipping $SIG — corrupt history tail" >&2
    continue
  }
  LAST_TS=$(echo "$LAST" | jq -r '.timestamp // empty')
  LAST_RESULT=$(echo "$LAST" | jq -r '.result // empty')
  [[ -z "$LAST_TS" || -z "$LAST_RESULT" ]] && continue

  LAST_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$LAST_TS" +%s 2>/dev/null \
            || date -d "$LAST_TS" +%s 2>/dev/null \
            || echo "")
  if [[ -z "$LAST_EPOCH" || ! "$LAST_EPOCH" =~ ^[0-9]+$ ]]; then
    echo "gap-analyze: skipping $SIG — unparseable timestamp $LAST_TS" >&2
    continue
  fi

  if [[ "$LAST_RESULT" == "fail" || "$LAST_RESULT" == "error" ]]; then
    FAILURE=$(echo "$FAILURE" | jq --arg s "$SIG" --argjson l "$LAST" '. + [{signature:$s, last:$l}]')
    if [[ $(wc -l < "$HIST") -ge 2 ]]; then
      if command -v flock >/dev/null 2>&1; then
        PREV=$(flock -s "$HIST" tail -2 "$HIST" | head -1)
      else
        PREV=$(tail -2 "$HIST" | head -1)
      fi
      if echo "$PREV" | jq -e . >/dev/null 2>&1 && [[ $(echo "$PREV" | jq -r '.result // empty') == "pass" ]]; then
        REGRESSION=$(echo "$REGRESSION" | jq --arg s "$SIG" '. + [{signature:$s}]')
      fi
    fi
  elif [[ "$LAST_EPOCH" -lt "$CUTOFF" ]]; then
    DAYS_OLD=$(( ($(date +%s) - LAST_EPOCH) / 86400 ))
    STALE=$(echo "$STALE" | jq --arg s "$SIG" --argjson d "$DAYS_OLD" '. + [{signature:$s, days_old:$d}]')
  fi
done < <(jq -r '.cases | to_entries[] | [.value.coverage_signature // empty, .value.endpoint // empty] | @tsv' "$INDEX")

jq -n \
  --argjson u "$UNTESTED" --argjson s "$STALE" --argjson f "$FAILURE" --argjson r "$REGRESSION" \
  --argjson sd "$STALENESS_DAYS" \
  '{schema:1, staleness_days:$sd,
    gaps:{untested:$u, stale:$s, recent_failure:$f, regression:$r}}'
