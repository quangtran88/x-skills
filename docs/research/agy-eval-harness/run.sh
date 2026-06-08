#!/usr/bin/env bash
# Diff-harness: replay the identical voice-recording research prompt through three
# research backends and score each against two known primary-source anchors.
#
#   ANCHOR-1 (web/docs grounding): GA event is `response.output_audio_transcript.done`.
#       Repo contains only the LEGACY `response.audio_transcript.done` and a decoy
#       `response.output_item.done` — so grepping the repo is a trap; this tests
#       whether the backend grounds against current OpenAI docs / model currency.
#   ANCHOR-2 (repo grounding): real signature is
#       `dispatchCoffer(deps, ctx, args)` (coffer.ts:123), called as
#       `dispatchCoffer(deps, {agentId}, {op:"write", path, content})`.
#       gemini invented `dispatchCoffer(driver, path, stream)`. Tests whether the
#       backend actually reads the repo before asserting a code signature.
#
# Lane design: gemini and agy run the SAME model (Gemini 3.1 Pro), so lane1-vs-lane2
# isolates the *harness* effect (file-attach-only vs agentic repo grounding) — the
# exact question for the June 18 gemini-CLI -> agy migration.
set -uo pipefail

REPO="${ONECLAW_REPO:-/Users/randytran/Codes/oneclaw}"
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/out"
PROMPT_FILE="$HERE/prompt.txt"
BRIDGE="extensions/oneclaw-multiagent/src/adapters/whatsapp/realtime-bridge.ts"
DESIGN="docs/backlog/2026-06-04-voice-pre-call-handoff-design.md"
TIMEOUT="${TIMEOUT:-420}"
mkdir -p "$OUT"
PROMPT="$(cat "$PROMPT_FILE")"

run_lane () { # name, seconds-cap, command...
  local name="$1"; shift
  local cap="$1"; shift
  echo ">> running lane: $name (cap ${cap}s)"
  local t0 t1
  t0=$(date +%s)
  ( cd "$REPO" && timeout "$cap" "$@" ) > "$OUT/$name.txt" 2> "$OUT/$name.err"
  local rc=$?
  t1=$(date +%s)
  printf '%s\texit=%s\tseconds=%s\tbytes=%s\n' "$name" "$rc" "$((t1-t0))" "$(wc -c < "$OUT/$name.txt")" | tee "$OUT/$name.meta"
}

# Lane 1 — gemini-agent (incumbent): Gemini 3.1 Pro, file-attach only, no repo tool loop.
run_lane gemini "$TIMEOUT" \
  gemini-agent --model pro --raw --file "$BRIDGE" --file "$DESIGN" "$PROMPT"

# Lane 2 — agy (migration target): Gemini 3.1 Pro, agentic w/ repo grounding + search.
# NOTE: prompt MUST be the value of -p/--prompt; a positional arg is ignored (agy just chats).
run_lane agy "$TIMEOUT" \
  agy -p "$PROMPT" --model "Gemini 3.1 Pro (High)" --add-dir "$REPO" --dangerously-skip-permissions

# Lane 3 — omo-explore (opencode): GPT-5.4-mini, agentic w/ repo tool loop.
run_lane explore "$TIMEOUT" \
  opencode run --agent explore --dir "$REPO" "$PROMPT"

echo
echo "all lanes complete -> scoring"
"$HERE/score.sh"
