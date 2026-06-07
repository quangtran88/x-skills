#!/usr/bin/env bash
# channel-select.sh — stateless-first / stateful-aware channel selection (Phase 4).
# Emits {"tested":[<name>,...],"skipped":[{"name","reason"}]} to stdout.
#
# Decision table (spec §Component 2):
#   singleton_id == null .............. stateless → tested (default QA target)
#   stateful + owned + driver==http ... tested (R1 carve-out: drive the owned http singleton)
#   stateful + owned + chat driver .... skip  stateful-owned-chat-driver-deferred
#   stateful + not-owned .............. skip  stateful-not-owned
#   stateful + unverifiable ........... skip  stateful-unverifiable
#   no channels[] ..................... implicit primary http channel tested (back-compat)
# Ownership comes from channel-ownership.sh (reads only feature-overrides.local.json, R2).
set -euo pipefail

LIB_DIR="$(cd "$(dirname "$0")" && pwd)"
OWN="$LIB_DIR/channel-ownership.sh"

PROFILE=""
WORKTREE=""
ONLY_CHANNEL=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --worktree) WORKTREE="$2"; shift 2 ;;
    --channel) ONLY_CHANNEL="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done
[[ -f "$PROFILE" ]] || { echo "REASON=profile not found: $PROFILE" >&2; exit 2; }
[[ -n "$WORKTREE" ]] || WORKTREE="$(pwd)"

n_channels=$(jq -r '.channels // [] | length' "$PROFILE")

# Back-compat: no channels[] → test the implicit primary http channel, skip nothing.
if [[ "$n_channels" -eq 0 ]]; then
  primary=$(jq -r '.primary_entry_point' "$PROFILE")
  jq -nc --arg p "$primary" '{tested:[$p], skipped:[]}'
  exit 0
fi

# Select the channel set: all channels, or just the named one when --channel given.
if [[ -n "$ONLY_CHANNEL" ]]; then
  channels=$(jq -c --arg n "$ONLY_CHANNEL" '[.channels[] | select(.name == $n)]' "$PROFILE")
  [[ "$(jq 'length' <<<"$channels")" -gt 0 ]] || { echo "REASON=channel '$ONLY_CHANNEL' not in profile" >&2; exit 2; }
else
  channels=$(jq -c '.channels' "$PROFILE")
fi

tested='[]'
skipped='[]'
while IFS= read -r ch; do
  name=$(jq -r '.name' <<<"$ch")
  sid=$(jq -r '.singleton_id // "null"' <<<"$ch")
  driver=$(jq -r '.driver' <<<"$ch")

  if [[ "$sid" == "null" ]]; then
    tested=$(jq -c --arg n "$name" '. + [$n]' <<<"$tested")
    continue
  fi

  ownership=$(bash "$OWN" --singleton-id "$sid" --worktree "$WORKTREE")
  case "$ownership" in
    owned)
      if [[ "$driver" == "http" ]]; then
        tested=$(jq -c --arg n "$name" '. + [$n]' <<<"$tested")
      else
        skipped=$(jq -c --arg n "$name" --arg r "stateful-owned-chat-driver-deferred" \
          '. + [{name:$n, reason:$r}]' <<<"$skipped")
      fi
      ;;
    not-owned)
      skipped=$(jq -c --arg n "$name" --arg r "stateful-not-owned" \
        '. + [{name:$n, reason:$r}]' <<<"$skipped")
      ;;
    unverifiable)
      skipped=$(jq -c --arg n "$name" --arg r "stateful-unverifiable" \
        '. + [{name:$n, reason:$r}]' <<<"$skipped")
      ;;
  esac
done < <(jq -c '.[]' <<<"$channels")

jq -nc --argjson t "$tested" --argjson s "$skipped" '{tested:$t, skipped:$s}'
