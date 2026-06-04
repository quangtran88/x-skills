#!/usr/bin/env bash
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
INIT="$SKILL_DIR/scripts/init.sh"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
cd "$WORK"; git init -q

cat > profile.json <<'JSON'
{ "schema":1, "version":"1.0.0", "primary_entry_point":"api",
  "entry_points":[{"name":"api","type":"http","auto_managed":true,"primary":true,"verified":false,
    "launch":{"kind":"command","command":"true"},
    "base_url_template":"http://localhost:1","base_url_fallback":"http://localhost:1",
    "health":{"method":"GET","path":"/","expected_status":200}}] }
JSON
printf '# QA Memory — test\n\n## Channels\n\n### api (driver: http)\n' > memory.md

"$INIT" --profile-json profile.json --memory-md memory.md >/dev/null

pass=0; fail=0
[[ -f .x-skills/x-qa/QA_MEMORY.md ]] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: QA_MEMORY.md not written"; }
grep -q "## Channels" .x-skills/x-qa/QA_MEMORY.md && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: content not copied"; }
# QA_MEMORY.md must NOT be gitignored (git-tracked team memory)
! grep -q "QA_MEMORY.md" .gitignore && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: QA_MEMORY.md must not be gitignored"; }

echo "qa-memory: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
