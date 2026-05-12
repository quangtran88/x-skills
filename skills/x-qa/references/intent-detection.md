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
| anything else (free-form prose) | terminal branch | `prose` (scout greps repo for related code) |

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
  "candidates": []
}
```

Unused fields are `null`. Exactly one `resolved.*` field is non-null per
intent, except `artifact` and `artifact-dir` which both populate
`artifact_path`. The `candidates` array is emitted as `[]` by
`classify-intent.sh` (pure bash, no LLM context); the orchestrator may
populate it before the ask-when-ambiguous gate when it can compute
alternatives (e.g. fuzzy service-name matches against the profile).

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
