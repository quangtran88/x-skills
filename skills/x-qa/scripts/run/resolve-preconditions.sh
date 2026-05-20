#!/usr/bin/env bash
set -euo pipefail
CASE_ID="$1"
KB=".x-skills/x-qa/kb"
INDEX="$KB/index.json"
DEPTH_CAP=4

# Visited set as a colon-delimited string. Bash arrays don't pass cleanly
# through recursion, so we serialize.
resolve() {
  local cid="$1" depth="$2" visited="$3"
  if [[ "$depth" -gt "$DEPTH_CAP" ]]; then
    echo "precondition depth > $DEPTH_CAP starting at $CASE_ID" >&2; exit 1
  fi
  if [[ ":$visited:" == *":$cid:"* ]]; then
    # Reconstruct the cycle path for a useful error.
    echo "precondition cycle detected: ${visited//:/ → } → $cid" >&2; exit 1
  fi
  visited="$visited:$cid"

  local pre file
  pre=$(jq -r --arg c "$cid" '.cases[$c].precondition_case_id // empty' "$INDEX")
  if [[ -n "$pre" ]]; then
    resolve "$pre" $((depth + 1)) "$visited"
  fi
  file=$(jq -r --arg c "$cid" '.cases[$c].file' "$INDEX")
  # KB case files are YAML — convert to JSON before jq selects steps.
  yq eval -o=json '.steps' "$KB/$file" | jq -c '.[]'
}

{ resolve "$CASE_ID" 0 ""; } | jq -s '.'
