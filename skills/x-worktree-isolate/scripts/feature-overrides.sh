#!/usr/bin/env bash
# feature-overrides.sh — features / enable / disable / ack-host-singletons subcommands.
#
# Reads <worktree>/.worktree-isolate/profile.json (or main-checkout copy).
# Writes <worktree>/.worktree-isolate/feature-overrides.local.json (gitignored).
# Re-invokes apply.sh to regenerate compose.override.yml + .env.worktree.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

SUB="${1:-}"; shift || true
QUIET=0
FORCE=0
POSITIONAL=()
for arg in "$@"; do
  case "$arg" in
    --quiet) QUIET=1 ;;
    --force|--steal) FORCE=1 ;;
    *) POSITIONAL+=("$arg") ;;
  esac
done
set -- "${POSITIONAL[@]:-}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "x-worktree-isolate ${SUB}: not in a git work tree" >&2; exit 1
fi
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"
COMMON_DIR="$(git rev-parse --git-common-dir)"
PROFILE_LOCAL="$REPO_ROOT/.worktree-isolate/profile.json"
PROFILE_MAIN="$(dirname "$(cd "$REPO_ROOT" && cd "$COMMON_DIR" && pwd -P)")/.worktree-isolate/profile.json"
PROFILE=""
if [[ -f "$PROFILE_LOCAL" ]]; then PROFILE="$PROFILE_LOCAL"
elif [[ -f "$PROFILE_MAIN" ]]; then PROFILE="$PROFILE_MAIN"
fi
if [[ -z "$PROFILE" ]]; then echo "x-worktree-isolate ${SUB}: no profile found" >&2; exit 1; fi

OV_DIR="$REPO_ROOT/.worktree-isolate"
OV_FILE="$OV_DIR/feature-overrides.local.json"
mkdir -p "$OV_DIR"

case "$SUB" in
  features)
    python3 - "$PROFILE" "$OV_FILE" <<'PY'
import json, os, sys
prof = json.load(open(sys.argv[1]))
overrides = {}
if os.path.isfile(sys.argv[2]):
    try:
        overrides = {o["id"]: o["state"] for o in json.load(open(sys.argv[2])).get("overrides", []) if isinstance(o, dict) and "id" in o and "state" in o}
    except (OSError, json.JSONDecodeError):
        overrides = {}
print(f"{'id':<30} {'kind':<16} {'state':<14} rationale")
for s in prof.get("singletons", []) or []:
    state = overrides.get(s["id"], s.get("default_in_worktree", "disabled"))
    print(f"{s['id'][:30]:<30} {s.get('kind',''):<16} {state:<14} {s.get('rationale','')[:60]}")
PY
    ;;
  enable|disable|ack-host-singletons)
    feature_id="${1:-}"
    if [[ "$SUB" != "ack-host-singletons" && -z "$feature_id" ]]; then
      echo "usage: x-worktree-isolate $SUB <feature-id>" >&2; exit 1
    fi
    NEW_STATE=""
    case "$SUB" in
      enable)              NEW_STATE="enabled" ;;
      disable)             NEW_STATE="disabled" ;;
      ack-host-singletons) NEW_STATE="acknowledged" ;;
    esac
    # ENABLE only: win the claim BEFORE writing the override (enabled ⇒ owned invariant).
    if [[ "$SUB" == "enable" ]]; then
      # Resolve tier + this worktree's COMPOSE_PROJECT_NAME for liveness.
      COMMON_DIR_FO="$(git rev-parse --git-common-dir)"
      ABS_COMMON_FO="$(cd "$REPO_ROOT" && cd "$COMMON_DIR_FO" && pwd -P)"
      _sanitize_fo() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -c '[:alnum:]_-' '-' | sed 's/-\{2,\}/-/g; s/^-//; s/-$//'; }
      BRANCH_FO="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
      PROJECT_NAME_FO="$(_sanitize_fo "$(basename "$(dirname "$ABS_COMMON_FO")")")-$(_sanitize_fo "$BRANCH_FO")"
      TIER_FO="$(python3 -c 'import json,sys; b={s["id"]:s for s in json.load(open(sys.argv[1])).get("singletons",[]) or []}; print(b.get(sys.argv[2],{}).get("kind",""))' "$PROFILE" "$feature_id")"
      PROJ_FO=""; [[ "$TIER_FO" == "compose-service" ]] && PROJ_FO="$PROJECT_NAME_FO"
      # shellcheck source=allocate-ports.sh
      . "$SCRIPT_DIR/allocate-ports.sh"
      xwi_acquire_lock || exit 1
      xwi_heal_registry
      if ! xwi_claim_singleton "$feature_id" "$REPO_ROOT" "$BRANCH_FO" "$TIER_FO" "$PROJ_FO" "$FORCE"; then
        xwi_release_lock
        echo "x-worktree-isolate enable: refused (see notice above). Use --force to steal a live lock." >&2
        exit 2
      fi
      xwi_release_lock   # release BEFORE apply (child process) to avoid lock contention.
    fi
    python3 - "$PROFILE" "$OV_FILE" "$SUB" "$feature_id" "$NEW_STATE" <<'PY'
import json, os, sys, time
prof = json.load(open(sys.argv[1]))
ov_path, sub, fid, state = sys.argv[2:]
existing = {"schema": 1, "overrides": []}
if os.path.isfile(ov_path):
    try: existing = json.load(open(ov_path))
    except (OSError, json.JSONDecodeError): pass
overrides = {o["id"]: o["state"] for o in existing.get("overrides", []) if isinstance(o, dict) and "id" in o and "state" in o}

if sub == "ack-host-singletons":
    for s in prof.get("singletons", []) or []:
        if s.get("kind") == "host":
            overrides[s["id"]] = "acknowledged"
else:
    by_id = {s["id"]: s for s in prof.get("singletons", []) or []}
    if fid not in by_id:
        print(f"x-worktree-isolate {sub}: no such feature id: {fid}", file=sys.stderr)
        sys.exit(1)
    # Host-tier singletons can't be per-worktree-disabled; the legal state is
    # 'acknowledged' (via ack-host-singletons) or unset. Rejecting here avoids
    # the confusing UX where `enable <host-id>` "succeeds" then the next
    # `apply` re-blocks because state != "acknowledged".
    if by_id[fid].get("kind") == "host":
        print(
            f"x-worktree-isolate {sub}: '{fid}' is a host-tier singleton; "
            "use 'x-worktree-isolate ack-host-singletons' instead.",
            file=sys.stderr,
        )
        sys.exit(1)
    overrides[fid] = state

out = {
    "schema": 1,
    "overrides": [{"id": k, "state": v} for k, v in sorted(overrides.items())],
    "updated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
}
tmp = ov_path + ".tmp"
with open(tmp, "w") as fh: json.dump(out, fh, indent=2)
os.replace(tmp, ov_path)
PY
    FORCE_ARG=(); [[ "$FORCE" -eq 1 ]] && FORCE_ARG=(--force)
    if [[ "$QUIET" -eq 1 ]]; then
      bash "$SCRIPT_DIR/apply.sh" --quiet --if-profile-exists ${FORCE_ARG[@]+"${FORCE_ARG[@]}"}
    else
      bash "$SCRIPT_DIR/apply.sh" --if-profile-exists ${FORCE_ARG[@]+"${FORCE_ARG[@]}"}
    fi
    ;;
  *)
    echo "feature-overrides: unknown subcommand: $SUB" >&2; exit 1 ;;
esac
