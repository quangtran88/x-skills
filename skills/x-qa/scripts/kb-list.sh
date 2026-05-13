#!/usr/bin/env bash
# kb-list.sh — tabulate KB contents.
# Usage: kb-list.sh [--cases|--flows|--baselines]
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/lib/kb-common.sh"

SCOPE="all"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cases)     SCOPE="cases"; shift ;;
    --flows)     SCOPE="flows"; shift ;;
    --baselines) SCOPE="baselines"; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

INDEX=$(kb_index_path)
[[ -f "$INDEX" ]] || { echo "✗ no KB at $(kb_root)" >&2; exit 1; }

list_cases() {
  echo "# Cases"
  echo "ID	ENDPOINT	CATEGORY	STREAK	LAST_VERDICT"
  jq -r '.cases | to_entries[] | [.key, .value.endpoint, .value.category, (.value.green_streak // 0), (.value.last_verdict // "")] | @tsv' "$INDEX"
}

list_flows() {
  echo "# Flows"
  echo "ID	CHAIN	STREAK	LAST_VERDICT"
  jq -r '.flows | to_entries[] | [.key, (.value.case_ids | join("→")), (.value.green_streak // 0), (.value.last_verdict // "")] | @tsv' "$INDEX"
}

list_baselines() {
  echo "# Baselines"
  echo "ENDPOINT	SAMPLES	LAST_SEEN"
  jq -r '.baselines | to_entries[] | [.key, (.value.samples // 0), (.value.last_seen_at // "")] | @tsv' "$INDEX"
}

case "$SCOPE" in
  cases)     list_cases ;;
  flows)     list_flows ;;
  baselines) list_baselines ;;
  all)       list_cases; echo; list_flows; echo; list_baselines ;;
esac
