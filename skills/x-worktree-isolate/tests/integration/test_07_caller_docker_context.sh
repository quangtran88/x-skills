#!/usr/bin/env bash
# Test 7: caller (simulating x-do --wt) reads state.local.json and builds DOCKER CONTEXT block.
# Verifies the caller-integration.md DOCKER CONTEXT block matches the schema-v1 contract.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t07
trap test_teardown EXIT

MAIN="$TEST_TMP/main"
make_repo "$MAIN"
write_profile "$MAIN"
commit_profile "$MAIN"

WT="$TEST_TMP/wt"
make_worktree "$MAIN" "$WT" "feat-x"

out="$(sim_step_6_5 "$WT" default)"
assert_contains "$out" "ISOLATE_APPLIED=true" "apply must succeed"

# Caller's contract: read state.local.json, validate schema, build DOCKER CONTEXT block.
state_file="$WT/.worktree-isolate/state.local.json"
schema="$(state_field "$state_file" schema)"
assert_eq "1" "$schema" "schema must be 1"

cpn="$(state_field "$state_file" compose_project_name)"
data_dir="$(state_field "$state_file" data_dir_path)"
ports="$(python3 -c '
import json,sys
d = json.load(open(sys.argv[1]))
print(", ".join(f"{k}={v}" for k,v in d["allocated_ports"].items()))
' "$state_file")"

# Reconstruct launch command (no .env present in this fixture).
launch="docker compose --env-file .env.worktree"
[ -f "$WT/.env" ] && launch="docker compose --env-file .env --env-file .env.worktree"

# Build the DOCKER CONTEXT block.
block="DOCKER CONTEXT (this worktree is isolated):
COMPOSE_PROJECT_NAME=$cpn
Allocated ports: $ports"
[ -n "$data_dir" ] && block="$block
Data dir: $data_dir"
block="$block
Launch: $launch
Use \`docker compose exec <service>\` (NOT \`docker exec <name>\`)."

# Assertions on the rendered block.
assert_contains "$block" "DOCKER CONTEXT" "block must have header"
assert_contains "$block" "COMPOSE_PROJECT_NAME=$cpn" "block must contain compose project name"
assert_contains "$block" "POSTGRES_PORT=" "block must contain POSTGRES_PORT"
assert_contains "$block" "REDIS_PORT=" "block must contain REDIS_PORT"
assert_contains "$block" "Launch: docker compose --env-file .env.worktree" "launch line must reflect no-base-env"
assert_contains "$block" "docker compose exec" "exec guidance must be present"

# Reconstruction logic must be re-evaluated at dispatch time (NOT cached from envelope).
# Helper mirrors the contract documented in caller-integration.md and context-envelope.md.
reconstruct_launch() {
  local wt="$1"
  if [ -f "$wt/.env" ]; then
    echo "docker compose --env-file .env --env-file .env.worktree"
  else
    echo "docker compose --env-file .env.worktree"
  fi
}

# Negative case: no .env present, launch must omit base --env-file.
rm -f "$WT/.env"
launch_no_env="$(reconstruct_launch "$WT")"
assert_eq "docker compose --env-file .env.worktree" "$launch_no_env" \
  "no-base-env: launch must omit --env-file .env"

# Positive case: .env present, launch must include base --env-file BEFORE .env.worktree.
echo "FOO=bar" > "$WT/.env"
launch_with_env="$(reconstruct_launch "$WT")"
assert_eq "docker compose --env-file .env --env-file .env.worktree" "$launch_with_env" \
  "base-env-present: launch must stack both --env-file flags"

# Cross-check: the two reconstructions must differ — proves reconstruction reacted to .env state change.
[ "$launch_no_env" != "$launch_with_env" ] || fail "reconstruction did not react to .env presence change"

pass "test 07 — caller DOCKER CONTEXT block"
