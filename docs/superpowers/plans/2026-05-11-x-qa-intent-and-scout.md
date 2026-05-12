# x-qa Intent-Detection + Scout Phase Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `/x-skills:x-qa run` accept a free-form request (PR ref, file path, spec doc, prose, service name, or nothing) and auto-classify it into a scope source; dispatch a scout subagent only when the input is feature-spec / prose / artifact; let the QA-lead plan express `depends_on` so cases can be parallel or sequential.

**Architecture:** Insert a classifier step into the existing Run Phases (between Bootstrap and Plan), persist an `intent.json` envelope, conditionally fire a scout via the pinned simple-runner (gemini-flash / OMC executor / Explore), feed the scope JSON into the plan generator, and extend the test-plan schema + dispatcher with `depends_on` for topological execution. No new user-facing CLI flags — existing `--pr` / `--branch` / `--service` become explicit overrides for the auto-detected intent.

**Tech Stack:** Bash 4+ (jq, git, gh), markdown skill references, existing `case-runner-prompts.md` runner abstraction.

---

## File Structure

**New files:**
- `skills/x-qa/references/intent-detection.md` — classifier rules + ask-when-ambiguous template
- `skills/x-qa/references/scout-prompt.md` — scout subagent prompt + scope envelope schema
- `skills/x-qa/scripts/classify-intent.sh` — pure-bash classifier (no LLM), emits `intent.json`
- `skills/x-qa/scripts/lib/topo-order.sh` — topological sort for plan dispatch waves
- `skills/x-qa/scripts/tests/fixtures/intent-cases.txt` — classifier fixture inputs
- `skills/x-qa/scripts/tests/classify.sh` — smoke test for classifier
- `skills/x-qa/scripts/tests/topo.sh` — smoke test for topo-order

**Modified files:**
- `skills/x-qa/SKILL.md` — insert "Phase 2.5 Classify" and conditional "Phase 3.5 Scout"; reference new bash helpers
- `skills/x-qa/references/test-plan-schema.md` — add `depends_on` field to TestCase, document parallel-group semantics
- `skills/x-qa/templates/test-plan.example.yml` — show one chained case
- `skills/x-qa/scripts/tests/smoke.sh` — add hooks calling classify.sh + topo.sh
- `skills/x-qa/gotchas.md` — three new entries (misclassification, scout context overflow, topo cycle)

Each file has one responsibility. The classifier never calls an LLM; the scout never writes intent; the topo helper is pure data-transform.

---

### Task 1: Classifier reference doc

**Files:**
- Create: `skills/x-qa/references/intent-detection.md`

- [ ] **Step 1: Write the reference doc**

Create `skills/x-qa/references/intent-detection.md`:

```markdown
# Intent Detection

`x-qa run` accepts a free-form request via `{{ARGUMENTS}}`. The classifier
selects ONE intent. No flag explosion — flags are explicit overrides only.

## Inputs

| Input shape | Detection rule | Intent |
|---|---|---|
| empty string | none | `branch` (test current branch via `git diff main...HEAD`) |
| `PR #<n>`, `#<n>`, URL `github.com/.../pull/<n>` | regex match | `pr` (use `gh pr diff`) |
| matches `profile.entry_points[].name` exactly | string equality | `service` (smoke-test that entry only) |
| existing file path AND path matches `*.md` `*.txt` `*.rst` `docs/**` `specs/**` | `test -f` + suffix/dir check | `spec` (scout reads file → walks code) |
| existing file path AND not a spec dir | `test -f` | `artifact` (scout walks callers + endpoint decls) |
| existing directory path | `test -d` | `artifact-dir` (scout walks all files within) |
| anything else (free-form prose) | fallback | `prose` (scout greps repo for related code) |

The classifier is pure bash — see `scripts/classify-intent.sh`. No LLM call.

## Override Flags (explicit, not required)

`--pr <n>` / `--branch <name>` / `--service <name>` force intent and skip
classification. They exist for CI and x-team where input is structured.

## Output Envelope

The classifier writes `<run-dir>/intent.json`:

```json
{
  "intent": "branch|pr|service|spec|artifact|artifact-dir|prose",
  "raw": "<original input>",
  "resolved": {
    "pr_number": 42,                       // pr only
    "branch": "feature/x",                 // branch only
    "service_name": "api",                 // service only
    "spec_path": "docs/avatar.md",         // spec only
    "artifact_path": "src/api/users.ts",   // artifact / artifact-dir
    "prose": "avatar upload 256px"         // prose only
  },
  "confidence": "high|medium|low",
  "candidates": []                         // populated when confidence != high
}
```

## Ask-When-Ambiguous

If `confidence == "low"` OR multiple plausible candidates exist, the
orchestrator asks ONE question before proceeding. Template:

> Detected `<intent>` but I see <N> candidates: <list>.
> Which should I test? [1] <a> [2] <b> [3] all

After resolution, rewrite `intent.json` with `confidence: high` and proceed.

## Examples

| User input | Classifier output |
|---|---|
| `` (empty) | `branch`, high |
| `PR #42` | `pr`, high, pr_number=42 |
| `api` (matches profile entry) | `service`, high, service_name="api" |
| `docs/avatar-spec.md` (exists) | `spec`, high |
| `src/api/users.ts` (exists, not spec) | `artifact`, high |
| `src/api/` (exists, dir) | `artifact-dir`, high |
| `avatar upload should resize to 256px` | `prose`, medium |
| `foo` (no file, no entry match) | `prose`, low → ask user |
```

- [ ] **Step 2: Verify file exists and is well-formed**

Run: `test -f skills/x-qa/references/intent-detection.md && head -5 skills/x-qa/references/intent-detection.md`
Expected: file present, starts with `# Intent Detection`

- [ ] **Step 3: Commit**

```bash
git add skills/x-qa/references/intent-detection.md
git commit -m "feat(x-qa): add intent-detection reference doc"
```

---

### Task 2: Classifier bash script

**Files:**
- Create: `skills/x-qa/scripts/classify-intent.sh`
- Create: `skills/x-qa/scripts/tests/classify.sh`
- Create: `skills/x-qa/scripts/tests/fixtures/intent-cases.txt`

- [ ] **Step 1: Write fixture cases**

Create `skills/x-qa/scripts/tests/fixtures/intent-cases.txt`:

```
# format: <expected-intent>|<input>|<setup-hint>
branch||
pr|PR #42|
pr|#42|
pr|https://github.com/o/r/pull/42|
service|api|profile-has-api
spec|docs/avatar.md|create-file-docs/avatar.md
artifact|src/api/users.ts|create-file-src/api/users.ts
artifact-dir|src/api|create-dir-src/api
prose|avatar upload should resize|
prose|qwertyfoobar|
```

- [ ] **Step 2: Write the failing test**

Create `skills/x-qa/scripts/tests/classify.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURES="$SKILL_DIR/scripts/tests/fixtures/intent-cases.txt"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
cd "$WORK"; git init -q

# Minimal profile with one entry named "api"
mkdir -p .x-skills/x-qa
cat > .x-skills/x-qa/profile.json <<'JSON'
{ "schema":1, "version":"1.0.0", "primary_entry_point":"api",
  "entry_points":[{"name":"api","type":"http","auto_managed":true,
    "launch":{"kind":"command","command":"true"},
    "base_url_template":"http://localhost:1","base_url_fallback":"http://localhost:1",
    "health":{"method":"GET","path":"/","expected_status":200},
    "primary":true,"verified":false}]}
JSON

pass=0; fail=0
while IFS='|' read -r expected input setup; do
  [[ "$expected" =~ ^# ]] || [[ -z "$expected" ]] && continue
  case "$setup" in
    create-file-*) path="${setup#create-file-}"; mkdir -p "$(dirname "$path")"; touch "$path" ;;
    create-dir-*)  mkdir -p "${setup#create-dir-}" ;;
  esac
  got=$("$SKILL_DIR/scripts/classify-intent.sh" "$input" | jq -r '.intent')
  if [[ "$got" == "$expected" ]]; then
    pass=$((pass+1))
  else
    fail=$((fail+1))
    echo "FAIL: input=[$input] expected=$expected got=$got"
  fi
done < "$FIXTURES"

echo "classify smoke: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
```

- [ ] **Step 3: Run test to verify it fails**

Run: `chmod +x skills/x-qa/scripts/tests/classify.sh && skills/x-qa/scripts/tests/classify.sh`
Expected: FAIL with "No such file or directory" for `classify-intent.sh`

- [ ] **Step 4: Implement the classifier**

Create `skills/x-qa/scripts/classify-intent.sh`:

```bash
#!/usr/bin/env bash
# classify-intent.sh <raw-input>
# Emits intent.json on stdout. Pure bash + jq. No LLM.
set -euo pipefail

RAW="${1:-}"
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PROFILE="$REPO_ROOT/.x-skills/x-qa/profile.json"

intent=""; confidence="high"
pr_number=""; branch=""; service=""; spec=""; artifact=""; prose=""

trim="${RAW#"${RAW%%[![:space:]]*}"}"; trim="${trim%"${trim##*[![:space:]]}"}"

if [[ -z "$trim" ]]; then
  intent="branch"
elif [[ "$trim" =~ ^(PR[[:space:]]*)?#?([0-9]+)$ ]] || \
     [[ "$trim" =~ github\.com/[^/]+/[^/]+/pull/([0-9]+) ]]; then
  intent="pr"; pr_number="${BASH_REMATCH[2]:-${BASH_REMATCH[1]}}"
elif [[ -f "$PROFILE" ]] && jq -e --arg n "$trim" '.entry_points[] | select(.name==$n)' "$PROFILE" >/dev/null 2>&1; then
  intent="service"; service="$trim"
elif [[ -f "$trim" ]]; then
  case "$trim" in
    docs/*|specs/*|*.md|*.txt|*.rst) intent="spec"; spec="$trim" ;;
    *)                                intent="artifact"; artifact="$trim" ;;
  esac
elif [[ -d "$trim" ]]; then
  intent="artifact-dir"; artifact="$trim"
else
  intent="prose"; prose="$trim"
  # confidence low if input is one word with no spec-like markers
  [[ "$trim" =~ ^[A-Za-z0-9_-]+$ ]] && confidence="low"
  [[ ${#trim} -lt 8 ]] && confidence="low"
  [[ "$confidence" != "low" ]] && confidence="medium"
fi

jq -n \
  --arg intent "$intent" --arg raw "$RAW" --arg confidence "$confidence" \
  --arg pr "$pr_number" --arg branch "$branch" --arg service "$service" \
  --arg spec "$spec" --arg artifact "$artifact" --arg prose "$prose" \
  '{
     intent: $intent,
     raw: $raw,
     confidence: $confidence,
     resolved: {
       pr_number: (if $pr=="" then null else ($pr|tonumber) end),
       branch:    (if $branch=="" then null else $branch end),
       service_name: (if $service=="" then null else $service end),
       spec_path:    (if $spec=="" then null else $spec end),
       artifact_path:(if $artifact=="" then null else $artifact end),
       prose:        (if $prose=="" then null else $prose end)
     },
     candidates: []
   }'
```

- [ ] **Step 5: Run test to verify it passes**

Run: `chmod +x skills/x-qa/scripts/classify-intent.sh && skills/x-qa/scripts/tests/classify.sh`
Expected: `classify smoke: 10 passed, 0 failed` (or matching the fixture count)

- [ ] **Step 6: Commit**

```bash
git add skills/x-qa/scripts/classify-intent.sh skills/x-qa/scripts/tests/classify.sh skills/x-qa/scripts/tests/fixtures/intent-cases.txt
git commit -m "feat(x-qa): add classify-intent.sh + smoke test"
```

---

### Task 3: Scout prompt + scope envelope reference

**Files:**
- Create: `skills/x-qa/references/scout-prompt.md`

- [ ] **Step 1: Write the reference**

Create `skills/x-qa/references/scout-prompt.md`:

```markdown
# Scout Subagent

The scout dispatches when `intent ∈ {spec, artifact, artifact-dir, prose}`.
For `branch` / `pr` / `service` the existing static derivation suffices —
no scout.

## Runner Pair

Reuse the bootstrap-pinned `X_QA_SIMPLE_RUNNER` (gemini-flash by default;
OMC executor / Explore when gemini_cli is unpinned). Scout is one
short-lived dispatch — NOT `run_in_background` — orchestrator waits inline.

## Prompt Template

The scout receives `intent.json` plus the repo root. It MUST emit a single
JSON scope envelope to stdout. No prose.

```
You are a QA scope scout. Read the input below and produce a JSON scope
envelope that the QA planner will use to write test cases. Do NOT write
test cases yourself. Do NOT execute anything.

Input intent: <INTENT_JSON>
Repo root: <REPO_ROOT>

Procedure:
1. Read the source-of-truth for this intent:
   - spec         → read the spec file
   - artifact     → read the file, then walk references (morph codebase_search up to depth 2)
   - artifact-dir → list files in the dir, read key ones
   - prose        → grep the repo for related identifiers
2. Identify reachable endpoints/behaviors that should be tested.
3. List edge cases the source-of-truth implies.
4. Cap output: ≤ 20 endpoints, ≤ 40 edge cases.

Emit ONLY this JSON to stdout:

{
  "intent": "<echo>",
  "feature_summary": "<one paragraph>",
  "touched_endpoints": ["/api/x", "/api/y"],
  "touched_files":     ["src/a.ts", "src/b.ts"],
  "behaviors":         ["uploads accept jpeg/png", "rejects >2MB"],
  "edge_cases":        ["empty body", "missing auth", "boundary 2MB"],
  "open_questions":    ["what is max upload size?"]
}

If you cannot determine scope (zero touched files), output:
{ "intent":"<echo>", "scope_empty": true, "reason":"<one-line>" }
```

## Output Path

Write the scope envelope to `<run-dir>/scope.json`.

## Plan Generator Contract

When `scope.json` exists, the planner MUST:
- Constrain `test_cases[]` to `touched_endpoints` (refuse cases outside).
- Emit at least one case per `behaviors[]` entry.
- Emit at least one `edge` or `error` case per `edge_cases[]` entry.
- Surface `open_questions[]` in the run output as warnings.

If `scope_empty: true`, fall back to whole-profile coverage and warn.

## Failure Modes

- Scout returns invalid JSON → quarantine to `<run-dir>/scope.raw`,
  fall back to whole-profile coverage, warn.
- Scout times out (>60s) → same fallback.
- Scout `open_questions` non-empty → propagate to QA_REPORT.md notes section.
```

- [ ] **Step 2: Verify**

Run: `test -f skills/x-qa/references/scout-prompt.md && grep -q 'scope_empty' skills/x-qa/references/scout-prompt.md`
Expected: exit 0

- [ ] **Step 3: Commit**

```bash
git add skills/x-qa/references/scout-prompt.md
git commit -m "feat(x-qa): add scout-prompt reference + scope envelope schema"
```

---

### Task 4: Extend test-plan schema with `depends_on`

**Files:**
- Modify: `skills/x-qa/references/test-plan-schema.md`
- Modify: `skills/x-qa/templates/test-plan.example.yml`

- [ ] **Step 1: Add depends_on field to schema**

Edit `skills/x-qa/references/test-plan-schema.md`, in the `## TestCase` table add a row after `timeout_ms`:

```markdown
| `depends_on` | string[] | no | List of `test_case.id` values that MUST pass before this case runs. Empty/absent = no deps (parallel-eligible). Cycles refused by dispatcher. |
| `parallel_group` | string | no | Optional hint: cases sharing a group run together in one wave. Without it, the dispatcher infers waves from `depends_on` topology. |
```

After the schema tables, add a new section:

```markdown
## Sequencing Semantics

Dispatcher behavior:
1. Build a DAG: nodes = `test_cases[].id`, edges = `depends_on`.
2. Refuse the plan if the DAG has a cycle (`scripts/lib/topo-order.sh` returns non-zero).
3. Compute waves via Kahn's algorithm. All cases in a wave dispatch in
   parallel (capped at `--max-bg`). Wave N+1 starts after every case in
   wave N reaches a terminal verdict.
4. A `fail` in wave N skips downstream dependents (mark `skipped`,
   not `fail`, in QA_REPORT.md). Independent branches continue.

If `depends_on` is empty across all cases, behavior matches v1 (flat
parallel fanout). Backwards compatible.
```

- [ ] **Step 2: Update example YAML**

Edit `skills/x-qa/templates/test-plan.example.yml` — append two cases that demonstrate a login → use-token chain. If the file does not exist or lacks examples, replace its content with:

```yaml
feature: avatar-upload
entry_point: api
acceptance:
  - "User can upload a jpeg ≤ 2MB"
  - "Server rejects >2MB with 413"
qa_strategy:
  base_url_var: BASE_URL
test_cases:
  - id: tc-001
    category: happy
    complexity: simple
    description: "GET /health responds 200"
    request: { method: GET, path: /health }
    assertions:
      - { kind: status, expr: "", op: eq, value: 200 }

  - id: tc-002
    category: auth
    complexity: complex
    description: "POST /auth/login returns token"
    request:
      method: POST
      path: /auth/login
      body: { user: "${FIXTURE_USER}", pass: "${FIXTURE_PASS}" }
    assertions:
      - { kind: status, expr: "", op: eq, value: 200 }
      - { kind: body-jsonpath, expr: "$.token", op: matches, value: "^[A-Za-z0-9._-]+$" }

  - id: tc-003
    category: happy
    complexity: complex
    description: "Upload avatar with token from tc-002"
    depends_on: [tc-002]
    request:
      method: POST
      path: /me/avatar
      headers: { Authorization: "Bearer ${TC_002_TOKEN}" }
    assertions:
      - { kind: status, expr: "", op: eq, value: 201 }
```

- [ ] **Step 3: Verify**

Run: `grep -q 'depends_on' skills/x-qa/references/test-plan-schema.md && grep -q 'tc-002' skills/x-qa/templates/test-plan.example.yml`
Expected: exit 0

- [ ] **Step 4: Commit**

```bash
git add skills/x-qa/references/test-plan-schema.md skills/x-qa/templates/test-plan.example.yml
git commit -m "feat(x-qa): add depends_on + parallel_group to plan schema"
```

---

### Task 5: Topological dispatch helper

**Files:**
- Create: `skills/x-qa/scripts/lib/topo-order.sh`
- Create: `skills/x-qa/scripts/tests/topo.sh`

- [ ] **Step 1: Write the failing test**

Create `skills/x-qa/scripts/tests/topo.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TOPO="$SKILL_DIR/scripts/lib/topo-order.sh"

# Plan with 3 cases: tc-003 depends on tc-002; tc-001 independent.
plan=$(cat <<'JSON'
{ "test_cases": [
  { "id": "tc-001", "depends_on": [] },
  { "id": "tc-002", "depends_on": [] },
  { "id": "tc-003", "depends_on": ["tc-002"] }
]}
JSON
)

out=$(echo "$plan" | "$TOPO")
echo "$out"

# Expect: wave 0 has tc-001 and tc-002 (order-insensitive), wave 1 has tc-003.
w0=$(echo "$out" | jq -c '.waves[0] | sort')
w1=$(echo "$out" | jq -c '.waves[1] | sort')
[[ "$w0" == '["tc-001","tc-002"]' ]] || { echo "FAIL wave0: $w0"; exit 1; }
[[ "$w1" == '["tc-003"]' ]]          || { echo "FAIL wave1: $w1"; exit 1; }

# Cycle case must fail with exit code 2.
cycle=$(cat <<'JSON'
{ "test_cases": [
  { "id": "a", "depends_on": ["b"] },
  { "id": "b", "depends_on": ["a"] }
]}
JSON
)
set +e
echo "$cycle" | "$TOPO" >/dev/null 2>&1; rc=$?
set -e
[[ $rc -eq 2 ]] || { echo "FAIL cycle exit: got $rc, want 2"; exit 1; }

echo "topo smoke: OK"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `chmod +x skills/x-qa/scripts/tests/topo.sh && skills/x-qa/scripts/tests/topo.sh`
Expected: FAIL with "No such file or directory" for `topo-order.sh`

- [ ] **Step 3: Implement topo-order.sh**

Create `skills/x-qa/scripts/lib/topo-order.sh`:

```bash
#!/usr/bin/env bash
# topo-order.sh — read a test-plan JSON on stdin, emit { "waves": [[id,...], ...] }
# Exit 0 = OK, 2 = cycle detected, 1 = malformed input.
set -euo pipefail

plan=$(cat) || { echo "read failed" >&2; exit 1; }

# Validate JSON and required fields
echo "$plan" | jq -e '.test_cases' >/dev/null || { echo "missing test_cases" >&2; exit 1; }

# Kahn's algorithm via jq
result=$(echo "$plan" | jq -c '
  def kahn:
    . as $plan
    | ($plan.test_cases | map({ id: .id, deps: (.depends_on // []) })) as $nodes
    | { waves: [], remaining: $nodes }
    | until((.remaining|length) == 0;
        (.remaining | map(select((.deps|length) == 0)) | map(.id)) as $ready
        | if ($ready|length) == 0 then .cycle = true | .remaining = [] else . end
        | if .cycle == true then . else
            .waves += [$ready]
            | .remaining |= (
                map(select((.id as $i | $ready | index($i)) | not))
                | map(.deps |= map(select(. as $d | $ready | index($d) | not)))
              )
          end
      )
    | if .cycle == true then { cycle: true } else { waves: .waves } end;
  kahn
')

if echo "$result" | jq -e '.cycle == true' >/dev/null; then
  echo "topo-order: cycle detected in depends_on" >&2
  exit 2
fi

echo "$result"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `chmod +x skills/x-qa/scripts/lib/topo-order.sh && skills/x-qa/scripts/tests/topo.sh`
Expected: `topo smoke: OK`

- [ ] **Step 5: Commit**

```bash
git add skills/x-qa/scripts/lib/topo-order.sh skills/x-qa/scripts/tests/topo.sh
git commit -m "feat(x-qa): add topo-order.sh dispatch scheduler + smoke test"
```

---

### Task 6: Wire new helpers into smoke.sh

**Files:**
- Modify: `skills/x-qa/scripts/tests/smoke.sh`

- [ ] **Step 1: Read current smoke.sh tail to find the right hook point**

Run: `tail -30 skills/x-qa/scripts/tests/smoke.sh`
Expected: see the final assertions / exit line

- [ ] **Step 2: Append classifier + topo smoke calls**

At the bottom of `skills/x-qa/scripts/tests/smoke.sh`, before the final exit, append:

```bash
# --- new in 2026-05-11 plan: classifier + topo smoke ---
echo "→ running classify smoke"
bash "$SKILL_DIR/scripts/tests/classify.sh"
echo "→ running topo-order smoke"
bash "$SKILL_DIR/scripts/tests/topo.sh"
```

If smoke.sh has an explicit `exit 0` at the bottom, insert these calls *before* it.

- [ ] **Step 3: Run combined smoke**

Run: `bash skills/x-qa/scripts/tests/smoke.sh`
Expected: existing smoke output PLUS `classify smoke: ... 0 failed` and `topo smoke: OK`

- [ ] **Step 4: Commit**

```bash
git add skills/x-qa/scripts/tests/smoke.sh
git commit -m "test(x-qa): chain classify + topo into smoke.sh"
```

---

### Task 7: Update SKILL.md Run Phases

**Files:**
- Modify: `skills/x-qa/SKILL.md`

- [ ] **Step 1: Insert Phase 2.5 (Classify) and Phase 3.5 (Scout) into Run Phases**

In `skills/x-qa/SKILL.md`, find the `## Run Phases` section. Replace the numbered list (currently 1–13) with:

```markdown
## Run Phases

1. Bootstrap (above).
2. Auto-doctor (skippable via `--skip-doctor`).
3. **Classify intent.** Run `scripts/classify-intent.sh "{{ARGUMENTS}}"`, persist to `<run-dir>/intent.json`. If `confidence == "low"` OR multiple candidates surface, ask the user ONE question per `references/intent-detection.md § Ask-When-Ambiguous`, then rewrite intent.json.
4. Resolve target from intent: `service` → entry name; `branch`/`pr` → PR-surface derivation (`references/pr-surface-derivation.md`); `spec`/`artifact`/`artifact-dir`/`prose` → trigger Phase 5 (Scout). Refuse if resolved entry's `type != http` (v1 limitation).
5. **Scout (conditional).** Only when intent ∈ {`spec`, `artifact`, `artifact-dir`, `prose`}: dispatch `$X_QA_SIMPLE_RUNNER` inline per `references/scout-prompt.md`. Persist `<run-dir>/scope.json`. On invalid JSON / timeout, fall back to whole-profile coverage and warn.
6. Plan: read `--plan <path>` if given, else generate per `references/test-plan-schema.md` using profile catalog + (if present) `scope.json` as ground truth.
7. Launch service via `scripts/launch-entry-point.sh` (skipped on `--no-launch` or `--service <ext-url>`).
8. Health wait via `scripts/health-wait.sh`.
9. Classify cases per `references/classification-rules.md` (simple vs complex).
10. **Compute dispatch waves.** Pipe plan JSON through `scripts/lib/topo-order.sh`. Refuse plan on cycle. Each wave dispatches in parallel (capped at `--max-bg`, all `run_in_background: true`); next wave starts when every case in current wave reaches terminal state. Cases whose deps failed are marked `skipped`, not `fail`. Templates in `references/case-runner-prompts.md`.
11. Collect every dispatch terminal state (mandatory per `~/.claude/rules/background-agents.md`). Never `background_cancel(all=true)` before collection.
12. Retry flaky inline up to `--retry-flaky`.
13. Teardown via launch entry's `launch.teardown` (skipped if Phase 7 was skipped).
14. Aggregate via `scripts/aggregate-results.sh` → `QA_REPORT.md`. Propagate `scope.json.open_questions` into the report's notes section.
15. Emit envelope.
```

- [ ] **Step 2: Add task-arg note near the top**

In `skills/x-qa/SKILL.md`, find the line `Task: {{ARGUMENTS}}` at the bottom and add directly above the `## Bootstrap` heading (or just below the frontmatter) the following paragraph:

```markdown
## Input Contract

`run` accepts a free-form `{{ARGUMENTS}}` — empty string, `PR #<n>`, an
entry-point name, a file path, a directory, or prose describing a feature.
The bootstrap classifier (Phase 3) resolves it. Explicit flags
(`--pr`/`--branch`/`--service`/`--plan`) override classification. Do NOT
add new user-facing flags for input source — the classifier handles it.
```

- [ ] **Step 3: Refresh Subcommand Routing list**

In `## Subcommand Routing`, replace the `run:` line:

```markdown
- `run`: see "Run Phases" below; intent via `references/intent-detection.md`; scout via `references/scout-prompt.md`
```

- [ ] **Step 4: Verify SKILL.md still parses**

Run: `grep -n 'Phase' skills/x-qa/SKILL.md | head -20`
Expected: see `Phase 2.5` is gone (replaced by step "3. Classify intent"), Run Phases now has 15 numbered items, Classify appears at 3, Scout at 5

- [ ] **Step 5: Commit**

```bash
git add skills/x-qa/SKILL.md
git commit -m "feat(x-qa): wire intent classifier + scout phase into Run Phases"
```

---

### Task 8: Update gotchas.md

**Files:**
- Modify: `skills/x-qa/gotchas.md`

- [ ] **Step 1: Append new gotchas**

At the bottom of `skills/x-qa/gotchas.md`, append:

```markdown

## Intent classification & scout

14. **Single-token prose misclassified.** `x-qa run foo` with no `foo` file
    and no `foo` entry returns `prose, low` and triggers the ask-when-
    ambiguous gate. Tab-complete or quote the input for clarity.
15. **Scout context overflow on large repos.** A `prose` intent in a monorepo
    can balloon scope. Scout caps output at 20 endpoints / 40 edge cases
    (`references/scout-prompt.md`). If the cap fires, the planner sees a
    truncated surface — surface this in QA_REPORT.md as a warning.
16. **Cycle in `depends_on`.** `topo-order.sh` refuses with exit 2 and a
    one-line stderr. Inspect plan YAML; remove the cycle. Common cause:
    LLM-generated plan crosses two unrelated flows that share a fixture.
17. **Skipped vs failed cases.** A `fail` in wave N skips downstream
    dependents. They show `verdict: skipped` in QA_REPORT.md and do NOT
    count toward `flaky_rate`. Only `fail` blocks the run verdict.
18. **Scout dispatched without gemini_cli.** When `gemini_cli` capability is
    unpinned, `X_QA_SIMPLE_RUNNER` falls back to OMC executor / Explore.
    Scout latency rises (~3-5x); cost lower. Acceptable.
```

- [ ] **Step 2: Verify**

Run: `grep -c '^## ' skills/x-qa/gotchas.md`
Expected: at least 5 (sections including the new "Intent classification & scout")

- [ ] **Step 3: Commit**

```bash
git add skills/x-qa/gotchas.md
git commit -m "docs(x-qa): document intent + scout + topo gotchas"
```

---

### Task 9: End-to-end manual verification

**Files:** none (verification only)

- [ ] **Step 1: Run combined smoke suite**

Run: `bash skills/x-qa/scripts/tests/smoke.sh`
Expected: all three smoke blocks (existing + classify + topo) pass

- [ ] **Step 2: Dry-run classifier against each fixture intent**

Run:
```bash
for input in "" "PR #99" "api" "src/api/users.ts" "docs/avatar.md" "avatar upload resize" "z"; do
  echo "--- input=[$input] ---"
  skills/x-qa/scripts/classify-intent.sh "$input"
done
```
Expected: each emits a JSON envelope with the correct `intent` and `confidence`. The empty input → `branch`; `PR #99` → `pr` with pr_number=99; `z` → `prose` with `low` confidence.

- [ ] **Step 3: Spot-check SKILL.md flow**

Open `skills/x-qa/SKILL.md` and read Phases 3, 4, 5 aloud. Confirm:
- Phase 3 calls `classify-intent.sh` and writes `intent.json`.
- Phase 4 branches on intent.
- Phase 5 dispatches scout ONLY for spec/artifact/artifact-dir/prose.
- Phase 10 references `topo-order.sh`.

- [ ] **Step 4: Final commit (only if any drift was caught)**

If verification revealed missing wiring, fix inline, then:

```bash
git add -A
git commit -m "fix(x-qa): plan verification fixes"
```

If clean, skip the commit.

---

## Self-Review Notes

**Spec coverage check:**
- ✅ Auto-detect intent (no flag explosion) → Tasks 1–2 (doc + classifier)
- ✅ Scout subagent for feature-spec/artifact inputs → Tasks 3, 7 (Phase 5)
- ✅ QA lead writes test plan → existing planner unchanged; consumes scope.json
- ✅ Parallel OR sequential per plan → Tasks 4–5 (depends_on + topo-order)
- ✅ Ask-when-ambiguous → Task 1 § Ask-When-Ambiguous + Task 7 Phase 3
- ✅ Use x-gemini or x-omo for scout → reuses pinned `X_QA_SIMPLE_RUNNER`, no new runner abstraction

**Backwards compat:** plans without `depends_on` flatten to wave 0 → existing flat fanout. Profiles unchanged. `init`/`update`/`doctor`/`inspect`/`generate` unchanged. x-team integration unchanged (still calls `run --worktree …`, classifier on empty input degrades to `branch`).

**Skipped:** non-HTTP execution (gotcha #12) — out of scope; v2 work. TeamCreate-based dispatch — out of scope; bg dispatch is sufficient.
