# agy-agent: Full Replacement of gemini-agent (Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **History:** this began as a *dual-track* plan (keep gemini-agent as default, add agy as fallback). It was rewritten on **2026-06-08** to a **full replacement** (`agy` becomes the sole Google-model backend; `gemini-agent` is deleted) — see the x-review trail in the Self-Review. The wrapper Tasks 2–7 are identical to the dual-track version (the wrapper itself doesn't change); only the framing and the suite-migration tail (Tasks 8–14) differ.

**Goal:** Replace `bin/gemini-agent` **entirely** with `bin/agy-agent`, a headless wrapper for Google's Antigravity CLI (`agy`), as the **sole Google-model backend across the whole x-skills suite**. The standalone `gemini` CLI stops serving AI Ultra/Pro/free on **2026-06-18**; rather than maintain a dying dual-track, this plan migrates **every** consumer to agy, replaces the `gemini_cli` capability with `agy_cli`, and deletes `bin/gemini-agent`. **Phased so the suite never points at a removed binary:** add agy end-to-end → migrate consumers → delete gemini last (Task 14).

**Architecture:** `agy-agent` mirrors the shape of `bin/gemini-agent` (arg parse → resolve → exec → classify → emit response + stderr summary) but drops everything that depended on Gemini's JSON output (stats, session-id, thinking-starvation detector) because **agy print mode is plain text only**. It adds two things agy lacks: a **synthetic exit code** (agy exits `0` even on auth/quota/empty failures, so the wrapper detects failure via empty-stdout + log-tail and exits non-zero) and a **model-alias map** to agy's exact display strings. `agy-agent` is the **sole** backend: `gemini_cli` is replaced by `agy_cli` end-to-end (manifest → projection hook → ~10 skill gate lines), every `gemini-agent` call site is migrated to `agy-agent`, and `bin/gemini-agent` is deleted last. **Two consumers need real rework, not a rename:** **x-research** (parallel fan-out of backends) and **x-qa** (parallel case waves + JSON-parsing eval scripts) — because agy is **plain-text-only** and **MUST be serialized** (concurrent agy calls hang on a per-call gRPC server). Those get dedicated tasks (12, 13); the rest are mechanical `--file`→`--add-dir` remaps and `gemini_cli`→`agy_cli` renames.

**Tech Stack:** Bash (set -uo pipefail), `jq` (agy-agent `trustedWorkspaces` preflight — Task 5; optional, degrades gracefully when absent), `agy` v1.0.6+ CLI, `timeout`/`gtimeout` (coreutils). The `bin/setup` capability manifest is emitted via a `python3` heredoc (not jq). Plain-shell test scripts (no bats — matches `skills/x-worktree-isolate/tests/`).

**Spec source:** `docs/research/2026-06-06-agy-antigravity-cli-headless-usage-guide.md` (binary-verified). Read it before starting — every flag/path/behavior below traces to a verified finding there.

**Validation source (NEW):** `docs/research/2026-06-06-agy-antigravity-cli-headless-usage-guide.md` **Part 2 (§12–15)** — a live 3-backend bake-off (agy vs gemini-agent vs omo-explore) replaying a real research prompt against 2 primary-source anchors. It produced the amendments below. Read it before Task 6 and Task 10. (Runnable harness: `docs/research/agy-eval-harness/`.)

---

## Findings & Amendments (eval harness, 2026-06-06)

The bake-off confirmed the plan's core thesis (**agy is a viable gemini-CLI replacement for repo-grounded research** — it tied gemini on the anchors, *beat* it on grounding because it reads the repo, and ran ~2× slower not 3–5×). But it overturned four specifics this plan currently gets wrong. Apply these where flagged inline.

1. **The Task 6 auth classifier is BROKEN as written — fix required.** agy writes `error getting token source: You are not logged into Antigravity` + `failed to set auth token` into its log on **every** run, *including successful ones* (they're for auxiliary `loadCodeAssistResponse`/`fetchAdminControls`/`ListExperiments` caches, not model serving). The Task 6 classifier greps the log for `auth|...|credential` whenever stdout is empty → it will mislabel **every** empty-output failure (traversal hang, quota, planner-empty) as `auth_error`. The auth string is noise, not signal. → **Patched inline in Task 6 Step 4 below** (auth bucket demoted; check timeout/quota/planner first; only call it auth on a *specific, serving-path* marker).

2. **`--add-dir` on a large tree hangs agy — add a guard (Task 4).** Pointing `--add-dir` at the 65 GB oneclaw repo root caused agy to hang for 15–25 min with zero output (agentic traversal blowup). Scoped to a 572 KB subtree it returned in 79 s. The wrapper must **warn when an `--add-dir` target is large** (file-count or du threshold) and the docs must say "scope to the relevant subtree, never the repo root." → see Task 4 amendment + Task 9 gotcha.

3. **agy invocations must be SERIALIZED (new constraint).** agy spawns a local gRPC language-server per call; concurrent invocations contend and hang. This is now **load-bearing for the whole migration**: the two consumers that fan out the backend in parallel — **x-research** (default fan-out + Max Mode, up to 5 background lanes) and **x-qa** (case waves capped at `--max-bg`) — cannot just swap `gemini-agent`→`agy-agent`; their concurrency model must change so the agy lane runs **sequentially**. → dedicated rework in **Task 12** (x-research) and **Task 13** (x-qa); gotcha documented in Task 9; do **not** dispatch parallel `agy-agent` calls anywhere.

4. **Latency is ~2×, not 3–5×; the web/docs-currency gap is real.** Single scoped run: 79 s (agy) vs 37 s (gemini). The 3–5× figure only appears under the two pathologies above (huge `--add-dir`, concurrency). Separately: agy returned the repo's **legacy** event string instead of the current GA one because it trusted the repo over live docs — so `--grounded` (inject "Use Google Search") is **load-bearing for "what's current" questions**, not optional. → fix the gotchas.md latency line; keep `--grounded` (Task 4) and exercise it in Task 10.

---

## File Structure

**Phase A — the wrapper (Tasks 2–7):**

| File | Responsibility | Action |
|---|---|---|
| `bin/agy-agent` | The wrapper: parse → resolve model/flags → preflight trust → exec agy → classify failure → emit | **Create** |
| `bin/tests/agy-agent.test.sh` | Offline unit tests (dry-run argv assertions) + failure-detection tests via fake-`agy` stub | **Create** |
| `bin/tests/fixtures/fake-agy` | Stub that mimics `agy -p` (canned stdout / empty / chrome) toggled by env, for offline tests | **Create** |

**Phase B — add `agy_cli` end-to-end (Task 8):**

| File | Responsibility | Action |
|---|---|---|
| `bin/setup` | Detect `agy` + timeout → `cap_set agy_cli`; bind `agy-agent` symlink; emit `agy_cli` in manifest + case-arm. (gemini bits stay until Task 14) | **Modify** |
| `skills/x-shared/capability-loading.md` | Register `agy_cli` in the capability schema (the canonical boolean key) | **Modify** |
| `hooks/inject-capabilities.sh` | Project `agy_cli` into the `[x-skills/capabilities]` SessionStart line (line 44) | **Modify** |

**Phase C — migrate consumers off `gemini-agent`/`gemini_cli` (Tasks 9–13):**

| File | Responsibility | Action |
|---|---|---|
| `skills/x-gemini/SKILL.md` | Reframe to agy-only backend: `--model` alias table, `--file`→`--add-dir`, remove `--stream`/`--output-format`/`@file`/JSON-surface docs; add `--grounded` | **Modify** (Task 9) |
| `skills/x-gemini/gotchas.md` | Replace gemini gotchas with agy-specific ones (exit-0-lies, trustedWorkspaces, no-JSON, chrome, serialize, large-`--add-dir`, currency) | **Modify** (Task 9) |
| `skills/x-bugfix/SKILL.md`, `skills/x-review/{SKILL.md,steps/step-02-review.md}`, `skills/x-do/steps/step-03-review.md`, `skills/x-guide/{steps/step-02-ingest.md,references/routing-matrix.md,gotchas.md}`, `skills/x-mindful/steps/step-01-detect.md`, `skills/x-worktree-isolate/SKILL.md`, `skills/x-shared/{omo-routing.md,mcp-toolbox.md,invocation-guide.md,common-gotchas.md}`, `skills/x-research/references/synthesis-rules.md`, `skills/x-qa/references/{scout-prompt.md,init-interview.md}`, `README.md`, `commands/setup.md`, `hooks/check-version.sh` | Mechanical migration: `gemini_cli`→`agy_cli`, `gemini-agent`→`agy-agent`, `--file`→`--add-dir` (MODERATE rows only) | **Modify** (Task 11) |
| `skills/x-research/{SKILL.md,references/max-mode.md,references/prompt-templates.md}` | **Rework**: pull the agy lane OUT of the parallel fan-out → run it sequentially; `--file`→`--add-dir` | **Modify** (Task 12) |
| `skills/x-qa/{SKILL.md,references/case-runner-prompts.md,scripts/evals/score-case.sh,scripts/evals/calibrate-judge.sh}` | **Rework**: serialize the agy simple-runner within case waves; drop `--raw` (agy is plain-text-only); keep model-authored case-JSON (plain-text passthrough is compatible) | **Modify** (Task 13) |

**Phase D — delete gemini (Task 14):**

| File | Responsibility | Action |
|---|---|---|
| `bin/gemini-agent` | The old wrapper | **Delete** |
| `bin/setup` | Remove `1b` gemini-agent binding, `1c` Gemini CLI detection, `gemini_cli` manifest line + case-arm + symlink vars; switch `report_skill` x-gemini/x-guide to `agy_cli` | **Modify** |
| `hooks/{inject-capabilities.sh,check-version.sh}` | Remove `gemini_cli` projection + the gemini-agent binding/`has("gemini_cli")` freshness checks | **Modify** |
| `skills/x-shared/capability-loading.md` | Remove the `gemini_cli` schema key | **Modify** |

> **Migration invariant:** after each task, `bin/setup` runs clean and no skill routes to a binary/capability that doesn't yet exist. `gemini-agent` is deleted **only** in Task 14, after every call site has moved (Tasks 9–13).

**Convention to follow (Tasks 2–7):** copy `bin/gemini-agent`'s idioms exactly — UTF-8 locale probe (lines 21–32), timeout-binary resolution (81–90), Claude-env stripping via `env -u CLAUDECODE …` (160–164), 0600 log persistence with `! -L` symlink guard + `install -m 0600` (202–227), 50k-char tail truncation (323–328). Do **not** reinvent these; lift them **before** `gemini-agent` is deleted in Task 14.

---

## Task 1: ~~Re-pin stale gemini model aliases~~ — REMOVED (full-replacement rewrite)

**Dropped 2026-06-08.** The dual-track plan opened by fixing the stale `gemini-agent` `flash`/`pro` alias table. Under full replacement, `gemini-agent` and its Models table are **deleted** (Task 9 rewrites `skills/x-gemini/SKILL.md` to agy aliases; Task 14 deletes the binary), so re-pinning a soon-to-be-deleted table is wasted work. No action — kept as a numbered placeholder so Tasks 2–7's internal cross-references ("Task 4", "Task 6") stay valid.

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

# --- Verify agy CLI (skipped under dry-run: dry-run never execs agy, so the
# offline tests T2–T5 must not require agy on PATH — fixes "No network, no real agy") ---
if [[ "${X_AGY_DRY_RUN:-0}" != "1" ]] && ! command -v agy &>/dev/null; then
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
# trusted CWD -> no warning. NB: the wrapper checks BOTH $PWD (logical "/tmp")
# and pwd -P (physical "/private/tmp" on macOS), so seeding the logical path matches.
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
# Check BOTH the logical ($PWD) and physical (pwd -P) CWD. On macOS /tmp is a
# symlink to /private/tmp, so `pwd -P` canonicalizes it — and agy may store
# either form in trustedWorkspaces. Matching either avoids a spurious warning
# (and makes the T5 "trusted is silent" assertion pass on darwin).
CWD_ABS="$(pwd -P)"
if ! is_trusted "$PWD" && ! is_trusted "$CWD_ABS"; then
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

## Task 8: Add `agy_cli` capability end-to-end (setup + manifest + projection + schema)

**Goal:** make `agy_cli` a first-class capability flowing detection → manifest → SessionStart projection → skill gate, and bind the `agy-agent` symlink. **gemini stays wired** here (its removal is Task 14) so `bin/setup` keeps working through the migration. Only x-gemini's readiness gate flips to `agy_cli` now, because Task 9 migrates x-gemini's backend immediately after. **No OR-group arm** — under full replacement there is no dual-track to OR.

**Files:**
- Modify: `bin/setup`
- Modify: `hooks/inject-capabilities.sh`
- Modify: `skills/x-shared/capability-loading.md`

- [ ] **Step 1: Add source/link path vars** — near `bin/setup:16` (after `GEMINI_AGENT_SRC=…`) and `:23` (after `GEMINI_LINK_PATH=…`):

```bash
AGY_AGENT_SRC="$PLUGIN_DIR/bin/agy-agent"
AGY_LINK_PATH="$LINK_DIR/agy-agent"
```

- [ ] **Step 2: Add detection + binding section** — the section-1 headers are already used through `1g` (`1`=omo-agent, `1b`=gemini-agent, `1c`=Gemini CLI, `1d`=worktrunk, `1e`=x-worktree-isolate, `1f`=x-upstream, `1g`=GitNexus, verified `bin/setup:510–624`). Append the agy block **after `1g`** (~`bin/setup:624+`) with the next free sub-number, **`1h`**:

```bash
# --- 1h. Antigravity CLI (agy) — Google-model backend (replaces gemini) ---
header "1h. Antigravity CLI (agy) — Google-model backend"
AGY_PRESENT=0
command -v agy &>/dev/null && AGY_PRESENT=1
if [[ -f "$AGY_AGENT_SRC" ]]; then
  chmod +x "$AGY_AGENT_SRC"; install_symlink "$AGY_AGENT_SRC" "$AGY_LINK_PATH"
fi
if [[ $AGY_PRESENT -eq 1 ]]; then
  ok "agy found: $(agy --version 2>/dev/null || echo unknown)"
else
  info "agy CLI not found — x-gemini and all Google-model routing depend on it"
  missing_add "cli" "agy" "Antigravity CLI (Google-model backend for x-gemini/x-research/x-qa)" "https://antigravity.google/cli"
fi
# Same timeout gate as gemini (TIMEOUT_PRESENT is set in 1c).
if [[ $AGY_PRESENT -eq 1 && ${TIMEOUT_PRESENT:-0} -eq 1 ]]; then
  cap_set agy_cli true
else
  cap_set agy_cli false
fi
```
(Re-check the header list in your tree before inserting — if a `1h` already exists, use the next free letter. The point is simply: do not duplicate an existing `header "1x…"`.)

- [ ] **Step 3: Add to the manifest `python3` block** — the capability manifest is emitted by a `python3` heredoc (`<<PYMANIFEST`, **not** jq). At `bin/setup:914` (after the `"gemini_cli": …` line inside the `"capabilities"` dict):

```bash
        "agy_cli":            cap("$(cap_get agy_cli)"),
```

- [ ] **Step 4: Add the `agy_cli)` case-arm + flip x-gemini's readiness gate**

Add the arm to the `case "$dep"` switch (after the `gemini_cli)` arm at `bin/setup:981`):
```bash
      agy_cli)        [[ "$(cap_get agy_cli)" == "true" ]] && met=true ;;
```
Flip x-gemini's report line at `bin/setup:1011` from `gemini_cli` to `agy_cli` (its backend becomes agy in Task 9):
```bash
report_skill "x-gemini"       agy_cli
```
Leave `report_skill "x-guide" gemini_cli research-mcps` (line 1014) alone for now — Task 11 flips it when x-guide is migrated.

- [ ] **Step 5: Project `agy_cli` into the SessionStart capabilities line** — in `hooks/inject-capabilities.sh` (~line 44, beside the `gemini_cli` projection `(.capabilities.gemini_cli | select(truthy) | "gemini_cli")`):

```bash
        (.capabilities.agy_cli | select(truthy) | "agy_cli"),
```
Copy the **exact** jq idiom from the adjacent `gemini_cli` line and swap the key — do not hand-author a different `select(...)` form.

- [ ] **Step 6: Register `agy_cli` in the capability schema** — in `skills/x-shared/capability-loading.md`, add `agy_cli` to the manifest schema block (beside `"gemini_cli": true,`, ~line 32) and to the capability table:

```markdown
| `agy_cli` | Antigravity CLI (`agy`) present + a `timeout`/`gtimeout` binary | The Google-model backend (`agy-agent`). Required by x-gemini; used by x-research, x-qa, x-bugfix, x-guide, x-mindful. **Replaces `gemini_cli`.** |
```

- [ ] **Step 7: Verify setup runs clean + projection works**

```bash
cd /Users/randytran/Codes/x-skills
bash bin/setup 2>&1 | tail -40
jq '.capabilities.agy_cli' ~/.config/x-skills/capabilities.json    # -> true (agy is installed here)
bash hooks/inject-capabilities.sh 2>/dev/null | grep -o 'agy_cli' || echo "PROJECTION MISSING"
```
Expected: `agy_cli` is `true` in the manifest and appears in the projection output. (Do NOT use `--detect-only` — `bin/setup` has no such flag.)

- [ ] **Step 8: Commit**

```bash
git add bin/setup hooks/inject-capabilities.sh skills/x-shared/capability-loading.md
git commit -m "feat(setup): add agy_cli capability end-to-end (detect, bind, manifest, project, schema)"
```

---

## Task 9: Migrate the x-gemini bridge itself to agy (agy-only)

x-gemini is the bridge skill — it must stop documenting/invoking `gemini-agent` and use `agy-agent` exclusively. The skill **keeps its name** `x-gemini` (it still serves Gemini models — now via agy, plus the Claude/GPT-OSS bonus). (The `agy_cli` schema registration already happened in Task 8 Step 6.)

**Files:**
- Modify: `skills/x-gemini/SKILL.md`
- Modify: `skills/x-gemini/gotchas.md`

- [ ] **Step 1: SKILL.md — swap the backend + rewrite the Models table for agy.** Across the skill body:
  - the wrapper is `agy-agent` (replace every `bin/gemini-agent` / `gemini-agent` reference, incl. the Bootstrap path);
  - the invocation map uses agy flags — `--model`, `--add-dir DIR` (replaces `--file`/`@file`), `--resume`/`-c`, `--system FILE`, `--grounded`;
  - **remove** `--stream`, `--output-format`, `@file`, and the line stating "the wrapper parses Gemini's `--output-format json` and emits only `.response`" — agy is plain-text, there is no JSON surface;
  - replace the Models table with the agy alias map (mirror Task 3's `resolve_model`):

```markdown
| Alias | agy model (display string) | Best For |
|---|---|---|
| `flash` (default) | `Gemini 3.5 Flash (Medium)` | Fast lookups, classification, summaries |
| `flash-low` / `flash-high` | `Gemini 3.5 Flash (Low)` / `(High)` | bulk / harder fast-tier |
| `pro` | `Gemini 3.1 Pro (High)` | Reasoning, deep analysis |
| `pro-low` | `Gemini 3.1 Pro (Low)` | cheaper reasoning |
| `claude-sonnet` / `claude-opus` | `Claude Sonnet 4.6 (Thinking)` / `Claude Opus 4.6 (Thinking)` | cross-provider (agy-only advantage) |
| `gpt-oss` | `GPT-OSS 120B (Medium)` | cross-provider |
```
  Add a one-line note: agy is **plain-text only**, the wrapper **synthesizes a real exit code** (agy exits 0 even on failure), and `--grounded` is **required** for "what's current / latest version" questions.

- [ ] **Step 2: gotchas.md — REPLACE the gemini gotchas with the agy gotchas.** The old `--output-format`/`--stream`/thinking-starvation gotchas no longer apply (delete them). Use the verbatim block from research doc §10:

```markdown
## agy backend (agy-agent)

- **No JSON.** agy print mode is plain text; there is no `--json`/`--output-format`. `agy-agent` emits the text directly.
- **Exit 0 lies.** agy exits 0 even on auth/quota/empty failures. `agy-agent` re-derives a real exit code from empty-stdout + `--log-file` tail; trust the wrapper's exit code, not agy's.
- **trustedWorkspaces.** agy hangs on a trust prompt for untrusted dirs in non-TTY. `agy-agent` preflights and warns; set `X_AGY_AUTO_TRUST=1` to auto-append CWD.
- **Grounding is prompt-driven** (no flag) AND load-bearing for currency. Without `--grounded`, agy trusts the repo over live docs and will return stale identifiers (verified: it returned a *legacy* OpenAI event the repo still contained instead of the current GA one). Pass `--grounded` for any "what's current / latest version" question.
- **Never `--add-dir` a large tree.** Pointing it at a repo root (e.g. a 65 GB monorepo with node_modules/build/vendored checkouts) makes agy's agentic traversal hang for 15–25 min with zero output. Scope to the relevant subtree(s) — a 572 KB scope returned in 79 s. `agy-agent` warns when a target looks large.
- **Serialize agy calls.** agy spawns a local gRPC language-server per invocation; concurrent calls contend and hang. Consumers that fan out (x-research, x-qa) MUST run agy lanes sequentially, not in parallel.
- **Auth noise in the log is NOT an auth failure.** Every run's log contains `not logged into Antigravity` / `failed to set auth token` (auxiliary caches), even on success. Don't classify on it; trust `agy-agent`'s status, which strips this noise.
- **Latency** ~2× a single scoped grounded run (≈79 s) — NOT 3–5×. The 3–5× only appears under the two pathologies above (huge `--add-dir`, concurrency). Route bulk work to `--model flash-low`.
```

- [ ] **Step 3: Commit**

```bash
git add skills/x-gemini/SKILL.md skills/x-gemini/gotchas.md
git commit -m "refactor(x-gemini): migrate bridge to agy-agent backend (agy-only)"
```

---

## Task 10: agy backend validation (smoke the migrated backend; no code)

**No cutover** — this is a straight replacement, not a dated flip. This task just confirms agy serves the consumer signal classes before the mechanical migration fans out.

**Files:**
- Modify: `docs/research/2026-06-06-agy-antigravity-cli-headless-usage-guide.md` (append a "Validation results" section)

- [ ] **Step 1: Run each consumer signal class through agy once** and record latency/quality:

```bash
# library-current-state lookup (x-research / x-guide signal): grounded flash
agy-agent --model flash-low --grounded "Is the 'zod' npm package still actively maintained? Latest version + last release date, cite URLs."
# multi-file review (x-review / x-bugfix signal): pro on a small dir
agy-agent --model pro --add-dir skills/x-gemini "List the top 3 risks in this wrapper as FILE:LINE — list only."
# pass/fail judge (x-qa eval signal): plain text JSON, no --raw flag exists
agy-agent --model flash "Reply with ONLY this JSON: {\"score\": 0.9}"
```

- [ ] **Step 2: Append a "Validation results (YYYY-MM-DD)" table** to the research doc: prompt class, latency, usable?, failure-detection hits, whether grounding cited real URLs, whether chrome appeared, whether the judge emitted parseable bare JSON.

- [ ] **Step 3: Replace any "cutover plan" wording with the replacement note** (there is no fallback):

```markdown
### Replacement status
- `agy` is the SOLE Google-model backend. `gemini-agent` + `gemini_cli` are removed (Task 14).
- Re-pin model aliases if `agy models` changes the display strings (re-run `agy models`; update Task 3's `resolve_model` + the x-gemini table).
```

- [ ] **Step 4: Commit**

```bash
git add docs/research/2026-06-06-agy-antigravity-cli-headless-usage-guide.md
git commit -m "docs(research): agy backend validation results (replacement, no cutover)"
```

---

## Task 11: Migrate the mechanical consumers (`gemini_cli`→`agy_cli`, `gemini-agent`→`agy-agent`, `--file`→`--add-dir`)

Every consumer EXCEPT the two parallel-fan-out hot spots (x-research → Task 12, x-qa → Task 13) and x-gemini (done in Task 9). These are mechanical: rename the capability gate, rename the binary, and remap `--file <path>`→`--add-dir <dir>` where present. **No concurrency changes** — none of these fan out agy.

**Files & transforms** (line refs from the 2026-06-08 inventory; verify before editing):

- [ ] **Step 1: Capability-gate renames** `gemini_cli` → `agy_cli`:
  - `skills/x-review/SKILL.md` (gate mentions ~71, 106) and `skills/x-review/steps/step-02-review.md` (~5 gate refs)
  - `skills/x-do/steps/step-03-review.md` (~35)
  - `skills/x-guide/steps/step-02-ingest.md` (~33), `skills/x-guide/references/routing-matrix.md` (~7, 36), `skills/x-guide/gotchas.md` (~24–27)
  - `skills/x-mindful/steps/step-01-detect.md` (~39)
  - `skills/x-worktree-isolate/SKILL.md` (~23, prose — "gemini_cli is irrelevant" → "agy_cli is irrelevant")
  - `skills/x-research/gotchas.md` (~1, gate ref only; the SKILL routing is Task 12)
  - Also flip x-guide's readiness gate in `bin/setup:1014`: `report_skill "x-guide" gemini_cli research-mcps` → `report_skill "x-guide" agy_cli research-mcps`.

- [ ] **Step 2: Binary renames** `gemini-agent` → `agy-agent` (+ `--file`→`--add-dir` on rows that carry it):
  - `skills/x-review/steps/step-02-review.md` (~15, 32, 56, 66, 95) — `gemini-agent --model pro` → `agy-agent --model pro`. **Safe to keep `run_in_background: true`**: x-review issues exactly ONE agy call per review (no agy-on-agy concurrency). Update the "gemini perspective / Google-Search-grounding" wording to agy + `--grounded`.
  - `skills/x-bugfix/SKILL.md` (~16, 83–85, 147–150) — `gemini-agent --file <log>` / `--file <screenshot>` → `agy-agent --add-dir <dir>` (point at the containing dir, not the file); `--model pro` stays.
  - `skills/x-shared/invocation-guide.md` (~31–54) — canonical invocation examples: `gemini-agent`→`agy-agent`, `--file`→`--add-dir`, drop `--resume` JSON notes if any.
  - `skills/x-shared/omo-routing.md` (~56), `skills/x-shared/mcp-toolbox.md` (~10, 12, 26), `skills/x-shared/common-gotchas.md` (~11) — table/prose renames.
  - `skills/x-qa/references/scout-prompt.md` (~9–11, 94) — scout is **serial** (explicitly "NOT run_in_background"), so a plain rename is safe; `--file`→`--add-dir` if present.
  - `skills/x-qa/references/init-interview.md` (~119), `skills/x-research/references/synthesis-rules.md` (~89) — prose mentions.
  - `README.md` (~15, 24, 26, 47, 81, 155), `commands/setup.md` (~11) — binding/skill-description prose: `gemini-agent`→`agy-agent`.
  - `hooks/check-version.sh` — Case 3 (`bin/gemini-agent` binding freshness, ~61–66) → `bin/agy-agent`; Case 4 (`has("gemini_cli")`, ~69–75) → `has("agy_cli")` + update the pre-version message. (The `gemini_cli` removal itself lands in Task 14; here you point the freshness checks at the new names.)

- [ ] **Step 3: Verify no behavioral gate is left dangling** — every migrated file should now reference `agy_cli`/`agy-agent`, and `bin/setup` still runs clean:

```bash
cd /Users/randytran/Codes/x-skills
# These files must have NO remaining gemini refs (x-research/x-qa excluded — Tasks 12/13):
grep -rEl 'gemini-agent|gemini_cli' skills/x-review skills/x-bugfix skills/x-do skills/x-guide \
  skills/x-mindful skills/x-worktree-isolate skills/x-shared README.md commands/setup.md hooks/check-version.sh \
  | grep -v 'docs/' && echo "STILL HAS GEMINI REFS (above)" || echo "clean"
bash bin/setup 2>&1 | tail -5   # x-guide should now report on agy_cli
```
Expected: `clean`, and setup exits without error.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor: migrate mechanical consumers to agy-agent/agy_cli backend"
```

---

## Task 12: Rework x-research for agy (serialize the agy lane)

**The constraint:** concurrent **agy** processes hang — but a single agy lane running alongside non-agy lanes (oracle, perplexity, MCP) is fine. So the rule is **≤1 agy lane in flight at any moment**, not "no parallelism."

**Files:**
- Modify: `skills/x-research/SKILL.md`, `skills/x-research/references/max-mode.md`, `skills/x-research/references/prompt-templates.md`

- [ ] **Step 1: Standard Mode default fan-out** (`SKILL.md:75–79`) — `gemini-agent`→`agy-agent`, `--file`→`--add-dir`, `gemini_cli`→`agy_cli` in the gate (`:17`). This lane is a **single** background agy call in parallel with the primary (non-agy) — keep it; it's safe (one agy process). Update routing-table rows (`:57–65`) to `agy-agent --add-dir` / `agy-agent --grounded`.

- [ ] **Step 2: Max Mode — cap agy lanes to ONE concurrent** (`max-mode.md:26–43`). The Fan-Out Matrix lists `agy-agent` as a lane in several question classes. Add an explicit rule: **at most one agy lane may be in flight; if a question class would dispatch more than one agy variant, run them sequentially (or collapse to a single agy lane).** All non-agy lanes still fan out in parallel. Update the cap note (`:43`) to call this out. Rename `gemini-agent`→`agy-agent`, `--file`→`--add-dir`.

- [ ] **Step 3: prompt-templates.md** (`:84`) — "Max Mode adds perplexity_research + agy-agent" rename; note the single-agy-lane rule.

- [ ] **Step 4: Add a cross-skill caution** to `skills/x-research/gotchas.md`: two overlapping agy-using runs (e.g. x-research Max Mode while x-qa runs) contend — agy is a process-global singleton. Operators should not run two agy-heavy skills concurrently.

- [ ] **Step 5: Verify** — grep the three files for any remaining `gemini-agent`/`gemini_cli`/`--file` (none should remain), and confirm the matrix/docs state the ≤1-agy-lane rule.

- [ ] **Step 6: Commit**

```bash
git add skills/x-research
git commit -m "refactor(x-research): migrate to agy; cap agy lanes to one concurrent (serialize)"
```

---

## Task 13: Rework x-qa for agy (serialize case waves + drop `--raw`)

**Two changes agy forces:** (a) the simple-runner case waves dispatch **multiple** `gemini-agent` calls in parallel (capped at `--max-bg`) → multiple concurrent agy calls → **hang**; the agy runner must run cases **sequentially**. (b) the eval scripts call `gemini-agent --model flash --raw` and parse `.score`; agy has **no `--raw`** (it's plain-text natively) → drop the flag. The judge prompt already returns bare `{"score":…}`, so plain-text passthrough is parse-compatible.

**Files:**
- Modify: `skills/x-qa/SKILL.md`, `skills/x-qa/references/case-runner-prompts.md`, `skills/x-qa/scripts/evals/score-case.sh`, `skills/x-qa/scripts/evals/calibrate-judge.sh`

- [ ] **Step 1: Serialize the agy simple-runner waves** (`SKILL.md:175`, `case-runner-prompts.md:7–13`). When the simple runner is `agy-agent` (was `gemini-agent --model flash`), the wave must dispatch cases **one at a time** (effective `--max-bg 1` for the agy runner) — concurrent agy calls hang. Document that the parallel-wave optimization is **disabled for the agy runner** (it stays available for the non-agy fallback runners: OMC executor / Explore). Rename `gemini-agent`→`agy-agent`; gate `gemini_cli`→`agy_cli` (`:21, 64–65, 219–220`).

- [ ] **Step 2: Drop `--raw` in the eval scripts.** In `score-case.sh` (default `X_QA_JUDGE_CMD`, ~line 81) and `calibrate-judge.sh` (~line 21), change `gemini-agent --model flash --raw "$(cat)"` → `agy-agent --model flash "$(cat)"`. The `.score` jq parse (`score-case.sh:92`, `calibrate-judge.sh:31`) is unchanged — agy emits the bare JSON the judge prompt asks for as plain text. Update the recorded `X_QA_JUDGE_MODEL` default label (`score-case.sh:26`) from `gemini-flash` to `agy-flash`.

- [ ] **Step 3: Keep the model-authored case JSON.** The simple-runner prompt (`case-runner-prompts.md:19–63`) tells the model to emit a JSON result doc; the aggregator jq-parses it (`:88–90`). agy plain-text passthrough preserves this verbatim — no prompt change needed beyond ensuring it still says "output ONLY the JSON" (also suppresses agy's `### Work Summary` chrome).

- [ ] **Step 4: Verify** — run the eval scripts against a tiny fixture to confirm `.score` still parses from agy plain-text output:

```bash
cd /Users/randytran/Codes/x-skills/skills/x-qa
echo '{"expected":"pong"}' | X_QA_JUDGE_CMD='agy-agent --model flash' bash scripts/evals/score-case.sh --selftest 2>&1 | tail -5 || true
grep -rEl 'gemini-agent|gemini_cli|--raw' . | grep -v docs/ && echo "STILL HAS GEMINI/RAW REFS" || echo "clean"
```
Expected: `clean`; the judge path returns a numeric score.

- [ ] **Step 5: Commit**

```bash
git add skills/x-qa
git commit -m "refactor(x-qa): migrate to agy; serialize case waves; drop --raw (plain-text judge)"
```

---

## Task 14: Delete `gemini-agent` + remove `gemini_cli` (final phase)

Only after Tasks 9–13 have moved every call site. This removes the dead backend and the dead capability, then gates on "no active gemini refs remain."

**Files:**
- Delete: `bin/gemini-agent`
- Modify: `bin/setup`, `hooks/inject-capabilities.sh`, `hooks/check-version.sh`, `skills/x-shared/capability-loading.md`

- [ ] **Step 1: Pre-flight — assert no consumer still routes to gemini.** Abort the deletion if anything outside `docs/` and this plan still references the binary or capability:

```bash
cd /Users/randytran/Codes/x-skills
grep -rEn 'gemini-agent|gemini_cli' --include='*.md' --include='*.sh' . \
  | grep -vE '^(docs/|\./docs/)' | grep -v 'superpowers/plans/' \
  && { echo "ABORT: live gemini refs remain — finish Tasks 9–13 first"; } || echo "safe to delete"
```
Expected: `safe to delete`. (If anything prints, migrate it before continuing.)

- [ ] **Step 2: Delete the binary + setup wiring.**
  - `git rm bin/gemini-agent`
  - In `bin/setup`: remove `GEMINI_AGENT_SRC` (`:16`) and `GEMINI_LINK_PATH` (`:23`); the `bin/gemini-agent` not-symlink check (`~:220`); the `1b. gemini-agent binding` block (`~:531–540`); the `1c. Gemini CLI` detection block (`~:542–579`); the `"gemini_cli": …` manifest line (`:914`); and the `gemini_cli)` case-arm (`:981`). (x-gemini/x-guide report lines were already flipped to `agy_cli` in Tasks 8/11.)

- [ ] **Step 3: Remove the capability from hooks + schema.**
  - `hooks/inject-capabilities.sh`: remove the `gemini_cli` projection line (`~:44`).
  - `hooks/check-version.sh`: remove the now-dead `has("gemini_cli")` pre-version branch if it's fully superseded by the `agy_cli` checks from Task 11 (or leave a one-time migration note — implementer's call).
  - `skills/x-shared/capability-loading.md`: remove the `"gemini_cli": true,` schema key (`~:32`).

- [ ] **Step 4: Final gate — clean setup, clean grep, agy still works.**

```bash
cd /Users/randytran/Codes/x-skills
bash bin/setup 2>&1 | tail -20                         # no errors, no gemini_cli
jq '.capabilities | has("gemini_cli")' ~/.config/x-skills/capabilities.json   # -> false
jq '.capabilities.agy_cli' ~/.config/x-skills/capabilities.json               # -> true
# zero live refs (docs/plan history is allowed to keep them):
grep -rEn 'gemini-agent|gemini_cli' --include='*.md' --include='*.sh' . \
  | grep -vE 'docs/|superpowers/plans/' && echo "LEFTOVER REFS" || echo "fully removed"
bash bin/tests/agy-agent.test.sh                       # wrapper still green
```
Expected: setup clean, `has("gemini_cli")` is `false`, `agy_cli` is `true`, grep prints `fully removed`, wrapper tests pass.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat!: remove gemini-agent + gemini_cli — agy is the sole Google-model backend"
```

---

## Self-Review (completed by plan author)

**Spec coverage** (against research doc §11 wrapper table): model-alias map ✓ (T3), `--file`→`--add-dir` ✓ (T4), `--system` emulation ✓ (T4), `--resume`→`-c`/`--conversation` ✓ (T4), grounding injection ✓ (T4), empty-stdout+log-tail failure detection ✓ (T6), chrome strip ✓ (T6), `trustedWorkspaces` preflight ✓ (T5). **Replacement coverage:** `agy_cli` end-to-end — detect/manifest/projection/schema ✓ (T8), x-gemini bridge migrated ✓ (T9), agy validation ✓ (T10), mechanical consumers ✓ (T11), x-research serialized ✓ (T12), x-qa serialized + `--raw` dropped ✓ (T13), gemini deleted behind a grep gate ✓ (T14). T1 removed (no point re-pinning a soon-deleted table). **Dropped by design (no JSON):** stats/session-id/thinking-starvation — out of scope, documented in T9.

**Known open item (flagged, not a placeholder):** capturing a conversation **id** from a headless `-p` run is unverified (research doc §7). `--resume` (latest, via `-c`) works; explicit `--conversation <id>` is wired but id-capture is a follow-up probe — not blocking, because `-c` covers the multi-turn case. T10 can add an id-capture probe if a consumer needs it.

**Type/flag consistency:** env knobs are uniform `X_AGY_*` (`X_AGY_DRY_RUN`, `X_AGY_NO_LOG`, `X_AGY_DEFAULT_MODEL`, `X_AGY_AUTO_TRUST`, `X_AGY_STRIP_SUMMARY`, `X_AGY_ADDDIR_MAX`, `AGY_TIMEOUT`); model aliases identical across T3 map and T9 docs; `resolve_model()` named consistently; fake-agy modes (`ok/empty/chrome/authlog/noiselog`) match the T6 assertions.

**Eval-harness amendments (2026-06-06):** the four findings from the merged research doc Part 2 (§12–15) are integrated — classifier auth-noise bug fixed + regression-tested (T6 `noiselog`), large-`--add-dir` guard (T4), serialization + currency + latency gotchas (T9). See the "Findings & Amendments" section near the top.

**x-review amendments (2026-06-08):** defects caught in cross-model plan review are fixed inline — (1) **Task 5** trust preflight checks BOTH `$PWD` and `pwd -P`, so the macOS `/tmp`→`/private/tmp` symlink no longer fails the "trusted is silent" assertion; (2) **Task 2** skips the `agy`-presence check under `X_AGY_DRY_RUN=1`, so offline tests T2–T5 no longer require `agy` on PATH; (3) the Task 8 manifest block is correctly labeled `python3` (not jq), and the Tech-Stack `jq` note is corrected (jq is used in agy-agent's Task 5 preflight; the setup manifest is python3). The earlier dual-track `report_skill` OR-arm (`gemini_backend)`) is **obsolete** under full replacement — Task 8 now simply adds the `agy_cli)` arm and points x-gemini at `agy_cli` (no OR needed).

**Full-replacement rewrite (2026-06-08):** converted from dual-track to a full `gemini-agent`→`agy-agent` replacement (user decision: delete gemini, agy is the sole backend). Wrapper Tasks 2–7 are unchanged; the tail (T8–T14) adds `agy_cli` end-to-end, migrates all ~19 consumer files, reworks x-research and x-qa for agy's serialize-only + plain-text constraints, and deletes `gemini-agent` last behind a grep gate. Blast radius (78 `gemini-agent` + 31 `gemini_cli` refs across 19 files) inventoried 2026-06-08. **Two HARD consumers** carry real risk and have dedicated tasks: x-research parallel fan-out (T12 — cap to ≤1 agy lane) and x-qa parallel case waves + `--raw` JSON eval (T13 — serialize waves, drop `--raw`).

**Placeholder scan:** Tasks 2–10 and 14 are fully copy-pasteable. Tasks 11–13 (bulk migration of ~19 files) give precise file:line targets + the exact transform per file rather than a full diff for each — appropriate for a rename/remap sweep; the implementer applies edits guided by the 2026-06-08 inventory and verifies via each task's grep gate. No hidden TODOs.
