#!/usr/bin/env bash
# lib.sh — shared helpers for x-worktree-isolate integration tests.
# Bash 3.2 portable (no mapfile, no associative arrays, no ${var,,}).

set -euo pipefail

# Resolve plugin paths.
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SKILL_DIR="$(cd "$TESTS_DIR/../.." && pwd -P)"
PLUGIN_DIR="$(cd "$SKILL_DIR/../.." && pwd -P)"
DISPATCH="$SKILL_DIR/scripts/dispatch.sh"
APPLY_BIN="bash $DISPATCH apply"
RELEASE_BIN="bash $DISPATCH release"
LIST_BIN="bash $DISPATCH list"

# Each test gets its own XDG_CONFIG_HOME so the registry is isolated.
test_setup() {
  local test_name="$1"
  TEST_TMP="$(mktemp -d -t "xwi-test-${test_name}.XXXXXX")"
  export XDG_CONFIG_HOME="$TEST_TMP/xdg"
  mkdir -p "$XDG_CONFIG_HOME"
  cd "$TEST_TMP"
}

test_teardown() {
  if [ -n "${TEST_TMP:-}" ] && [ -d "$TEST_TMP" ]; then
    rm -rf "$TEST_TMP"
  fi
}

# Make a git repo in $1 with one initial commit.
make_repo() {
  local dir="$1"
  mkdir -p "$dir"
  (
    cd "$dir"
    git init -q -b main
    git config user.email "test@test"
    git config user.name "test"
    echo "init" > README
    git add README
    git commit -q -m init
  )
}

# Write a synthetic profile.json into <main-repo>/.worktree-isolate/.
# $1 = repo path, $2 = profile body (json, defaults to a minimal valid profile).
write_profile() {
  local repo="$1"
  local body="${2:-}"
  mkdir -p "$repo/.worktree-isolate"
  if [ -z "$body" ]; then
    body='{
  "schema": 2,
  "stack": "compose",
  "port_strategy": {
    "scan_range": [18000, 29999],
    "ports": [
      {"var": "POSTGRES_PORT", "service": "db", "default": 5432, "container_port": 5432},
      {"var": "REDIS_PORT", "service": "cache", "default": 6379, "container_port": 6379}
    ]
  },
  "services_to_strip": [
    {"service": "db", "container_name": "myapp_db", "ports": [{"var": "POSTGRES_PORT", "container_port": 5432}]},
    {"service": "cache", "container_name": "myapp_cache", "ports": [{"var": "REDIS_PORT", "container_port": 6379}]}
  ],
  "data_dirs": [
    {"var": "PG_DATA", "default_relative": "./data/pg", "per_worktree": true}
  ],
  "global_label_warnings": [],
  "single_worktree_profiles": []
,"singletons": [], "detection_guardrails": {"scan_max_depth": 4, "scan_max_file_bytes": 1048576, "exclude_dirs": [], "exclude_globs": []}}'
  fi
  printf '%s\n' "$body" > "$repo/.worktree-isolate/profile.json"
}

# Add + commit profile (so linked worktrees inherit it via the main checkout).
commit_profile() {
  local repo="$1"
  (
    cd "$repo"
    git add .worktree-isolate/profile.json
    git commit -q -m "add profile"
  )
}

# Provision a linked worktree at $2 from $1 on branch $3.
make_worktree() {
  local main="$1" wt_path="$2" branch="$3"
  (cd "$main" && git worktree add -b "$branch" "$wt_path" main >/dev/null 2>&1)
}

# Simulate x-worktree's step 6.5 logic. Runs from inside <wt_path>.
# Echoes envelope additions (ISOLATE_APPLIED, ISOLATE_REASON, ISOLATE_HINT) on stdout.
# $1 = wt_path, $2 = mode (default | no-isolate | env-disabled | binary-missing)
sim_step_6_5() {
  local wt_path="$1" mode="${2:-default}"

  # --no-isolate: omit line entirely
  if [ "$mode" = "no-isolate" ]; then
    return 0
  fi

  # XWI_AUTO_ISOLATE=0
  if [ "$mode" = "env-disabled" ] || [ "${XWI_AUTO_ISOLATE:-}" = "0" ]; then
    echo "ISOLATE_APPLIED=skipped"
    echo "ISOLATE_REASON=env-disabled"
    return 0
  fi

  # binary-missing
  if [ "$mode" = "binary-missing" ]; then
    echo "ISOLATE_APPLIED=skipped"
    echo "ISOLATE_REASON=binary-missing"
    return 0
  fi

  local stderr_file rel_stderr_file rc
  stderr_file="$(mktemp -t xwi-stderr.XXXXXX)"
  rel_stderr_file="$(mktemp -t xwi-rel.XXXXXX)"

  # Run apply --quiet --if-profile-exists from inside the worktree.
  set +e
  ( cd "$wt_path" && bash "$DISPATCH" apply --quiet --if-profile-exists ) 2>"$stderr_file"
  rc=$?
  set -e

  if [ "$rc" -eq 0 ]; then
    if [ -f "$wt_path/.worktree-isolate/state.local.json" ]; then
      echo "ISOLATE_APPLIED=true"
    else
      echo "ISOLATE_APPLIED=skipped"
      echo "ISOLATE_REASON=no-profile"
    fi
    rm -f "$stderr_file" "$rel_stderr_file"
    return 0
  fi

  # Failure path. Sanitize stderr.
  local reason
  reason="$(LC_ALL=C tr -cd '\11\12\15\40-\176' < "$stderr_file" | tr '\n\r\t' ' ' | head -c 200)"
  if [ "$rc" -eq 124 ]; then
    reason="apply-timeout-5s"
  fi

  # Orphan cleanup.
  rm -f "$wt_path/.worktree-isolate/state.local.json"
  set +e
  ( cd "$wt_path" && bash "$DISPATCH" release --quiet ) 2>"$rel_stderr_file" || true
  set -e

  echo "ISOLATE_APPLIED=false"
  echo "ISOLATE_REASON=$reason"

  local hint="run x-worktree-isolate apply manually to retry"
  if [ -s "$rel_stderr_file" ]; then
    local rel_reason
    rel_reason="$(LC_ALL=C tr -cd '\11\12\15\40-\176' < "$rel_stderr_file" | tr '\n\r\t' ' ' | head -c 100)"
    hint="${hint}; release-failed: ${rel_reason}"
  fi
  echo "ISOLATE_HINT=$hint"

  rm -f "$stderr_file" "$rel_stderr_file"
}

# Assert helpers (bash 3.2 portable).
assert_eq() {
  local expected="$1" actual="$2" msg="${3:-assertion failed}"
  if [ "$expected" != "$actual" ]; then
    echo "FAIL: $msg"
    echo "  expected: $expected"
    echo "  actual:   $actual"
    return 1
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" msg="${3:-assertion failed}"
  case "$haystack" in
    *"$needle"*) return 0 ;;
    *)
      echo "FAIL: $msg"
      echo "  haystack: $haystack"
      echo "  needle:   $needle"
      return 1
      ;;
  esac
}

assert_file_exists() {
  local path="$1" msg="${2:-file should exist}"
  if [ ! -f "$path" ]; then
    echo "FAIL: $msg"
    echo "  path: $path"
    return 1
  fi
}

assert_file_absent() {
  local path="$1" msg="${2:-file should NOT exist}"
  if [ -f "$path" ]; then
    echo "FAIL: $msg"
    echo "  path: $path"
    return 1
  fi
}

# Read a field from state.local.json via python3.
state_field() {
  local file="$1" field="$2"
  python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get(sys.argv[2], ""))' "$file" "$field"
}

# Count slots in the registry.
registry_slots_count() {
  local reg
  reg="${XDG_CONFIG_HOME}/worktree-isolate"
  if [ ! -d "$reg" ]; then
    echo 0
    return
  fi
  python3 -c '
import json, os, sys
root = sys.argv[1]
total = 0
for repo_id in os.listdir(root):
    f = os.path.join(root, repo_id, "registry.json")
    if not os.path.isfile(f): continue
    with open(f) as fh:
        try: total += len(json.load(fh).get("slots", []))
        except json.JSONDecodeError: pass
print(total)
' "$reg"
}

# Detect docker. Tests requiring docker compose render are skipped without it.
have_docker() {
  command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1
}

# Print test result and bump counters in the parent shell via output.
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; return 1; }
skip() { echo "SKIP: $1 ($2)"; }
