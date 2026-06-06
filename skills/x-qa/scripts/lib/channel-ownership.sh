#!/usr/bin/env bash
# channel-ownership.sh — resolve ownership of a stateful channel's singleton in
# THIS worktree. Reads ONLY <worktree>/.worktree-isolate/feature-overrides.local.json
# (R2: never the global singleton_owners registry). Prints one token to stdout:
#   owned        — singleton state == "enabled" here (won the claim ⇒ owned, per the spec)
#   not-owned    — isolate set up but singleton not enabled (disabled / acknowledged / absent)
#   unverifiable — .worktree-isolate/ absent (isolate not set up; never test stateful blind)
# Usage: channel-ownership.sh --singleton-id <id> --worktree <root>
set -euo pipefail

SINGLETON_ID=""
WORKTREE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --singleton-id) SINGLETON_ID="$2"; shift 2 ;;
    --worktree) WORKTREE="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$SINGLETON_ID" ]] || { echo "REASON=missing --singleton-id" >&2; exit 2; }
[[ -n "$WORKTREE" ]] || { echo "REASON=missing --worktree" >&2; exit 2; }

isolate_dir="$WORKTREE/.worktree-isolate"
overrides="$isolate_dir/feature-overrides.local.json"

# isolate not set up at all → unverifiable (conservative — never test stateful blind)
if [[ ! -d "$isolate_dir" ]]; then
  echo "unverifiable"
  exit 0
fi

# isolate present but overrides file absent → nothing enabled → not-owned
if [[ ! -f "$overrides" ]]; then
  echo "not-owned"
  exit 0
fi

state=$(jq -r --arg id "$SINGLETON_ID" \
  '.overrides[]? | select(.id == $id) | .state' "$overrides" 2>/dev/null | head -n1)

if [[ "$state" == "enabled" ]]; then
  echo "owned"
else
  # disabled / acknowledged / absent entry → not owned here
  echo "not-owned"
fi
