#!/usr/bin/env bash
# smoke.sh — end-to-end smoke for x-qa scripts (no LLM calls)
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TEST_REPO=$(mktemp -d)
TEST_REPO=$(cd "$TEST_REPO" && pwd -P)
trap 'rm -rf "$TEST_REPO"' EXIT

cd "$TEST_REPO"
git init -q

# Generate a hand-crafted profile
cat > /tmp/smoke-profile.json <<EOF
{
  "schema": 1,
  "version": "1.0.0",
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "generated_by": "x-qa-init",
  "repo_root": "$TEST_REPO",
  "primary_entry_point": "stub",
  "entry_points": [{
    "name": "stub",
    "type": "http",
    "auto_managed": true,
    "launch": { "kind": "command", "command": "true" },
    "base_url_template": "http://localhost:9999",
    "base_url_fallback": "http://localhost:9999",
    "health": { "method": "GET", "path": "/health", "expected_status": 200, "timeout_s": 5 },
    "primary": true,
    "verified": false
  }]
}
EOF

# init
"$SKILL_DIR/scripts/init.sh" --profile-json /tmp/smoke-profile.json
test -f .x-skills/x-qa/profile.json || { echo "FAIL: profile not created"; exit 1; }

# doctor
"$SKILL_DIR/scripts/doctor.sh"

# launch (will run `true`, no real service; --trust-profile bypasses TOFU for smoke)
# Capture-then-grep avoids SIGPIPE under `pipefail` when launcher writes after grep matches.
launch_out=$("$SKILL_DIR/scripts/launch-entry-point.sh" --name stub --trust-profile)
grep -q '^BASE_URL=' <<<"$launch_out"

# aggregate with synthetic case
RUN_DIR=$(mktemp -d)
mkdir "$RUN_DIR/cases"
cat > "$RUN_DIR/plan.yml" <<'EOF'
feature: smoke
entry_point: stub
test_cases:
  - id: tc-001
    category: happy
    complexity: simple
EOF
cat > "$RUN_DIR/cases/tc-001.json" <<'EOF'
{ "id": "tc-001", "verdict": "pass", "runner": "gemini-flash", "attempts": 1, "duration_ms": 100, "error": "" }
EOF
aggregate_out=$("$SKILL_DIR/scripts/aggregate-results.sh" --run-dir "$RUN_DIR" --plan "$RUN_DIR/plan.yml")
grep -q '^QA_VERDICT=pass' <<<"$aggregate_out"

# --- chained smoke tests ---
echo "→ running classify smoke"
bash "$SKILL_DIR/scripts/tests/classify.sh"
echo "→ running topo-order smoke"
bash "$SKILL_DIR/scripts/tests/topo.sh"
echo "→ running kb smoke"
bash "$SKILL_DIR/scripts/tests/kb-smoke.sh"

echo "✓ x-qa smoke passed"
