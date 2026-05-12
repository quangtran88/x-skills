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

If `scope_empty: true`, the planner uses whole-profile coverage and warns.

## Failure Modes

- Scout returns invalid JSON → quarantine to `<run-dir>/scope.raw`,
  uses whole-profile coverage, warn.
- Scout times out (>60s) → same: whole-profile coverage, warn.
- Scout `open_questions` non-empty → propagate to QA_REPORT.md notes section.
