#!/usr/bin/env bash
# doctor.sh — validation suite for x-worktree-isolate.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=allocate-ports.sh
. "$SCRIPT_DIR/allocate-ports.sh"

PASS=0
FAIL=0

ok()   { printf '  ✓ %s\n' "$1"; PASS=$((PASS+1)); }
warn() { printf '  ! %s\n' "$1"; }
bad()  { printf '  ✗ %s\n' "$1"; FAIL=$((FAIL+1)); }

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  bad "not inside a git work tree"
  exit 1
fi
REPO_ROOT="$(git rev-parse --show-toplevel)"
COMMON_DIR="$(git rev-parse --git-common-dir)"

# 1. Profile present + schema
PROFILE="$REPO_ROOT/.worktree-isolate/profile.json"
[[ -f "$PROFILE" ]] || PROFILE="$(dirname "$(cd "$COMMON_DIR" && pwd -P)")/.worktree-isolate/profile.json"
if [[ ! -f "$PROFILE" ]]; then
  bad "profile.json not found (.worktree-isolate/profile.json)"
else
  schema="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("schema"))' "$PROFILE" 2>/dev/null || echo bad)"
  if [[ "$schema" == "1" ]]; then
    ok "profile.json schema=1 ($PROFILE)"
  else
    bad "profile.json schema mismatch (got '$schema', want 1)"
  fi
fi

# 2. Compose files referenced exist
if [[ -f "$PROFILE" ]]; then
  python3 - "$PROFILE" "$REPO_ROOT" <<'PY' && ok "compose_files all present" || bad "one or more compose files missing"
import json, os, sys
prof = json.load(open(sys.argv[1]))
root = sys.argv[2]
missing = [f for f in prof.get("compose_files", []) if not os.path.isfile(os.path.join(root, f))]
sys.exit(1 if missing else 0)
PY
fi

# 3. Drift detection: compare current (service, container_name) pairs against profile.
# Fix #8: pass compose file paths via NUL-delimited list (no unquoted argv).
if [[ -f "$PROFILE" ]] && command -v python3 >/dev/null; then
  DRIFT_RESULT="$(python3 - "$PROFILE" "$REPO_ROOT" "$SCRIPT_DIR/parse-compose.py" <<'PY'
import json, os, subprocess, sys
profile_path, repo_root, parser = sys.argv[1:]
prof = json.load(open(profile_path))
files = [os.path.join(repo_root, f) for f in prof.get("compose_files", []) if os.path.isfile(os.path.join(repo_root, f))]
if not files:
    print("ok|(no compose files)|(none)")
    sys.exit(0)
out = subprocess.check_output(["python3", parser, *files])
parsed = json.loads(out)
cur_pairs = set()
for cf in parsed.get("compose_files", []):
    for svc_name, svc in cf.get("services", {}).items():
        cn = svc.get("container_name")
        if cn:
            cur_pairs.add((svc_name, cn))
exp_pairs = set()
for e in prof.get("services_to_strip", []) or []:
    if e.get("container_name"):
        exp_pairs.add((e.get("service"), e.get("container_name")))
def fmt(pairs):
    return ",".join(f"{s}={c}" for s, c in sorted(pairs)) or "(none)"
status = "ok" if cur_pairs == exp_pairs else "drift"
print(f"{status}|{fmt(cur_pairs)}|{fmt(exp_pairs)}")
PY
)"
  IFS='|' read -r STATUS CUR EXP <<<"$DRIFT_RESULT"
  if [[ "$STATUS" == "ok" ]]; then
    ok "service→container_name set matches profile ($CUR)"
  else
    bad "drift: compose has [$CUR], profile expects [$EXP] — re-run init --rescan"
  fi
fi

# 4. Registry consistency: orphaned slots
REG="$(xwi_registry_file 2>/dev/null || true)"
if [[ -n "$REG" && -f "$REG" ]]; then
  ORPHANS="$(python3 - "$REG" <<'PY'
import json, os, sys
data = json.load(open(sys.argv[1]))
orphans = [s.get("worktree_path") for s in data.get("slots", []) if not os.path.isdir(s.get("worktree_path",""))]
print("\n".join(orphans))
PY
)"
  if [[ -z "$ORPHANS" ]]; then
    ok "registry has no orphaned slots"
  else
    bad "orphaned slots in registry:"$'\n'"$ORPHANS"
  fi
fi

# 5. .env.worktree present + ports free OR bound by us
ENV_WT="$REPO_ROOT/.env.worktree"
if [[ -f "$ENV_WT" ]]; then
  ok ".env.worktree present"
  while IFS='=' read -r k v; do
    [[ -z "$k" || "$k" == \#* || "$k" == "COMPOSE_PROJECT_NAME" ]] && continue
    if [[ "$v" =~ ^[0-9]+$ ]]; then
      if xwi_port_bound "$v"; then
        ok "  $k=$v is bound (assumed by this stack)"
      else
        ok "  $k=$v is free (stack not running)"
      fi
    fi
  done < "$ENV_WT"
else
  warn ".env.worktree not present (run apply)"
fi

# 6. DinD identity mounts: confirm volumes still satisfy ${V}:${V} when profile claims so.
if [[ -f "$PROFILE" ]]; then
  python3 - "$PROFILE" "$REPO_ROOT" "$SCRIPT_DIR/parse-compose.py" <<'PY' && ok "dind identity mounts intact" || bad "dind identity mount drift"
import json, os, subprocess, sys
prof = json.load(open(sys.argv[1]))
root, parser = sys.argv[2], sys.argv[3]
need = {d["var"] for d in prof.get("data_dirs", []) if d.get("dind_identity_mount")}
if not need:
    sys.exit(0)
files = [os.path.join(root, f) for f in prof.get("compose_files", []) if os.path.isfile(os.path.join(root, f))]
if not files:
    sys.exit(0)
out = subprocess.check_output(["python3", parser, *files])
parsed = json.loads(out)
have = set()
for cf in parsed.get("compose_files", []):
    for svc in cf.get("services", {}).values():
        for v in svc.get("volumes", []):
            if v.get("identity_mount"):
                have.add(v.get("host_var"))
sys.exit(0 if need.issubset(have) else 1)
PY
fi

# 7. docker compose config asserts overridden ports appear
# Fix #5: only stack `--env-file .env` when the base file exists.
if [[ -f "$ENV_WT" && -f "$REPO_ROOT/compose.override.yml" ]] && command -v docker >/dev/null; then
  if [[ -f "$REPO_ROOT/.env" ]]; then
    RENDERED="$(cd "$REPO_ROOT" && docker compose --env-file .env --env-file .env.worktree config 2>/dev/null || true)"
  else
    RENDERED="$(cd "$REPO_ROOT" && docker compose --env-file .env.worktree config 2>/dev/null || true)"
  fi
  if [[ -n "$RENDERED" ]]; then
    if printf '%s' "$RENDERED" | grep -qE '127\.0\.0\.1:[0-9]+:[0-9]+'; then
      ok "docker compose config exposes overridden host ports"
    else
      bad "docker compose config does NOT show overridden host ports — override likely not merging"
    fi
  else
    warn "docker compose config returned empty (compose v2 not on PATH or compose syntax error)"
  fi
fi

echo
if [[ "$FAIL" -gt 0 ]]; then
  echo "doctor: $PASS passed, $FAIL failed"
  exit 1
else
  echo "doctor: $PASS passed, all checks clean"
fi
