#!/usr/bin/env bash
# kb-import.sh — merge a foreign KB tarball into the current KB.
# Usage: kb-import.sh <in.tgz> [--rename-collisions]
# Behaviour:
#   - Refuses on case/flow ID collisions unless --rename-collisions is given.
#   - With --rename-collisions, suffixes incoming IDs with -import-N.
#   - Always merges baselines (per-endpoint), summing samples.
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/lib/kb-common.sh"

IN=""
RENAME=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --rename-collisions) RENAME=true; shift ;;
    *) IN="$1"; shift ;;
  esac
done
[[ -z "$IN" || ! -f "$IN" ]] && { echo "Usage: kb-import.sh <in.tgz> [--rename-collisions]" >&2; exit 2; }

kb_ensure_layout
ROOT=$(kb_root)
INDEX=$(kb_index_path)

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
tar -C "$work" -xzf "$IN"
[[ -f "$work/kb/index.json" ]] || { echo "✗ tarball missing kb/index.json" >&2; exit 1; }
kb_assert_schema "$work/kb/index.json"

collisions=$(jq -r --slurpfile cur "$INDEX" '
  ($cur[0].cases // {}) as $c
  | (.cases // {}) | to_entries | map(select($c[.key])) | length
' "$work/kb/index.json")

if (( collisions > 0 )) && [[ "$RENAME" != true ]]; then
  echo "✗ $collisions case ID collisions. Re-run with --rename-collisions to suffix them." >&2
  exit 1
fi

# Merge cases
while IFS= read -r id; do
  src_file="$work/kb/$(jq -r --arg id "$id" '.cases[$id].file' "$work/kb/index.json")"
  exists=$(jq -r --arg id "$id" '.cases | has($id)' "$INDEX")
  dest_id="$id"
  if [[ "$exists" == "true" && "$RENAME" == true ]]; then
    n=2
    while [[ "$(jq -r --arg id "${id}-import-$n" '.cases | has($id)' "$INDEX")" == "true" ]]; do n=$((n+1)); done
    dest_id="${id}-import-$n"
  fi
  cp "$src_file" "$ROOT/cases/$dest_id.yaml"
  entry=$(jq --arg id "$id" '.cases[$id]' "$work/kb/index.json")
  tmp=$(mktemp)
  jq --arg id "$dest_id" --argjson v "$entry" \
    '.cases[$id] = ($v | .file = "cases/" + $id + ".yaml")' \
    "$INDEX" > "$tmp"
  mv "$tmp" "$INDEX"
done < <(jq -r '.cases | keys[]' "$work/kb/index.json")

# Merge flows analogously
while IFS= read -r id; do
  src_file="$work/kb/$(jq -r --arg id "$id" '.flows[$id].file' "$work/kb/index.json")"
  exists=$(jq -r --arg id "$id" '.flows | has($id)' "$INDEX")
  dest_id="$id"
  if [[ "$exists" == "true" && "$RENAME" == true ]]; then
    n=2
    while [[ "$(jq -r --arg id "${id}-import-$n" '.flows | has($id)' "$INDEX")" == "true" ]]; do n=$((n+1)); done
    dest_id="${id}-import-$n"
  fi
  cp "$src_file" "$ROOT/flows/$dest_id.yaml"
  entry=$(jq --arg id "$id" '.flows[$id]' "$work/kb/index.json")
  tmp=$(mktemp)
  jq --arg id "$dest_id" --argjson v "$entry" \
    '.flows[$id] = ($v | .file = "flows/" + $id + ".yaml")' \
    "$INDEX" > "$tmp"
  mv "$tmp" "$INDEX"
done < <(jq -r '.flows | keys[]' "$work/kb/index.json")

# Merge baselines — sum samples, keep most recent last_seen_at, additive shape union.
while IFS= read -r ep; do
  src_file="$work/kb/$(jq -r --arg id "$ep" '.baselines[$id].file' "$work/kb/index.json")"
  slug=$(kb_endpoint_slug "$ep")
  dest_file="$ROOT/baselines/$slug.json"
  if [[ -f "$dest_file" ]]; then
    tmp=$(mktemp)
    jq -s '
      (.[0].samples // 0) as $sa
      | (.[1].samples // 0) as $sb
      | .[0] * .[1]
      | .samples = ($sa + $sb)
      | .last_seen_at = ([.[0].last_seen_at, .[1].last_seen_at] | max)
    ' "$dest_file" "$src_file" > "$tmp"
    mv "$tmp" "$dest_file"
  else
    cp "$src_file" "$dest_file"
  fi
  entry=$(jq --arg id "$ep" '.baselines[$id]' "$work/kb/index.json")
  tmp=$(mktemp)
  jq --arg id "$ep" --argjson v "$entry" \
    '.baselines[$id] = ($v | .file = "baselines/' "$slug" '.json")' \
    "$INDEX" > "$tmp" || jq --arg id "$ep" --argjson v "$entry" --arg slug "$slug" \
       '.baselines[$id] = ($v | .file = ("baselines/" + $slug + ".json"))' "$INDEX" > "$tmp"
  mv "$tmp" "$INDEX"
done < <(jq -r '.baselines | keys[]?' "$work/kb/index.json")

echo "✓ kb-import: merged from $IN"
