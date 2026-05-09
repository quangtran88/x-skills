#!/usr/bin/env bash
# inspect.sh — Phase 1: scan repo, draft profile.json.
#
# Usage:
#   inspect.sh             Print draft profile to stdout.
#   inspect.sh --write     Write to .worktree-isolate/profile.json + patch .gitignore.
#   inspect.sh --rescan    Write .worktree-isolate/profile.json.new alongside,
#                          print diff command, exit 1.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
# shellcheck source=allocate-ports.sh
. "$SCRIPT_DIR/allocate-ports.sh"

WRITE=1   # default: persist (init writes profile)
DRY_RUN=0
RESCAN=0
for arg in "$@"; do
  case "$arg" in
    --write)   WRITE=1 ;;
    --dry-run) WRITE=0; DRY_RUN=1 ;;
    --rescan)  RESCAN=1; WRITE=1 ;;
    --help|-h)
      cat <<'EOF'
inspect.sh — Phase 1: build profile.json draft.
  (default)   persist to .worktree-isolate/profile.json + patch .gitignore
  --dry-run   print profile JSON to stdout, do not touch disk
  --rescan    write .worktree-isolate/profile.json.new and print a diff command
EOF
      exit 0 ;;
    *) echo "inspect.sh: unknown flag: $arg" >&2; exit 1 ;;
  esac
done

# --- Preflight ---
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "x-worktree-isolate init: not inside a git work tree" >&2
  exit 1
fi
REPO_ROOT="$(git rev-parse --show-toplevel)"

# Fix #11: assert main checkout, not a linked worktree.
COMMON_DIR_RAW="$(git rev-parse --git-common-dir)"
GIT_DIR_RAW="$(git rev-parse --git-dir)"
abs_path() {
  if command -v realpath >/dev/null 2>&1; then realpath "$1"
  elif command -v python3 >/dev/null 2>&1; then python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$1"
  else (cd "$1" 2>/dev/null && pwd -P); fi
}
ABS_COMMON_INSP="$(abs_path "$COMMON_DIR_RAW")"
ABS_GIT_INSP="$(abs_path "$GIT_DIR_RAW")"
if [[ "$ABS_COMMON_INSP" != "$ABS_GIT_INSP" ]]; then
  echo "x-worktree-isolate init: must run from the main checkout, not a linked worktree" >&2
  echo "  cd to the primary checkout (where .git is a directory, not a file) and re-run." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "x-worktree-isolate init: python3 not on PATH (required for parse-compose.py)" >&2
  exit 2
fi

# Compose v2.24+ assertion. v1 (`docker-compose`) is rejected.
if command -v docker >/dev/null 2>&1 && docker compose version --short >/dev/null 2>&1; then
  COMPOSE_VER="$(docker compose version --short 2>/dev/null || echo 0.0.0)"
  major="${COMPOSE_VER%%.*}"
  rest="${COMPOSE_VER#*.}"
  minor="${rest%%.*}"
  if (( ${major:-0} < 2 )) || { (( ${major:-0} == 2 )) && (( ${minor:-0} < 24 )); }; then
    echo "x-worktree-isolate init: docker compose >= 2.24 required (found $COMPOSE_VER)" >&2
    exit 2
  fi
elif command -v docker-compose >/dev/null 2>&1; then
  echo "x-worktree-isolate init: docker-compose v1 detected and not supported." >&2
  echo "  Install Compose v2: https://docs.docker.com/compose/install/" >&2
  exit 2
else
  echo "x-worktree-isolate init: 'docker compose' not found — cannot verify version. Continuing." >&2
fi

# --- Find compose files (depth <= 2) ---
COMPOSE_FILES=()
while IFS= read -r line; do
  COMPOSE_FILES+=("$line")
done < <(
  find "$REPO_ROOT" -maxdepth 2 -type f \
    \( -name 'docker-compose.yml' -o -name 'docker-compose.yaml' \
       -o -name 'compose.yml' -o -name 'compose.yaml' \) \
    ! -name 'compose.override.yml' ! -name 'compose.override.yaml' \
    ! -name 'docker-compose.override.yml' ! -name 'docker-compose.override.yaml' \
    | sort
)

if [[ ${#COMPOSE_FILES[@]} -eq 0 ]]; then
  echo "x-worktree-isolate init: no compose files found within depth 2 of $REPO_ROOT" >&2
  exit 1
fi

# --- Parse via parse-compose.py ---
PARSED_JSON="$(python3 "$SCRIPT_DIR/parse-compose.py" "${COMPOSE_FILES[@]}")"

# --- Detect Makefile/shell global label filters ---
# Fix #7: scan a fixed set: Makefile, *.mk, scripts/*.sh, bin/*.sh.
LABEL_SCAN_FILES=()
while IFS= read -r line; do
  LABEL_SCAN_FILES+=("$line")
done < <(
  {
    [[ -f "$REPO_ROOT/Makefile" ]] && echo "$REPO_ROOT/Makefile"
    find "$REPO_ROOT" -maxdepth 3 -type f -name '*.mk' 2>/dev/null
    find "$REPO_ROOT/scripts" -maxdepth 3 -type f -name '*.sh' 2>/dev/null
    find "$REPO_ROOT/bin" -maxdepth 2 -type f -name '*.sh' 2>/dev/null
  } | sort -u
)
LABEL_WARNINGS_JSON="$(python3 - "$REPO_ROOT" "${LABEL_SCAN_FILES[@]:-}" <<'PY'
import json, os, re, sys
repo_root = sys.argv[1]
files = [p for p in sys.argv[2:] if p]
warns = []
pat = re.compile(r"--filter\s+label=(\S+)")
for path in files:
    if not os.path.isfile(path):
        continue
    rel = os.path.relpath(path, repo_root)
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            for i, line in enumerate(fh, start=1):
                for m in pat.finditer(line):
                    warns.append({
                        "label": m.group(1).strip("'\""),
                        "found_in": f"{rel}:{i}",
                        "fix_hint": "Scope this filter by COMPOSE_PROJECT_NAME (e.g. --filter label=com.docker.compose.project=$$COMPOSE_PROJECT_NAME) so it only matches the current worktree containers.",
                        "severity": "blocker",
                    })
    except OSError:
        continue
print(json.dumps(warns))
PY
)"

# --- Build profile.json ---
PROFILE_JSON="$(python3 - "$PARSED_JSON" "$LABEL_WARNINGS_JSON" "$REPO_ROOT" <<'PY'
import json, os, sys, time
parsed = json.loads(sys.argv[1])
label_warnings = json.loads(sys.argv[2])
repo_root = sys.argv[3]

compose_files_meta = parsed.get("compose_files", [])

ports = []                    # flat list (used by allocator)
data_dirs = []
dns_refs = []
single_worktree_profiles = []
seen_vars = set()
seen_data_vars = set()

# services_to_strip: bind service-key → container_name (or None) and port var list.
# Compose merges by service KEY (not container_name), so apply must key the
# override block by the YAML service name.
services_to_strip = {}        # ordered dict: svc_name -> entry

# Fix #16: drop unused container_port param.
def suggest_var(svc_name):
    base = svc_name.upper().replace("-", "_").replace(".", "_")
    return f"{base}_PORT"

for cf in compose_files_meta:
    services = cf.get("services", {})
    for svc_name, svc in services.items():
        cname = svc.get("container_name") or None
        svc_port_entries = []   # entries for this service ports
        for p in svc.get("ports", []):
            host_var = p.get("host_var")
            host_lit = p.get("host_literal")
            cport = p.get("container_port")
            # Container-port-only entries (no host side at all) skip — Compose
            # assigns a random host port; no isolation needed.
            if host_var is None and host_lit is None:
                continue
            if host_var:
                if host_var in seen_vars:
                    continue
                seen_vars.add(host_var)
                entry = {
                    "var": host_var,
                    "service": svc_name,
                    "default": int(host_lit) if host_lit is not None else int(cport or 0),
                    "container_port": int(cport) if cport is not None else 0,
                }
            else:
                if cport is None:
                    continue
                var_name = suggest_var(svc_name)
                if var_name in seen_vars:
                    continue
                seen_vars.add(var_name)
                entry = {
                    "var": var_name,
                    "service": svc_name,
                    "default": int(host_lit),
                    "container_port": int(cport),
                }
            ports.append(entry)
            svc_port_entries.append({"var": entry["var"], "container_port": entry["container_port"]})
        # Add to services_to_strip if it has a hardcoded container_name OR has hardcoded host ports.
        needs_strip = bool(cname) or bool(svc_port_entries)
        if needs_strip:
            existing = services_to_strip.get(svc_name)
            if existing is None:
                services_to_strip[svc_name] = {
                    "service": svc_name,
                    "container_name": cname,
                    "ports": list(svc_port_entries),
                }
            else:
                if cname and not existing.get("container_name"):
                    existing["container_name"] = cname
                # merge ports without duplicating vars
                seen_p = {p["var"] for p in existing["ports"]}
                for sp in svc_port_entries:
                    if sp["var"] not in seen_p:
                        existing["ports"].append(sp)
                        seen_p.add(sp["var"])
        for v in svc.get("volumes", []):
            host_var = v.get("host_var")
            if host_var and host_var not in seen_data_vars:
                seen_data_vars.add(host_var)
                data_dirs.append({
                    "var": host_var,
                    "default_relative": "./data",
                    "per_worktree": True,
                    "dind_identity_mount": bool(v.get("identity_mount")),
                    "rationale": "host:container identity mount required by docker.sock-spawned containers" if v.get("identity_mount") else "",
                })
        for prof in svc.get("profiles", []) or []:
            single_worktree_profiles.append({
                "service": svc_name,
                "profile": prof,
                "reason": "compose profile flagged for single-worktree review",
                "severity": "warning",
            })
    dns_refs.extend(cf.get("service_dns_references", []))

services_to_strip_list = list(services_to_strip.values())

profile = {
    "schema": 1,
    "generator_version": "0.1.0",
    "stack": "docker-compose",
    "compose_files": [os.path.relpath(cf["file"], repo_root) for cf in compose_files_meta],
    "compose_override_target": "compose.override.yml",
    "env_file_target": ".env.worktree",
    "port_strategy": {
        "mode": "registry",
        "scan_range": [18000, 29999],
        "ports": ports,
    },
    "data_dirs": data_dirs,
    "services_to_strip": services_to_strip_list,
    "service_dns_references": dns_refs,
    "global_label_warnings": label_warnings,
    "single_worktree_profiles": single_worktree_profiles,
    "post_apply_hints": [],
    "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
}
print(json.dumps(profile, indent=2))
PY
)"

# --- Output ---
TARGET_DIR="$REPO_ROOT/.worktree-isolate"
TARGET="$TARGET_DIR/profile.json"

# Fix #3: default behavior is to write (init persists profile). --dry-run
# preserves the old stdout-only mode for ad-hoc inspection.
if [[ "$WRITE" -eq 0 ]]; then
  printf '%s\n' "$PROFILE_JSON"
  exit 0
fi

mkdir -p "$TARGET_DIR"

if [[ "$RESCAN" -eq 1 && -f "$TARGET" ]]; then
  RESCAN_PATH="$TARGET_DIR/profile.json.new"
  printf '%s\n' "$PROFILE_JSON" > "$RESCAN_PATH"
  echo "x-worktree-isolate init --rescan: wrote $RESCAN_PATH"
  echo "Review changes:"
  echo "  diff -u '$TARGET' '$RESCAN_PATH'"
  echo "Then merge manually and remove the .new file."
  exit 1
fi

printf '%s\n' "$PROFILE_JSON" > "$TARGET"
echo "x-worktree-isolate init: wrote $TARGET"

# --- Patch .gitignore (idempotent) ---
GITIGNORE="$REPO_ROOT/.gitignore"
LINES=(
  "# x-worktree-isolate"
  ".env.worktree"
  "compose.override.yml"
  ".worktree-isolate/state.local.json"
)
touch "$GITIGNORE"
for line in "${LINES[@]}"; do
  if ! grep -qxF "$line" "$GITIGNORE" 2>/dev/null; then
    printf '%s\n' "$line" >> "$GITIGNORE"
  fi
done
echo "x-worktree-isolate init: ensured .gitignore entries"

# --- Hint user about wt.toml + git add ---
WT_TOML="$REPO_ROOT/.config/wt.toml"
echo
echo "Next steps:"
echo "  1. Review and edit $TARGET (especially port_strategy and data_dirs)."
echo "  2. Add to git:"
echo "       git add .worktree-isolate/profile.json .gitignore"
echo "  3. (Optional) Wire up worktrunk hooks. Append to $WT_TOML:"
echo "       post-create = \"x-worktree-isolate apply --quiet\""
echo "       pre-remove  = \"x-worktree-isolate release --quiet\""
echo "     Or copy from: $SKILL_DIR/templates/wt.toml.snippet"
echo "  4. Run apply in each worktree:"
echo "       x-worktree-isolate apply"
