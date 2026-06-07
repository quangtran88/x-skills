#!/usr/bin/env bash
# Test 29: dispatch VERSION, config.json version, and `version` output all agree at 0.3.1.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t29
trap test_teardown EXIT

CFG_VER="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$SKILL_DIR/config.json")"
assert_eq "0.3.1" "$CFG_VER" "config.json version must be 0.3.1"

REPO="$TEST_TMP/r"; make_repo "$REPO"
ver_out="$(cd "$REPO" && bash "$DISPATCH" version)"
assert_contains "$ver_out" "0.3.1" "dispatch version output must be 0.3.1"

pass "test 29 — version constants consistent at 0.3.1"
