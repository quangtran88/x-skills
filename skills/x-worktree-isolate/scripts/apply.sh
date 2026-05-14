#!/usr/bin/env bash
# apply.sh — Phase 2: write compose.override.yml + .env.worktree for current worktree.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
# shellcheck source=allocate-ports.sh
. "$SCRIPT_DIR/allocate-ports.sh"

QUIET=0
IF_PROFILE_EXISTS=0
IGNORE_WARNINGS=0
DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --quiet)              QUIET=1 ;;
    --if-profile-exists)  IF_PROFILE_EXISTS=1 ;;
    --ignore-warnings)    IGNORE_WARNINGS=1 ;;
    --dry-run)            DRY_RUN=1 ;;
    --help|-h)
      cat <<'EOF'
apply.sh — Phase 2: write override + .env.worktree.
  --quiet                suppress success summary
  --if-profile-exists    exit 0 silently when no profile.json
  --ignore-warnings      bypass severity:blocker gate (explicit footgun ack)
  --dry-run              preview without writing
EOF
      exit 0 ;;
    *) echo "apply.sh: unknown flag: $arg" >&2; exit 1 ;;
  esac
done

log() { [[ "$QUIET" -eq 1 ]] || printf '%s\n' "$*"; }

# --- Verify in worktree (linked, not main) ---
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "x-worktree-isolate apply: not inside a git work tree" >&2
  exit 1
fi
REPO_ROOT="$(git rev-parse --show-toplevel)"
COMMON_DIR="$(git rev-parse --git-common-dir)"
GIT_DIR="$(git rev-parse --git-dir)"
ABS_COMMON="$(cd "$REPO_ROOT" 2>/dev/null && cd "$COMMON_DIR" 2>/dev/null && pwd -P)" || ABS_COMMON="$COMMON_DIR"
ABS_GIT="$(cd "$REPO_ROOT" 2>/dev/null && cd "$GIT_DIR" 2>/dev/null && pwd -P)" || ABS_GIT="$GIT_DIR"
if [[ "$ABS_COMMON" == "$ABS_GIT" ]]; then
  if [[ "$IF_PROFILE_EXISTS" -eq 1 ]]; then
    exit 0
  fi
  echo "x-worktree-isolate apply: cwd is the main checkout, not a linked worktree." >&2
  echo "  Run apply from inside a worktree (created via 'wt switch -c' or 'git worktree add')." >&2
  exit 1
fi

# --- Locate profile.json (linked-worktree-aware) ---
# The profile lives in the main checkout's working tree. Resolve via
# git-common-dir → parent dir of .git is the main checkout.
PROFILE_LOCAL="$REPO_ROOT/.worktree-isolate/profile.json"
PROFILE_MAIN="$(dirname "$ABS_COMMON")/.worktree-isolate/profile.json"
PROFILE=""
if [[ -f "$PROFILE_LOCAL" ]]; then
  PROFILE="$PROFILE_LOCAL"
elif [[ -f "$PROFILE_MAIN" ]]; then
  PROFILE="$PROFILE_MAIN"
fi

if [[ -z "$PROFILE" ]]; then
  if [[ "$IF_PROFILE_EXISTS" -eq 1 ]]; then
    exit 0
  fi
  echo "x-worktree-isolate apply: no .worktree-isolate/profile.json found." >&2
  echo "  Run 'x-worktree-isolate init' in the main checkout first." >&2
  exit 1
fi

# Hard-reject schema:1 (v0.2.0+ requires schema:2). Print precise migration command.
SCHEMA="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("schema"))' "$PROFILE")"
if [[ "$SCHEMA" == "1" ]]; then
  cat >&2 <<EOF
x-worktree-isolate apply: profile schema 1 is no longer supported by v0.2.0+.
  Profile: $PROFILE

  Migrate by running init --rescan from the main checkout:

    cd <main-checkout> && x-worktree-isolate init --rescan

  init --rescan will write ${PROFILE}.new alongside the existing profile and
  print the exact diff + merge commands you should run next. Do not edit
  ${PROFILE} by hand.
EOF
  exit 1
fi
if [[ "$SCHEMA" != "2" ]]; then
  echo "x-worktree-isolate apply: unsupported profile schema ($SCHEMA). Expected 2." >&2
  exit 1
fi

# --- Evaluate blocker warnings BEFORE allocating (so we don't burn slots on a no-go). ---
# Unified collector: global_label_warnings + single_worktree_profiles + singletons[kind=host].
OVERRIDES_FILE="$REPO_ROOT/.worktree-isolate/feature-overrides.local.json"
BLOCKER_LIST="$(python3 - "$PROFILE" "$OVERRIDES_FILE" <<'PY'
import json, os, sys
profile = json.load(open(sys.argv[1]))
ov_path = sys.argv[2]
overrides = {}
if os.path.isfile(ov_path):
    try: overrides = {o["id"]: o["state"] for o in json.load(open(ov_path)).get("overrides", []) if isinstance(o, dict) and "id" in o and "state" in o}
    except (OSError, json.JSONDecodeError): pass

lines = []
for w in profile.get("global_label_warnings", []):
    if not isinstance(w, dict): continue
    if not w.get("label"): continue
    if w.get("severity") == "blocker":
        lines.append(f"  - [{w.get('found_in','?')}] label={w.get('label')}\n    fix_hint: {w.get('fix_hint','(none)')}")
for w in profile.get("single_worktree_profiles", []):
    if not isinstance(w, dict): continue
    if w.get("severity") == "blocker" and w.get("service"):
        lines.append(f"  - profile={w.get('profile')} on service {w.get('service')}: {w.get('reason')}")
for s in profile.get("singletons", []) or []:
    if s.get("kind") != "host": continue
    state = overrides.get(s.get("id"), s.get("default_in_worktree", "disabled"))
    if state == "acknowledged": continue
    if s.get("severity") != "blocker": continue
    lines.append(
        f"  - host-singleton {s.get('id')}: {s.get('host_artifact','')}\n"
        f"    fix: {s.get('manual_fix_hint','run x-worktree-isolate ack-host-singletons')}"
    )
print("\n".join(lines))
PY
)"
if [[ -n "$BLOCKER_LIST" && "$IGNORE_WARNINGS" -eq 0 ]]; then
  cat >&2 <<EOF
x-worktree-isolate apply: BLOCKED — unresolved cross-worktree footguns:
$BLOCKER_LIST

Resolve the issues above (apply the fix_hint), or:
  - for host-singletons, run: x-worktree-isolate ack-host-singletons
  - or re-run with --ignore-warnings to acknowledge the footguns explicitly.
EOF
  exit 1
fi

# --- Compute project name + branch ---
BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
sanitize() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -c '[:alnum:]_-' '-' | sed 's/-\{2,\}/-/g; s/^-//; s/-$//'; }
REPO_NAME="$(basename "$(dirname "$ABS_COMMON")")"
REPO_SLUG="$(sanitize "$REPO_NAME")"
BRANCH_SLUG="$(sanitize "$BRANCH")"
PROJECT_NAME="${REPO_SLUG}-${BRANCH_SLUG}"

# --- Acquire lock + allocate ---
xwi_acquire_lock || exit 1
trap 'xwi_release_lock' EXIT

SLOT="$(xwi_allocate_slot "$REPO_ROOT")"

# Build allocations: walk profile ports, pick a host port per slot.
# Fix #4: if THIS worktree already has a registry entry, reuse those ports
# verbatim so re-apply produces a byte-identical .env.worktree.
PORT_PLAN_JSON="$(python3 - "$PROFILE" "$SLOT" "$REPO_ROOT" "$(xwi_registry_file)" <<'PY'
import json, os, sys
profile = json.load(open(sys.argv[1]))
slot = int(sys.argv[2])
worktree = sys.argv[3]
reg_path = sys.argv[4]
strat = profile.get("port_strategy", {})
lo, hi = strat.get("scan_range", [18000, 29999])
existing_ports = {}
if os.path.isfile(reg_path):
    try:
        reg = json.load(open(reg_path))
        for s in reg.get("slots", []):
            if s.get("worktree_path") == worktree:
                existing_ports = s.get("ports") or {}
                break
    except json.JSONDecodeError:
        existing_ports = {}
out = []
for p in strat.get("ports", []):
    out.append({
        "var": p["var"],
        "service": p.get("service"),
        "default": int(p["default"]),
        "container_port": int(p.get("container_port", 0)),
        "preassigned": int(existing_ports[p["var"]]) if p["var"] in existing_ports else None,
    })
print(json.dumps({"slot": slot, "lo": lo, "hi": hi, "ports": out}))
PY
)"

# Single python eval extracts everything we need (avoids N forks per port).
eval "$(python3 - "$PORT_PLAN_JSON" <<'PY'
import json, shlex, sys
plan = json.loads(sys.argv[1])
print(f"LO={shlex.quote(str(plan['lo']))}")
print(f"HI={shlex.quote(str(plan['hi']))}")
print(f"PORT_COUNT={shlex.quote(str(len(plan['ports'])))}")
for i, p in enumerate(plan["ports"]):
    print(f"P_VAR_{i}={shlex.quote(p['var'])}")
    print(f"P_DEFAULT_{i}={shlex.quote(str(p['default']))}")
    print(f"P_CPORT_{i}={shlex.quote(str(p['container_port']))}")
    print(f"P_SVC_{i}={shlex.quote(p['service'] or '')}")
    print(f"P_PRE_{i}={shlex.quote(str(p['preassigned']) if p['preassigned'] is not None else '')}")
PY
)"

CLAIMED_CSV="$(xwi_claimed_ports_csv)"

declare -a SELECTED_VARS=()
declare -a SELECTED_PORTS=()
declare -a SELECTED_CONTAINER_PORTS=()
declare -a SELECTED_SERVICES=()

# When reusing this worktree's prior allocations, exclude them from the
# "claimed" set so the picker doesn't see them as collisions.
PRE_CSV=""
for ((i=0; i<PORT_COUNT; i++)); do
  pre_var="P_PRE_${i}"
  pre_val="${!pre_var}"
  if [[ -n "$pre_val" ]]; then
    PRE_CSV="${PRE_CSV:+${PRE_CSV},}${pre_val}"
  fi
done

# Subtract PRE_CSV ports from CLAIMED_CSV so reused ports aren't blocked.
ALL_CLAIMED="$(python3 - "$CLAIMED_CSV" "$PRE_CSV" <<'PY'
import sys
claimed = [p for p in sys.argv[1].split(",") if p]
mine = set(p for p in sys.argv[2].split(",") if p)
remaining = [p for p in claimed if p not in mine]
print(",".join(remaining))
PY
)"

for ((i=0; i<PORT_COUNT; i++)); do
  var_name="P_VAR_${i}";    VAR="${!var_name}"
  def_name="P_DEFAULT_${i}"; DEFAULT="${!def_name}"
  cp_name="P_CPORT_${i}";    CPORT="${!cp_name}"
  svc_name="P_SVC_${i}";     SVC="${!svc_name}"
  pre_name="P_PRE_${i}";     PRE="${!pre_name}"
  if [[ -n "$PRE" ]]; then
    PICKED="$PRE"
  else
    PICKED="$(xwi_pick_port "$DEFAULT" "$SLOT" "$LO" "$HI" "$ALL_CLAIMED")" || exit 1
  fi
  ALL_CLAIMED="${ALL_CLAIMED:+${ALL_CLAIMED},}${PICKED}"
  SELECTED_VARS+=("$VAR")
  SELECTED_PORTS+=("$PICKED")
  SELECTED_CONTAINER_PORTS+=("$CPORT")
  SELECTED_SERVICES+=("$SVC")
done

# --- Compute data_dir absolute paths (Fix #6: ALL per_worktree entries) ---
DATA_DIRS_JSON="$(python3 - "$PROFILE" "$REPO_ROOT" <<'PY'
import json, os, sys
profile = json.load(open(sys.argv[1]))
repo_root = sys.argv[2]
out = []
for d in profile.get("data_dirs", []):
    if not d.get("per_worktree"):
        continue
    rel = d.get("default_relative") or "./data"
    out.append({"var": d.get("var") or "", "path": os.path.abspath(os.path.join(repo_root, rel))})
print(json.dumps(out))
PY
)"

declare -a DATA_VARS=()
declare -a DATA_PATHS=()
eval "$(python3 - "$DATA_DIRS_JSON" <<'PY'
import json, shlex, sys
entries = json.loads(sys.argv[1])
print(f"DATA_COUNT={shlex.quote(str(len(entries)))}")
for i, e in enumerate(entries):
    print(f"D_VAR_{i}={shlex.quote(e['var'])}")
    print(f"D_PATH_{i}={shlex.quote(e['path'])}")
PY
)"
for ((i=0; i<DATA_COUNT; i++)); do
  v_name="D_VAR_${i}"; p_name="D_PATH_${i}"
  DATA_VARS+=("${!v_name}")
  DATA_PATHS+=("${!p_name}")
done

# Back-compat single-value pair (used by state.local.json + summary header).
DATA_VAR="${DATA_VARS[0]:-}"
DATA_PATH="${DATA_PATHS[0]:-}"

# --- Render compose.override.yml ---
OVERRIDE_PATH="$REPO_ROOT/compose.override.yml"
ENV_PATH="$REPO_ROOT/.env.worktree"
STATE_DIR="$REPO_ROOT/.worktree-isolate"
STATE_PATH="$STATE_DIR/state.local.json"

# Single-pass render: merge services_to_strip (container_name/ports) + singleton
# compose_service_fields (deploy/profiles) into ONE dict per service so
# compose.override.yml has exactly one `services.<svc>:` block per service.
RENDER_JSON="$(python3 "$SCRIPT_DIR/render-singletons.py" --profile "$PROFILE" --overrides "$OVERRIDES_FILE")"

# Surface render-side warnings (e.g., replicas-zero on standalone compose).
RENDER_WARNINGS="$(printf '%s' "$RENDER_JSON" | python3 -c 'import json,sys; print("\n".join(f"⚠ {w}" for w in json.load(sys.stdin).get("warnings", [])))')"
if [[ -n "$RENDER_WARNINGS" ]]; then
  printf '%s\n' "$RENDER_WARNINGS" >&2
fi

OVERRIDE_BODY="$(python3 - "$PROFILE" "$RENDER_JSON" <<'PY'
import json, sys
profile = json.load(open(sys.argv[1]))
render = json.loads(sys.argv[2])
svc_fields = render.get("compose_service_fields", {})

merged: dict = {}
for e in profile.get("services_to_strip", []) or []:
    if not isinstance(e, dict): continue
    svc = e.get("service")
    if not svc: continue
    entry = merged.setdefault(svc, {})
    if e.get("container_name"):
        entry["container_name_reset"] = True
    if e.get("ports"):
        entry["ports"] = list(e.get("ports") or [])
for svc, fields in (svc_fields or {}).items():
    entry = merged.setdefault(svc, {})
    if "deploy" in fields:
        entry["deploy"] = fields["deploy"]
    if "profiles" in fields:
        entry.setdefault("profiles", [])
        for p in fields["profiles"]:
            if p not in entry["profiles"]:
                entry["profiles"].append(p)

lines = ["services:"]
for svc, entry in merged.items():
    if not entry:
        continue
    lines.append(f"  {svc}:")
    if entry.get("container_name_reset"):
        lines.append("    container_name: !reset null")
    if entry.get("ports"):
        lines.append("    ports: !override")
        for p in entry["ports"]:
            var = p.get("var"); cport = p.get("container_port")
            if not var or cport is None: continue
            lines.append(f'      - "127.0.0.1:${{{var}}}:{cport}"')
    if entry.get("deploy"):
        lines.append("    deploy:")
        for k, v in entry["deploy"].items():
            lines.append(f"      {k}: {json.dumps(v)}")
    if entry.get("profiles"):
        lines.append("    profiles:")
        for p in entry["profiles"]:
            lines.append(f"      - {p}")
print("\n".join(lines))
PY
)"

OVERRIDE_HEADER='# Auto-generated by x-worktree-isolate — do not edit by hand.
# Regenerate via: x-worktree-isolate apply'
OVERRIDE_CONTENT="${OVERRIDE_HEADER}
${OVERRIDE_BODY}"

# --- Render .env.worktree ---
# Fix #5: launch hint depends on whether base .env exists.
if [[ -f "$REPO_ROOT/.env" ]]; then
  LAUNCH_HINT="docker compose --env-file .env --env-file .env.worktree up"
else
  LAUNCH_HINT="docker compose --env-file .env.worktree up"
fi

ENV_LINES="COMPOSE_PROJECT_NAME=${PROJECT_NAME}"
# Fix #6: emit ALL data_dir entries (not just the first).
for ((i=0; i<${#DATA_VARS[@]}; i++)); do
  dv="${DATA_VARS[$i]}"; dp="${DATA_PATHS[$i]}"
  if [[ -n "$dv" && -n "$dp" ]]; then
    ENV_LINES="${ENV_LINES}
${dv}=${dp}"
  fi
done
for ((i=0; i<${#SELECTED_VARS[@]}; i++)); do
  ENV_LINES="${ENV_LINES}
${SELECTED_VARS[$i]}=${SELECTED_PORTS[$i]}"
done
SINGLETON_ENV_LINES="$(printf '%s' "$RENDER_JSON" | python3 -c 'import json,sys; print("\n".join(json.load(sys.stdin).get("env_lines", [])))')"
if [[ -n "$SINGLETON_ENV_LINES" ]]; then
  ENV_LINES="${ENV_LINES}
${SINGLETON_ENV_LINES}"
fi
ENV_CONTENT="# Auto-generated by x-worktree-isolate — do not edit by hand.
# Regenerate via: x-worktree-isolate apply
# Launch: ${LAUNCH_HINT}
${ENV_LINES}"

# --- Build state.local.json + ports map for registry ---
PORTS_MAP_JSON="$(python3 - "${SELECTED_VARS[*]:-}" "${SELECTED_PORTS[*]:-}" <<'PY'
import json, sys
keys = sys.argv[1].split()
vals = sys.argv[2].split()
out = {}
for k, v in zip(keys, vals):
    out[k] = int(v)
print(json.dumps(out))
PY
)"

STATE_CONTENT="$(python3 - "$SLOT" "$PORTS_MAP_JSON" "$DATA_VAR" "$DATA_PATH" "$BRANCH" "$PROJECT_NAME" <<'PY'
import json, sys, time
slot, ports_map, dvar, dpath, branch, proj = sys.argv[1:]
print(json.dumps({
    "schema": 1,
    "slot": int(slot),
    "branch": branch,
    "compose_project_name": proj,
    "allocated_ports": json.loads(ports_map),
    "data_dir_var": dvar,
    "data_dir_path": dpath,
    "applied_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
}, indent=2))
PY
)"

# --- DRY RUN: print what we'd write, don't touch disk. ---
if [[ "$DRY_RUN" -eq 1 ]]; then
  log "── dry-run: $OVERRIDE_PATH ─────────────────────────"
  log "$OVERRIDE_CONTENT"
  log "── dry-run: $ENV_PATH ─────────────────────────"
  log "$ENV_CONTENT"
  log "── dry-run: $STATE_PATH ─────────────────────────"
  log "$STATE_CONTENT"
  log "── dry-run: registry slot $SLOT (not claimed) ─────"
  exit 0
fi

# --- Write files ---
# Atomic write: render to mktemp on the same filesystem, then rename. A SIGINT
# or disk-full mid-write leaves the target file untouched rather than a partial
# YAML/env that `docker compose up` would fail on.
write_atomic() {
  local target="$1" content="$2" dir tmp
  dir=$(dirname "$target")
  mkdir -p "$dir"
  tmp=$(mktemp "$dir/.xwi.$(basename "$target").XXXXXX")
  printf '%s\n' "$content" > "$tmp"
  mv "$tmp" "$target"
}
write_atomic "$OVERRIDE_PATH" "$OVERRIDE_CONTENT"
write_atomic "$ENV_PATH"      "$ENV_CONTENT"
mkdir -p "$STATE_DIR"
write_atomic "$STATE_PATH"    "$STATE_CONTENT"

# --- Patch .gitignore (idempotent) ---
GITIGNORE="$REPO_ROOT/.gitignore"
LINES=(
  "# x-worktree-isolate"
  ".env.worktree"
  "compose.override.yml"
  ".worktree-isolate/state.local.json"
  ".worktree-isolate/feature-overrides.local.json"
)
touch "$GITIGNORE"
for line in "${LINES[@]}"; do
  if ! grep -qxF "$line" "$GITIGNORE" 2>/dev/null; then
    printf '%s\n' "$line" >> "$GITIGNORE"
  fi
done

# --- mkdir data dirs (Fix #6: all of them) ---
for ((i=0; i<${#DATA_PATHS[@]}; i++)); do
  dp="${DATA_PATHS[$i]}"
  [[ -n "$dp" ]] && mkdir -p "$dp"
done

# --- Claim registry slot ---
xwi_claim_slot "$SLOT" "$REPO_ROOT" "$BRANCH" "$PORTS_MAP_JSON" "$DATA_PATH"

# Singleton ownership bookkeeping (declarative; not a runtime lock).
ENABLED_IDS="$(python3 - "$PROFILE" "$OVERRIDES_FILE" <<'PY'
import json, os, sys
prof = json.load(open(sys.argv[1]))
ov_path = sys.argv[2]
overrides = {}
if os.path.isfile(ov_path):
    try: overrides = {o["id"]: o["state"] for o in json.load(open(ov_path)).get("overrides", []) if isinstance(o, dict) and "id" in o and "state" in o}
    except (OSError, json.JSONDecodeError): pass
out=[]
for s in prof.get("singletons", []) or []:
    sid = s["id"]
    state = overrides.get(sid, s.get("default_in_worktree","disabled"))
    if state == "enabled":
        out.append(sid)
print(",".join(out))
PY
)"
xwi_set_singleton_owners "$REPO_ROOT" "$ENABLED_IDS"

# --- Print Next Steps ---
if [[ "$QUIET" -eq 0 ]]; then
  cat <<EOF

✓ x-worktree-isolate applied (slot $SLOT)

  COMPOSE_PROJECT_NAME=$PROJECT_NAME
  branch              = $BRANCH
EOF
  for ((i=0; i<${#DATA_VARS[@]}; i++)); do
    dv="${DATA_VARS[$i]}"; dp="${DATA_PATHS[$i]}"
    [[ -n "$dv" && -n "$dp" ]] && echo "  ${dv} = ${dp}"
  done
  echo "  ports:"
  for ((i=0; i<${#SELECTED_VARS[@]}; i++)); do
    echo "    ${SELECTED_VARS[$i]} = ${SELECTED_PORTS[$i]} → container ${SELECTED_CONTAINER_PORTS[$i]} (${SELECTED_SERVICES[$i]})"
  done
  cat <<EOF

  Files written:
    $OVERRIDE_PATH
    $ENV_PATH
    $STATE_PATH

  Next steps — launch this worktree:
    ${LAUNCH_HINT}

EOF
fi
