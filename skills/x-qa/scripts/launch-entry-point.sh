#!/usr/bin/env bash
# launch-entry-point.sh — start a service by entry-point name from profile
# Usage: launch-entry-point.sh --name <ep-name> [--profile <path>] [--worktree <path>] [--trust-profile]
# Emits: BASE_URL=<resolved-url> on stdout; non-zero exit on failure.
set -euo pipefail

PROFILE_PATH=""
EP_NAME=""
WORKTREE_PATH=""
TRUST_PROFILE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) EP_NAME="$2"; shift 2 ;;
    --profile) PROFILE_PATH="$2"; shift 2 ;;
    --worktree) WORKTREE_PATH="$2"; shift 2 ;;
    --trust-profile) TRUST_PROFILE=true; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

REPO_ROOT="$(git rev-parse --show-toplevel)"
[[ -z "$PROFILE_PATH" ]] && PROFILE_PATH="$REPO_ROOT/.x-skills/x-qa/profile.json"
[[ -z "$WORKTREE_PATH" ]] && WORKTREE_PATH="$(pwd)"

# Trust scope: shared across all linked worktrees of the same repo. git-common-dir
# resolves to the main checkout's .git for both main and linked worktrees, so its
# parent is the stable per-repo identifier. Without this, every linked worktree
# created by x-team gets a fresh trust key and exit-4 fails before any test runs.
TRUST_SCOPE_ROOT="$(cd "$(git rev-parse --git-common-dir)/.." 2>/dev/null && pwd -P)" \
  || TRUST_SCOPE_ROOT="$(cd "$REPO_ROOT" && pwd -P)"

ep=$(jq -r --arg n "$EP_NAME" '.entry_points[] | select(.name == $n)' "$PROFILE_PATH")
[[ -z "$ep" ]] && { echo "✗ launch FAILED REASON=entry point '$EP_NAME' not in profile" >&2; exit 2; }

# D5 enforcement: v1 only launches type=http
ep_type=$(jq -r '.type' <<<"$ep")
if [[ "$ep_type" != "http" ]]; then
  echo "✗ launch FAILED" >&2
  echo "REASON=type '$ep_type' not supported in v1; only http (D5)" >&2
  exit 2
fi

kind=$(jq -r '.launch.kind' <<<"$ep")
command=$(jq -r '.launch.command' <<<"$ep")
working_dir=$(jq -r '.launch.working_dir // "."' <<<"$ep")
uses_isolate=$(jq -r '.launch.uses_isolate_profile // false' <<<"$ep")

case "$kind" in
  docker-compose|command|npm-script|makefile-target) ;;
  *) echo "✗ launch FAILED REASON=unknown launch.kind '$kind'" >&2; exit 2 ;;
esac

# Path-traversal guard: working_dir must resolve under repo_root
target_dir=$(cd "$WORKTREE_PATH" && cd "$working_dir" 2>/dev/null && pwd -P) \
  || { echo "✗ launch FAILED REASON=working_dir '$working_dir' does not resolve" >&2; exit 2; }
canonical_root=$(cd "$REPO_ROOT" && pwd -P)
case "$target_dir/" in
  "$canonical_root"/*) ;;
  *) echo "✗ launch FAILED REASON=working_dir '$working_dir' escapes repo_root" >&2; exit 2 ;;
esac

# TOFU launch-command consent (mitigates checked-in profile RCE)
trust_db="${XDG_CONFIG_HOME:-$HOME/.config}/x-skills/x-qa/trusted-profiles.json"
mkdir -p "$(dirname "$trust_db")"
[[ -f "$trust_db" ]] || echo '{}' > "$trust_db"
profile_hash=$(shasum -a 256 "$PROFILE_PATH" | awk '{print $1}')
trust_key="${TRUST_SCOPE_ROOT}::${EP_NAME}::${profile_hash}"
already_trusted=$(jq --arg k "$trust_key" -r 'has($k) | tostring' "$trust_db")

if [[ "$already_trusted" != "true" && "$TRUST_PROFILE" != true ]]; then
  echo "✗ launch FAILED" >&2
  echo "REASON=launch.command for entry-point '$EP_NAME' is not trusted on this machine." >&2
  echo "  command: $command" >&2
  echo "  working_dir: $target_dir" >&2
  echo "  profile_hash: $profile_hash" >&2
  echo "Re-run with --trust-profile after reviewing the command." >&2
  exit 4
fi

# Persist trust on this run (so non-interactive CI does not need a re-confirm next time)
if [[ "$TRUST_PROFILE" == true ]]; then
  # mkdir-based lock — atomic across N parallel x-qa runs in sibling worktrees.
  # Without this, concurrent jq read + mv pairs lose-write each other's entries.
  lock_dir="${trust_db}.lock"
  acquired=false
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    if mkdir "$lock_dir" 2>/dev/null; then
      acquired=true
      trap 'rmdir "$lock_dir" 2>/dev/null || true' EXIT
      break
    fi
    sleep 0.2
  done
  if [[ "$acquired" != true ]]; then
    echo "✗ launch FAILED" >&2
    echo "REASON=could not acquire trust DB lock at $lock_dir after 2s" >&2
    exit 5
  fi
  tmp=$(mktemp)
  jq --arg k "$trust_key" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
     '. + {($k): {trusted_at: $ts}}' "$trust_db" > "$tmp" && mv "$tmp" "$trust_db"
  rmdir "$lock_dir" 2>/dev/null || true
  trap - EXIT
fi

# Execute via `bash -c` (no eval — no double parsing, no current-env re-expansion of metachars)
( cd "$target_dir" && bash -c "$command" ) >&2

# Resolve base URL
template=$(jq -r '.base_url_template' <<<"$ep")
fallback=$(jq -r '.base_url_fallback' <<<"$ep")

if [[ "$uses_isolate" == "true" ]] && [[ -f "$WORKTREE_PATH/.worktree-isolate/state.local.json" ]]; then
  # Substitute every ${ISOLATE_PORT_<NAME>} from state file (key: allocated_ports — see
  # skills/x-worktree-isolate/scripts/apply.sh:358)
  state="$WORKTREE_PATH/.worktree-isolate/state.local.json"
  resolved="$template"
  while [[ "$resolved" =~ \$\{ISOLATE_PORT_([A-Z0-9_]+)\} ]]; do
    var="${BASH_REMATCH[1]}"
    port=$(jq -r --arg v "$var" '.allocated_ports[$v] // empty' "$state")
    if [[ -z "$port" ]]; then
      resolved="$fallback"
      break
    fi
    resolved="${resolved//\$\{ISOLATE_PORT_$var\}/$port}"
  done
else
  resolved="$fallback"
fi

echo "BASE_URL=$resolved"
