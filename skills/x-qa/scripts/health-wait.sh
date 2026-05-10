#!/usr/bin/env bash
# health-wait.sh — poll a health endpoint until 200 or timeout
# Usage: health-wait.sh --url <full-url> --status <expected> --timeout <seconds> [--interval-ms <ms>]
set -euo pipefail

URL=""
STATUS=200
TIMEOUT=60
INTERVAL_MS=1000
code=000  # initialise so `set -u` does not blow up if loop never iterates

while [[ $# -gt 0 ]]; do
  case "$1" in
    --url) URL="$2"; shift 2 ;;
    --status) STATUS="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --interval-ms) INTERVAL_MS="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$URL" ]] && { echo "REASON=missing --url" >&2; exit 2; }

deadline=$(( $(date +%s) + TIMEOUT ))
interval_s=$(awk "BEGIN{print $INTERVAL_MS/1000}")

while [[ $(date +%s) -lt $deadline ]]; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$URL" || echo 000)
  if [[ "$code" == "$STATUS" ]]; then
    echo "HEALTHY=true"
    echo "URL=$URL"
    echo "STATUS=$code"
    exit 0
  fi
  sleep "$interval_s"
done

echo "HEALTHY=false" >&2
echo "URL=$URL" >&2
echo "REASON=timeout after ${TIMEOUT}s, last status=$code" >&2
exit 1
