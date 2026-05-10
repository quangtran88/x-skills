#!/usr/bin/env bash
# feature-map-update.sh — update one feature's state OR top-level phase
# Usage:
#   feature-map-update.sh --team-slug <slug> --phase <phase>
#   feature-map-update.sh --team-slug <slug> --task-id <id> [--status <status>] [--attempts <n>] [--qa-add '<json>'] [--blocker '<str>'] [--clear-blocker] [--worktree <abs>] [--worker <name>] [--merged-at <ts>]
set -euo pipefail

TEAM_SLUG=""
PHASE=""
TASK_ID=""
STATUS=""
ATTEMPTS=""
QA_ADD=""
BLOCKER=""
CLEAR_BLOCKER=false
WORKTREE=""
WORKER=""
MERGED_AT=""

# Pre-define tmp/lock-related vars BEFORE trap registration so the EXIT trap
# never references unbound variables under `set -u` if arg-parsing fails early.
tmp=""
LOCK_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --team-slug) TEAM_SLUG="$2"; shift 2 ;;
    --phase) PHASE="$2"; shift 2 ;;
    --task-id) TASK_ID="$2"; shift 2 ;;
    --status) STATUS="$2"; shift 2 ;;
    --attempts) ATTEMPTS="$2"; shift 2 ;;
    --qa-add) QA_ADD="$2"; shift 2 ;;
    --blocker) BLOCKER="$2"; shift 2 ;;
    --clear-blocker) CLEAR_BLOCKER=true; shift ;;
    --worktree) WORKTREE="$2"; shift 2 ;;
    --worker) WORKER="$2"; shift 2 ;;
    --merged-at) MERGED_AT="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

REPO_ROOT="$(git rev-parse --show-toplevel)"
MAP_PATH="$REPO_ROOT/.x-skills/x-team/teams/$TEAM_SLUG/feature-map.json"
[[ -f "$MAP_PATH" ]] || { echo "REASON=map not found: $MAP_PATH" >&2; exit 2; }

# Validate enum-typed args before touching the file
if [[ -n "$ATTEMPTS" ]]; then
  [[ "$ATTEMPTS" =~ ^[0-9]+$ ]] || { echo "REASON=--attempts must be a non-negative integer" >&2; exit 2; }
fi
if [[ -n "$QA_ADD" ]]; then
  jq -e 'type == "object" and has("run_id") and has("verdict") and has("report")' <<<"$QA_ADD" >/dev/null 2>&1 \
    || { echo "REASON=--qa-add must be a JSON object with run_id/verdict/report" >&2; exit 2; }
fi
if [[ -n "$STATUS" ]]; then
  case "$STATUS" in
    pending|in_progress|qa|awaiting_human|blocked|done|failed) ;;
    *) echo "REASON=--status must be one of: pending|in_progress|qa|awaiting_human|blocked|done|failed" >&2; exit 2 ;;
  esac
fi
if [[ -n "$PHASE" ]]; then
  case "$PHASE" in
    decomposing|provisioning|running|finalizing|complete|aborted) ;;
    *) echo "REASON=--phase must be one of: decomposing|provisioning|running|finalizing|complete|aborted" >&2; exit 2 ;;
  esac
fi
if [[ -n "$WORKTREE" ]]; then
  [[ "$WORKTREE" = /* ]] || { echo "REASON=--worktree must be an absolute path" >&2; exit 2; }
  [[ -d "$WORKTREE" ]] || { echo "REASON=--worktree path does not exist: $WORKTREE" >&2; exit 2; }
fi
if [[ -n "$TASK_ID" ]]; then
  jq -e --arg id "$TASK_ID" '.features | map(.task_id) | index($id) != null' "$MAP_PATH" >/dev/null \
    || { echo "REASON=--task-id '$TASK_ID' not found in feature map" >&2; exit 2; }
fi
if [[ -n "$PHASE" && -n "$TASK_ID" ]]; then
  echo "REASON=--phase and --task-id are mutually exclusive" >&2; exit 2
fi

LOCK_DIR="$MAP_PATH.lockd"
tmp="$MAP_PATH.tmp.$$"

# mkdir-based lock works on stock macOS/Linux (no flock dependency).
# Stale lock reclaimed after 600s — covers crashed writers without livelock on real concurrent updates.
# Poll budget is ~700 polls so the 600s reclaim threshold is reachable by any waiter.
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
release_lock() {
  [[ -n "$LOCK_DIR" ]] && rmdir "$LOCK_DIR" 2>/dev/null || true
  [[ -n "$tmp" ]] && rm -f "$tmp" "$tmp.2" 2>/dev/null || true
}

trap release_lock EXIT

acquire_lock
cp "$MAP_PATH" "$tmp"

# Each jq stanza must propagate failure (|| exit 1) — `&& mv` chained under set -e
# does NOT abort on jq failure; it just skips the mv and silently advances to the next stanza.
apply_jq() {
  jq "$@" "$tmp" > "$tmp.2" || { echo "REASON=jq failed: $*" >&2; exit 1; }
  mv "$tmp.2" "$tmp"
}

if [[ -n "$PHASE" ]]; then
  apply_jq --arg p "$PHASE" '.phase = $p'
fi

if [[ -n "$TASK_ID" ]]; then
  if [[ -n "$STATUS" ]]; then
    apply_jq --arg id "$TASK_ID" --arg s "$STATUS" '(.features[] | select(.task_id == $id)).status = $s'
  fi
  if [[ -n "$ATTEMPTS" ]]; then
    apply_jq --arg id "$TASK_ID" --argjson n "$ATTEMPTS" '(.features[] | select(.task_id == $id)).attempts = $n'
  fi
  if [[ -n "$QA_ADD" ]]; then
    apply_jq --arg id "$TASK_ID" --argjson q "$QA_ADD" '(.features[] | select(.task_id == $id)).qa_runs += [$q]'
  fi
  if [[ "$CLEAR_BLOCKER" == true ]]; then
    apply_jq --arg id "$TASK_ID" '(.features[] | select(.task_id == $id)).blocker = null'
  elif [[ -n "$BLOCKER" ]]; then
    apply_jq --arg id "$TASK_ID" --arg b "$BLOCKER" '(.features[] | select(.task_id == $id)).blocker = $b'
  fi
  if [[ -n "$WORKTREE" ]]; then
    apply_jq --arg id "$TASK_ID" --arg w "$WORKTREE" '(.features[] | select(.task_id == $id)).worktree = $w'
  fi
  if [[ -n "$WORKER" ]]; then
    apply_jq --arg id "$TASK_ID" --arg w "$WORKER" '(.features[] | select(.task_id == $id)).worker = $w'
  fi
  if [[ -n "$MERGED_AT" ]]; then
    apply_jq --arg id "$TASK_ID" --arg t "$MERGED_AT" '(.features[] | select(.task_id == $id)).merged_at = $t'
  fi
fi

mv "$tmp" "$MAP_PATH"
echo "✓ feature map updated"
