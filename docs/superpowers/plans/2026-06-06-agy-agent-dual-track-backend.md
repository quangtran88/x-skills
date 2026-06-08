# agy-agent Dual-Track Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `bin/agy-agent`, a headless wrapper for Google's Antigravity CLI (`agy`), as a dual-track backend for the x-gemini skill behind a new `agy_cli` capability flag — so x-skills keeps working after the standalone `gemini` CLI stops serving AI Ultra/Pro/free on **2026-06-18**.

**Architecture:** `agy-agent` mirrors the shape of `bin/gemini-agent` (arg parse → resolve → exec → classify → emit response + stderr summary) but drops everything that depended on Gemini's JSON output (stats, session-id, thinking-starvation detector) because **agy print mode is plain text only**. It adds two things agy lacks: a **synthetic exit code** (agy exits `0` even on auth/quota/empty failures, so the wrapper detects failure via empty-stdout + log-tail and exits non-zero) and a **model-alias map** to agy's exact display strings. `gemini-agent` stays the default; skills select the backend by capability (`gemini_cli` preferred while it lives, `agy_cli` as fallback/override).

**Tech Stack:** Bash (set -uo pipefail), `jq` (setup manifest only — NOT in agy-agent), `agy` v1.0.6+ CLI, `timeout`/`gtimeout` (coreutils). Plain-shell test scripts (no bats — matches `skills/x-worktree-isolate/tests/`).

**Spec source:** `docs/research/2026-06-06-agy-antigravity-cli-headless-usage-guide.md` (binary-verified). Read it before starting — every flag/path/behavior below traces to a verified finding there.

**Validation source (NEW):** `docs/research/2026-06-06-agy-antigravity-cli-headless-usage-guide.md` **Part 2 (§12–15)** — a live 3-backend bake-off (agy vs gemini-agent vs omo-explore) replaying a real research prompt against 2 primary-source anchors. It produced the amendments below. Read it before Task 6 and Task 10. (Runnable harness: `docs/research/agy-eval-harness/`.)

---

## Findings & Amendments (eval harness, 2026-06-06)

The bake-off confirmed the plan's core thesis (**agy is a viable gemini-CLI replacement for repo-grounded research** — it tied gemini on the anchors, *beat* it on grounding because it reads the repo, and ran ~2× slower not 3–5×). But it overturned four specifics this plan currently gets wrong. Apply these where flagged inline.

1. **The Task 6 auth classifier is BROKEN as written — fix required.** agy writes `error getting token source: You are not logged into Antigravity` + `failed to set auth token` into its log on **every** run, *including successful ones* (they're for auxiliary `loadCodeAssistResponse`/`fetchAdminControls`/`ListExperiments` caches, not model serving). The Task 6 classifier greps the log for `auth|...|credential` whenever stdout is empty → it will mislabel **every** empty-output failure (traversal hang, quota, planner-empty) as `auth_error`. The auth string is noise, not signal. → **Patched inline in Task 6 Step 4 below** (auth bucket demoted; check timeout/quota/planner first; only call it auth on a *specific, serving-path* marker).

2. **`--add-dir` on a large tree hangs agy — add a guard (Task 4).** Pointing `--add-dir` at the 65 GB oneclaw repo root caused agy to hang for 15–25 min with zero output (agentic traversal blowup). Scoped to a 572 KB subtree it returned in 79 s. The wrapper must **warn when an `--add-dir` target is large** (file-count or du threshold) and the docs must say "scope to the relevant subtree, never the repo root." → see Task 4 amendment + Task 9 gotcha.

3. **agy invocations must be SERIALIZED (new constraint).** agy spawns a local gRPC language-server per call; concurrent invocations contend and hang. This matters for **x-research Max Mode and x-qa parallel runners**, which fan out backends. → Task 9 gotcha + a note for consumers; do **not** dispatch parallel `agy-agent` calls.

4. **Latency is ~2×, not 3–5×; the web/docs-currency gap is real.** Single scoped run: 79 s (agy) vs 37 s (gemini). The 3–5× figure only appears under the two pathologies above (huge `--add-dir`, concurrency). Separately: agy returned the repo's **legacy** event string instead of the current GA one because it trusted the repo over live docs — so `--grounded` (inject "Use Google Search") is **load-bearing for "what's current" questions**, not optional. → fix the gotchas.md latency line; keep `--grounded` (Task 4) and exercise it in Task 10.

---

## File Structure

| File | Responsibility | Action |
|---|---|---|
| `bin/agy-agent` | The wrapper: parse → resolve model/flags → preflight trust → exec agy → classify failure → emit | **Create** |
| `bin/tests/agy-agent.test.sh` | Offline unit tests (dry-run argv assertions) + failure-detection tests via fake-`agy` stub | **Create** |
| `bin/tests/fixtures/fake-agy` | Stub that mimics `agy -p` (canned stdout / empty / chrome) toggled by env, for offline tests | **Create** |
| `bin/setup` | Detect `agy` + timeout → `cap_set agy_cli`; bind `agy-agent` symlink; add to manifest + reports | **Modify** |
| `skills/x-gemini/SKILL.md` | Re-pin stale `flash`/`pro` aliases (independent fix); document `agy_cli` backend + `--backend` selection | **Modify** |
| `skills/x-gemini/gotchas.md` | Add agy-specific gotchas (exit-0-lies, trustedWorkspaces, no-JSON, chrome) | **Modify** |
| `skills/x-shared/capability-loading.md` | Register `agy_cli` in the capability schema + fallback table | **Modify** |

**Convention to follow:** copy `bin/gemini-agent`'s idioms exactly — UTF-8 locale probe (lines 21–32), timeout-binary resolution (81–90), Claude-env stripping via `env -u CLAUDECODE …` (160–164), 0600 log persistence with `! -L` symlink guard + `install -m 0600` (202–227), 50k-char tail truncation (323–328). Do **not** reinvent these; lift them.

---

## Task 1: Re-pin stale gemini model aliases (independent quick-fix, ships first)

**Why first:** verified live — `gemini-agent --model flash` AND `--model pro` both now resolve to `gemini-3-flash-preview`, and `-m gemini-2.5-flash` fails (empty stream). The `SKILL.md` Models table is wrong on both rows. This is a <10-line fix with no dependency on the rest of the plan; ship it so the dying gemini path is at least documented correctly.

**Files:**
- Modify: `skills/x-gemini/SKILL.md` (the Models table, ~lines 59–66)

- [ ] **Step 1: Verify current resolution (evidence before edit)**

Run:
```bash
cd /Users/randytran/Codes/x-skills
bin/gemini-agent --model flash "say PONG" 2>&1 >/dev/null | grep -o 'model=[^ ]*'
bin/gemini-agent --model pro   "say PONG" 2>&1 >/dev/null | grep -o 'model=[^ ]*'
```
Expected: both print `model=gemini-3-flash-preview` (confirming pro silently downgrades). If `pro` now shows a real Pro id, adjust the table to whatever it actually resolves to.

- [ ] **Step 2: Update the Models table**

In `skills/x-gemini/SKILL.md`, replace the table body rows so they reflect reality (use the ids observed in Step 1):

```markdown
| Alias | Resolves To (verified 2026-06-06) | Best For |
|---|---|---|
| `flash` (default) | `gemini-3-flash-preview` | Fast lookups, classification, summaries |
| `pro` | `gemini-3.1-pro-preview` *(⚠ observed downgrading to `gemini-3-flash-preview` — re-verify)* | Reasoning, deep analysis, multimodal |
| Full ID | passthrough | e.g., `gemini-3-flash-preview`; note `gemini-2.5-flash` now returns empty-stream errors |
```

- [ ] **Step 3: Commit**

```bash
git add skills/x-gemini/SKILL.md
git commit -m "fix(x-gemini): re-pin stale flash/pro model aliases to gemini-3 ids"
```

---

## Task 2: Scaffold `bin/agy-agent` (skeleton + arg parse + dry-run + empty-prompt guard)

**Files:**
- Create: `bin/agy-agent`
- Create: `bin/tests/agy-agent.test.sh`

- [ ] **Step 1: Write the failing test**

Create `bin/tests/agy-agent.test.sh`:
```bash
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

echo "---"; echo "PASS=$PASS FAIL=$FAIL"; [[ $FAIL -eq 0 ]]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash bin/tests/agy-agent.test.sh`
Expected: FAIL — `bin/agy-agent` does not exist yet (`No such file or directory`).

- [ ] **Step 3: Write minimal implementation**

Create `bin/agy-agent`:
```bash
#!/usr/bin/env bash
# agy-agent — wrapper for Google Antigravity CLI (agy) headless mode.
# Dual-track sibling of gemini-agent. Spec: docs/research/2026-06-06-agy-antigravity-cli-headless-usage-guide.md
#
# Usage:
#   agy-agent "<prompt>"                       # default model (flash)
#   agy-agent --model pro "<prompt>"           # Gemini 3.1 Pro (High)
#   agy-agent --add-dir /abs/dir "<prompt>"    # mount dir into workspace
#   agy-agent --resume "<follow-up>"           # continue latest conversation (-c)
#   agy-agent --conversation <id> "<prompt>"   # resume a specific conversation
#   agy-agent --grounded "<prompt>"            # inject "Use Google Search"
#   agy-agent --system /abs/sys.md "<prompt>"  # emulate system prompt (prepend)
#   agy-agent --sandbox / --yolo / --raw       # passthrough / output modes
set -uo pipefail

# UTF-8 locale so ${var: -N} counts chars not bytes (lifted from gemini-agent).
if [[ -z "${LC_ALL:-}" || "${LC_ALL%%.*}" == "C" ]]; then
  for _loc in C.UTF-8 en_US.UTF-8 C.utf8 en_US.utf8; do
    if locale -a 2>/dev/null | grep -qiE "^${_loc//./\\.}$"; then export LC_ALL="$_loc"; break; fi
  done
  unset _loc
fi

# --- Defaults ---
MODEL="${X_AGY_DEFAULT_MODEL:-}"
SYSTEM_MD=""
EXTRA_DIRS=()
RESUME=""          # "" | "latest" | "<id>"
GROUNDED=0
YOLO=0
SANDBOX=0
RAW=0

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --model|-m)        MODEL="${2:-}"; shift 2 || true ;;
    --model=*)         MODEL="${1#--model=}"; shift ;;
    --system)          SYSTEM_MD="${2:-}"; shift 2 || true ;;
    --system=*)        SYSTEM_MD="${1#--system=}"; shift ;;
    --add-dir|--dir)   EXTRA_DIRS+=("${2:-}"); shift 2 || true ;;
    --add-dir=*)       EXTRA_DIRS+=("${1#--add-dir=}"); shift ;;
    --resume|-r)       RESUME="latest"; shift ;;
    --conversation)    RESUME="${2:-}"; shift 2 || true ;;
    --conversation=*)  RESUME="${1#--conversation=}"; shift ;;
    --grounded)        GROUNDED=1; shift ;;
    --yolo)            YOLO=1; shift ;;
    --sandbox)         SANDBOX=1; shift ;;
    --raw)             RAW=1; shift ;;
    --help|-h)         sed -n '2,18p' "$0" | sed 's/^# //; s/^#//'; exit 0 ;;
    -*) echo "Error: Unknown flag: $1" >&2; exit 1 ;;
    *)  break ;;
  esac
done

PROMPT="${*:-}"
if [[ -z "$PROMPT" ]]; then
  echo "Error: prompt required" >&2
  echo "Usage: agy-agent [--model pro|flash|...] [--add-dir DIR] [--resume] [--grounded] [--system FILE] \"<prompt>\"" >&2
  exit 1
fi

# --- Verify agy CLI ---
if ! command -v agy &>/dev/null; then
  echo "Error: agy CLI not found on PATH" >&2
  echo "Install: https://antigravity.google/cli  (or run /x-skills:setup)" >&2
  exit 1
fi

# (model resolution — Task 3) (flag build — Task 4) (preflight — Task 5)
# (exec + classify — Task 6). For now: build a minimal argv and honor dry-run.
ARGS=(-p "$PROMPT")
[[ -n "$MODEL" ]] && ARGS+=(--model "$MODEL")

if [[ "${X_AGY_DRY_RUN:-0}" == "1" ]]; then
  printf 'agy\n'; printf '%s\n' "${ARGS[@]}"   # one arg per line — stable, escape-free test assertions
  exit 0
fi

# Placeholder exec (replaced in Task 6).
exec agy "${ARGS[@]}"
```

- [ ] **Step 4: Make executable, run test to verify it passes**

Run:
```bash
chmod +x bin/agy-agent
bash bin/tests/agy-agent.test.sh
```
Expected: `PASS=4 FAIL=0`

- [ ] **Step 5: Commit**

```bash
git add bin/agy-agent bin/tests/agy-agent.test.sh
git commit -m "feat(agy-agent): scaffold wrapper skeleton with dry-run + arg parse"
```

---

## Task 3: Model-alias map

**Files:**
- Modify: `bin/agy-agent`
- Modify: `bin/tests/agy-agent.test.sh`

- [ ] **Step 1: Write the failing test** — append to `bin/tests/agy-agent.test.sh` before the final summary block:

```bash
# T3 model alias resolution (dry-run shows --model with agy display string)
run_dry() { X_AGY_DRY_RUN=1 "$AGY_AGENT" "$@" 2>/dev/null; }
assert_contains "flash->display"  'Gemini 3.5 Flash (Medium)'  "$(run_dry --model flash x)"
assert_contains "pro->display"    'Gemini 3.1 Pro (High)'      "$(run_dry --model pro x)"
assert_contains "flash-low"       'Gemini 3.5 Flash (Low)'     "$(run_dry --model flash-low x)"
assert_contains "claude-opus"     'Claude Opus 4.6 (Thinking)' "$(run_dry --model claude-opus x)"
assert_contains "passthrough"     'Gemini 3.1 Pro (Low)'       "$(run_dry --model 'Gemini 3.1 Pro (Low)' x)"
# default (no --model) must still pin a model so headless isn't model-ambiguous
assert_contains "default flash"   'Gemini 3.5 Flash (Medium)'  "$(run_dry x)"
```
(Dry-run prints one arg per line, so assert on the plain model value — the `--model` flag and its value are on separate lines.)

- [ ] **Step 2: Run to verify it fails**

Run: `bash bin/tests/agy-agent.test.sh`
Expected: FAIL on the T3 assertions — aliases are passed through verbatim, not mapped, and default has no `--model`.

- [ ] **Step 3: Implement the alias map** — in `bin/agy-agent`, replace the `ARGS=(-p "$PROMPT"); [[ -n "$MODEL" ]] && ARGS+=(--model "$MODEL")` block with:

```bash
# --- Resolve model alias to agy's exact display string (verified via `agy models`) ---
resolve_model() {
  case "$1" in
    ""|flash|flash-medium) echo "Gemini 3.5 Flash (Medium)" ;;
    flash-low)             echo "Gemini 3.5 Flash (Low)" ;;
    flash-high)            echo "Gemini 3.5 Flash (High)" ;;
    pro|pro-high)          echo "Gemini 3.1 Pro (High)" ;;
    pro-low)               echo "Gemini 3.1 Pro (Low)" ;;
    claude-sonnet)         echo "Claude Sonnet 4.6 (Thinking)" ;;
    claude-opus)           echo "Claude Opus 4.6 (Thinking)" ;;
    gpt-oss)               echo "GPT-OSS 120B (Medium)" ;;
    *)                     echo "$1" ;;   # passthrough: already an agy display string
  esac
}
MODEL_RESOLVED="$(resolve_model "$MODEL")"

ARGS=(-p "$PROMPT")
ARGS+=(--model "$MODEL_RESOLVED")
```

- [ ] **Step 4: Run to verify it passes**

Run: `bash bin/tests/agy-agent.test.sh`
Expected: all PASS (`FAIL=0`).

- [ ] **Step 5: Commit**

```bash
git add bin/agy-agent bin/tests/agy-agent.test.sh
git commit -m "feat(agy-agent): map model aliases to agy display strings"
```

---

## Task 4: Flag translation (add-dir, resume, grounding, system-prompt, sandbox/yolo)

**Files:**
- Modify: `bin/agy-agent`
- Modify: `bin/tests/agy-agent.test.sh`

- [ ] **Step 1: Write the failing test** — append before the summary block:

```bash
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
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash bin/tests/agy-agent.test.sh`
Expected: FAIL on T4 — none of these flags are wired yet.

- [ ] **Step 3: Implement** — in `bin/agy-agent`, **before** the `ARGS=(-p "$PROMPT")` line (so the prompt is fully assembled first), insert prompt assembly; then extend the argv build. Replace the Task-3 block with:

```bash
# --- Assemble final prompt (system prepend + grounding directive) ---
if [[ -n "$SYSTEM_MD" ]]; then
  if [[ ! -f "$SYSTEM_MD" ]]; then echo "Error: system prompt file not found: $SYSTEM_MD" >&2; exit 1; fi
  PROMPT="$(cat "$SYSTEM_MD")"$'\n\n---\n\n'"$PROMPT"
fi
if [[ "$GROUNDED" -eq 1 ]]; then
  PROMPT="$PROMPT"$'\n\n(Use Google Search to ground your answer in current sources and cite URLs.)'
fi

MODEL_RESOLVED="$(resolve_model "$MODEL")"

ARGS=(-p "$PROMPT")
ARGS+=(--model "$MODEL_RESOLVED")

# --add-dir: validate each path (reject leading '-'; warn+skip missing dirs)
for d in "${EXTRA_DIRS[@]+"${EXTRA_DIRS[@]}"}"; do
  if [[ "$d" == -* ]]; then echo "Error: --add-dir path begins with '-' (rejected): $d" >&2; exit 1; fi
  if [[ ! -d "$d" ]]; then echo "Warning: --add-dir not a directory: $d (skipping)" >&2; continue; fi
  # AMENDMENT (finding #2): a large --add-dir makes agy's traversal hang (15-25min, 0 bytes).
  # Warn past a threshold; `find|head` bounds the cost so we don't walk a 65GB tree to count it.
  fcount=$(find "$d" -type f 2>/dev/null | head -n "${X_AGY_ADDDIR_MAX:-2000}" | wc -l | tr -d ' ')
  if [[ "$fcount" -ge "${X_AGY_ADDDIR_MAX:-2000}" ]]; then
    echo "[agy-agent] WARNING: --add-dir '$d' has ≥${X_AGY_ADDDIR_MAX:-2000} files — agy may hang on traversal." >&2
    echo "[agy-agent]   Scope to a specific subtree (e.g. src/<feature>), not a repo root." >&2
  fi
  ARGS+=(--add-dir "$d")
done

# resume: "latest" -> -c ; specific id -> --conversation <id>
if [[ "$RESUME" == "latest" ]]; then
  ARGS+=(-c)
elif [[ -n "$RESUME" ]]; then
  ARGS+=(--conversation "$RESUME")
fi

[[ "$SANDBOX" -eq 1 ]] && ARGS+=(--sandbox)
[[ "$YOLO" -eq 1 ]]    && ARGS+=(--dangerously-skip-permissions)
```

(Keep `resolve_model()` defined above this block.)

- [ ] **Step 4: Run to verify it passes**

Run: `bash bin/tests/agy-agent.test.sh`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add bin/agy-agent bin/tests/agy-agent.test.sh
git commit -m "feat(agy-agent): translate add-dir/resume/grounding/system/sandbox/yolo flags"
```

---

## Task 5: trustedWorkspaces preflight

**Why:** verified gotcha — agy hangs on an interactive trust prompt for an untrusted workspace in non-TTY. `~/.gemini/antigravity-cli/settings.json` holds `trustedWorkspaces`. Preflight: if CWD (or any `--add-dir`) is not trusted, warn loudly with the exact remediation (and, only when `X_AGY_AUTO_TRUST=1`, append it).

**Files:**
- Modify: `bin/agy-agent`
- Modify: `bin/tests/agy-agent.test.sh`

- [ ] **Step 1: Write the failing test** — append:

```bash
# T5 trust preflight warns (to stderr) when CWD not trusted; never blocks dry-run
fakehome=$(mktemp -d); mkdir -p "$fakehome/.gemini/antigravity-cli"
echo '{"trustedWorkspaces":[]}' > "$fakehome/.gemini/antigravity-cli/settings.json"
err=$(cd /tmp && HOME="$fakehome" X_AGY_DRY_RUN=1 "$AGY_AGENT" x 2>&1 >/dev/null)
assert_contains "untrusted warns" "not a trusted workspace" "$err"
# trusted CWD -> no warning
echo "{\"trustedWorkspaces\":[\"/tmp\"]}" > "$fakehome/.gemini/antigravity-cli/settings.json"
err=$(cd /tmp && HOME="$fakehome" X_AGY_DRY_RUN=1 "$AGY_AGENT" x 2>&1 >/dev/null)
assert_eq "trusted is silent" "" "$err"
rm -rf "$fakehome"
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash bin/tests/agy-agent.test.sh`
Expected: FAIL — no preflight emitted.

- [ ] **Step 3: Implement** — insert in `bin/agy-agent` after the agy-presence check and before the dry-run block:

```bash
# --- trustedWorkspaces preflight (avoids interactive trust-prompt hang) ---
AGY_SETTINGS="${HOME}/.gemini/antigravity-cli/settings.json"
is_trusted() { # $1 = absolute path
  [[ -f "$AGY_SETTINGS" ]] || return 1
  command -v jq &>/dev/null || return 0   # can't check without jq -> assume ok, don't block
  jq -e --arg p "$1" '(.trustedWorkspaces // []) | index($p)' "$AGY_SETTINGS" >/dev/null 2>&1
}
CWD_ABS="$(pwd -P)"
if ! is_trusted "$CWD_ABS"; then
  if [[ "${X_AGY_AUTO_TRUST:-0}" == "1" && -w "$AGY_SETTINGS" ]]; then
    tmp="$(mktemp)"; jq --arg p "$CWD_ABS" '.trustedWorkspaces = ((.trustedWorkspaces // []) + [$p] | unique)' \
      "$AGY_SETTINGS" > "$tmp" 2>/dev/null && mv "$tmp" "$AGY_SETTINGS" \
      && echo "[agy-agent] auto-trusted workspace: $CWD_ABS" >&2
  else
    echo "[agy-agent] WARNING: '$CWD_ABS' is not a trusted workspace in $AGY_SETTINGS." >&2
    echo "[agy-agent]   agy may hang on an interactive trust prompt. Fix: add the path to trustedWorkspaces," >&2
    echo "[agy-agent]   or re-run with X_AGY_AUTO_TRUST=1 to append it automatically." >&2
  fi
fi
```

- [ ] **Step 4: Run to verify it passes**

Run: `bash bin/tests/agy-agent.test.sh`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add bin/agy-agent bin/tests/agy-agent.test.sh
git commit -m "feat(agy-agent): trustedWorkspaces preflight to avoid headless trust-prompt hang"
```

---

## Task 6: Execution, failure detection (synthetic exit code), logging, truncation, stderr summary

**This is the core.** agy exits `0` even on auth/quota/empty failures → the wrapper treats **empty/whitespace stdout** as failure and classifies via agy's own `--log-file`. It also strips the optional `### Work Summary` chrome (opt-in) and truncates at 50k chars (lifted from gemini-agent).

**Files:**
- Modify: `bin/agy-agent`
- Create: `bin/tests/fixtures/fake-agy`
- Modify: `bin/tests/agy-agent.test.sh`

- [ ] **Step 1: Create the fake-agy stub**

Create `bin/tests/fixtures/fake-agy`:
```bash
#!/usr/bin/env bash
# Test double for `agy`. Behavior toggled by env:
#   FAKE_AGY_MODE=ok      -> print canned response, exit 0
#   FAKE_AGY_MODE=empty   -> print nothing, exit 0 (agy's "exit-0 lies" failure)
#   FAKE_AGY_MODE=chrome  -> print response + "### Work Summary" block, exit 0
#   FAKE_AGY_MODE=authlog -> empty stdout, write 'not authenticated' to --log-file, exit 0
#   FAKE_AGY_MODE=noiselog-> empty stdout, write the REAL always-present auth NOISE (appears on
#                            success too) to --log-file, exit 0 — regression guard for finding #1
# Recognizes -p, --model, --log-file; ignores the rest.
LOG=""
while [[ $# -gt 0 ]]; do case "$1" in --log-file) LOG="$2"; shift 2;; *) shift;; esac; done
case "${FAKE_AGY_MODE:-ok}" in
  ok)       printf 'PONG\n' ;;
  empty)    : ;;
  chrome)   printf 'PONG\n\n### Work Summary\n* did a thing\n' ;;
  authlog)  [[ -n "$LOG" ]] && echo 'error: not authenticated' > "$LOG" ;;
  noiselog) [[ -n "$LOG" ]] && printf '%s\n%s\n' \
              'W log_context.go:117] Cache(loadCodeAssistResponse): Singleflight refresh failed: error getting token source: You are not logged into Antigravity.' \
              'W client.go:81] failed to set auth token' > "$LOG" ;;
esac
exit 0
```
Run: `chmod +x bin/tests/fixtures/fake-agy`

- [ ] **Step 2: Write the failing tests** — append to `bin/tests/agy-agent.test.sh`:

```bash
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
```

- [ ] **Step 3: Run to verify it fails**

Run: `bash bin/tests/agy-agent.test.sh`
Expected: FAIL on T6 — current wrapper `exec agy …` (no detection/exit synthesis/chrome handling).

- [ ] **Step 4: Implement** — in `bin/agy-agent`, replace the dry-run block's trailing `exec agy "${ARGS[@]}"` (and everything after the dry-run `exit 0`) with the full exec+classify tail:

```bash
if [[ "${X_AGY_DRY_RUN:-0}" == "1" ]]; then
  printf 'agy\n'; printf '%s\n' "${ARGS[@]}"   # one arg per line — stable, escape-free test assertions
  exit 0
fi

# --- Resolve timeout binary (macOS lacks `timeout` without coreutils) ---
if command -v timeout &>/dev/null; then TIMEOUT_BIN="timeout"
elif command -v gtimeout &>/dev/null; then TIMEOUT_BIN="gtimeout"
else echo "Error: neither 'timeout' nor 'gtimeout' on PATH (brew install coreutils)" >&2; exit 1; fi
AGY_TIMEOUT="${AGY_TIMEOUT:-600}"

# agy's own run log — used to classify failures (agy exits 0 even on error).
RUN_LOG="$(mktemp /tmp/agy-agent-runlog-XXXXXXXX)"
OUT_TMP="$(mktemp /tmp/agy-agent-out-XXXXXXXX)"
ERR_TMP="$(mktemp /tmp/agy-agent-err-XXXXXXXX)"
trap 'rm -f "$RUN_LOG" "$OUT_TMP" "$ERR_TMP"' EXIT
ARGS+=(--log-file "$RUN_LOG" --print-timeout "${AGY_TIMEOUT}s")

LABEL="${MODEL:-flash}"
START=$(date +%s)
echo "[agy-agent] started model=$LABEL at $(date +%H:%M:%S) (timeout=${AGY_TIMEOUT}s)" >&2

env -u CLAUDECODE -u CLAUDE_SESSION_ID -u CLAUDECODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT \
  "$TIMEOUT_BIN" "$AGY_TIMEOUT" agy "${ARGS[@]}" > "$OUT_TMP" 2> "$ERR_TMP"
RAW_EXIT=$?
DURATION=$(( $(date +%s) - START ))

# --- Failure detection: agy exits 0 even on failure, so judge by output + log ---
RESPONSE="$(cat "$OUT_TMP")"
STRIPPED="${RESPONSE//[$' \t\n\r']/}"   # whitespace-only counts as empty
STATUS="success"; SYNTH_EXIT=0
if [[ "$RAW_EXIT" -eq 124 ]]; then
  STATUS="timeout"; SYNTH_EXIT=124
elif [[ -z "$STRIPPED" ]]; then
  SYNTH_EXIT=1
  # AMENDMENT (finding #1): agy's log ALWAYS contains "not logged into Antigravity" and
  # "failed to set auth token" — even on SUCCESSFUL runs (auxiliary admin/experiment caches,
  # NOT the model-serving path). Verified in the merged research doc Part 2 (§8/§14). So those
  # strings are NOISE, not auth signal. Strip the known-noise lines first, check quota/planner
  # before auth, and only call it auth on a specific serving-path marker.
  diag="$(grep -ivE 'not logged into Antigravity|failed to set auth token|loadCodeAssistResponse|fetchAdminControls|ListExperiments|availableModels|Singleflight' "$RUN_LOG" "$ERR_TMP" 2>/dev/null)"
  if   grep -qiE 'quota|exhaust|rate.?limit|credit' <<<"$diag"; then STATUS="quota_error"
  elif grep -qiE 'PlannerResponse|panic' <<<"$diag"; then STATUS="planner_empty"
  elif grep -qiE 'not authenticated|unauthor|invalid.{0,3}token|token expired|sign.?in required|403' <<<"$diag"; then STATUS="auth_error"
  else STATUS="empty_output"; fi
elif [[ "$RAW_EXIT" -ne 0 ]]; then
  STATUS="error_exit_${RAW_EXIT}"; SYNTH_EXIT="$RAW_EXIT"
fi

# --- Persist log (0600, user-private) unless disabled (lifted from gemini-agent) ---
DEBUG_LOG="(disabled)"
if [[ "${X_AGY_NO_LOG:-0}" != "1" ]]; then
  TS=$(date +%Y%m%d-%H%M%S)
  DIR="${XDG_CACHE_HOME:-$HOME/.cache}/x-skills/agy"
  if mkdir -p "$DIR" 2>/dev/null; then
    DEBUG_LOG="$DIR/agy-agent-${TS}-${LABEL// /_}.log"
    if [[ ! -L "$DEBUG_LOG" ]]; then
      install -m 0600 /dev/null "$DEBUG_LOG" 2>/dev/null && { cat "$OUT_TMP" "$RUN_LOG" > "$DEBUG_LOG" 2>/dev/null; } || DEBUG_LOG="(disabled)"
    else DEBUG_LOG="(disabled)"; fi
  fi
fi

# --- On failure: surface diagnosis, emit summary, exit non-zero ---
if [[ "$SYNTH_EXIT" -ne 0 ]]; then
  echo "[agy-agent] FAILED status=${STATUS} (agy raw exit=${RAW_EXIT}; agy exits 0 even on error — judged by empty output + log)" >&2
  tail -5 "$RUN_LOG" "$ERR_TMP" 2>/dev/null | sed 's/^/[agy-agent]   /' >&2
  echo "[agy-agent] $LABEL | duration=${DURATION}s | status=${STATUS} | log=${DEBUG_LOG}" >&2
  exit "$SYNTH_EXIT"
fi

# --- Success path: optional chrome strip, truncation, emit ---
if [[ "$RAW" -eq 0 && "${X_AGY_STRIP_SUMMARY:-0}" == "1" ]]; then
  RESPONSE="${RESPONSE%%$'\n'### Work Summary*}"
fi
MAX_CHARS=50000
if [[ "${#RESPONSE}" -gt "$MAX_CHARS" ]]; then
  RESPONSE="[agy-agent: truncated — showing tail]"$'\n\n'"${RESPONSE: -$MAX_CHARS}"
fi
printf '%s\n' "$RESPONSE"
echo "[agy-agent] $LABEL | duration=${DURATION}s | status=${STATUS} | log=${DEBUG_LOG}" >&2
exit 0
```

- [ ] **Step 5: Run to verify it passes**

Run: `bash bin/tests/agy-agent.test.sh`
Expected: all PASS (`FAIL=0`).

- [ ] **Step 6: Commit**

```bash
git add bin/agy-agent bin/tests/agy-agent.test.sh bin/tests/fixtures/fake-agy
git commit -m "feat(agy-agent): exec + synthetic-exit failure detection + logging + chrome strip"
```

---

## Task 7: Live smoke test (gated, real agy)

**Files:**
- Modify: `bin/tests/agy-agent.test.sh`

- [ ] **Step 1: Add a gated live block** at the very end of the test (before the final `[[ $FAIL -eq 0 ]]`):

```bash
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
```

- [ ] **Step 2: Run offline (live skipped) then live**

Run: `bash bin/tests/agy-agent.test.sh`  → Expected: PASS, prints the skip line.
Run: `X_AGY_LIVE=1 bash bin/tests/agy-agent.test.sh`  → Expected: PASS including live (budget ~150s).

- [ ] **Step 3: Commit**

```bash
git add bin/tests/agy-agent.test.sh
git commit -m "test(agy-agent): add gated live smoke (PONG + grounding)"
```

---

## Task 8: Wire `agy_cli` capability + agy-agent binding into `bin/setup`

**Files:**
- Modify: `bin/setup` (mirror the `gemini` blocks — see line refs below)

- [ ] **Step 1: Add source/link path vars** — near `bin/setup:16` (after `GEMINI_AGENT_SRC=…`) and `:23` (after `GEMINI_LINK_PATH=…`):

```bash
AGY_AGENT_SRC="$PLUGIN_DIR/bin/agy-agent"
AGY_LINK_PATH="$LINK_DIR/agy-agent"
```

- [ ] **Step 2: Add detection + binding section** — after the `1c. Gemini CLI` block (ends ~`bin/setup:578`), insert a `1d. Antigravity CLI` section modeled on `1b`+`1c`:

```bash
# --- 1d. Antigravity CLI (agy) — dual-track backend for x-gemini ---
header "1d. Antigravity CLI (agy) — fallback backend for x-gemini"
AGY_PRESENT=0
command -v agy &>/dev/null && AGY_PRESENT=1
if [[ -f "$AGY_AGENT_SRC" ]]; then
  chmod +x "$AGY_AGENT_SRC"; install_symlink "$AGY_AGENT_SRC" "$AGY_LINK_PATH"
fi
if [[ $AGY_PRESENT -eq 1 ]]; then
  ok "agy found: $(agy --version 2>/dev/null || echo unknown)"
else
  info "agy CLI not found (optional until gemini Ultra serving ends 2026-06-18)"
  missing_add "cli" "agy" "Antigravity CLI (fallback backend for x-gemini)" "https://antigravity.google/cli"
fi
# Same timeout gate as gemini (TIMEOUT_PRESENT is set in 1c).
if [[ $AGY_PRESENT -eq 1 && ${TIMEOUT_PRESENT:-0} -eq 1 ]]; then
  cap_set agy_cli true
else
  cap_set agy_cli false
fi
```

- [ ] **Step 3: Add to the manifest jq block** — at `bin/setup:914` (after the `"gemini_cli": …` line):

```bash
        "agy_cli":            cap("$(cap_get agy_cli)"),
```

- [ ] **Step 4: Add to capability-met switch + skill report** — at `bin/setup:981` (in the `case` near `gemini_cli)`):

```bash
      agy_cli)        [[ "$(cap_get agy_cli)" == "true" ]] && met=true ;;
```
and update the x-gemini report at `bin/setup:1011` so EITHER backend satisfies it:
```bash
report_skill "x-gemini"       gemini_cli agy_cli
```
(Confirm `report_skill` treats multiple flags as OR; if it's AND, change x-gemini's line to report ok when either is met — read the function near line 970–1000 and adjust.)

- [ ] **Step 5: Verify setup runs clean**

Run:
```bash
cd /Users/randytran/Codes/x-skills
bash bin/setup --detect-only 2>&1 | grep -iE 'agy|agy_cli' || bash bin/setup 2>&1 | tail -40
jq '.capabilities.agy_cli' ~/.config/x-skills/capabilities.json
```
Expected: `agy_cli` appears in output and is `true` (agy is installed on this machine) in the manifest.

- [ ] **Step 6: Commit**

```bash
git add bin/setup
git commit -m "feat(setup): detect agy, bind agy-agent, emit agy_cli capability"
```

---

## Task 9: Document the backend in skill + shared docs

**Files:**
- Modify: `skills/x-gemini/SKILL.md`
- Modify: `skills/x-gemini/gotchas.md`
- Modify: `skills/x-shared/capability-loading.md`

- [ ] **Step 1: x-gemini SKILL.md — add a Backend Selection section** after the Bootstrap block:

```markdown
## Backend Selection (gemini vs agy)

x-gemini has two interchangeable backends. The wrappers share a flag surface (`--model`, `--add-dir`/`--file`, `--resume`, `--system`).

| Backend | Wrapper | Capability | Use when |
|---|---|---|---|
| Gemini CLI (default) | `gemini-agent` | `gemini_cli` | preferred while it serves (Ultra serving ends **2026-06-18**) |
| Antigravity CLI | `agy-agent` | `agy_cli` | gemini unavailable, or `--backend agy`, or after the cutoff |

**Routing:** prefer `gemini-agent` when `gemini_cli` is pinned; else fall back to `agy-agent` when `agy_cli` is pinned. Model aliases (`flash`, `pro`) map on both. agy adds `claude-sonnet`/`claude-opus`/`gpt-oss`. agy outputs plain text only (no JSON), and the wrapper synthesizes a real exit code (agy itself exits 0 even on failure).
```

- [ ] **Step 2: gotchas.md — append agy gotchas** (verbatim from the research doc §10):

```markdown
## agy backend (agy-agent)

- **No JSON.** agy print mode is plain text; there is no `--json`/`--output-format`. `agy-agent` emits the text directly.
- **Exit 0 lies.** agy exits 0 even on auth/quota/empty failures. `agy-agent` re-derives a real exit code from empty-stdout + `--log-file` tail; trust the wrapper's exit code, not agy's.
- **trustedWorkspaces.** agy hangs on a trust prompt for untrusted dirs in non-TTY. `agy-agent` preflights and warns; set `X_AGY_AUTO_TRUST=1` to auto-append CWD.
- **Grounding is prompt-driven** (no flag) AND load-bearing for currency. Without `--grounded`, agy trusts the repo over live docs and will return stale identifiers (verified: it returned a *legacy* OpenAI event the repo still contained instead of the current GA one). Pass `--grounded` for any "what's current / latest version" question.
- **Never `--add-dir` a large tree.** Pointing it at a repo root (e.g. a 65 GB monorepo with node_modules/build/vendored checkouts) makes agy's agentic traversal hang for 15–25 min with zero output. Scope to the relevant subtree(s) — a 572 KB scope returned in 79 s. `agy-agent` warns when a target looks large.
- **Serialize agy calls.** agy spawns a local gRPC language-server per invocation; concurrent calls contend and hang. Consumers that fan out (x-research Max Mode, x-qa parallel runners) MUST run agy lanes sequentially, not in parallel.
- **Auth noise in the log is NOT an auth failure.** Every run's log contains `not logged into Antigravity` / `failed to set auth token` (auxiliary caches), even on success. Don't classify on it; trust `agy-agent`'s status, which strips this noise.
- **Latency** ~2× the gemini wrapper for a single scoped grounded run (≈79 s vs ≈37 s) — NOT 3–5×. The 3–5× only appears under the two pathologies above (huge `--add-dir`, concurrency). Route bulk work to `--model flash-low`.
```

- [ ] **Step 3: capability-loading.md — register `agy_cli`** in the capability list/schema and add the fallback row:

```markdown
| `agy_cli` | Antigravity CLI (`agy`) present + timeout binary | `agy-agent` available as x-gemini backend; fallback when `gemini_cli` is false (mandatory after 2026-06-18) |
```

- [ ] **Step 4: Commit**

```bash
git add skills/x-gemini/SKILL.md skills/x-gemini/gotchas.md skills/x-shared/capability-loading.md
git commit -m "docs(x-gemini): document agy-agent backend, selection, and gotchas"
```

---

## Task 10: Consumer validation + cutover note (no code; evidence-gathering)

**Files:**
- Modify: `docs/research/2026-06-06-agy-antigravity-cli-headless-usage-guide.md` (append a "Validation results" section)

- [ ] **Step 1: Run each heavy consumer through agy once** and record latency/quality:

Run (manually, recording outputs):
```bash
# A library-current-state lookup (x-research signal): grounded flash
agy-agent --model flash-low --grounded "Is the 'zod' npm package still actively maintained? Latest version + last release date, cite URLs."
# A multi-file review (x-review signal): pro on a small dir
agy-agent --model pro --add-dir skills/x-gemini "List the top 3 risks in this wrapper as FILE:LINE — list only."
```

- [ ] **Step 2: Append a "Validation results (YYYY-MM-DD)" table** to the research doc with: backend, prompt class, latency, whether output was usable, any failure-detection hits. Note whether grounding cited real URLs and whether chrome appeared.

- [ ] **Step 3: Record the cutover trigger** in the same section:

```markdown
### Cutover plan
- Now → 2026-06-17: `gemini_cli` stays default; `agy_cli` available via `--backend agy`.
- 2026-06-18 (Ultra serving ends): flip x-gemini routing so `agy_cli` is preferred when `gemini_cli` live-check fails. Re-pin model aliases if agy's `agy models` list changed (re-run `agy models`).
```

- [ ] **Step 4: Commit**

```bash
git add docs/research/2026-06-06-agy-antigravity-cli-headless-usage-guide.md
git commit -m "docs(research): agy consumer-validation results + cutover trigger"
```

---

## Self-Review (completed by plan author)

**Spec coverage** (against research doc §11 wrapper table): model-alias map ✓ (T3), `--file`→`--add-dir` ✓ (T4), `--system` emulation ✓ (T4), `--resume`→`-c`/`--conversation` ✓ (T4), grounding injection ✓ (T4), empty-stdout+log-tail failure detection ✓ (T6), chrome strip ✓ (T6), `trustedWorkspaces` preflight ✓ (T5), capability flag + setup wiring ✓ (T8), docs ✓ (T9), validation/cutover ✓ (T10), the independent SKILL.md alias fix ✓ (T1). **Dropped by design (no JSON):** stats/session-id/thinking-starvation — explicitly out of scope, documented in T9.

**Known open item (flagged, not a placeholder):** capturing a conversation **id** from a headless `-p` run is unverified (research doc §7). `--resume` (latest, via `-c`) works; explicit `--conversation <id>` is wired but id-capture is a follow-up probe — not blocking, because `-c` covers the multi-turn case. T10 can add an id-capture probe if a consumer needs it.

**Type/flag consistency:** env knobs are uniform `X_AGY_*` (`X_AGY_DRY_RUN`, `X_AGY_NO_LOG`, `X_AGY_DEFAULT_MODEL`, `X_AGY_AUTO_TRUST`, `X_AGY_STRIP_SUMMARY`, `X_AGY_ADDDIR_MAX`, `AGY_TIMEOUT`); model aliases identical across T3 map and T9 docs; `resolve_model()` named consistently; fake-agy modes (`ok/empty/chrome/authlog/noiselog`) match the T6 assertions.

**Eval-harness amendments (2026-06-06):** the four findings from the merged research doc Part 2 (§12–15) are integrated — classifier auth-noise bug fixed + regression-tested (T6 `noiselog`), large-`--add-dir` guard (T4), serialization + currency + latency gotchas (T9). See the "Findings & Amendments" section near the top.

**Placeholder scan:** none — every code step is complete and copy-pasteable.
