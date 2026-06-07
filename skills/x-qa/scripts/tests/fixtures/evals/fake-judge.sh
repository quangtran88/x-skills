#!/usr/bin/env bash
# Fake judge: reads a prompt on stdin, ignores it, emits a score from
# $FAKE_SCORE (default 0.9). Mimics the real judge's stdout contract.
set -euo pipefail
cat >/dev/null
jq -n --argjson s "${FAKE_SCORE:-0.9}" '{score:$s, reason:"fake"}'
