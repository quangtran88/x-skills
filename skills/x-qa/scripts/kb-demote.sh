#!/usr/bin/env bash
# kb-demote.sh — manually quarantine a promoted case or flow.
# Usage: kb-demote.sh <id> [--reason "..."]
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/lib/kb-common.sh"

ID="${1:-}"
REASON="manual"
shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --reason) REASON="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done
[[ -z "$ID" ]] && { echo "Usage: kb-demote.sh <id> [--reason ...]" >&2; exit 2; }

INDEX=$(kb_index_path)
[[ -f "$INDEX" ]] || { echo "✗ no KB at $(kb_root)" >&2; exit 1; }

now=$(kb_now)
in_cases=$(jq -r --arg id "$ID" '.cases | has($id)' "$INDEX")
in_flows=$(jq -r --arg id "$ID" '.flows | has($id)' "$INDEX")
[[ "$in_cases" != "true" && "$in_flows" != "true" ]] && { echo "✗ $ID not in index" >&2; exit 1; }

key="cases"; [[ "$in_flows" == "true" ]] && key="flows"

_apply() {
  local tmp; tmp=$(mktemp)
  jq --arg id "$ID" --arg now "$now" --arg reason "$REASON" \
    ".$key[\$id].quarantined = true | .$key[\$id].demoted_at = \$now | .$key[\$id].demoted_reason = \$reason" \
    "$INDEX" > "$tmp"
  mv "$tmp" "$INDEX"
}
kb_with_lock "$INDEX" _apply

echo "✓ demoted $key.$ID — $REASON"
