#!/usr/bin/env bash
# Offline unit tests for bin/omo-agent's OpenCode 1.x / 2.x handling. No network,
# no real opencode: fixtures/fake-opencode stands in via OPENCODE_BIN.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OMO_AGENT="$HERE/../omo-agent"
FAKE="$HERE/fixtures/fake-opencode"
PASS=0; FAIL=0
assert_eq() { # $1=desc $2=expected $3=actual
  if [[ "$2" == "$3" ]]; then PASS=$((PASS+1)); else
    FAIL=$((FAIL+1)); echo "FAIL: $1"; echo "  expected: $2"; echo "  actual:   $3"; fi
}
assert_contains() { # $1=desc $2=needle $3=haystack
  if [[ "$3" == *"$2"* ]]; then PASS=$((PASS+1)); else
    FAIL=$((FAIL+1)); echo "FAIL: $1"; echo "  needle:   $2"; echo "  haystack: $3"; fi
}
assert_not_contains() { # $1=desc $2=needle $3=haystack
  if [[ "$3" != *"$2"* ]]; then PASS=$((PASS+1)); else
    FAIL=$((FAIL+1)); echo "FAIL: $1"; echo "  unexpected: $2"; echo "  haystack:   $3"; fi
}

command -v timeout >/dev/null 2>&1 || { echo "SKIP: omo-agent needs GNU timeout"; exit 0; }

# A space in the path proves --dir / --file stay single arguments.
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir "$WORK/my proj" && cd "$WORK/my proj" || exit 1
CWD=$(pwd)
V1="1.17.16"
V2="opencode v2.0.27"

# Run omo-agent against the fake. $1 = fake `--version` output, rest = omo-agent
# args. Sets OUT, ERR, RC, LOG (every fake argv, one <arg><arg>… line each) and
# RUNS (the `run` lines, minus the `run --help` contract probe).
# FAKE_OC_* / OMO_TIMEOUT pass through from the caller's env. XDG_CONFIG_HOME is
# pinned so the machine's own oh-my-openagent.json never leaks into a run.
oa() {
  local ver="$1"; shift
  : > "$WORK/log"; rm -f "$WORK/count" "$WORK/stdin"
  OUT=$(OPENCODE_BIN="$FAKE" FAKE_OC_VERSION="$ver" FAKE_OC_LOG="$WORK/log" \
        FAKE_OC_STDIN="$WORK/stdin" FAKE_OC_COUNT="$WORK/count" OMO_TIMEOUT="${OMO_TIMEOUT:-20}" \
        XDG_CONFIG_HOME="$WORK/xdg" \
        "$OMO_AGENT" "$@" 2>"$WORK/err"); RC=$?
  ERR=$(cat "$WORK/err")
  LOG=$(cat "$WORK/log")
  RUNS=$(grep '^<run>' "$WORK/log" | grep -vx '<run><--help>' || true)
  # omo-agent keeps a raw debug log per run; remove exactly the one this run wrote.
  local raw; raw=$(sed -n 's/.* raw=\(\/tmp\/omo-agent-[^ ]*\.log\).*/\1/p' "$WORK/err" | head -1)
  [[ -n "$raw" ]] && rm -f "$raw"
}
count_lines() { [[ -z "$1" ]] && echo 0 || printf '%s\n' "$1" | wc -l | tr -d ' '; }
last_line() { printf '%s\n' "$1" | tail -1; }
# Write (or with "" remove) the OMO config the wrapper reads role models from.
omo_cfg() {
  rm -rf "$WORK/xdg"; [[ -n "$1" ]] || return 0
  mkdir -p "$WORK/xdg/opencode" && printf '%s\n' "$1" > "$WORK/xdg/opencode/oh-my-openagent.json"
}

# T1 v1 argv is unchanged from the pre-v2 wrapper
oa "$V1" --model openai/gpt-5.5 "hello v1"
assert_eq "v1 model: exit" "0" "$RC"
assert_contains "v1 model: output" "PONG" "$OUT"
assert_eq "v1 model: argv" "<run><--pure><--agent><build><--model><openai/gpt-5.5><--dir><$CWD>" "$RUNS"
assert_contains "v1 model: prompt on stdin" "hello v1" "$(cat "$WORK/stdin")"
assert_not_contains "v1 model: full id skips the model list" "<models>" "$LOG"
assert_contains "v1 model: contract is logged" "opencode=v1" "$ERR"

oa "$V1" oracle "hi"
assert_eq "v1 agent: argv" "<run><--agent><oracle><--dir><$CWD>" "$RUNS"

oa "$V1" --model gpt "hi"
assert_contains "v1 alias: plain models call" $'\n<models>\n' $'\n'"$LOG"$'\n'
assert_contains "v1 alias: resolved" "<--model><openai/gpt-5.5>" "$RUNS"

echo note > "$WORK/a note.md"
oa "$V1" --model openai/gpt-5.5 -f "$WORK/a note.md" "hi"
assert_eq "v1 file: argv" "<run><--pure><--agent><build><--model><openai/gpt-5.5><--dir><$CWD><--file><$WORK/a note.md>" "$RUNS"

# T2 v1 gates still short-circuit before `opencode run`
oa "$V1" momus "hi"
assert_eq "v1 broken agent: exit" "1" "$RC"
assert_contains "v1 broken agent: message" "UNAVAILABLE" "$ERR"
assert_eq "v1 broken agent: no opencode run" "" "$RUNS"
oa "$V1" nonsense "hi"
assert_contains "v1 unknown agent: message" "Unknown agent" "$ERR"
assert_eq "v1 unknown agent: no opencode run" "" "$RUNS"

# T3 v2 argv: --standalone, no --pure, no --dir (the fake rejects both, like 2.0.27)
oa "$V2" --model openai/gpt-5.5 "hello v2"
assert_eq "v2 model: exit" "0" "$RC"
assert_contains "v2 model: output" "PONG" "$OUT"
assert_eq "v2 model: argv" "<run><--standalone><--agent><build><--model><openai/gpt-5.5>" "$RUNS"
assert_contains "v2 model: prompt on stdin" "hello v2" "$(cat "$WORK/stdin")"
assert_contains "v2 model: contract is logged" "opencode=v2" "$ERR"

oa "$V2" explore "hi"
assert_eq "v2 agent: argv" "<run><--standalone><--agent><explore>" "$RUNS"

oa "$V2" --model gpt "hi"
assert_contains "v2 alias: models --standalone" $'\n<models><--standalone>\n' $'\n'"$LOG"$'\n'
assert_contains "v2 alias: resolved" "<--model><openai/gpt-5.5>" "$RUNS"

oa "$V2" --model openai/gpt-5.5 -f "$WORK/a note.md" "hi"
assert_eq "v2 file: argv" "<run><--standalone><--agent><build><--model><openai/gpt-5.5><--file><$WORK/a note.md>" "$RUNS"

# T4 v2 cold start: retried on the activation error, bounded, never on v1
FAKE_OC_MODE=cold:2 oa "$V2" --model openai/gpt-5.5 "hi"
assert_eq "v2 cold run: recovers" "0" "$RC"
assert_contains "v2 cold run: output" "PONG" "$OUT"
assert_eq "v2 cold run: attempts" "3" "$(count_lines "$RUNS")"
assert_contains "v2 cold run: retry is logged" "retry 2/5" "$ERR"

FAKE_OC_MODE=cold:99 oa "$V2" --model openai/gpt-5.5 "hi"
assert_eq "v2 cold forever: fails" "1" "$RC"
assert_eq "v2 cold forever: 1 try + 5 retries" "6" "$(count_lines "$RUNS")"

FAKE_OC_MODE=cold:1 oa "$V2" --model gpt "hi"
assert_eq "v2 cold models: recovers" "0" "$RC"
assert_eq "v2 cold models: listed twice" "2" "$(count_lines "$(grep '^<models>' "$WORK/log")")"
FAKE_OC_MODE=coldout:1 oa "$V2" --model gpt "hi"
assert_eq "v2 cold models, error on stdout: recovers" "0" "$RC"
assert_contains "v2 cold models, error on stdout: resolved" "<--model><openai/gpt-5.5>" "$RUNS"

FAKE_OC_MODE=cold:1 oa "$V1" --model openai/gpt-5.5 "hi"
assert_eq "v1: no activation retry" "1" "$(count_lines "$RUNS")"

# T5 a run that reached the model is never retried, whatever its output says
FAKE_OC_MODE=billed oa "$V2" --model openai/gpt-5.5 "hi"
assert_eq "v2 billed run quoting the error: fails" "1" "$RC"
assert_eq "v2 billed run quoting the error: one attempt" "1" "$(count_lines "$RUNS")"

# T6 v2 missing agent: passed through (no v1 gate), explained only for its own miss
FAKE_OC_MODE=noagent oa "$V2" momus "review plan.md please"
assert_eq "v2 missing agent: exit" "1" "$RC"
assert_eq "v2 missing agent: reaches opencode, not emulated" "<run><--standalone><--agent><momus>" "$RUNS"
assert_contains "v2 missing agent: explained" "agent 'momus' does not exist in this OpenCode 2 install" "$ERR"
assert_not_contains "v2 missing agent: not the v1 compat error" "UNAVAILABLE" "$ERR"
if [[ -e "$CWD/.sisyphus" ]]; then FAIL=$((FAIL+1)); echo "FAIL: v2 momus ran the v1 plan-copy workaround"; else PASS=$((PASS+1)); fi
FAKE_OC_MODE=nested oa "$V2" explore "hi"
assert_eq "v2 nested agent miss: fails" "1" "$RC"
assert_not_contains "v2 nested agent miss: requested agent not blamed" "does not exist" "$ERR"
assert_contains "v2 nested agent miss: status line kept" "status=" "$ERR"

# T7 timeout: exit 124, one attempt, not reported as a missing agent
FAKE_OC_MODE=slow OMO_TIMEOUT=2 oa "$V2" explore "hi"
assert_eq "v2 timeout: exit" "124" "$RC"
assert_eq "v2 timeout: one attempt" "1" "$(count_lines "$RUNS")"
assert_contains "v2 timeout: status" "status=timeout" "$ERR"
assert_not_contains "v2 timeout: not a missing agent" "does not exist" "$ERR"

# T8 v2 role agents: native agent first, else the read-only `explore` stand-in,
# on the model oh-my-openagent.json pins for the role
V2_BUILTINS="build plan explore general"
if command -v jq >/dev/null 2>&1; then
  omo_cfg '{"agents":{"oracle":{"model":"openai/gpt-5.5","variant":"high"},"explore":{"model":"openai/gpt-5.3-codex"},"librarian":{"model":"bad id; rm -rf /"}}}'

  FAKE_OC_NATIVE_AGENTS="$V2_BUILTINS" oa "$V2" oracle "review this"
  assert_eq "v2 oracle stand-in: exit" "0" "$RC"
  assert_contains "v2 oracle stand-in: output" "PONG" "$OUT"
  assert_eq "v2 oracle stand-in: native tried, then explore, same pinned model" \
    "<run><--standalone><--agent><oracle><--model><openai/gpt-5.5#high>"$'\n'"<run><--standalone><--agent><explore><--model><openai/gpt-5.5#high>" "$RUNS"
  assert_contains "v2 oracle stand-in: role hint" "[ROLE: oracle" "$(cat "$WORK/stdin")"
  assert_contains "v2 oracle stand-in: caller prompt kept" "review this" "$(cat "$WORK/stdin")"
  assert_contains "v2 oracle stand-in: announced" "running v2's read-only 'explore' agent as oracle" "$ERR"

  oa "$V2" oracle "hi"
  assert_eq "v2 native oracle wins" "<run><--standalone><--agent><oracle><--model><openai/gpt-5.5#high>" "$RUNS"
  assert_not_contains "v2 native oracle: no role hint" "[ROLE:" "$(cat "$WORK/stdin")"

  FAKE_OC_NATIVE_AGENTS="$V2_BUILTINS" oa "$V2" explore "hi"
  assert_eq "v2 explore: built-in on its pinned model" "<run><--standalone><--agent><explore><--model><openai/gpt-5.3-codex>" "$RUNS"

  FAKE_OC_NATIVE_AGENTS="$V2_BUILTINS" oa "$V2" librarian "hi"
  assert_eq "v2 librarian: a pin that is not a model id is dropped" \
    "<run><--standalone><--agent><librarian>"$'\n'"<run><--standalone><--agent><explore>" "$RUNS"

  # pinned model not served by this install → default model, whichever error comes first
  FAKE_OC_NATIVE_AGENTS="$V2_BUILTINS" FAKE_OC_BAD_MODEL="openai/gpt-5.5#high" oa "$V2" oracle "hi"
  assert_eq "v2 unavailable pin (agent error first): recovers" "0" "$RC"
  assert_eq "v2 unavailable pin (agent error first): ends on explore, default model" "<run><--standalone><--agent><explore>" "$(last_line "$RUNS")"
  assert_contains "v2 unavailable pin: announced" "is unavailable — using the OpenCode default model" "$ERR"
  FAKE_OC_NATIVE_AGENTS="$V2_BUILTINS" FAKE_OC_BAD_MODEL="openai/gpt-5.5#high" FAKE_OC_MODEL_FIRST=1 oa "$V2" oracle "hi"
  assert_eq "v2 unavailable pin (model error first): recovers" "0" "$RC"
  assert_eq "v2 unavailable pin (model error first): ends on explore, default model" "<run><--standalone><--agent><explore>" "$(last_line "$RUNS")"
  assert_eq "v2 unavailable pin (model error first): bounded" "3" "$(count_lines "$RUNS")"

  # a run that already reached the model is never re-run as a stand-in
  FAKE_OC_MODE=billedmiss oa "$V2" oracle "hi"
  assert_eq "v2 billed run reporting the agent missing: one attempt" "1" "$(count_lines "$RUNS")"
  FAKE_OC_MODE=ansimiss oa "$V2" oracle "hi"
  assert_eq "v2 billed run with a colour-wrapped banner: one attempt" "1" "$(count_lines "$RUNS")"
  FAKE_OC_MODE=bytemiss oa "$V2" oracle "hi"
  assert_eq "v2 billed run, banner after a non-UTF-8 byte: one attempt" "1" "$(count_lines "$RUNS")"
  FAKE_OC_MODE=crmiss oa "$V2" oracle "hi"
  assert_eq "v2 billed run with a CR-prefixed banner: one attempt" "1" "$(count_lines "$RUNS")"
  FAKE_OC_MODE=spacemiss oa "$V2" oracle "hi"
  assert_eq "v2 billed run, multi-word agent in the banner: one attempt" "1" "$(count_lines "$RUNS")"
  omo_cfg '{"agents":{"oracle":{"model":"--agent/x"}}}'
  oa "$V2" oracle "hi"
  assert_eq "v2 pin starting with a dash is dropped" "<run><--standalone><--agent><oracle>" "$RUNS"

  oa "$V1" oracle "hi"
  assert_eq "v1 oracle: plugin owns the model, pin not passed" "<run><--agent><oracle><--dir><$CWD>" "$RUNS"
else
  echo "NOTE: jq not installed — role-model pin checks skipped"
fi

omo_cfg ""
FAKE_OC_NATIVE_AGENTS="$V2_BUILTINS" oa "$V2" multimodal-looker "hi"
assert_eq "v2 role without OMO config: explore on the default model" \
  "<run><--standalone><--agent><multimodal-looker>"$'\n'"<run><--standalone><--agent><explore>" "$RUNS"
FAKE_OC_NATIVE_AGENTS="$V2_BUILTINS" oa "$V2" momus "hi"
assert_eq "v2 non-role name: not emulated" "1" "$(count_lines "$RUNS")"
assert_contains "v2 non-role name: explained" "does not exist in this OpenCode 2 install" "$ERR"

# T9 dev/snapshot builds report 0.0.0-… on both lines → contract comes from `run --help`
FAKE_OC_CONTRACT=2 oa "0.0.0-dev-20831" --model openai/gpt-5.5 "hi"
assert_eq "dev build, v2 contract" "<run><--standalone><--agent><build><--model><openai/gpt-5.5>" "$RUNS"
FAKE_OC_CONTRACT=1 oa "0.0.0-dev-202610110139" --model openai/gpt-5.5 "hi"
assert_eq "dev build, v1 contract" "<run><--pure><--agent><build><--model><openai/gpt-5.5><--dir><$CWD>" "$RUNS"

# T10 the skill-local copy is the same script
if cmp -s "$OMO_AGENT" "$HERE/../../skills/x-omo/omo-agent"; then PASS=$((PASS+1)); else
  FAIL=$((FAIL+1)); echo "FAIL: skills/x-omo/omo-agent differs from bin/omo-agent"; fi

echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
