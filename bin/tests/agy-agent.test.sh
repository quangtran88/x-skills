#!/usr/bin/env bash
# Offline unit tests for bin/agy-agent. No network, no real agy.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGY_AGENT="$HERE/../agy-agent"
PASS=0; FAIL=0
assert_eq() { # $1=desc $2=expected $3=actual
  if [[ "$2" == "$3" ]]; then PASS=$((PASS+1)); else
    FAIL=$((FAIL+1)); echo "FAIL: $1"; echo "  expected: $2"; echo "  actual:   $3"; fi
}
assert_contains() { # $1=desc $2=needle $3=haystack
  if [[ "$3" == *"$2"* ]]; then PASS=$((PASS+1)); else
    FAIL=$((FAIL+1)); echo "FAIL: $1"; echo "  needle:   $2"; echo "  haystack: $3"; fi
}

# T2.1 empty prompt -> non-zero exit
out=$("$AGY_AGENT" 2>&1); rc=$?
assert_eq "empty prompt exits non-zero" "1" "$rc"
assert_contains "empty prompt message" "prompt required" "$out"

# T2.2 dry-run prints the agy argv and does not execute
out=$(X_AGY_DRY_RUN=1 "$AGY_AGENT" "hello world" 2>/dev/null); rc=$?
assert_eq "dry-run exits 0" "0" "$rc"
assert_contains "dry-run shows -p" "-p" "$out"
assert_contains "dry-run shows prompt" "hello world" "$out"

# T3 model alias resolution (dry-run shows --model with agy display string)
run_dry() { X_AGY_DRY_RUN=1 "$AGY_AGENT" "$@" 2>/dev/null; }
assert_contains "flash->display"  'Gemini 3.5 Flash (Medium)'  "$(run_dry --model flash x)"
assert_contains "pro->display"    'Gemini 3.1 Pro (High)'      "$(run_dry --model pro x)"
assert_contains "flash-low"       'Gemini 3.5 Flash (Low)'     "$(run_dry --model flash-low x)"
assert_contains "claude-opus"     'Claude Opus 4.6 (Thinking)' "$(run_dry --model claude-opus x)"
assert_contains "passthrough"     'Gemini 3.1 Pro (Low)'       "$(run_dry --model 'Gemini 3.1 Pro (Low)' x)"
# default (no --model) must still pin a model so headless isn't model-ambiguous
assert_contains "default flash"   'Gemini 3.5 Flash (Medium)'  "$(run_dry x)"

# T4 flag translation
assert_contains "add-dir flag" '--add-dir'                       "$(run_dry --add-dir /tmp x)"
assert_contains "add-dir val"  '/tmp'                            "$(run_dry --add-dir /tmp x)"
assert_contains "resume->-c"   '-c'                              "$(run_dry --resume x)"
assert_contains "conversation" 'abc123'                          "$(run_dry --conversation abc123 x)"
assert_contains "sandbox"      '--sandbox'                       "$(run_dry --sandbox x)"
assert_contains "yolo"         '--dangerously-skip-permissions' "$(run_dry --yolo x)"
# grounding injects the directive into the prompt (last positional -p arg)
assert_contains "grounded dir" 'Use Google Search'              "$(run_dry --grounded 'latest bun version')"
# system prompt is prepended to the prompt text (agy has no --system)
sys=$(mktemp); printf 'You are terse.' > "$sys"
assert_contains "system prepend" 'You are terse.'               "$(run_dry --system "$sys" 'hi')"
rm -f "$sys"

# T5 trust preflight warns (to stderr) when CWD not trusted; never blocks dry-run
fakehome=$(mktemp -d); mkdir -p "$fakehome/.gemini/antigravity-cli"
echo '{"trustedWorkspaces":[]}' > "$fakehome/.gemini/antigravity-cli/settings.json"
err=$(cd /tmp && HOME="$fakehome" X_AGY_DRY_RUN=1 "$AGY_AGENT" x 2>&1 >/dev/null)
assert_contains "untrusted warns" "not a trusted workspace" "$err"
# trusted CWD -> no warning. NB: the wrapper checks BOTH $PWD (logical "/tmp")
# and pwd -P (physical "/private/tmp" on macOS), so seeding the logical path matches.
echo "{\"trustedWorkspaces\":[\"/tmp\"]}" > "$fakehome/.gemini/antigravity-cli/settings.json"
err=$(cd /tmp && HOME="$fakehome" X_AGY_DRY_RUN=1 "$AGY_AGENT" x 2>&1 >/dev/null)
assert_eq "trusted is silent" "" "$err"
rm -rf "$fakehome"

# T6 execution + failure detection, using the fake-agy stub on PATH
FIX="$HERE/fixtures"
run_live() { PATH="$FIX:$PATH" X_AGY_NO_LOG=1 "$AGY_AGENT" "$@"; }

# ok -> stdout has response, exit 0
out=$(FAKE_AGY_MODE=ok run_live "ping" 2>/dev/null); rc=$?
assert_eq "ok exit 0" "0" "$rc"; assert_contains "ok stdout" "PONG" "$out"

# empty stdout -> wrapper exits NON-zero (synthetic), since agy lies with exit 0
out=$(FAKE_AGY_MODE=empty run_live "ping" 2>/dev/null); rc=$?
assert_eq "empty -> non-zero exit" "1" "$rc"

# authlog -> non-zero + stderr classifies as auth
err=$(FAKE_AGY_MODE=authlog run_live "ping" 2>&1 >/dev/null); rc=$?
assert_eq "authlog -> non-zero" "1" "$rc"
assert_contains "auth classified" "auth_error" "$err"

# REGRESSION (finding #1): the always-present auth NOISE must NOT be classified as auth.
# noiselog writes the same lines agy emits on SUCCESS — empty stdout here means a generic
# failure, and the classifier must say empty_output, never auth_error.
err=$(FAKE_AGY_MODE=noiselog run_live "ping" 2>&1 >/dev/null); rc=$?
assert_eq "noiselog -> non-zero" "1" "$rc"
assert_contains "noise -> empty_output" "status=empty_output" "$err"
assert_eq "noise NOT auth" "0" "$([[ "$err" == *"auth_error"* ]] && echo 1 || echo 0)"

# chrome stripping is opt-in: default keeps it, X_AGY_STRIP_SUMMARY=1 removes it
out=$(FAKE_AGY_MODE=chrome run_live "ping" 2>/dev/null)
assert_contains "chrome kept by default" "Work Summary" "$out"
out=$(FAKE_AGY_MODE=chrome X_AGY_STRIP_SUMMARY=1 run_live "ping" 2>/dev/null)
assert_eq "chrome stripped" "0" "$([[ "$out" == *"Work Summary"* ]] && echo 1 || echo 0)"

# T-guard: trailing value-flag must error fast, not infinite-loop hang (exit 1, not 124).
# Each guarded by `timeout 5` so a regression would surface as rc=124, never wedge the suite.
for tf in --model -m --system --add-dir --dir --conversation; do
  ( timeout 5 "$AGY_AGENT" "$tf" ) >/dev/null 2>&1; rc=$?
  assert_eq "trailing $tf errors not hangs" "1" "$rc"
done

# T7 live smoke — only when X_AGY_LIVE=1 and real agy present (costs quota, ~10-150s)
if [[ "${X_AGY_LIVE:-0}" == "1" ]] && command -v agy &>/dev/null; then
  out=$("$AGY_AGENT" --model flash-low "Reply with exactly one word: PONG" 2>/dev/null); rc=$?
  assert_eq "live exit 0" "0" "$rc"
  assert_contains "live PONG" "PONG" "$out"
  out=$("$AGY_AGENT" --model flash-low --grounded "Latest stable Bun version this week? Cite a URL." 2>/dev/null)
  assert_contains "live grounding cites url" "http" "$out"
else
  echo "(skipping live smoke — set X_AGY_LIVE=1 to enable)"
fi

echo "---"; echo "PASS=$PASS FAIL=$FAIL"; [[ $FAIL -eq 0 ]]
