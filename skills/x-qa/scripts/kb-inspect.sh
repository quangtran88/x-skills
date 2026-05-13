#!/usr/bin/env bash
# kb-inspect.sh — pretty-print a KB case/flow + recent ledger history.
# Usage: kb-inspect.sh <case-or-flow-id>
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/lib/kb-common.sh"

ID="${1:-}"
[[ -z "$ID" ]] && { echo "Usage: kb-inspect.sh <id>" >&2; exit 2; }

INDEX=$(kb_index_path)
[[ -f "$INDEX" ]] || { echo "✗ no KB at $(kb_root)" >&2; exit 1; }

# Try case first, then flow.
kind=""
entry=$(jq --arg id "$ID" '.cases[$id] // empty' "$INDEX")
[[ -n "$entry" ]] && kind="case"
if [[ -z "$entry" ]]; then
  entry=$(jq --arg id "$ID" '.flows[$id] // empty' "$INDEX")
  [[ -n "$entry" ]] && kind="flow"
fi
[[ -z "$entry" ]] && { echo "✗ $ID not found in index.cases or index.flows" >&2; exit 1; }

echo "=== $kind: $ID ==="
echo "$entry" | jq .

file_rel=$(jq -r '.file' <<<"$entry")
body_path="$(kb_root)/$file_rel"
echo
echo "=== body ($file_rel) ==="
if [[ -f "$body_path" ]]; then
  cat "$body_path"
else
  echo "✗ body missing on disk"
fi

echo
echo "=== ledger history (last 20 mentions) ==="
LEDGER=$(kb_ledger_path)
if [[ -s "$LEDGER" ]]; then
  jq -r --arg id "$ID" '
    select(.cases[]?.id == $id or (.flow_observations[]?.chain | index($id)))
    | "\(.run_id)\t\(.verdict)\tcase=\([.cases[]? | select(.id==$id) | .verdict] | join(","))"
  ' "$LEDGER" | tail -20
else
  echo "(empty ledger)"
fi
