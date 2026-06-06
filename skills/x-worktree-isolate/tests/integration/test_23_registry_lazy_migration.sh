#!/usr/bin/env bash
# Test 23: old flat singleton_owners migrates lazily to enriched registry_schema:2, idempotent.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t23
trap test_teardown EXIT

MAIN="$TEST_TMP/main"
make_repo "$MAIN"
write_profile "$MAIN"
commit_profile "$MAIN"

WT="$TEST_TMP/wt23"
make_worktree "$MAIN" "$WT" "feat-x"

# Seed an OLD-shape registry by hand: flat singleton_owners, NO registry_schema marker.
REG_DIR="$(cd "$WT" && . "$SKILL_DIR/scripts/allocate-ports.sh" && xwi_registry_dir)"
REG="$REG_DIR/registry.json"
cat > "$REG" <<JSON
{"slots": [{"slot": 0, "worktree_path": "$WT", "branch": "feat-x", "ports": {}, "data_dir": ""}],
 "singleton_owners": {"slack-listener": "$WT"}}
JSON

# Heal under lock (apply triggers heal as its first registry action).
( cd "$WT" && bash "$DISPATCH" apply --quiet )

# Assert: registry_schema:2 marker present, owner enriched to object with worktree_path.
python3 - "$REG" "$WT" <<'PY'
import json, sys
reg, wt = sys.argv[1], sys.argv[2]
d = json.load(open(reg))
assert d.get("registry_schema") == 2, f"expected registry_schema:2, got {d.get('registry_schema')}"
owners = d.get("singleton_owners", {})
# slack-listener was not in a profile/feature-overrides, so heal drops it (ground-truth rebuild).
assert "slack-listener" not in owners, f"stale owner should be dropped by heal, got {owners}"
print("ok-shape")
PY

# Idempotency: re-run apply, registry_schema stays 2, no duplication / crash.
( cd "$WT" && bash "$DISPATCH" apply --quiet )
python3 - "$REG" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
assert d.get("registry_schema") == 2
print("ok-idempotent")
PY

pass "test 23 — registry lazy migration to schema 2, idempotent"
