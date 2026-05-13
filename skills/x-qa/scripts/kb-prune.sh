#!/usr/bin/env bash
# kb-prune.sh — reconcile filesystem vs index.
# Usage:
#   kb-prune.sh --orphans          (list mismatches, no writes)
#   kb-prune.sh --orphans --apply  (remove orphan files / dangling index entries)
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/lib/kb-common.sh"

MODE=""
APPLY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --orphans) MODE="orphans"; shift ;;
    --apply)   APPLY=true; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done
[[ "$MODE" == "orphans" ]] || { echo "Usage: kb-prune.sh --orphans [--apply]" >&2; exit 2; }

INDEX=$(kb_index_path)
[[ -f "$INDEX" ]] || { echo "✗ no KB at $(kb_root)" >&2; exit 1; }

echo "# Orphan files (on disk, not in index):"
for dir in cases flows baselines; do
  while IFS= read -r f; do
    rel="${f#$(kb_root)/}"
    in_idx=$(jq -r --arg p "$rel" '
      (.cases | to_entries | map(select(.value.file == $p)) | length) +
      (.flows | to_entries | map(select(.value.file == $p)) | length) +
      (.baselines | to_entries | map(select(.value.file == $p)) | length)
    ' "$INDEX")
    if [[ "$in_idx" == "0" ]]; then
      echo "$rel"
      if [[ "$APPLY" == true ]]; then rm "$f"; echo "  rm $f"; fi
    fi
  done < <(find "$(kb_root)/$dir" -maxdepth 1 -type f \( -name "*.yaml" -o -name "*.yml" -o -name "*.json" \) 2>/dev/null || true)
done

echo
echo "# Dangling index entries (in index, not on disk):"
for key in cases flows baselines; do
  while IFS=$'\t' read -r id rel; do
    [[ -f "$(kb_root)/$rel" ]] || {
      echo "$key.$id → $rel"
      if [[ "$APPLY" == true ]]; then
        tmp=$(mktemp)
        jq --arg id "$id" "del(.$key[\$id])" "$INDEX" > "$tmp"
        mv "$tmp" "$INDEX"
      fi
    }
  done < <(jq -r ".$key | to_entries[] | [.key, .value.file] | @tsv" "$INDEX")
done
