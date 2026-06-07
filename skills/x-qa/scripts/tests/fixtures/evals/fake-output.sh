#!/usr/bin/env bash
# Fake SUT: prints a fixed response body. Ignores all args.
set -euo pipefail
printf '%s' '{"answer":"Paris is the capital of France."}'
