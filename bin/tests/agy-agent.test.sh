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

echo "---"; echo "PASS=$PASS FAIL=$FAIL"; [[ $FAIL -eq 0 ]]
