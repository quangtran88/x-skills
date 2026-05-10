#!/usr/bin/env bash
# feature-map-read.sh — query state for resume / monitoring
# Usage: feature-map-read.sh --team-slug <slug> [--filter <jq-expr>]
set -euo pipefail

TEAM_SLUG=""
FILTER="."

while [[ $# -gt 0 ]]; do
  case "$1" in
    --team-slug) TEAM_SLUG="$2"; shift 2 ;;
    --filter) FILTER="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

REPO_ROOT="$(git rev-parse --show-toplevel)"
MAP_PATH="$REPO_ROOT/.x-skills/x-team/teams/$TEAM_SLUG/feature-map.json"
[[ -f "$MAP_PATH" ]] || { echo "REASON=map not found" >&2; exit 2; }

jq "$FILTER" "$MAP_PATH"
