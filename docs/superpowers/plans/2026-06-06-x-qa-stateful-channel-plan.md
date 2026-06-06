# x-qa: Stateless-First, Stateful-Aware Channel Selection — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make x-qa default to stateless channels per worktree and become stateful-aware — executing only an HTTP stateful channel this worktree owns, skipping all other stateful channels with precise reasons — by linking each channel to an x-worktree-isolate singleton via an additive `singleton_id` field.

**Architecture:** Statefulness is *derived* from a single new optional field `channels[].singleton_id` (string|null; null = stateless), which links to `x-worktree-isolate singletons[].id`. Ownership is read **only** from the worktree-local `<worktree>/.worktree-isolate/feature-overrides.local.json` (`state == "enabled"` ⇒ owned), never the global registry. The decision table is factored into a new testable resolver (`scripts/lib/channel-select.sh`) that emits `<run-dir>/channels.json`; `aggregate-results.sh` reads that artifact to emit `CHANNELS_TESTED` / `CHANNELS_SKIPPED`, mirroring the existing `scope.json` / `kb-counters.env` consumption pattern. Doc/prose changes are guarded by grep-anchored assertions in `scripts/tests/channel-contract.sh`.

**Tech Stack:** bash, python3/jq, existing scripts/tests harness; reads x-worktree-isolate worktree-local state

---

## Dependency note on the x-worktree-isolate plan

This plan is the **x-qa half** of `docs/superpowers/plans/2026-06-06-stateful-stateless-channel-isolation.md`. It assumes the x-worktree-isolate lock plan is **already done** — specifically that `enable <id>` writes `{"id":..,"state":"enabled"}` into `<worktree>/.worktree-isolate/feature-overrides.local.json` (already true today per `skills/x-worktree-isolate/SKILL.md:147-162`) and that "enabled here ⇒ won the claim" is enforced at claim time (the isolate-side enforcement; x-qa only *reads* the result). **x-qa never reads the global registry (R2)** — every step here reads only the two worktree-local files. No step in this plan blocks on isolate code beyond the file shapes already documented at `skills/x-worktree-isolate/SKILL.md:128-162`, so all tasks are runnable now.

## Test harness conventions (match exactly — do not invent a framework)

Verified from `skills/x-qa/scripts/tests/{channels,channel-contract,classify,qa-memory}.sh`:

- Each test is a standalone `#!/usr/bin/env bash` + `set -euo pipefail` file in `skills/x-qa/scripts/tests/`.
- `SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"`.
- Use `WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT; cd "$WORK"; git init -q` for repo-rooted scripts.
- Counters: `pass=0; fail=0`; print `FAIL: <desc>` on mismatch; final line `echo "<name>: $pass passed, $fail failed"`; last line `[[ $fail -eq 0 ]]`.
- **There is no master runner** (`.github/workflows/` is empty; no `run-tests`). Run each test directly: `bash skills/x-qa/scripts/tests/<name>.sh` — expected terminal line `<name>: N passed, 0 failed` and exit 0.
- lib scripts (`scripts/lib/*.sh`) follow the subprocess convention seen in `verdict.sh` / `topo-order.sh`: read args/stdin → emit JSON/tokens to stdout, never sourced.

---

## File Structure

| File | Create/Modify | Responsibility |
|---|---|---|
| `skills/x-qa/references/profile-schema.md` | Modify | Document `channels[].singleton_id` (string\|null), the version-bump rule (schema stays 1), and the new C8 doctor checks. |
| `skills/x-qa/templates/profile.example.json` | Modify | Add a stateful HTTP channel example carrying `singleton_id`; bump example `version`. |
| `skills/x-qa/scripts/lib/channel-ownership.sh` | Create | Given `--singleton-id <id> --worktree <root>`, emit `owned`\|`not-owned`\|`unverifiable` by reading ONLY `feature-overrides.local.json`. |
| `skills/x-qa/scripts/lib/channel-select.sh` | Create | Given profile + worktree + optional `--channel`, emit `channels.json` `{tested:[...], skipped:[{name,reason}]}` applying the full decision table. |
| `skills/x-qa/scripts/aggregate-results.sh` | Modify | Read `<run-dir>/channels.json` (when present) and emit `CHANNELS_TESTED=` / `CHANNELS_SKIPPED=`. |
| `skills/x-qa/scripts/doctor.sh` | Modify | C8: validate `singleton_id` resolves against isolate `singletons[].id` when an isolate profile is present (warning on dangling); info-nudge when channels present but none carry `singleton_id`. |
| `skills/x-qa/references/doctor-checks.md` | Modify | Document C8 dangling-ref warning + the `singleton_id` info-nudge. |
| `skills/x-qa/references/channel-drivers.md` | Modify | Document the three stateful skip reasons + the owned-http EXECUTE carve-out. |
| `skills/x-qa/references/init-interview.md` | Modify | Add the stateful-channel → `singletons[].id` mapping step for `init`/`update`. |
| `skills/x-qa/SKILL.md` | Modify | Phase 4 stateless-first/stateful-aware bullet; Run Envelope `CHANNELS_TESTED`/`CHANNELS_SKIPPED`; skip-reason references. |
| `skills/x-qa/scripts/tests/channel-ownership.sh` | Create | Unit-test the four ownership outcomes (owned / not-owned / acknowledged-not-owned / unverifiable). |
| `skills/x-qa/scripts/tests/channel-select.sh` | Create | Unit-test the full decision table (stateless default, owned+http, owned+chat, not-owned, unverifiable, back-compat). |
| `skills/x-qa/scripts/tests/channels.sh` | Modify | Add C8 doctor cases: dangling `singleton_id` warning, valid `singleton_id`, info-nudge when none set. |
| `skills/x-qa/scripts/tests/aggregate-channels.sh` | Create | Unit-test `aggregate-results.sh` emits `CHANNELS_TESTED`/`CHANNELS_SKIPPED` from `channels.json` (and empty when absent). |
| `skills/x-qa/scripts/tests/channel-contract.sh` | Modify | Grep-anchor every prose contract string (skip reasons, envelope keys, `singleton_id`, decision-table verbs). |

---

## Tasks

### Task 1: Channel schema — document `singleton_id` + stateful example profile

**Files:**
- Modify: `skills/x-qa/references/profile-schema.md` (Channels table ~lines 87-101; Channel Validation Rules ~lines 102-110)
- Modify: `skills/x-qa/templates/profile.example.json` (channels array lines 72-99; `version` line 7)
- Test: `skills/x-qa/scripts/tests/channels.sh` (existing — reused to prove the example still validates) and `skills/x-qa/scripts/tests/channel-contract.sh` (prose grep, extended in Task 9)

This task is doc + example + version-bump only; it must keep the existing `channels.sh` test green (the example is validated indirectly via doctor in Task 6's test; here we only assert the example file still parses + carries the new field).

- [ ] **Step 1: Write a failing assertion that the example profile carries a stateful `singleton_id`.** Add to the END of `skills/x-qa/scripts/tests/channels.sh`, just before the final `echo "channels: ..."` line:
  ```bash
  # Example profile must carry a stateful channel with a non-null singleton_id
  EX="$SKILL_DIR/templates/profile.example.json"
  if [[ "$(jq -r '[.channels[]? | select(.singleton_id != null)] | length' "$EX")" -ge 1 ]]; then
    pass=$((pass+1))
  else
    fail=$((fail+1)); echo "FAIL: profile.example.json has no channel with a non-null singleton_id"
  fi
  # Stateless channels must explicitly carry singleton_id:null (derived statefulness)
  if jq -e '[.channels[]? | select(has("singleton_id") | not)] | length == 0' "$EX" >/dev/null; then
    pass=$((pass+1))
  else
    fail=$((fail+1)); echo "FAIL: profile.example.json has a channel missing the singleton_id key"
  fi
  ```
- [ ] **Step 2: Run it — expect FAIL.** `bash skills/x-qa/scripts/tests/channels.sh` → expect `FAIL: profile.example.json has no channel with a non-null singleton_id` and final `channels: N passed, ≥1 failed`, exit 1 (today's example has no `singleton_id` keys).
- [ ] **Step 3: Add the `singleton_id` row to the Channels table in `profile-schema.md`.** Insert into the table at `references/profile-schema.md` (after the `name` row, ~line 89):
  ```markdown
  | `singleton_id` | string \| null | no | Links this channel to `x-worktree-isolate singletons[].id`. **`null` = stateless** (default QA target, port-isolated). **Set = stateful** — selection skips it unless this worktree owns the singleton (see `references/channel-drivers.md`). Optional and additive: schema stays `1`; absence = stateless = today's behavior. The enabling env var is NOT copied here — it is looked up via the singleton. |
  ```
  Then add validation rule C8 after C7 (~line 110):
  ```markdown
  - C8 (warning) `singleton_id`, when set AND an isolate profile (`<repo_root>/.worktree-isolate/profile.json`) is present, must resolve to a `singletons[].id`. Dangling refs warn, never hard-fail (isolate is optional). When `channels[]` is present but no channel carries a non-null `singleton_id`, doctor emits an info-level nudge to run `x-qa update`.
  ```
- [ ] **Step 4: Document the version-bump rule in the Schema Migration section.** In `references/profile-schema.md § Schema Migration` (~line 126), append:
  ```markdown
  `singleton_id` (added 2026-06) is an **additive optional field**: `schema` stays `1`; bump profile `version` only. Existing profiles without `singleton_id` keep working untouched (absence = stateless). `x-qa update` populates the field by cross-referencing the isolate profile.
  ```
- [ ] **Step 5: Add a stateful HTTP channel + make every channel carry `singleton_id` in the example.** Edit `templates/profile.example.json`. Bump `"version": "1.2.0"` → `"1.3.0"` (line 7). Add `"singleton_id": null` to the existing `admin-api` and `dashboard` channels, set `"singleton_id": "telegram-bot"` on the existing `telegram-bot` channel, and add a NEW stateful HTTP channel `webhook-receiver` after `admin-api`:
  ```json
      {
        "name": "webhook-receiver",
        "driver": "http",
        "audience": "system",
        "entry_point": "api",
        "singleton_id": "github-webhook",
        "base_url_template": "http://localhost:${ISOLATE_PORT_API}/webhooks",
        "base_url_fallback": "http://localhost:3000/webhooks",
        "auth": {
          "kind": "api-key",
          "token_source": "env:WEBHOOK_SECRET"
        }
      },
  ```
- [ ] **Step 6: Run the test — expect PASS.** `bash skills/x-qa/scripts/tests/channels.sh` → expect `channels: N passed, 0 failed`, exit 0. (The existing template-mode doctor cases still pass because `singleton_id` is not yet validated by doctor — C8 lands in Task 6.)
- [ ] **Step 7: Commit.** `git add skills/x-qa/references/profile-schema.md skills/x-qa/templates/profile.example.json skills/x-qa/scripts/tests/channels.sh && git commit -m "feat(x-qa): add channels[].singleton_id schema + stateful example"`

---

### Task 2: Ownership read helper (`channel-ownership.sh`)

**Files:**
- Create: `skills/x-qa/scripts/lib/channel-ownership.sh`
- Test: `skills/x-qa/scripts/tests/channel-ownership.sh`

Reads ONLY `<worktree>/.worktree-isolate/feature-overrides.local.json` (R2 — never the global registry). Four-way outcome: `enabled` ⇒ `owned`; `disabled`/`acknowledged`/absent-entry (isolate dir present) ⇒ `not-owned`; `.worktree-isolate/` absent ⇒ `unverifiable`. Note `acknowledged` is explicitly **not** owned.

- [ ] **Step 1: Write the failing test.** Create `skills/x-qa/scripts/tests/channel-ownership.sh`:
  ```bash
  #!/usr/bin/env bash
  # channel-ownership.sh — unit-test the ownership read helper (R2: reads only
  # feature-overrides.local.json, never the global registry).
  set -euo pipefail
  SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
  OWN="$SKILL_DIR/scripts/lib/channel-ownership.sh"
  pass=0; fail=0
  expect() { # <desc> <expected-stdout> <worktree-root> <singleton-id>
    local desc="$1" want="$2" wt="$3" id="$4" got
    got=$("$OWN" --singleton-id "$id" --worktree "$wt" 2>/dev/null || true)
    if [[ "$got" == "$want" ]]; then pass=$((pass+1)); else
      fail=$((fail+1)); echo "FAIL: $desc (want '$want', got '$got')"; fi
  }

  # 1. isolate absent → unverifiable
  W1=$(mktemp -d)
  expect "no .worktree-isolate dir → unverifiable" "unverifiable" "$W1" "slack-listener"

  # 2. isolate present, singleton enabled → owned
  W2=$(mktemp -d); mkdir -p "$W2/.worktree-isolate"
  cat > "$W2/.worktree-isolate/feature-overrides.local.json" <<'JSON'
  {"schema":1,"overrides":[{"id":"slack-listener","state":"enabled"}],"updated_at":"2026-06-06T00:00:00Z"}
  JSON
  expect "enabled → owned" "owned" "$W2" "slack-listener"

  # 3. isolate present, singleton disabled → not-owned
  W3=$(mktemp -d); mkdir -p "$W3/.worktree-isolate"
  cat > "$W3/.worktree-isolate/feature-overrides.local.json" <<'JSON'
  {"schema":1,"overrides":[{"id":"slack-listener","state":"disabled"}],"updated_at":"2026-06-06T00:00:00Z"}
  JSON
  expect "disabled → not-owned" "not-owned" "$W3" "slack-listener"

  # 4. isolate present, host singleton acknowledged → not-owned (ack ≠ owned)
  W4=$(mktemp -d); mkdir -p "$W4/.worktree-isolate"
  cat > "$W4/.worktree-isolate/feature-overrides.local.json" <<'JSON'
  {"schema":1,"overrides":[{"id":"host-crontab","state":"acknowledged"}],"updated_at":"2026-06-06T00:00:00Z"}
  JSON
  expect "acknowledged → not-owned" "not-owned" "$W4" "host-crontab"

  # 5. isolate present but no entry for this id → not-owned (absent = default disabled)
  expect "absent entry → not-owned" "not-owned" "$W2" "telegram-bot"

  # 6. isolate dir present but overrides file missing → not-owned (set up, nothing enabled)
  W6=$(mktemp -d); mkdir -p "$W6/.worktree-isolate"
  expect "dir present, no overrides file → not-owned" "not-owned" "$W6" "slack-listener"

  rm -rf "$W1" "$W2" "$W3" "$W4" "$W6"
  echo "channel-ownership: $pass passed, $fail failed"
  [[ $fail -eq 0 ]]
  ```
- [ ] **Step 2: Run it — expect FAIL.** `bash skills/x-qa/scripts/tests/channel-ownership.sh` → expect failure (the script does not exist yet: `FAIL: ... (want '...', got '')` for every case, exit 1).
- [ ] **Step 3: Implement `scripts/lib/channel-ownership.sh`.**
  ```bash
  #!/usr/bin/env bash
  # channel-ownership.sh — resolve ownership of a stateful channel's singleton in
  # THIS worktree. Reads ONLY <worktree>/.worktree-isolate/feature-overrides.local.json
  # (R2: never the global singleton_owners registry). Prints one token to stdout:
  #   owned        — singleton state == "enabled" here (won the claim ⇒ owned, per the spec)
  #   not-owned    — isolate set up but singleton not enabled (disabled / acknowledged / absent)
  #   unverifiable — .worktree-isolate/ absent (isolate not set up; never test stateful blind)
  # Usage: channel-ownership.sh --singleton-id <id> --worktree <root>
  set -euo pipefail

  SINGLETON_ID=""
  WORKTREE=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --singleton-id) SINGLETON_ID="$2"; shift 2 ;;
      --worktree) WORKTREE="$2"; shift 2 ;;
      *) echo "Unknown arg: $1" >&2; exit 2 ;;
    esac
  done
  [[ -n "$SINGLETON_ID" ]] || { echo "REASON=missing --singleton-id" >&2; exit 2; }
  [[ -n "$WORKTREE" ]] || { echo "REASON=missing --worktree" >&2; exit 2; }

  isolate_dir="$WORKTREE/.worktree-isolate"
  overrides="$isolate_dir/feature-overrides.local.json"

  # isolate not set up at all → unverifiable (conservative — never test stateful blind)
  if [[ ! -d "$isolate_dir" ]]; then
    echo "unverifiable"
    exit 0
  fi

  # isolate present but overrides file absent → nothing enabled → not-owned
  if [[ ! -f "$overrides" ]]; then
    echo "not-owned"
    exit 0
  fi

  state=$(jq -r --arg id "$SINGLETON_ID" \
    '.overrides[]? | select(.id == $id) | .state' "$overrides" 2>/dev/null | head -n1)

  if [[ "$state" == "enabled" ]]; then
    echo "owned"
  else
    # disabled / acknowledged / absent entry → not owned here
    echo "not-owned"
  fi
  ```
- [ ] **Step 4: `chmod +x` and run — expect PASS.** `chmod +x skills/x-qa/scripts/lib/channel-ownership.sh && bash skills/x-qa/scripts/tests/channel-ownership.sh` → expect `channel-ownership: 6 passed, 0 failed`, exit 0.
- [ ] **Step 5: Commit.** `git add skills/x-qa/scripts/lib/channel-ownership.sh skills/x-qa/scripts/tests/channel-ownership.sh && git commit -m "feat(x-qa): channel-ownership helper reads only feature-overrides.local.json (R2)"`

---

### Task 3 + 4: Channel selection resolver (`channel-select.sh`) — stateless-first + stateful resolution

**Files:**
- Create: `skills/x-qa/scripts/lib/channel-select.sh`
- Test: `skills/x-qa/scripts/tests/channel-select.sh`

This is the decision-table seam. Inputs: `--profile <path> --worktree <root> [--channel <name>]`. Output (stdout): `{"tested":["<name>",...],"skipped":[{"name":"<name>","reason":"<reason>"}]}`. Calls `channel-ownership.sh` from Task 2. Exact skip reasons (verbatim): `stateful-owned-chat-driver-deferred`, `stateful-not-owned`, `stateful-unverifiable`. Owned + http ⇒ tested.

Decision table (per spec §Component 2):
- No `channels[]` (or only the implicit primary http channel) → tested = the primary entry's implicit http channel; skipped = `[]` (back-compat).
- `--channel <name>` set → resolve only that channel; apply the same per-channel rules below.
- Stateless channel (`singleton_id == null`) → **tested**.
- Stateful + owned + `driver == http` → **tested** (R1 carve-out).
- Stateful + owned + driver ∈ {browser, computer-use} → skip `stateful-owned-chat-driver-deferred`.
- Stateful + not-owned → skip `stateful-not-owned`.
- Stateful + unverifiable (isolate absent) → skip `stateful-unverifiable`.

- [ ] **Step 1: Write the failing test.** Create `skills/x-qa/scripts/tests/channel-select.sh`:
  ```bash
  #!/usr/bin/env bash
  # channel-select.sh — unit-test the stateless-first / stateful-aware decision table.
  set -euo pipefail
  SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
  SEL="$SKILL_DIR/scripts/lib/channel-select.sh"
  pass=0; fail=0
  ok() { if [[ "$2" == "$3" ]]; then pass=$((pass+1)); else
    fail=$((fail+1)); echo "FAIL: $1 (want '$3', got '$2')"; fi; }

  mkprofile() { # writes profile.json with the given channels[] JSON into $1
    cat > "$1" <<JSON
  { "schema":1,"version":"1.3.0","primary_entry_point":"api",
    "entry_points":[{"name":"api","type":"http","auto_managed":true,"primary":true,"verified":false,
      "launch":{"kind":"command","command":"true"},
      "base_url_template":"http://localhost:1","base_url_fallback":"http://localhost:1",
      "health":{"method":"GET","path":"/","expected_status":200}}],
    "channels": $2 }
  JSON
  }
  enable_singleton() { # <worktree> <id> <state>
    mkdir -p "$1/.worktree-isolate"
    cat > "$1/.worktree-isolate/feature-overrides.local.json" <<JSON
  {"schema":1,"overrides":[{"id":"$2","state":"$3"}],"updated_at":"2026-06-06T00:00:00Z"}
  JSON
  }

  CH_STATELESS='[{"name":"admin-api","driver":"http","audience":"admin","entry_point":"api","singleton_id":null,"base_url_template":"http://localhost:1","base_url_fallback":"http://localhost:1"}]'
  CH_HTTP_STATEFUL='[{"name":"webhook","driver":"http","audience":"system","entry_point":"api","singleton_id":"gh-webhook","base_url_template":"http://localhost:1","base_url_fallback":"http://localhost:1"}]'
  CH_CHAT_STATEFUL='[{"name":"tg","driver":"computer-use","audience":"external","entry_point":"external","singleton_id":"telegram-bot"}]'

  # A. stateless channel always tested, isolate absent
  W=$(mktemp -d); P="$W/profile.json"; mkprofile "$P" "$CH_STATELESS"
  out=$("$SEL" --profile "$P" --worktree "$W")
  ok "stateless tested" "$(jq -rc '.tested' <<<"$out")" '["admin-api"]'
  ok "stateless no skips" "$(jq -rc '.skipped' <<<"$out")" '[]'

  # B. http stateful, NOT owned (isolate absent) → unverifiable skip
  W=$(mktemp -d); P="$W/profile.json"; mkprofile "$P" "$CH_HTTP_STATEFUL"
  out=$("$SEL" --profile "$P" --worktree "$W")
  ok "http stateful isolate-absent skip" "$(jq -rc '.skipped' <<<"$out")" '[{"name":"webhook","reason":"stateful-unverifiable"}]'
  ok "http stateful unverifiable not tested" "$(jq -rc '.tested' <<<"$out")" '[]'

  # C. http stateful, isolate present but disabled → not-owned skip
  W=$(mktemp -d); P="$W/profile.json"; mkprofile "$P" "$CH_HTTP_STATEFUL"; enable_singleton "$W" "gh-webhook" "disabled"
  out=$("$SEL" --profile "$P" --worktree "$W")
  ok "http stateful not-owned skip" "$(jq -rc '.skipped' <<<"$out")" '[{"name":"webhook","reason":"stateful-not-owned"}]'

  # D. http stateful, OWNED → tested (R1 carve-out)
  W=$(mktemp -d); P="$W/profile.json"; mkprofile "$P" "$CH_HTTP_STATEFUL"; enable_singleton "$W" "gh-webhook" "enabled"
  out=$("$SEL" --profile "$P" --worktree "$W")
  ok "http stateful owned tested" "$(jq -rc '.tested' <<<"$out")" '["webhook"]'
  ok "http stateful owned no skip" "$(jq -rc '.skipped' <<<"$out")" '[]'

  # E. chat stateful, OWNED → deferred skip
  W=$(mktemp -d); P="$W/profile.json"; mkprofile "$P" "$CH_CHAT_STATEFUL"; enable_singleton "$W" "telegram-bot" "enabled"
  out=$("$SEL" --profile "$P" --worktree "$W")
  ok "chat stateful owned deferred" "$(jq -rc '.skipped' <<<"$out")" '[{"name":"tg","reason":"stateful-owned-chat-driver-deferred"}]'

  # F. back-compat: no channels[] → implicit primary http channel tested, nothing skipped
  W=$(mktemp -d); P="$W/profile.json"
  cat > "$P" <<'JSON'
  { "schema":1,"version":"1.0.0","primary_entry_point":"api",
    "entry_points":[{"name":"api","type":"http","auto_managed":true,"primary":true,"verified":false,
      "launch":{"kind":"command","command":"true"},
      "base_url_template":"http://localhost:1","base_url_fallback":"http://localhost:1",
      "health":{"method":"GET","path":"/","expected_status":200}}] }
  JSON
  out=$("$SEL" --profile "$P" --worktree "$W")
  ok "no channels → implicit primary tested" "$(jq -rc '.tested' <<<"$out")" '["api"]'
  ok "no channels → no skips" "$(jq -rc '.skipped' <<<"$out")" '[]'

  # G. --channel selects a single named channel only
  W=$(mktemp -d); P="$W/profile.json"
  mkprofile "$P" "$(jq -c '. + '"$CH_HTTP_STATEFUL" <<<"$CH_STATELESS")"
  out=$("$SEL" --profile "$P" --worktree "$W" --channel admin-api)
  ok "--channel narrows to one tested" "$(jq -rc '.tested' <<<"$out")" '["admin-api"]'
  ok "--channel ignores other channels" "$(jq -rc '.skipped' <<<"$out")" '[]'

  echo "channel-select: $pass passed, $fail failed"
  [[ $fail -eq 0 ]]
  ```
- [ ] **Step 2: Run it — expect FAIL.** `bash skills/x-qa/scripts/tests/channel-select.sh` → expect every `ok` to fail (script absent), final `channel-select: 0 passed, N failed`, exit 1.
- [ ] **Step 3: Implement `scripts/lib/channel-select.sh`.**
  ```bash
  #!/usr/bin/env bash
  # channel-select.sh — stateless-first / stateful-aware channel selection (Phase 4).
  # Emits {"tested":[<name>,...],"skipped":[{"name","reason"}]} to stdout.
  #
  # Decision table (spec §Component 2):
  #   singleton_id == null .............. stateless → tested (default QA target)
  #   stateful + owned + driver==http ... tested (R1 carve-out: drive the owned http singleton)
  #   stateful + owned + chat driver .... skip  stateful-owned-chat-driver-deferred
  #   stateful + not-owned .............. skip  stateful-not-owned
  #   stateful + unverifiable ........... skip  stateful-unverifiable
  #   no channels[] ..................... implicit primary http channel tested (back-compat)
  # Ownership comes from channel-ownership.sh (reads only feature-overrides.local.json, R2).
  set -euo pipefail

  LIB_DIR="$(cd "$(dirname "$0")" && pwd)"
  OWN="$LIB_DIR/channel-ownership.sh"

  PROFILE=""
  WORKTREE=""
  ONLY_CHANNEL=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --profile) PROFILE="$2"; shift 2 ;;
      --worktree) WORKTREE="$2"; shift 2 ;;
      --channel) ONLY_CHANNEL="$2"; shift 2 ;;
      *) echo "Unknown arg: $1" >&2; exit 2 ;;
    esac
  done
  [[ -f "$PROFILE" ]] || { echo "REASON=profile not found: $PROFILE" >&2; exit 2; }
  [[ -n "$WORKTREE" ]] || WORKTREE="$(pwd)"

  n_channels=$(jq -r '.channels // [] | length' "$PROFILE")

  # Back-compat: no channels[] → test the implicit primary http channel, skip nothing.
  if [[ "$n_channels" -eq 0 ]]; then
    primary=$(jq -r '.primary_entry_point' "$PROFILE")
    jq -nc --arg p "$primary" '{tested:[$p], skipped:[]}'
    exit 0
  fi

  # Select the channel set: all channels, or just the named one when --channel given.
  if [[ -n "$ONLY_CHANNEL" ]]; then
    channels=$(jq -c --arg n "$ONLY_CHANNEL" '[.channels[] | select(.name == $n)]' "$PROFILE")
    [[ "$(jq 'length' <<<"$channels")" -gt 0 ]] || { echo "REASON=channel '$ONLY_CHANNEL' not in profile" >&2; exit 2; }
  else
    channels=$(jq -c '.channels' "$PROFILE")
  fi

  tested='[]'
  skipped='[]'
  while IFS= read -r ch; do
    name=$(jq -r '.name' <<<"$ch")
    sid=$(jq -r '.singleton_id // "null"' <<<"$ch")
    driver=$(jq -r '.driver' <<<"$ch")

    if [[ "$sid" == "null" ]]; then
      tested=$(jq -c --arg n "$name" '. + [$n]' <<<"$tested")
      continue
    fi

    ownership=$("$OWN" --singleton-id "$sid" --worktree "$WORKTREE")
    case "$ownership" in
      owned)
        if [[ "$driver" == "http" ]]; then
          tested=$(jq -c --arg n "$name" '. + [$n]' <<<"$tested")
        else
          skipped=$(jq -c --arg n "$name" --arg r "stateful-owned-chat-driver-deferred" \
            '. + [{name:$n, reason:$r}]' <<<"$skipped")
        fi
        ;;
      not-owned)
        skipped=$(jq -c --arg n "$name" --arg r "stateful-not-owned" \
          '. + [{name:$n, reason:$r}]' <<<"$skipped")
        ;;
      unverifiable)
        skipped=$(jq -c --arg n "$name" --arg r "stateful-unverifiable" \
          '. + [{name:$n, reason:$r}]' <<<"$skipped")
        ;;
    esac
  done < <(jq -c '.[]' <<<"$channels")

  jq -nc --argjson t "$tested" --argjson s "$skipped" '{tested:$t, skipped:$s}'
  ```
- [ ] **Step 4: `chmod +x` and run — expect PASS.** `chmod +x skills/x-qa/scripts/lib/channel-select.sh && bash skills/x-qa/scripts/tests/channel-select.sh` → expect `channel-select: 13 passed, 0 failed`, exit 0. Also re-run the ownership test to confirm no regression: `bash skills/x-qa/scripts/tests/channel-ownership.sh` → `channel-ownership: 6 passed, 0 failed`.
- [ ] **Step 5: Commit.** `git add skills/x-qa/scripts/lib/channel-select.sh skills/x-qa/scripts/tests/channel-select.sh && git commit -m "feat(x-qa): stateless-first/stateful-aware channel-select resolver (R1)"`

---

### Task 5: Envelope additions in `aggregate-results.sh`

**Files:**
- Modify: `skills/x-qa/scripts/aggregate-results.sh` (emit block lines 264-282)
- Test: `skills/x-qa/scripts/tests/aggregate-channels.sh`

`aggregate-results.sh` reads `<run-dir>/channels.json` (written by Phase 4 via `channel-select.sh`) and emits `CHANNELS_TESTED=<csv>` + `CHANNELS_SKIPPED=<name:reason,...>`. When the artifact is absent (back-compat, e.g. no channels selected), both keys emit empty values. This mirrors the existing `scope.json` / `kb-counters.env` consumption pattern already in this script.

- [ ] **Step 1: Write the failing test.** Create `skills/x-qa/scripts/tests/aggregate-channels.sh`. It builds a minimal run-dir + plan + one passing case, then asserts the two envelope keys. (Mirrors the minimal-run fixtures used elsewhere; `aggregate-results.sh` requires a `cases/` dir, a plan with ≥1 `test_case`, and a per-case result file.)
  ```bash
  #!/usr/bin/env bash
  # aggregate-channels.sh — aggregate-results.sh must emit CHANNELS_TESTED /
  # CHANNELS_SKIPPED from <run-dir>/channels.json (empty when absent).
  set -euo pipefail
  SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
  AGG="$SKILL_DIR/scripts/aggregate-results.sh"
  WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
  cd "$WORK"; git init -q

  mk_run() { # writes a minimal run-dir + plan into $1, returns plan path on stdout
    local rd="$1"; mkdir -p "$rd/cases"
    cat > "$rd/plan.yaml" <<'YAML'
  feature: ch-test
  entry_point: api
  test_cases:
    - id: tc-1
      category: smoke
  YAML
    cat > "$rd/cases/tc-1.json" <<'JSON'
  [{"id":"tc-1","verdict":"pass","runner":"x","attempts":1,"duration_ms":1,"evidence":{},"error":""}]
  JSON
    echo "$rd/plan.yaml"
  }

  pass=0; fail=0
  field() { awk -F= -v k="$2" '$1==k{sub(/^[^=]*=/,""); print; exit}' <<<"$1"; }

  # 1. channels.json present → CSV + name:reason list, --no-kb to avoid KB side effects
  RD="$WORK/run-1"; PLAN=$(mk_run "$RD")
  cat > "$RD/channels.json" <<'JSON'
  {"tested":["admin-api","webhook"],"skipped":[{"name":"tg","reason":"stateful-not-owned"},{"name":"dash","reason":"stateful-unverifiable"}]}
  JSON
  out=$("$AGG" --run-dir "$RD" --plan "$PLAN" --no-kb)
  [[ "$(field "$out" CHANNELS_TESTED)" == "admin-api,webhook" ]] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: CHANNELS_TESTED got=[$(field "$out" CHANNELS_TESTED)]"; }
  [[ "$(field "$out" CHANNELS_SKIPPED)" == "tg:stateful-not-owned,dash:stateful-unverifiable" ]] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: CHANNELS_SKIPPED got=[$(field "$out" CHANNELS_SKIPPED)]"; }

  # 2. channels.json absent → both keys present and empty (back-compat)
  RD="$WORK/run-2"; PLAN=$(mk_run "$RD")
  out=$("$AGG" --run-dir "$RD" --plan "$PLAN" --no-kb)
  [[ "$(field "$out" CHANNELS_TESTED)" == "" ]] && grep -q '^CHANNELS_TESTED=' <<<"$out" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: CHANNELS_TESTED should be present+empty"; }
  [[ "$(field "$out" CHANNELS_SKIPPED)" == "" ]] && grep -q '^CHANNELS_SKIPPED=' <<<"$out" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: CHANNELS_SKIPPED should be present+empty"; }

  echo "aggregate-channels: $pass passed, $fail failed"
  [[ $fail -eq 0 ]]
  ```
- [ ] **Step 2: Run it — expect FAIL.** `bash skills/x-qa/scripts/tests/aggregate-channels.sh` → expect `FAIL: CHANNELS_TESTED ...` (keys not emitted yet), exit 1.
- [ ] **Step 3: Implement the channels read + emit in `aggregate-results.sh`.** After the `SERVICE_LAUNCHED="false"` default declaration (~line 16), the channels artifact is read in the envelope block. Insert just before `# Emit envelope` (~line 264):
  ```bash
  # Channel selection results (Phase 4 → <run-dir>/channels.json via channel-select.sh).
  # Absent artifact = no channels selected (back-compat) → both keys empty.
  channels_tested=""
  channels_skipped=""
  if [[ -f "$RUN_DIR/channels.json" ]]; then
    channels_tested=$(jq -r '(.tested // []) | join(",")' "$RUN_DIR/channels.json" 2>/dev/null || echo "")
    channels_skipped=$(jq -r '(.skipped // []) | map("\(.name):\(.reason)") | join(",")' "$RUN_DIR/channels.json" 2>/dev/null || echo "")
  fi
  ```
  Then append to the envelope emit block (after `echo "KB_PROMOTE_STATUS=$kb_status"`, line 282):
  ```bash
  echo "CHANNELS_TESTED=$channels_tested"
  echo "CHANNELS_SKIPPED=$channels_skipped"
  ```
- [ ] **Step 4: Run the test — expect PASS.** `bash skills/x-qa/scripts/tests/aggregate-channels.sh` → expect `aggregate-channels: 4 passed, 0 failed`, exit 0.
- [ ] **Step 5: Commit.** `git add skills/x-qa/scripts/aggregate-results.sh skills/x-qa/scripts/tests/aggregate-channels.sh && git commit -m "feat(x-qa): emit CHANNELS_TESTED/CHANNELS_SKIPPED from channels.json"`

---

### Task 6: doctor — `singleton_id` validation + info-nudge

**Files:**
- Modify: `skills/x-qa/scripts/doctor.sh` (channel-checks block lines 189-249)
- Modify: `skills/x-qa/references/doctor-checks.md`
- Test: `skills/x-qa/scripts/tests/channels.sh` (extend with C8 cases)

C8: when a channel's `singleton_id` is set AND `<repo_root>/.worktree-isolate/profile.json` exists with `singletons[]`, the id must resolve to a `singletons[].id` — dangling refs `warnings=$((warnings+1))`, never hard-fail. When `.worktree-isolate/profile.json` is absent or has no `singletons[]`, C8 is a **no-op** (must survive `--template-mode` in a fresh mktemp git root). Info-nudge: when `channels[]` present but no channel carries a non-null `singleton_id`, emit a distinct `info=` line on the PASS path.

- [ ] **Step 1: Write failing C8 cases in `channels.sh`.** Add after the existing path-traversal case (after line 56 in `channels.sh`), before the `--- update preserves ...` block:
  ```bash
  # C8: valid singleton_id resolving against an isolate profile → no extra warning
  ISO=$(mktemp -d); cd "$ISO"; git init -q; mkdir -p .worktree-isolate .x-skills/x-qa
  cat > .worktree-isolate/profile.json <<'JSON'
  {"schema":2,"singletons":[{"id":"gh-webhook","tier":"compose-service"}]}
  JSON
  jq '.repo_root="'"$ISO"'" | .channels[0].singleton_id="gh-webhook"' "$WORK/valid.json" > .x-skills/x-qa/profile.json
  out=$("$DOCTOR" .x-skills/x-qa/profile.json 2>&1); rc=$?
  if [[ $rc -eq 0 ]] && ! grep -q "first_failure=C8" <<<"$out"; then pass=$((pass+1)); else
    fail=$((fail+1)); echo "FAIL: valid singleton_id should pass doctor (rc=$rc)"; fi

  # C8: dangling singleton_id → PASS overall but warnings incremented (never hard-fail)
  jq '.repo_root="'"$ISO"'" | .channels[0].singleton_id="ghost-singleton"' "$WORK/valid.json" > .x-skills/x-qa/profile.json
  out=$("$DOCTOR" .x-skills/x-qa/profile.json 2>&1); rc=$?
  warn=$(awk -F= '/^warnings=/{print $2}' <<<"$out")
  if [[ $rc -eq 0 ]] && [[ "${warn:-0}" -ge 1 ]]; then pass=$((pass+1)); else
    fail=$((fail+1)); echo "FAIL: dangling singleton_id should warn not fail (rc=$rc warn=$warn)"; fi

  # Info-nudge: channels present, none carry singleton_id → info= line on PASS
  jq '.repo_root="'"$ISO"'"' "$WORK/valid.json" > .x-skills/x-qa/profile.json  # valid.json channels have no singleton_id
  out=$("$DOCTOR" .x-skills/x-qa/profile.json 2>&1)
  if grep -q "^info=" <<<"$out"; then pass=$((pass+1)); else
    fail=$((fail+1)); echo "FAIL: expected info= nudge when no channel carries singleton_id"; fi

  # C8 no-op under --template-mode with no isolate profile (must not error)
  jq '.channels[0].singleton_id="anything"' "$WORK/valid.json" > template-sid.json
  cd "$WORK"
  expect "singleton_id under template-mode (no isolate) passes" 0 "$ISO/template-sid.json"
  rm -rf "$ISO"
  ```
  > Note: `valid.json`'s channels carry no `singleton_id` today, so the info-nudge case is honest. The `expect` helper already exists at the top of `channels.sh`; reuse it for the template-mode no-op.
- [ ] **Step 2: Run it — expect FAIL.** `bash skills/x-qa/scripts/tests/channels.sh` → expect `FAIL: expected info= nudge ...` (and the dangling/valid C8 cases pass trivially today only if doctor doesn't crash — confirm the failure is the missing `info=` line / missing warning), exit 1.
- [ ] **Step 3: Implement C8 + info-nudge in `doctor.sh`.** Inside the `if [[ "$have_channels" -gt 0 ]]; then` block (after C7, before the closing `fi` at line 249), add:
  ```bash
    # C8: singleton_id resolves against the isolate profile when present (warning on
    # dangling, never hard-fail — isolate is optional). No-op when no isolate profile
    # or no singletons[] (survives --template-mode in a fresh repo root).
    iso_profile="$repo_root/.worktree-isolate/profile.json"
    if [[ -f "$iso_profile" ]] && [[ "$(jq -r '.singletons // [] | length' "$iso_profile" 2>/dev/null || echo 0)" -gt 0 ]]; then
      while IFS= read -r sid; do
        [[ -z "$sid" || "$sid" == "null" ]] && continue
        resolves=$(jq -r --arg id "$sid" '[.singletons[]? | select(.id == $id)] | length' "$iso_profile" 2>/dev/null || echo 0)
        [[ "$resolves" -ge 1 ]] || { warnings=$((warnings+1)); echo "warn=channel singleton_id '$sid' not found in isolate singletons[]" >&2; }
      done < <(jq -r '.channels[].singleton_id // empty' "$PROFILE_PATH")
    fi

    # Info-nudge: channels present but none carry a non-null singleton_id.
    with_sid=$(jq -r '[.channels[] | select(.singleton_id != null)] | length' "$PROFILE_PATH")
    if [[ "$with_sid" -eq 0 ]]; then
      info_nudge="channels present but none carry singleton_id — run 'x-qa update' for stateful-aware selection"
    fi
  ```
  Then add `info_nudge=""` near the top counter declarations (after `warnings=0`, line 21) and emit it on the PASS path. Change the closing PASS block (lines 309-312) to:
  ```bash
  echo "✓ doctor PASS"
  echo "checks_attempted=$checks_attempted"
  echo "checks_passed=$checks_passed"
  echo "warnings=$warnings"
  [[ -n "$info_nudge" ]] && echo "info=$info_nudge"
  ```
- [ ] **Step 4: Run the test — expect PASS.** `bash skills/x-qa/scripts/tests/channels.sh` → expect `channels: N passed, 0 failed`, exit 0.
- [ ] **Step 5: Document C8 + nudge in `doctor-checks.md`.** In `references/doctor-checks.md`, under a new `## Channel stateful-awareness` heading (after the KB integrity section ~line 36):
  ```markdown
  ## Channel stateful-awareness

  C8. When a channel sets `singleton_id` AND `<repo_root>/.worktree-isolate/profile.json` exists with a non-empty `singletons[]`, the id MUST resolve to a `singletons[].id`. A dangling ref increments `warnings` (and prints `warn=...` on stderr) — never a hard fail, because isolate is optional. No-op when no isolate profile / no `singletons[]` (survives `--template-mode`).

  Info-nudge. When `channels[]` is present but no channel carries a non-null `singleton_id`, doctor prints an `info=channels present but none carry singleton_id — run 'x-qa update' for stateful-aware selection` line on the PASS path. Info-level, distinct from `warnings` — never affects exit code.
  ```
- [ ] **Step 6: Commit.** `git add skills/x-qa/scripts/doctor.sh skills/x-qa/references/doctor-checks.md skills/x-qa/scripts/tests/channels.sh && git commit -m "feat(x-qa): doctor validates singleton_id + info-nudge for stateful migration"`

---

### Task 7: init interview + `x-qa update` migration (profile side)

**Files:**
- Modify: `skills/x-qa/references/init-interview.md` (Channel Enumeration section ~lines 64-81)
- Test: `skills/x-qa/scripts/tests/channel-contract.sh` (grep-anchor, extended in Task 9) + `skills/x-qa/scripts/tests/qa-memory.sh` (existing — proves `init.sh` unchanged & green)

Per the advisor: **no shell changes needed.** `init.sh` persists LLM-constructed JSON verbatim (so a channel with `singleton_id` flows through unchanged), and `update.sh` canon-compares whole channel objects (so `singleton_id` rides along automatically — verified at `scripts/update.sh:33-45`). This task is interview prose + a contract-grep only (YAGNI on script edits).

- [ ] **Step 1: Confirm `init.sh`/`update.sh` need no change (no failing code test).** Run the existing tests to establish the green baseline: `bash skills/x-qa/scripts/tests/qa-memory.sh` → `qa-memory: N passed, 0 failed`; `bash skills/x-qa/scripts/tests/channels.sh` → `channels: N passed, 0 failed`. The "failing test" for this task is the contract-grep added in Step 2.
- [ ] **Step 2: Add the failing contract-grep.** Append to `skills/x-qa/scripts/tests/channel-contract.sh` (before its final `echo`):
  ```bash
  # init-interview.md: stateful singleton mapping step (Task 7)
  need references/init-interview.md "Stateful channel mapping"
  need references/init-interview.md "singleton_id"
  ```
  Run `bash skills/x-qa/scripts/tests/channel-contract.sh` → expect `FAIL: references/init-interview.md missing: Stateful channel mapping`, exit 1.
- [ ] **Step 3: Add the mapping step to `init-interview.md`.** After the per-channel "Session" bullet in the Channel Enumeration section (~line 81), add:
  ```markdown
  ## Stateful channel mapping (isolate-aware)

  When `<repo_root>/.worktree-isolate/profile.json` exists, after each channel is
  confirmed, offer to link stateful-looking channels (bots, webhook receivers,
  schedulers) to an isolate singleton:

  > **Is `<channel-name>` a stateful singleton** (one live listener per platform —
  > Slack/Telegram/WhatsApp bot, webhook receiver)? If so, which isolate singleton
  > gates it? I see: `<singletons[].id list>`.
  > - Pick one → sets `channels[].singleton_id` (the channel is then **skipped**
  >   unless this worktree owns the singleton; an owned **http** channel is driven).
  > - "stateless" → sets `singleton_id: null` (default QA target, port-isolated).

  The enabling env var is **not** copied into the profile — it is looked up via the
  singleton (`singleton_id → singletons[].suggested_env_var`) so the two profiles
  cannot drift. `singleton_id` is optional: existing profiles without it keep working
  (absence = stateless).

  `x-qa update` runs the **same** mapping over channels that lack a `singleton_id`,
  cross-referencing the isolate profile. Channels already carrying `singleton_id`
  are left untouched. This is the x-qa half of the spec's §4c committed-profile
  migration — additive, never a hard gate.
  ```
- [ ] **Step 4: Run the contract test — expect PASS.** `bash skills/x-qa/scripts/tests/channel-contract.sh` → expect `channel-contract: N passed, 0 failed`, exit 0. Re-run `bash skills/x-qa/scripts/tests/qa-memory.sh` to confirm `init.sh` behavior is unchanged → `qa-memory: N passed, 0 failed`.
- [ ] **Step 5: Commit.** `git add skills/x-qa/references/init-interview.md skills/x-qa/scripts/tests/channel-contract.sh && git commit -m "docs(x-qa): init/update map stateful channels to isolate singleton_id (§4c)"`

---

### Task 8: SKILL.md — Phase 4 selection, channel-drivers skip reasons, Run Envelope

**Files:**
- Modify: `skills/x-qa/SKILL.md` (Phase 4 channel resolution lines 141-151; Run Envelope lines 81-111)
- Modify: `skills/x-qa/references/channel-drivers.md` (feature-gate section ~lines 31-35)
- Test: `skills/x-qa/scripts/tests/channel-contract.sh` (grep-anchor, extended in Task 9)

- [ ] **Step 1: Add failing contract-greps for the SKILL.md + channel-drivers prose.** Append to `channel-contract.sh` (before its final `echo`):
  ```bash
  # SKILL.md Phase 4 + Run Envelope (Task 8)
  need SKILL.md "CHANNELS_TESTED"
  need SKILL.md "CHANNELS_SKIPPED"
  need SKILL.md "channel-select.sh"
  need SKILL.md "stateless"
  # channel-drivers.md stateful skip reasons (Task 8)
  need references/channel-drivers.md "stateful-owned-chat-driver-deferred"
  need references/channel-drivers.md "stateful-not-owned"
  need references/channel-drivers.md "stateful-unverifiable"
  ```
  Run `bash skills/x-qa/scripts/tests/channel-contract.sh` → expect `FAIL: SKILL.md missing: CHANNELS_TESTED` (and the others), exit 1.
- [ ] **Step 2: Rewrite the Phase 4 channel-resolution bullet in `SKILL.md`.** Replace the "No channel selected → default to the primary entry point's implicit `http` channel" sub-bullet (lines 150-151) and extend the resolution block. After the existing `http`/`browser`/`computer-use` driver bullets (line 149), insert:
  ```markdown
     - **Stateless-first default (no `--channel`).** Run `scripts/lib/channel-select.sh
       --profile <profile> --worktree <worktree> [--channel <name>]` → persist
       `<run-dir>/channels.json`. With no `--channel`, it defaults to **stateless**
       channels (`singleton_id == null`) on the primary entry point. No `channels[]`
       at all → the implicit primary `http` channel (back-compat).
     - **Stateful resolution** (ownership from `feature-overrides.local.json` only, R2):
       - owned here AND `driver == http` → **EXECUTE** via the existing http runner path.
       - owned here AND driver ∈ {browser, computer-use} → skip
         `CHANNEL_SKIPPED reason=stateful-owned-chat-driver-deferred`.
       - not owned (the default) → skip `CHANNEL_SKIPPED reason=stateful-not-owned`.
       - isolate not set up → skip `CHANNEL_SKIPPED reason=stateful-unverifiable`
         (never test a stateful channel blind).
       `channels.json.tested` drives Phases 8-15; `channels.json.skipped` feeds the
       envelope's `CHANNELS_SKIPPED`.
  ```
  Remove/replace the now-superseded line 150-151 sub-bullet so the "no channel" path points at `channel-select.sh` rather than describing it inline.
- [ ] **Step 3: Add the two envelope keys to the Run Envelope success block in `SKILL.md`.** After the `EXPLORE_OBLIGATIONS_ADDED=<n>` line (line 110), add:
  ```markdown
  CHANNELS_TESTED=<csv>         # channels selected for execution (names)
  CHANNELS_SKIPPED=<name:reason,...>  # skipped channels + reason (stateful-not-owned / stateful-unverifiable / stateful-owned-chat-driver-deferred)
  ```
- [ ] **Step 4: Document the stateful skip reasons + owned-http carve-out in `channel-drivers.md`.** In `references/channel-drivers.md`, after the existing "Feature-gate at run time" section (~line 35), add:
  ```markdown
  ## Stateful channels (`singleton_id` set)

  A channel with a non-null `singleton_id` is **stateful** — it links to an
  `x-worktree-isolate singletons[].id`. Selection (`scripts/lib/channel-select.sh`)
  reads ownership from `<worktree>/.worktree-isolate/feature-overrides.local.json`
  ONLY (never the global registry, R2): `state == "enabled"` ⇒ owned here.

  | Situation | Outcome |
  |---|---|
  | owned here AND `driver == http` | **EXECUTE** via the existing http runner (R1 carve-out — drive the singleton this worktree holds) |
  | owned here AND driver ∈ {browser, computer-use} | skip `stateful-owned-chat-driver-deferred` (chat drivers are capture-only) |
  | not owned here (default) | skip `stateful-not-owned` |
  | isolate not set up at all | skip `stateful-unverifiable` (never test stateful blind) |

  Stateless channels (`singleton_id == null`) are the **default QA target** — each
  on its own isolated port. The enabling env var is looked up via the singleton
  (`singleton_id → singletons[].suggested_env_var`), never copied into the profile.
  ```
- [ ] **Step 5: Run the contract test — expect PASS.** `bash skills/x-qa/scripts/tests/channel-contract.sh` → expect `channel-contract: N passed, 0 failed`, exit 0.
- [ ] **Step 6: Commit.** `git add skills/x-qa/SKILL.md skills/x-qa/references/channel-drivers.md skills/x-qa/scripts/tests/channel-contract.sh && git commit -m "docs(x-qa): Phase 4 stateless-first selection + stateful skip reasons + envelope keys"`

---

### Task 9: Full-suite green gate + shared-contract appendix sync

**Files:**
- Test: all of `skills/x-qa/scripts/tests/*.sh`

Final task — confirm the whole x-qa test suite is green and the shared-contract names match verbatim across every file touched. No new code; this is the leave-green verification gate.

- [ ] **Step 1: Run every x-qa test directly and confirm 0 failures.**
  ```bash
  for t in skills/x-qa/scripts/tests/*.sh; do
    echo "== $t =="
    bash "$t" || echo "!!! FAILED: $t"
  done
  ```
  Expect each to print `<name>: N passed, 0 failed` and no `!!! FAILED` line. Pay special attention to `channels.sh`, `channel-ownership.sh`, `channel-select.sh`, `aggregate-channels.sh`, `channel-contract.sh`, `classify.sh`, `qa-memory.sh`.
- [ ] **Step 2: Verify the skip-reason strings are byte-identical everywhere.** The three reasons must match verbatim across `channel-select.sh`, `channel-drivers.md`, `SKILL.md`, and the tests:
  ```bash
  grep -RhoE "stateful-(owned-chat-driver-deferred|not-owned|unverifiable)" \
    skills/x-qa/scripts/lib/channel-select.sh \
    skills/x-qa/references/channel-drivers.md \
    skills/x-qa/SKILL.md | sort -u
  ```
  Expect exactly three lines: `stateful-not-owned`, `stateful-owned-chat-driver-deferred`, `stateful-unverifiable`. Any extra/missing line = a typo to fix before completing.
- [ ] **Step 3: Verify the envelope keys match between emitter and doc.**
  ```bash
  grep -c "^echo \"CHANNELS_TESTED=" skills/x-qa/scripts/aggregate-results.sh
  grep -c "^echo \"CHANNELS_SKIPPED=" skills/x-qa/scripts/aggregate-results.sh
  grep -c "CHANNELS_TESTED" skills/x-qa/SKILL.md
  grep -c "CHANNELS_SKIPPED" skills/x-qa/SKILL.md
  ```
  Each must be ≥1.
- [ ] **Step 4: Final commit (if Steps 2-3 surfaced any fix).** Only if a string-sync fix was needed: `git add -A skills/x-qa && git commit -m "chore(x-qa): sync stateful channel contract strings across docs + scripts"`. Otherwise no-op.

> **Note for the orchestrator:** A version bump of the three manifests (`plugin.json`, `marketplace.json`, `package.json`) per `CLAUDE.md § Release Workflow` is a separate release step, NOT part of this feature plan. The profile-content `version` bump lives in `templates/profile.example.json` (Task 1) and is auto-bumped by `update.sh` for live profiles.

---

## SHARED CONTRACT (verbatim — do not alter names)

> Reproduced from `docs/superpowers/plans/2026-06-06-stateful-stateless-channel-isolation.md`. Every implementer MUST use these exact strings.

- **Link field:** x-qa `channels[].singleton_id` (string | null) → isolate `singletons[].id`.
- **x-qa reads ONLY worktree-local isolate files:**
  - `state.local.json` (`allocated_ports`) — already wired in `launch-entry-point.sh`.
  - `feature-overrides.local.json` (`overrides[]` of `{id, state}`) — the new read (ownership).
  - **NEVER the global `singleton_owners` registry (R2).**
- **Ownership rule:** "`enabled` in `feature-overrides.local.json` ⇒ owned here". isolate absent ⇒ `unverifiable`. (`disabled` / `acknowledged` / absent entry ⇒ not owned.)
- **Skip reasons (exact strings):**
  - `stateful-owned-chat-driver-deferred`
  - `stateful-not-owned`
  - `stateful-unverifiable`
  - Owned + http ⇒ **EXECUTE** (no skip, R1 carve-out).
- **Envelope additions:** `CHANNELS_TESTED=<csv>`, `CHANNELS_SKIPPED=<name:reason,...>`.
- **The enabling env var is NOT copied** into the x-qa profile — looked up via the singleton (`singleton_id → singletons[].suggested_env_var`) when needed; statefulness is derived solely from `singleton_id` presence.
- **Profile:** `singleton_id` optional, `null` = stateless, schema stays `1`, `version` bumped; doctor emits an info-nudge when channels carry no `singleton_id` + a dangling-ref warning when `singleton_id` does not resolve against the isolate profile.

---

## Why this order leaves the skill green at every commit

1. **Task 1** (schema doc + example + version) — additive doc/JSON only; `channels.sh` stays green (doctor doesn't validate `singleton_id` until Task 6).
2. **Task 2** (ownership helper) — new isolated lib + test; nothing else references it yet.
3. **Tasks 3+4** (selection resolver) — new isolated lib consuming Task 2; not yet wired into the run loop, so the run path is unchanged.
4. **Task 5** (envelope) — `aggregate-results.sh` reads `channels.json` *when present*; absent = empty keys = back-compat, so existing run flows are unaffected.
5. **Task 6** (doctor) — C8 is no-op without an isolate profile and warning-only with a dangling ref; never changes exit code for existing profiles.
6. **Task 7** (init/update prose) — no shell change; `init.sh`/`update.sh` already carry `singleton_id` through verbatim.
7. **Task 8** (SKILL.md/channel-drivers) — prose wiring that points the run loop at `channel-select.sh`; guarded by contract-greps.
8. **Task 9** — full-suite green gate + verbatim string sync.

Back-compat invariants held throughout: `channels.json` missing → empty envelope keys; no `channels[]` → implicit primary http channel tested, nothing skipped; `singleton_id` optional → all existing `version:"1.0.0"` inline-fixture profiles still pass doctor.
