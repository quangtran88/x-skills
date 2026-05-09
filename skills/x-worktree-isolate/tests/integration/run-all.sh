#!/usr/bin/env bash
# run-all.sh — execute every test_*.sh in this directory, summarize pass/fail/skip.
# Bash 3.2 portable.

set -u
cd "$(dirname "${BASH_SOURCE[0]}")"

PASS=0
FAIL=0
SKIP=0
FAILED_TESTS=""

for test_file in test_*.sh; do
  [ -f "$test_file" ] || continue
  echo "── $test_file ────────────────────────────────────"
  set +e
  bash "$test_file"
  rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAILED_TESTS="${FAILED_TESTS} $test_file"
  fi
  echo
done

echo "── summary ────────────────────────────────────"
echo "  PASS: $PASS"
echo "  FAIL: $FAIL"
echo "  SKIP: $SKIP"
[ -n "$FAILED_TESTS" ] && echo "  failed:$FAILED_TESTS"

[ "$FAIL" -eq 0 ]
