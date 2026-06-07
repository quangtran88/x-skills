#!/usr/bin/env bash
# allocate-ports.sh — registry primitives for x-worktree-isolate.
#
# Provides: repo_id, registry_dir, registry_file, lock acquire/release, slot
# allocation, port collision check, slot release, list. Sourced by apply.sh /
# release.sh; also runnable directly: `allocate-ports.sh list`.

set -euo pipefail

# --- Repo identity ---
# sha1(realpath(git rev-parse --git-common-dir)) — main checkout and linked
# worktrees of one repo all map to the same hash.
xwi_repo_id() {
  local common_dir abs_dir
  common_dir="$(git rev-parse --git-common-dir 2>/dev/null)" || {
    echo "x-worktree-isolate: not inside a git work tree" >&2
    return 1
  }
  # `realpath` is GNU coreutils on Linux, BSD on macOS — both accept a path arg.
  if command -v realpath >/dev/null 2>&1; then
    abs_dir="$(realpath "$common_dir")"
  elif command -v python3 >/dev/null 2>&1; then
    abs_dir="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$common_dir")"
  else
    abs_dir="$(cd "$common_dir" && pwd -P)"
  fi
  if command -v openssl >/dev/null 2>&1; then
    printf '%s' "$abs_dir" | openssl dgst -sha1 -hex | awk '{print $NF}'
  else
    python3 -c 'import hashlib,sys; print(hashlib.sha1(sys.argv[1].encode()).hexdigest())' "$abs_dir"
  fi
}

xwi_registry_dir() {
  local id
  id="$(xwi_repo_id)" || return 1
  local root="${XDG_CONFIG_HOME:-$HOME/.config}/worktree-isolate/$id"
  mkdir -p "$root"
  echo "$root"
}

xwi_registry_file() {
  local dir
  dir="$(xwi_registry_dir)" || return 1
  echo "$dir/registry.json"
}

xwi_registry_lock_dir() {
  local dir
  dir="$(xwi_registry_dir)" || return 1
  echo "$dir/registry.lock"
}

# --- Lock primitives ---
# PID-stamped lock with stale detection. The holder writes $$ into lock_dir/pid;
# a contender that finds the lock checks if the holder PID is still alive via
# `kill -0`. If not, take over the lock. Prevents a crashed/killed apply from
# wedging every subsequent invocation behind a manual rmdir.
xwi_acquire_lock() {
  local lock_dir pid_file holder
  lock_dir="$(xwi_registry_lock_dir)" || return 1
  pid_file="$lock_dir/pid"
  local i
  # Budget covers one full apply's critical section (heal + claim + materialize +
  # slot/port allocation, each spawning python) so parallel applies serialize rather
  # than spuriously failing to acquire. Dead holders are taken over immediately below.
  for i in {1..50}; do
    if mkdir "$lock_dir" 2>/dev/null; then
      printf '%s\n' "$$" > "$pid_file" 2>/dev/null || true
      return 0
    fi
    # Lock exists — check if the holder is alive.
    if [[ -f "$pid_file" ]]; then
      holder="$(cat "$pid_file" 2>/dev/null || true)"
      if [[ -n "$holder" ]] && ! kill -0 "$holder" 2>/dev/null; then
        # Holder is dead → take over.
        rm -f "$pid_file" 2>/dev/null || true
        rmdir "$lock_dir" 2>/dev/null || true
        if mkdir "$lock_dir" 2>/dev/null; then
          printf '%s\n' "$$" > "$pid_file" 2>/dev/null || true
          echo "x-worktree-isolate: took over stale lock (PID $holder was not alive)" >&2
          return 0
        fi
      fi
    fi
    sleep 0.2
  done
  echo "x-worktree-isolate: could not acquire registry lock at $lock_dir after 50 retries (~10s)." >&2
  echo "If no other apply/release is running, remove it manually: rm -rf '$lock_dir'" >&2
  return 1
}

xwi_release_lock() {
  local lock_dir pid_file
  lock_dir="$(xwi_registry_lock_dir)" 2>/dev/null || return 0
  pid_file="$lock_dir/pid"
  # Only release if we own it (PID match) — guards against the rare case
  # where a stale-takeover happened and the original holder revives.
  if [[ -f "$pid_file" ]]; then
    local holder
    holder="$(cat "$pid_file" 2>/dev/null || true)"
    [[ "$holder" != "$$" ]] && return 0
    rm -f "$pid_file" 2>/dev/null || true
  fi
  rmdir "$lock_dir" 2>/dev/null || true
}

# --- Registry I/O (jq-free, python3-based) ---
xwi_read_registry() {
  local file
  file="$(xwi_registry_file)" || return 1
  if [[ ! -f "$file" ]]; then
    echo '{"slots": []}'
    return 0
  fi
  cat "$file"
}

# Write registry from JSON on stdin to file (atomic via mktemp + mv).
xwi_write_registry() {
  local file tmp
  file="$(xwi_registry_file)" || return 1
  tmp="$(mktemp "${file}.XXXXXX")"
  cat > "$tmp"
  mv "$tmp" "$file"
}

# Allocate the next free slot index for a given worktree path.
# Echoes the slot integer on stdout.
xwi_allocate_slot() {
  local worktree_path="$1"
  python3 - "$worktree_path" "$(xwi_registry_file)" <<'PY'
import json, os, sys
worktree = sys.argv[1]
path = sys.argv[2]
data = {"slots": []}
if os.path.isfile(path):
    with open(path) as fh:
        try:
            data = json.load(fh)
        except json.JSONDecodeError:
            data = {"slots": []}
slots = data.get("slots", [])
# If this worktree already has a slot, reuse it (idempotent re-apply).
for entry in slots:
    if entry.get("worktree_path") == worktree:
        print(entry["slot"])
        sys.exit(0)
used = {entry.get("slot") for entry in slots}
n = 0
while n in used:
    n += 1
print(n)
PY
}

# Test if a TCP port is already bound (lsof). Returns 0 if bound, 1 if free.
xwi_port_bound() {
  local port="$1"
  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null | grep -q LISTEN
  else
    # Fallback: bash /dev/tcp probe (works on Linux/macOS bash 4+ and bash 3.2 on macOS).
    (echo > "/dev/tcp/127.0.0.1/$port") >/dev/null 2>&1
  fi
}

# Compute candidate port for slot N: default + N*1000, scan upward on collision.
# Args: default_port slot scan_low scan_high claimed_csv
# Echoes selected port, or empty + non-zero exit on exhaustion.
xwi_pick_port() {
  local default="$1" slot="$2" lo="$3" hi="$4" claimed="$5"
  local candidate=$(( default + slot * 1000 ))
  if (( candidate < lo )); then candidate="$lo"; fi
  while (( candidate <= hi )); do
    # Fix #2: whole-token compare, not substring (avoids 8789 matching ,18789,).
    local found=0 p
    if [[ -n "$claimed" ]]; then
      local IFS=','
      for p in $claimed; do
        if [[ "$p" == "$candidate" ]]; then found=1; break; fi
      done
      unset IFS
    fi
    if (( found == 0 )) && ! xwi_port_bound "$candidate"; then
      echo "$candidate"
      return 0
    fi
    candidate=$(( candidate + 1 ))
  done
  echo "x-worktree-isolate: port range exhausted scanning from $((default + slot * 1000)) up to $hi" >&2
  return 1
}

# Persist a claim in the registry. Args: slot worktree_path branch ports_json data_dir
xwi_claim_slot() {
  local slot="$1" wpath="$2" branch="$3" ports_json="$4" data_dir="$5"
  python3 - "$slot" "$wpath" "$branch" "$ports_json" "$data_dir" "$(xwi_registry_file)" "$$" <<'PY'
import json, os, sys, time
slot, wpath, branch, ports_json, data_dir, path, pid = sys.argv[1:]
slot = int(slot)
ports = json.loads(ports_json)
data = {"slots": []}
if os.path.isfile(path):
    with open(path) as fh:
        try: data = json.load(fh)
        except json.JSONDecodeError: data = {"slots": []}
slots = [s for s in data.get("slots", []) if s.get("worktree_path") != wpath and s.get("slot") != slot]
slots.append({
    "slot": slot,
    "worktree_path": wpath,
    "branch": branch,
    "ports": ports,
    "data_dir": data_dir,
    "pid": int(pid),
    "allocated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
})
slots.sort(key=lambda s: s["slot"])
data["slots"] = slots
tmp = path + ".tmp"
with open(tmp, "w") as fh:
    json.dump(data, fh, indent=2)
os.replace(tmp, path)
PY
}

# Release a slot by worktree path.
xwi_release_slot() {
  local wpath="$1"
  python3 - "$wpath" "$(xwi_registry_file)" <<'PY'
# Fix #12: surface JSON parse errors instead of silently leaking the slot.
import json, os, sys
wpath, path = sys.argv[1:]
if not os.path.isfile(path):
    sys.exit(0)
try:
    with open(path) as fh:
        data = json.load(fh)
except json.JSONDecodeError as e:
    print(f"x-worktree-isolate release: registry file is not valid JSON: {path}: {e}", file=sys.stderr)
    print("  Inspect the file and fix or remove it manually before re-running release.", file=sys.stderr)
    sys.exit(2)
slots = [s for s in data.get("slots", []) if s.get("worktree_path") != wpath]
data["slots"] = slots
tmp = path + ".tmp"
with open(tmp, "w") as fh:
    json.dump(data, fh, indent=2)
os.replace(tmp, path)
PY
}

# All currently claimed host ports as a comma-separated string.
xwi_claimed_ports_csv() {
  python3 - "$(xwi_registry_file)" <<'PY'
import json, os, sys
path = sys.argv[1]
if not os.path.isfile(path):
    sys.exit(0)
with open(path) as fh:
    try: data = json.load(fh)
    except json.JSONDecodeError: sys.exit(0)
ports = []
for s in data.get("slots", []):
    for v in (s.get("ports") or {}).values():
        ports.append(str(v))
print(",".join(ports))
PY
}

xwi_list_slots() {
  local file
  file="$(xwi_registry_file)" || return 1
  if [[ ! -f "$file" ]]; then
    echo "x-worktree-isolate: registry empty (no slots claimed)"
    return 0
  fi
  python3 - "$file" <<'PY'
import json, sys
with open(sys.argv[1]) as fh:
    try: data = json.load(fh)
    except json.JSONDecodeError:
        print("x-worktree-isolate: registry file is not valid JSON")
        sys.exit(1)
slots = data.get("slots", [])
owners = data.get("singleton_owners", {}) or {}
# Reverse map worktree_path -> [ids] for the owner column.
by_path = {}
for sid, o in owners.items():
    if isinstance(o, dict):
        by_path.setdefault(o.get("worktree_path", ""), []).append(sid)
if not slots:
    print("x-worktree-isolate: registry empty (no slots claimed)")
    sys.exit(0)
print(f"slot  branch                       owns                   ports                                     worktree_path")
for s in slots:
    own = ",".join(sorted(by_path.get(s.get("worktree_path", ""), []))) or "-"
    ports = ",".join(f"{k}={v}" for k, v in (s.get("ports") or {}).items())
    print(f"{s.get('slot'):<5} {str(s.get('branch') or '')[:28]:<28} {own[:22]:<22} {ports[:40]:<40}  {s.get('worktree_path')}")
PY
}

# --- Registry schema marker ---
XWI_REGISTRY_SCHEMA=2

# Lock-free registry heal. ASSUMES the caller already holds the registry lock.
# 1. Stamp registry_schema:2 (idempotent).
# 2. Upgrade flat singleton_owners {id: path} → {id: {worktree_path, branch, claimed_at}}.
# 3. Rebuild owners from GROUND TRUTH: each live slot's feature-overrides.local.json.
#    - live slot = worktree_path is a dir AND still has a registry slot.
#    - if 2+ live slots enable the same id → leave it UNOWNED (pre-existing conflict;
#      surfaced by callers via xwi_claim_singleton refusal). heal never elects a winner.
xwi_heal_registry() {
  local file
  file="$(xwi_registry_file)" || return 1
  [[ -f "$file" ]] || return 0
  python3 - "$file" "$XWI_REGISTRY_SCHEMA" <<'PY'
import json, os, sys, time
path, schema = sys.argv[1], int(sys.argv[2])
try:
    data = json.load(open(path))
except json.JSONDecodeError:
    sys.exit(0)  # malformed registry: leave for release.sh's explicit error path.
slots = data.get("slots", []) or []
now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

def overrides_for(slot):
    wt = slot.get("worktree_path") or ""
    if not os.path.isdir(wt):
        return None  # dead slot.
    ov = os.path.join(wt, ".worktree-isolate", "feature-overrides.local.json")
    enabled, updated = [], now
    if os.path.isfile(ov):
        try:
            o = json.load(open(ov))
            updated = o.get("updated_at") or now
            for e in o.get("overrides", []):
                if isinstance(e, dict) and e.get("state") == "enabled" and e.get("id"):
                    enabled.append(e["id"])
        except (OSError, json.JSONDecodeError):
            pass
    return {"branch": slot.get("branch") or "", "wt": wt, "enabled": enabled, "updated_at": updated}

# Ground-truth: id -> list of (wt, branch, claimed_at) claiming it.
claims = {}
for s in slots:
    info = overrides_for(s)
    if info is None:
        continue
    for sid in info["enabled"]:
        claims.setdefault(sid, []).append(
            {"worktree_path": info["wt"], "branch": info["branch"], "claimed_at": info["updated_at"]}
        )

owners = {}
for sid, lst in claims.items():
    if len(lst) == 1:
        owners[sid] = lst[0]
    # len >= 2 → pre-existing conflict → leave UNOWNED (claim refuses, migrate reports).

data["registry_schema"] = schema
data["singleton_owners"] = owners
tmp = path + ".tmp"
with open(tmp, "w") as fh:
    json.dump(data, fh, indent=2)
os.replace(tmp, path)
PY
}

# Echo the JSON object for a singleton owner (or empty string if unowned).
xwi_singleton_owner_json() {
  local sid="$1"
  python3 - "$sid" "$(xwi_registry_file)" <<'PY'
import json, os, sys
sid, path = sys.argv[1], sys.argv[2]
if not os.path.isfile(path): sys.exit(0)
try: data = json.load(open(path))
except json.JSONDecodeError: sys.exit(0)
o = (data.get("singleton_owners") or {}).get(sid)
if o: print(json.dumps(o))
PY
}

# Report ids enabled by 2+ live slots (pre-existing conflicts). One line per id:
#   <id>|<branch1>@<path1>,<branch2>@<path2>
xwi_preexisting_conflicts() {
  python3 - "$(xwi_registry_file)" <<'PY'
import json, os, sys
path = sys.argv[1]
if not os.path.isfile(path): sys.exit(0)
try: data = json.load(open(path))
except json.JSONDecodeError: sys.exit(0)
claims = {}
for s in data.get("slots", []) or []:
    wt = s.get("worktree_path") or ""
    if not os.path.isdir(wt): continue
    ov = os.path.join(wt, ".worktree-isolate", "feature-overrides.local.json")
    if not os.path.isfile(ov): continue
    try: o = json.load(open(ov))
    except (OSError, json.JSONDecodeError): continue
    for e in o.get("overrides", []):
        if isinstance(e, dict) and e.get("state") == "enabled" and e.get("id"):
            claims.setdefault(e["id"], []).append(f"{s.get('branch') or ''}@{wt}")
for sid, owners in sorted(claims.items()):
    if len(owners) >= 2:
        print(f"{sid}|{','.join(owners)}")
PY
}

# Liveness test for a singleton owner. Args: owner_json tier owner_compose_project
#   DEAD when: owner worktree_path is gone from disk; OR no longer holds a registry slot
#     (ALL tiers); OR (compose tier only) COMPOSE_PROJECT_NAME has zero running containers.
#   env-flag / host tiers: path + slot signal only.
# Returns 0 = ALIVE, 1 = DEAD.
xwi_owner_alive() {
  local owner_json="$1" tier="$2" proj="$3"
  local owner_path
  owner_path="$(printf '%s' "$owner_json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("worktree_path",""))')"
  [[ -n "$owner_path" && -d "$owner_path" ]] || return 1            # path gone → dead (all tiers)
  # Still holds a registry slot?
  local has_slot
  has_slot="$(python3 - "$owner_path" "$(xwi_registry_file)" <<'PY'
import json, os, sys
wt, path = sys.argv[1], sys.argv[2]
if not os.path.isfile(path): print("0"); sys.exit(0)
try: d = json.load(open(path))
except json.JSONDecodeError: print("0"); sys.exit(0)
print("1" if any(s.get("worktree_path") == wt for s in d.get("slots", []) or []) else "0")
PY
)"
  [[ "$has_slot" == "1" ]] || return 1                              # no slot → dead (all tiers)
  if [[ "$tier" == "compose-service" && -n "$proj" ]]; then
    if command -v docker >/dev/null 2>&1; then
      local running
      running="$(docker ps --filter "label=com.docker.compose.project=${proj}" -q 2>/dev/null | head -n1)"
      [[ -n "$running" ]] || return 1                               # zero containers → dead (R3)
    fi
    # no docker → cannot prove zero-containers; fall back to path/slot signal = ALIVE.
  fi
  return 0
}

# Disable singleton $sid in EVERY live worktree's feature-overrides EXCEPT $keep,
# so the next heal elects $keep as the sole owner. Used by --force/--steal to make a
# live-owner / pre-existing-conflict steal durable (heal rebuilds from ground truth, so
# stealing the registry slot alone is not enough — the loser's override must be cleared).
# ASSUMES caller holds the registry lock.
xwi_force_release_others() {
  local sid="$1" keep="$2"
  python3 - "$sid" "$keep" "$(xwi_registry_file)" <<'PY'
import json, os, sys, time
sid, keep, reg = sys.argv[1], sys.argv[2], sys.argv[3]
if not os.path.isfile(reg): sys.exit(0)
try: data = json.load(open(reg))
except json.JSONDecodeError: sys.exit(0)
now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
for s in data.get("slots", []) or []:
    wt = s.get("worktree_path") or ""
    if not wt or wt == keep or not os.path.isdir(wt): continue
    ov = os.path.join(wt, ".worktree-isolate", "feature-overrides.local.json")
    if not os.path.isfile(ov): continue
    try: o = json.load(open(ov))
    except (OSError, json.JSONDecodeError): continue
    changed = False
    for e in o.get("overrides", []):
        if isinstance(e, dict) and e.get("id") == sid and e.get("state") == "enabled":
            e["state"] = "disabled"; changed = True
    if changed:
        o["updated_at"] = now
        tmp = ov + ".tmp"
        with open(tmp, "w") as fh: json.dump(o, fh, indent=2)
        os.replace(tmp, ov)
PY
}

# Claim ONE singleton id for this worktree. ASSUMES caller holds the registry lock
# AND has already run xwi_heal_registry.
# Args: id worktree_path branch tier compose_project force(0|1)
# Returns: 0 claimed; 2 refused (SINGLETON_CONFLICT or SINGLETON_CONFLICT_PREEXISTING).
xwi_claim_singleton() {
  local sid="$1" wpath="$2" branch="$3" tier="$4" proj="$5" force="${6:-0}"

  # Pre-existing conflict: id enabled by 2+ live slots → unowned by heal.
  # --force resolves it in our favor by clearing the other claimants' overrides.
  local pre
  pre="$(xwi_preexisting_conflicts | grep -F "${sid}|" || true)"
  if [[ -n "$pre" ]]; then
    if [[ "$force" -eq 1 ]]; then
      xwi_force_release_others "$sid" "$wpath"
      echo "SINGLETON_LOCK_STOLEN=${sid} from=preexisting" >&2
    else
      local owners="${pre#*|}"
      echo "SINGLETON_CONFLICT_PREEXISTING=${sid} owners=${owners}" >&2
      echo "  Resolve: run 'x-worktree-isolate disable ${sid}' in the loser worktree, then retry (or pass --force)." >&2
      return 2
    fi
  fi

  local owner_json owner_path owner_branch
  owner_json="$(xwi_singleton_owner_json "$sid")"
  if [[ -n "$owner_json" ]]; then
    owner_path="$(printf '%s' "$owner_json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("worktree_path",""))')"
    owner_branch="$(printf '%s' "$owner_json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("branch",""))')"
    if [[ "$owner_path" == "$wpath" ]]; then
      :  # owned by self → re-claim (refresh claimed_at below).
    elif xwi_owner_alive "$owner_json" "$tier" "$proj"; then
      if [[ "$force" -eq 1 ]]; then
        xwi_force_release_others "$sid" "$wpath"   # clear the live owner's override so heal won't re-conflict
        echo "SINGLETON_LOCK_STOLEN=${sid} from=${owner_branch}" >&2
      else
        echo "SINGLETON_CONFLICT=${sid} owner=${owner_branch}@${owner_path}" >&2
        return 2
      fi
    else
      # Dead owner → auto-steal. Clear its stale override too: a path-gone owner has no
      # override to clear (xwi_force_release_others skips non-dir paths), but a compose-tier
      # R3-dead owner (containers down, path alive) keeps an enabled override that heal would
      # otherwise count as a live claimant → SINGLETON_CONFLICT_PREEXISTING on the next apply.
      xwi_force_release_others "$sid" "$wpath"
      echo "SINGLETON_LOCK_STOLEN=${sid} from=${owner_branch}" >&2   # dead → auto-steal
    fi
  fi

  # Write the enriched owner entry.
  python3 - "$sid" "$wpath" "$branch" "$(xwi_registry_file)" "$XWI_REGISTRY_SCHEMA" <<'PY'
import json, os, sys, time
sid, wpath, branch, path, schema = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], int(sys.argv[5])
data = {"slots": []}
if os.path.isfile(path):
    try: data = json.load(open(path))
    except json.JSONDecodeError: data = {"slots": []}
owners = data.get("singleton_owners") or {}
owners[sid] = {"worktree_path": wpath, "branch": branch,
               "claimed_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
data["singleton_owners"] = owners
data["registry_schema"] = schema
tmp = path + ".tmp"
with open(tmp, "w") as fh: json.dump(data, fh, indent=2)
os.replace(tmp, path)
PY
  return 0
}

# --- Singleton ownership (enforced) ---
# Set this worktree's owned set to EXACTLY $ids (SYNC, not additive):
#   - claim every id in $ids (refuse→propagate exit 2);
#   - drop self-owned ids NOT in $ids (this is how `disable` releases ownership).
# Args: ids_csv worktree_path branch tiers_json force(0|1)
#   tiers_json maps id -> {"tier":..., "proj":...} so the claim can run liveness.
# ASSUMES caller holds the lock AND has run xwi_heal_registry.
# Returns 0 if all claims succeed; 2 if any id is refused (caller decides hard-fail).
xwi_sync_singleton_owners() {
  local ids_csv="$1" wpath="$2" branch="$3" tiers_json="$4" force="${5:-0}"
  local rc=0 sid tier proj
  # Drop self-owned ids not in the new set.
  python3 - "$ids_csv" "$wpath" "$(xwi_registry_file)" <<'PY'
import json, os, sys
ids = set(i for i in sys.argv[1].split(",") if i)
wpath, path = sys.argv[2], sys.argv[3]
if not os.path.isfile(path): sys.exit(0)
try: data = json.load(open(path))
except json.JSONDecodeError: sys.exit(0)
owners = data.get("singleton_owners") or {}
owners = {k: v for k, v in owners.items()
          if not (isinstance(v, dict) and v.get("worktree_path") == wpath and k not in ids)}
data["singleton_owners"] = owners
tmp = path + ".tmp"
with open(tmp, "w") as fh: json.dump(data, fh, indent=2)
os.replace(tmp, path)
PY
  # Claim each enabled id.
  local IFS=','
  for sid in $ids_csv; do
    [[ -n "$sid" ]] || continue
    tier="$(printf '%s' "$tiers_json" | python3 -c 'import json,sys; print((json.load(sys.stdin).get(sys.argv[1]) or {}).get("tier",""))' "$sid")"
    proj="$(printf '%s' "$tiers_json" | python3 -c 'import json,sys; print((json.load(sys.stdin).get(sys.argv[1]) or {}).get("proj",""))' "$sid")"
    xwi_claim_singleton "$sid" "$wpath" "$branch" "$tier" "$proj" "$force" || rc=2
  done
  unset IFS
  return "$rc"
}

xwi_clear_singleton_owners_for() {
  local wpath="$1"
  python3 - "$wpath" "$(xwi_registry_file)" <<'PY'
import json, os, sys
wpath, path = sys.argv[1], sys.argv[2]
if not os.path.isfile(path): sys.exit(0)
try: data = json.load(open(path))
except json.JSONDecodeError: sys.exit(0)
owners = data.get("singleton_owners") or {}
owners = {k: v for k, v in owners.items()
          if not (isinstance(v, dict) and v.get("worktree_path") == wpath)}
data["singleton_owners"] = owners
tmp = path + ".tmp"
with open(tmp, "w") as fh: json.dump(data, fh, indent=2)
os.replace(tmp, path)
PY
}

# CLI passthrough so dispatch.sh can call `allocate-ports.sh list`.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  case "${1:-}" in
    list)
      if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        xwi_acquire_lock && { xwi_heal_registry; xwi_release_lock; }
      fi
      xwi_list_slots
      ;;
    *) echo "usage: allocate-ports.sh list" >&2; exit 1 ;;
  esac
fi
