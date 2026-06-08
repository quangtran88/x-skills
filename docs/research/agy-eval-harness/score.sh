#!/usr/bin/env bash
# Score each lane's output against the two anchors. Pure grep — deterministic, auditable.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/out"

score_anchor1 () { # stdin = output text -> verdict
  local f="$1"
  if   grep -qiF 'output_audio_transcript.done' "$f"; then echo "CORRECT (output_audio_transcript.done)"
  elif grep -qiF 'output_item.done'            "$f"; then echo "INVENTED (output_item.done — gemini's original error)"
  elif grep -qiE 'audio_transcript\.done'      "$f"; then echo "LEGACY (audio_transcript.done — stale alias)"
  else echo "MISS (no concrete event string emitted)"
  fi
}

score_anchor2 () { # file -> verdict
  local f="$1"
  # CORRECT: real param names deps/ctx/args (allowing TS type annotations like
  # `deps: CofferDeps`), OR the canonical write-call shape `dispatchCoffer(deps, {agentId}, ...)`.
  if   grep -qiE 'dispatchCoffer\s*\(\s*deps[^,]*,\s*ctx[^,]*,\s*args' "$f" \
    || grep -qiE 'dispatchCoffer\s*\(\s*deps\s*,\s*\{[^)]*agentId' "$f"; then
       echo "CORRECT (deps, ctx, args / {op:write})"
  elif grep -qiE 'dispatchCoffer\s*\(\s*driver' "$f"; then
       echo "INVENTED (driver, path, stream — gemini's original error)"
  elif grep -qiE 'dispatchCoffer\s*\(' "$f"; then
       echo "PARTIAL (calls dispatchCoffer but wrong/unverified params)"
  else echo "MISS (no dispatchCoffer signature emitted)"
  fi
}

printf '\n%-10s | %-9s | %-7s | %-52s | %s\n' LANE EXIT SECONDS ANCHOR-1_transcript-event ANCHOR-2_dispatchCoffer
printf -- '-----------+-----------+---------+------------------------------------------------------+-----------------------------------\n'
for name in gemini agy explore; do
  f="$OUT/$name.txt"; meta="$OUT/$name.meta"
  [ -f "$f" ] || { printf '%-10s | (no output)\n' "$name"; continue; }
  ex=$(cut -f2 "$meta" 2>/dev/null | cut -d= -f2); se=$(cut -f3 "$meta" 2>/dev/null | cut -d= -f2)
  a1="$(score_anchor1 "$f")"; a2="$(score_anchor2 "$f")"
  printf '%-10s | %-9s | %-7s | %-52s | %s\n' "$name" "${ex:-?}" "${se:-?}" "$a1" "$a2"
done
echo
echo "raw outputs: $OUT/<lane>.txt   stderr: $OUT/<lane>.err"
