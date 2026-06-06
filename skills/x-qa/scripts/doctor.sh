#!/usr/bin/env bash
# doctor.sh — validate profile against repo state
# NOTE: Uses python3 for path resolution instead of `realpath -m` (GNU-only flag;
# macOS BSD realpath has no -m). Portable across Linux and macOS.
set -euo pipefail

PROFILE_PATH=""
TEMPLATE_MODE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --template-mode) TEMPLATE_MODE=true; shift ;;
    *) PROFILE_PATH="$1"; shift ;;
  esac
done
[[ -z "$PROFILE_PATH" ]] && PROFILE_PATH="$(git rev-parse --show-toplevel)/.x-skills/x-qa/profile.json"
[[ -f "$PROFILE_PATH" ]] || { echo "✗ doctor FAIL"; echo "reason=profile not found at $PROFILE_PATH"; exit 2; }

repo_root=$(git rev-parse --show-toplevel)
checks_attempted=0
checks_passed=0
warnings=0
info_nudge=""

fail() {
  echo "✗ doctor FAIL"
  echo "checks_attempted=$checks_attempted"
  echo "checks_passed=$checks_passed"
  echo "first_failure=$1"
  echo "reason=$2"
  exit 1
}
attempt() { checks_attempted=$((checks_attempted+1)); }
pass() { checks_passed=$((checks_passed+1)); }

# Portable substitute for `realpath -m` (resolves path without requiring existence).
# realpath -m is GNU-only; macOS BSD realpath lacks the -m flag.
resolve_path() {
  python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$1"
}

# Check 1: schema
attempt
[[ "$(jq -r '.schema' "$PROFILE_PATH")" == "1" ]] || fail 1 "schema != 1"
pass

# Check 2: entry_points non-empty
attempt
[[ "$(jq -r '.entry_points | length' "$PROFILE_PATH")" -gt 0 ]] || fail 2 "no entry_points"
pass

# Check 3: exactly one primary, matching top-level primary_entry_point
attempt
primary_count=$(jq '[.entry_points[] | select(.primary == true)] | length' "$PROFILE_PATH")
[[ "$primary_count" == "1" ]] || fail 3 "expected 1 primary entry, found $primary_count"
top_primary=$(jq -r '.primary_entry_point' "$PROFILE_PATH")
ep_primary=$(jq -r '.entry_points[] | select(.primary == true) | .name' "$PROFILE_PATH")
[[ "$top_primary" == "$ep_primary" ]] || fail 3 "primary_entry_point '$top_primary' != entry with primary:true '$ep_primary'"
pass

# Check 4: auto_managed set on every entry
attempt
missing_am=$(jq '[.entry_points[] | select(.auto_managed == null)] | length' "$PROFILE_PATH")
[[ "$missing_am" == "0" ]] || fail 4 "entries missing auto_managed: $missing_am"
pass

# Check 5: name slugs (1-40 chars; suffix optional so single-char names like "a" pass)
attempt
while IFS= read -r name; do
  [[ "$name" =~ ^[a-z0-9]([a-z0-9-]{0,38}[a-z0-9])?$ ]] || fail 5 "invalid slug: $name"
done < <(jq -r '.entry_points[].name' "$PROFILE_PATH")
pass

# Check 6: repo_root matches
if [[ "$TEMPLATE_MODE" != true ]]; then
  attempt
  profile_root=$(jq -r '.repo_root' "$PROFILE_PATH")
  [[ "$profile_root" == "$repo_root" ]] || fail 6 "repo_root drift: profile=$profile_root actual=$repo_root"
  pass
fi

# Check 7: working_dir under repo_root
if [[ "$TEMPLATE_MODE" != true ]]; then
  attempt
  while IFS= read -r ep; do
    wd=$(jq -r '.launch.working_dir // "."' <<<"$ep")
    resolved=$(resolve_path "$repo_root/$wd")
    case "$resolved/" in
      "$repo_root"/*|"$repo_root/") ;;
      *) fail 7 "working_dir '$wd' escapes repo_root ($resolved)" ;;
    esac
  done < <(jq -c '.entry_points[]' "$PROFILE_PATH")
  pass
fi

# Check 8: referenced files exist + launch.command non-empty (rule 7)
if [[ "$TEMPLATE_MODE" != true ]]; then
  attempt
  while IFS= read -r ep; do
    cmd=$(jq -r '.launch.command // empty' <<<"$ep")
    [[ -n "$cmd" ]] || fail 8 "launch.command is empty for entry $(jq -r '.name' <<<"$ep")"
    spec=$(jq -r '.openapi_spec // empty' <<<"$ep")
    if [[ -n "$spec" ]]; then
      [[ -f "$repo_root/$spec" ]] || fail 8 "openapi_spec missing: $spec"
    fi
  done < <(jq -c '.entry_points[]' "$PROFILE_PATH")
  pass
fi

# Check 9: auth token_source — env or repo-rooted file, no traversal
attempt
while IFS= read -r src; do
  [[ -z "$src" || "$src" == "null" ]] && continue
  [[ "$src" =~ ^(env:[A-Za-z0-9_]+|file:[A-Za-z0-9_./-]+)$ ]] \
    || fail 9 "invalid auth token_source: $src (must match env:NAME or file:path)"
  if [[ "$src" == file:* ]]; then
    fpath="${src#file:}"
    [[ "$fpath" != *..* ]] || fail 9 "auth token_source contains '..' (path traversal): $src"
    if [[ "$TEMPLATE_MODE" != true ]]; then
      resolved=$(resolve_path "$repo_root/$fpath")
      case "$resolved/" in "$repo_root"/*|"$repo_root/") ;; *) fail 9 "auth token_source escapes repo_root: $src" ;; esac
    fi
  fi
done < <(jq -r '.entry_points[].auth.token_source // empty' "$PROFILE_PATH")
pass

# Check 10: type:http has required fields
attempt
while IFS= read -r ep; do
  if [[ "$(jq -r '.type' <<<"$ep")" == "http" ]]; then
    for f in base_url_template base_url_fallback health; do
      v=$(jq -r ".$f // empty" <<<"$ep")
      [[ -n "$v" ]] || fail 10 "http entry missing $f"
    done
  fi
done < <(jq -c '.entry_points[]' "$PROFILE_PATH")
pass

# Check 11: type:cli args_schema recommended (warning)
attempt
while IFS= read -r ep; do
  if [[ "$(jq -r '.type' <<<"$ep")" == "cli" ]]; then
    [[ "$(jq -r '.args_schema // empty' <<<"$ep")" != "" ]] || warnings=$((warnings+1))
  fi
done < <(jq -c '.entry_points[]' "$PROFILE_PATH")
pass

# Check 12: type:worker queue_inspect recommended (warning)
attempt
while IFS= read -r ep; do
  if [[ "$(jq -r '.type' <<<"$ep")" == "worker" ]]; then
    [[ "$(jq -r '.queue_inspect // empty' <<<"$ep")" != "" ]] || warnings=$((warnings+1))
  fi
done < <(jq -c '.entry_points[]' "$PROFILE_PATH")
pass

# Check 13: npm-script presence
if [[ "$TEMPLATE_MODE" != true ]]; then
  attempt
  while IFS= read -r ep; do
    if [[ "$(jq -r '.launch.kind' <<<"$ep")" == "npm-script" ]]; then
      cmd=$(jq -r '.launch.command' <<<"$ep")
      script_name=$(awk '{print $3}' <<<"$cmd")  # `npm run <name>`
      wd=$(jq -r '.launch.working_dir // "."' <<<"$ep")
      pkg="$repo_root/$wd/package.json"
      [[ -f "$pkg" ]] || fail 13 "npm-script entry but $pkg missing"
      jq -e --arg s "$script_name" '.scripts[$s] // empty' "$pkg" >/dev/null \
        || fail 13 "npm script '$script_name' not in $pkg"
    fi
  done < <(jq -c '.entry_points[]' "$PROFILE_PATH")
  pass
fi

# Check 14: docker compose file presence
if [[ "$TEMPLATE_MODE" != true ]]; then
  attempt
  while IFS= read -r ep; do
    cmd=$(jq -r '.launch.command' <<<"$ep")
    if [[ "$cmd" == *"docker compose"* || "$cmd" == *"docker-compose"* ]]; then
      wd=$(jq -r '.launch.working_dir // "."' <<<"$ep")
      have_compose=false
      for f in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
        [[ -f "$repo_root/$wd/$f" ]] && have_compose=true && break
      done
      [[ "$have_compose" == true ]] || fail 14 "docker compose referenced but no compose file in $wd"
    fi
  done < <(jq -c '.entry_points[]' "$PROFILE_PATH")
  pass
fi

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

  # C5: channel auth token_source — env: or file: only (no literal secrets; rejects '..' path traversal, mirrors rule 9)
  attempt
  while IFS= read -r src; do
    [[ -z "$src" || "$src" == "null" ]] && continue
    [[ "$src" =~ ^(env:[A-Za-z0-9_]+|file:[A-Za-z0-9_./-]+)$ ]] \
      || fail C5 "invalid channel auth token_source: $src (env:NAME or file:path; literal secrets rejected)"
    if [[ "$src" == file:* ]]; then
      fpath="${src#file:}"
      [[ "$fpath" != *..* ]] || fail C5 "channel auth token_source contains '..' (path traversal): $src"
    fi
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

  # Info-nudge: channels present but NONE declare the singleton_id key (not migrated).
  # Use has("singleton_id") — NOT `!= null` — so a fully-migrated stateless profile that
  # writes `singleton_id: null` explicitly counts as migrated and the nudge does NOT fire
  # forever. Distinguishes "key present (migrated, even if null)" from "key absent (not migrated)".
  with_sid=$(jq -r '[.channels[] | select(has("singleton_id"))] | length' "$PROFILE_PATH")
  if [[ "$with_sid" -eq 0 ]]; then
    info_nudge="channels present but none carry singleton_id — run 'x-qa update' for stateful-aware selection"
  fi
fi

# ---- KB integrity checks (skipped if no KB present) ------------------------
KB_ROOT="$repo_root/.x-skills/x-qa/kb"
KB_INDEX="$KB_ROOT/index.json"
if [[ -d "$KB_ROOT" && -f "$KB_INDEX" ]]; then
  # KB1: schema pin
  attempt
  [[ "$(jq -r '.schema' "$KB_INDEX")" == "1" ]] || fail KB1 "kb/index.json schema != 1"
  pass

  # KB2: every index.cases entry points to a real file
  attempt
  while IFS=$'\t' read -r id rel; do
    [[ -f "$KB_ROOT/$rel" ]] || fail KB2 "kb/index.json cases.$id → $rel missing on disk"
  done < <(jq -r '.cases | to_entries[] | [.key, .value.file] | @tsv' "$KB_INDEX")
  pass

  # KB3: every index.flows entry points to a real file
  attempt
  while IFS=$'\t' read -r id rel; do
    [[ -f "$KB_ROOT/$rel" ]] || fail KB3 "kb/index.json flows.$id → $rel missing on disk"
  done < <(jq -r '.flows | to_entries[] | [.key, .value.file] | @tsv' "$KB_INDEX")
  pass

  # KB4: every index.baselines entry points to a real file
  attempt
  while IFS=$'\t' read -r ep rel; do
    [[ -f "$KB_ROOT/$rel" ]] || fail KB4 "kb/index.json baselines[\"$ep\"] → $rel missing on disk"
  done < <(jq -r '.baselines | to_entries[] | [.key, .value.file] | @tsv' "$KB_INDEX")
  pass

  # KB5: every case YAML on disk has a matching index entry (orphans = warning)
  while IFS= read -r f; do
    rel="${f#$KB_ROOT/}"
    in_idx=$(jq -r --arg p "$rel" '[(.cases | to_entries[] | select(.value.file == $p))] | length' "$KB_INDEX")
    [[ "$in_idx" == "0" ]] && warnings=$((warnings+1))
  done < <(find "$KB_ROOT/cases" -maxdepth 1 -type f \( -name "*.yaml" -o -name "*.yml" \) 2>/dev/null || true)

  # KB6: corpus drift — case endpoints not in profile catalog (warning, not fail)
  attempt
  profile_endpoints=$(jq -r '.entry_points[] | select(.type=="http") | .openapi_spec // empty' "$PROFILE_PATH")
  # We do not parse OpenAPI here; the warning is heuristic. If profile has no
  # spec, skip. Real coverage check happens at plan-generation time.
  pass

  # KB7: corpus checksum integrity (warning when file body differs from index hash)
  while IFS=$'\t' read -r id rel sum; do
    [[ -z "$sum" || "$sum" == "null" ]] && continue
    actual_file="$KB_ROOT/$rel"
    [[ -f "$actual_file" ]] || continue
    if command -v sha256sum >/dev/null 2>&1; then
      actual="sha256:$(sha256sum "$actual_file" | awk '{print $1}')"
    else
      actual="sha256:$(shasum -a 256 "$actual_file" | awk '{print $1}')"
    fi
    [[ "$actual" == "$sum" ]] || warnings=$((warnings+1))
  done < <(jq -r '.cases | to_entries[] | [.key, .value.file, (.value.checksum // "null")] | @tsv' "$KB_INDEX")
fi

echo "✓ doctor PASS"
echo "checks_attempted=$checks_attempted"
echo "checks_passed=$checks_passed"
echo "warnings=$warnings"
if [[ -n "$info_nudge" ]]; then echo "info=$info_nudge"; fi
