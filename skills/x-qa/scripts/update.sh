#!/usr/bin/env bash
# update.sh — write a reconciled profile from an LLM-constructed diff
# Usage: update.sh --reconciled-json <path> [--allow-overwrite-user-edits]
set -euo pipefail

PROFILE_PATH="$(git rev-parse --show-toplevel)/.x-skills/x-qa/profile.json"
RECONCILED=""
ALLOW_OVERWRITE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --reconciled-json) RECONCILED="$2"; shift 2 ;;
    --allow-overwrite-user-edits) ALLOW_OVERWRITE=true; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -f "$PROFILE_PATH" ]] || { echo "✗ update FAILED REASON=no existing profile; run init first" >&2; exit 2; }
[[ -f "$RECONCILED" ]] || { echo "✗ update FAILED REASON=missing --reconciled-json input" >&2; exit 2; }

# Canonicalize JSON (recursive key sort) before equality check so that key-order drift
# from regenerated profiles does not false-positive trigger user-edit protection.
canon='walk(if type=="object" then to_entries|sort_by(.key)|from_entries else . end)'

if [[ "$ALLOW_OVERWRITE" != true ]]; then
  user_edited_changed=$(jq -n \
    --slurpfile old "$PROFILE_PATH" \
    --slurpfile new "$RECONCILED" \
    "[\$old[0].entry_points[] as \$oe | \$new[0].entry_points[] as \$ne |
      select(\$oe.name == \$ne.name and \$oe.auto_managed == false and
             ((\$oe | $canon) != (\$ne | $canon)))] | length")
  [[ "$user_edited_changed" == "0" ]] || { echo "✗ update FAILED REASON=$user_edited_changed user-edited entries would be overwritten; use --allow-overwrite-user-edits" >&2; exit 3; }
  channel_edited_changed=$(jq -n \
    --slurpfile old "$PROFILE_PATH" \
    --slurpfile new "$RECONCILED" \
    "[\$old[0].channels[]? | select(.auto_managed == false) |
      . as \$oc |
      ((\$new[0].channels[]? | select(.name == \$oc.name)) // null) as \$nc |
      select(\$nc == null or ((\$oc | $canon) != (\$nc | $canon)))] | length")
  [[ "$channel_edited_changed" == "0" ]] || { echo "✗ update FAILED REASON=$channel_edited_changed user-edited channels would be changed/removed; use --allow-overwrite-user-edits" >&2; exit 3; }
fi

# Bump version + timestamps
final=$(jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '. + { generated_at: $ts, generated_by: "x-qa-update", version: ((.version // "1.0.0") | split(".") | .[2] = ((.[2] | tonumber + 1) | tostring) | join(".")) }' "$RECONCILED")

echo "$final" > "$PROFILE_PATH"
MEM="$(dirname "$PROFILE_PATH")/QA_MEMORY.md"
if [[ -f "$MEM" ]] && [[ "$PROFILE_PATH" -nt "$MEM" ]]; then
  echo "WARN=QA_MEMORY.md older than profile; re-run the init interview to refresh narrative memory" >&2
fi
echo "✓ x-qa update complete"
echo "PROFILE_PATH=$PROFILE_PATH"
echo "VERSION=$(jq -r '.version' "$PROFILE_PATH")"
