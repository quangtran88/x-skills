# Instrument-and-Verify — Proactive Logging & No-Guess Discipline

Shared principle file. Loaded by `x-do` (during execution) and `x-bugfix` (during fix). Promotes observability and citation-grounded reasoning from a reactive last-resort move to a default implementation habit.

## The Three Rules

### 1. Log on first pass (not on the second failure)

Every new feature and every bugfix ships with structured logs at decision points in the same diff as the implementation. Logs are not "added when something breaks" — they are part of the deliverable.

Cover these points at minimum:
- **Entry / exit** of the new function or modified handler.
- **Branches** — every `if/else`, `switch`, early-return, guard clause.
- **State transitions** — anything that flips a flag, mutates shared state, or crosses a callback / async boundary.
- **Error catches** — every `catch` block logs the caught error with structured context, never `console.error(e)` alone.
- **External boundaries** — HTTP calls, DB queries, queue publish, IPC, lib calls into unfamiliar code (log the request shape and the response shape).

**Log decision variables, not narration.** `"got here"` is weak. `{streamStopped: true, sending: false, bufferLen: 23, userId}` is strong. The rule of thumb: if a future debugger has to ask "what was the state when this branch ran?" — the log should already answer it.

**Logs stay after the bug is fixed.** Do not strip diagnostic logs at the end of the task. Downgrade them to debug level if they're noisy, but keep them: the same call chain breaks again, and the next person should not have to re-instrument.

**Match the project's logger.** Read 2-3 nearby files first to find the existing logger import (`pino`, `winston`, `console`, custom wrapper). Do not introduce a new logging dependency for this rule.

### 2. Test-first when touching anything new

Before writing implementation code that calls an unfamiliar library, an upstream module, an external API, or a code path you haven't traced end-to-end, you MUST first verify the real behavior. The order is non-negotiable: **observe, then implement.** Never implement against an assumed API shape.

Acceptable verification artifacts (pick the cheapest that proves the point):

| Artifact | When to use |
|---|---|
| One-line REPL / `node -e "..."` / `python -c "..."` | Quick property check on a known import |
| 10-line scratch script (`/tmp/scratch.{ts,py,sh}`) that prints the real return value | Library call returning a non-trivial shape |
| `curl` against a real endpoint with `-v` | HTTP API or webhook — log full request + response, including headers |
| Reading the lib's source in `node_modules` / source tarball | When the docs are sparse or contradict observed behavior |
| `context7` MCP query for the official docs | Public lib, API surface question, version-sensitive |
| `deepwiki` MCP for the lib's GitHub repo | "How does X library handle Y internally?" |

The output of the verification artifact (the actual return shape, the real error class, the real HTTP status) MUST be cited in the implementation's commit message, PR description, or inline rationale comment when it's not self-evident. Delete the scratch file after copying the knowledge into the implementation. **Do not commit `/tmp/scratch.*` to the repo.**

### 3. Never guess — every claim needs a citation

If you cannot point to one of the following, you do not know — you are guessing:

- A `file:line` in the codebase
- A test output (passing OR failing — both are evidence)
- A log line from a real run
- A doc URL (official lib docs, RFC, spec)
- A successful tool call result you can re-read

Phrases that mean "I am guessing, not knowing":
- "probably …"
- "I think …"
- "should work …"
- "this is how it usually …"
- "by convention …"
- "the lib usually …"

When you catch yourself reaching for any of those: STOP. Go back to rule 2 — run an experiment, then return with evidence. This applies to implementation, debugging, code review, and architectural claims alike.

## When to apply

| Skill / Mode | Application |
|---|---|
| `x-do` Mode A (existing plan) | Forward all 3 rules into the executor's `[CONSTRAINTS]` block in step-04. |
| `x-do` Mode B (new feature) | Same — `[CONSTRAINTS]` block. Logs added in the same diff as the feature. |
| `x-do` Mode D (quick task) | Rule 3 still applies (no guessing). Rule 1 scales down — single-line config edits don't need a log. Rule 2 still applies if a new lib is touched. |
| `x-do` Mode F (refactor) | Rule 3 strict — refactoring without understanding existing behavior breaks invariants. Run characterization tests first. |
| `x-bugfix` Mode A (quick bug) | Rule 1 fires in "Fix & Verify" step 2 — implement WITH logs at the call-chain decision points. Rule 3 fires in "Hypothesize & Test" — hypothesis must cite real evidence. |
| `x-bugfix` Mode B (deep investigation) | Same as Mode A, plus the Instrumentation Pivot is now the *first* move, not a 2-failure fallback. |
| `x-bugfix` Mode Q (quick fix) | Rule 3 still applies — type errors are self-documenting evidence, that's the citation. |

## What this is NOT

- **Not "add 50 log lines to every PR".** Cover the decision points; resist log spam. A 200-line PR with 80 lines of logs is broken.
- **Not "write a test for every line".** Rule 2 is about *new external surface* — unfamiliar libs, untraced paths. Code paths you wrote yesterday don't need a re-verification ritual.
- **Not a replacement for TDD.** TDD (per `superpowers:test-driven-development`) governs WHAT tests to write. This file governs WHAT to know before writing code at all.

## Related

- `../x-bugfix/SKILL.md` § "Instrumentation Pivot" — the reactive sibling of rule 1. After 2 failed hypothesis iterations, this same instrumentation discipline becomes mandatory rather than default.
- `~/.claude/rules/test-before-apply.md` — the global rule that mandates rule 2 at the user level. This file is the skill-level enforcement that propagates the rule into executor subagents.
- `../x-do/references/iteration-patterns.md` — defines what counts as an "iteration" and a "no-progress" signal, used by rule-3 stall detection.
