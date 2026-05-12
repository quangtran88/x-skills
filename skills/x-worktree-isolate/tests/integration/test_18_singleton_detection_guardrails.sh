#!/usr/bin/env bash
# Test 18: env-flag detection respects exclude_dirs + max_file_bytes + max_depth.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t18
trap test_teardown EXIT

MAIN="$TEST_TMP/main"
make_repo "$MAIN"

# Source that SHOULD match (depth 1, normal file).
mkdir -p "$MAIN/src"
cat > "$MAIN/src/scheduler.js" <<'JS'
const cron = require('node-cron');
cron.schedule('* * * * *', () => console.log('tick'));
JS

# Source that SHOULD NOT match — inside node_modules (excluded).
mkdir -p "$MAIN/node_modules/somepkg"
cat > "$MAIN/node_modules/somepkg/index.js" <<'JS'
require('node-cron');
JS

# Source that SHOULD NOT match — too deep.
mkdir -p "$MAIN/a/b/c/d/e/f"
cat > "$MAIN/a/b/c/d/e/f/deep.js" <<'JS'
require('node-cron');
JS

# Source that SHOULD NOT match — too big.
mkdir -p "$MAIN/big"
python3 -c 'import os,sys; open(sys.argv[1],"w").write("// pad\n"*200000 + "require(\"node-cron\")")' "$MAIN/big/huge.js"

DETECT="$SKILL_DIR/scripts/detect-singletons.py"
guard='{"scan_max_depth":4,"scan_max_file_bytes":1048576,"exclude_dirs":["node_modules"],"exclude_globs":[]}'
out_json="$(python3 "$DETECT" --repo "$MAIN" --guardrails "$guard")"

echo "$out_json" | python3 -c '
import json, sys
data = json.load(sys.stdin)
candidates = data.get("singletons", [])
node_cron = [c for c in candidates if c["id"] == "node-cron"]
assert len(node_cron) == 1, f"expected exactly 1 node-cron hit, got {len(node_cron)}: {node_cron}"
ev = node_cron[0]["evidence"][0]
assert "src/scheduler.js" in ev, f"hit must be src/scheduler.js, got {ev}"
assert "node_modules" not in str(candidates), "must not scan node_modules"
print("ok")
'

pass "test 18 — env-flag detection respects guardrails"
