#!/usr/bin/env bash
# feature-map-init.sh — write initial state file for an x-team run
# Usage: feature-map-init.sh --team-slug <slug> --request <str> --base <branch> --features-json <path>
set -euo pipefail

TEAM_SLUG=""
REQUEST=""
BASE="main"
FEATURES_JSON=""
AUTO_MERGE=false
MAX_FEATURES=3

while [[ $# -gt 0 ]]; do
  case "$1" in
    --team-slug) TEAM_SLUG="$2"; shift 2 ;;
    --request) REQUEST="$2"; shift 2 ;;
    --base) BASE="$2"; shift 2 ;;
    --features-json) FEATURES_JSON="$2"; shift 2 ;;
    --auto-merge) AUTO_MERGE=true; shift ;;
    --max-features) MAX_FEATURES="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

REPO_ROOT="$(git rev-parse --show-toplevel)"
TEAM_DIR="$REPO_ROOT/.x-skills/x-team/teams/$TEAM_SLUG"
MAP_PATH="$TEAM_DIR/feature-map.json"
LOCK_DIR="$MAP_PATH.lockd"

mkdir -p "$TEAM_DIR"

# Validate features-json is an array (must be done BEFORE slurpfile)
[[ -f "$FEATURES_JSON" ]] || { echo "REASON=features-json not found: $FEATURES_JSON" >&2; exit 2; }
jq -e 'type == "array"' "$FEATURES_JSON" >/dev/null \
  || { echo "REASON=features-json must be a JSON array" >&2; exit 2; }

# Acquire same lockfile that update.sh uses (mkdir is portable atomic-create).
# Stale-lock handling: if lock dir is older than 600s, assume crashed writer and reclaim.
acquire_lock() {
  local tries=0
  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    if [[ -d "$LOCK_DIR" ]]; then
      local age
      age=$(( $(date +%s) - $(stat -f %m "$LOCK_DIR" 2>/dev/null || stat -c %Y "$LOCK_DIR") ))
      if [[ $age -gt 600 ]]; then
        rmdir "$LOCK_DIR" 2>/dev/null || true
        continue
      fi
    fi
    tries=$((tries + 1))
    [[ $tries -gt 700 ]] && { echo "REASON=could not acquire lock after ~700s" >&2; exit 2; }
    sleep 1
  done
}
release_lock() { rmdir "$LOCK_DIR" 2>/dev/null || true; }
trap release_lock EXIT

acquire_lock

# Atomic write: jq to tmp in same dir, then mv (rename is atomic on POSIX).
tmp="$MAP_PATH.tmp.$$"
jq -n \
  --arg team "$TEAM_SLUG" \
  --arg req "$REQUEST" \
  --arg base "$BASE" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson am "$AUTO_MERGE" \
  --argjson mf "$MAX_FEATURES" \
  --slurpfile features "$FEATURES_JSON" \
  '{
    schema: 1,
    team_name: $team,
    created_at: $ts,
    request: $req,
    base_branch: $base,
    auto_merge: $am,
    max_features: $mf,
    phase: "decomposing",
    features: ($features[0])
  }' > "$tmp"
mv "$tmp" "$MAP_PATH"

echo "✓ feature map initialized"
echo "MAP_PATH=$MAP_PATH"
