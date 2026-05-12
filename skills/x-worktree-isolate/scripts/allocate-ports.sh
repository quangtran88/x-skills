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
  for i in 1 2 3 4 5; do
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
  echo "x-worktree-isolate: could not acquire registry lock at $lock_dir after 5 retries." >&2
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
if not slots:
    print("x-worktree-isolate: registry empty (no slots claimed)")
    sys.exit(0)
print(f"slot  branch                              ports                                     worktree_path")
for s in slots:
    ports = ",".join(f"{k}={v}" for k, v in (s.get("ports") or {}).items())
    print(f"{s.get('slot'):<5} {str(s.get('branch') or '')[:36]:<36} {ports[:40]:<40}  {s.get('worktree_path')}")
PY
}

# --- Singleton ownership (declarative bookkeeping) ---
# Records which worktree currently has each singleton enabled. Not a runtime
# lock — the env-flag in .env.worktree is what actually prevents dual-execution.
xwi_set_singleton_owners() {
  local wpath="$1" ids="$2"
  python3 - "$wpath" "$ids" "$(xwi_registry_file)" <<'PY'
import json, os, sys
wpath, ids_csv, path = sys.argv[1:]
ids = [i for i in ids_csv.split(",") if i]
data = {"slots": [], "singleton_owners": {}}
if os.path.isfile(path):
    try: data = json.load(open(path))
    except json.JSONDecodeError: data = {"slots": [], "singleton_owners": {}}
owners = data.get("singleton_owners") or {}
owners = {k: v for k, v in owners.items() if v != wpath}
for sid in ids:
    owners[sid] = wpath
data["singleton_owners"] = owners
tmp = path + ".tmp"
with open(tmp, "w") as fh: json.dump(data, fh, indent=2)
os.replace(tmp, path)
PY
}

xwi_clear_singleton_owners_for() {
  local wpath="$1"
  xwi_set_singleton_owners "$wpath" ""
}

# CLI passthrough so dispatch.sh can call `allocate-ports.sh list`.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  case "${1:-}" in
    list) xwi_list_slots ;;
    *) echo "usage: allocate-ports.sh list" >&2; exit 1 ;;
  esac
fi
