# Case Runner Prompts

Each test case becomes one bg dispatch. Output is a single JSON document at `<run-dir>/cases/<case-id>.json` matching the CaseResult schema (see `qa-report-schema.md`).

## Simple Runner — gemini-bg

Dispatched via `Bash(run_in_background: true)` against the `gemini-agent` bridge from `skills/x-gemini` (resolves the right model id and binds to the Google Ultra subscription):

```bash
gemini-agent --model flash "$PROMPT" > "$RUN_DIR/cases/$CASE_ID.json"
```

`--model flash` resolves to `gemini-2.5-flash` (per `skills/x-gemini/SKILL.md` model table). Do NOT call the raw `gemini` CLI directly with `--model gemini-3.x-flash` — that flag and that model id are not real.

If `gemini_cli` capability is unpinned, `bootstrap` falls back to the simple runner stored in env var `X_QA_SIMPLE_RUNNER` (e.g., `Agent oh-my-claudecode:executor model=haiku`).

Where `$PROMPT`:

```
You are a single-shot HTTP test runner. Execute exactly ONE HTTP request and check assertions. Output ONLY a JSON document.

Base URL: <BASE_URL>
Case ID: <CASE_ID>

Request:
  Method: <METHOD>
  Path: <PATH>
  Headers: <HEADERS_JSON>
  Body: <BODY_JSON>
  Query: <QUERY_JSON>

Assertions:
  <ASSERTIONS_JSON>

Auth (if any): <AUTH_HEADER>

Procedure:
1. Build the full URL.
2. Execute via curl with --max-time 30.
3. Capture status, headers, body, latency.
4. Evaluate every assertion.
5. Output JSON exactly:

{
  "id": "<CASE_ID>",
  "verdict": "pass" | "fail",
  "runner": "gemini-flash",
  "attempts": 1,
  "evidence": {
    "request": { "method": "...", "url": "...", "headers": {...}, "body": {...} },
    "response": { "status": ..., "headers": {...}, "body": {...} },
    "latency_ms": ...
  },
  "duration_ms": ...,
  "error": ""
}

Output ONLY this JSON. No prose, no markdown fences, no commentary.
```

## Complex Runner — claude-bg (qa-tester or Explore)

Dispatched via `Agent(run_in_background: true)`. The bootstrap step pins the resolved subagent_type into `X_QA_COMPLEX_RUNNER` (e.g., `oh-my-claudecode:qa-tester` when `plugin.omc` is pinned, `Explore` otherwise). Reference the env var, not the literal name:

```python
Agent(
  description="QA case <CASE_ID>",
  subagent_type=os.environ["X_QA_COMPLEX_RUNNER"],  # e.g. "oh-my-claudecode:qa-tester"
  model="sonnet",
  run_in_background=True,
  prompt=COMPLEX_PROMPT
)
```

> Plain `subagent_type="qa-tester"` resolves to no agent in this plugin — OMC agents register under the `oh-my-claudecode:` namespace (see `skills/x-shared/invocation-guide.md:10,203`). Always use the namespaced form when `plugin.omc` is pinned.

## Output Path Convention

`<run-dir>/cases/<case-id>.json` — exactly. Aggregator (`aggregate-results.sh`) globs this path.

## Failure Modes

- Runner times out: aggregator detects missing case file → marks as `fail` with `error: "runner timeout"`.
- Runner emits invalid JSON: aggregator catches jq error → marks as `fail` with `error: "invalid json output"` and quarantines raw output to `<run-dir>/cases/<case-id>.raw`.
- Runner emits valid JSON but missing required fields: aggregator marks as `fail` with `error: "incomplete case result"`.

## Retries (flaky-handling)

If a case verdict is `fail` AND the case is marked `--retry-flaky` eligible, the orchestrator re-runs the SAME prompt up to N times in foreground. If any retry passes, set verdict to `flaky-recovered`.
