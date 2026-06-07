#!/usr/bin/env bash
# channel-contract.sh — grep-anchored checks that doc contracts contain
# their load-bearing clauses. Cheap guard against silent contract drift.
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
pass=0; fail=0
need() { if grep -qF -- "$2" "$SKILL_DIR/$1"; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: $1 missing: $2"; fi; }

# channel-drivers.md
need references/channel-drivers.md "computer-use"
need references/channel-drivers.md "feature-gate"
need references/channel-drivers.md "captures every channel"

# init-interview.md (Task 5)
need references/init-interview.md "## Channel Enumeration"
need references/init-interview.md "Monitoring"
need references/init-interview.md "credentials"

# SKILL.md + case-runner-prompts.md guard (Task 7)
need SKILL.md "never executes the repository's own test suites"
need SKILL.md "--channel"
need references/case-runner-prompts.md "MUST NOT run the repository's own test suites"

# init-interview.md: stateful singleton mapping step (Task 16)
need references/init-interview.md "Stateful channel mapping"
need references/init-interview.md "singleton_id"

# SKILL.md Phase 4 + Run Envelope (Task 17)
need SKILL.md "CHANNELS_TESTED"
need SKILL.md "CHANNELS_SKIPPED"
need SKILL.md "channel-select.sh"
need SKILL.md "stateless"
# channel-drivers.md stateful skip reasons (Task 17)
need references/channel-drivers.md "stateful-owned-chat-driver-deferred"
need references/channel-drivers.md "stateful-not-owned"
need references/channel-drivers.md "stateful-unverifiable"

echo "channel-contract: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
