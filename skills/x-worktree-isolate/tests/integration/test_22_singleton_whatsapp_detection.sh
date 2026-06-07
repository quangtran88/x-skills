#!/usr/bin/env bash
# Test 22: WhatsApp patterns detected — compose env (whatsapp) + source signature (whatsapp-web).
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t22
trap test_teardown EXIT

REPO="$TEST_TMP/repo"
make_repo "$REPO"
# Tier 1: compose env var token.
cat > "$REPO/docker-compose.yml" <<'YAML'
services:
  wa:
    image: node:20
    environment:
      WHATSAPP_TOKEN: secret
      WHATSAPP_SESSION: sess
YAML
# Tier 2: source signatures.
mkdir -p "$REPO/src"
cat > "$REPO/src/bot.js" <<'JS'
import makeWASocket from '@whiskeysockets/baileys';
const sock = makeWASocket({});
JS
cat > "$REPO/src/web.js" <<'JS'
const { Client } = require('whatsapp-web.js');
const c = new Client({});
JS

DETECT="$SKILL_DIR/scripts/detect-singletons.py"
OUT="$(python3 "$DETECT" --repo "$REPO")"

echo "$OUT" | python3 -c '
import json, sys
d = json.load(sys.stdin)
ids = {s["id"] for s in d.get("singletons", [])}
assert "whatsapp" in ids, f"expected compose-tier whatsapp id, got {ids}"
assert "whatsapp-web" in ids, f"expected env-flag whatsapp-web id, got {ids}"
kinds = {s["id"]: s["kind"] for s in d["singletons"]}
assert kinds["whatsapp"] == "compose-service", kinds
assert kinds["whatsapp-web"] == "env-flag", kinds
print("ok")
'

pass "test 22 — WhatsApp Tier-1 + Tier-2 detection"
