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
   - artifact     → read the file, then walk references (native `Grep` / OMO `explore` up to depth 2)
   - artifact-dir → list files in the dir, read key ones
   - prose        → grep the repo for related identifiers
2. Identify reachable endpoints/behaviors that should be tested.
3. List edge cases the source-of-truth implies.
4. Build the domain model (see "## Domain Research" below): entities + field
   constraints + business invariants + the state machine.
5. Enumerate obligations from the domain model AND the failure-mode taxonomy
   (`references/failure-mode-taxonomy.md`). Mark `required` vs `recommended`.
6. Cap output: ≤ 20 endpoints, ≤ 40 edge cases, ≤ 60 obligations.

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

If you cannot determine scope (zero touched files), output:
{ "intent":"<echo>", "scope_empty": true, "reason":"<one-line>" }
```

## Domain Research

Before enumerating obligations, model the domain — **code-first**:

1. **Read the code** that defines the rules: data models / ORM entities,
   migrations, validators / schema files (zod, pydantic, JSON-Schema, DTOs),
   enum/state definitions, and the handler for each touched endpoint. Use
   OMO `explore` (or native `Grep`) for "where is <entity> validated / its state
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

## Output Path

Write the scope envelope to `<run-dir>/scope.json`.

## Plan Generator Contract

When `scope.json` exists, the planner MUST:
- Constrain `test_cases[]` to `touched_endpoints` (refuse cases outside).
- Emit at least one case per `behaviors[]` entry.
- Emit at least one `edge` or `error` case per `edge_cases[]` entry.
- Surface `open_questions[]` in the run output as warnings.
- Emit ≥1 `test_cases[]` entry covering **every `severity: required` obligation**
  in `obligations[]`, tagging each case with the obligation id(s) it satisfies
  via `covers: [...]` (see `references/test-plan-schema.md`). The coverage gate
  (`scripts/coverage-check.sh`) refuses a plan that leaves any required
  obligation uncovered.

If `scope_empty: true`, the planner uses whole-profile coverage and warns.

## Failure Modes

- Scout returns invalid JSON → quarantine to `<run-dir>/scope.raw`,
  uses whole-profile coverage, warn.
- Scout times out (>60s) → same: whole-profile coverage, warn.
- Scout `open_questions` non-empty → propagate to QA_REPORT.md notes section.

## User Hints Block (Convention)

When the run was invoked with prose intent (`intent.json.intent == "prose"`) or with free-form `--service`/`--branch`/`--pr` plus an inline description, the scout prompt MUST include the user's raw text as a dedicated `## User Hints` markdown block, NOT mixed into the directive prose.

Placement: immediately before the `## Task` block, immediately after any code-context blocks. Format:

```markdown
## User Hints (prioritization guidance, may be empty)

> {{intent.json.resolved.prose}}

## Task
…
```

**Rationale.** Verbatim isolation prevents the LLM from treating user hints as instructions to override the scout's structured contract. The leading `>` blockquote marker makes the boundary visually unambiguous in transcripts.

**Empty case.** When no prose is present, emit:

```markdown
## User Hints (prioritization guidance, may be empty)

> (none)
```

Do NOT omit the block — its presence is part of the prompt's stable shape.