# x-worktree-isolate v0.2 — Singleton Awareness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend x-worktree-isolate so that, in addition to compose container/port/volume collisions, it also detects and disables **stateful singletons** (Slack/Discord/Telegram listeners, webhook receivers, schedulers, polling workers, host crontabs) that should not run concurrently across parallel worktrees.

**Architecture:** Three-tier detection plugged into the existing two-phase `init` + `apply` model. Tier 1 = compose-service heuristics (token-name + image), disabled via `compose.override.yml` (`deploy.replicas: 0` or `profiles: [singleton]` gating). Tier 2 = env-flag heuristics (source + .env scan with guardrails), disabled via `<VAR>=false` lines in `.env.worktree`. Tier 3 = host-tier artifacts (crontab, systemd unit files) — detect-and-warn only; `apply` hard-blocks until acknowledged. Per-worktree opt-back-in via new CLI subcommands (`features` / `enable` / `disable` / `ack-host-singletons`) writing a gitignored `feature-overrides.local.json`. Schema bump 1→2 with hard rejection of v1 profiles (apply prints exact migration command).

**Key architectural invariant — single-pass compose override rendering.** `apply.sh` builds `compose.override.yml` by merging two sources of per-service modifications into a SINGLE `dict[service] → {container_name?, ports?, deploy?, profiles?}` before YAML serialization. The two sources are: (a) `services_to_strip[]` (existing v0.1 fields — `container_name: !reset null` + `ports: !override`), and (b) `singletons[]` where `kind=="compose-service"` (new v0.2 fields — `deploy.replicas: 0` OR `profiles: [singleton]`). The renderer NEVER emits two top-level `services.<svc>:` blocks for the same service. `render-singletons.py` returns the v0.2 contributions as structured JSON (a dict keyed by service name), and `apply.sh`'s existing render-python block does the merge.

**Tech Stack:** Bash 3.2+, Python 3 (PyYAML, stdlib only otherwise), git, docker compose ≥ 2.24. No new runtime dependencies.

---

## File Structure

**Create:**
- `skills/x-worktree-isolate/scripts/singleton-patterns.py` — Pattern table (token names, library imports, scheduler signatures, host-artifact globs).
- `skills/x-worktree-isolate/scripts/detect-singletons.py` — Scanner across all three tiers; emits `singletons[]` candidate JSON.
- `skills/x-worktree-isolate/scripts/render-singletons.py` — Renders compose `services.<svc>.deploy.replicas: 0` (or profile-gate) + env-flag lines, applying feature-overrides.
- `skills/x-worktree-isolate/scripts/feature-overrides.sh` — Bash wrappers for `features` / `enable` / `disable` / `ack-host-singletons` subcommands.
- `skills/x-worktree-isolate/references/singleton-patterns.md` — Documents what we detect and why.
- `skills/x-worktree-isolate/tests/integration/test_11_singleton_schema_v1_rejected.sh`
- `skills/x-worktree-isolate/tests/integration/test_12_singleton_compose_replicas_zero.sh`
- `skills/x-worktree-isolate/tests/integration/test_13_singleton_envflag_written.sh`
- `skills/x-worktree-isolate/tests/integration/test_14_singleton_host_blocks_apply.sh`
- `skills/x-worktree-isolate/tests/integration/test_15_singleton_main_checkout_no_disable.sh`
- `skills/x-worktree-isolate/tests/integration/test_16_singleton_features_enable_disable.sh`
- `skills/x-worktree-isolate/tests/integration/test_17_singleton_init_non_interactive.sh`
- `skills/x-worktree-isolate/tests/integration/test_18_singleton_detection_guardrails.sh`
- `skills/x-worktree-isolate/tests/integration/test_19_singleton_profile_gate.sh`
- `skills/x-worktree-isolate/tests/integration/test_20_singleton_dedup_with_services_to_strip.sh`
- `skills/x-worktree-isolate/tests/integration/test_21_doctor_singleton_invariants.sh`

**Modify:**
- `skills/x-worktree-isolate/config.json` — `version` 0.1.0→0.2.0; `schema_version` 1→2.
- `skills/x-worktree-isolate/scripts/dispatch.sh` — `VERSION` bump; new subcommands wired to `feature-overrides.sh`.
- `skills/x-worktree-isolate/scripts/inspect.sh` — Calls `detect-singletons.py`; interactive prompt loop; `--non-interactive` flag; writes `schema: 2` + `singletons[]` + `detection_guardrails{}` into profile.json.
- `skills/x-worktree-isolate/scripts/apply.sh` — Hard rejects `schema: 1`; reads `singletons[]`; calls `render-singletons.py`; merges output into override + env files; respects `feature-overrides.local.json`; host-tier blocker gate.
- `skills/x-worktree-isolate/scripts/release.sh` — Clears `singleton_owners` entries for this worktree.
- `skills/x-worktree-isolate/scripts/doctor.sh` — Validates singleton invariants (env-flag echoed, replicas:0 in rendered compose config, host-tier ack present if needed).
- `skills/x-worktree-isolate/scripts/allocate-ports.sh` — Registry schema gains optional `singleton_owners` object; helpers `xwi_record_singleton_owner` / `xwi_clear_singleton_owners_for`.
- `skills/x-worktree-isolate/templates/profile.template.json` — schema:2 with full `singletons[]` example block.
- `skills/x-worktree-isolate/SKILL.md` — Schema bump callout; new singleton workflow section; CLI table updated.
- `skills/x-worktree-isolate/references/detection-heuristics.md` — Add singleton probe rows.
- `skills/x-worktree-isolate/gotchas.md` — Add singleton-specific gotchas (false positives, host-tier ack semantics).
- `skills/x-worktree-isolate/tests/integration/lib.sh` — `write_profile` helper updated to emit `schema: 2`.

---

## Profile Schema (v2)

`profile.json` gains the following on top of v1 fields. All v1 fields remain; only `schema` is bumped and these are added.

```jsonc
{
  "schema": 2,
  // existing v1 fields: generator_version, stack, compose_files, compose_override_target,
  //   env_file_target, port_strategy, data_dirs, services_to_strip, service_dns_references,
  //   global_label_warnings, single_worktree_profiles, post_apply_hints, generated_at
  "singletons": [
    {
      "id": "slack-bot",
      "kind": "compose-service",                 // "compose-service" | "env-flag" | "host"
      "evidence": ["docker-compose.yml:services.slack-listener.environment.SLACK_BOT_TOKEN"],
      "rationale": "Slack Socket Mode listener — duplicate connections receive events twice.",
      "default_in_worktree": "disabled",         // "disabled" | "enabled"
      "severity": "warning",                     // "blocker" | "warning" | "info"
      "compose_service": "slack-listener",       // kind=compose-service
      "disable_method": "replicas-zero"          // "replicas-zero" | "profile-gate"
    },
    {
      "id": "cron-dispatcher",
      "kind": "env-flag",
      "evidence": ["src/jobs/scheduler.ts:14: cron.schedule(...)"],
      "rationale": "node-cron scheduler — duplicate workers will fire jobs twice.",
      "default_in_worktree": "disabled",
      "severity": "warning",
      "env_var": "RUN_CRON_DISPATCHER",
      "env_disabled_value": "false"
    },
    {
      "id": "host-crontab",
      "kind": "host",
      "evidence": ["infra/cron/dispatcher.crontab"],
      "rationale": "Repo-tracked crontab — host-shared state, cannot be auto-disabled per worktree.",
      "default_in_worktree": "disabled",
      "severity": "blocker",                     // host-tier defaults to blocker
      "host_artifact": "infra/cron/dispatcher.crontab",
      "manual_fix_hint": "Comment out the line in your active crontab before running a second worktree, or run `x-worktree-isolate ack-host-singletons`."
    }
  ],
  "detection_guardrails": {
    "scan_max_depth": 4,
    "scan_max_file_bytes": 1048576,
    "exclude_dirs": ["node_modules", "vendor", ".git", "dist", "build", "__pycache__", "target", ".next", ".venv", "tests/fixtures"],
    "exclude_globs": ["*.min.js", "*.lock", "package-lock.json", "pnpm-lock.yaml", "yarn.lock", "Cargo.lock"]
  }
}
```

`feature-overrides.local.json` (gitignored, per-worktree, beside `state.local.json`):

```jsonc
{
  "schema": 1,
  "overrides": [
    {"id": "slack-bot", "state": "enabled"},          // "enabled" | "disabled"
    {"id": "host-crontab", "state": "acknowledged"}    // "acknowledged" only valid for kind=host
  ],
  "updated_at": "2026-05-11T12:00:00Z"
}
```

Registry (`~/.config/worktree-isolate/<sha1>/registry.json`) gains `singleton_owners`:

```jsonc
{
  "slots": [...],
  "singleton_owners": {
    "slack-bot": "/abs/path/to/worktree-A"   // declarative bookkeeping only, NOT a runtime lock
  }
}
```

---

## Task 1: Schema bump infrastructure (config + template + test helper)

**Files:**
- Modify: `skills/x-worktree-isolate/config.json`
- Modify: `skills/x-worktree-isolate/templates/profile.template.json`
- Modify: `skills/x-worktree-isolate/tests/integration/lib.sh`
- Modify: `skills/x-worktree-isolate/scripts/dispatch.sh:17`
- Test: `skills/x-worktree-isolate/tests/integration/test_11_singleton_schema_v1_rejected.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/integration/test_11_singleton_schema_v1_rejected.sh`:

```bash
#!/usr/bin/env bash
# Test 11: apply must hard-reject a schema:1 profile with a precise migration message.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t11
trap test_teardown EXIT

MAIN="$TEST_TMP/main"
make_repo "$MAIN"

# Write a legacy schema:1 profile.
mkdir -p "$MAIN/.worktree-isolate"
cat > "$MAIN/.worktree-isolate/profile.json" <<'JSON'
{
  "schema": 1,
  "stack": "docker-compose",
  "port_strategy": {"scan_range": [18000, 29999], "ports": []},
  "services_to_strip": [],
  "data_dirs": [],
  "global_label_warnings": [],
  "single_worktree_profiles": []
}
JSON
( cd "$MAIN" && git add .worktree-isolate/profile.json && git commit -q -m "legacy v1 profile" )

WT="$TEST_TMP/wt"
make_worktree "$MAIN" "$WT" "feat-x"

# Apply MUST fail and MUST mention init --rescan.
set +e
stderr_capture="$(cd "$WT" && bash "$DISPATCH" apply 2>&1 >/dev/null)"
rc=$?
set -e

[ "$rc" -ne 0 ] || fail "apply must non-zero exit on schema:1"
assert_contains "$stderr_capture" "schema 1 is no longer supported" "must surface schema rejection"
assert_contains "$stderr_capture" "init --rescan" "must surface migration command"
assert_file_absent "$WT/compose.override.yml" "must not write override on schema reject"
assert_file_absent "$WT/.env.worktree" "must not write env on schema reject"

pass "test 11 — schema:1 hard-rejected with migration hint"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash skills/x-worktree-isolate/tests/integration/test_11_singleton_schema_v1_rejected.sh`
Expected: FAIL — current `apply.sh` accepts schema:1.

- [ ] **Step 3: Bump version constants**

Edit `skills/x-worktree-isolate/config.json` — set `"version": "0.2.0"` and `"schema_version": 2`.

Edit `skills/x-worktree-isolate/scripts/dispatch.sh` line 17:
```bash
VERSION="0.2.0"
```

- [ ] **Step 4: Update test helper to emit schema:2**

Edit `skills/x-worktree-isolate/tests/integration/lib.sh` `write_profile` default body — change `"schema": 1` to `"schema": 2`, and append `,"singletons": [], "detection_guardrails": {"scan_max_depth": 4, "scan_max_file_bytes": 1048576, "exclude_dirs": [], "exclude_globs": []}` before the closing brace.

- [ ] **Step 5: Update `apply.sh` schema check to hard-reject v1**

Replace the `SCHEMA_OK` block at `apply.sh:77-87` with:

```bash
# Hard-reject schema:1 (v0.2.0+ requires schema:2). Print precise migration command.
SCHEMA="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("schema"))' "$PROFILE")"
if [[ "$SCHEMA" == "1" ]]; then
  cat >&2 <<EOF
x-worktree-isolate apply: profile schema 1 is no longer supported by v0.2.0+.
  Profile: $PROFILE

  Migrate by running init --rescan from the main checkout:

    cd <main-checkout> && x-worktree-isolate init --rescan

  init --rescan will write ${PROFILE}.new alongside the existing profile and
  print the exact diff + merge commands you should run next. Do not edit
  ${PROFILE} by hand.
EOF
  exit 1
fi
if [[ "$SCHEMA" != "2" ]]; then
  echo "x-worktree-isolate apply: unsupported profile schema ($SCHEMA). Expected 2." >&2
  exit 1
fi
```

- [ ] **Step 6: Update template**

Overwrite `skills/x-worktree-isolate/templates/profile.template.json` with the full v2 example (set `"schema": 2`, add `"singletons": [...]` example with one entry per kind, add `"detection_guardrails": {...}` defaults). Keep existing v1 fields, only change `schema` value and add the two new top-level keys.

- [ ] **Step 7: Bump inspect.sh to write schema:2 (with empty singletons[])**

This step closes the intermediate-broken-state gap. After Task 1 lands, anyone running `init` then `apply` MUST get a working result; otherwise apply will reject the just-generated profile.

In `inspect.sh`, find the PROFILE_JSON-building python block (the `python3 - "$PARSED_JSON" "$LABEL_WARNINGS_JSON" "$REPO_ROOT" <<'PY'` block, currently around lines 144-270). Change the `profile = { ... }` dict literal to set `"schema": 2` AND append empty `singletons` + default `detection_guardrails` keys:

```python
profile = {
    "schema": 2,
    "generator_version": "0.2.0",
    # ... existing keys unchanged ...
    "post_apply_hints": [],
    "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    "singletons": [],
    "detection_guardrails": {
        "scan_max_depth": 4,
        "scan_max_file_bytes": 1048576,
        "exclude_dirs": ["node_modules", "vendor", ".git", "dist", "build",
                         "__pycache__", "target", ".next", ".venv", "tests/fixtures"],
        "exclude_globs": ["*.min.js", "*.lock", "package-lock.json",
                          "pnpm-lock.yaml", "yarn.lock", "Cargo.lock"],
    },
}
```

The `singletons[]` array stays empty in Task 1 — Task 6 wires the detector to populate it. Apply will accept this shape today because the v0.2 host-blocker gate (Task 10) only fires when the array contains non-acknowledged host entries.

- [ ] **Step 8: Run test to verify it passes**

Run: `bash skills/x-worktree-isolate/tests/integration/test_11_singleton_schema_v1_rejected.sh`
Expected: PASS.

- [ ] **Step 9: Run the full existing suite with surgical schema bumps**

Run: `bash skills/x-worktree-isolate/tests/integration/run-all.sh`
Expected: PASS for tests using the updated `write_profile` helper (which now emits schema:2). For tests that inline `"schema": 1` AS PART OF THE HAPPY-PATH FIXTURE, bump to `2` ONLY in these specific files:

- `tests/integration/test_03_blocker_warning.sh`
- `tests/integration/test_04_idempotent_reapply.sh`
- `tests/integration/test_07_caller_docker_context.sh`
- `tests/integration/test_08_parallel_concurrency.sh`
- `tests/integration/test_09_apply_timeout.sh`
- `tests/integration/test_09b_orphan_cleanup_with_state.sh`

When you bump each, also add the empty `singletons: []` and a minimal `detection_guardrails: {"scan_max_depth":4,"scan_max_file_bytes":1048576,"exclude_dirs":[],"exclude_globs":[]}` to the inline JSON.

**DO NOT MODIFY** `tests/integration/test_10_malformed_profile.sh` — its schema:1 literal IS the rejection fixture. If it currently asserts a v1-specific malformation message, replace that fixture content with an intentionally-broken schema:2 profile (e.g., missing required key, wrong type) and keep the existing rejection-message assertion. Read the test first; do not blindly edit.

- [ ] **Step 10: Commit**

```bash
git add skills/x-worktree-isolate/config.json \
        skills/x-worktree-isolate/scripts/dispatch.sh \
        skills/x-worktree-isolate/scripts/apply.sh \
        skills/x-worktree-isolate/scripts/inspect.sh \
        skills/x-worktree-isolate/templates/profile.template.json \
        skills/x-worktree-isolate/tests/integration/lib.sh \
        skills/x-worktree-isolate/tests/integration/test_*.sh \
        skills/x-worktree-isolate/tests/integration/test_11_singleton_schema_v1_rejected.sh
git commit -m "feat(x-worktree-isolate): bump to schema 2, hard-reject v1 profiles"
```

---

## Task 2: Singleton pattern table

**Files:**
- Create: `skills/x-worktree-isolate/scripts/singleton-patterns.py`

Single source of truth for what we look for. No tests directly — exercised through Task 3-5 scanner tests.

- [ ] **Step 1: Create the pattern module**

```python
#!/usr/bin/env python3
"""singleton-patterns.py — Pattern catalog for stateful singleton detection.

Three tiers:
  TIER_COMPOSE   — token env vars + image substrings that mark a compose service
                   as a singleton (e.g., SLACK_BOT_TOKEN in a service's environment).
  TIER_ENV_FLAG  — token env-var name patterns + source-code library signatures
                   that mark a feature flag the user should toggle in worktrees.
  TIER_HOST      — repo-tracked host artifacts (crontabs, systemd unit files)
                   that share OS-level state and cannot be per-worktree disabled.

Each entry: id, regex (compiled), rationale, suggested_env_var (env-flag only).
"""

from __future__ import annotations
import re
from dataclasses import dataclass, field


@dataclass(frozen=True)
class Pattern:
    id: str
    rationale: str
    # For compose-service tier: matched against env-var names AND image substrings.
    # For env-flag tier: matched against env-var names AND source-code text.
    # For host tier: glob applied against repo-relative file paths.
    matchers: tuple[str, ...]
    suggested_env_var: str = ""
    severity: str = "warning"     # "blocker" | "warning" | "info"


TIER_COMPOSE: tuple[Pattern, ...] = (
    Pattern(
        id="slack-listener",
        rationale="Slack Socket Mode / RTM listener — duplicate connections receive events twice.",
        matchers=("SLACK_BOT_TOKEN", "SLACK_APP_TOKEN", "SLACK_SIGNING_SECRET"),
        suggested_env_var="SLACK_LISTENER_ENABLED",
    ),
    Pattern(
        id="discord-bot",
        rationale="Discord gateway connection — duplicate bots double-respond.",
        matchers=("DISCORD_BOT_TOKEN", "DISCORD_TOKEN"),
        suggested_env_var="DISCORD_BOT_ENABLED",
    ),
    Pattern(
        id="telegram-bot",
        rationale="Telegram long-poll / webhook — duplicate listeners cause 409 conflicts.",
        matchers=("TELEGRAM_BOT_TOKEN", "TELEGRAM_TOKEN"),
        suggested_env_var="TELEGRAM_BOT_ENABLED",
    ),
    Pattern(
        id="stripe-webhook",
        rationale="Stripe webhook receiver — duplicate listeners double-process events.",
        matchers=("STRIPE_WEBHOOK_SECRET",),
        suggested_env_var="STRIPE_WEBHOOK_ENABLED",
    ),
    Pattern(
        id="github-app-webhook",
        rationale="GitHub App webhook — duplicate listeners double-process events.",
        matchers=("GITHUB_APP_PRIVATE_KEY", "GITHUB_WEBHOOK_SECRET"),
        suggested_env_var="GITHUB_WEBHOOK_ENABLED",
    ),
    Pattern(
        id="ngrok-tunnel",
        rationale="Public tunnel — fixed public URL only one worktree may own at a time.",
        matchers=("ngrok/ngrok", "NGROK_AUTHTOKEN", "localtunnel"),
        suggested_env_var="NGROK_ENABLED",
    ),
    Pattern(
        id="watchtower",
        rationale="watchtower auto-updater — singleton by design.",
        matchers=("containrrr/watchtower",),
        suggested_env_var="WATCHTOWER_ENABLED",
    ),
)


TIER_ENV_FLAG: tuple[Pattern, ...] = (
    Pattern(
        id="node-cron",
        rationale="node-cron scheduler — duplicate workers will fire jobs twice.",
        matchers=(r"\bcron\.schedule\b", r"from\s+['\"]node-cron['\"]", r"require\(['\"]node-cron['\"]\)"),
        suggested_env_var="RUN_SCHEDULER",
    ),
    Pattern(
        id="bullmq-worker",
        rationale="BullMQ worker — duplicate workers cause double-execution.",
        matchers=(r"new\s+Worker\(", r"from\s+['\"]bullmq['\"]"),
        suggested_env_var="RUN_BULLMQ_WORKER",
    ),
    Pattern(
        id="celery-beat",
        rationale="Celery beat scheduler — singleton by design.",
        matchers=(r"celery\s+beat", r"CELERY_BEAT_SCHEDULER"),
        suggested_env_var="RUN_CELERY_BEAT",
    ),
    Pattern(
        id="slack-bolt",
        rationale="Slack Bolt app — duplicate listeners receive events twice.",
        matchers=(r"from\s+slack_bolt", r"from\s+['\"]@slack/bolt['\"]", r"SocketModeClient", r"RTMClient"),
        suggested_env_var="SLACK_LISTENER_ENABLED",
    ),
    Pattern(
        id="discord-client",
        rationale="Discord client — duplicate connections double-respond.",
        matchers=(r"discord\.Client\(", r"new\s+Discord\.Client"),
        suggested_env_var="DISCORD_BOT_ENABLED",
    ),
    Pattern(
        id="telegraf",
        rationale="Telegraf (Telegram) — duplicate long-poll causes 409.",
        matchers=(r"new\s+Telegraf\(", r"from\s+['\"]telegraf['\"]"),
        suggested_env_var="TELEGRAM_BOT_ENABLED",
    ),
    Pattern(
        id="agenda",
        rationale="Agenda scheduler — duplicate workers double-execute.",
        matchers=(r"new\s+Agenda\(", r"from\s+['\"]agenda['\"]"),
        suggested_env_var="RUN_SCHEDULER",
    ),
    Pattern(
        id="chokidar-shared-watch",
        rationale="chokidar watch on shared host path — duplicate watchers fire twice.",
        matchers=(r"chokidar\.watch\(", r"from\s+['\"]chokidar['\"]"),
        suggested_env_var="RUN_FILE_WATCHER",
    ),
    Pattern(
        id="procfile-worker",
        rationale="Procfile worker line — foreman/honcho run these as singletons; gate with an env flag.",
        matchers=(r"^worker:", r"^scheduler:"),  # matched against Procfile contents
        suggested_env_var="RUN_PROCFILE_WORKER",
    ),
)


# TIER_HOST entries all default to severity=blocker — host state cannot be auto-disabled
# per worktree, so apply.sh hard-blocks until `ack-host-singletons` is invoked. Procfile
# was considered for this tier but reclassified to env-flag in TIER_ENV_FLAG above (its
# natural disable is `RUN_PROCFILE_WORKER=false`, not a host-level toggle).
TIER_HOST: tuple[Pattern, ...] = (
    Pattern(
        id="host-crontab",
        rationale="Repo-tracked crontab — host-shared state, cannot be auto-disabled per worktree.",
        matchers=("*.crontab", "crontab"),
        severity="blocker",
    ),
    Pattern(
        id="systemd-service",
        rationale="systemd unit file — host-shared state, cannot be auto-disabled per worktree.",
        matchers=("*.service", "*.timer"),
        severity="blocker",
    ),
)


# Compiled-on-demand regexes for env-flag tier.
def env_flag_regexes() -> list[tuple[Pattern, re.Pattern[str]]]:
    out = []
    for p in TIER_ENV_FLAG:
        joined = "|".join(f"(?:{m})" for m in p.matchers)
        out.append((p, re.compile(joined)))
    return out
```

- [ ] **Step 2: Commit**

```bash
git add skills/x-worktree-isolate/scripts/singleton-patterns.py
git commit -m "feat(x-worktree-isolate): singleton pattern catalog (3 tiers)"
```

---

## Task 3: Tier 1 detection — compose-service singletons

**Files:**
- Create: `skills/x-worktree-isolate/scripts/detect-singletons.py` (initial: Tier 1 only)
- Test: `skills/x-worktree-isolate/tests/integration/test_12_singleton_compose_replicas_zero.sh` (skeleton — detection only at this stage)

- [ ] **Step 1: Write the failing test (scanner-only assertion)**

Create `tests/integration/test_12_singleton_compose_replicas_zero.sh`:

```bash
#!/usr/bin/env bash
# Test 12 (stage A — Task 3): detect-singletons emits a compose-service candidate
# when a service env contains SLACK_BOT_TOKEN. Renderer assertion comes in Task 8.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t12a
trap test_teardown EXIT

MAIN="$TEST_TMP/main"
make_repo "$MAIN"

cat > "$MAIN/docker-compose.yml" <<'YAML'
services:
  slack-listener:
    image: myapp/slack:latest
    environment:
      SLACK_BOT_TOKEN: xoxb-fake
YAML

DETECT="$SKILL_DIR/scripts/detect-singletons.py"
out_json="$(python3 "$DETECT" --repo "$MAIN")"

echo "$out_json" | python3 -c '
import json, sys
data = json.load(sys.stdin)
slack = [s for s in data.get("singletons", []) if s.get("compose_service") == "slack-listener" and s.get("kind") == "compose-service"]
assert len(slack) == 1, f"expected one slack-listener compose-service candidate, got {slack}"
assert slack[0]["id"] == "slack-listener", f"id must be the stable pattern id, got {slack[0]['"'"'id'"'"']}"
assert slack[0]["disable_method"] in ("replicas-zero", "profile-gate")
print("ok")
'

pass "test 12a — compose-service singleton detected"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash skills/x-worktree-isolate/tests/integration/test_12_singleton_compose_replicas_zero.sh`
Expected: FAIL — `detect-singletons.py` does not exist yet.

- [ ] **Step 3: Implement Tier 1 in detect-singletons.py**

Create `skills/x-worktree-isolate/scripts/detect-singletons.py`:

```python
#!/usr/bin/env python3
"""detect-singletons.py — Heuristic scanner across three tiers.

Usage:
  detect-singletons.py --repo <repo_root> [--guardrails <json>]

Output:
  {"singletons": [...], "warnings": [...]}  on stdout (pretty JSON).
"""

from __future__ import annotations
import argparse, json, os, sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
import importlib.util
spec = importlib.util.spec_from_file_location("singleton_patterns", SCRIPT_DIR / "singleton-patterns.py")
sp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sp)

# Reuse parse-compose for YAML walk.
spec2 = importlib.util.spec_from_file_location("parse_compose", SCRIPT_DIR / "parse-compose.py")
pc = importlib.util.module_from_spec(spec2)
spec2.loader.exec_module(pc)


def find_compose_files(repo: Path) -> list[Path]:
    names = ("docker-compose.yml", "docker-compose.yaml", "compose.yml", "compose.yaml")
    found: list[Path] = []
    for entry in sorted(repo.rglob("*")):
        if entry.is_file() and entry.name in names and "override" not in entry.name:
            depth = len(entry.relative_to(repo).parts) - 1
            if depth <= 2:
                found.append(entry)
    return found


def detect_compose(repo: Path) -> list[dict]:
    """Emit one entry per (pattern, compose_service) match.

    ID contract: ``id`` is the stable pattern id (e.g. ``"slack-listener"``).
    The same ``id`` may appear multiple times if the same pattern matches
    multiple compose services; entries differ by ``compose_service``. CLI
    subcommands (``enable``/``disable``) operate on ``id`` and toggle all
    matching entries together — see Task 11.

    Default disable_method is ``replicas-zero``. To use ``profile-gate``
    instead, the user edits the profile by hand after init (see
    references/singleton-patterns.md, "Profile gate vs replicas-zero").
    Detection never auto-selects profile-gate.
    """
    out: list[dict] = []
    seen_pairs: set[tuple[str, str]] = set()
    for cf in find_compose_files(repo):
        parsed = pc.parse_compose_file(str(cf))
        for svc_name, svc in parsed.get("services", {}).items():
            env = svc.get("environment") or {}
            image = svc.get("image") or ""
            for pat in sp.TIER_COMPOSE:
                hits: list[str] = []
                for m in pat.matchers:
                    for env_key in env.keys():
                        if m in env_key:
                            hits.append(f"{cf.name}:services.{svc_name}.environment.{env_key}")
                    if isinstance(image, str) and m in image:
                        hits.append(f"{cf.name}:services.{svc_name}.image={image}")
                if hits:
                    pair = (pat.id, svc_name)
                    if pair in seen_pairs:
                        continue
                    seen_pairs.add(pair)
                    out.append({
                        "id": pat.id,
                        "kind": "compose-service",
                        "evidence": hits,
                        "rationale": pat.rationale,
                        "default_in_worktree": "disabled",
                        "severity": pat.severity,
                        "compose_service": svc_name,
                        "disable_method": "replicas-zero",
                    })
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True)
    ap.add_argument("--guardrails", default="{}")
    args = ap.parse_args()
    repo = Path(args.repo).resolve()
    if not repo.is_dir():
        print(f"detect-singletons: not a directory: {repo}", file=sys.stderr)
        sys.exit(1)

    singletons: list[dict] = []
    singletons.extend(detect_compose(repo))
    # Tier 2 + Tier 3 land in Tasks 4 and 5.

    print(json.dumps({"singletons": singletons, "warnings": []}, indent=2))


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash skills/x-worktree-isolate/tests/integration/test_12_singleton_compose_replicas_zero.sh`
Expected: PASS — emits the `slack-listener:slack-listener` candidate.

- [ ] **Step 5: Commit**

```bash
git add skills/x-worktree-isolate/scripts/detect-singletons.py \
        skills/x-worktree-isolate/tests/integration/test_12_singleton_compose_replicas_zero.sh
git commit -m "feat(x-worktree-isolate): tier-1 compose-service singleton detection"
```

---

## Task 4: Tier 2 detection — env-flag singletons with guardrails

**Files:**
- Modify: `skills/x-worktree-isolate/scripts/detect-singletons.py`
- Test: `skills/x-worktree-isolate/tests/integration/test_18_singleton_detection_guardrails.sh`

- [ ] **Step 1: Write the failing test (guardrails + env-flag detection)**

Create `tests/integration/test_18_singleton_detection_guardrails.sh`:

```bash
#!/usr/bin/env bash
# Test 18: env-flag detection respects exclude_dirs + max_file_bytes + max_depth.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t18
trap test_teardown EXIT

MAIN="$TEST_TMP/main"
make_repo "$MAIN"

# Source that SHOULD match (depth 1, normal file).
mkdir -p "$MAIN/src"
cat > "$MAIN/src/scheduler.js" <<'JS'
const cron = require('node-cron');
cron.schedule('* * * * *', () => console.log('tick'));
JS

# Source that SHOULD NOT match — inside node_modules (excluded).
mkdir -p "$MAIN/node_modules/somepkg"
cat > "$MAIN/node_modules/somepkg/index.js" <<'JS'
require('node-cron');
JS

# Source that SHOULD NOT match — too deep.
mkdir -p "$MAIN/a/b/c/d/e/f"
cat > "$MAIN/a/b/c/d/e/f/deep.js" <<'JS'
require('node-cron');
JS

# Source that SHOULD NOT match — too big.
mkdir -p "$MAIN/big"
python3 -c 'open("'"$MAIN"'/big/huge.js","w").write("// pad\n"*200000 + "require(\"node-cron\")")'

DETECT="$SKILL_DIR/scripts/detect-singletons.py"
guard='{"scan_max_depth":4,"scan_max_file_bytes":1048576,"exclude_dirs":["node_modules"],"exclude_globs":[]}'
out_json="$(python3 "$DETECT" --repo "$MAIN" --guardrails "$guard")"

echo "$out_json" | python3 -c '
import json, sys
data = json.load(sys.stdin)
candidates = data.get("singletons", [])
node_cron = [c for c in candidates if c["id"].startswith("node-cron")]
assert len(node_cron) == 1, f"expected exactly 1 node-cron hit (only src/scheduler.js), got {len(node_cron)}"
ev = node_cron[0]["evidence"][0]
assert "src/scheduler.js" in ev, f"hit must be src/scheduler.js, got {ev}"
assert "node_modules" not in str(candidates), "must not scan node_modules"
print("ok")
'

pass "test 18 — env-flag detection respects guardrails"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash skills/x-worktree-isolate/tests/integration/test_18_singleton_detection_guardrails.sh`
Expected: FAIL — Tier 2 detection not implemented yet.

- [ ] **Step 3: Add Tier 2 to detect-singletons.py**

Append to `detect-singletons.py` (above `def main()`):

```python
DEFAULT_GUARDRAILS = {
    "scan_max_depth": 4,
    "scan_max_file_bytes": 1048576,
    "exclude_dirs": ["node_modules", "vendor", ".git", "dist", "build",
                     "__pycache__", "target", ".next", ".venv", "tests/fixtures"],
    "exclude_globs": ["*.min.js", "*.lock", "package-lock.json",
                      "pnpm-lock.yaml", "yarn.lock", "Cargo.lock"],
}

SOURCE_EXTS = {".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs",
               ".py", ".rb", ".go", ".rs", ".java", ".kt",
               ".env", ".env.example", ".env.sample"}


def _path_excluded(p: Path, repo: Path, guard: dict) -> bool:
    rel = p.relative_to(repo)
    parts = rel.parts
    for ex in guard.get("exclude_dirs") or []:
        # support either single-segment or path-segment matches
        ex_parts = tuple(Path(ex).parts)
        if any(parts[i:i+len(ex_parts)] == ex_parts for i in range(len(parts))):
            return True
    name = p.name
    import fnmatch
    for glob in guard.get("exclude_globs") or []:
        if fnmatch.fnmatch(name, glob):
            return True
    return False


def _eligible_files(repo: Path, guard: dict):
    max_depth = int(guard.get("scan_max_depth", 4))
    max_bytes = int(guard.get("scan_max_file_bytes", 1048576))
    for p in repo.rglob("*"):
        if not p.is_file():
            continue
        rel = p.relative_to(repo)
        if len(rel.parts) - 1 > max_depth:
            continue
        if _path_excluded(p, repo, guard):
            continue
        ext = p.suffix.lower()
        is_env = p.name.startswith(".env") or p.name in (".env", ".env.example")
        if ext not in SOURCE_EXTS and not is_env:
            continue
        try:
            if p.stat().st_size > max_bytes:
                continue
        except OSError:
            continue
        yield p


def detect_env_flag(repo: Path, guard: dict) -> list[dict]:
    out: list[dict] = []
    seen_ids: set[str] = set()
    regexes = sp.env_flag_regexes()
    for f in _eligible_files(repo, guard):
        try:
            text = f.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        for pat, regex in regexes:
            m = regex.search(text)
            if not m:
                continue
            rel = f.relative_to(repo).as_posix()
            line_no = text[:m.start()].count("\n") + 1
            cand_id = pat.id
            if cand_id in seen_ids:
                continue
            seen_ids.add(cand_id)
            out.append({
                "id": cand_id,
                "kind": "env-flag",
                "evidence": [f"{rel}:{line_no}: {m.group(0)[:80]}"],
                "rationale": pat.rationale,
                "default_in_worktree": "disabled",
                "severity": pat.severity,
                "env_var": pat.suggested_env_var,
                "env_disabled_value": "false",
            })
    return out
```

In `main()`, parse guardrails and call `detect_env_flag`:

```python
guard = json.loads(args.guardrails) if args.guardrails else {}
merged = {**DEFAULT_GUARDRAILS, **(guard or {})}
singletons.extend(detect_env_flag(repo, merged))
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash skills/x-worktree-isolate/tests/integration/test_18_singleton_detection_guardrails.sh`
Expected: PASS — exactly one `node-cron` candidate from `src/scheduler.js`.

- [ ] **Step 5: Commit**

```bash
git add skills/x-worktree-isolate/scripts/detect-singletons.py \
        skills/x-worktree-isolate/tests/integration/test_18_singleton_detection_guardrails.sh
git commit -m "feat(x-worktree-isolate): tier-2 env-flag detection with guardrails"
```

---

## Task 5: Tier 3 detection — host artifacts (detect + warn only)

**Files:**
- Modify: `skills/x-worktree-isolate/scripts/detect-singletons.py`
- Test: `skills/x-worktree-isolate/tests/integration/test_14_singleton_host_blocks_apply.sh` (detection assertion only at this stage; apply-block comes in Task 10)

- [ ] **Step 1: Write the failing test (host detection assertion)**

Create `tests/integration/test_14_singleton_host_blocks_apply.sh`:

```bash
#!/usr/bin/env bash
# Test 14 (stage A — Task 5): detect a repo-tracked crontab artifact.
# Stage B (apply blocker) gets added in Task 10.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t14a
trap test_teardown EXIT

MAIN="$TEST_TMP/main"
make_repo "$MAIN"
mkdir -p "$MAIN/infra/cron"
cat > "$MAIN/infra/cron/dispatcher.crontab" <<'CRON'
*/5 * * * * /usr/bin/dispatcher run
CRON

DETECT="$SKILL_DIR/scripts/detect-singletons.py"
out_json="$(python3 "$DETECT" --repo "$MAIN")"

echo "$out_json" | python3 -c '
import json, sys
data = json.load(sys.stdin)
host = [s for s in data.get("singletons", []) if s["kind"] == "host"]
assert any(s["id"] == "host-crontab" for s in host), f"expected host-crontab id, got {[s['"'"'id'"'"'] for s in host]}"
ct = next(s for s in host if s["id"] == "host-crontab")
assert ct["severity"] == "blocker", f"host tier must default severity=blocker, got {ct['"'"'severity'"'"']}"
assert "manual_fix_hint" in ct
print("ok")
'

pass "test 14a — host-tier crontab detected with severity=blocker"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash skills/x-worktree-isolate/tests/integration/test_14_singleton_host_blocks_apply.sh`
Expected: FAIL — Tier 3 not implemented.

- [ ] **Step 3: Add Tier 3 to detect-singletons.py**

Append to `detect-singletons.py`:

```python
import fnmatch as _fnmatch

def detect_host(repo: Path, guard: dict) -> list[dict]:
    out: list[dict] = []
    seen_ids: set[str] = set()
    max_depth = int(guard.get("scan_max_depth", 4))
    for p in repo.rglob("*"):
        if not p.is_file():
            continue
        rel = p.relative_to(repo)
        if len(rel.parts) - 1 > max_depth:
            continue
        if _path_excluded(p, repo, guard):
            continue
        rel_posix = rel.as_posix()
        for pat in sp.TIER_HOST:
            if pat.id in seen_ids:
                continue
            matched = False
            for m in pat.matchers:
                # treat as glob over the repo-relative posix path; also allow plain filename match
                if _fnmatch.fnmatch(p.name, m) or _fnmatch.fnmatch(rel_posix, m):
                    matched = True
                    break
            if matched:
                seen_ids.add(pat.id)
                out.append({
                    "id": pat.id,
                    "kind": "host",
                    "evidence": [rel_posix],
                    "rationale": pat.rationale,
                    "default_in_worktree": "disabled",
                    "severity": pat.severity,
                    "host_artifact": rel_posix,
                    "manual_fix_hint": (
                        f"Disable or scope {rel_posix} before running parallel worktrees, "
                        "or run `x-worktree-isolate ack-host-singletons` to acknowledge."
                    ),
                })
    return out
```

In `main()` after the env-flag call: `singletons.extend(detect_host(repo, merged))`.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash skills/x-worktree-isolate/tests/integration/test_14_singleton_host_blocks_apply.sh`
Expected: PASS — host-crontab detected with severity=blocker.

- [ ] **Step 5: Commit**

```bash
git add skills/x-worktree-isolate/scripts/detect-singletons.py \
        skills/x-worktree-isolate/tests/integration/test_14_singleton_host_blocks_apply.sh
git commit -m "feat(x-worktree-isolate): tier-3 host-artifact detection"
```

---

## Task 6: Wire inspect.sh to call detector and populate singletons[]

**Files:**
- Modify: `skills/x-worktree-isolate/scripts/inspect.sh`

Task 1 already bumped `inspect.sh` to write `schema: 2` with an empty `singletons: []` and default `detection_guardrails`. This task only adds the detector wiring; the interactive prompt loop AND the test that exercises `--non-interactive` ship together in Task 7.

- [ ] **Step 1: Edit inspect.sh to call detect-singletons.py**

In `inspect.sh`, after `LABEL_WARNINGS_JSON=` is computed but before `PROFILE_JSON=` is built, call the detector:

```bash
# --- Detect singletons (Tasks 3-5) ---
GUARDRAILS_DEFAULT='{"scan_max_depth":4,"scan_max_file_bytes":1048576,"exclude_dirs":["node_modules","vendor",".git","dist","build","__pycache__","target",".next",".venv","tests/fixtures"],"exclude_globs":["*.min.js","*.lock","package-lock.json","pnpm-lock.yaml","yarn.lock","Cargo.lock"]}'
SINGLETONS_RAW="$(python3 "$SCRIPT_DIR/detect-singletons.py" --repo "$REPO_ROOT" --guardrails "$GUARDRAILS_DEFAULT")"
SINGLETONS_LIST_JSON="$(printf '%s' "$SINGLETONS_RAW" | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin).get("singletons",[])))')"
```

In the `PROFILE_JSON=` python block (the one already writing `schema: 2`), pass `$SINGLETONS_LIST_JSON` and `$GUARDRAILS_DEFAULT` as additional argv entries; inside the python, replace the empty `singletons: []` / default `detection_guardrails` set in Task 1 with the detected values:

```python
singletons_list = json.loads(sys.argv[4])
guardrails = json.loads(sys.argv[5])
# ... existing profile dict construction unchanged ...
profile["singletons"] = singletons_list
profile["detection_guardrails"] = guardrails
```

- [ ] **Step 2: Unit smoke**

Run inspect.sh manually against a repo with the test-12 compose fixture and confirm `singletons` array in the output contains the slack-listener candidate.

```bash
( cd <fixture-repo> && bash skills/x-worktree-isolate/scripts/inspect.sh --dry-run | python3 -c 'import json,sys; p=json.load(sys.stdin); print([s["id"] for s in p["singletons"]])' )
```

Expected output: `['slack-listener']`.

- [ ] **Step 3: Commit**

```bash
git add skills/x-worktree-isolate/scripts/inspect.sh
git commit -m "feat(x-worktree-isolate): inspect.sh wires detector + populates singletons[]"
```

---

## Task 7: Interactive init prompt loop (and --non-interactive flag)

**Files:**
- Modify: `skills/x-worktree-isolate/scripts/inspect.sh`
- Test: `skills/x-worktree-isolate/tests/integration/test_17_singleton_init_non_interactive.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/integration/test_17_singleton_init_non_interactive.sh`:

```bash
#!/usr/bin/env bash
# Test 17: init --non-interactive scans + writes all candidates without prompting.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t17
trap test_teardown EXIT

MAIN="$TEST_TMP/main"
make_repo "$MAIN"
cat > "$MAIN/docker-compose.yml" <<'YAML'
services:
  slack-listener:
    image: myapp/slack:latest
    environment:
      SLACK_BOT_TOKEN: xoxb-fake
YAML
( cd "$MAIN" && git add docker-compose.yml && git commit -q -m compose )

# --non-interactive: never prompt; write all candidates as "disabled".
( cd "$MAIN" && bash "$DISPATCH" init --non-interactive )

profile="$MAIN/.worktree-isolate/profile.json"
assert_file_exists "$profile" "profile must be written"

python3 <<PY
import json
p = json.load(open("$profile"))
assert p["schema"] == 2
ids = {s["id"] for s in p.get("singletons", [])}
assert any("slack-listener" in i for i in ids), f"expected slack-listener, got {ids}"
PY

pass "test 17 — init --non-interactive scans + writes candidates"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash skills/x-worktree-isolate/tests/integration/test_17_singleton_init_non_interactive.sh`
Expected: FAIL — `--non-interactive` flag does not exist.

- [ ] **Step 3: Add interactive default + --non-interactive flag to inspect.sh**

In `inspect.sh` argument parsing (around line 20), add:

```bash
INTERACTIVE=1
NON_INTERACTIVE=0
for arg in "$@"; do
  case "$arg" in
    --write)             WRITE=1 ;;
    --dry-run)           WRITE=0; DRY_RUN=1; INTERACTIVE=0 ;;
    --rescan)            RESCAN=1; WRITE=1 ;;
    --non-interactive)   NON_INTERACTIVE=1; INTERACTIVE=0 ;;
    --interactive)       INTERACTIVE=1; NON_INTERACTIVE=0 ;;
    --help|-h)
      cat <<'EOF'
inspect.sh — Phase 1: build profile.json draft.
  (default)            persist to .worktree-isolate/profile.json + interactive singleton prompts
  --non-interactive    skip prompts, accept all detected candidates as disabled
  --dry-run            print profile JSON to stdout, do not touch disk
  --rescan             write .worktree-isolate/profile.json.new and print a diff command
EOF
      exit 0 ;;
    *) echo "inspect.sh: unknown flag: $arg" >&2; exit 1 ;;
  esac
done
# If stdin is not a TTY, force non-interactive (CI safety).
if [[ "$INTERACTIVE" -eq 1 ]] && [[ ! -t 0 ]]; then
  INTERACTIVE=0
  NON_INTERACTIVE=1
fi
```

After `SINGLETONS_LIST_JSON=` is computed (Task 6), add the interactive prompt loop. **Critical implementation note (GPT + Gemini reviewers caught this):** the prompt CANNOT be inside `python3 - <<EOF` because the heredoc consumes stdin (so `input()` raises EOFError), and it CANNOT be wrapped in `$(...)` command substitution because that captures the prompt text instead of showing it to the user.

The pattern below uses a tmpfile-backed python script that explicitly opens `/dev/tty` for both prompts and answers, leaving stdin/stdout untouched. The script reads candidates from a tmpfile input and writes the final JSON to a tmpfile output. Bash reads the output file:

```bash
if [[ "$INTERACTIVE" -eq 1 ]]; then
  PROMPT_IN="$(mktemp -t xwi-cands-in.XXXXXX)"
  PROMPT_OUT="$(mktemp -t xwi-cands-out.XXXXXX)"
  printf '%s' "$SINGLETONS_LIST_JSON" > "$PROMPT_IN"
  PROMPT_SCRIPT="$(mktemp -t xwi-prompt.XXXXXX.py)"
  cat > "$PROMPT_SCRIPT" <<'PY'
import json, sys

with open(sys.argv[1]) as fh:
    cands = json.load(fh)

# Open /dev/tty explicitly — heredoc-fed stdin and command-substitution stdout
# would otherwise break prompts. /dev/tty is the controlling terminal,
# unaffected by either.
try:
    tty = open("/dev/tty", "r+", buffering=1)
except OSError:
    # No TTY available — caller should have set INTERACTIVE=0 already.
    json.dump(cands, open(sys.argv[2], "w"))
    sys.exit(0)

def ask(prompt):
    tty.write(prompt)
    tty.flush()
    return tty.readline().strip()

kept = []
tty.write("\nx-worktree-isolate init: review detected singletons (these will be disabled in worktrees):\n")
for c in cands:
    tty.write(f"\n  [{c['id']}] kind={c['kind']} severity={c['severity']}\n")
    tty.write(f"    rationale: {c['rationale']}\n")
    for ev in c['evidence']:
        tty.write(f"    evidence:  {ev}\n")
    suffix = "/c" if c["kind"] == "env-flag" else ""
    while True:
        ans = ask(f"    Disable in worktrees? [Y/n{suffix}]: ").lower()
        if ans in ("", "y", "yes"):
            kept.append(c); break
        if ans in ("n", "no"):
            c["default_in_worktree"] = "enabled"; kept.append(c); break
        if c["kind"] == "env-flag" and ans in ("c", "customize"):
            new_var = ask(f"    Env var name [{c['env_var']}]: ")
            if new_var: c["env_var"] = new_var
            kept.append(c); break
        tty.write(f"      (please answer y / n{suffix})\n")

with open(sys.argv[2], "w") as fh:
    json.dump(kept, fh)
PY
  python3 "$PROMPT_SCRIPT" "$PROMPT_IN" "$PROMPT_OUT"
  SINGLETONS_LIST_JSON="$(cat "$PROMPT_OUT")"
  rm -f "$PROMPT_IN" "$PROMPT_OUT" "$PROMPT_SCRIPT"
fi
```

For `--non-interactive`, leave `SINGLETONS_LIST_JSON` as-is (default_in_worktree=disabled for all).

The TTY-fallback inside the python script (if `/dev/tty` open fails) handles edge cases where `INTERACTIVE=1` was somehow set without a real terminal (e.g., manual override). The earlier `[[ ! -t 0 ]]` check covers the normal CI path.

- [ ] **Step 4: Run the new test**

Run: `bash skills/x-worktree-isolate/tests/integration/test_17_singleton_init_non_interactive.sh`
Expected: PASS — profile written with `singletons[]` populated, schema 2.

- [ ] **Step 5: Author the deferred stage-B of test 12 (now that `--non-interactive` exists)**

Append to `tests/integration/test_12_singleton_compose_replicas_zero.sh` BEFORE the existing `pass` line:

```bash
# Stage B (Task 7): init --non-interactive writes singletons[] into profile.json.
( cd "$MAIN" && bash "$DISPATCH" init --non-interactive >/dev/null )
assert_file_exists "$MAIN/.worktree-isolate/profile.json" "init must write profile"
schema="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("schema"))' "$MAIN/.worktree-isolate/profile.json")"
assert_eq "2" "$schema" "profile schema must equal 2"
have_singleton="$(python3 -c '
import json,sys
p=json.load(open(sys.argv[1]))
ids=[s["id"] for s in p.get("singletons",[])]
print("yes" if "slack-listener" in ids else "no")
' "$MAIN/.worktree-isolate/profile.json")"
assert_eq "yes" "$have_singleton" "init must record slack-listener candidate in singletons[]"
```

Run: `bash skills/x-worktree-isolate/tests/integration/test_12_singleton_compose_replicas_zero.sh`
Expected: PASS for stages A + B. (Stage C — apply renders replicas:0 — lands in Task 10.)

- [ ] **Step 6: Commit**

```bash
git add skills/x-worktree-isolate/scripts/inspect.sh \
        skills/x-worktree-isolate/tests/integration/test_17_singleton_init_non_interactive.sh \
        skills/x-worktree-isolate/tests/integration/test_12_singleton_compose_replicas_zero.sh
git commit -m "feat(x-worktree-isolate): init interactive prompts + --non-interactive flag"
```

---

## Task 8: Render compose service disable (replicas:0)

**Files:**
- Create: `skills/x-worktree-isolate/scripts/render-singletons.py`

- [ ] **Step 1: Extend test 12 to assert apply output (stage C)**

Append to `tests/integration/test_12_singleton_compose_replicas_zero.sh`:

```bash
# Stage C (Task 8 + 10): apply renders services.slack-listener.deploy.replicas: 0.
commit_profile "$MAIN"  # commit the v2 profile
WT="$TEST_TMP/wt12"
make_worktree "$MAIN" "$WT" "feat-x"
( cd "$WT" && bash "$DISPATCH" apply --quiet )

override="$WT/compose.override.yml"
assert_file_exists "$override" "override must be written"
assert_contains "$(cat "$override")" "slack-listener:" "override must include slack-listener block"
assert_contains "$(cat "$override")" "replicas: 0" "override must set replicas: 0 for disabled compose-service singleton"
```

- [ ] **Step 2: Run test to verify stage-C fails**

Run: `bash skills/x-worktree-isolate/tests/integration/test_12_singleton_compose_replicas_zero.sh`
Expected: FAIL — renderer does not yet emit `replicas: 0` (apply.sh currently only renders `container_name: !reset null` + `ports: !override`).

- [ ] **Step 3: Implement render-singletons.py**

**Critical contract (Claude reviewer caught this):** the renderer returns a structured `dict[service] → fields` for compose contributions, NOT pre-formatted YAML lines. `apply.sh`'s existing render-python block already iterates `services_to_strip` to emit `container_name: !reset null` and `ports: !override`. Singleton contributions MUST merge into the same per-service dict to prevent two `services.<svc>:` blocks under one `services:` map (which Compose v2 rejects as duplicate-mapping-keys).

Create `skills/x-worktree-isolate/scripts/render-singletons.py`:

```python
#!/usr/bin/env python3
"""render-singletons.py — Compute singleton contributions to override + env files.

Usage:
  render-singletons.py --profile <path> [--overrides <path>]

Output (JSON on stdout):
  {
    "compose_service_fields": {
      "slack-listener": {"deploy": {"replicas": 0}},
      "watchtower":     {"profiles": ["singleton"]}
    },
    "env_lines": ["SLACK_LISTENER_ENABLED=false", "RUN_SCHEDULER=false"],
    "host_blockers": [{"id": "host-crontab", "host_artifact": "...", "manual_fix_hint": "..."}]
  }

Apply.sh merges compose_service_fields into its existing per-service override
dict before YAML serialization (one services.<svc>: block per service, never two).
"""

from __future__ import annotations
import argparse, json, os, sys


def load_overrides(path: str) -> dict[str, str]:
    if not path or not os.path.isfile(path):
        return {}
    try:
        data = json.load(open(path))
    except (OSError, json.JSONDecodeError):
        return {}
    return {o["id"]: o["state"] for o in data.get("overrides", []) if "id" in o and "state" in o}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--profile", required=True)
    ap.add_argument("--overrides", default="")
    args = ap.parse_args()

    profile = json.load(open(args.profile))
    overrides = load_overrides(args.overrides)
    svc_fields: dict[str, dict] = {}   # service -> {"deploy": {...}} | {"profiles": [...]}
    env_lines: list[str] = []
    host_blockers: list[dict] = []

    for s in profile.get("singletons", []) or []:
        sid = s.get("id")
        default = s.get("default_in_worktree", "disabled")
        state = overrides.get(sid, default)
        kind = s.get("kind")

        if kind == "host":
            if state == "acknowledged":
                continue
            host_blockers.append({
                "id": sid,
                "host_artifact": s.get("host_artifact", ""),
                "manual_fix_hint": s.get("manual_fix_hint", ""),
            })
            continue

        if state == "enabled":
            continue   # user wants it ON in this worktree — no disable emission

        if kind == "compose-service":
            svc = s.get("compose_service")
            method = s.get("disable_method", "replicas-zero")
            if not svc:
                continue
            entry = svc_fields.setdefault(svc, {})
            if method == "replicas-zero":
                entry["deploy"] = {"replicas": 0}
            elif method == "profile-gate":
                profs = entry.setdefault("profiles", [])
                if "singleton" not in profs:
                    profs.append("singleton")
        elif kind == "env-flag":
            var = s.get("env_var")
            val = s.get("env_disabled_value", "false")
            if var:
                env_lines.append(f"{var}={val}")

    print(json.dumps({
        "compose_service_fields": svc_fields,
        "env_lines": env_lines,
        "host_blockers": host_blockers,
    }, indent=2))


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Make renderer reachable but don't wire to apply yet**

Run a manual smoke: `python3 skills/x-worktree-isolate/scripts/render-singletons.py --profile <path-to-test-profile>` should emit a `compose_yaml_lines` array containing `replicas: 0` for a disabled compose-service singleton.

- [ ] **Step 5: Commit**

```bash
git add skills/x-worktree-isolate/scripts/render-singletons.py
git commit -m "feat(x-worktree-isolate): render-singletons.py (compose replicas:0 + env-flag + host-blocker)"
```

---

## Task 9: Render env-flag lines (no apply wiring yet)

This is purely covered by Task 8's `render-singletons.py` — but exercise it with a dedicated test before Task 10 wires it into apply.

**Files:**
- Test: `skills/x-worktree-isolate/tests/integration/test_13_singleton_envflag_written.sh`

- [ ] **Step 1: Write the failing test (renderer-only)**

Create `tests/integration/test_13_singleton_envflag_written.sh`:

```bash
#!/usr/bin/env bash
# Test 13 (stage A — Task 9): renderer emits env_lines for env-flag singletons.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t13a
trap test_teardown EXIT

MAIN="$TEST_TMP/main"
make_repo "$MAIN"
mkdir -p "$MAIN/.worktree-isolate"
cat > "$MAIN/.worktree-isolate/profile.json" <<'JSON'
{
  "schema": 2,
  "stack": "docker-compose",
  "port_strategy": {"scan_range": [18000, 29999], "ports": []},
  "services_to_strip": [],
  "data_dirs": [],
  "global_label_warnings": [],
  "single_worktree_profiles": [],
  "detection_guardrails": {"scan_max_depth":4,"scan_max_file_bytes":1048576,"exclude_dirs":[],"exclude_globs":[]},
  "singletons": [
    {
      "id": "node-cron", "kind": "env-flag", "evidence": ["src/jobs.js:1"],
      "rationale": "node-cron scheduler", "default_in_worktree": "disabled", "severity": "warning",
      "env_var": "RUN_SCHEDULER", "env_disabled_value": "false"
    }
  ]
}
JSON

out_json="$(python3 "$SKILL_DIR/scripts/render-singletons.py" --profile "$MAIN/.worktree-isolate/profile.json")"

echo "$out_json" | python3 -c '
import json,sys
data=json.load(sys.stdin)
assert "RUN_SCHEDULER=false" in data["env_lines"], data
print("ok")
'

pass "test 13a — env-flag renderer emits RUN_SCHEDULER=false"
```

- [ ] **Step 2: Run test**

Run: `bash skills/x-worktree-isolate/tests/integration/test_13_singleton_envflag_written.sh`
Expected: PASS (Task 8 already implemented the renderer logic).

- [ ] **Step 3: Commit**

```bash
git add skills/x-worktree-isolate/tests/integration/test_13_singleton_envflag_written.sh
git commit -m "test(x-worktree-isolate): renderer env-flag lines"
```

---

## Task 10: Wire renderer into apply.sh (single-pass merged override + unified blocker gate)

**Files:**
- Modify: `skills/x-worktree-isolate/scripts/apply.sh`
- Test: `skills/x-worktree-isolate/tests/integration/test_15_singleton_main_checkout_no_disable.sh`
- Test: `skills/x-worktree-isolate/tests/integration/test_19_singleton_profile_gate.sh` (profile-gate disable_method coverage)
- Test: `skills/x-worktree-isolate/tests/integration/test_20_singleton_dedup_with_services_to_strip.sh` (BLOCKER regression — duplicate service-key fixture)

This task does THREE things in one apply.sh edit:
1. Replace the OVERRIDE_BODY python block to merge `services_to_strip` AND `singleton compose_service_fields` into one dict, serialized as ONE `services.<svc>:` block per service.
2. Extend the existing blocker collector (currently at apply.sh:90-105 over `global_label_warnings` + `single_worktree_profiles`) to ALSO iterate `singletons[]` where `kind=="host"` and override-state is not `acknowledged`. ONE gate, ONE error format, ONE `--ignore-warnings` escape.
3. Append singleton env lines to ENV_LINES (env-flag tier).

Main-checkout exemption is already enforced by the existing `apply.sh:46-53` block; no edit needed there. Test 15 simply locks it in as an invariant — including a profile that HAS singletons, so the test actually exercises the exemption (Gemini reviewer caught this).

- [ ] **Step 1: Write failing tests**

Extend `tests/integration/test_13_singleton_envflag_written.sh` (stage B — already exists from Task 9 as renderer-only; add apply assertion):

```bash
# Stage B (Task 10): apply writes RUN_SCHEDULER=false into .env.worktree.
commit_profile "$MAIN"
WT="$TEST_TMP/wt13"
make_worktree "$MAIN" "$WT" "feat-x"
( cd "$WT" && bash "$DISPATCH" apply --quiet )
assert_contains "$(cat "$WT/.env.worktree")" "RUN_SCHEDULER=false" ".env.worktree must include disabled env-flag"
```

Extend `tests/integration/test_14_singleton_host_blocks_apply.sh` (stage B — write but immediately tag with a sentinel; the post-ack assertions move into Task 11):

```bash
# Stage B (Task 10): apply blocks when host singleton present + no ack.
( cd "$MAIN" && bash "$DISPATCH" init --non-interactive )
commit_profile "$MAIN"
WT="$TEST_TMP/wt14"
make_worktree "$MAIN" "$WT" "feat-x"

set +e
out="$(cd "$WT" && bash "$DISPATCH" apply 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] || fail "apply must block when host singleton present + no ack"
assert_contains "$out" "host-crontab" "blocker message must name the host singleton"
assert_contains "$out" "ack-host-singletons" "blocker message must mention ack subcommand"
```

(The ack + re-apply assertion is authored in Task 11 Step 6 — NOT here. No comment-out gymnastics.)

Rewrite `tests/integration/test_15_singleton_main_checkout_no_disable.sh` to inject a singleton (Gemini fix):

```bash
#!/usr/bin/env bash
# Test 15: running apply from the main checkout must short-circuit even when a
# singleton is present (so the exemption is actually exercised, not vacuously true).
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t15
trap test_teardown EXIT

MAIN="$TEST_TMP/main"
make_repo "$MAIN"
mkdir -p "$MAIN/.worktree-isolate"
cat > "$MAIN/.worktree-isolate/profile.json" <<'JSON'
{
  "schema": 2,
  "stack": "docker-compose",
  "port_strategy": {"scan_range": [18000, 29999], "ports": []},
  "services_to_strip": [],
  "data_dirs": [],
  "global_label_warnings": [],
  "single_worktree_profiles": [],
  "detection_guardrails": {"scan_max_depth":4,"scan_max_file_bytes":1048576,"exclude_dirs":[],"exclude_globs":[]},
  "singletons": [
    {"id":"node-cron","kind":"env-flag","evidence":["src/jobs.js:1"],"rationale":"sched","default_in_worktree":"disabled","severity":"warning","env_var":"RUN_SCHEDULER","env_disabled_value":"false"}
  ]
}
JSON
commit_profile "$MAIN"

( cd "$MAIN" && bash "$DISPATCH" apply --if-profile-exists --quiet )
assert_file_absent "$MAIN/compose.override.yml" "main checkout must not get compose override"
assert_file_absent "$MAIN/.env.worktree" "main checkout must not get .env.worktree"

# Confirm the exemption is the early-exit path (would have produced RUN_SCHEDULER=false otherwise).
pass "test 15 — main checkout exempt from singleton disable (singleton present, exemption exercised)"
```

Create `tests/integration/test_19_singleton_profile_gate.sh`:

```bash
#!/usr/bin/env bash
# Test 19: a compose-service singleton with disable_method=profile-gate produces
# services.<svc>.profiles: [singleton] in the override (instead of replicas:0).
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t19
trap test_teardown EXIT

MAIN="$TEST_TMP/main"
make_repo "$MAIN"
cat > "$MAIN/docker-compose.yml" <<'YAML'
services:
  ngrok:
    image: ngrok/ngrok:latest
YAML
mkdir -p "$MAIN/.worktree-isolate"
cat > "$MAIN/.worktree-isolate/profile.json" <<'JSON'
{
  "schema": 2,
  "stack": "docker-compose",
  "port_strategy": {"scan_range": [18000, 29999], "ports": []},
  "services_to_strip": [],
  "data_dirs": [],
  "global_label_warnings": [],
  "single_worktree_profiles": [],
  "detection_guardrails": {"scan_max_depth":4,"scan_max_file_bytes":1048576,"exclude_dirs":[],"exclude_globs":[]},
  "singletons": [
    {"id":"ngrok-tunnel","kind":"compose-service","evidence":["docker-compose.yml:services.ngrok.image"],"rationale":"public tunnel","default_in_worktree":"disabled","severity":"warning","compose_service":"ngrok","disable_method":"profile-gate"}
  ]
}
JSON
( cd "$MAIN" && git add . && git commit -q -m setup )

WT="$TEST_TMP/wt19"
make_worktree "$MAIN" "$WT" "feat-x"
( cd "$WT" && bash "$DISPATCH" apply --quiet )

ov="$WT/compose.override.yml"
assert_file_exists "$ov" "override must be written"
assert_contains "$(cat "$ov")" "ngrok:" "override must include ngrok block"
assert_contains "$(cat "$ov")" "profiles:" "override must include profiles list"
assert_contains "$(cat "$ov")" "- singleton" "override must gate ngrok with profile=singleton"

# Negative: must NOT contain replicas:0 (this singleton uses profile-gate, not replicas-zero).
case "$(cat "$ov")" in
  *"replicas: 0"*) fail "profile-gate singleton must NOT emit replicas:0" ;;
esac

pass "test 19 — profile-gate disable_method emits profiles:[singleton]"
```

Create `tests/integration/test_20_singleton_dedup_with_services_to_strip.sh`:

```bash
#!/usr/bin/env bash
# Test 20 (BLOCKER regression): a service that appears in BOTH services_to_strip
# (with container_name + ports) AND singletons[] (compose-service replicas-zero)
# must produce exactly ONE top-level services.<svc>: block in compose.override.yml.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t20
trap test_teardown EXIT

MAIN="$TEST_TMP/main"
make_repo "$MAIN"
cat > "$MAIN/docker-compose.yml" <<'YAML'
services:
  slack-listener:
    image: myapp/slack:latest
    container_name: myapp_slack
    ports:
      - "127.0.0.1:9000:9000"
    environment:
      SLACK_BOT_TOKEN: xoxb-fake
YAML
mkdir -p "$MAIN/.worktree-isolate"
cat > "$MAIN/.worktree-isolate/profile.json" <<'JSON'
{
  "schema": 2,
  "stack": "docker-compose",
  "port_strategy": {"scan_range": [18000, 29999], "ports": [{"var":"SLACK_PORT","service":"slack-listener","default":9000,"container_port":9000}]},
  "services_to_strip": [{"service":"slack-listener","container_name":"myapp_slack","ports":[{"var":"SLACK_PORT","container_port":9000}]}],
  "data_dirs": [],
  "global_label_warnings": [],
  "single_worktree_profiles": [],
  "detection_guardrails": {"scan_max_depth":4,"scan_max_file_bytes":1048576,"exclude_dirs":[],"exclude_globs":[]},
  "singletons": [
    {"id":"slack-listener","kind":"compose-service","evidence":["docker-compose.yml:services.slack-listener.environment.SLACK_BOT_TOKEN"],"rationale":"Slack","default_in_worktree":"disabled","severity":"warning","compose_service":"slack-listener","disable_method":"replicas-zero"}
  ]
}
JSON
( cd "$MAIN" && git add . && git commit -q -m setup )

WT="$TEST_TMP/wt20"
make_worktree "$MAIN" "$WT" "feat-x"
( cd "$WT" && bash "$DISPATCH" apply --quiet )

ov="$WT/compose.override.yml"
slack_keys="$(grep -cE '^  slack-listener:$' "$ov" || true)"
assert_eq "1" "$slack_keys" "compose.override.yml must have EXACTLY one top-level 'slack-listener:' block"
assert_contains "$(cat "$ov")" "container_name: !reset null" "override must keep container_name reset"
assert_contains "$(cat "$ov")" "ports: !override" "override must keep ports override"
assert_contains "$(cat "$ov")" "replicas: 0" "override must include singleton replicas:0"

pass "test 20 — single services.<svc> block when service is in both lists"
```

Run them — 13 stage-B / 14 stage-B / 15 / 19 / 20 all FAIL.

- [ ] **Step 2: Rewrite apply.sh blocker collector to include host singletons**

Replace the existing blocker-list python block at `apply.sh:90-106` with one that ALSO iterates `singletons[]`:

```bash
# Build the unified blocker list. Sources: global_label_warnings + single_worktree_profiles
# (existing v0.1 invariants) + singletons[] where kind=="host" and override-state != acknowledged.
OVERRIDES_FILE="$REPO_ROOT/.worktree-isolate/feature-overrides.local.json"
BLOCKER_LIST="$(python3 - "$PROFILE" "$OVERRIDES_FILE" <<'PY'
import json, os, sys
profile = json.load(open(sys.argv[1]))
ov_path = sys.argv[2]
overrides = {}
if os.path.isfile(ov_path):
    try: overrides = {o["id"]: o["state"] for o in json.load(open(ov_path)).get("overrides", [])}
    except (OSError, json.JSONDecodeError): pass

lines = []
for w in profile.get("global_label_warnings", []):
    if not isinstance(w, dict): continue
    if not w.get("label"): continue
    if w.get("severity") == "blocker":
        lines.append(f"  - [{w.get('found_in','?')}] label={w.get('label')}\n    fix_hint: {w.get('fix_hint','(none)')}")
for w in profile.get("single_worktree_profiles", []):
    if not isinstance(w, dict): continue
    if w.get("severity") == "blocker" and w.get("service"):
        lines.append(f"  - profile={w.get('profile')} on service {w.get('service')}: {w.get('reason')}")
for s in profile.get("singletons", []) or []:
    if s.get("kind") != "host": continue
    state = overrides.get(s.get("id"), s.get("default_in_worktree", "disabled"))
    if state == "acknowledged": continue
    if s.get("severity") != "blocker": continue
    lines.append(
        f"  - host-singleton {s.get('id')}: {s.get('host_artifact','')}\n"
        f"    fix: {s.get('manual_fix_hint','run x-worktree-isolate ack-host-singletons')}"
    )
print("\n".join(lines))
PY
)"
if [[ -n "$BLOCKER_LIST" && "$IGNORE_WARNINGS" -eq 0 ]]; then
  cat >&2 <<EOF
x-worktree-isolate apply: BLOCKED — unresolved cross-worktree footguns:
$BLOCKER_LIST

Resolve the issues above (apply the fix_hint), or:
  - for host-singletons, run: x-worktree-isolate ack-host-singletons
  - or re-run with --ignore-warnings to acknowledge the footguns explicitly.
EOF
  exit 1
fi
```

- [ ] **Step 3: Replace OVERRIDE_BODY render with single-pass merge**

Replace the OVERRIDE_BODY python block at `apply.sh:277-305` with:

```bash
RENDER_JSON="$(python3 "$SCRIPT_DIR/render-singletons.py" --profile "$PROFILE" --overrides "$OVERRIDES_FILE")"

OVERRIDE_BODY="$(python3 - "$PROFILE" "$RENDER_JSON" <<'PY'
import json, sys
profile = json.load(open(sys.argv[1]))
render = json.loads(sys.argv[2])
svc_fields = render.get("compose_service_fields", {})

# Merge services_to_strip + singleton fields into ONE dict keyed by service.
# This prevents duplicate `services.<svc>:` mapping keys.
merged: dict = {}
for e in profile.get("services_to_strip", []) or []:
    if not isinstance(e, dict): continue
    svc = e.get("service")
    if not svc: continue
    entry = merged.setdefault(svc, {})
    if e.get("container_name"):
        entry["container_name_reset"] = True
    if e.get("ports"):
        entry["ports"] = list(e.get("ports") or [])
for svc, fields in (svc_fields or {}).items():
    entry = merged.setdefault(svc, {})
    if "deploy" in fields:
        entry["deploy"] = fields["deploy"]
    if "profiles" in fields:
        entry.setdefault("profiles", [])
        for p in fields["profiles"]:
            if p not in entry["profiles"]:
                entry["profiles"].append(p)

# Serialize. One services.<svc>: block per merged entry.
lines = ["services:"]
for svc in merged.keys():
    entry = merged[svc]
    if not entry:
        continue
    lines.append(f"  {svc}:")
    if entry.get("container_name_reset"):
        lines.append("    container_name: !reset null")
    if entry.get("ports"):
        lines.append("    ports: !override")
        for p in entry["ports"]:
            var = p.get("var"); cport = p.get("container_port")
            if not var or cport is None: continue
            lines.append(f'      - "127.0.0.1:${{{var}}}:{cport}"')
    if entry.get("deploy"):
        lines.append("    deploy:")
        # deploy is a small shallow dict — emit one key at a time.
        for k, v in entry["deploy"].items():
            lines.append(f"      {k}: {json.dumps(v)}")
    if entry.get("profiles"):
        lines.append("    profiles:")
        for p in entry["profiles"]:
            lines.append(f"      - {p}")
print("\n".join(lines))
PY
)"
```

- [ ] **Step 4: Append singleton env lines**

After the existing `ENV_LINES` construction (around line ~336), add:

```bash
SINGLETON_ENV_LINES="$(printf '%s' "$RENDER_JSON" | python3 -c 'import json,sys; print("\n".join(json.load(sys.stdin)["env_lines"]))')"
if [[ -n "$SINGLETON_ENV_LINES" ]]; then
  ENV_LINES="${ENV_LINES}
${SINGLETON_ENV_LINES}"
fi
```

- [ ] **Step 5: Run the new tests**

```bash
bash skills/x-worktree-isolate/tests/integration/test_13_singleton_envflag_written.sh
bash skills/x-worktree-isolate/tests/integration/test_14_singleton_host_blocks_apply.sh
bash skills/x-worktree-isolate/tests/integration/test_15_singleton_main_checkout_no_disable.sh
bash skills/x-worktree-isolate/tests/integration/test_19_singleton_profile_gate.sh
bash skills/x-worktree-isolate/tests/integration/test_20_singleton_dedup_with_services_to_strip.sh
```

Expected: PASS for 13/15/19/20. Test 14 stops at the host-block assertion (the post-ack assertions land in Task 11).

- [ ] **Step 6: Run full suite for regressions**

Run: `bash skills/x-worktree-isolate/tests/integration/run-all.sh`
Expected: all PASS. Pay attention to test_02 (existing happy path) — the new merged-render serializer must produce a byte-equivalent override for v1-shape inputs (container_name + ports, no singletons).

- [ ] **Step 7: Commit**

```bash
git add skills/x-worktree-isolate/scripts/apply.sh \
        skills/x-worktree-isolate/tests/integration/test_13_singleton_envflag_written.sh \
        skills/x-worktree-isolate/tests/integration/test_14_singleton_host_blocks_apply.sh \
        skills/x-worktree-isolate/tests/integration/test_15_singleton_main_checkout_no_disable.sh \
        skills/x-worktree-isolate/tests/integration/test_19_singleton_profile_gate.sh \
        skills/x-worktree-isolate/tests/integration/test_20_singleton_dedup_with_services_to_strip.sh
git commit -m "feat(x-worktree-isolate): single-pass override render + unified host-blocker gate"
```

---

## Task 11: Feature-overrides CLI (`features`, `enable`, `disable`, `ack-host-singletons`)

**Files:**
- Create: `skills/x-worktree-isolate/scripts/feature-overrides.sh`
- Modify: `skills/x-worktree-isolate/scripts/dispatch.sh`
- Test: `skills/x-worktree-isolate/tests/integration/test_16_singleton_features_enable_disable.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/integration/test_16_singleton_features_enable_disable.sh`:

```bash
#!/usr/bin/env bash
# Test 16: features lists; enable/disable round-trip toggles .env.worktree + override.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t16
trap test_teardown EXIT

MAIN="$TEST_TMP/main"
make_repo "$MAIN"
mkdir -p "$MAIN/.worktree-isolate"
cat > "$MAIN/.worktree-isolate/profile.json" <<'JSON'
{
  "schema": 2,
  "stack": "docker-compose",
  "port_strategy": {"scan_range": [18000, 29999], "ports": []},
  "services_to_strip": [],
  "data_dirs": [],
  "global_label_warnings": [],
  "single_worktree_profiles": [],
  "detection_guardrails": {"scan_max_depth":4,"scan_max_file_bytes":1048576,"exclude_dirs":[],"exclude_globs":[]},
  "singletons": [
    {"id":"node-cron","kind":"env-flag","evidence":["src/jobs.js:1"],"rationale":"scheduler","default_in_worktree":"disabled","severity":"warning","env_var":"RUN_SCHEDULER","env_disabled_value":"false"}
  ]
}
JSON
commit_profile "$MAIN"

WT="$TEST_TMP/wt16"
make_worktree "$MAIN" "$WT" "feat-x"
( cd "$WT" && bash "$DISPATCH" apply --quiet )

# 1) features lists with state=disabled (default).
out="$(cd "$WT" && bash "$DISPATCH" features)"
assert_contains "$out" "node-cron" "features must list node-cron"
assert_contains "$out" "disabled" "default state must be disabled"
assert_contains "$(cat "$WT/.env.worktree")" "RUN_SCHEDULER=false" "default: env-flag disabled"

# 2) enable flips state + rewrites .env.worktree.
( cd "$WT" && bash "$DISPATCH" enable node-cron --quiet )
env_after="$(cat "$WT/.env.worktree")"
case "$env_after" in
  *"RUN_SCHEDULER=false"*) fail "after enable, RUN_SCHEDULER=false must be removed" ;;
esac

# 3) disable flips back.
( cd "$WT" && bash "$DISPATCH" disable node-cron --quiet )
assert_contains "$(cat "$WT/.env.worktree")" "RUN_SCHEDULER=false" "after disable, RUN_SCHEDULER=false must reappear"

pass "test 16 — features/enable/disable round-trip"
```

- [ ] **Step 2: Run test**

Run: `bash skills/x-worktree-isolate/tests/integration/test_16_singleton_features_enable_disable.sh`
Expected: FAIL — subcommands do not exist.

- [ ] **Step 3: Create feature-overrides.sh**

```bash
#!/usr/bin/env bash
# feature-overrides.sh — features / enable / disable / ack-host-singletons subcommands.
#
# Reads <worktree>/.worktree-isolate/profile.json (or main-checkout fallback).
# Writes <worktree>/.worktree-isolate/feature-overrides.local.json (gitignored).
# Re-invokes apply.sh to regenerate compose.override.yml + .env.worktree.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

SUB="${1:-}"; shift || true
# Scan ALL remaining args for --quiet (it can appear after the feature-id).
QUIET=0
POSITIONAL=()
for arg in "$@"; do
  case "$arg" in
    --quiet) QUIET=1 ;;
    *) POSITIONAL+=("$arg") ;;
  esac
done
set -- "${POSITIONAL[@]:-}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "x-worktree-isolate ${SUB}: not in a git work tree" >&2; exit 1
fi
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"   # apply.sh expects to run from repo root
COMMON_DIR="$(git rev-parse --git-common-dir)"
PROFILE_LOCAL="$REPO_ROOT/.worktree-isolate/profile.json"
PROFILE_MAIN="$(dirname "$(cd "$REPO_ROOT" && cd "$COMMON_DIR" && pwd -P)")/.worktree-isolate/profile.json"
PROFILE=""
if [[ -f "$PROFILE_LOCAL" ]]; then PROFILE="$PROFILE_LOCAL"; elif [[ -f "$PROFILE_MAIN" ]]; then PROFILE="$PROFILE_MAIN"; fi
if [[ -z "$PROFILE" ]]; then echo "x-worktree-isolate ${SUB}: no profile found" >&2; exit 1; fi

OV_DIR="$REPO_ROOT/.worktree-isolate"
OV_FILE="$OV_DIR/feature-overrides.local.json"
mkdir -p "$OV_DIR"

case "$SUB" in
  features)
    python3 - "$PROFILE" "$OV_FILE" <<'PY'
import json, os, sys
prof = json.load(open(sys.argv[1]))
overrides = {}
if os.path.isfile(sys.argv[2]):
    try:
        overrides = {o["id"]: o["state"] for o in json.load(open(sys.argv[2])).get("overrides", [])}
    except (OSError, json.JSONDecodeError):
        overrides = {}
print(f"{'id':<30} {'kind':<16} {'state':<14} rationale")
for s in prof.get("singletons", []) or []:
    state = overrides.get(s["id"], s.get("default_in_worktree", "disabled"))
    print(f"{s['id'][:30]:<30} {s.get('kind',''):<16} {state:<14} {s.get('rationale','')[:60]}")
PY
    ;;
  enable|disable|ack-host-singletons)
    feature_id="${1:-}"
    if [[ "$SUB" != "ack-host-singletons" && -z "$feature_id" ]]; then
      echo "usage: x-worktree-isolate $SUB <feature-id>" >&2; exit 1
    fi
    NEW_STATE=""
    case "$SUB" in
      enable)  NEW_STATE="enabled" ;;
      disable) NEW_STATE="disabled" ;;
      ack-host-singletons) NEW_STATE="acknowledged" ;;
    esac
    python3 - "$PROFILE" "$OV_FILE" "$SUB" "$feature_id" "$NEW_STATE" <<'PY'
import json, os, sys, time
prof = json.load(open(sys.argv[1]))
ov_path, sub, fid, state = sys.argv[2:]
existing = {"schema": 1, "overrides": []}
if os.path.isfile(ov_path):
    try: existing = json.load(open(ov_path))
    except (OSError, json.JSONDecodeError): pass
overrides = {o["id"]: o["state"] for o in existing.get("overrides", [])}

if sub == "ack-host-singletons":
    # Set ALL host singletons to acknowledged.
    for s in prof.get("singletons", []) or []:
        if s.get("kind") == "host":
            overrides[s["id"]] = "acknowledged"
else:
    ids = {s["id"] for s in prof.get("singletons", []) or []}
    if fid not in ids:
        print(f"x-worktree-isolate {sub}: no such feature id: {fid}", file=sys.stderr)
        sys.exit(1)
    overrides[fid] = state

out = {
    "schema": 1,
    "overrides": [{"id": k, "state": v} for k, v in sorted(overrides.items())],
    "updated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
}
tmp = ov_path + ".tmp"
with open(tmp, "w") as fh: json.dump(out, fh, indent=2)
os.replace(tmp, ov_path)
PY
    # Re-apply to regenerate override + env.
    bash "$SCRIPT_DIR/apply.sh" $([[ "$QUIET" -eq 1 ]] && echo --quiet) --if-profile-exists
    ;;
  *)
    echo "feature-overrides: unknown subcommand: $SUB" >&2; exit 1 ;;
esac
```

- [ ] **Step 4: Wire dispatch.sh**

Edit `dispatch.sh` — add subcommand cases and update usage:

```bash
  features|enable|disable|ack-host-singletons)
    exec bash "$SCRIPT_DIR/feature-overrides.sh" "$cmd" "$@"
    ;;
```

Add to `usage()`:

```
  features                          List profiled singletons + per-worktree state.
  enable <id>                       Mark singleton as enabled in this worktree.
  disable <id>                      Mark singleton as disabled (default).
  ack-host-singletons               Acknowledge all host-tier singletons (per worktree).
```

- [ ] **Step 5: Add feature-overrides.local.json to .gitignore patch list**

Edit `inspect.sh` `.gitignore` LINES array (around line 300):

```bash
LINES=(
  "# x-worktree-isolate"
  ".env.worktree"
  "compose.override.yml"
  ".worktree-isolate/state.local.json"
  ".worktree-isolate/feature-overrides.local.json"
)
```

Same change in `apply.sh` LINES array (~line 385).

- [ ] **Step 6: Author test 14 post-ack assertions (now that `ack-host-singletons` exists)**

Append to `tests/integration/test_14_singleton_host_blocks_apply.sh`, BEFORE the existing `pass` line:

```bash
# Stage C (Task 11): after ack, apply succeeds and writes .env.worktree.
( cd "$WT" && bash "$DISPATCH" ack-host-singletons --quiet )
( cd "$WT" && bash "$DISPATCH" apply --quiet )
assert_file_exists "$WT/.env.worktree" "apply must succeed after host ack"

# --quiet contract regression test (Claude reviewer caught this).
ack_stdout="$(cd "$WT" && bash "$DISPATCH" ack-host-singletons --quiet 2>&1)"
[ -z "$ack_stdout" ] || fail "ack-host-singletons --quiet must produce no stdout (got: $ack_stdout)"
```

Run:
```bash
bash skills/x-worktree-isolate/tests/integration/test_14_singleton_host_blocks_apply.sh
bash skills/x-worktree-isolate/tests/integration/test_16_singleton_features_enable_disable.sh
```

Expected: PASS for both.

- [ ] **Step 7: Commit**

```bash
git add skills/x-worktree-isolate/scripts/feature-overrides.sh \
        skills/x-worktree-isolate/scripts/dispatch.sh \
        skills/x-worktree-isolate/scripts/inspect.sh \
        skills/x-worktree-isolate/scripts/apply.sh \
        skills/x-worktree-isolate/tests/integration/test_14_singleton_host_blocks_apply.sh \
        skills/x-worktree-isolate/tests/integration/test_16_singleton_features_enable_disable.sh
git commit -m "feat(x-worktree-isolate): features/enable/disable/ack-host-singletons subcommands"
```

---

## Task 12: Registry singleton_owners (declarative)

**Files:**
- Modify: `skills/x-worktree-isolate/scripts/allocate-ports.sh`
- Modify: `skills/x-worktree-isolate/scripts/apply.sh`
- Modify: `skills/x-worktree-isolate/scripts/release.sh`

- [ ] **Step 1: Extend test 16 with stage-B assertion**

Append to `tests/integration/test_16_singleton_features_enable_disable.sh`:

```bash
# Stage B: enabling a singleton records ownership in the registry (declarative).
( cd "$WT" && bash "$DISPATCH" enable node-cron --quiet )
reg="$XDG_CONFIG_HOME/worktree-isolate"
owners="$(python3 -c '
import json, os, sys
root=sys.argv[1]
out={}
for rid in os.listdir(root):
    f=os.path.join(root,rid,"registry.json")
    if not os.path.isfile(f): continue
    out.update(json.load(open(f)).get("singleton_owners",{}))
print(json.dumps(out))
' "$reg")"
echo "$owners" | python3 -c '
import json,sys
o=json.load(sys.stdin)
assert "node-cron" in o, f"expected node-cron owner, got {o}"
print("ok")
'
```

- [ ] **Step 2: Add registry helpers**

Append to `allocate-ports.sh`:

```bash
# --- Singleton ownership (declarative bookkeeping) ---
xwi_set_singleton_owners() {
  # Args: worktree_path, singleton_ids_csv (empty string clears all owned by wpath)
  local wpath="$1" ids="$2"
  python3 - "$wpath" "$ids" "$(xwi_registry_file)" <<'PY'
import json, os, sys
wpath, ids_csv, path = sys.argv[1:]
ids = [i for i in ids_csv.split(",") if i]
data = {"slots": [], "singleton_owners": {}}
if os.path.isfile(path):
    try: data = json.load(open(path))
    except json.JSONDecodeError: data = {"slots": [], "singleton_owners": {}}
owners = data.get("singleton_owners") or {}
# Drop any singleton currently owned by THIS worktree.
owners = {k: v for k, v in owners.items() if v != wpath}
for sid in ids:
    owners[sid] = wpath
data["singleton_owners"] = owners
tmp = path + ".tmp"
with open(tmp, "w") as fh: json.dump(data, fh, indent=2)
os.replace(tmp, path)
PY
}

xwi_clear_singleton_owners_for() {
  local wpath="$1"
  xwi_set_singleton_owners "$wpath" ""
}
```

- [ ] **Step 3: Call xwi_set_singleton_owners from apply.sh**

In `apply.sh`, after `xwi_claim_slot` (~line 406), compute the list of currently-enabled singleton IDs (from profile.singletons + overrides) and record:

```bash
ENABLED_IDS="$(python3 - "$PROFILE" "$OVERRIDES_FILE" <<'PY'
import json, os, sys
prof = json.load(open(sys.argv[1]))
ov_path = sys.argv[2]
overrides = {}
if os.path.isfile(ov_path):
    try: overrides = {o["id"]: o["state"] for o in json.load(open(ov_path)).get("overrides", [])}
    except (OSError, json.JSONDecodeError): pass
out=[]
for s in prof.get("singletons", []) or []:
    sid = s["id"]
    state = overrides.get(sid, s.get("default_in_worktree","disabled"))
    if state == "enabled":
        out.append(sid)
print(",".join(out))
PY
)"
xwi_set_singleton_owners "$REPO_ROOT" "$ENABLED_IDS"
```

- [ ] **Step 4: Clear from release.sh**

In `release.sh` (read it first to find the spot — likely near `xwi_release_slot`):

```bash
xwi_clear_singleton_owners_for "$REPO_ROOT"
```

- [ ] **Step 5: Run test**

Run: `bash skills/x-worktree-isolate/tests/integration/test_16_singleton_features_enable_disable.sh`
Expected: PASS through stage B.

- [ ] **Step 6: Commit**

```bash
git add skills/x-worktree-isolate/scripts/allocate-ports.sh \
        skills/x-worktree-isolate/scripts/apply.sh \
        skills/x-worktree-isolate/scripts/release.sh \
        skills/x-worktree-isolate/tests/integration/test_16_singleton_features_enable_disable.sh
git commit -m "feat(x-worktree-isolate): registry singleton_owners declarative bookkeeping"
```

---

## Task 13: doctor.sh validates singleton invariants

**Files:**
- Modify: `skills/x-worktree-isolate/scripts/doctor.sh`
- Test: `skills/x-worktree-isolate/tests/integration/test_21_doctor_singleton_invariants.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/integration/test_21_doctor_singleton_invariants.sh`:

```bash
#!/usr/bin/env bash
# Test 21: doctor reports PASS for env-flag echo and FAIL when override file is tampered.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t21
trap test_teardown EXIT

MAIN="$TEST_TMP/main"
make_repo "$MAIN"
mkdir -p "$MAIN/.worktree-isolate"
cat > "$MAIN/.worktree-isolate/profile.json" <<'JSON'
{
  "schema": 2,
  "stack": "docker-compose",
  "port_strategy": {"scan_range":[18000,29999],"ports":[]},
  "services_to_strip": [],
  "data_dirs": [],
  "global_label_warnings": [],
  "single_worktree_profiles": [],
  "detection_guardrails": {"scan_max_depth":4,"scan_max_file_bytes":1048576,"exclude_dirs":[],"exclude_globs":[]},
  "singletons": [
    {"id":"node-cron","kind":"env-flag","evidence":["src/jobs.js:1"],"rationale":"sched","default_in_worktree":"disabled","severity":"warning","env_var":"RUN_SCHEDULER","env_disabled_value":"false"}
  ]
}
JSON
commit_profile "$MAIN"
WT="$TEST_TMP/wt21"
make_worktree "$MAIN" "$WT" "feat-x"
( cd "$WT" && bash "$DISPATCH" apply --quiet )

# 1) Doctor reports PASS.
out="$(cd "$WT" && bash "$DISPATCH" doctor 2>&1)"
assert_contains "$out" "singleton-env-flag" "doctor must include singleton invariant section"
assert_contains "$out" "PASS" "doctor must report PASS on a clean apply"

# 2) Tamper with .env.worktree, doctor reports FAIL.
sed -i.bak '/RUN_SCHEDULER=/d' "$WT/.env.worktree" && rm -f "$WT/.env.worktree.bak"
set +e
out2="$(cd "$WT" && bash "$DISPATCH" doctor 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] || fail "doctor must non-zero exit when invariant violated"
assert_contains "$out2" "RUN_SCHEDULER=false" "doctor must name the missing env-flag line"

pass "test 21 — doctor validates singleton env-flag invariant"
```

Run: `bash skills/x-worktree-isolate/tests/integration/test_21_doctor_singleton_invariants.sh`
Expected: FAIL — doctor doesn't validate singletons yet.

- [ ] **Step 2: Add the validation block to doctor.sh**

In `doctor.sh` (read it first to match its existing PASS/FAIL emission style), append a section that runs only when `state.local.json` exists:

```bash
STATE="$REPO_ROOT/.worktree-isolate/state.local.json"
if [[ -f "$STATE" ]]; then
  python3 - "$REPO_ROOT" "$PROFILE" "$REPO_ROOT/.worktree-isolate/feature-overrides.local.json" <<'PY' || DOCTOR_FAIL=1
import json, os, sys
repo, profile_path, ov_path = sys.argv[1:]
profile = json.load(open(profile_path))
overrides = {}
if os.path.isfile(ov_path):
    try: overrides = {o["id"]: o["state"] for o in json.load(open(ov_path)).get("overrides", [])}
    except (OSError, json.JSONDecodeError): pass

env_path = os.path.join(repo, ".env.worktree")
env_text = open(env_path).read() if os.path.isfile(env_path) else ""
failures = []
checks = 0

for s in profile.get("singletons", []) or []:
    sid = s["id"]; kind = s["kind"]
    state = overrides.get(sid, s.get("default_in_worktree", "disabled"))
    if state == "enabled":
        continue  # user opted IN — no invariant to check

    if kind == "env-flag":
        checks += 1
        line = f"{s.get('env_var','')}={s.get('env_disabled_value','false')}"
        if line not in env_text:
            failures.append(f"singleton-env-flag {sid}: expected `{line}` in .env.worktree")
    elif kind == "host" and state != "acknowledged":
        checks += 1
        failures.append(f"singleton-host {sid}: not acknowledged (run `x-worktree-isolate ack-host-singletons`)")
    # compose-service invariants need `docker compose ... config` and are too heavy
    # for doctor; covered by test_19/test_20 instead.

print(f"[singleton-invariants] {checks} check(s)")
if not failures:
    print("[singleton-invariants] PASS")
    sys.exit(0)
for f in failures:
    print(f"[singleton-invariants] FAIL: {f}")
sys.exit(1)
PY
fi
```

Pipe doctor's overall exit through the `DOCTOR_FAIL` accumulator (match existing pattern; if doctor.sh doesn't already aggregate, add `DOCTOR_FAIL=0` at the top and `exit $DOCTOR_FAIL` at the bottom).

- [ ] **Step 3: Run test**

Run: `bash skills/x-worktree-isolate/tests/integration/test_21_doctor_singleton_invariants.sh`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add skills/x-worktree-isolate/scripts/doctor.sh \
        skills/x-worktree-isolate/tests/integration/test_21_doctor_singleton_invariants.sh
git commit -m "feat(x-worktree-isolate): doctor validates singleton env-flag + host-ack invariants"
```

---

## Task 14: Documentation pass (SKILL.md, references, gotchas)

**Files:**
- Modify: `skills/x-worktree-isolate/SKILL.md`
- Modify: `skills/x-worktree-isolate/references/detection-heuristics.md`
- Create: `skills/x-worktree-isolate/references/singleton-patterns.md`
- Modify: `skills/x-worktree-isolate/gotchas.md`

- [ ] **Step 1: SKILL.md updates**

In SKILL.md:
- Update `description:` to mention "singleton-aware".
- Add a new `## Singletons (v0.2)` section after `## Workflow`, summarizing the three tiers + disable mechanisms + the four new subcommands.
- Update the CLI table (lines 27-33) to include `features`, `enable`, `disable`, `ack-host-singletons`, plus `init --non-interactive`.
- Update the `state.local.json schema` section (lines 104-119) to note `feature-overrides.local.json` as a sibling file.
- Bump version reference (`Currently 0.1.0` → `Currently 0.2.0`).
- Add migration callout at the top of the file: schema bump 1→2 requires `init --rescan` for existing repos.

- [ ] **Step 2: detection-heuristics.md — add singleton probe rows**

Append a new table section "Singleton probes (v0.2)" with one row per tier referencing `singleton-patterns.py`.

- [ ] **Step 3: singleton-patterns.md — new reference**

Create `references/singleton-patterns.md`: document the pattern catalog, evidence formats, severity assignment rules, and the "why we don't auto-disable host state" rationale.

- [ ] **Step 4: gotchas.md — add three entries**

Append:
- "False positives from vendored deps" — guardrails excludes `node_modules`, etc.; if a singleton you don't recognize appears, check the evidence path and add to `detection_guardrails.exclude_dirs`.
- "Host-tier ack is per-worktree" — `ack-host-singletons` writes to `<worktree>/.worktree-isolate/feature-overrides.local.json`; each new worktree must re-ack.
- "singleton_owners is declarative" — the registry does not prevent two worktrees from both enabling a singleton. The env-flag in `.env.worktree` is what actually prevents dual-execution; the registry is a hint for `features` output.

- [ ] **Step 5: Commit**

```bash
git add skills/x-worktree-isolate/SKILL.md \
        skills/x-worktree-isolate/references/detection-heuristics.md \
        skills/x-worktree-isolate/references/singleton-patterns.md \
        skills/x-worktree-isolate/gotchas.md
git commit -m "docs(x-worktree-isolate): document singleton awareness (v0.2)"
```

---

## Task 15: Full suite + run-all + plan exit

**Files:**
- Modify: `skills/x-worktree-isolate/tests/integration/run-all.sh` (if it enumerates tests explicitly)

- [ ] **Step 1: Verify run-all picks up new tests**

Read `run-all.sh`. If it globs `test_*.sh`, no edit needed. If it lists tests explicitly, add 11/12/13/14/15/16/17/18.

- [ ] **Step 2: Run full suite**

Run: `bash skills/x-worktree-isolate/tests/integration/run-all.sh`
Expected: ALL PASS.

- [ ] **Step 3: TypeScript / ESLint check**

This skill is bash + python only; no TS/JS files added. Skip tsc/eslint per the project's "Verify TypeScript & Lint After Implementation" rule (no applicable files).

- [ ] **Step 4: Commit**

```bash
git add skills/x-worktree-isolate/tests/integration/run-all.sh
git commit -m "test(x-worktree-isolate): include singleton tests in run-all"
```

---

## Self-Review Checklist (run before handoff)

**Spec coverage:**
- Schema:2 hard reject of schema:1 → Task 1 + test 11.
- Tier 1 compose-service detection → Task 3 + test 12 stage A.
- Tier 2 env-flag with guardrails → Tasks 4 + test 18.
- Tier 3 host detect-and-warn-only → Tasks 5 + 10 + test 14.
- Interactive init default, --non-interactive flag → Task 7 + test 17.
- Main checkout never disables singletons → Task 10 + test 15 (with singleton injected so exemption is exercised, not vacuous).
- `features` / `enable` / `disable` / `ack-host-singletons` CLI → Task 11 + test 16 + test 14 stage C.
- Registry `singleton_owners` declarative → Task 12 + test 16 stage B.
- Detection guardrails (excludes + max-depth + max-file-size) → Tasks 4 + 6 + test 18.
- `apply` stays non-interactive → preserved (no prompts added to apply.sh; interactive path lives only in inspect.sh and uses /dev/tty).
- `disable_method=profile-gate` produced AND tested → Task 10 + test 19.
- Single `services.<svc>:` block when service in both `services_to_strip` and `singletons[]` → Task 10 + test 20 (BLOCKER regression guard).
- `doctor` validates singleton invariants → Task 13 + test 21.

**Reviewer findings (3 reviewers) — all addressed:**
- GPT B1 (broken heredoc prompts) → Task 7 Step 3 rewrites to /dev/tty + tmpfile script.
- GPT B2 (ID drift) → Task 3 uses bare `pat.id`; test asserts `id == "slack-listener"` not `"slack-listener:slack-listener"`.
- GPT B3 / Gemini #4 (profile-gate untested) → test 19 added.
- Claude BLOCKER (duplicate services.<svc>:) → Task 10 single-pass merge + test 20.
- Claude HIGH (Task 1↔6 broken state) → Task 1 Step 7 bumps inspect.sh schema-emit immediately.
- Claude HIGH (Procfile severity contradiction) → Procfile reclassified to env-flag tier.
- Claude HIGH (blanket schema-bump corrupts test_10) → Task 1 Step 9 enumerates files; test_10 explicitly excluded.
- Claude MED (--quiet parsing) → feature-overrides.sh flag-scan loop over all $@.
- Claude MED (two parallel blocker gates) → unified into one collector in apply.sh.
- Claude MED (comment-out tests) → stage-B test additions moved into the tasks that make them pass.
- Claude LOW (fnmatch **) → matchers use `*.crontab` + bare `crontab`, no `**`.
- Claude LOW (doctor underspecified) → Task 13 now has concrete code + test 21.
- Claude LOW (migration UX ordering) → apply error message points to `init --rescan` only; no pre-printed diff/mv.
- Gemini HIGH (test 15 vacuous) → test 15 injects a singleton.
- Gemini HIGH (parse-compose.py mod with no task) → file structure entry removed; renderer injects deploy fresh.
- Gemini MED (cross-task ordering: --non-interactive in Task 6 before Task 7) → stage-B test moved into Task 7.
- Gemini LOW (feature-overrides cwd) → `cd "$REPO_ROOT"` added at top.

**Placeholders:** none.

**Type / name consistency:**
- Subcommands: `features`, `enable`, `disable`, `ack-host-singletons` consistent across dispatch + feature-overrides + tests.
- Profile keys: `singletons[]`, `detection_guardrails{}`, and per-entry `id` / `kind` / `evidence` / `default_in_worktree` / `severity` / `compose_service` / `disable_method` / `env_var` / `env_disabled_value` / `host_artifact` / `manual_fix_hint` used consistently between detector, renderer, apply, and feature-overrides.
- ID contract: `id` = stable `pat.id` from singleton-patterns.py. Same `id` may appear multiple times in `singletons[]` when one pattern matches multiple compose services; entries are distinguished by `compose_service`. CLI `enable <id>` / `disable <id>` toggles all entries with that id.
- Renderer return type: `compose_service_fields: dict[svc] -> {deploy?, profiles?}`, `env_lines: list[str]`, `host_blockers: list[dict]`. Apply.sh merges `compose_service_fields` into its own per-service dict before YAML emission — never appends pre-formatted YAML lines.
- State values: `enabled` / `disabled` / `acknowledged` consistent across overrides and renderer.

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-05-11-x-worktree-isolate-singletons.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

**Which approach?**
