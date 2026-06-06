# x-worktree-isolate: Enforced Singleton Lock + WhatsApp + Migration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `x-worktree-isolate` enforce mutual-exclusion of stateful singletons across parallel worktrees — replacing the declarative `singleton_owners` write with a liveness-checked, auto-stealing, `--force`-overridable claim run inside the registry lock — and add WhatsApp detection, a lazy registry migration to an enriched schema, and a `migrate` convenience subcommand.

**Architecture:** The per-repo registry's `singleton_owners` becomes an enriched map `{id: {worktree_path, branch, claimed_at}}` carrying a top-level `registry_schema: 2` marker; old flat shapes self-heal lazily on every lock-holding path. A new `xwi_claim_singleton` (replacing `xwi_set_singleton_owners`) checks the current owner, runs a tier-aware liveness test (path/slot for all tiers, plus zero-running-containers for compose tier), auto-steals dead locks, and refuses live ones unless `--force`/`--steal`. Claim and heal run only while the caller holds the existing registry lock (`apply.sh` already holds it; `enable`/`list`/`doctor`/`migrate` acquire→heal→release). Pre-existing dual-ownership detected during heal is left unowned and surfaced as `SINGLETON_CONFLICT_PREEXISTING`, refusing claims on that id until the loser runs `disable`.

**Tech Stack:** bash, python3 (PyYAML), docker compose ≥2.24, existing tests/integration/*.sh harness

---

## File Structure

| File | Create / Modify | Responsibility |
|---|---|---|
| `skills/x-worktree-isolate/scripts/allocate-ports.sh` | **Modify** | Add `xwi_registry_schema_marker`, `xwi_heal_registry` (lock-free core), `xwi_singleton_owner_*` readers, `xwi_owner_alive`, `xwi_claim_singleton`, `xwi_sync_singleton_owners`; rewrite `xwi_clear_singleton_owners_for` for the enriched shape; keep `xwi_set_singleton_owners` removed (all call sites migrated); enrich `list` to print an `owner` column. |
| `skills/x-worktree-isolate/scripts/apply.sh` | **Modify** | Move singleton claim to **before** any file write (right after lock + heal); call `xwi_sync_singleton_owners` honoring `--force`; add `--force`/`--steal` flag parsing; emit `SINGLETON_CONFLICT`/`SINGLETON_LOCK_STOLEN`/`SINGLETON_CONFLICT_PREEXISTING`. |
| `skills/x-worktree-isolate/scripts/feature-overrides.sh` | **Modify** | `enable` acquires the lock, heals, claims the id (refuse→write nothing) BEFORE writing the override file; pass `--force`/`--steal` through to the claim and to `apply`. |
| `skills/x-worktree-isolate/scripts/dispatch.sh` | **Modify** | Bump `VERSION` to `0.3.0`; route new `migrate` subcommand; document `--force`/`--steal` on `enable`/`apply` in usage. |
| `skills/x-worktree-isolate/scripts/migrate.sh` | **Create** | `migrate` subcommand: lock→heal→print pre-existing-conflict report→rescan prompt→pointer to `x-qa update`. |
| `skills/x-worktree-isolate/scripts/singleton-patterns.py` | **Modify** | Add WhatsApp Tier-1 (`whatsapp`) and Tier-2 (`whatsapp-web`) patterns. |
| `skills/x-worktree-isolate/scripts/doctor.sh` | **Modify** | Heal under lock; add a dead-lock check that flags stale singleton owners and prints the clear hint. |
| `skills/x-worktree-isolate/config.json` | **Modify** | `version` 0.2.0 → 0.3.0. |
| `skills/x-worktree-isolate/SKILL.md` | **Modify** | v0.3 migration banner; enriched-registry + enforced-claim docs; `owner` column; honest-guarantee-per-tier statement; WhatsApp row; anti-patterns; `migrate`/`--force` in workflow + detection tables. |
| `skills/x-worktree-isolate/references/singleton-patterns.md` | **Modify** | WhatsApp catalog rows in Tier 1 + Tier 2. |
| `skills/x-worktree-isolate/tests/integration/test_22_singleton_whatsapp_detection.sh` | **Create** | Drive `detect-singletons.py` over a WhatsApp fixture; assert the `whatsapp`/`whatsapp-web` ids appear. |
| `skills/x-worktree-isolate/tests/integration/test_23_registry_lazy_migration.sh` | **Create** | Old flat `singleton_owners` → enriched `registry_schema:2`, idempotent on re-run. |
| `skills/x-worktree-isolate/tests/integration/test_24_singleton_claim_enforced.sh` | **Create** | env-flag singleton: claim → second worktree refuse (`SINGLETON_CONFLICT`) → `--force` steal → release clears. |
| `skills/x-worktree-isolate/tests/integration/test_25_singleton_deadlock_autosteal.sh` | **Create** | Dead owner (path gone) → auto-steal (`SINGLETON_LOCK_STOLEN`). |
| `skills/x-worktree-isolate/tests/integration/test_26_singleton_preexisting_conflict.sh` | **Create** | Two live slots enable same id → heal leaves unowned + `SINGLETON_CONFLICT_PREEXISTING`; claim refused until `disable`. |
| `skills/x-worktree-isolate/tests/integration/test_27_singleton_compose_liveness_r3.sh` | **Create** | (docker-gated) compose-tier owner with zero running containers reads dead → auto-stolen. |
| `skills/x-worktree-isolate/tests/integration/test_28_migrate_subcommand.sh` | **Create** | `migrate` heals + reports pre-existing conflicts + prints `x-qa update` pointer. |
| `skills/x-worktree-isolate/tests/integration/test_29_version_consistency.sh` | **Create** | `dispatch` VERSION, `config.json` version, and `version` output all agree at 0.3.0. |

---

## SHARED CONTRACT — reproduce VERBATIM (see Appendix A). Function names used throughout this plan:
`xwi_heal_registry`, `xwi_claim_singleton`, `xwi_sync_singleton_owners`, `xwi_owner_alive`, `xwi_clear_singleton_owners_for`, `xwi_registry_schema_marker`. The flat-shape `xwi_set_singleton_owners` is **removed** — every call site migrates to `xwi_sync_singleton_owners`.

---

### Task 1: Registry enrichment + lazy migration core (`xwi_heal_registry`)

Establishes the enriched `singleton_owners` shape `{id: {worktree_path, branch, claimed_at}}` with `registry_schema: 2`, and a lock-free heal that upgrades old shapes and rebuilds owners from ground truth. This is the foundation every later task builds on. The heal is a **lock-free core** — callers that don't already hold the registry lock must wrap it.

**Files:**
- Modify: `skills/x-worktree-isolate/scripts/allocate-ports.sh` (add `xwi_heal_registry` after `xwi_list_slots`, ~line 290; helper readers after it)
- Test: `skills/x-worktree-isolate/tests/integration/test_23_registry_lazy_migration.sh` (Create)

- [ ] **Step 1: Write the failing migration test.** Create `tests/integration/test_23_registry_lazy_migration.sh`:
```bash
#!/usr/bin/env bash
# Test 23: old flat singleton_owners migrates lazily to enriched registry_schema:2, idempotent.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t23
trap test_teardown EXIT

MAIN="$TEST_TMP/main"
make_repo "$MAIN"
write_profile "$MAIN"
commit_profile "$MAIN"

WT="$TEST_TMP/wt23"
make_worktree "$MAIN" "$WT" "feat-x"

# Seed an OLD-shape registry by hand: flat singleton_owners, NO registry_schema marker.
REG_DIR="$(cd "$WT" && . "$SKILL_DIR/scripts/allocate-ports.sh" && xwi_registry_dir)"
REG="$REG_DIR/registry.json"
cat > "$REG" <<JSON
{"slots": [{"slot": 0, "worktree_path": "$WT", "branch": "feat-x", "ports": {}, "data_dir": ""}],
 "singleton_owners": {"slack-listener": "$WT"}}
JSON

# Heal under lock (apply triggers heal as its first registry action).
( cd "$WT" && bash "$DISPATCH" apply --quiet )

# Assert: registry_schema:2 marker present, owner enriched to object with worktree_path.
python3 - "$REG" "$WT" <<'PY'
import json, sys
reg, wt = sys.argv[1], sys.argv[2]
d = json.load(open(reg))
assert d.get("registry_schema") == 2, f"expected registry_schema:2, got {d.get('registry_schema')}"
owners = d.get("singleton_owners", {})
# slack-listener was not in a profile/feature-overrides, so heal drops it (ground-truth rebuild).
assert "slack-listener" not in owners, f"stale owner should be dropped by heal, got {owners}"
print("ok-shape")
PY

# Idempotency: re-run apply, registry_schema stays 2, no duplication / crash.
( cd "$WT" && bash "$DISPATCH" apply --quiet )
python3 - "$REG" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
assert d.get("registry_schema") == 2
print("ok-idempotent")
PY

pass "test 23 — registry lazy migration to schema 2, idempotent"
```

- [ ] **Step 2: Run the test, expect FAIL.**
```
bash skills/x-worktree-isolate/tests/integration/test_23_registry_lazy_migration.sh
# EXPECTED FAIL: AssertionError: expected registry_schema:2, got None
```

- [ ] **Step 3: Add the heal core + schema marker + owner readers to `allocate-ports.sh`.** Insert after `xwi_list_slots` (after line 290), before the `# --- Singleton ownership` comment:
```bash
# --- Registry schema marker ---
XWI_REGISTRY_SCHEMA=2

# Lock-free registry heal. ASSUMES the caller already holds the registry lock.
# 1. Stamp registry_schema:2 (idempotent).
# 2. Upgrade flat singleton_owners {id: path} → {id: {worktree_path, branch, claimed_at}}.
# 3. Rebuild owners from GROUND TRUTH: each live slot's feature-overrides.local.json.
#    - live slot = worktree_path is a dir AND still has a registry slot.
#    - if 2+ live slots enable the same id → leave it UNOWNED (pre-existing conflict;
#      surfaced by callers via xwi_claim_singleton refusal). heal never elects a winner.
xwi_heal_registry() {
  local file
  file="$(xwi_registry_file)" || return 1
  [[ -f "$file" ]] || return 0
  python3 - "$file" "$XWI_REGISTRY_SCHEMA" <<'PY'
import json, os, sys, time
path, schema = sys.argv[1], int(sys.argv[2])
try:
    data = json.load(open(path))
except json.JSONDecodeError:
    sys.exit(0)  # malformed registry: leave for release.sh's explicit error path.
slots = data.get("slots", []) or []
now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

def overrides_for(slot):
    wt = slot.get("worktree_path") or ""
    if not os.path.isdir(wt):
        return None  # dead slot.
    ov = os.path.join(wt, ".worktree-isolate", "feature-overrides.local.json")
    enabled, updated = [], now
    if os.path.isfile(ov):
        try:
            o = json.load(open(ov))
            updated = o.get("updated_at") or now
            for e in o.get("overrides", []):
                if isinstance(e, dict) and e.get("state") == "enabled" and e.get("id"):
                    enabled.append(e["id"])
        except (OSError, json.JSONDecodeError):
            pass
    return {"branch": slot.get("branch") or "", "wt": wt, "enabled": enabled, "updated_at": updated}

# Ground-truth: id -> list of (wt, branch, claimed_at) claiming it.
claims = {}
for s in slots:
    info = overrides_for(s)
    if info is None:
        continue
    for sid in info["enabled"]:
        claims.setdefault(sid, []).append(
            {"worktree_path": info["wt"], "branch": info["branch"], "claimed_at": info["updated_at"]}
        )

owners = {}
for sid, lst in claims.items():
    if len(lst) == 1:
        owners[sid] = lst[0]
    # len >= 2 → pre-existing conflict → leave UNOWNED (claim refuses, migrate reports).

data["registry_schema"] = schema
data["singleton_owners"] = owners
tmp = path + ".tmp"
with open(tmp, "w") as fh:
    json.dump(data, fh, indent=2)
os.replace(tmp, path)
PY
}

# Echo the JSON object for a singleton owner (or empty string if unowned).
xwi_singleton_owner_json() {
  local sid="$1"
  python3 - "$sid" "$(xwi_registry_file)" <<'PY'
import json, os, sys
sid, path = sys.argv[1], sys.argv[2]
if not os.path.isfile(path): sys.exit(0)
try: data = json.load(open(path))
except json.JSONDecodeError: sys.exit(0)
o = (data.get("singleton_owners") or {}).get(sid)
if o: print(json.dumps(o))
PY
}

# Report ids enabled by 2+ live slots (pre-existing conflicts). One line per id:
#   <id>|<branch1>@<path1>,<branch2>@<path2>
xwi_preexisting_conflicts() {
  python3 - "$(xwi_registry_file)" <<'PY'
import json, os, sys
path = sys.argv[1]
if not os.path.isfile(path): sys.exit(0)
try: data = json.load(open(path))
except json.JSONDecodeError: sys.exit(0)
claims = {}
for s in data.get("slots", []) or []:
    wt = s.get("worktree_path") or ""
    if not os.path.isdir(wt): continue
    ov = os.path.join(wt, ".worktree-isolate", "feature-overrides.local.json")
    if not os.path.isfile(ov): continue
    try: o = json.load(open(ov))
    except (OSError, json.JSONDecodeError): continue
    for e in o.get("overrides", []):
        if isinstance(e, dict) and e.get("state") == "enabled" and e.get("id"):
            claims.setdefault(e["id"], []).append(f"{s.get('branch') or ''}@{wt}")
for sid, owners in sorted(claims.items()):
    if len(owners) >= 2:
        print(f"{sid}|{','.join(owners)}")
PY
}
```

- [ ] **Step 4: Run the test, expect PASS.**
```
bash skills/x-worktree-isolate/tests/integration/test_23_registry_lazy_migration.sh
# EXPECTED: ok-shape / ok-idempotent / PASS: test 23 — registry lazy migration to schema 2, idempotent
```
(Note: this test will only pass once `apply.sh` calls `xwi_heal_registry` — wired in Task 3 Step 3. If running Task 1 in isolation first, verify the heal core by sourcing it directly per Step 5; the test goes green after Task 3.)

- [ ] **Step 5: Verify heal core in isolation (no apply dependency) before moving on.**
```
cd /tmp && rm -rf xwiheal && mkdir xwiheal && cd xwiheal
printf '{"slots":[],"singleton_owners":{"x":"/gone"}}' > reg.json
XWI_REGISTRY_SCHEMA=2 python3 - reg.json 2 <<'PY'
import json,sys; d=json.load(open(sys.argv[1])); print("loaded ok", d.get("singleton_owners"))
PY
# EXPECTED: loaded ok {'x': '/gone'}  (confirms the inline python parses; full heal verified by test 23)
```

- [ ] **Step 6: Commit.**
```
git add skills/x-worktree-isolate/scripts/allocate-ports.sh skills/x-worktree-isolate/tests/integration/test_23_registry_lazy_migration.sh
git commit -m "feat(x-worktree-isolate): enriched singleton_owners + lazy registry heal (registry_schema:2)"
```

---

### Task 2: Liveness check + enforced claim (`xwi_owner_alive`, `xwi_claim_singleton`, `xwi_sync_singleton_owners`)

Adds the tier-aware liveness rule and the claim primitive that refuses live owners (unless `--force`), auto-steals dead ones, and refuses pre-existing-conflict ids. Also the SYNC primitive (set this worktree's owned set to exactly the enabled ids — not additive). Pure helpers here; wiring into `apply`/`enable` is Tasks 3–4. All run lock-free (caller holds the lock).

**Files:**
- Modify: `skills/x-worktree-isolate/scripts/allocate-ports.sh` (add after the Task-1 readers; rewrite `xwi_clear_singleton_owners_for`; delete `xwi_set_singleton_owners`)
- Test: covered end-to-end by Task 4's `test_24` / Task 5's `test_25` (the helpers have no standalone subcommand). This task's verification is a direct-source smoke test (Step 4).

- [ ] **Step 1: Add `xwi_owner_alive`.** Insert after `xwi_preexisting_conflicts` in `allocate-ports.sh`:
```bash
# Liveness test for a singleton owner. Args: owner_json tier owner_compose_project
#   DEAD when: owner worktree_path is gone from disk; OR no longer holds a registry slot
#     (ALL tiers); OR (compose tier only) COMPOSE_PROJECT_NAME has zero running containers.
#   env-flag / host tiers: path + slot signal only.
# Returns 0 = ALIVE, 1 = DEAD.
xwi_owner_alive() {
  local owner_json="$1" tier="$2" proj="$3"
  local owner_path
  owner_path="$(printf '%s' "$owner_json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("worktree_path",""))')"
  [[ -n "$owner_path" && -d "$owner_path" ]] || return 1            # path gone → dead (all tiers)
  # Still holds a registry slot?
  local has_slot
  has_slot="$(python3 - "$owner_path" "$(xwi_registry_file)" <<'PY'
import json, os, sys
wt, path = sys.argv[1], sys.argv[2]
if not os.path.isfile(path): print("0"); sys.exit(0)
try: d = json.load(open(path))
except json.JSONDecodeError: print("0"); sys.exit(0)
print("1" if any(s.get("worktree_path") == wt for s in d.get("slots", []) or []) else "0")
PY
)"
  [[ "$has_slot" == "1" ]] || return 1                              # no slot → dead (all tiers)
  if [[ "$tier" == "compose-service" && -n "$proj" ]]; then
    if command -v docker >/dev/null 2>&1; then
      local running
      running="$(docker ps --filter "label=com.docker.compose.project=${proj}" -q 2>/dev/null | head -n1)"
      [[ -n "$running" ]] || return 1                               # zero containers → dead (R3)
    fi
    # no docker → cannot prove zero-containers; fall back to path/slot signal = ALIVE.
  fi
  return 0
}
```

- [ ] **Step 2: Add `xwi_claim_singleton`.** Insert after `xwi_owner_alive`. This is the enforced replacement for the old declarative write. It claims ONE id; callers loop over ids. Tier + compose-project are passed by the caller (derived from the profile + COMPOSE_PROJECT_NAME). Emits notices; returns 0 = claimed, 2 = refused (live or pre-existing).
```bash
# Claim ONE singleton id for this worktree. ASSUMES caller holds the registry lock
# AND has already run xwi_heal_registry.
# Args: id worktree_path branch tier compose_project force(0|1)
# Returns: 0 claimed; 2 refused (SINGLETON_CONFLICT or SINGLETON_CONFLICT_PREEXISTING).
xwi_claim_singleton() {
  local sid="$1" wpath="$2" branch="$3" tier="$4" proj="$5" force="${6:-0}"

  # Pre-existing conflict: id enabled by 2+ live slots → unowned by heal → refuse.
  local pre
  pre="$(xwi_preexisting_conflicts | grep -F "${sid}|" || true)"
  if [[ -n "$pre" ]]; then
    local owners="${pre#*|}"
    echo "SINGLETON_CONFLICT_PREEXISTING=${sid} owners=${owners}" >&2
    echo "  Resolve: run 'x-worktree-isolate disable ${sid}' in the loser worktree, then retry." >&2
    return 2
  fi

  local owner_json owner_path owner_branch
  owner_json="$(xwi_singleton_owner_json "$sid")"
  if [[ -n "$owner_json" ]]; then
    owner_path="$(printf '%s' "$owner_json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("worktree_path",""))')"
    owner_branch="$(printf '%s' "$owner_json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("branch",""))')"
    if [[ "$owner_path" == "$wpath" ]]; then
      :  # owned by self → re-claim (refresh claimed_at below).
    elif xwi_owner_alive "$owner_json" "$tier" "$proj"; then
      if [[ "$force" -eq 1 ]]; then
        echo "SINGLETON_LOCK_STOLEN=${sid} from=${owner_branch}" >&2
      else
        echo "SINGLETON_CONFLICT=${sid} owner=${owner_branch}@${owner_path}" >&2
        return 2
      fi
    else
      echo "SINGLETON_LOCK_STOLEN=${sid} from=${owner_branch}" >&2   # dead → auto-steal
    fi
  fi

  # Write the enriched owner entry.
  python3 - "$sid" "$wpath" "$branch" "$(xwi_registry_file)" "$XWI_REGISTRY_SCHEMA" <<'PY'
import json, os, sys, time
sid, wpath, branch, path, schema = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], int(sys.argv[5])
data = {"slots": []}
if os.path.isfile(path):
    try: data = json.load(open(path))
    except json.JSONDecodeError: data = {"slots": []}
owners = data.get("singleton_owners") or {}
owners[sid] = {"worktree_path": wpath, "branch": branch,
               "claimed_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
data["singleton_owners"] = owners
data["registry_schema"] = schema
tmp = path + ".tmp"
with open(tmp, "w") as fh: json.dump(data, fh, indent=2)
os.replace(tmp, path)
PY
  return 0
}
```

- [ ] **Step 3: Add `xwi_sync_singleton_owners` + rewrite `xwi_clear_singleton_owners_for`; delete `xwi_set_singleton_owners`.** Replace the entire block from `# --- Singleton ownership (declarative bookkeeping) ---` (line 292) through `xwi_clear_singleton_owners_for` (line 319) with:
```bash
# --- Singleton ownership (enforced) ---
# Set this worktree's owned set to EXACTLY $ids (SYNC, not additive):
#   - claim every id in $ids (refuse→propagate exit 2);
#   - drop self-owned ids NOT in $ids (this is how `disable` releases ownership).
# Args: ids_csv worktree_path branch tiers_json force(0|1)
#   tiers_json maps id -> {"tier":..., "proj":...} so the claim can run liveness.
# ASSUMES caller holds the lock AND has run xwi_heal_registry.
# Returns 0 if all claims succeed; 2 if any id is refused (caller decides hard-fail).
xwi_sync_singleton_owners() {
  local ids_csv="$1" wpath="$2" branch="$3" tiers_json="$4" force="${5:-0}"
  local rc=0 sid tier proj
  # Drop self-owned ids not in the new set.
  python3 - "$ids_csv" "$wpath" "$(xwi_registry_file)" <<'PY'
import json, os, sys
ids = set(i for i in sys.argv[1].split(",") if i)
wpath, path = sys.argv[2], sys.argv[3]
if not os.path.isfile(path): sys.exit(0)
try: data = json.load(open(path))
except json.JSONDecodeError: sys.exit(0)
owners = data.get("singleton_owners") or {}
owners = {k: v for k, v in owners.items()
          if not (isinstance(v, dict) and v.get("worktree_path") == wpath and k not in ids)}
data["singleton_owners"] = owners
tmp = path + ".tmp"
with open(tmp, "w") as fh: json.dump(data, fh, indent=2)
os.replace(tmp, path)
PY
  # Claim each enabled id.
  local IFS=','
  for sid in $ids_csv; do
    [[ -n "$sid" ]] || continue
    tier="$(printf '%s' "$tiers_json" | python3 -c 'import json,sys; print((json.load(sys.stdin).get(sys.argv[1]) or {}).get("tier",""))' "$sid")"
    proj="$(printf '%s' "$tiers_json" | python3 -c 'import json,sys; print((json.load(sys.stdin).get(sys.argv[1]) or {}).get("proj",""))' "$sid")"
    xwi_claim_singleton "$sid" "$wpath" "$branch" "$tier" "$proj" "$force" || rc=2
  done
  unset IFS
  return "$rc"
}

xwi_clear_singleton_owners_for() {
  local wpath="$1"
  python3 - "$wpath" "$(xwi_registry_file)" <<'PY'
import json, os, sys
wpath, path = sys.argv[1], sys.argv[2]
if not os.path.isfile(path): sys.exit(0)
try: data = json.load(open(path))
except json.JSONDecodeError: sys.exit(0)
owners = data.get("singleton_owners") or {}
owners = {k: v for k, v in owners.items()
          if not (isinstance(v, dict) and v.get("worktree_path") == wpath)}
data["singleton_owners"] = owners
tmp = path + ".tmp"
with open(tmp, "w") as fh: json.dump(data, fh, indent=2)
os.replace(tmp, path)
PY
}
```

- [ ] **Step 4: Smoke-test the helpers by direct source.** (No subcommand yet; verify no syntax errors + claim/refuse logic.)
```
cd /tmp && rm -rf xwiclaim && mkdir -p xwiclaim/wtA && cd xwiclaim
export XDG_CONFIG_HOME=/tmp/xwiclaim/xdg && mkdir -p "$XDG_CONFIG_HOME"
(cd /tmp/xwiclaim/wtA && git init -q -b main && git config user.email t@t && git config user.name t && git commit -q --allow-empty -m init)
bash -c '
  . /Users/randytran/Codes/x-skills/skills/x-worktree-isolate/scripts/allocate-ports.sh
  cd /tmp/xwiclaim/wtA
  reg="$(xwi_registry_file)"; printf "{\"slots\":[{\"slot\":0,\"worktree_path\":\"/tmp/xwiclaim/wtA\",\"branch\":\"main\"}]}" > "$reg"
  xwi_heal_registry
  xwi_claim_singleton "telegram-bot" "/tmp/xwiclaim/wtA" "main" "env-flag" "" 0 && echo "CLAIM-OK"
  # Second owner-by-other, alive (path exists) → refuse.
  xwi_claim_singleton "telegram-bot" "/tmp/xwiclaim/wtOTHER" "feat" "env-flag" "" 0; echo "rc=$?"
'
# EXPECTED: CLAIM-OK ; then SINGLETON_CONFLICT=telegram-bot owner=main@/tmp/xwiclaim/wtA on stderr ; rc=2
```

- [ ] **Step 5: Confirm no stray references to the deleted function.**
```
grep -rn "xwi_set_singleton_owners" skills/x-worktree-isolate/scripts/
# EXPECTED: no output (apply.sh/release.sh call sites migrated in Tasks 3 & 6; if any remain, they break — fix before commit)
```
(release.sh still calls `xwi_clear_singleton_owners_for` — that name is retained, so release is unaffected. apply.sh's `xwi_set_singleton_owners` call is migrated in Task 3.)

- [ ] **Step 6: Commit.**
```
git add skills/x-worktree-isolate/scripts/allocate-ports.sh
git commit -m "feat(x-worktree-isolate): enforced xwi_claim_singleton + tier-aware liveness + SYNC owners"
```

---

### Task 3: Wire enforced claim into `apply.sh` (move BEFORE file writes, add `--force`/`--steal`)

The claim must run right after lock acquisition + heal, before any port allocation or file write — a refusal must leave the worktree untouched. Replace the trailing `xwi_set_singleton_owners` call (apply.sh:494) with an early `xwi_sync_singleton_owners`.

**Files:**
- Modify: `skills/x-worktree-isolate/scripts/apply.sh` (flag parse ~lines 11–32; lock+heal+claim block after line 154; delete the trailing claim at lines 476–494)
- Test: green via `test_23` (Task 1) once heal is wired; refusal path covered by `test_24` (Task 4)

- [ ] **Step 1: Confirm test_23 currently FAILS for the right reason** (heal not yet called by apply).
```
bash skills/x-worktree-isolate/tests/integration/test_23_registry_lazy_migration.sh
# EXPECTED FAIL: expected registry_schema:2, got None  (apply hasn't healed yet)
```

- [ ] **Step 2: Add `--force`/`--steal` flag parsing.** In apply.sh's arg loop, add the var declaration (after `DRY_RUN=0`, line 14):
```bash
FORCE=0
```
and inside the `for arg in "$@"; do case "$arg" in` block, add before `--help|-h)`:
```bash
    --force|--steal)      FORCE=1 ;;
```
and update the `--help` heredoc to list:
```
  --force, --steal       steal a live singleton lock from another worktree
```

- [ ] **Step 3: Insert heal + early enforced claim right after lock acquisition.** After line 154 (`trap 'xwi_release_lock' EXIT`), and BEFORE `SLOT="$(xwi_allocate_slot "$REPO_ROOT")"` (line 156), insert:
```bash
# Self-heal the registry on every apply (idempotent; we hold the lock).
xwi_heal_registry

# Compute project name early (needed for both the claim and the render below).
BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
sanitize() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -c '[:alnum:]_-' '-' | sed 's/-\{2,\}/-/g; s/^-//; s/-$//'; }
REPO_NAME="$(basename "$(dirname "$ABS_COMMON")")"
REPO_SLUG="$(sanitize "$REPO_NAME")"
BRANCH_SLUG="$(sanitize "$BRANCH")"
PROJECT_NAME="${REPO_SLUG}-${BRANCH_SLUG}"

# Enforced singleton claim BEFORE any file write — a refusal leaves the worktree untouched.
CLAIM_PLAN="$(python3 - "$PROFILE" "$OVERRIDES_FILE" "$PROJECT_NAME" <<'PY'
import json, os, sys
prof = json.load(open(sys.argv[1]))
ov_path, proj = sys.argv[2], sys.argv[3]
overrides = {}
if os.path.isfile(ov_path):
    try: overrides = {o["id"]: o["state"] for o in json.load(open(ov_path)).get("overrides", []) if isinstance(o, dict) and "id" in o and "state" in o}
    except (OSError, json.JSONDecodeError): pass
ids, tiers = [], {}
for s in prof.get("singletons", []) or []:
    sid = s["id"]
    state = overrides.get(sid, s.get("default_in_worktree", "disabled"))
    if state != "enabled": continue
    if sid not in ids: ids.append(sid)
    # compose-tier liveness needs THIS owner's COMPOSE_PROJECT_NAME.
    tiers[sid] = {"tier": s.get("kind", ""), "proj": proj if s.get("kind") == "compose-service" else ""}
print(json.dumps({"ids": ids, "tiers": tiers}))
PY
)"
ENABLED_IDS="$(printf '%s' "$CLAIM_PLAN" | python3 -c 'import json,sys; print(",".join(json.load(sys.stdin)["ids"]))')"
TIERS_JSON="$(printf '%s' "$CLAIM_PLAN" | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin)["tiers"]))')"
if ! xwi_sync_singleton_owners "$ENABLED_IDS" "$REPO_ROOT" "$BRANCH" "$TIERS_JSON" "$FORCE"; then
  echo "x-worktree-isolate apply: refused to claim one or more singletons (see notice above)." >&2
  echo "  Re-run with --force to steal a live lock, or disable the conflicting singleton." >&2
  exit 2
fi
```

- [ ] **Step 4: Delete the now-redundant late computation + trailing claim.** Remove the duplicate `BRANCH=`/`sanitize`/`PROJECT_NAME` block (lines 144–150 — now computed early in Step 3) and the entire trailing singleton block lines 476–494 (the `# Singleton ownership bookkeeping (declarative...)` comment through `xwi_set_singleton_owners "$REPO_ROOT" "$ENABLED_IDS"`). The early claim replaces it.

- [ ] **Step 5: Run test_23 — expect PASS.**
```
bash skills/x-worktree-isolate/tests/integration/test_23_registry_lazy_migration.sh
# EXPECTED: ok-shape / ok-idempotent / PASS: test 23
```

- [ ] **Step 6: Run the full existing suite — confirm no regressions (esp. test_16 owner-key assertions, test_02/04 apply).**
```
bash skills/x-worktree-isolate/tests/integration/run-all.sh
# EXPECTED: summary FAIL: 0  (test_16 reads only owner KEYS via `"node-cron" in o`, survives the enriched shape)
```

- [ ] **Step 7: Commit.**
```
git add skills/x-worktree-isolate/scripts/apply.sh
git commit -m "feat(x-worktree-isolate): enforce singleton claim before file writes in apply; --force/--steal"
```

---

### Task 4: Wire enforced claim into `enable` (claim BEFORE writing the override) + claim-enforcement test

Today `enable` writes `feature-overrides.local.json` (state=enabled) then calls `apply.sh`. If the claim then refuses, the override already says enabled → invariant violated. Fix: `enable` acquires the lock, heals, claims the id FIRST (refuse→write nothing, exit nonzero), then writes the override, releases the lock, and calls `apply` (whose own claim self-claims idempotently — no child-process deadlock because the lock is released first). `disable` rides on apply's owner-sync and needs no change.

**Files:**
- Modify: `skills/x-worktree-isolate/scripts/feature-overrides.sh` (the `enable|disable|ack-host-singletons)` branch, lines 58–115)
- Test: `skills/x-worktree-isolate/tests/integration/test_24_singleton_claim_enforced.sh` (Create)

- [ ] **Step 1: Write the failing enforcement test.** Create `tests/integration/test_24_singleton_claim_enforced.sh`. Uses an **env-flag** singleton (path-only liveness = deterministic, docker-free):
```bash
#!/usr/bin/env bash
# Test 24: env-flag singleton — claim → second worktree refuse → --force steal → release clears.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t24
trap test_teardown EXIT

MAIN="$TEST_TMP/main"
make_repo "$MAIN"
mkdir -p "$MAIN/.worktree-isolate"
cat > "$MAIN/.worktree-isolate/profile.json" <<'JSON'
{
  "schema": 2, "stack": "docker-compose",
  "port_strategy": {"scan_range": [18000, 29999], "ports": []},
  "services_to_strip": [], "data_dirs": [], "global_label_warnings": [], "single_worktree_profiles": [],
  "detection_guardrails": {"scan_max_depth":4,"scan_max_file_bytes":1048576,"exclude_dirs":[],"exclude_globs":[]},
  "singletons": [
    {"id":"node-cron","kind":"env-flag","evidence":["src/jobs.js:1"],"rationale":"scheduler","default_in_worktree":"disabled","severity":"warning","env_var":"RUN_SCHEDULER","env_disabled_value":"false"}
  ]
}
JSON
commit_profile "$MAIN"

WTA="$TEST_TMP/wtA"; make_worktree "$MAIN" "$WTA" "feat-a"
WTB="$TEST_TMP/wtB"; make_worktree "$MAIN" "$WTB" "feat-b"
( cd "$WTA" && bash "$DISPATCH" apply --quiet )
( cd "$WTB" && bash "$DISPATCH" apply --quiet )

# 1) wtA claims node-cron.
( cd "$WTA" && bash "$DISPATCH" enable node-cron --quiet )

# 2) wtB enable refuses (live owner) → SINGLETON_CONFLICT on stderr, nonzero exit, NO override written for wtB.
set +e
errB="$( cd "$WTB" && bash "$DISPATCH" enable node-cron --quiet 2>&1 )"
rcB=$?
set -e
assert_eq "1" "$([ "$rcB" -ne 0 ] && echo 1 || echo 0)" "wtB enable must fail while wtA owns the lock"
assert_contains "$errB" "SINGLETON_CONFLICT=node-cron" "must emit SINGLETON_CONFLICT"
# wtB feature-overrides must NOT show node-cron enabled (invariant: enabled⇒owned).
ovB="$WTB/.worktree-isolate/feature-overrides.local.json"
if [ -f "$ovB" ]; then
  case "$(cat "$ovB")" in
    *'"id": "node-cron"'*'"state": "enabled"'*) fail "refused claim must not leave node-cron enabled in wtB" ;;
  esac
fi

# 3) wtB --force steals the live lock.
errB2="$( cd "$WTB" && bash "$DISPATCH" enable node-cron --force --quiet 2>&1 )"
assert_contains "$errB2" "SINGLETON_LOCK_STOLEN=node-cron" "force must steal with SINGLETON_LOCK_STOLEN"
reg="$XDG_CONFIG_HOME/worktree-isolate"
owner_path="$(python3 -c '
import json,os,sys
root=sys.argv[1]
for rid in os.listdir(root):
    f=os.path.join(root,rid,"registry.json")
    if not os.path.isfile(f): continue
    o=json.load(open(f)).get("singleton_owners",{}).get("node-cron")
    if o: print(o.get("worktree_path",""))
' "$reg")"
assert_eq "$WTB" "$owner_path" "after --force, wtB must own node-cron"

# 4) release clears wtB ownership.
( cd "$WTB" && bash "$DISPATCH" release --quiet )
owner_after="$(python3 -c '
import json,os,sys
root=sys.argv[1]; out=""
for rid in os.listdir(root):
    f=os.path.join(root,rid,"registry.json")
    if not os.path.isfile(f): continue
    if "node-cron" in json.load(open(f)).get("singleton_owners",{}): out="present"
print(out)
' "$reg")"
assert_eq "" "$owner_after" "release must clear node-cron ownership"

pass "test 24 — enforced claim: refuse / --force steal / release clears"
```

- [ ] **Step 2: Run the test, expect FAIL** (today's `enable` writes the override before any claim, so wtB succeeds and the invariant breaks).
```
bash skills/x-worktree-isolate/tests/integration/test_24_singleton_claim_enforced.sh
# EXPECTED FAIL: "wtB enable must fail while wtA owns the lock"
```

- [ ] **Step 3: Add `--force`/`--steal` parsing to `feature-overrides.sh`.** Declare `FORCE=0` after `QUIET=0` (line 13), and in the arg loop (lines 15–20) add to the `case`:
```bash
    --force|--steal) FORCE=1 ;;
```

- [ ] **Step 4: Make `enable` claim before writing the override.** In the `enable|disable|ack-host-singletons)` branch, the override is written by the inline python at lines 69–109. Insert AFTER the `NEW_STATE` case block (after line 68) and BEFORE the python heredoc (line 69):
```bash
    # ENABLE only: win the claim BEFORE writing the override (enabled ⇒ owned invariant).
    if [[ "$SUB" == "enable" ]]; then
      # Resolve tier + this worktree's COMPOSE_PROJECT_NAME for liveness.
      COMMON_DIR_FO="$(git rev-parse --git-common-dir)"
      ABS_COMMON_FO="$(cd "$REPO_ROOT" && cd "$COMMON_DIR_FO" && pwd -P)"
      _sanitize_fo() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -c '[:alnum:]_-' '-' | sed 's/-\{2,\}/-/g; s/^-//; s/-$//'; }
      BRANCH_FO="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
      PROJECT_NAME_FO="$(_sanitize_fo "$(basename "$(dirname "$ABS_COMMON_FO")")")-$(_sanitize_fo "$BRANCH_FO")"
      TIER_FO="$(python3 -c 'import json,sys; b={s["id"]:s for s in json.load(open(sys.argv[1])).get("singletons",[]) or []}; print(b.get(sys.argv[2],{}).get("kind",""))' "$PROFILE" "$feature_id")"
      PROJ_FO=""; [[ "$TIER_FO" == "compose-service" ]] && PROJ_FO="$PROJECT_NAME_FO"
      # shellcheck source=allocate-ports.sh
      . "$SCRIPT_DIR/allocate-ports.sh"
      xwi_acquire_lock || exit 1
      xwi_heal_registry
      if ! xwi_claim_singleton "$feature_id" "$REPO_ROOT" "$BRANCH_FO" "$TIER_FO" "$PROJ_FO" "$FORCE"; then
        xwi_release_lock
        echo "x-worktree-isolate enable: refused (see notice above). Use --force to steal a live lock." >&2
        exit 2
      fi
      xwi_release_lock   # release BEFORE apply (child process) to avoid lock contention.
    fi
```
> Note: `xwi_claim_singleton` writes the owner immediately; the subsequent `apply` (Step-5 call) re-claims idempotently (owned-by-self → refresh). Releasing the lock here is required — `apply.sh` is a child process with a different `$$` and would otherwise spin on the parent-held lock.

- [ ] **Step 5: Pass `--force` through to the `apply` re-render call.** The block at lines 110–114 calls apply. Replace with:
```bash
    FORCE_ARG=(); [[ "$FORCE" -eq 1 ]] && FORCE_ARG=(--force)
    if [[ "$QUIET" -eq 1 ]]; then
      bash "$SCRIPT_DIR/apply.sh" --quiet --if-profile-exists "${FORCE_ARG[@]}"
    else
      bash "$SCRIPT_DIR/apply.sh" --if-profile-exists "${FORCE_ARG[@]}"
    fi
```

- [ ] **Step 6: Run test_24, expect PASS; then full suite.**
```
bash skills/x-worktree-isolate/tests/integration/test_24_singleton_claim_enforced.sh
# EXPECTED: PASS: test 24 — enforced claim: refuse / --force steal / release clears
bash skills/x-worktree-isolate/tests/integration/run-all.sh
# EXPECTED: summary FAIL: 0
```

- [ ] **Step 7: Commit.**
```
git add skills/x-worktree-isolate/scripts/feature-overrides.sh skills/x-worktree-isolate/tests/integration/test_24_singleton_claim_enforced.sh
git commit -m "feat(x-worktree-isolate): enable claims singleton before writing override; --force passthrough"
```

---

### Task 5: Dead-lock auto-steal test (path-gone)

Verifies liveness: an owner whose `worktree_path` no longer exists on disk is dead → the next claim auto-steals with `SINGLETON_LOCK_STOLEN`. No new code (logic landed in Task 2); this is the missing-coverage test for the all-tiers path signal. The test drives `xwi_claim_singleton` directly (sourcing `allocate-ports.sh`, matching the existing test style) so the auto-steal branch is exercised deterministically without heal pre-dropping the owner.

**Files:**
- Test: `skills/x-worktree-isolate/tests/integration/test_25_singleton_deadlock_autosteal.sh` (Create)

- [ ] **Step 1: Write the test.**
```bash
#!/usr/bin/env bash
# Test 25: dead owner (worktree_path removed) → next claim auto-steals (SINGLETON_LOCK_STOLEN).
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t25
trap test_teardown EXIT

MAIN="$TEST_TMP/main"
make_repo "$MAIN"
mkdir -p "$MAIN/.worktree-isolate"
cat > "$MAIN/.worktree-isolate/profile.json" <<'JSON'
{
  "schema": 2, "stack": "docker-compose",
  "port_strategy": {"scan_range": [18000, 29999], "ports": []},
  "services_to_strip": [], "data_dirs": [], "global_label_warnings": [], "single_worktree_profiles": [],
  "detection_guardrails": {"scan_max_depth":4,"scan_max_file_bytes":1048576,"exclude_dirs":[],"exclude_globs":[]},
  "singletons": [
    {"id":"node-cron","kind":"env-flag","evidence":["src/jobs.js:1"],"rationale":"scheduler","default_in_worktree":"disabled","severity":"warning","env_var":"RUN_SCHEDULER","env_disabled_value":"false"}
  ]
}
JSON
commit_profile "$MAIN"

WTA="$TEST_TMP/wtA"; make_worktree "$MAIN" "$WTA" "feat-a"
WTB="$TEST_TMP/wtB"; make_worktree "$MAIN" "$WTB" "feat-b"
( cd "$WTA" && bash "$DISPATCH" apply --quiet )
( cd "$WTB" && bash "$DISPATCH" apply --quiet )

# Simulate a crashed/removed worktree: nuke wtA's dir, then seed a present-in-registry-but-
# path-gone owner and claim directly so the auto-steal branch is deterministic.
rm -rf "$WTA"
( cd "$WTB" && bash -c '
  . "'"$SKILL_DIR"'/scripts/allocate-ports.sh"
  reg="$(xwi_registry_file)"
  python3 - "$reg" "'"$WTA"'" <<PY
import json,sys
reg,wta=sys.argv[1],sys.argv[2]
d=json.load(open(reg))
d.setdefault("singleton_owners",{})["node-cron"]={"worktree_path":wta,"branch":"feat-a","claimed_at":"2026-01-01T00:00:00Z"}
json.dump(d,open(reg,"w"),indent=2)
PY
  xwi_acquire_lock
  xwi_claim_singleton node-cron "'"$WTB"'" feat-b env-flag "" 0
  xwi_release_lock
' 2>"$TEST_TMP/err25" )
assert_contains "$(cat "$TEST_TMP/err25")" "SINGLETON_LOCK_STOLEN=node-cron" "dead owner must be auto-stolen"

reg="$(cd "$WTB" && . "$SKILL_DIR/scripts/allocate-ports.sh" && xwi_registry_file)"
owner_path="$(python3 -c '
import json,sys
o=json.load(open(sys.argv[1]))["singleton_owners"].get("node-cron",{})
print(o.get("worktree_path",""))
' "$reg")"
assert_eq "$WTB" "$owner_path" "after auto-steal, wtB must own node-cron"

pass "test 25 — dead-lock auto-steal on path-gone owner"
```

- [ ] **Step 2: Run the test, expect PASS** (logic already implemented in Task 2).
```
bash skills/x-worktree-isolate/tests/integration/test_25_singleton_deadlock_autosteal.sh
# EXPECTED: PASS: test 25 — dead-lock auto-steal on path-gone owner
```

- [ ] **Step 3: Commit.**
```
git add skills/x-worktree-isolate/tests/integration/test_25_singleton_deadlock_autosteal.sh
git commit -m "test(x-worktree-isolate): dead-lock auto-steal on path-gone owner"
```

---

### Task 6: Pre-existing conflict — refuse-until-resolved (test + verification)

Verifies D4: when two LIVE worktrees both have the same singleton enabled, heal leaves it unowned and the claim refuses with `SINGLETON_CONFLICT_PREEXISTING` until the loser runs `disable`. Logic landed in Tasks 1–2; this is the integration coverage.

**Files:**
- Test: `skills/x-worktree-isolate/tests/integration/test_26_singleton_preexisting_conflict.sh` (Create)

- [ ] **Step 1: Write the test.**
```bash
#!/usr/bin/env bash
# Test 26: two live worktrees both enabled same singleton → heal leaves unowned +
# SINGLETON_CONFLICT_PREEXISTING; claim refused until one runs disable.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t26
trap test_teardown EXIT

MAIN="$TEST_TMP/main"
make_repo "$MAIN"
mkdir -p "$MAIN/.worktree-isolate"
cat > "$MAIN/.worktree-isolate/profile.json" <<'JSON'
{
  "schema": 2, "stack": "docker-compose",
  "port_strategy": {"scan_range": [18000, 29999], "ports": []},
  "services_to_strip": [], "data_dirs": [], "global_label_warnings": [], "single_worktree_profiles": [],
  "detection_guardrails": {"scan_max_depth":4,"scan_max_file_bytes":1048576,"exclude_dirs":[],"exclude_globs":[]},
  "singletons": [
    {"id":"node-cron","kind":"env-flag","evidence":["src/jobs.js:1"],"rationale":"scheduler","default_in_worktree":"disabled","severity":"warning","env_var":"RUN_SCHEDULER","env_disabled_value":"false"}
  ]
}
JSON
commit_profile "$MAIN"

WTA="$TEST_TMP/wtA"; make_worktree "$MAIN" "$WTA" "feat-a"
WTB="$TEST_TMP/wtB"; make_worktree "$MAIN" "$WTB" "feat-b"
( cd "$WTA" && bash "$DISPATCH" apply --quiet )
( cd "$WTB" && bash "$DISPATCH" apply --quiet )

# Simulate the pre-upgrade illegal state: BOTH worktrees' feature-overrides enable node-cron,
# bypassing the claim (write the override files directly).
for WT in "$WTA" "$WTB"; do
  cat > "$WT/.worktree-isolate/feature-overrides.local.json" <<JSON
{"schema":1,"overrides":[{"id":"node-cron","state":"enabled"}],"updated_at":"2026-01-01T00:00:00Z"}
JSON
done

# A third claim (wtA re-apply) must REFUSE node-cron with the pre-existing notice.
set +e
errA="$( cd "$WTA" && bash "$DISPATCH" apply --quiet 2>&1 )"
rcA=$?
set -e
assert_eq "1" "$([ "$rcA" -ne 0 ] && echo 1 || echo 0)" "apply must refuse on pre-existing conflict"
assert_contains "$errA" "SINGLETON_CONFLICT_PREEXISTING=node-cron" "must emit pre-existing notice"
assert_contains "$errA" "owners=" "notice must list both owners"

# Heal left it unowned.
reg="$(cd "$WTA" && . "$SKILL_DIR/scripts/allocate-ports.sh" && xwi_registry_file)"
unowned="$(python3 -c 'import json,sys; print("node-cron" not in json.load(open(sys.argv[1])).get("singleton_owners",{}))' "$reg")"
assert_eq "True" "$unowned" "pre-existing conflict id must be left unowned"

# Loser disables → wtA can now claim.
( cd "$WTB" && bash "$DISPATCH" disable node-cron --quiet )
( cd "$WTA" && bash "$DISPATCH" apply --quiet )
owner="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["singleton_owners"].get("node-cron",{}).get("worktree_path",""))' "$reg")"
assert_eq "$WTA" "$owner" "after loser disables, wtA claims node-cron"

pass "test 26 — pre-existing conflict refuse-until-resolved"
```
> Note: the `disable node-cron` in wtB regenerates wtB's override (state=disabled) via apply; then wtA's apply sees only one live enabler and claims successfully. `disable` does not run the enable-path claim, so it is never blocked.

- [ ] **Step 2: Run the test, expect PASS** (logic already implemented).
```
bash skills/x-worktree-isolate/tests/integration/test_26_singleton_preexisting_conflict.sh
# EXPECTED: PASS: test 26 — pre-existing conflict refuse-until-resolved
```
If it fails, fix `xwi_preexisting_conflicts` / `xwi_claim_singleton`'s pre-existing branch in `allocate-ports.sh` (Task 1/2) until green — do not weaken the test.

- [ ] **Step 3: Commit.**
```
git add skills/x-worktree-isolate/tests/integration/test_26_singleton_preexisting_conflict.sh
git commit -m "test(x-worktree-isolate): pre-existing singleton conflict refuse-until-resolved"
```

---

### Task 7: Compose-tier liveness (R3) — stopped-stack owner auto-stolen (docker-gated test)

Verifies R3: a compose-tier owner whose `COMPOSE_PROJECT_NAME` has zero running containers reads dead → auto-stolen. Docker-gated (`have_docker || skip`). Logic landed in Task 2 (`xwi_owner_alive` compose branch).

**Files:**
- Test: `skills/x-worktree-isolate/tests/integration/test_27_singleton_compose_liveness_r3.sh` (Create)

- [ ] **Step 1: Write the docker-gated test.**
```bash
#!/usr/bin/env bash
# Test 27 (R3): compose-tier owner with zero running containers reads dead → auto-stolen.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t27
trap test_teardown EXIT

if ! have_docker; then
  skip "test 27" "docker compose not available"
  exit 0
fi

MAIN="$TEST_TMP/main"
make_repo "$MAIN"
cat > "$MAIN/docker-compose.yml" <<'YAML'
services:
  slackbot:
    image: alpine:3
    environment:
      SLACK_BOT_TOKEN: xoxb-test
YAML
mkdir -p "$MAIN/.worktree-isolate"
cat > "$MAIN/.worktree-isolate/profile.json" <<'JSON'
{
  "schema": 2, "stack": "docker-compose",
  "port_strategy": {"scan_range": [18000, 29999], "ports": []},
  "services_to_strip": [], "data_dirs": [], "global_label_warnings": [], "single_worktree_profiles": [],
  "detection_guardrails": {"scan_max_depth":4,"scan_max_file_bytes":1048576,"exclude_dirs":[],"exclude_globs":[]},
  "singletons": [
    {"id":"slack-listener","kind":"compose-service","evidence":["docker-compose.yml:services.slackbot.environment.SLACK_BOT_TOKEN"],"rationale":"slack","default_in_worktree":"disabled","severity":"warning","compose_service":"slackbot","disable_method":"profile-gate"}
  ]
}
JSON
( cd "$MAIN" && git add . && git commit -q -m setup )

WTA="$TEST_TMP/wtA"; make_worktree "$MAIN" "$WTA" "feat-a"
WTB="$TEST_TMP/wtB"; make_worktree "$MAIN" "$WTB" "feat-b"
( cd "$WTA" && bash "$DISPATCH" apply --quiet )
( cd "$WTB" && bash "$DISPATCH" apply --quiet )

# wtA owns slack-listener. Its COMPOSE_PROJECT_NAME has NO running containers (we never `up`).
( cd "$WTA" && bash "$DISPATCH" enable slack-listener --quiet )

# wtB enable: compose-tier owner with zero running containers = DEAD (R3) → auto-steal.
errB="$( cd "$WTB" && bash "$DISPATCH" enable slack-listener --quiet 2>&1 )"
assert_contains "$errB" "SINGLETON_LOCK_STOLEN=slack-listener" "stopped-stack compose owner must be auto-stolen (R3)"
reg="$(cd "$WTB" && . "$SKILL_DIR/scripts/allocate-ports.sh" && xwi_registry_file)"
owner="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["singleton_owners"].get("slack-listener",{}).get("worktree_path",""))' "$reg")"
assert_eq "$WTB" "$owner" "after R3 auto-steal, wtB must own slack-listener"

pass "test 27 — compose-tier R3 stopped-stack auto-steal"
```

- [ ] **Step 2: Run the test, expect PASS or SKIP.**
```
bash skills/x-worktree-isolate/tests/integration/test_27_singleton_compose_liveness_r3.sh
# EXPECTED (docker present): PASS: test 27 — compose-tier R3 stopped-stack auto-steal
# EXPECTED (no docker): SKIP: test 27 (docker compose not available)
```

- [ ] **Step 3: Commit.**
```
git add skills/x-worktree-isolate/tests/integration/test_27_singleton_compose_liveness_r3.sh
git commit -m "test(x-worktree-isolate): compose-tier R3 stopped-stack liveness auto-steal"
```

---

### Task 8: WhatsApp catalog (`singleton-patterns.py`) + detection test

Adds WhatsApp Tier-1 (compose env/image) and Tier-2 (source signatures). `TIER_COMPOSE` matchers are **substrings** (`m in env_key`/`m in image`) → use `WHATSAPP_` (no glob `*`) + specific keys. `TIER_ENV_FLAG` matchers are **regex alternation under `re.MULTILINE`** → escape metachars.

**Files:**
- Modify: `skills/x-worktree-isolate/scripts/singleton-patterns.py` (append a Tier-1 entry to `TIER_COMPOSE`, lines 28–71; a Tier-2 entry to `TIER_ENV_FLAG`, lines 74–129)
- Modify: `skills/x-worktree-isolate/references/singleton-patterns.md` (Tier-1 + Tier-2 tables)
- Test: `skills/x-worktree-isolate/tests/integration/test_22_singleton_whatsapp_detection.sh` (Create)

- [ ] **Step 1: Write the failing detection test.** Drives `detect-singletons.py` over a fixture (matches the existing harness — no pytest):
```bash
#!/usr/bin/env bash
# Test 22: WhatsApp patterns detected — compose env (whatsapp) + source signature (whatsapp-web).
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t22
trap test_teardown EXIT

REPO="$TEST_TMP/repo"
make_repo "$REPO"
# Tier 1: compose env var token.
cat > "$REPO/docker-compose.yml" <<'YAML'
services:
  wa:
    image: node:20
    environment:
      WHATSAPP_TOKEN: secret
      WHATSAPP_SESSION: sess
YAML
# Tier 2: source signatures.
mkdir -p "$REPO/src"
cat > "$REPO/src/bot.js" <<'JS'
import makeWASocket from '@whiskeysockets/baileys';
const sock = makeWASocket({});
JS
cat > "$REPO/src/web.js" <<'JS'
const { Client } = require('whatsapp-web.js');
const c = new Client({});
JS

DETECT="$SKILL_DIR/scripts/detect-singletons.py"
OUT="$(python3 "$DETECT" --repo "$REPO")"

echo "$OUT" | python3 -c '
import json, sys
d = json.load(sys.stdin)
ids = {s["id"] for s in d.get("singletons", [])}
assert "whatsapp" in ids, f"expected compose-tier whatsapp id, got {ids}"
assert "whatsapp-web" in ids, f"expected env-flag whatsapp-web id, got {ids}"
kinds = {s["id"]: s["kind"] for s in d["singletons"]}
assert kinds["whatsapp"] == "compose-service", kinds
assert kinds["whatsapp-web"] == "env-flag", kinds
print("ok")
'

pass "test 22 — WhatsApp Tier-1 + Tier-2 detection"
```

- [ ] **Step 2: Run the test, expect FAIL.**
```
bash skills/x-worktree-isolate/tests/integration/test_22_singleton_whatsapp_detection.sh
# EXPECTED FAIL: AssertionError: expected compose-tier whatsapp id, got {...}
```

- [ ] **Step 3: Add the Tier-1 WhatsApp pattern.** In `singleton-patterns.py`, append to `TIER_COMPOSE` (after the `watchtower` entry, before the closing `)` at line 71):
```python
    Pattern(
        id="whatsapp",
        rationale="WhatsApp Web session is single-device — two listeners fight over the session.",
        matchers=("WHATSAPP_TOKEN", "WHATSAPP_SESSION", "WHATSAPP_"),
        suggested_env_var="WHATSAPP_LISTENER_ENABLED",
    ),
```
> `WHATSAPP_` is a substring catch-all for any `WHATSAPP_*` env key; the two specific keys are listed first for clearer evidence strings. No `*` glob — `TIER_COMPOSE` matches via `m in env_key`.

- [ ] **Step 4: Add the Tier-2 WhatsApp pattern.** Append to `TIER_ENV_FLAG` (after `procfile-worker`, before the closing `)` at line 129). Metachars escaped for the `re.MULTILINE` alternation; shares the env var with the compose id (mirrors the slack precedent):
```python
    Pattern(
        id="whatsapp-web",
        rationale="Baileys / whatsapp-web.js client — single-device session; duplicate listeners fight over it.",
        matchers=(r"@whiskeysockets/baileys", r"whatsapp-web\.js", r"makeWASocket\(", r"new\s+Client\("),
        suggested_env_var="WHATSAPP_LISTENER_ENABLED",
    ),
```
> Caveat captured for the reviewer: `new\s+Client\(` is broad (matches non-WhatsApp `new Client(`). It is paired with the specific `whatsapp-web\.js`/`baileys`/`makeWASocket\(` matchers in the same alternation, so any single hit classifies the file as `whatsapp-web`; this mirrors the existing `discord-client` (`new\s+Discord\.Client`) breadth trade-off and the ID-contract dedup (`seen_ids`) ensures one entry.

- [ ] **Step 5: Run the test, expect PASS.**
```
bash skills/x-worktree-isolate/tests/integration/test_22_singleton_whatsapp_detection.sh
# EXPECTED: ok / PASS: test 22 — WhatsApp Tier-1 + Tier-2 detection
```

- [ ] **Step 6: Add WhatsApp rows to `references/singleton-patterns.md`.** In the Tier 1 table (after the `watchtower` row, ~line 26):
```
| `whatsapp` | `WHATSAPP_TOKEN`, `WHATSAPP_SESSION`, `WHATSAPP_` | WhatsApp Web session is single-device; two listeners fight over the session |
```
In the Tier 2 table (after `procfile-worker`, ~line 44):
```
| `whatsapp-web` | `@whiskeysockets/baileys`, `whatsapp-web\.js`, `makeWASocket(`, `new Client(` | Baileys / whatsapp-web.js single-device session; duplicate listeners fight over it |
```

- [ ] **Step 7: Commit.**
```
git add skills/x-worktree-isolate/scripts/singleton-patterns.py skills/x-worktree-isolate/references/singleton-patterns.md skills/x-worktree-isolate/tests/integration/test_22_singleton_whatsapp_detection.sh
git commit -m "feat(x-worktree-isolate): WhatsApp singleton patterns (Tier-1 whatsapp + Tier-2 whatsapp-web)"
```

---

### Task 9: `migrate` subcommand + `doctor`/`list` owner awareness

Adds the `migrate` convenience entry point (lock→heal→pre-existing-conflict report→rescan prompt→`x-qa update` pointer), wires it into `dispatch.sh`, makes `list` heal under lock and print an `owner` column, and makes `doctor` heal + flag dead locks.

**Files:**
- Create: `skills/x-worktree-isolate/scripts/migrate.sh`
- Modify: `skills/x-worktree-isolate/scripts/dispatch.sh` (route `migrate`; usage text)
- Modify: `skills/x-worktree-isolate/scripts/allocate-ports.sh` (`list` CLI branch heals under lock; `xwi_list_slots` prints owner column)
- Modify: `skills/x-worktree-isolate/scripts/doctor.sh` (heal under lock; dead-lock check)
- Test: `skills/x-worktree-isolate/tests/integration/test_28_migrate_subcommand.sh` (Create)

- [ ] **Step 1: Write the failing migrate test.**
```bash
#!/usr/bin/env bash
# Test 28: migrate heals registry, reports pre-existing conflicts, prints x-qa update pointer.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t28
trap test_teardown EXIT

MAIN="$TEST_TMP/main"
make_repo "$MAIN"
mkdir -p "$MAIN/.worktree-isolate"
cat > "$MAIN/.worktree-isolate/profile.json" <<'JSON'
{
  "schema": 2, "stack": "docker-compose",
  "port_strategy": {"scan_range": [18000, 29999], "ports": []},
  "services_to_strip": [], "data_dirs": [], "global_label_warnings": [], "single_worktree_profiles": [],
  "detection_guardrails": {"scan_max_depth":4,"scan_max_file_bytes":1048576,"exclude_dirs":[],"exclude_globs":[]},
  "singletons": [
    {"id":"node-cron","kind":"env-flag","evidence":["x"],"rationale":"s","default_in_worktree":"disabled","severity":"warning","env_var":"RUN_SCHEDULER","env_disabled_value":"false"}
  ]
}
JSON
commit_profile "$MAIN"

WTA="$TEST_TMP/wtA"; make_worktree "$MAIN" "$WTA" "feat-a"
WTB="$TEST_TMP/wtB"; make_worktree "$MAIN" "$WTB" "feat-b"
( cd "$WTA" && bash "$DISPATCH" apply --quiet )
( cd "$WTB" && bash "$DISPATCH" apply --quiet )
# Illegal pre-existing dual-enable.
for WT in "$WTA" "$WTB"; do
  cat > "$WT/.worktree-isolate/feature-overrides.local.json" <<JSON
{"schema":1,"overrides":[{"id":"node-cron","state":"enabled"}],"updated_at":"2026-01-01T00:00:00Z"}
JSON
done

out="$( cd "$WTA" && bash "$DISPATCH" migrate 2>&1 )"
assert_contains "$out" "registry_schema" "migrate must confirm registry healed to schema 2"
assert_contains "$out" "SINGLETON_CONFLICT_PREEXISTING=node-cron" "migrate must report pre-existing conflicts"
assert_contains "$out" "x-qa update" "migrate must point x-qa users at x-qa update"
assert_contains "$out" "init --rescan" "migrate must prompt a rescan for new patterns"

reg="$(cd "$WTA" && . "$SKILL_DIR/scripts/allocate-ports.sh" && xwi_registry_file)"
schema="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("registry_schema"))' "$reg")"
assert_eq "2" "$schema" "migrate must persist registry_schema:2"

pass "test 28 — migrate heals + reports conflicts + pointers"
```

- [ ] **Step 2: Run the test, expect FAIL** (`migrate` unknown subcommand).
```
bash skills/x-worktree-isolate/tests/integration/test_28_migrate_subcommand.sh
# EXPECTED FAIL: x-worktree-isolate: unknown subcommand: migrate
```

- [ ] **Step 3: Create `scripts/migrate.sh`.**
```bash
#!/usr/bin/env bash
# migrate.sh — convenience upgrade view: heal registry → report pre-existing
# conflicts → prompt rescan → point x-qa users at `x-qa update`. The heal also
# runs lazily on apply/enable/list/doctor, so users who never run migrate still
# get safe behavior; this is just the single "what do I need to do" summary.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=allocate-ports.sh
. "$SCRIPT_DIR/allocate-ports.sh"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "x-worktree-isolate migrate: not inside a git work tree" >&2
  exit 1
fi

xwi_acquire_lock || exit 1
trap 'xwi_release_lock' EXIT
xwi_heal_registry
REG="$(xwi_registry_file)"
SCHEMA="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("registry_schema"))' "$REG" 2>/dev/null || echo "?")"

echo "x-worktree-isolate migrate"
echo "  registry_schema = $SCHEMA (healed in place; safe to re-run)"
echo

CONFLICTS="$(xwi_preexisting_conflicts)"
if [[ -n "$CONFLICTS" ]]; then
  echo "  Pre-existing singleton conflicts (two live worktrees own the same id):"
  while IFS='|' read -r sid owners; do
    [[ -n "$sid" ]] || continue
    echo "    SINGLETON_CONFLICT_PREEXISTING=$sid owners=$owners"
  done <<<"$CONFLICTS"
  echo "    Resolve: run 'x-worktree-isolate disable <id>' in the loser worktree."
  echo
else
  echo "  No pre-existing singleton conflicts."
  echo
fi

cat <<EOF
  Next steps:
    1. Pick up new singleton patterns (e.g. WhatsApp): run from the main checkout:
         x-worktree-isolate init --rescan
       then hand-merge profile.json.new and commit.
    2. For x-qa stateful-aware channel selection, run in each worktree:
         x-qa update
EOF
```

- [ ] **Step 4: Route `migrate` in `dispatch.sh` + bump usage.** Add a case before `version|--version|-v)` (after line 67):
```bash
  migrate)
    exec bash "$SCRIPT_DIR/migrate.sh" "$@"
    ;;
```
In the `usage()` heredoc, add under the subcommand list (after `ack-host-singletons`):
```
  migrate                           Heal registry + report pre-existing conflicts + upgrade pointers.
```
and update the `enable`/`apply` usage lines to mention `--force`:
```
  apply [--quiet|--if-profile-exists|--ignore-warnings|--dry-run|--force]
  enable <id> [--force]             Mark singleton enabled (claim the lock; --force steals).
```

- [ ] **Step 5: Make `list` heal under lock + print owner column.** In `allocate-ports.sh`, replace the `xwi_list_slots` python body (lines 274–289) so it reads `singleton_owners` and appends an owner column:
```bash
xwi_list_slots() {
  local file
  file="$(xwi_registry_file)" || return 1
  if [[ ! -f "$file" ]]; then
    echo "x-worktree-isolate: registry empty (no slots claimed)"
    return 0
  fi
  python3 - "$file" <<'PY'
import json, sys
with open(sys.argv[1]) as fh:
    try: data = json.load(fh)
    except json.JSONDecodeError:
        print("x-worktree-isolate: registry file is not valid JSON"); sys.exit(1)
slots = data.get("slots", [])
owners = data.get("singleton_owners", {}) or {}
# Reverse map worktree_path -> [ids] for the owner column.
by_path = {}
for sid, o in owners.items():
    if isinstance(o, dict):
        by_path.setdefault(o.get("worktree_path", ""), []).append(sid)
if not slots:
    print("x-worktree-isolate: registry empty (no slots claimed)"); sys.exit(0)
print(f"{'slot':<5} {'branch':<28} {'owns':<22} worktree_path")
for s in slots:
    own = ",".join(sorted(by_path.get(s.get("worktree_path",""), []))) or "-"
    print(f"{s.get('slot'):<5} {str(s.get('branch') or '')[:28]:<28} {own[:22]:<22} {s.get('worktree_path')}")
PY
}
```
And update the CLI passthrough at the bottom (lines 322–327) so `list` heals first under the lock:
```bash
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  case "${1:-}" in
    list)
      if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        xwi_acquire_lock && { xwi_heal_registry; xwi_release_lock; }
      fi
      xwi_list_slots
      ;;
    *) echo "usage: allocate-ports.sh list" >&2; exit 1 ;;
  esac
fi
```

- [ ] **Step 6: Make `doctor` heal under lock + flag dead locks.** In `doctor.sh`, insert after the registry-orphans block (after line 101):
```bash
# 4b. Singleton owner liveness: heal + flag any owner whose worktree_path is gone.
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  xwi_acquire_lock 2>/dev/null && { xwi_heal_registry; xwi_release_lock; } || true
fi
if [[ -n "$REG" && -f "$REG" ]]; then
  DEAD_OWNERS="$(python3 - "$REG" <<'PY'
import json, os, sys
d = json.load(open(sys.argv[1]))
dead = []
for sid, o in (d.get("singleton_owners") or {}).items():
    if isinstance(o, dict) and not os.path.isdir(o.get("worktree_path","")):
        dead.append(f"{sid} (owner gone: {o.get('worktree_path','')})")
print("\n".join(dead))
PY
)"
  if [[ -z "$DEAD_OWNERS" ]]; then
    ok "no dead singleton locks"
  else
    while IFS= read -r line; do
      [[ -n "$line" ]] && warn "dead singleton lock: $line — clear with: x-worktree-isolate migrate"
    done <<<"$DEAD_OWNERS"
  fi
fi
```
> Heal already drops dead owners, so after heal `DEAD_OWNERS` is normally empty (the `ok` path); the warn path covers a race where an owner dir vanished between heal and check. The `migrate` clear hint satisfies the "doctor offers to clear" requirement.

- [ ] **Step 7: Run test_28 + full suite, expect PASS.**
```
bash skills/x-worktree-isolate/tests/integration/test_28_migrate_subcommand.sh
# EXPECTED: PASS: test 28 — migrate heals + reports conflicts + pointers
bash skills/x-worktree-isolate/tests/integration/run-all.sh
# EXPECTED: summary FAIL: 0
```

- [ ] **Step 8: Commit.**
```
git add skills/x-worktree-isolate/scripts/migrate.sh skills/x-worktree-isolate/scripts/dispatch.sh skills/x-worktree-isolate/scripts/allocate-ports.sh skills/x-worktree-isolate/scripts/doctor.sh skills/x-worktree-isolate/tests/integration/test_28_migrate_subcommand.sh
git commit -m "feat(x-worktree-isolate): migrate subcommand + owner column in list + doctor dead-lock check"
```

---

### Task 10: Version bump 0.2.0 → 0.3.0 + SKILL.md docs

Bumps both version constants and the SKILL.md prose, adds the v0.3 migration banner, the enforced-claim + enriched-registry docs, the honest-guarantee-per-tier statement, the WhatsApp row, the new flags/subcommand in the workflow + detection tables, and an anti-pattern. No profile schema bump (singletons[] additions are additive; profile `schema` stays 2).

**Files:**
- Modify: `skills/x-worktree-isolate/config.json` (line 2)
- Modify: `skills/x-worktree-isolate/scripts/dispatch.sh` (line 17)
- Modify: `skills/x-worktree-isolate/SKILL.md` (banner line 8; version line 61; singletons table; anti-patterns; workflow/detection tables; honest-guarantee)
- Test: `skills/x-worktree-isolate/tests/integration/test_29_version_consistency.sh` (Create)

- [ ] **Step 1: Add a version-consistency test guard.** Create `tests/integration/test_29_version_consistency.sh`:
```bash
#!/usr/bin/env bash
# Test 29: dispatch VERSION, config.json version, and `version` output all agree at 0.3.0.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t29
trap test_teardown EXIT

CFG_VER="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$SKILL_DIR/config.json")"
assert_eq "0.3.0" "$CFG_VER" "config.json version must be 0.3.0"

REPO="$TEST_TMP/r"; make_repo "$REPO"
ver_out="$(cd "$REPO" && bash "$DISPATCH" version)"
assert_contains "$ver_out" "0.3.0" "dispatch version output must be 0.3.0"

pass "test 29 — version constants consistent at 0.3.0"
```

- [ ] **Step 2: Run it, expect FAIL.**
```
bash skills/x-worktree-isolate/tests/integration/test_29_version_consistency.sh
# EXPECTED FAIL: config.json version must be 0.3.0 (expected 0.3.0, actual 0.2.0)
```

- [ ] **Step 3: Bump `config.json`.**
```jsonc
// line 2
  "version": "0.3.0",
```

- [ ] **Step 4: Bump `dispatch.sh`.**
```bash
# line 17
VERSION="0.3.0"
```

- [ ] **Step 5: Run test_29, expect PASS.**
```
bash skills/x-worktree-isolate/tests/integration/test_29_version_consistency.sh
# EXPECTED: PASS: test 29 — version constants consistent at 0.3.0
```

- [ ] **Step 6: Add the v0.3 migration banner to SKILL.md.** After the existing v0.2 banner (after line 8), insert:
```markdown
> **v0.3 migration (soft, self-healing):** Singleton locks are now **enforced** — only one worktree may `enable` a given singleton (Slack/Telegram/WhatsApp/etc.) at a time. The per-repo registry's `singleton_owners` is enriched to `{id: {worktree_path, branch, claimed_at}}` with a `registry_schema: 2` marker and **self-heals lazily** on the next `apply`/`enable`/`list`/`doctor` — no manual step required. Run `x-worktree-isolate migrate` for the one-shot upgrade view (heal + pre-existing-conflict report + rescan/`x-qa update` pointers). Unlike v0.2, there is **no hard reject**: every new field is additive. Pick up the new WhatsApp patterns via `init --rescan`. Profile `schema` stays **2**.
```

- [ ] **Step 7: Update the `version` prose (line 61) and the `enable`/`apply` workflow items; add `migrate`.** Change line 61 to:
```markdown
12. **`version`** — print version (currently `0.3.0`).
```
Update item 14 (`enable <id>`) to:
```markdown
14. **`enable <id> [--force]`** — claim the singleton lock for this worktree, then mark it enabled and regenerate override + `.env.worktree`. Refuses if another **live** worktree owns it (`SINGLETON_CONFLICT`); auto-steals a **dead** owner (`SINGLETON_LOCK_STOLEN`); `--force`/`--steal` steals a live owner. Reaching `enabled` therefore **guarantees** this worktree owns the singleton.
```
Add a new workflow item after `ack-host-singletons` (item 16):
```markdown
17. **`migrate`** — convenience upgrade view: heal registry → report pre-existing conflicts → prompt `init --rescan` → point x-qa users at `x-qa update`. The heal runs automatically on apply/enable/list/doctor regardless; `migrate` is just the single summary.
```
Update item 4 (`apply`) to mention `--force`:
```markdown
4. **`apply` (`--force`/`--steal`)** — Phase 2. ... `apply` now claims every enabled singleton **before writing any file**; a refused claim leaves the worktree untouched and exits non-zero. `--force`/`--steal` steals a live lock.
```

- [ ] **Step 8: Add `migrate` to the Detection table + the enriched-registry note to the Singletons section.** In the Detection table (after the `ack-host-singletons` row, line 38):
```markdown
| User upgraded the skill and wants the one-shot "what do I need to do" view | `migrate` |
| User wants to steal a live singleton lock from another worktree | `enable <id> --force` / `apply --force` |
```
In the Singletons (now v0.3) section, add an enriched-registry paragraph after the tier table (after line 87):
```markdown
**Enforcement (v0.3):** the per-repo registry records each owned singleton as
`singleton_owners[id] = {worktree_path, branch, claimed_at}` (top-level `registry_schema: 2`). `enable` and `apply` run an enforced **claim** inside the registry lock: unowned/owned-by-self → claim; another **live** owner → refuse (`SINGLETON_CONFLICT=<id> owner=<branch>@<path>`) unless `--force`; a **dead** owner → auto-steal (`SINGLETON_LOCK_STOLEN=<id> from=<branch>`). A lock is **dead** when the owner's `worktree_path` is gone from disk OR it no longer holds a registry slot (all tiers), OR — compose-tier only — its `COMPOSE_PROJECT_NAME` has zero running containers. On upgrade, two live worktrees that both already enabled the same singleton surface `SINGLETON_CONFLICT_PREEXISTING=<id> owners=<b1>@<p1>,<b2>@<p2>` and the id stays unowned until the loser runs `disable <id>`.
```

- [ ] **Step 9: Add the honest-guarantee-per-tier statement.** After the enforcement paragraph (Step 8), add:
```markdown
**Honest guarantee per tier.** The registry makes the *claim* exclusive — two worktrees can never both *believe* they own a platform. **Runtime** exclusivity is only as strong as the tier:
- **compose-tier** (`profiles: [xwi-disabled]`) — a real gate; the disabled service does not start. Note: a compose lock only reads as *live* once the owner's stack is up — a stopped stack is reclaimable (R3).
- **env-flag tier** — advisory; the app must read `<VAR>=false` and short-circuit. The skill cannot enforce app code.
- **host-tier** — manual acknowledgement only.

The lock cannot reach into application code; it prevents the dual-ownership *belief*, not every possible dual *execution*.
```

- [ ] **Step 10: Add the WhatsApp row to the SKILL.md singletons tier table.** In the Tier 1 row of the table at lines 79–83, append `WhatsApp` to the detected-tokens list:
```markdown
| 1 — compose-service | Compose service env contains Slack/Discord/Telegram/Stripe/GitHub-App/**WhatsApp** token, or image matches ngrok/watchtower | `services.<svc>.profiles: [xwi-disabled]` (default) or `deploy.replicas: 0` (Swarm only) |
```
In the Tier 2 row, append the WhatsApp libs:
```markdown
| 2 — env-flag | Source matches `node-cron`/`bullmq`/`celery beat`/`slack-bolt`/`telegraf`/`agenda`/`chokidar`/Procfile worker line/**`@whiskeysockets/baileys`/`whatsapp-web.js`** | `<VAR>=false` line appended to `.env.worktree` |
```

- [ ] **Step 11: Add an anti-pattern.** In the Anti-patterns list (after line 73), add:
```markdown
- **Never bypass the claim by hand-editing `feature-overrides.local.json` to `enabled`** — the "enabled ⇒ owned" guarantee holds only because `enable` wins the registry claim first. A hand-edited dual-enable surfaces as `SINGLETON_CONFLICT_PREEXISTING` on the next claim and blocks until resolved.
```

- [ ] **Step 12: Run the full suite — confirm everything green at 0.3.0.**
```
bash skills/x-worktree-isolate/tests/integration/run-all.sh
# EXPECTED: summary PASS: <N>  FAIL: 0  (includes test_22..29)
```

- [ ] **Step 13: Commit.**
```
git add skills/x-worktree-isolate/config.json skills/x-worktree-isolate/scripts/dispatch.sh skills/x-worktree-isolate/SKILL.md skills/x-worktree-isolate/tests/integration/test_29_version_consistency.sh
git commit -m "docs(x-worktree-isolate): v0.3.0 bump — enforced singleton lock + WhatsApp + migrate docs"
```

---

## Final verification (run before declaring done)

- [ ] **Step F1: Full suite green.**
```
bash skills/x-worktree-isolate/tests/integration/run-all.sh
# EXPECTED: FAIL: 0 (test_27 may SKIP without docker)
```
- [ ] **Step F2: No stray `xwi_set_singleton_owners` references anywhere in scripts.**
```
grep -rn "xwi_set_singleton_owners" skills/x-worktree-isolate/
# EXPECTED: no output
```
- [ ] **Step F3: Confirm the shared-contract notices are emitted with the exact spelling** (grep the implemented scripts against the appendix):
```
grep -rn "SINGLETON_CONFLICT=\|SINGLETON_LOCK_STOLEN=\|SINGLETON_CONFLICT_PREEXISTING=" skills/x-worktree-isolate/scripts/
# EXPECTED: matches in allocate-ports.sh (claim) and migrate.sh; each spelled exactly as Appendix A
```

---

## Appendix A — SHARED CONTRACT (verbatim; do not alter names)

- **Link field:** x-qa `channels[].singleton_id` (string|null) → isolate `singletons[].id`.
- **Enriched registry `singleton_owners`:** `{ "<id>": { "worktree_path": str, "branch": str, "claimed_at": ISO8601 } }`; top-level `registry_schema: 2`; old shape `{ "<id>": "<worktree_path>" }` / missing marker = migrate lazily, idempotent.
- **`feature-overrides.local.json` unchanged (schema 1):** `overrides[]` of `{id, state}`, state ∈ enabled|disabled|acknowledged.
- **Ownership rule (consumed by x-qa, honored here):** "enabled in a worktree's feature-overrides ⇒ that worktree owns it", guaranteed because `enabled` is only reachable by winning the claim.
- **Notices:**
  - `SINGLETON_CONFLICT=<id> owner=<branch>@<path>`
  - `SINGLETON_LOCK_STOLEN=<id> from=<branch>`
  - `SINGLETON_CONFLICT_PREEXISTING=<id> owners=<b1>@<p1>,<b2>@<p2>`
- **New flags:** `--force` / `--steal` on `enable` and `apply`. **New subcommand:** `migrate`. **Version 0.3.0.**
- **Liveness dead** = worktree_path gone OR no registry slot (all tiers) OR (compose-tier) zero running containers for COMPOSE_PROJECT_NAME.
- **`claimed_at` on heal-reconstructed owners** (spec-unspecified; pinned here): use the owner worktree's `feature-overrides.local.json` `updated_at` when present, else the heal's `now()` UTC timestamp. Fresh claims via `xwi_claim_singleton` always stamp `now()`.

---

### Implementation notes carried from review (load-bearing)

1. **enable→apply atomicity:** `enable` must claim under the lock and **release the lock before calling `apply`** (a child process with a different `$$` would otherwise deadlock on the parent-held lock). The override file is written only after the claim wins.
2. **apply claim placement:** the claim runs **immediately after lock + heal, before any file write**; a refusal exits non-zero with zero files touched.
3. **Lock threading:** `xwi_heal_registry` is a **lock-free core** assuming the caller holds the lock. `apply` calls it directly; `enable`/`list`/`doctor`/`migrate` wrap it `acquire → heal → release`. Never double-acquire.
4. **Claim is SYNC, not ADD; heal never elects a winner:** `apply` sets this worktree's owned set to exactly `ENABLED_IDS` (drops self-owned ids no longer enabled — this is how `disable` releases). Heal rebuilds from ground truth and leaves dual-claimed ids **unowned**, surfaced via `SINGLETON_CONFLICT_PREEXISTING` on the next claim.
5. **Matcher syntax per tier:** `TIER_COMPOSE` = substring (`WHATSAPP_`, no `*`); `TIER_ENV_FLAG` = regex under `re.MULTILINE` (escape: `makeWASocket\(`, `new\s+Client\(`, `whatsapp-web\.js`, `@whiskeysockets/baileys`).
6. **Two version constants** (`dispatch.sh:17`, `config.json:2`) plus SKILL.md prose — bump all three. Plugin/marketplace manifest bumps are release-time, out of this plan's scope.
7. **Test tier choice:** the basic refuse/steal test (test_24) uses an **env-flag** singleton (path-only liveness, docker-free, deterministic); compose-tier R3 (test_27) is docker-gated with `have_docker || skip`.
8. **Known limitation — `enable` claim→override is not fully atomic (accepted):** Task 4 releases the registry lock immediately after winning the claim, *before* the override file is written, so `apply` (a child process) can re-acquire without deadlocking. This leaves a sub-millisecond window where a concurrent `--force` steal from another worktree could land between the claim and the override write, leaving this worktree's `feature-overrides.local.json` saying `enabled` while it no longer owns the lock. This is accepted, not fixed: (a) it requires a deliberate, rare, destructive `--force` from another worktree in that exact window; (b) the next `apply`/`heal` self-corrects (heal rebuilds owners from ground truth, and a re-apply re-claims or refuses); (c) the "atomic" alternative — holding the lock across the override write — reintroduces a lock-leak-on-`set -e`-failure that the current ordering deliberately avoids. If a future change adds a release trap to `feature-overrides.sh`, revisit and hold the lock through the override write.
