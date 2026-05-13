#!/usr/bin/env bash
# kb-prune.sh — reconcile filesystem vs index, age out stale baselines, trim ledger.
# Usage:
#   kb-prune.sh --orphans                          (list mismatches, no writes)
#   kb-prune.sh --orphans --apply                  (remove orphan files/index entries)
#   kb-prune.sh --baselines --older-than <Nd>      (drop baselines with last_seen older than N days)
#   kb-prune.sh --ledger                           (trim ledger to $X_QA_KB_LEDGER_RETAIN lines)
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/lib/kb-common.sh"

MODE=""
APPLY=false
OLDER_THAN=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --orphans)    MODE="orphans"; shift ;;
    --baselines)  MODE="baselines"; shift ;;
    --ledger)     MODE="ledger"; shift ;;
    --apply)      APPLY=true; shift ;;
    --older-than) OLDER_THAN="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done
[[ -z "$MODE" ]] && { echo "Usage: kb-prune.sh --orphans|--baselines|--ledger [opts]" >&2; exit 2; }

INDEX=$(kb_index_path)
[[ -f "$INDEX" ]] || { echo "✗ no KB at $(kb_root)" >&2; exit 1; }

case "$MODE" in
  orphans)
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
    ;;

  baselines)
    [[ -z "$OLDER_THAN" ]] && { echo "--baselines requires --older-than <Nd>" >&2; exit 2; }
    days="${OLDER_THAN%d}"
    [[ "$days" =~ ^[0-9]+$ ]] || { echo "bad --older-than format: $OLDER_THAN (expected e.g. 90d)" >&2; exit 2; }
    cutoff=$(python3 -c "from datetime import datetime,timedelta,timezone; print((datetime.now(timezone.utc)-timedelta(days=$days)).strftime('%Y-%m-%dT%H:%M:%SZ'))")
    echo "# Baselines untouched since $cutoff:"
    while IFS=$'\t' read -r ep rel last_seen; do
      if [[ "$last_seen" < "$cutoff" ]]; then
        echo "$ep (last_seen=$last_seen)"
        if [[ "$APPLY" == true ]]; then
          rm -f "$(kb_root)/$rel"
          tmp=$(mktemp)
          jq --arg id "$ep" 'del(.baselines[$id])' "$INDEX" > "$tmp"
          mv "$tmp" "$INDEX"
        fi
      fi
    done < <(jq -r '.baselines | to_entries[] | [.key, .value.file, (.value.last_seen_at // "1970-01-01T00:00:00Z")] | @tsv' "$INDEX")
    ;;

  ledger)
    LEDGER=$(kb_ledger_path)
    [[ -s "$LEDGER" ]] || { echo "(empty ledger)"; exit 0; }
    total=$(wc -l < "$LEDGER" | tr -d ' ')
    if (( total > X_QA_KB_LEDGER_RETAIN )); then
      tmp=$(mktemp)
      tail -n "$X_QA_KB_LEDGER_RETAIN" "$LEDGER" > "$tmp"
      mv "$tmp" "$LEDGER"
      echo "✓ ledger trimmed: $total → $X_QA_KB_LEDGER_RETAIN"
    else
      echo "✓ ledger within budget: $total ≤ $X_QA_KB_LEDGER_RETAIN"
    fi
    ;;
esac
