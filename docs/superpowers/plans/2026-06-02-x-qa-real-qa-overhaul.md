# x-qa Real-QA Overhaul — Channels Capture + Research-Driven Exhaustive Generation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make x-qa behave like a real QA engineer end-to-end: (Arc A) capture every **channel** it reaches a system through — API audiences, dashboard, chat bots — each with its own driver, port, env/config and credentials-*location* in a git-tracked `QA_MEMORY.md`, route `run` by driver (executing `http` today, capturing the rest), and **never** execute the repo's own e2e suite; and (Arc B) **research each feature's domain before writing cases** (entities, field constraints, invariants, state transitions), enumerate production failure modes from a codified taxonomy, and **gate generation on covering every required obligation** — including the "false case" (a 200 response with a wrong result), not just error-probing.

**Architecture:** Three arcs over the same skill, then one finalize.
- **Arc A — Capture spine (Tasks 1–8).** `entry_points[]` (how to *start* services) stays unchanged; a new top-level `channels[]` (how to *reach/drive* them) is added alongside it. A driver registry (`http`→curl, `browser`→Playwright MCP, `computer-use`→real chat client) feature-gates execution. Narrative onboarding knowledge lands in a git-tracked `QA_MEMORY.md`. Delivers capture + `http` execution; `browser`/`computer-use` execution is sequenced as follow-on plans (Roadmap).
- **Arc B — Research-driven generation (Tasks 9–13).** The Scout (Run Phase 5) gains a **code-first Domain Research** step emitting `domain_model` + `obligations[]` into the existing `scope.json`. A taxonomy (`failure-mode-taxonomy.md`) drives obligation enumeration; cases gain `covers: [obligation-id]`; a deterministic `coverage-check.sh` enforces that every `required` obligation is covered. The LLM *enumerates* obligations (judgment); the script *enforces* coverage (determinism).
- **Arc C — Exploratory QA team (Tasks 14–18).** A new Run Phase 13.5 turns `obligations[]` into worker assignments and dispatches a **bounded swarm of curious worker agents** that drive the live service to *break* each obligation — chasing the taxonomy's "false case" (200-but-wrong) that a single-shot HTTP runner cannot. Findings land on a **shared bug-board** (native Claude team when pinned, background fanout otherwise), get deduped + **independently triaged**, and each confirmed bug is **minted into a red repro stub** routed to `x-bugfix` (it earns a KB regression slot only after the fix lands and it goes green). Default-on locally, **skipped in CI**; ≤6 workers, ≤15 probes each.
- **Task 19 — Finalize.** Combined gotchas, the full combined test suite, and a single version bump.

**Tech Stack:** Bash 3.2-compatible shell + `jq` (1.7) + `yq` (mikefarah v4), JSON profile schema + YAML test plans, Markdown skill contracts, the existing `scripts/tests/*.sh` harness pattern (mktemp + `git init` + assertions).

---

## Scope

**In scope:** `channels[]` schema + validation, channel scan hints, `QA_MEMORY.md` capture + reconciliation, expanded `init` interview, `run` channel selection + driver feature-gate, the never-run-the-repo's-e2e-suite guard (Arc A); `domain_model` + `obligations[]` in `scope.json`, code-first domain research, failure-mode taxonomy (probing + semantic/false-case), `covers[]` + obligation-gated Required Coverage, `coverage-check.sh` gate + golden test, run-phase wiring + envelope counters (Arc B); obligation→worker clustering (`cluster-partition.sh`), exploratory worker + team-coordination contracts, bug-board dedup (`finding-merge.sh`), triage/verify gate, confirmed-finding→KB-case minting (`finding-to-case.sh`), Phase 13.5 wiring + `--explore`/`--no-explore` + `EXPLORE_*` envelope counters + the native-team/bg-fanout capability gate (Arc C); combined gotchas + single version bump (Task 19).

**Out of scope (follow-on plans, see Roadmap):** executing `browser` (Playwright MCP) and `computer-use` (chat) drivers; promoting `domain_model` into the git-tracked KB for cross-run reuse (stays ephemeral in the run-dir for now); auto-generating deterministic-case *bodies* (still LLM-authored — this plan gates their *coverage*, not their prose); feeding minted `EXPLORE_OBLIGATIONS_ADDED` back into the scout's enumeration on the *same* run (they land in the report + next run, not a within-run re-scout).

## Anchoring & ordering (read before executing)

Arc A executes first, against the **pristine** tree — so its line-number anchors ("insert after Check 14's closing `fi`, line 187") are valid as written. Arc B executes after Arc A and uses **textual anchors only** (quoted phrases, never line numbers); each Arc B anchor has been verified to survive Arc A's edits (the two arcs touch *different sections* of the shared files `SKILL.md` and `gotchas.md`, and Arc B never edits the files Arc A creates). The version trio is bumped **once**, in Task 14, reading the current version at execution time.

### Obligation model (Arc B single source of truth — referenced by Tasks 9–12)

The scout emits `scope.json.obligations[]`. Each obligation is the unit the coverage gate enforces. **Stable id grammar** (used identically in Task 9 scope schema, Task 10 taxonomy, Task 11 `covers[]`, and Task 12 `coverage-check.sh`):

| `kind` | id format | Covered by a case that… |
|---|---|---|
| `field` | `field:<entity>.<field>:<constraint-slug>` | exercises that field constraint (edge/error case) |
| `invariant` | `inv:<slug>` | asserts the invariant holds **on a success response** (the "false case") |
| `transition` | `trans:<from>-><to>` | drives that legal state transition and asserts it succeeds |
| `illegal-transition` | `xtrans:<from>-><to>` | attempts the illegal transition and asserts it is rejected |
| `failure-mode` | `fmode:<area>:<mode>` | triggers that taxonomy failure mode |

Each obligation object: `{ "id": <string>, "kind": <enum above>, "ref": <string>, "severity": "required"|"recommended", "source": "acceptance"|"domain"|"taxonomy" }`. The gate enforces `required`; `recommended` is reported but never blocks.

## File Structure

| File | Responsibility | Action | Arc |
|---|---|---|---|
| `skills/x-qa/references/profile-schema.md` | Document `channels[]` Channel object + validation rules | Modify | A |
| `skills/x-qa/templates/profile.example.json` | Full example gains a `channels[]` block | Modify | A |
| `skills/x-qa/templates/profile.minimal.json` | Minimal example gains one channel | Modify | A |
| `skills/x-qa/scripts/doctor.sh` | Validate `channels[]` (C1–C7) + QA_MEMORY presence warning | Modify | A |
| `skills/x-qa/scripts/init.sh` | `--memory-md` writes `QA_MEMORY.md` | Modify | A |
| `skills/x-qa/scripts/lib/scan-helpers.sh` | New `scan_channels` deterministic hint generator | Modify | A |
| `skills/x-qa/references/qa-memory-schema.md` | Define the `QA_MEMORY.md` markdown contract | Create | A |
| `skills/x-qa/templates/qa-memory.example.md` | Authoring template for `QA_MEMORY.md` | Create | A |
| `skills/x-qa/references/channel-drivers.md` | Driver registry + feature-gate + build/capture matrix | Create | A |
| `skills/x-qa/references/init-interview.md` | Channel + monitoring/env/db/creds sections + x-research scan | Modify | A |
| `skills/x-qa/scripts/classify-intent.sh` | Emit `resolved.channel` | Modify | A |
| `skills/x-qa/references/intent-detection.md` | Document `--channel` + NL channel selection | Modify | A |
| `skills/x-qa/references/case-runner-prompts.md` | Runner "real QA, never the repo's suite" guard | Modify | A |
| `skills/x-qa/scripts/update.sh` | Reconcile `channels[]`; warn on `QA_MEMORY.md` staleness | Modify | A |
| `skills/x-qa/references/update-diff-rules.md` | Channels + QA_MEMORY diff rules | Modify | A |
| `skills/x-qa/scripts/tests/channels.sh` | Channel schema validation tests | Create | A |
| `skills/x-qa/scripts/tests/scan-channels.sh` | `scan_channels` hint tests | Create | A |
| `skills/x-qa/scripts/tests/qa-memory.sh` | `init --memory-md` write test | Create | A |
| `skills/x-qa/scripts/tests/channel-contract.sh` | Grep-anchored doc-contract checks (Arc A) | Create | A |
| `skills/x-qa/references/scout-prompt.md` | Domain-research procedure + `domain_model`/`obligations` in scope | Modify | B |
| `skills/x-qa/references/failure-mode-taxonomy.md` | QA checklist: probing + semantic/"false case" + id scheme | Create | B |
| `skills/x-qa/references/test-plan-schema.md` | `covers[]` field + obligation-gated Required Coverage | Modify | B |
| `skills/x-qa/templates/test-plan.example.yml` | Example cases gain `covers:` tags | Modify | B |
| `skills/x-qa/scripts/coverage-check.sh` | Deterministic obligation-coverage gate | Create | B |
| `skills/x-qa/scripts/tests/coverage-check.sh` | Golden pass/fail fixtures for the gate | Create | B |
| `skills/x-qa/scripts/tests/domain-contract.sh` | Grep-anchored doc-contract checks (Arc B) | Create | B |
| `skills/x-qa/scripts/explore/cluster-partition.sh` | Partition `obligations[]` into ≤N worker clusters | Create | C |
| `skills/x-qa/references/explorer-prompts.md` | Curious exploratory worker prompt (hunt false-case, probe budget) | Create | C |
| `skills/x-qa/references/explore-team.md` | Team coordination + capability gate + CI-skip + bounded swarm | Create | C |
| `skills/x-qa/scripts/explore/finding-merge.sh` | Dedup the bug-board by signature (keep highest severity) | Create | C |
| `skills/x-qa/scripts/explore/finding-to-case.sh` | Mint a red repro stub (for x-bugfix) from a confirmed finding | Create | C |
| `skills/x-qa/references/triage-verify.md` | Adversarial verify gate (independent confirm before report) | Create | C |
| `skills/x-qa/scripts/tests/cluster-partition.sh` | Golden partition test | Create | C |
| `skills/x-qa/scripts/tests/explore-contract.sh` | Grep-anchored doc + SKILL.md contract checks (Arc C) | Create | C |
| `skills/x-qa/scripts/tests/finding-merge.sh` | Golden bug-board dedup test | Create | C |
| `skills/x-qa/scripts/tests/finding-to-case.sh` | Golden mint test (minted case satisfies coverage gate) | Create | C |
| `skills/x-qa/SKILL.md` | Channel resolution + driver gate + e2e guard (A); domain-research + coverage gate + envelope (B); Phase 13.5 + explore flags/routing/envelope (C) | Modify | A+B+C |
| `skills/x-qa/gotchas.md` | Channel/driver gotchas (A) + research/coverage gotchas (B) + exploratory-team gotchas, lift #13 (C) | Modify | A+B+C |
| `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `package.json` | Single version bump | Modify | T19 |

---
### Task 1: `channels[]` schema + doctor validation

**Files:**
- Modify: `skills/x-qa/scripts/doctor.sh` (insert channel checks after Check 14, before the KB checks block at line 189)
- Modify: `skills/x-qa/references/profile-schema.md`
- Modify: `skills/x-qa/templates/profile.example.json`, `skills/x-qa/templates/profile.minimal.json`
- Create: `skills/x-qa/scripts/tests/channels.sh`
- Create fixtures inline in the test (mktemp profiles)

- [ ] **Step 1: Write the failing test**

Create `skills/x-qa/scripts/tests/channels.sh`:

```bash
#!/usr/bin/env bash
# channels.sh — doctor.sh channels[] validation, run in --template-mode
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
DOCTOR="$SKILL_DIR/scripts/doctor.sh"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
cd "$WORK"; git init -q

pass=0; fail=0
expect() { # <desc> <expected-exit> <profile-file>
  local desc="$1" want="$2" file="$3" got=0
  "$DOCTOR" --template-mode "$file" >/dev/null 2>&1 || got=$?
  if [[ "$got" == "$want" ]]; then pass=$((pass+1)); else
    fail=$((fail+1)); echo "FAIL: $desc (want exit $want, got $got)"; fi
}

base='{ "schema":1, "version":"1.0.0", "primary_entry_point":"api",
  "entry_points":[{"name":"api","type":"http","auto_managed":true,"primary":true,"verified":false,
    "launch":{"kind":"command","command":"true"},
    "base_url_template":"http://localhost:1","base_url_fallback":"http://localhost:1",
    "health":{"method":"GET","path":"/","expected_status":200}}]'

# valid: http channel + browser channel + external chat channel
jq -n "$base, \"channels\":[
  {\"name\":\"admin-api\",\"driver\":\"http\",\"audience\":\"admin\",\"entry_point\":\"api\",
   \"base_url_template\":\"http://localhost:1\",\"base_url_fallback\":\"http://localhost:1\",
   \"auth\":{\"kind\":\"bearer\",\"token_source\":\"env:ADMIN_TOKEN\"}},
  {\"name\":\"dashboard\",\"driver\":\"browser\",\"audience\":\"user\",\"entry_point\":\"api\",
   \"base_url_template\":\"http://localhost:1\",\"base_url_fallback\":\"http://localhost:1\"},
  {\"name\":\"telegram-bot\",\"driver\":\"computer-use\",\"audience\":\"external\",\"entry_point\":\"external\"}
] }" > valid.json
expect "valid channels pass" 0 valid.json

# bad driver
jq '.channels[1].driver="grpc"' valid.json > bad-driver.json
expect "bad driver fails" 1 bad-driver.json

# bad audience
jq '.channels[0].audience="superuser"' valid.json > bad-aud.json
expect "bad audience fails" 1 bad-aud.json

# dangling entry_point ref
jq '.channels[0].entry_point="ghost"' valid.json > bad-ref.json
expect "dangling entry_point fails" 1 bad-ref.json

# literal secret in channel auth (security)
jq '.channels[0].auth.token_source="sk-live-abc123"' valid.json > bad-secret.json
expect "literal secret in channel auth fails" 1 bad-secret.json

# browser driver missing base_url
jq 'del(.channels[1].base_url_template)' valid.json > bad-url.json
expect "browser channel missing base_url fails" 1 bad-url.json

echo "channels: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash skills/x-qa/scripts/tests/channels.sh`
Expected: FAIL — "valid channels pass (want exit 0, got 0)" passes but the negative cases report `got 0` because doctor.sh does not yet validate channels (everything currently exits 0). Net: non-zero exit, several `FAIL:` lines.

- [ ] **Step 3: Add channel validation to `doctor.sh`**

Insert this block in `skills/x-qa/scripts/doctor.sh` immediately **after** Check 14's closing `fi` (line 187) and **before** the `# ---- KB integrity checks` comment (line 189):

```bash
# ---- Channel checks (skipped if no channels present) -----------------------
have_channels=$(jq -r '.channels // [] | length' "$PROFILE_PATH")
if [[ "$have_channels" -gt 0 ]]; then
  # C1: channel name slugs valid + unique
  attempt
  dupes=$(jq -r '[.channels[].name] | group_by(.) | map(select(length>1)) | length' "$PROFILE_PATH")
  [[ "$dupes" == "0" ]] || fail C1 "duplicate channel names"
  while IFS= read -r cname; do
    [[ "$cname" =~ ^[a-z0-9]([a-z0-9-]{0,38}[a-z0-9])?$ ]] || fail C1 "invalid channel slug: $cname"
  done < <(jq -r '.channels[].name' "$PROFILE_PATH")
  pass

  # C2: driver enum
  attempt
  bad=$(jq -r '[.channels[] | select(.driver as $d | ["http","browser","computer-use"] | index($d) | not)] | length' "$PROFILE_PATH")
  [[ "$bad" == "0" ]] || fail C2 "channel driver must be http|browser|computer-use"
  pass

  # C3: audience enum
  attempt
  bad=$(jq -r '[.channels[] | select(.audience as $a | ["admin","user","external","system"] | index($a) | not)] | length' "$PROFILE_PATH")
  [[ "$bad" == "0" ]] || fail C3 "channel audience must be admin|user|external|system"
  pass

  # C4: entry_point resolves to an entry, or is "external"
  attempt
  while IFS= read -r ref; do
    [[ "$ref" == "external" ]] && continue
    jq -e --arg n "$ref" '.entry_points[] | select(.name==$n)' "$PROFILE_PATH" >/dev/null \
      || fail C4 "channel entry_point '$ref' not in entry_points and != 'external'"
  done < <(jq -r '.channels[].entry_point' "$PROFILE_PATH")
  pass

  # C5: channel auth token_source — env: or file: only (no literal secrets; reuses rule 9)
  attempt
  while IFS= read -r src; do
    [[ -z "$src" || "$src" == "null" ]] && continue
    [[ "$src" =~ ^(env:[A-Za-z0-9_]+|file:[A-Za-z0-9_./-]+)$ ]] \
      || fail C5 "invalid channel auth token_source: $src (env:NAME or file:path; literal secrets rejected)"
  done < <(jq -r '.channels[].auth.token_source // empty' "$PROFILE_PATH")
  pass

  # C6: http/browser drivers require base_url_template + base_url_fallback
  attempt
  while IFS= read -r ch; do
    drv=$(jq -r '.driver' <<<"$ch")
    if [[ "$drv" == "http" || "$drv" == "browser" ]]; then
      for f in base_url_template base_url_fallback; do
        [[ -n "$(jq -r ".$f // empty" <<<"$ch")" ]] || fail C6 "channel driver=$drv missing $f"
      done
    fi
  done < <(jq -c '.channels[]' "$PROFILE_PATH")
  pass

  # C7: narrative memory presence (warning, not fail)
  [[ -f "$(dirname "$PROFILE_PATH")/QA_MEMORY.md" ]] || warnings=$((warnings+1))
fi
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash skills/x-qa/scripts/tests/channels.sh`
Expected: PASS — `channels: 6 passed, 0 failed`

Also run the existing suite to confirm no regression: `bash skills/x-qa/scripts/tests/smoke.sh`
Expected: PASS

- [ ] **Step 5: Document the schema + update templates**

Append to `skills/x-qa/references/profile-schema.md` after the `## Fixtures` block (before `## Validation Rules`):

```markdown
## Channels (`channels[]`, optional)

A **channel** is one way QA *reaches and drives* the system — distinct from an
`entry_point` (how to *start* a service). One launched service can expose many
channels (admin API + user API + dashboard); a channel may have no local
service (`entry_point: "external"`, e.g. a hosted chat bot).

| Field | Type | Required | Notes |
|---|---|---|---|
| `name` | string (slug) | yes | Unique. Used as `--channel <name>`. |
| `driver` | enum | yes | `http` \| `browser` \| `computer-use`. Picks the runner; see `references/channel-drivers.md`. |
| `audience` | enum | yes | `admin` \| `user` \| `external` \| `system`. Drives which credentials apply. |
| `entry_point` | string | yes | A `entry_points[].name`, or `"external"` for hosted surfaces. |
| `base_url_template` | string | http/browser | Where to reach it. Supports `${ISOLATE_PORT_<NAME>}`. |
| `base_url_fallback` | string | http/browser | Used when isolate state absent. |
| `port` | int | no | Inbound port hint for this surface. |
| `auth` | Auth | no | Same Auth schema as entry points. `token_source` is **location only** (`env:`/`file:`) — literal secrets rejected by `doctor.sh` (C5). |
| `app` | string | no | Client identity for browser/computer-use chat (e.g. `telegram-web`, `whatsapp-desktop`). |
| `target` | string | no | Conversation/contact a chat driver drives (e.g. `@my_test_bot`). |
| `session` | string | no | Description of the stateful logged-in session (e.g. "QR bootstrap one-time, manual"). **Description only — never a secret.** |
| `memory_ref` | string | no | Anchor into `QA_MEMORY.md` (e.g. `QA_MEMORY.md#telegram-bot`). |

### Channel Validation Rules (enforced by `doctor.sh`)

- C1 `name` is a unique 1-40 char lowercase slug.
- C2 `driver` ∈ {`http`,`browser`,`computer-use`}.
- C3 `audience` ∈ {`admin`,`user`,`external`,`system`}.
- C4 `entry_point` is `"external"` or matches an `entry_points[].name`.
- C5 `auth.token_source` matches `^(env:|file:)…$`. **Literal secrets rejected.**
- C6 `http`/`browser` drivers require `base_url_template` + `base_url_fallback`.
- C7 (warning) `channels[]` present but no `QA_MEMORY.md` next to the profile.
```

Add a `channels` array to `skills/x-qa/templates/profile.example.json`: an `admin-api` http channel and a `dashboard` browser channel — **both with `entry_point` set to the literal value of the example's existing `primary_entry_point`** (so C4 resolves; do not invent a name) — plus a `telegram-bot` computer-use channel with `entry_point: "external"`. Give the http/browser channels `base_url_template` + `base_url_fallback` (reuse the primary entry's URLs). Add one `http` channel to `skills/x-qa/templates/profile.minimal.json`, also referencing that file's `primary_entry_point`.

Verify templates still validate: `bash skills/x-qa/scripts/doctor.sh --template-mode skills/x-qa/templates/profile.example.json`
Expected: `✓ doctor PASS`

- [ ] **Step 6: Commit**

```bash
git add skills/x-qa/scripts/doctor.sh skills/x-qa/scripts/tests/channels.sh \
  skills/x-qa/references/profile-schema.md skills/x-qa/templates/profile.example.json \
  skills/x-qa/templates/profile.minimal.json
git commit -m "feat(x-qa): add channels[] schema + doctor validation"
```

---

### Task 2: `scan_channels` deterministic hint generator

**Files:**
- Modify: `skills/x-qa/scripts/lib/scan-helpers.sh` (append a new function)
- Create: `skills/x-qa/scripts/tests/scan-channels.sh`

- [ ] **Step 1: Write the failing test**

Create `skills/x-qa/scripts/tests/scan-channels.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "$SKILL_DIR/scripts/lib/scan-helpers.sh"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/src"
cat > "$WORK/package.json" <<'JSON'
{ "dependencies": { "telegraf": "^4.0.0", "next": "^14" } }
JSON
cat > "$WORK/next.config.js" <<'JS'
module.exports = {}
JS

out=$(scan_channels "$WORK")
pass=0; fail=0
check() { if echo "$out" | jq -e "$1" >/dev/null; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: $2"; fi; }

check 'map(select(.name=="telegram"))|length==1' "telegram bot-sdk hint"
check 'map(select(.driver=="computer-use"))|length>=1' "chat hint uses computer-use driver"
check 'map(select(.name=="dashboard" and .driver=="browser"))|length==1' "dashboard browser hint"
check 'all(.[]; has("confidence"))' "every hint has confidence"

echo "scan-channels: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash skills/x-qa/scripts/tests/scan-channels.sh`
Expected: FAIL with `scan_channels: command not found` (function does not exist yet).

- [ ] **Step 3: Implement `scan_channels`**

Append to `skills/x-qa/scripts/lib/scan-helpers.sh`:

```bash
scan_channels() {
  local root="$1"
  local items='[]'

  # Multiple exposed compose ports → candidate http channels
  if [[ -f "$root/docker-compose.yml" ]] || [[ -f "$root/docker-compose.yaml" ]]; then
    local compose_file
    compose_file=$([[ -f "$root/docker-compose.yml" ]] && echo "$root/docker-compose.yml" || echo "$root/docker-compose.yaml")
    local svc
    svc=$(yq eval -o=json '.' "$compose_file" 2>/dev/null \
      | jq '.services // {} | to_entries | map(select(.value.ports != null))
            | map({name: .key, driver:"http", audience:"user", entry_point:.key,
                   source:"compose-port", confidence:"medium"})' || echo '[]')
    items=$(jq --argjson s "$svc" '. + $s' <<<"$items")
  fi

  # Chat-bot SDK imports → candidate computer-use chat channels.
  # Format: "<grep-alt-pattern>|<channel-name>" (bash 3.2: no assoc arrays).
  for probe in \
    'telegraf|node-telegram-bot-api|python-telegram-bot::telegram' \
    'whatsapp-web|@whiskeysockets/baileys|twilio::whatsapp' \
    'discord\.js|discord\.py::discord'; do
    local pats="${probe%%::*}" cname="${probe##*::}"
    if grep -rqE "($pats)" "$root/src" "$root/app" "$root/package.json" 2>/dev/null; then
      items=$(jq --arg n "$cname" \
        '. + [{name:$n, driver:"computer-use", audience:"external",
               entry_point:"external", source:"bot-sdk", confidence:"low"}]' <<<"$items")
    fi
  done

  # Web-UI config → candidate browser dashboard channel
  for f in next.config.js nuxt.config.js vite.config.ts angular.json; do
    if [[ -f "$root/$f" ]]; then
      items=$(jq '. + [{name:"dashboard", driver:"browser", audience:"user",
             entry_point:"external", source:"web-ui-config", confidence:"low"}]' <<<"$items")
      break
    fi
  done

  echo "$items"
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash skills/x-qa/scripts/tests/scan-channels.sh`
Expected: PASS — `scan-channels: 4 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add skills/x-qa/scripts/lib/scan-helpers.sh skills/x-qa/scripts/tests/scan-channels.sh
git commit -m "feat(x-qa): scan_channels deterministic channel hints"
```

---

### Task 3: `QA_MEMORY.md` capture (`init --memory-md`)

**Files:**
- Modify: `skills/x-qa/scripts/init.sh` (add `--memory-md` arg + write)
- Create: `skills/x-qa/references/qa-memory-schema.md`
- Create: `skills/x-qa/templates/qa-memory.example.md`
- Create: `skills/x-qa/scripts/tests/qa-memory.sh`

- [ ] **Step 1: Write the failing test**

Create `skills/x-qa/scripts/tests/qa-memory.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
INIT="$SKILL_DIR/scripts/init.sh"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
cd "$WORK"; git init -q

cat > profile.json <<'JSON'
{ "schema":1, "version":"1.0.0", "primary_entry_point":"api",
  "entry_points":[{"name":"api","type":"http","auto_managed":true,"primary":true,"verified":false,
    "launch":{"kind":"command","command":"true"},
    "base_url_template":"http://localhost:1","base_url_fallback":"http://localhost:1",
    "health":{"method":"GET","path":"/","expected_status":200}}] }
JSON
printf '# QA Memory — test\n\n## Channels\n\n### api (driver: http)\n' > memory.md

"$INIT" --profile-json profile.json --memory-md memory.md >/dev/null

pass=0; fail=0
[[ -f .x-skills/x-qa/QA_MEMORY.md ]] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: QA_MEMORY.md not written"; }
grep -q "## Channels" .x-skills/x-qa/QA_MEMORY.md && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: content not copied"; }
# QA_MEMORY.md must NOT be gitignored (git-tracked team memory)
! grep -q "QA_MEMORY.md" .gitignore && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: QA_MEMORY.md must not be gitignored"; }

echo "qa-memory: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash skills/x-qa/scripts/tests/qa-memory.sh`
Expected: FAIL — `init.sh` rejects the unknown `--memory-md` arg (exit 2, `Unknown arg`), so `QA_MEMORY.md` is never written.

- [ ] **Step 3: Implement `--memory-md` in `init.sh`**

In `skills/x-qa/scripts/init.sh`, add a variable near the top (after `FORCE=false`, line 12):

```bash
MEMORY_INPUT=""
```

Add a case to the arg loop (alongside `--profile-json` / `--force`):

```bash
    --memory-md) MEMORY_INPUT="$2"; shift 2 ;;
```

After the profile is copied (`cp "$PROFILE_INPUT" "$PROFILE_PATH"`, line 63), add:

```bash
# Optional narrative QA memory — git-tracked team knowledge (per-channel env/config,
# monitoring, db, credentials LOCATION only). Never gitignored.
if [[ -n "$MEMORY_INPUT" ]]; then
  [[ -f "$MEMORY_INPUT" ]] || { echo "✗ x-qa init FAILED" >&2; echo "REASON=--memory-md path not found: $MEMORY_INPUT" >&2; exit 2; }
  cp "$MEMORY_INPUT" "$PROFILE_DIR/QA_MEMORY.md"
fi
```

(The existing gitignore loop only adds `runs/`, `cache/`, `state.local.json`, `.lock` — `QA_MEMORY.md` stays tracked. No change needed there.)

- [ ] **Step 4: Run test to verify it passes**

Run: `bash skills/x-qa/scripts/tests/qa-memory.sh`
Expected: PASS — `qa-memory: 3 passed, 0 failed`

- [ ] **Step 5: Write the schema + template**

Create `skills/x-qa/references/qa-memory-schema.md`:

```markdown
# QA_MEMORY.md Schema

`.x-skills/x-qa/QA_MEMORY.md` is **git-tracked** narrative team memory — the
human-readable "how to QA this project" doc. It complements `profile.json`
(machine config) and the KB (proven cases); it never duplicates profile fields.

The LLM authors it during `init` from interview answers and pipes it to
`init.sh --memory-md`. `run` reads it as planner + runner ground-truth context.

## Required sections

```markdown
# QA Memory — <project>

## Overview
<one paragraph: what the system is, the main user journeys QA cares about>

## Channels
### <channel-name> (driver: <http|browser|computer-use>, audience: <admin|user|external|system>)
- Reach: <base_url, or app + target conversation>
- Env/config: <which .env files + which vars are load-bearing for THIS channel>
- Credentials: <LOCATION ONLY — env var name / vault path / "ask #team". NEVER the secret.>
- Session: <for stateful drivers: how the logged-in session is bootstrapped>
- Notes: <gotchas, rate limits, test-account caveats>

## Test Setup
<how to get the system into a testable state: seed data, migrations, services>

## Monitoring & Observability
<where logs/metrics/traces live; how to watch a request end-to-end during a test>

## Environment & Database
<env files, DB connection, how to seed/reset/inspect the DB>

## Known Gotchas
<flaky areas, ordering constraints, anything a returning QA should know>
```

## Hard rule — credentials

`QA_MEMORY.md` is committed. It records **where** credentials live, never the
secret value — identical to the `profile.json` `auth.token_source` rule
(`env:`/`file:` only). A reviewer seeing a literal token in this file MUST
treat it as a leaked secret to rotate. See `~/.claude/rules/security.md`.
```

Create `skills/x-qa/templates/qa-memory.example.md` filling each section with a realistic two-channel example (an `http` admin-api and a `computer-use` telegram-bot), using `env:ADMIN_TOKEN` / "ask #qa-team" style credential *locations* only.

- [ ] **Step 6: Commit**

```bash
git add skills/x-qa/scripts/init.sh skills/x-qa/references/qa-memory-schema.md \
  skills/x-qa/templates/qa-memory.example.md skills/x-qa/scripts/tests/qa-memory.sh
git commit -m "feat(x-qa): capture git-tracked QA_MEMORY.md at init"
```

---

### Task 4: Driver registry + feature-gate doc

**Files:**
- Create: `skills/x-qa/references/channel-drivers.md`
- Create: `skills/x-qa/scripts/tests/channel-contract.sh` (shared by Tasks 4, 5, 7)

- [ ] **Step 1: Write the failing test**

Create `skills/x-qa/scripts/tests/channel-contract.sh`:

```bash
#!/usr/bin/env bash
# channel-contract.sh — grep-anchored checks that doc contracts contain
# their load-bearing clauses. Cheap guard against silent contract drift.
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
pass=0; fail=0
need() { if grep -qF "$2" "$SKILL_DIR/$1"; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: $1 missing: $2"; fi; }

# channel-drivers.md
need references/channel-drivers.md "computer-use"
need references/channel-drivers.md "feature-gate"
need references/channel-drivers.md "captures every channel"

# init-interview.md (Task 5)
need references/init-interview.md "## Channel Enumeration"
need references/init-interview.md "Monitoring"
need references/init-interview.md "credentials"

# SKILL.md + case-runner-prompts.md guard (Task 7)
need SKILL.md "never executes the repository's own test suites"
need SKILL.md "--channel"
need references/case-runner-prompts.md "MUST NOT run the repository's own test suites"

echo "channel-contract: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash skills/x-qa/scripts/tests/channel-contract.sh`
Expected: FAIL — `references/channel-drivers.md` does not exist; multiple `FAIL:` lines.

- [ ] **Step 3: Create `channel-drivers.md`**

Create `skills/x-qa/references/channel-drivers.md`:

```markdown
# Channel Drivers

A channel's `driver` decides how `run` reaches it.
Onboarding **captures every channel** regardless of driver; execution is
**feature-gated** — a driver runs
only when its required capability is present, otherwise the channel is captured
and skipped with a notice (same pattern as the `type != http` limit in gotcha #12).

| Driver | Reaches | Runner | Capability gate | Status (this plan) |
|---|---|---|---|---|
| `http` | API channels (admin/user/webhook) | `curl` (existing simple/complex runners) | always available | **executes** |
| `browser` | web dashboards / UIs | Playwright MCP (DOM/a11y, deterministic, CI-friendly) | `mcp.playwright` | capture-only (Plan 2) |
| `computer-use` | chat apps (Telegram/WhatsApp), native GUIs | web client → Claude-for-Chrome; desktop app → OS computer-use MCP | a computer-use / Chrome-control MCP | capture-only (Plan 3/4) |

## Why Playwright for dashboards, computer-use for chat

Dashboards run in x-qa's **controlled launch environment** — Playwright MCP's
determinism, headless/CI execution, and low token cost win there. Chat apps
require a **real logged-in session** with no clean DOM/API, so they need the
agentic/vision path (Claude-for-Chrome for web clients, OS computer-use for
desktop apps). See `docs/superpowers/plans/` roadmap for the driver build order.

## Security — agentic drivers

`browser`/`computer-use` drivers operate a real logged-in session with a large
prompt-injection blast radius. They MUST run against a **dedicated test
account**, never a personal one. `QA_MEMORY.md` records the session *location*,
never the secret (`~/.claude/rules/security.md`).

## Feature-gate at run time

`run` resolves the target channel, reads its `driver`, and checks the gate:
- gate satisfied → dispatch the driver's runner;
- gate unsatisfied → emit `CHANNEL_SKIPPED=<name> reason=driver '<driver>' not executable (capability <cap> absent)` and continue.
```

- [ ] **Step 4: Run the relevant part of the test**

Run: `bash skills/x-qa/scripts/tests/channel-contract.sh`
Expected: the three `channel-drivers.md` checks now pass; `init-interview.md`/`SKILL.md`/`case-runner-prompts.md` checks still FAIL (delivered in Tasks 5 & 7). Net: still non-zero — expected until Task 7.

- [ ] **Step 5: Commit**

> Note: `channel-contract.sh` is created here but intentionally stays **red**
> until Tasks 5 and 7 add the `init-interview.md` / `SKILL.md` / runner anchors.
> To keep every commit green, it is committed in **Task 7 Step 5** (once all 9
> anchors pass) — not here. It lives on disk now so Tasks 5/7 can run it.

```bash
git add skills/x-qa/references/channel-drivers.md
git commit -m "feat(x-qa): channel driver registry + feature-gate"
```

---

### Task 5: Expand the `init` interview

**Files:**
- Modify: `skills/x-qa/references/init-interview.md`

- [ ] **Step 1: (Test already exists)** — the `init-interview.md` anchors are asserted by `channel-contract.sh` (Task 4). Confirm they currently fail:

Run: `bash skills/x-qa/scripts/tests/channel-contract.sh 2>&1 | grep init-interview`
Expected: `FAIL: references/init-interview.md missing: ## Channel Enumeration` (and Monitoring, credentials).

- [ ] **Step 2: Add the channel + context sections**

Insert into `skills/x-qa/references/init-interview.md` after the `## Free-form additions` block (line 63) — the new interview phase runs after entry points are settled:

```markdown
## Channel Enumeration

After entry points are settled, enumerate **channels** — every way QA reaches
the system. Seed the question with `scan_channels` hints (multiple ports, bot
SDKs, web-UI configs) AND an x-research semantic pass (see "x-research scan"
below):

> **How is this system driven for testing?** I detected: <scan_channels hints>.
> For each surface, confirm: name, driver (`http` / `browser` / `computer-use`),
> audience (`admin` / `user` / `external` / `system`), and how it's reached.

Per channel, then ask:

> **Reach** — base URL (http/browser), or app + target conversation (chat).
> **Credentials** — where do THIS channel's creds live? `env:<NAME>` / `file:<path>` / "ask team". **Never paste the secret** — it goes in a git-tracked file.
> **Env/config** — which `.env` files and which vars are load-bearing here?
> **Session** (browser/computer-use) — how is the logged-in session bootstrapped (QR/2FA, one-time)?

## Test Setup, Monitoring, Environment, Database

These populate `QA_MEMORY.md` (narrative), not `profile.json`:

> **Test setup** — how do I get the system into a testable state (seed, migrations)?
> **Monitoring** — where are logs/metrics/traces? How do I watch one request end-to-end?
> **Environment** — which env files matter; any required secrets (by location)?
> **Database** — connection, and how to seed / reset / inspect it?

## x-research scan (semantic discovery)

Before the channel question, dispatch a focused x-research pass to enrich the
deterministic `scan_channels` hints with semantic findings (how tests are set
up, where monitoring lives, which env/db setup running requires). Borrow
x-research's dispatch (morph `codebase_search` + a `gemini-agent` reading) —
do NOT invoke the full `/x-research` router (its bootstrap/classification is
redundant here). The bash `scan-helpers.sh` output remains the ground truth for
*entry-point existence* (anti-hallucination, gotcha #4); x-research only adds
the channel/audience/monitoring/env/db semantic layer.

## QA_MEMORY.md authoring

After the interview, author `QA_MEMORY.md` per `references/qa-memory-schema.md`
and persist via `init.sh --memory-md <path>`. In `--non-interactive`, write the
template skeleton with `<!-- TODO: fill -->` markers and `auto_managed: true`.
```

- [ ] **Step 3: Run the contract test**

Run: `bash skills/x-qa/scripts/tests/channel-contract.sh 2>&1 | grep init-interview || echo "init-interview clean"`
Expected: `init-interview clean`

- [ ] **Step 4: Commit**

```bash
git add skills/x-qa/references/init-interview.md
git commit -m "feat(x-qa): channel + monitoring/env/db interview sections"
```

---

### Task 6: `run` channel selection in `classify-intent.sh`

**Files:**
- Modify: `skills/x-qa/scripts/classify-intent.sh`
- Modify: `skills/x-qa/references/intent-detection.md`
- Reuses test: `skills/x-qa/scripts/tests/classify.sh`

- [ ] **Step 1: Write the failing test**

Add a dedicated channel test to the end of `skills/x-qa/scripts/tests/classify.sh`, just before the final `echo` (line 47). This needs a profile with a channel, so build a fresh work dir inside the same script:

```bash
# --- channel selection ---
CH=$(mktemp -d)
ch_out=$( cd "$CH"; git init -q
  mkdir -p .x-skills/x-qa
  cat > .x-skills/x-qa/profile.json <<'JSON'
{ "schema":1,"version":"1.0.0","primary_entry_point":"api",
  "entry_points":[{"name":"api","type":"http","auto_managed":true,"primary":true,"verified":false,
    "launch":{"kind":"command","command":"true"},
    "base_url_template":"http://localhost:1","base_url_fallback":"http://localhost:1",
    "health":{"method":"GET","path":"/","expected_status":200}}],
  "channels":[{"name":"dashboard","driver":"browser","audience":"user","entry_point":"api",
    "base_url_template":"http://localhost:1","base_url_fallback":"http://localhost:1"}] }
JSON
  c1=$("$SKILL_DIR/scripts/classify-intent.sh" "test the avatar feature via dashboard" | jq -r '.resolved.channel')
  c2=$("$SKILL_DIR/scripts/classify-intent.sh" "dashboard" | jq -r '.resolved.channel')
  c3=$("$SKILL_DIR/scripts/classify-intent.sh" "test something via ghostchannel" | jq -r '.resolved.channel')
  [[ "$c1" == "dashboard" ]] && echo "OK c1" || echo "FAIL c1 got=$c1"
  [[ "$c2" == "dashboard" ]] && echo "OK c2" || echo "FAIL c2 got=$c2"
  [[ "$c3" == "null" ]] && echo "OK c3" || echo "FAIL c3 got=$c3"
)
rm -rf "$CH"
echo "$ch_out"
grep -q "FAIL" <<<"$ch_out" && { echo "channel selection FAILED"; exit 1; } || true
```

(Note: keep this block above the existing final `echo "classify smoke…"`.)

- [ ] **Step 2: Run test to verify it fails**

Run: `bash skills/x-qa/scripts/tests/classify.sh`
Expected: FAIL — `.resolved.channel` does not exist (`jq` yields empty/`null` for all, c1/c2 mismatch).

- [ ] **Step 3: Add channel detection to `classify-intent.sh`**

In `skills/x-qa/scripts/classify-intent.sh`, after the big `if/elif` intent block closes (line 55) and **before** the final `jq -n` emit (line 57), add:

```bash
# Channel selection: whole-input exact channel name, or trailing
# "via|using|through|on [the] <name>". Profile-scoped; null when no match.
channel=""
if [[ -f "$PROFILE" ]]; then
  if jq -e --arg n "$trim" '.channels[]? | select(.name==$n)' "$PROFILE" >/dev/null 2>&1; then
    channel="$trim"
  elif [[ "$trim" =~ (via|using|through|on)[[:space:]]+(the[[:space:]]+)?([A-Za-z0-9_-]+)[[:space:]]*$ ]]; then
    cand="${BASH_REMATCH[3]}"
    jq -e --arg n "$cand" '.channels[]? | select(.name==$n)' "$PROFILE" >/dev/null 2>&1 && channel="$cand"
  fi
fi
```

Then add `--arg channel "$channel"` to the `jq -n` invocation (alongside the other `--arg` flags) and add this line inside the `resolved: { … }` object (after `prose:`):

```
       channel:      (if $channel=="" then null else $channel end)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash skills/x-qa/scripts/tests/classify.sh`
Expected: PASS — `OK c1`, `OK c2`, `OK c3`, then `classify smoke: N passed, 0 failed`.

- [ ] **Step 5: Document + commit**

Append to `skills/x-qa/references/intent-detection.md` (after `## Override Flags`):

```markdown
## Channel Selection

`run` can target a specific channel. Two paths, both resolved against
`profile.json.channels[]`:
- **Flag:** `--channel <name>` (explicit override; orchestrator-parsed).
- **Natural language:** trailing `via|using|through|on [the] <name>`, or the
  whole input equal to a channel name. Emitted as `resolved.channel` (null when
  no channel matches). Unknown channel names fall through to `null` — the
  orchestrator then asks which channel, listing `channels[].name`.
```

```bash
git add skills/x-qa/scripts/classify-intent.sh skills/x-qa/references/intent-detection.md \
  skills/x-qa/scripts/tests/classify.sh
git commit -m "feat(x-qa): run channel selection via flag + natural language"
```

---

### Task 7: `run` driver gate + "never run the repo's e2e suite" guard

**Files:**
- Modify: `skills/x-qa/SKILL.md`
- Modify: `skills/x-qa/references/case-runner-prompts.md`
- Reuses test: `skills/x-qa/scripts/tests/channel-contract.sh`

- [ ] **Step 1: Confirm the contract anchors still fail**

Run: `bash skills/x-qa/scripts/tests/channel-contract.sh 2>&1 | grep -E "SKILL.md|case-runner"`
Expected: `FAIL: SKILL.md missing: never`, `FAIL: SKILL.md missing: --channel`, `FAIL: references/case-runner-prompts.md missing: MUST NOT`.

- [ ] **Step 2: Add the `--channel` flag + channel-resolution phase + guard to `SKILL.md`**

In `skills/x-qa/SKILL.md`, add `--channel <name>` to the `run` flags line (line 39), after `--service <name>` context. Then in `## Run Phases`, replace Phase 4 ("Resolve target from intent…") to add channel resolution and the driver gate. Insert after the existing Phase 4 sentence:

```markdown
   - **Channel resolution.** If `intent.json.resolved.channel` (or `--channel`)
     is set, resolve it against `profile.json.channels[]` and pin
     `X_QA_CHANNEL` + `X_QA_DRIVER`. Read the driver's feature-gate per
     `references/channel-drivers.md`:
     - `http` → execute (Phases 8–15 as today, against the channel's `base_url`).
     - `browser` / `computer-use` → if the gating capability is absent, emit
       `CHANNEL_SKIPPED=<name> reason=driver '<driver>' not executable` and stop
       with a clear notice (capture-only in this release). Do NOT fall back to a
       different channel silently.
     - No channel selected → default to the primary entry point's implicit
       `http` channel (back-compat with pre-channels behavior).
```

Add a new subsection under `## Run Phases` (before `## After This Skill`):

```markdown
## Real-QA Contract (MANDATORY)

`run` tests the system the way a QA engineer drives it —
it **never executes the repository's own test suites**. The runner MUST NOT
invoke `npm test`,
`npm run test:e2e`, `pytest`, `playwright test`, `cypress run`, `go test`,
`vitest`, or any project test command. Instead it drives the actual channel:
issue real requests (curl for `http`), adjust fixture/mock data, and mint cases
from `QA_MEMORY.md` + the KB corpus. `launch.command` starts the *service only*
(`references/service-launch.md`); it is never a test command. This holds across
every driver.
```

- [ ] **Step 3: Add the guard to the runner prompts**

In `skills/x-qa/references/case-runner-prompts.md`, add to **both** the Simple Runner `$PROMPT` (after line 20's "Execute exactly ONE HTTP request…") and the Complex Runner prompt, a shared clause:

```markdown
You MUST NOT run the repository's own test suites (`npm test`, `test:e2e`,
`pytest`, `playwright test`, `cypress`, etc.). Drive the live service directly
(real requests, adjusted mock data) like a manual QA engineer. If you find an
existing e2e suite, ignore it — your job is to exercise the actual flow.
```

- [ ] **Step 4: Run the contract test (now fully green)**

Run: `bash skills/x-qa/scripts/tests/channel-contract.sh`
Expected: PASS — `channel-contract: 9 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add skills/x-qa/SKILL.md skills/x-qa/references/case-runner-prompts.md \
  skills/x-qa/scripts/tests/channel-contract.sh
git commit -m "feat(x-qa): run channel driver gate + never-run-repo-suite guard"
```

---

### Task 8: `update` reconciliation for channels + QA_MEMORY.md

**Files:**
- Modify: `skills/x-qa/scripts/update.sh`
- Modify: `skills/x-qa/references/update-diff-rules.md`
- Modify: `skills/x-qa/scripts/tests/channels.sh` (add an update-path assertion)

- [ ] **Step 1: Write the failing test**

Append to `skills/x-qa/scripts/tests/channels.sh`, before the final `echo` line:

```bash
# --- update preserves user-edited channels + warns on stale QA_MEMORY.md ---
UP=$(mktemp -d)
up_out=$( cd "$UP"; git init -q; mkdir -p .x-skills/x-qa
  jq '. + {repo_root:"'"$UP"'"}' "$WORK/valid.json" > .x-skills/x-qa/profile.json
  # reconciled scan drops the dashboard channel; user marked it auto_managed:false
  jq '.channels[1].auto_managed=false' .x-skills/x-qa/profile.json > .x-skills/x-qa/profile.json.tmp \
    && mv .x-skills/x-qa/profile.json.tmp .x-skills/x-qa/profile.json
  jq 'del(.channels[1])' .x-skills/x-qa/profile.json > reconciled.json
  if "$SKILL_DIR/scripts/update.sh" --reconciled-json reconciled.json >/dev/null 2>&1; then
    echo "FAIL upd: dropped a user-edited channel without --allow-overwrite-user-edits"
  else echo "OK upd"; fi
)
rm -rf "$UP"
echo "$up_out"
grep -q "FAIL upd" <<<"$up_out" && fail=$((fail+1)) || pass=$((pass+1))
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash skills/x-qa/scripts/tests/channels.sh`
Expected: FAIL — `update.sh` only guards user-edited `entry_points`, not `channels`, so it overwrites silently and the test reports `FAIL upd`.

- [ ] **Step 3: Extend `update.sh` to guard channels**

In `skills/x-qa/scripts/update.sh`, inside the `if [[ "$ALLOW_OVERWRITE" != true ]]; then` block (after the existing `entry_points` check, line 32), add a parallel channel check:

```bash
  channel_edited_changed=$(jq -n \
    --slurpfile old "$PROFILE_PATH" \
    --slurpfile new "$RECONCILED" \
    "[\$old[0].channels[]? as \$oc | select(\$oc.auto_managed == false) |
      (\$new[0].channels[]? | select(.name == \$oc.name)) as \$nc |
      select((\$nc == null) or ((\$oc | $canon) != (\$nc | $canon)))] | length")
  [[ "$channel_edited_changed" == "0" ]] || { echo "✗ update FAILED REASON=$channel_edited_changed user-edited channels would be changed/removed; use --allow-overwrite-user-edits" >&2; exit 3; }
```

After the profile is written (`echo "$final" > "$PROFILE_PATH"`, line 39), add a staleness warning for the narrative memory:

```bash
MEM="$(dirname "$PROFILE_PATH")/QA_MEMORY.md"
if [[ -f "$MEM" ]] && [[ "$PROFILE_PATH" -nt "$MEM" ]]; then
  echo "WARN=QA_MEMORY.md older than profile; re-run the init interview to refresh narrative memory" >&2
fi
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash skills/x-qa/scripts/tests/channels.sh`
Expected: PASS — `channels: 7 passed, 0 failed`

- [ ] **Step 5: Document + commit**

Append to `skills/x-qa/references/update-diff-rules.md`:

```markdown
## Channels & QA_MEMORY.md

- `channels[]` reconcile by `name`, same ADDED/MISSING/CHANGED/UNCHANGED rules
  as entry points. `auto_managed: false` channels are preserved; `update`
  refuses to change or drop them without `--allow-overwrite-user-edits`.
- `QA_MEMORY.md` is narrative and not auto-reconciled. `update` emits
  `WARN=QA_MEMORY.md older than profile…` when the profile is newer, prompting a
  re-interview. It is never auto-overwritten (it holds human knowledge).
```

```bash
git add skills/x-qa/scripts/update.sh skills/x-qa/references/update-diff-rules.md \
  skills/x-qa/scripts/tests/channels.sh
git commit -m "feat(x-qa): update reconciliation for channels + QA_MEMORY staleness"
```

---

### Task 9: `domain_model` + `obligations[]` in the scope envelope (scout domain-research)

**Files:**
- Modify: `skills/x-qa/references/scout-prompt.md`
- Create: `skills/x-qa/scripts/tests/domain-contract.sh`

- [ ] **Step 1: Write the failing contract test**

Create `skills/x-qa/scripts/tests/domain-contract.sh` with **only** the scout anchors (later tasks append their own anchors to this same file, each commit staying green):

```bash
#!/usr/bin/env bash
# domain-contract.sh — grep-anchored checks that the research-driven generation
# doc contracts contain their load-bearing clauses. Grows across T9/T10/T11/T13;
# each task appends its anchors and keeps this suite green at its own commit.
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
pass=0; fail=0
need() { if grep -qF "$2" "$SKILL_DIR/$1"; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: $1 missing: $2"; fi; }

# --- Task 1: scout-prompt.md domain research ---
need references/scout-prompt.md "## Domain Research"
need references/scout-prompt.md "domain_model"
need references/scout-prompt.md "obligations"
need references/scout-prompt.md "code-first"

echo "domain-contract: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash skills/x-qa/scripts/tests/domain-contract.sh`
Expected: FAIL — four `FAIL: references/scout-prompt.md missing:` lines (the section does not exist yet); non-zero exit.

- [ ] **Step 3: Extend the scope envelope + add the domain-research procedure**

In `skills/x-qa/references/scout-prompt.md`, the Prompt Template's emitted JSON currently ends with `"open_questions"`. Replace the emitted-JSON block (the one anchored by the line `  "open_questions":    ["what is max upload size?"]`) so the envelope also carries `domain_model` and `obligations`:

```
Emit ONLY this JSON to stdout:

{
  "intent": "<echo>",
  "feature_summary": "<one paragraph>",
  "touched_endpoints": ["/api/x", "/api/y"],
  "touched_files":     ["src/a.ts", "src/b.ts"],
  "behaviors":         ["uploads accept jpeg/png", "rejects >2MB"],
  "edge_cases":        ["empty body", "missing auth", "boundary 2MB"],
  "domain_model": {
    "entities": [
      { "name": "avatar",
        "fields": [
          { "name": "size",   "type": "int",  "constraints": ["min:1","max:2097152"] },
          { "name": "format", "type": "enum", "constraints": ["in:jpeg,png"] }
        ] }
    ],
    "invariants": [
      { "id": "owner-only", "rule": "a user may read/replace only their OWN avatar" }
    ],
    "state_machine": {
      "states": ["none","pending","active"],
      "transitions": [
        { "from": "none",   "to": "active", "legal": true,  "trigger": "upload" },
        { "from": "active", "to": "active", "legal": false, "reason": "no re-upload while processing" }
      ]
    }
  },
  "obligations": [
    { "id": "field:avatar.size:max-2mb", "kind": "field",              "ref": "avatar.size",   "severity": "required",    "source": "acceptance" },
    { "id": "inv:owner-only",            "kind": "invariant",          "ref": "owner-only",    "severity": "required",    "source": "domain" },
    { "id": "trans:none->active",        "kind": "transition",         "ref": "none->active",  "severity": "required",    "source": "domain" },
    { "id": "xtrans:active->active",     "kind": "illegal-transition", "ref": "active->active","severity": "required",    "source": "domain" },
    { "id": "fmode:auth:bypass",         "kind": "failure-mode",       "ref": "auth:bypass",   "severity": "recommended", "source": "taxonomy" }
  ],
  "open_questions":    ["what is max upload size?"]
}
```

Then, immediately after the Prompt Template's `Procedure:` numbered list (anchored by the line `4. Cap output: ≤ 20 endpoints, ≤ 40 edge cases.`), insert a new step `5` and a new doc section after the template. First extend the procedure — replace that capping line with:

```
4. Build the domain model (see "## Domain Research" below): entities + field
   constraints + business invariants + the state machine.
5. Enumerate obligations from the domain model AND the failure-mode taxonomy
   (`references/failure-mode-taxonomy.md`). Mark `required` vs `recommended`.
6. Cap output: ≤ 20 endpoints, ≤ 40 edge cases, ≤ 60 obligations.
```

Then add this new section immediately **before** the existing `## Output Path` section (anchored by the line `## Output Path`):

```markdown
## Domain Research

Before enumerating obligations, model the domain — **code-first**:

1. **Read the code** that defines the rules: data models / ORM entities,
   migrations, validators / schema files (zod, pydantic, JSON-Schema, DTOs),
   enum/state definitions, and the handler for each touched endpoint. Use
   `morph codebase_search` for "where is <entity> validated / its state
   machine" and read the hits. This is the source of truth for field
   constraints, invariants, and transitions.
2. **Only if the code does not reveal a rule** (e.g. an external/business
   constraint with no in-repo definition) escalate to one external research
   lane (`perplexity_ask` or a `gemini-agent` reading) — cheapest-viable-first,
   mirroring x-research's own gate. Do NOT open a research session when the code
   already answers the question; that wastes tokens and latency.
3. Emit the findings as the `domain_model` block (entities → fields →
   `constraints[]`; `invariants[]`; `state_machine` with legal/illegal
   `transitions[]`).

## Obligations

An **obligation** is one thing the generated plan MUST cover. Enumerate them
from the domain model and the taxonomy, using this stable id grammar (the
coverage gate, `scripts/coverage-check.sh`, matches on these ids):

| kind | id format | source |
|---|---|---|
| `field` | `field:<entity>.<field>:<constraint-slug>` | each field constraint |
| `invariant` | `inv:<slug>` | each business invariant (asserted on success — the "false case") |
| `transition` | `trans:<from>-><to>` | each legal state transition |
| `illegal-transition` | `xtrans:<from>-><to>` | each illegal transition (must be rejected) |
| `failure-mode` | `fmode:<area>:<mode>` | each applicable taxonomy failure mode |

Mark each `severity: required` (gate-blocking) or `recommended` (reported,
non-blocking). Acceptance-criteria-derived obligations and security-relevant
failure modes are `required`; breadth/nice-to-have probes are `recommended`.
```

Finally, extend the existing `## Plan Generator Contract` list. After its last bullet (anchored by `- Surface \`open_questions[]\` in the run output as warnings.`), add:

```markdown
- Emit ≥1 `test_cases[]` entry covering **every `severity: required` obligation**
  in `obligations[]`, tagging each case with the obligation id(s) it satisfies
  via `covers: [...]` (see `references/test-plan-schema.md`). The coverage gate
  (`scripts/coverage-check.sh`) refuses a plan that leaves any required
  obligation uncovered.
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash skills/x-qa/scripts/tests/domain-contract.sh`
Expected: PASS — `domain-contract: 4 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add skills/x-qa/references/scout-prompt.md skills/x-qa/scripts/tests/domain-contract.sh
git commit -m "feat(x-qa): scout domain-research → domain_model + obligations in scope"
```

---

### Task 10: `failure-mode-taxonomy.md` (failure-probing + semantic/"false case")

**Files:**
- Create: `skills/x-qa/references/failure-mode-taxonomy.md`
- Modify: `skills/x-qa/scripts/tests/domain-contract.sh` (append taxonomy anchors)

- [ ] **Step 1: Add the failing anchors**

Append to `skills/x-qa/scripts/tests/domain-contract.sh`, immediately **before** the final `echo "domain-contract: …"` line:

```bash
# --- Task 2: failure-mode-taxonomy.md ---
need references/failure-mode-taxonomy.md "## A. Failure-Probing Modes"
need references/failure-mode-taxonomy.md "## B. Semantic Correctness"
need references/failure-mode-taxonomy.md "false case"
need references/failure-mode-taxonomy.md "fmode:"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash skills/x-qa/scripts/tests/domain-contract.sh`
Expected: FAIL — four new `FAIL: references/failure-mode-taxonomy.md missing:` lines (file does not exist); non-zero exit. (The Task-9 scout anchors still pass.)

- [ ] **Step 3: Create the taxonomy**

Create `skills/x-qa/references/failure-mode-taxonomy.md`:

```markdown
# Failure-Mode Taxonomy

The checklist a real QA reasons through. The scout (`scout-prompt.md`) picks the
modes that *apply to this domain* and emits them as `fmode:<area>:<mode>`
obligations; the planner writes a case per obligation; `coverage-check.sh`
enforces it. Two halves — probe for crashes **and** probe for wrong answers.

## A. Failure-Probing Modes (provoke an error or rejection)

| Area | Mode | Apply when | Example obligation id |
|---|---|---|---|
| input | boundary | any numeric/size/length limit | `fmode:upload:boundary` |
| input | null-empty-missing | any optional/required field | `fmode:profile:null-empty-missing` |
| input | type-format | typed/format-constrained field | `fmode:profile:type-format` |
| input | malformed-payload | any JSON/multipart body | `fmode:api:malformed-payload` |
| input | oversize | any size-bounded resource | `fmode:upload:oversize` |
| authz | auth-missing-expired | any authenticated route | `fmode:auth:missing-expired` |
| authz | bypass | any owner/role-scoped resource | `fmode:auth:bypass` |
| writes | idempotency-duplicate | non-idempotent POST/charge | `fmode:order:idempotency-duplicate` |
| writes | concurrency-race | shared mutable resource | `fmode:wallet:concurrency-race` |
| writes | ordering | order-dependent operations | `fmode:ledger:ordering` |
| writes | partial-failure-rollback | multi-step write / transaction | `fmode:checkout:partial-failure-rollback` |
| reads | pagination-cursor | list/cursor endpoints | `fmode:feed:pagination-cursor` |
| infra | rate-limit | rate-limited endpoint | `fmode:api:rate-limit` |
| security | injection | any value reaching a query/shell/path | `fmode:search:injection` |
| encoding | unicode-emoji | free-text fields | `fmode:comment:unicode-emoji` |
| time | timezone-dst | date/time logic | `fmode:booking:timezone-dst` |
| money | rounding-precision | monetary/decimal fields | `fmode:invoice:rounding-precision` |
| state | illegal-transition | any state machine | covered by `xtrans:<from>-><to>` |

## B. Semantic Correctness (the "false case": 200 but WRONG)

A real QA does not stop at "it returned 200". The most dangerous production bug
is the **false case** — a success response carrying a wrong result. Every
`invariant` obligation (`inv:<slug>`) is verified here, by asserting on the
**success** response and/or the resulting state, not by provoking an error.

| Check | What to assert on the SUCCESS path |
|---|---|
| invariant-holds | the business rule still holds (`inv:<slug>`) — e.g. balance never negative |
| side-effect-verified | the write actually happened (re-read / DB row changed), not just acked |
| computed-field-correct | derived/computed values are right (totals, tax, counts) |
| referential-integrity | related rows are consistent after the op (no orphans) |
| no-data-leak | the response exposes only the caller's data (ties to `inv:owner-only`) |
| idempotent-result-equal | replaying an idempotent op yields the same result, not a duplicate |

## How the scout uses this

1. For each entity/endpoint in the domain model, walk column A and keep the
   modes that *apply* (skip `money` if there is no monetary field, etc.).
2. For each invariant, add a column-B `inv:` obligation asserted on success.
3. Mark security/authz and acceptance-derived modes `required`; breadth probes
   `recommended`.

Over-enumeration is waste; under-enumeration misses prod bugs. When unsure
whether a mode applies, include it as `recommended` (reported, non-blocking).
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash skills/x-qa/scripts/tests/domain-contract.sh`
Expected: PASS — `domain-contract: 8 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add skills/x-qa/references/failure-mode-taxonomy.md skills/x-qa/scripts/tests/domain-contract.sh
git commit -m "feat(x-qa): failure-mode taxonomy (probing + semantic false-case)"
```

---

### Task 11: `covers[]` field + strengthened Required Coverage

**Files:**
- Modify: `skills/x-qa/references/test-plan-schema.md`
- Modify: `skills/x-qa/templates/test-plan.example.yml`
- Modify: `skills/x-qa/scripts/tests/domain-contract.sh` (append schema anchors)

- [ ] **Step 1: Add the failing anchors**

Append to `skills/x-qa/scripts/tests/domain-contract.sh`, immediately **before** the final `echo "domain-contract: …"` line:

```bash
# --- Task 3: test-plan-schema.md covers[] + obligation-gated coverage ---
need references/test-plan-schema.md "covers"
need references/test-plan-schema.md "Coverage Obligations"
need references/test-plan-schema.md "assert the outcome"
```

Also add a parse-the-example assertion just below those `need` lines (so the example actually carries machine-readable `covers:` tags, not just prose):

```bash
# the example plan must carry parseable covers[] tags
if [[ "$(yq eval -o=json '[.test_cases[].covers[]?] | length' "$SKILL_DIR/templates/test-plan.example.yml")" -ge 3 ]]; then
  pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: example test plan has <3 covers[] tags"; fi
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash skills/x-qa/scripts/tests/domain-contract.sh`
Expected: FAIL — `test-plan-schema.md missing: covers` / `Coverage Obligations` / `assert the outcome`, plus `example test plan has <3 covers[] tags`; non-zero exit.

- [ ] **Step 3: Add `covers[]` to the TestCase schema**

In `skills/x-qa/references/test-plan-schema.md`, in the `## TestCase` table, add a row immediately **after** the `parallel_group` row (anchored by the cell `| \`parallel_group\` | string | no |`):

```markdown
| `covers` | string[] | no | Obligation ids this case satisfies (`field:…`/`inv:…`/`trans:…`/`xtrans:…`/`fmode:…` per `references/scout-prompt.md § Obligations`). Read by `scripts/coverage-check.sh`. A case may cover several; an obligation may be covered by several. |
```

- [ ] **Step 4: Strengthen Required Coverage**

In `skills/x-qa/references/test-plan-schema.md`, replace the entire `## Required Coverage (planner contract)` section (anchored by its body line `Every generated plan MUST include at least one case in EACH category present in the feature surface. Planner refuses to emit a plan missing \`happy\` for any reachable endpoint.`) with:

```markdown
## Required Coverage (planner contract — obligation-gated)

Coverage is enforced against `scope.json.obligations[]`, not category presence:

1. **Every `severity: required` obligation** is satisfied by ≥1 case whose
   `covers[]` lists that obligation id. `scripts/coverage-check.sh` refuses the
   plan otherwise (Run Phase 7.5).
2. **Happy/edge cases assert the outcome, not just the status.** For every
   `inv:<slug>` obligation, a case MUST assert the invariant on the *success*
   response or resulting state (a `body-jsonpath`/`custom` assertion) — catching
   the "false case" (200 with a wrong result). A case that only asserts
   `status == 2xx` does NOT satisfy an `inv:` obligation.
3. **Still emit ≥1 `happy` case per reachable endpoint** (unchanged baseline).
4. `recommended` obligations are encouraged but never block the gate.
```

- [ ] **Step 5: Tag the example plan**

In `skills/x-qa/templates/test-plan.example.yml`, add `covers:` tags to the existing cases so the example demonstrates the contract (and satisfies the Step-1 parse assertion). Add a `covers` line under each case's `category`:
- `tc-001` (health happy) → `covers: ["trans:none->active"]`
- `tc-002` (auth) → `covers: ["fmode:auth:missing-expired"]`
- `tc-003` (upload happy) → `covers: ["inv:owner-only", "field:avatar.size:max-2mb"]`

And add the invariant-asserting assertion to `tc-003` (demonstrating "assert the outcome", not just status 201) — append to its `assertions:` list:

```yaml
      - { kind: body-jsonpath, expr: "$.owner_id", op: eq, value: "${FIXTURE_USER}" }
```

- [ ] **Step 6: Run test to verify it passes**

Run: `bash skills/x-qa/scripts/tests/domain-contract.sh`
Expected: PASS — `domain-contract: 12 passed, 0 failed`

Also confirm the example still parses as a plan:
Run: `yq eval -o=json '.test_cases | length' skills/x-qa/templates/test-plan.example.yml`
Expected: `3`

- [ ] **Step 7: Commit**

```bash
git add skills/x-qa/references/test-plan-schema.md skills/x-qa/templates/test-plan.example.yml \
  skills/x-qa/scripts/tests/domain-contract.sh
git commit -m "feat(x-qa): covers[] field + obligation-gated Required Coverage"
```

---

### Task 12: `coverage-check.sh` obligation-coverage gate + golden test

**Files:**
- Create: `skills/x-qa/scripts/coverage-check.sh`
- Create: `skills/x-qa/scripts/tests/coverage-check.sh`

- [ ] **Step 1: Write the failing golden test**

Create `skills/x-qa/scripts/tests/coverage-check.sh`:

```bash
#!/usr/bin/env bash
# coverage-check.sh (test) — golden pass/fail fixtures for the coverage gate.
# Proves the gate (a) passes a plan covering every required obligation and
# (b) fails a plan that drops one, naming the uncovered id.
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
CC="$SKILL_DIR/scripts/coverage-check.sh"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT; cd "$WORK"

cat > scope.json <<'JSON'
{ "obligations":[
  {"id":"field:avatar.size:max-2mb","kind":"field","severity":"required"},
  {"id":"inv:owner-only","kind":"invariant","severity":"required"},
  {"id":"trans:none->active","kind":"transition","severity":"required"},
  {"id":"xtrans:active->active","kind":"illegal-transition","severity":"required"},
  {"id":"fmode:auth:bypass","kind":"failure-mode","severity":"recommended"}
] }
JSON

# complete: covers all REQUIRED (the recommended fmode is intentionally omitted)
cat > complete.yml <<'YML'
feature: avatar
entry_point: api
test_cases:
  - id: tc-happy
    covers: ["trans:none->active", "inv:owner-only"]
  - id: tc-oversize
    covers: ["field:avatar.size:max-2mb"]
  - id: tc-illegal
    covers: ["xtrans:active->active"]
YML

# incomplete: drops xtrans:active->active
cat > incomplete.yml <<'YML'
feature: avatar
entry_point: api
test_cases:
  - id: tc-happy
    covers: ["trans:none->active", "inv:owner-only"]
  - id: tc-oversize
    covers: ["field:avatar.size:max-2mb"]
YML

pass=0; fail=0

# (1) complete plan → exit 0, verdict pass
out=$("$CC" --scope scope.json --plan complete.yml) && rc=0 || rc=$?
if [[ "$rc" -eq 0 ]] && jq -e '.verdict=="pass"' <<<"$out" >/dev/null; then
  pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: complete should pass (rc=$rc): $out"; fi

# (2) incomplete plan → non-zero, uncovered names the dropped illegal transition
out=$("$CC" --scope scope.json --plan incomplete.yml) && rc=0 || rc=$?
if [[ "$rc" -ne 0 ]] && jq -e '.uncovered | index("xtrans:active->active")' <<<"$out" >/dev/null; then
  pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: incomplete should fail naming xtrans (rc=$rc): $out"; fi

# (3) recommended-only gap does NOT block (complete plan omits fmode:auth:bypass yet passes)
if jq -e '.verdict=="pass"' <<<"$("$CC" --scope scope.json --plan complete.yml)" >/dev/null; then
  pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: recommended gap must not block"; fi

echo "coverage-check: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash skills/x-qa/scripts/tests/coverage-check.sh`
Expected: FAIL — `coverage-check.sh: No such file or directory` (the gate script does not exist yet); non-zero exit.

- [ ] **Step 3: Implement the gate**

Create `skills/x-qa/scripts/coverage-check.sh`:

```bash
#!/usr/bin/env bash
# coverage-check.sh — enforce that every `required` obligation in scope.json is
# covered by ≥1 test case's covers[] in the plan. The LLM enumerates obligations
# (judgment); this script enforces coverage (determinism). Plan may be YAML/JSON.
set -euo pipefail

SCOPE="" PLAN=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --scope) SCOPE="$2"; shift 2 ;;
    --plan)  PLAN="$2";  shift 2 ;;
    *) echo "COVERAGE_ERROR=unknown arg: $1" >&2; exit 2 ;;
  esac
done
[[ -f "$SCOPE" ]] || { echo "COVERAGE_ERROR=scope not found: $SCOPE" >&2; exit 2; }
[[ -f "$PLAN"  ]] || { echo "COVERAGE_ERROR=plan not found: $PLAN"  >&2; exit 2; }

# Normalize the plan to JSON (yq handles YAML or JSON input).
plan_json=$(yq eval -o=json '.' "$PLAN" 2>/dev/null) \
  || { echo "COVERAGE_ERROR=plan not parseable: $PLAN" >&2; exit 2; }

required=$(jq -c '[.obligations[]? | select(.severity=="required") | .id] | unique' "$SCOPE")
covered=$(jq -c  '[.test_cases[]?.covers[]?] | unique' <<<"$plan_json")
uncovered=$(jq -cn --argjson req "$required" --argjson cov "$covered" '$req - $cov')

req_n=$(jq 'length' <<<"$required")
unc_n=$(jq 'length' <<<"$uncovered")
cov_n=$(( req_n - unc_n ))

jq -n --argjson required "$required" --argjson uncovered "$uncovered" \
  --argjson rn "$req_n" --argjson cn "$cov_n" \
  '{ required:$rn, covered:$cn, uncovered:$uncovered,
     verdict:(if ($uncovered|length)==0 then "pass" else "fail" end) }'

[[ "$unc_n" -eq 0 ]]
```

Make it executable:

```bash
chmod +x skills/x-qa/scripts/coverage-check.sh
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash skills/x-qa/scripts/tests/coverage-check.sh`
Expected: PASS — `coverage-check: 3 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add skills/x-qa/scripts/coverage-check.sh skills/x-qa/scripts/tests/coverage-check.sh
git commit -m "feat(x-qa): coverage-check.sh obligation-coverage gate + golden test"
```

---

### Task 13: Wire domain-research + coverage gate into Run Phases

**Files:**
- Modify: `skills/x-qa/SKILL.md`
- Modify: `skills/x-qa/scripts/tests/domain-contract.sh` (append SKILL.md anchors)

- [ ] **Step 1: Add the failing anchors**

Append to `skills/x-qa/scripts/tests/domain-contract.sh`, immediately **before** the final `echo "domain-contract: …"` line:

```bash
# --- Task 5: SKILL.md wiring ---
need SKILL.md "Domain Research"
need SKILL.md "coverage-check.sh"
need SKILL.md "--allow-coverage-gaps"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash skills/x-qa/scripts/tests/domain-contract.sh`
Expected: FAIL — three `FAIL: SKILL.md missing:` lines (`Domain Research`, `coverage-check.sh`, `--allow-coverage-gaps`); non-zero exit. (Tasks 9–11 anchors still pass.)

- [ ] **Step 3: Wire the scout domain-research note into Phase 5**

In `skills/x-qa/SKILL.md`, in `## Run Phases`, the Phase-5 sentence ends with `On invalid JSON / timeout, use whole-profile coverage and warn.` Append to that Phase-5 bullet:

```markdown
 The scout also performs **Domain Research** (`references/scout-prompt.md § Domain Research`) — code-first modeling of entities/constraints/invariants/transitions — and emits `domain_model` + `obligations[]` into `scope.json`. When intent is not scout-eligible (`branch`/`pr`/`service`), `obligations[]` is absent and Phase 7.5 is a no-op.
```

- [ ] **Step 4: Insert Phase 7.5 (coverage gate) + the flag + envelope counters**

In `skills/x-qa/SKILL.md`, insert a new phase between Phase 7 (anchored by its line starting `7. Plan: read \`--plan <path>\` if given`) and Phase 8 (anchored by `8. Launch service via \`scripts/launch-entry-point.sh\``):

```markdown
7.5. **Coverage gate** (skipped when `scope.json` has no `obligations[]`, or on `--allow-coverage-gaps`). Run `scripts/coverage-check.sh --scope <run-dir>/scope.json --plan <plan>`. If `verdict == fail`, refuse the plan with `PHASE=plan` and `REASON=uncovered required obligations: <ids>` — the planner must add cases for the named obligations and re-emit. `--allow-coverage-gaps` downgrades the refusal to a warning (uncovered ids surfaced in `QA_REPORT.md` notes). Fold `COVERAGE_REQUIRED` / `COVERAGE_COVERED` / `COVERAGE_UNCOVERED` into the run envelope.
```

Add the flag to the `run` flags line (anchored by `--no-kb\` (skip corpus + baseline + auto-promote)`) — append within that same flags sentence:

```
, `--allow-coverage-gaps` (downgrade the coverage gate to a warning)
```

Add the envelope counters to the **Success** envelope block, immediately after the `KB_PROMOTE_STATUS=ok|disabled|error` line:

```
COVERAGE_REQUIRED=<n>   # required obligations from scope.json
COVERAGE_COVERED=<n>    # required obligations satisfied by a case
COVERAGE_UNCOVERED=<csv> # uncovered required obligation ids ("" when none)
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bash skills/x-qa/scripts/tests/domain-contract.sh`
Expected: PASS — `domain-contract: 15 passed, 0 failed`

- [ ] **Step 6: Commit**

```bash
git add skills/x-qa/SKILL.md skills/x-qa/scripts/tests/domain-contract.sh
git commit -m "feat(x-qa): wire domain-research + coverage gate into run phases"
```

---

## Arc C — Exploratory QA Team (Tasks 14–18)

> **Why a third arc.** Arc B makes the *planner* enumerate what must be covered and gates it deterministically; Arc C makes a **team of curious worker agents** try to *break* each obligation and surface the ones the scout missed. The deterministic case tier (Arcs A/B) stays the reproducible, KB-promotable, CI-safe regression suite; Arc C adds an exploratory bug-hunt on top of it — the way a real QA team runs scripted regression **and** exploratory sessions. Arc C reuses Arc B's `obligations[]` as the worker-assignment unit, the taxonomy's "false case" (column B) as the primary hunt target (a single-shot HTTP runner structurally cannot chase a 200-but-wrong result; a curious agent can), and the `x-bugfix` route as the destination for confirmed findings. A confirmed finding is minted as a **red repro stub** (a currently-failing case) for x-bugfix — it is **not** written into the green KB corpus; it earns a KB regression slot only once the fix lands and it goes green via the existing auto-promote path.
>
> **Locked design decisions** (from review): (1) **Mode** — the exploratory tier runs by default on a **local/dev** run and is **auto-skipped in CI** (reuses the existing CI predicate from Phase 11); `--no-explore` opts out locally, `--explore` forces it in CI. (2) **Budget** — a **bounded swarm**: one worker per obligation-cluster, **≤6 concurrent**, each with a **fixed ≤15-probe budget**. (3) **Coordination** — a **native Claude team + shared bug-board** when team orchestration is pinned, **degrading to background `Agent` fanout** otherwise (lifts gotcha #13 as a documented capability upgrade).

### Arc C anchoring & ordering (read before executing)

Arc C executes after Arcs A and B and uses **textual anchors only**. Its run-phase wiring (Task 18) inserts a new **Phase 13.5** between deterministic flaky-retry (Phase 13) and teardown (Phase 14) — the service launched in Phase 8 is still up. Arc C never edits files Arcs A/B create; its SKILL.md anchors live in sections Arcs A/B already finalized (`## Capability Routing`, `## Run Envelope`, `## Run Phases`, the `run` flags line). The combined Arc-C tests join the suite in Task 19 (the renumbered finalize).

### Arc C obligation/finding contract (single source of truth — referenced by Tasks 14–18)

A **finding** is one suspected defect a worker surfaced. Each finding object on the bug-board:

`{ "id": <slug>, "cluster": <cluster-id>, "channel": <name|"default">, "obligation": <obligation-id|"none">, "endpoint": <path>, "failure_class": <enum>, "severity": "blocker"|"major"|"minor", "evidence": { "request": {...}, "response": {...}, "expected": <string>, "observed": <string> }, "status": "suspected"|"confirmed"|"rejected", "signature": <dedup-key> }`

- `failure_class` ∈ { `crash`, `error-leak`, `false-case`, `authz-bypass`, `state-corruption`, `contract-mismatch` } — the *kind* of bug, distinct from the taxonomy *mode* that provoked it.
- `signature` = `<channel>|<endpoint>|<obligation>|<failure_class>` — the dedup key (Task 16).
- `obligation: "none"` marks a finding the scout's `obligations[]` did **not** anticipate — the curiosity payoff. Task 17 mints these into new obligation ids so coverage grows next run.
- A worker NEVER self-confirms: it emits `status: "suspected"`. Triage (Task 17) independently flips to `confirmed`/`rejected`.

---

### Task 14: `cluster-partition.sh` — obligation → worker assignment

**Files:**
- Create: `skills/x-qa/scripts/explore/cluster-partition.sh`
- Create: `skills/x-qa/scripts/tests/cluster-partition.sh`

- [ ] **Step 1: Write the failing golden test**

Create `skills/x-qa/scripts/tests/cluster-partition.sh`:

```bash
#!/usr/bin/env bash
# cluster-partition.sh (test) — golden partition of obligations into ≤N cohesive
# clusters. Proves: cluster count is bounded, every obligation lands in exactly
# one cluster (no loss/dup), each cluster is well-formed, and it is deterministic.
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
CP="$SKILL_DIR/scripts/explore/cluster-partition.sh"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT; cd "$WORK"

cat > scope.json <<'JSON'
{ "obligations":[
  {"id":"field:avatar.size:max-2mb","kind":"field","ref":"avatar.size","severity":"required"},
  {"id":"inv:owner-only","kind":"invariant","ref":"owner-only","severity":"required"},
  {"id":"trans:none->active","kind":"transition","ref":"none->active","severity":"required"},
  {"id":"xtrans:active->active","kind":"illegal-transition","ref":"active->active","severity":"required"},
  {"id":"fmode:auth:bypass","kind":"failure-mode","ref":"auth:bypass","severity":"recommended"},
  {"id":"fmode:upload:oversize","kind":"failure-mode","ref":"upload:oversize","severity":"recommended"},
  {"id":"inv:balance-nonneg","kind":"invariant","ref":"balance-nonneg","severity":"required"}
] }
JSON

pass=0; fail=0
out=$("$CP" --scope scope.json --max-workers 3)

n=$(jq '.clusters | length' <<<"$out")
[[ "$n" -le 3 && "$n" -ge 1 ]] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: cluster count $n not in 1..3"; }

total=$(jq '[.clusters[].obligations[]] | length' <<<"$out")
[[ "$total" -eq 7 ]] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: partitioned $total/7 obligations"; }

uniq=$(jq '[.clusters[].obligations[].id] | unique | length' <<<"$out")
[[ "$uniq" -eq 7 ]] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: $uniq unique ids (obligation duped across clusters)"; }

jq -e 'all(.clusters[]; has("id") and has("channel") and has("obligations"))' <<<"$out" >/dev/null \
  && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: cluster missing id/channel/obligations"; }

out2=$("$CP" --scope scope.json --max-workers 3)
[[ "$out" == "$out2" ]] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: non-deterministic partition"; }

echo "cluster-partition: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash skills/x-qa/scripts/tests/cluster-partition.sh`
Expected: FAIL — `cluster-partition.sh: No such file or directory` (the partitioner does not exist yet); non-zero exit.

- [ ] **Step 3: Implement the partitioner**

Create `skills/x-qa/scripts/explore/cluster-partition.sh`:

```bash
#!/usr/bin/env bash
# cluster-partition.sh — deterministically partition scope.json.obligations[]
# into ≤ --max-workers cohesive clusters (one exploratory worker per cluster).
# Obligations are grouped by "topic" (the entity/area they belong to) so a worker
# owns a coherent slice; topics are then bin-packed round-robin into the cap.
# bash 3.2 + jq only (no assoc arrays). Deterministic: jq `unique` sorts.
set -euo pipefail

SCOPE="" MAXW=6 CHANNEL="default"
while [[ $# -gt 0 ]]; do case "$1" in
  --scope)       SCOPE="$2";   shift 2 ;;
  --max-workers) MAXW="$2";    shift 2 ;;
  --channel)     CHANNEL="$2"; shift 2 ;;
  *) echo "CLUSTER_ERROR=unknown arg: $1" >&2; exit 2 ;;
esac; done
[[ -f "$SCOPE" ]] || { echo "CLUSTER_ERROR=scope not found: $SCOPE" >&2; exit 2; }

jq --argjson maxw "$MAXW" --arg channel "$CHANNEL" '
  # topic = the cohesive area an obligation belongs to
  def topic:
    .id as $i
    | if   ($i|startswith("field:"))  then ($i|ltrimstr("field:")|split(".")[0])
      elif ($i|startswith("inv:"))    then "invariant"
      elif ($i|startswith("trans:")) or ($i|startswith("xtrans:")) then "state"
      elif ($i|startswith("fmode:"))  then ($i|ltrimstr("fmode:")|split(":")[0])
      else "misc" end;
  [ .obligations[]? | . + {topic: topic} ]          as $obs0
  | ([ $obs0[].topic ] | unique)                    as $topics   # sorted ⇒ deterministic
  | ([ ($topics|length), $maxw ] | min)             as $nbins
  # bind each obligation's bin via a captured topic var — jq's `index()` evaluates
  # its arg against the piped-in array, so `.topic` must be hoisted out first
  # (else `$topics|index(.topic)` indexes the array with the string "topic").
  | [ $obs0[] | (.topic) as $t | . + {bin: (($topics|index($t)) % $nbins)} ] as $obs
  | [ range(0; $nbins) as $b
      | { id: ("cluster-" + ($b|tostring)),
          channel: $channel,
          obligations: [ $obs[] | select(.bin == $b) | del(.bin) ] }
      | select(.obligations | length > 0)
      | . + { topics: ([.obligations[].topic] | unique) } ]
  | { clusters: . }
' "$SCOPE"
```

Make it executable:

```bash
chmod +x skills/x-qa/scripts/explore/cluster-partition.sh
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash skills/x-qa/scripts/tests/cluster-partition.sh`
Expected: PASS — `cluster-partition: 5 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add skills/x-qa/scripts/explore/cluster-partition.sh skills/x-qa/scripts/tests/cluster-partition.sh
git commit -m "feat(x-qa): cluster-partition.sh obligation→worker assignment"
```

---

### Task 15: Exploratory worker prompt + team coordination contracts

**Files:**
- Create: `skills/x-qa/references/explorer-prompts.md`
- Create: `skills/x-qa/references/explore-team.md`
- Create: `skills/x-qa/scripts/tests/explore-contract.sh` (shared by Tasks 15 & 18)

- [ ] **Step 1: Write the failing contract test**

Create `skills/x-qa/scripts/tests/explore-contract.sh` (grows in Task 18; each task keeps it green at its own commit — committed in Task 18 Step 5 once all anchors pass, lives on disk now so Task 18 can run it):

```bash
#!/usr/bin/env bash
# explore-contract.sh — grep-anchored checks that the exploratory-team contracts
# contain their load-bearing clauses. Cheap guard against silent contract drift.
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
pass=0; fail=0
need() { if grep -qF "$2" "$SKILL_DIR/$1"; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: $1 missing: $2"; fi; }

# --- Task 15: explorer-prompts.md (the curious worker) ---
need references/explorer-prompts.md "false case"
need references/explorer-prompts.md "probe budget"
need references/explorer-prompts.md "MUST NOT run the repository's own test suites"
need references/explorer-prompts.md "bug-board"

# --- Task 15: explore-team.md (coordination + gate) ---
need references/explore-team.md "shared bug-board"
need references/explore-team.md "native Claude team"
need references/explore-team.md "background"
need references/explore-team.md "skipped in CI"
need references/explore-team.md "≤6"

# --- Task 18: SKILL.md wiring (filled by Task 18) ---
need SKILL.md "--no-explore"
need SKILL.md "Exploratory bug-hunt"
need SKILL.md "EXPLORE_CONFIRMED"
need SKILL.md "X_QA_EXPLORE_MODE"

echo "explore-contract: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash skills/x-qa/scripts/tests/explore-contract.sh`
Expected: FAIL — neither doc exists and the SKILL.md anchors are absent; many `FAIL:` lines. The Task-18 SKILL.md anchors stay red until Task 18.

- [ ] **Step 3: Create `explorer-prompts.md`**

Create `skills/x-qa/references/explorer-prompts.md`:

```markdown
# Exploratory Worker Prompts

Each exploratory worker owns ONE obligation-cluster
(`scripts/explore/cluster-partition.sh`) and hunts for bugs within it like a
curious manual QA engineer — it does NOT execute a single pre-authored case. It
generates its own probes, drives the **live launched service**, and posts
findings to the shared bug-board.

## Worker dispatch

Workers are the pinned `X_QA_EXPLORER` agent (`oh-my-claudecode:qa-tester` when
`plugin.omc` is pinned, else `Explore`), model `sonnet`. One worker per cluster,
**≤6 concurrent** (`--max-bg`-bounded). Native-team mode shares a live bug-board
task list; bg-fanout mode appends to `<run-dir>/explore/board.jsonl`.

## Worker prompt

```
You are an exploratory QA engineer. You own this slice of the system and your
job is to FIND BUGS in it — not to confirm it works.

Channel / base URL: <BASE_URL>
Your cluster: <CLUSTER_ID>
Obligations you own (try to BREAK each one):
  <OBLIGATIONS_JSON>   # ids + their domain rule from scope.json.domain_model

Probe budget: at most <PROBE_BUDGET> requests (default 15). Spend them where the
risk is highest. Stop early once you stop finding new behavior.

How a real QA hunts (use BOTH halves of references/failure-mode-taxonomy.md):
1. Failure-probing (column A): provoke errors/rejections — boundaries, missing
   auth, malformed payloads, illegal state transitions.
2. The false case (column B): the most dangerous prod bug is a 200 carrying a
   WRONG result. For every invariant you own, drive the SUCCESS path and then
   VERIFY the outcome — re-read state, check side effects, confirm the caller
   only sees their own data, recompute totals. A 200 is NOT a pass.
3. Curiosity: if the code/domain hints at a rule your obligations DON'T list,
   probe it anyway and file it as a novel finding (obligation: "none").

You MUST NOT run the repository's own test suites (`npm test`, `test:e2e`,
`pytest`, `playwright test`, `cypress`, etc.). Drive the live service directly
like a manual QA engineer.

For every suspected defect, append ONE finding object to the bug-board
(schema: plan § "Arc C obligation/finding contract"):
  { "id","cluster","channel","obligation","endpoint","failure_class",
    "severity","evidence":{"request","response","expected","observed"},
    "status":"suspected",
    "signature":"<channel>|<endpoint>|<obligation>|<failure_class>" }

Do NOT mark a finding "confirmed" — triage verifies it independently.
Output: append findings to the board; emit a one-line summary of probes spent.
```

## What a worker must NOT do

- Do not author or run the repo's e2e suite (same guard as the deterministic runner).
- Do not exceed the **probe budget** — over-probing is waste; report and stop.
- Do not self-confirm findings — that is triage's job (`references/triage-verify.md`).
```

- [ ] **Step 4: Create `explore-team.md`**

Create `skills/x-qa/references/explore-team.md`:

```markdown
# Exploratory QA Team — Coordination

The exploratory tier is a **team of curious workers** that hunts bugs in the live
service after the deterministic cases have run. It is the execution-layer
counterpart to Arc B: Arc B enumerates obligations; this team tries to break them
and surfaces the ones the scout missed.

## When it runs (mode: default-local, **skipped in CI**)

- Runs **by default on a local/dev run**.
- Is **skipped in CI** — reuses the Phase-11 CI predicate
  (`[[ -z "$CI" && -z "$GITHUB_ACTIONS" && -z "$BUILDKITE" && -z "$GITLAB_CI" ]]`).
- `--no-explore` opts out locally; `--explore` forces it even in CI.
- Skipped with a notice when the service was not launched (`--no-launch`) or when
  there are no obligations AND no reachable endpoints to cluster.

## Coordination (capability-gated)

| Mode | When | Mechanism |
|---|---|---|
| **native Claude team** (preferred) | team orchestration pinned (`plugin.omc`) | A **shared bug-board** task list (TeamCreate + a task per cluster). Workers claim a cluster, post findings live, and can see peers' findings — no duplicate hunting. |
| **background fanout** (fallback) | team orchestration absent | One **background** `Agent` per cluster (existing bg-dispatch), each appending to `<run-dir>/explore/board.jsonl`. No live cross-worker awareness; dedup happens at merge. |

Bootstrap pins `X_QA_EXPLORE_MODE` (`team`|`bg-fanout`) and `X_QA_EXPLORER`
(subagent_type). This lifts gotcha #13 ("no nested team") as a documented
capability upgrade — the fallback keeps Claude-only mode working.

## Bounded swarm (cost guard)

- **One worker per obligation-cluster**, **≤6 concurrent**.
- Each worker has a **fixed probe budget** (≤15 requests; see
  `references/explorer-prompts.md`).
- Clusters come from `scripts/explore/cluster-partition.sh --max-workers 6`
  (deterministic; partitions `scope.json.obligations[]`, optionally × channel).
- When `obligations[]` is absent (`branch`/`pr`/`service` intent), cluster by
  reachable endpoints instead; if neither exists, skip.

## Flow

1. Partition obligations → clusters (`cluster-partition.sh`).
2. Dispatch ≤6 workers (team or bg-fanout) → findings on the bug-board.
3. Dedup the board by signature (`scripts/explore/finding-merge.sh`).
4. **Triage** each unique finding independently (`references/triage-verify.md`) —
   only `confirmed` findings survive.
5. Mint a **red repro stub** per confirmed finding
   (`scripts/explore/finding-to-case.sh`) → the `x-bugfix` route (+ report). A
   repro is red/failing, so it is **NOT** KB-promoted; it becomes a regression
   case only after the fix lands and it goes green (existing auto-promote path).
6. Fold counters into the run envelope (`EXPLORE_*`). `EXPLORE_CONFIRMED` is
   counted from the triaged set (step 4), not from the pre-triage merge.
```

- [ ] **Step 5: Run the relevant part of the test**

Run: `bash skills/x-qa/scripts/tests/explore-contract.sh 2>&1 | grep -E "explorer-prompts|explore-team" || echo "explore docs clean"`
Expected: `explore docs clean` (the nine doc anchors pass; the four SKILL.md anchors still FAIL — delivered in Task 18).

- [ ] **Step 6: Commit**

```bash
git add skills/x-qa/references/explorer-prompts.md skills/x-qa/references/explore-team.md
git commit -m "feat(x-qa): exploratory worker prompt + team coordination contracts"
```

---

### Task 16: `finding-merge.sh` — dedup the shared bug-board

**Files:**
- Create: `skills/x-qa/scripts/explore/finding-merge.sh`
- Create: `skills/x-qa/scripts/tests/finding-merge.sh`

- [ ] **Step 1: Write the failing golden test**

Create `skills/x-qa/scripts/tests/finding-merge.sh`:

```bash
#!/usr/bin/env bash
# finding-merge.sh (test) — golden dedup of the bug-board. Proves duplicate
# signatures collapse to one (keeping the highest severity) and novel findings
# (obligation:"none") are counted.
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
FM="$SKILL_DIR/scripts/explore/finding-merge.sh"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT; cd "$WORK"

cat > board.jsonl <<'JSONL'
{"id":"f1","signature":"default|/api/avatar|inv:owner-only|authz-bypass","obligation":"inv:owner-only","failure_class":"authz-bypass","severity":"major","status":"confirmed"}
{"id":"f2","signature":"default|/api/avatar|inv:owner-only|authz-bypass","obligation":"inv:owner-only","failure_class":"authz-bypass","severity":"blocker","status":"confirmed"}
{"id":"f3","signature":"default|/api/avatar|none|false-case","obligation":"none","failure_class":"false-case","severity":"major","status":"confirmed"}
{"id":"f4","signature":"default|/api/avatar|fmode:upload:oversize|crash","obligation":"fmode:upload:oversize","failure_class":"crash","severity":"minor","status":"rejected"}
JSONL

pass=0; fail=0
out=$("$FM" --board board.jsonl)

[[ "$(jq '.total'  <<<"$out")" -eq 4 ]] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: total != 4"; }
[[ "$(jq '.unique' <<<"$out")" -eq 3 ]] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: unique != 3 (dup not merged)"; }
jq -e '.findings[] | select(.signature|endswith("authz-bypass")) | select(.severity=="blocker")' <<<"$out" >/dev/null \
  && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: dedup did not keep highest severity"; }
[[ "$(jq '.novel'  <<<"$out")" -eq 1 ]] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: novel != 1"; }

echo "finding-merge: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash skills/x-qa/scripts/tests/finding-merge.sh`
Expected: FAIL — `finding-merge.sh: No such file or directory`; non-zero exit.

- [ ] **Step 3: Implement the merge**

Create `skills/x-qa/scripts/explore/finding-merge.sh`:

```bash
#!/usr/bin/env bash
# finding-merge.sh — dedup the exploratory bug-board (one finding JSON per line)
# by signature, keeping the highest-severity instance of each. Emits the unique
# set plus counts the orchestrator folds into the run envelope.
set -euo pipefail

BOARD=""
while [[ $# -gt 0 ]]; do case "$1" in
  --board) BOARD="$2"; shift 2 ;;
  *) echo "MERGE_ERROR=unknown arg: $1" >&2; exit 2 ;;
esac; done
[[ -f "$BOARD" ]] || { echo "MERGE_ERROR=board not found: $BOARD" >&2; exit 2; }

jq -s '
  def rank: {"blocker":3,"major":2,"minor":1}[.] // 0;
  ( map(select(type=="object")) )                           as $all
  | ( $all | group_by(.signature) | map( sort_by(.severity|rank) | last ) ) as $uniq
  | { findings:  $uniq,
      total:     ($all  | length),
      unique:    ($uniq | length),
      confirmed: ([ $uniq[] | select(.status=="confirmed") ] | length),
      novel:     ([ $uniq[] | select(.obligation=="none")  ] | length) }
' "$BOARD"
```

Make it executable:

```bash
chmod +x skills/x-qa/scripts/explore/finding-merge.sh
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash skills/x-qa/scripts/tests/finding-merge.sh`
Expected: PASS — `finding-merge: 4 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add skills/x-qa/scripts/explore/finding-merge.sh skills/x-qa/scripts/tests/finding-merge.sh
git commit -m "feat(x-qa): finding-merge.sh dedup the exploratory bug-board"
```

---

### Task 17: `finding-to-case.sh` + triage/verify gate

**Files:**
- Create: `skills/x-qa/scripts/explore/finding-to-case.sh`
- Create: `skills/x-qa/references/triage-verify.md`
- Create: `skills/x-qa/scripts/tests/finding-to-case.sh`

Depends on `scripts/coverage-check.sh` (Arc B, Task 12) — the test proves a minted case actually satisfies the obligation it covers.

- [ ] **Step 1: Write the failing golden test**

Create `skills/x-qa/scripts/tests/finding-to-case.sh`:

```bash
#!/usr/bin/env bash
# finding-to-case.sh (test) — a confirmed finding mints a red repro stub that
# the coverage gate accepts for its obligation; a novel finding mints a new
# obligation id. Also asserts the triage gate doc exists.
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
MINT="$SKILL_DIR/scripts/explore/finding-to-case.sh"
CC="$SKILL_DIR/scripts/coverage-check.sh"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT; cd "$WORK"
pass=0; fail=0

grep -qF "independently verify" "$SKILL_DIR/references/triage-verify.md" \
  && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: triage-verify.md missing gate clause"; }

# (1) a finding tied to a known obligation mints a case covering it
cat > f1.json <<'JSON'
{"id":"f1","endpoint":"/api/avatar","obligation":"inv:owner-only","failure_class":"authz-bypass","severity":"blocker","status":"confirmed","evidence":{"request":{"method":"GET"},"expected":"403","observed":"200 with other user's avatar"}}
JSON
case_yaml=$("$MINT" --finding f1.json)
{ echo "feature: x"; echo "entry_point: api"; echo "test_cases:"; echo "$case_yaml" | sed 's/^/  /'; } > plan.yml
cat > scope.json <<'JSON'
{ "obligations":[ {"id":"inv:owner-only","severity":"required"} ] }
JSON
if "$CC" --scope scope.json --plan plan.yml | jq -e '.verdict=="pass"' >/dev/null; then
  pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: minted case does not satisfy its obligation"; fi

# (2) a novel finding (obligation:"none") mints a NEW obligation id on stderr
cat > f2.json <<'JSON'
{"id":"f2","endpoint":"/api/orders","obligation":"none","failure_class":"false-case","severity":"major","status":"confirmed","evidence":{"expected":"total=20","observed":"total=18"}}
JSON
minted=$("$MINT" --finding f2.json 2>&1 >/dev/null | grep MINTED_OBLIGATION || true)
[[ -n "$minted" ]] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: novel finding did not mint an obligation"; }

echo "finding-to-case: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash skills/x-qa/scripts/tests/finding-to-case.sh`
Expected: FAIL — `triage-verify.md` missing and `finding-to-case.sh: No such file or directory`; non-zero exit.

- [ ] **Step 3: Implement the minter**

Create `skills/x-qa/scripts/explore/finding-to-case.sh`:

```bash
#!/usr/bin/env bash
# finding-to-case.sh — mint a YAML **repro stub** (a red, currently-failing case)
# from a confirmed finding, to hand to x-bugfix. It is NOT promoted to the KB now
# (the KB is the green corpus); it becomes a regression case only after the fix
# lands and it goes green via the existing auto-promote path. Novel findings
# (obligation:"none") also mint a new obligation id (printed to stderr) so the
# scout's coverage grows next run. Reads one finding JSON via --finding or stdin.
set -euo pipefail

FINDING=""
while [[ $# -gt 0 ]]; do case "$1" in
  --finding) FINDING="$2"; shift 2 ;;
  *) echo "MINT_ERROR=unknown arg: $1" >&2; exit 2 ;;
esac; done
src=$( [[ -n "$FINDING" ]] && cat "$FINDING" || cat )

# the obligation this case covers — minted for novel findings
covers=$(jq -r '
  def slug: gsub("[^a-zA-Z0-9]+";"-") | ltrimstr("-") | rtrimstr("-") | ascii_downcase;
  if (.obligation == "none") or (.obligation == null)
  then "fmode:" + ((.endpoint // "x")|slug) + ":" + ((.failure_class // "bug")|slug)
  else .obligation end' <<<"$src")

if jq -e '(.obligation == "none") or (.obligation == null)' <<<"$src" >/dev/null; then
  echo "MINTED_OBLIGATION=$covers" >&2
fi

jq -c --arg covers "$covers" '
  { id:            ("explore-" + (.id // "x")),
    feature:       "exploratory",
    category:      "error",
    complexity:    "complex",
    origin:        "explore",
    covers:        [$covers],
    failure_class: (.failure_class // "bug"),
    severity:      (.severity // "major"),
    request:       ((.evidence.request // {}) + { path: (.endpoint // "/") }),  # carry full repro (method/headers/body) from evidence
    assertions:    [ { kind: "note",
                       expr: ("expected: " + (.evidence.expected // "")
                              + " | observed: " + (.evidence.observed // "")) } ] }
' <<<"$src" | yq -p=json -o=yaml '[.]'
```

Make it executable:

```bash
chmod +x skills/x-qa/scripts/explore/finding-to-case.sh
```

- [ ] **Step 4: Create the triage/verify gate doc**

Create `skills/x-qa/references/triage-verify.md`:

```markdown
# Triage & Adversarial Verification

Curiosity generates noise: a worker may flag intended behavior as a defect. A
finding becomes a reported bug ONLY after an independent verify pass — triage
never trusts the worker that raised it.

## The gate

For each unique finding on the merged board, dispatch a fresh verifier (a
different agent instance than the one that found it) to **independently verify**
the defect by reproducing it against the live service:

- Re-run the minimal repro from `evidence.request`.
- Confirm `observed` actually contradicts `expected` and the documented domain
  rule / invariant — not a misread of intended behavior.
- For a `false-case`, re-read the resulting state to confirm the wrong result
  persisted (not a stale read).

Verdict:
- reproduced + genuinely wrong → set `status: confirmed`.
- behaves as intended / cannot reproduce → set `status: rejected` (with reason).

Only `confirmed` findings are minted into cases (`scripts/explore/finding-to-case.sh`)
and surfaced in `QA_REPORT.md`. **Default to `rejected` when uncertain** — a false
bug report costs more team trust than a missed minor edge.

## Why a separate pass

Same rationale as the repo's reviewer/verifier separation (`~/.claude/CLAUDE.md`
"Keep authoring and review as separate passes"): the agent that hunted a bug is
biased toward believing it. A second, adversarial set of eyes filters false
positives before they reach the report.
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bash skills/x-qa/scripts/tests/finding-to-case.sh`
Expected: PASS — `finding-to-case: 3 passed, 0 failed`

- [ ] **Step 6: Commit**

```bash
git add skills/x-qa/scripts/explore/finding-to-case.sh skills/x-qa/references/triage-verify.md \
  skills/x-qa/scripts/tests/finding-to-case.sh
git commit -m "feat(x-qa): mint cases from confirmed findings + triage/verify gate"
```

---

### Task 18: Wire the exploratory phase into Run Phases + Capability Routing + envelope

**Files:**
- Modify: `skills/x-qa/SKILL.md`
- Reuses test: `skills/x-qa/scripts/tests/explore-contract.sh`

- [ ] **Step 1: Confirm the SKILL.md anchors still fail**

Run: `bash skills/x-qa/scripts/tests/explore-contract.sh 2>&1 | grep "SKILL.md"`
Expected: `FAIL: SKILL.md missing: --no-explore`, `…Exploratory bug-hunt`, `…EXPLORE_CONFIRMED`, `…X_QA_EXPLORE_MODE`.

- [ ] **Step 2: Add the `--no-explore`/`--explore` flags**

In `skills/x-qa/SKILL.md`, append to the `run` flags line — Arc B (Task 13) left it ending with `` `--allow-coverage-gaps` (downgrade the coverage gate to a warning) ``. Append within that same sentence:

```
, `--no-explore` (skip the exploratory bug-hunt) / `--explore` (force it even in CI)
```

- [ ] **Step 3: Add the Exploratory Team Routing block + bootstrap pin**

In `skills/x-qa/SKILL.md`, after the `## Capability Routing` table's note paragraph (anchored by `always reference the pinned env var.`), add:

```markdown
### Exploratory Team Routing (Arc C)

| Pinned | `X_QA_EXPLORE_MODE` | `X_QA_EXPLORER` |
|---|---|---|
| team orchestration (`plugin.omc`) | `team` (shared bug-board) | `oh-my-claudecode:qa-tester` (sonnet) |
| otherwise | `bg-fanout` (background `Agent`) | `Explore` (sonnet) |

Bootstrap pins `X_QA_EXPLORE_MODE` and `X_QA_EXPLORER` for Phase 13.5. See
`references/explore-team.md` (mode gate, bounded swarm) and
`references/explorer-prompts.md` (worker prompt).
```

In the `## Bootstrap (MANDATORY)` step 5 (runner-pair pin), append a sentence:

```markdown
   Also pin `X_QA_EXPLORE_MODE` (`team` when team orchestration / `plugin.omc` is pinned, else `bg-fanout`) and `X_QA_EXPLORER` (the exploratory worker subagent) per the Exploratory Team Routing table.
```

- [ ] **Step 4: Insert Phase 13.5 + envelope counters**

In `## Run Phases`, insert a new phase between Phase 13 (anchored by `13. Retry flaky inline up to \`--retry-flaky\`.`) and Phase 14 (anchored by `14. Teardown via launch entry's \`launch.teardown\``):

```markdown
13.5. **Exploratory bug-hunt (team)** — *default on a local run; **skipped in CI**; `--no-explore` opts out, `--explore` forces it.* Gate on the Phase-11 CI predicate. Requires the service to be up (skip if Phase 8 was skipped). When `scope.json.obligations[]` is present, partition it into ≤6 clusters (`scripts/explore/cluster-partition.sh --max-workers 6`); otherwise cluster by reachable endpoints (skip if neither). Dispatch one **Exploratory Worker** per cluster (`references/explorer-prompts.md`) via `X_QA_EXPLORE_MODE` (native team + shared bug-board, or background fanout — `references/explore-team.md`), each bounded to a ≤15-probe budget, writing to `<run-dir>/explore/board.jsonl`. Then dedup by signature (`scripts/explore/finding-merge.sh`), **triage** each unique finding independently (`references/triage-verify.md`), and mint a **red repro stub** per `confirmed` finding (`scripts/explore/finding-to-case.sh`) for the `x-bugfix` route + the report. **Do NOT KB-promote these** — the KB is the green corpus and Phase 16 auto-promotes only green cases; a repro stub becomes a regression case only after the fix lands and it goes green (via the existing auto-promote path). Count `EXPLORE_CONFIRMED` from the **triaged** set (this step), NOT from `finding-merge.sh` output (which runs pre-triage, when every finding is still `suspected`). Fold `EXPLORE_*` counters into the envelope.
```

Add the envelope counters to the **Success** block, immediately after Arc B's `COVERAGE_UNCOVERED=<csv> # uncovered required obligation ids ("" when none)` line:

```
EXPLORE_RAN=true|false        # false when skipped (CI / --no-explore / no service)
EXPLORE_FINDINGS=<n>          # unique suspected findings on the bug-board
EXPLORE_CONFIRMED=<n>         # findings that survived triage
EXPLORE_CASES_MINTED=<n>      # confirmed findings minted into kb cases
EXPLORE_OBLIGATIONS_ADDED=<n> # novel obligations minted from "none" findings
```

In `## After This Skill`, after the existing `On \`fail\`: surface offer to route into \`/x-skills:x-bugfix\`…` line, add:

```markdown
Confirmed exploratory findings (`EXPLORE_CONFIRMED > 0`) are also offered to `/x-skills:x-bugfix`, each carrying its minted case as the reproduction.
```

- [ ] **Step 5: Run the contract test (now fully green) + commit**

Run: `bash skills/x-qa/scripts/tests/explore-contract.sh`
Expected: PASS — `explore-contract: 13 passed, 0 failed`

```bash
git add skills/x-qa/SKILL.md skills/x-qa/scripts/tests/explore-contract.sh
git commit -m "feat(x-qa): wire exploratory bug-hunt phase + routing + envelope"
```

---


### Task 19: Gotchas, full combined suite, single version bump

**Files:**
- Modify: `skills/x-qa/gotchas.md`
- Modify: `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `package.json`

- [ ] **Step 1: Add channel gotchas (Arc A)**

Append to `skills/x-qa/gotchas.md` a `## Channels` section covering: (a) capture-vs-execute — non-`http` drivers are captured at init but skipped at run until their MCP is wired; (b) agentic-driver blast radius — use a dedicated test account; (c) channel `entry_point: external` has no launch/teardown — `run` must not try to launch it; (d) `--channel` selecting a non-executable driver yields `CHANNEL_SKIPPED`, not a failure.

- [ ] **Step 2: Add research-driven generation gotchas (Arc B)**

Append to `skills/x-qa/gotchas.md` a `## Research-Driven Generation` section covering: (a) **code-first** — domain research reads models/validators first; an external research lane fires only when the code doesn't reveal a rule (cost guard); (b) **obligations are the gate, not categories** — `coverage-check.sh` enforces `required` obligation ids, so a plan can have a `happy` case yet still be refused for a missing `xtrans:`/`inv:` obligation; (c) **the false case** — an `inv:` obligation needs an assertion on the *success* response (200-with-wrong-result), not just `status==2xx`; a case asserting only status does NOT satisfy it; (d) `domain_model` is **ephemeral in the run-dir** (not KB-promoted yet — see Roadmap); (e) `--allow-coverage-gaps` exists for spikes/legacy surfaces but uncovered required obligations then surface as `QA_REPORT.md` warnings — do not make it the default.

- [ ] **Step 2.5: Add exploratory-team gotchas (Arc C) + update gotcha #13**

First **rewrite gotcha #13** (`No nested OMC team. v1 fanout is bg-dispatch only.`) — it is now lifted: change it to record that the exploratory tier (Phase 13.5) uses a native Claude team + shared bug-board when team orchestration is pinned and degrades to background `Agent` fanout otherwise; the deterministic case fanout (Phase 11) remains bg-dispatch.

Then append to `skills/x-qa/gotchas.md` a `## Exploratory QA Team` section covering: (a) **default-local, skipped-in-CI** — the bug-hunt runs on a dev machine but is skipped under `CI`/`GITHUB_ACTIONS`/etc.; CI stays deterministic-only; `--explore` forces it, `--no-explore` disables it; (b) **bounded swarm** — ≤6 workers, ≤15 probes each; "do everything to find bugs" is budget-capped on purpose (gotcha #7 quota still applies); (c) **workers never self-confirm** — a finding is `suspected` until triage (`references/triage-verify.md`) independently reproduces it; default-reject on uncertainty to keep false-positive noise down; (d) **novel findings grow coverage** — a finding with `obligation:"none"` mints a fresh `fmode:` obligation id (`finding-to-case.sh`) so next run's coverage gate enforces it; (e) **needs a live service** — Phase 13.5 is skipped when Phase 8 (launch) was skipped (`--no-launch`/external `--service`); (f) **dedup is by signature** — two workers hitting the same `<channel>|<endpoint>|<obligation>|<failure_class>` collapse to one finding (highest severity wins); (g) **minted cases are RED repro stubs** — a confirmed finding mints a *failing* case for `x-bugfix`, never auto-promoted into the green KB corpus (it earns a regression slot only after the fix lands and goes green); and `EXPLORE_CONFIRMED` is counted *after* triage, not from the pre-triage `finding-merge.sh` output (every finding is `suspected` at merge time).

- [ ] **Step 3: Run the FULL combined suite**

Run each and confirm all PASS:

```bash
for t in smoke classify channels scan-channels qa-memory channel-contract \
         domain-contract coverage-check cluster-partition explore-contract \
         finding-merge finding-to-case verdict topo kb-smoke gap-analyze \
         precondition-chain precondition-cycle writeback-history; do
  echo "== $t =="; bash "skills/x-qa/scripts/tests/$t.sh" || { echo "SUITE FAIL at $t"; break; }
done
```

Expected: every harness prints `… passed, 0 failed` (or its existing success line); no `SUITE FAIL`.

- [ ] **Step 4: Verify templates + example plan self-coverage**

Profile template still validates:

Run: `bash skills/x-qa/scripts/doctor.sh --template-mode skills/x-qa/templates/profile.example.json`
Expected: `✓ doctor PASS`

Example test plan covers the example obligations the scout doc advertises:

```bash
cat > /tmp/xqa-ex-scope.json <<'JSON'
{ "obligations":[
  {"id":"inv:owner-only","severity":"required"},
  {"id":"field:avatar.size:max-2mb","severity":"required"},
  {"id":"trans:none->active","severity":"required"}
] }
JSON
bash skills/x-qa/scripts/coverage-check.sh --scope /tmp/xqa-ex-scope.json \
  --plan skills/x-qa/templates/test-plan.example.yml; rm -f /tmp/xqa-ex-scope.json
```

Expected: JSON with `"verdict": "pass"`, exit 0 (the example's `covers[]` tags from Task 11 satisfy these three).

- [ ] **Step 5: Bump version once (per `CLAUDE.md` release workflow)**

Bump the three manifests together to the next MINOR (feature) version — read each file's current `version` at execution time, increment minor, set patch to 0. This is the **only** version bump in the plan (all three arcs ship under it):
- `.claude-plugin/plugin.json` → `"version"`
- `.claude-plugin/marketplace.json` → the x-skills `skills` entry `"version"`
- `package.json` → `"version"`

- [ ] **Step 6: Commit**

```bash
git add skills/x-qa/gotchas.md .claude-plugin/plugin.json .claude-plugin/marketplace.json package.json
git commit -m "chore(release): x-qa real-QA overhaul (channels + research-driven generation) + version bump"
```

---

## Self-Review

- **Spec coverage — Arc A (channels):** (#A init→x-research scan) Task 5 x-research scan step + Task 2 deterministic hints. (#B questions: monitoring/creds/env/db) Task 5 sections + Task 3 memory schema. (#C md memory file) Task 3 `QA_MEMORY.md`. (#D real-QA, never repo suite) Task 7 guard + runner clause. (Channels concept) Tasks 1/4/6/7. (computer-use chat) captured via Task 1 schema + Task 4 registry; executed in follow-on plans. ✓
- **Spec coverage — Arc B (generation):** (*research first → domain model*) Task 9 scout Domain Research, code-first. (*generate complete cases from that*) Task 11 obligation-gated Required Coverage + Task 9 Plan Generator Contract. (*all edge + happy*) Task 10 taxonomy column A + Task 11 baseline happy-per-endpoint. (*error OR false case in production*) Task 10 column A (errors) **and** column B (false case: 200-but-wrong) + Task 11 invariant-on-success rule. (*think like a real QA*) Task 12 turns the checklist into an enforced gate. ✓
- **Spec coverage — Arc C (exploratory team):** (*claude team workers, not main-session only*) Task 18 Phase 13.5 dispatches one worker per cluster via `X_QA_EXPLORE_MODE` (native team / bg-fanout), lifting gotcha #13. (*each worker tests its own aspect*) Task 14 `cluster-partition.sh` gives each worker a disjoint obligation slice. (*generate more cases / curiosity*) Task 15 worker prompt hunts beyond its listed obligations (novel `obligation:"none"` findings) instead of executing one pre-authored case. (*do everything to find bugs — false case*) Task 15 prompt drives the success path and verifies the outcome (200-but-wrong), the thing single-shot runners can't. (*don't flood with false positives*) Task 17 triage independently verifies before report. (*bugs become actionable*) Task 17 mints each confirmed finding into a **red repro stub** for the `x-bugfix` route (NOT KB-promoted — the KB stays green; a fixed-and-green case earns the regression slot later). (*bounded cost*) Tasks 15/18 cap ≤6 workers × ≤15 probes; Task 18 skips in CI. ✓
- **Placeholder scan:** every code step contains runnable bash; doc steps contain the literal markdown to insert; no "TBD"/"handle edge cases"/"add validation". Arc C's three scripts (`cluster-partition.sh`, `finding-merge.sh`, `finding-to-case.sh`) were scratch-run against their golden fixtures before landing in the spec. ✓
- **Type consistency:** Arc A — driver enum `http|browser|computer-use`, audience `admin|user|external|system`, `resolved.channel`, `X_QA_CHANNEL`/`X_QA_DRIVER`, `CHANNEL_SKIPPED=` used identically across Tasks 1/4/6/7. Arc B — obligation id grammar (`field:`/`inv:`/`trans:`/`xtrans:`/`fmode:`), `severity: required|recommended`, `covers[]`, and `coverage-check.sh`'s `--scope`/`--plan` + `{required,covered,uncovered,verdict}` output used identically across Tasks 9/10/11/12/13. Arc C — the finding object (`failure_class` enum, `signature` = `<channel>|<endpoint>|<obligation>|<failure_class>`, `status: suspected|confirmed|rejected`), `X_QA_EXPLORE_MODE`/`X_QA_EXPLORER`, `EXPLORE_*` envelope keys used identically across Tasks 14/15/16/17/18; minted `covers[]` reuse Arc B's id grammar so `coverage-check.sh` accepts them unchanged. ✓
- **Always-green commits:** Arc A — `channel-contract.sh` is created in Task 4 but committed in Task 7 Step 5 (once all 9 anchors pass). Arc B — `domain-contract.sh` grows by appending anchors in the same task that writes the matching content (red→write→green→commit each time); `coverage-check.sh`'s golden test ships green inside Task 12. Arc C — `explore-contract.sh` is created in Task 15 but committed in Task 18 Step 5 (once all 13 anchors pass, mirroring Arc A); the three golden tests (`cluster-partition`/`finding-merge`/`finding-to-case`) ship green inside their own task. No test is committed red. ✓
- **Cross-arc anchor safety:** Arc A runs first against the pristine tree (line-number anchors valid). Arc B's textual anchors (`On invalid JSON / timeout…`, `7. Plan: read --plan…`, `8. Launch service…`, `KB_PROMOTE_STATUS=ok|disabled|error`, `--no-kb (skip corpus…)`, the `parallel_group` row, the Required-Coverage body, the scout `open_questions` / `Cap output` / `Output Path` anchors) all live in sections Arc A does not edit. Arc C's textual anchors (`always reference the pinned env var.`, the `## Bootstrap` step 5, Phase-13 `Retry flaky inline…`, Phase-14 `Teardown via launch entry's…`, the Arc-B `COVERAGE_UNCOVERED=` envelope line, the `run` flags line ending in `--allow-coverage-gaps`, the `On \`fail\`: surface offer…` line) live in sections Arcs A/B finalized but do not later re-edit — verified against the edit order. Single version bump in Task 19. ✓

---

## Roadmap — follow-on plans (out of scope here)

**Arc A — driver execution** (build in this order, risk-ascending):

1. **Plan: `browser` driver execution (Playwright MCP).** Activate the reserved `ai_action`/`ai_assertion` step modes + `FallbackResponse` tier (`references/test-plan-schema.md`, `references/fallback-contract.md`). Add a `dashboard` runner that drives Playwright MCP, flip `tier_2_enabled`, gate on `mcp.playwright` (present in session today).
2. **Plan: `computer-use` chat-web driver (Claude for Chrome).** Drive web.telegram.org / web.whatsapp.com via the real logged-in browser session; dedicated test account; session bootstrap doc.
3. **Plan: `computer-use` chat-desktop driver (OS computer-use MCP).** Drive Telegram/WhatsApp Desktop. **Blocked** until a computer-use/desktop-control MCP is added to the pinned capability set (none today).

**Arc B — generation depth:**

4. **Promote `domain_model` to the KB.** Cache the researched model under `kb/` keyed by endpoint-set so reruns skip re-research. Inherits the KB's staleness/curation machinery (`kb-curation.md`) — defer until the per-run model proves stable.
5. **Obligation history in the gap analyzer.** Feed `obligations[]` into `gap-analyze.sh` so an obligation that regressed (was covered, now isn't) is flagged like a `recent-failure` signature — closing the loop between research, coverage, and run history.
6. **Stronger scout for domain research / obligation enumeration.** *(Addresses a review finding this plan does NOT close.)* The scout currently enumerates `obligations[]` on `X_QA_SIMPLE_RUNNER` (gemini-flash by default) — but obligation enumeration is judgment-heavy and sits upstream of the *entire* coverage gate **and** of Arc C's worker assignments, so a thin enumeration weakens everything downstream. Pin a distinct `X_QA_SCOUT_RUNNER` (sonnet/opus) for the Domain Research dispatch (Phase 5 / Task 9), separate from the per-case `X_QA_SIMPLE_RUNNER`. Arc C's novel-finding minting *mitigates* a weak enumeration (curious workers recover rules the scout missed) but does not replace it — this is the proper fix.

**Arc C — exploratory depth:**

7. **Within-run re-scout from novel findings.** Today `EXPLORE_OBLIGATIONS_ADDED` (minted from `obligation:"none"` findings) only enriches the report + next run. Feed them back into the *same* run's coverage gate so a curiosity-discovered rule is enforced immediately — needs a re-plan loop guard to stay bounded.
8. **Exploratory workers on `browser`/`computer-use` channels.** Once the Arc-A `browser` (Playwright MCP) and `computer-use` (chat) drivers execute (Roadmap items 1–3), let exploratory workers drive *those* channels too — a curious QA hunting a dashboard or a chat bot, not just an HTTP API. Reuses the same cluster/board/triage/mint machinery; only the worker's driver changes.
9. **Bug-board persistence + cross-run dedup.** Persist confirmed-finding signatures so a bug found last run isn't re-reported as novel this run (mirrors the KB baseline staleness machinery).

Each follow-on reuses the captured `channels[]` + `QA_MEMORY.md` (Arc A), the `obligations[]` + `covers[]` contract (Arc B), and the finding/bug-board contract (Arc C) — no schema churn.
