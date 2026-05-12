# x-qa Gotchas

## Service launch

1. **Slow image pull on first run.** First `docker compose up` after a fresh checkout pulls images. Set `health.timeout_s` ≥ 120 if your stack does this.
2. **Port collision across worktrees.** If `launch.uses_isolate_profile: true`, ports are allocated via `x-worktree-isolate`. Without isolate, two parallel runs collide. Solution: enable isolate or run sequentially.
3. **State drift between cases.** DB rows from case N leak into case N+1. Use `fixtures.reset_strategy: per-case` (slow, safe) or design test data to be non-overlapping.

## Plan generation

4. **Endpoint hallucination.** LLM planners invent endpoints not in code. Mitigation: `plan-generate.sh` passes the OpenAPI spec + scanned route catalog as ground truth. Refuse cases referencing endpoints not in catalog.
5. **Auth fixture leak.** Plan author writes literal token in YAML. `doctor.sh` rejects on profile; planner should also reject. Always use `${ENV_VAR}` substitution.

## Dispatch

6. **Background result loss.** Per `~/.claude/rules/background-agents.md`: NEVER `background_cancel(all=true)` before reading every dispatch's output. Aggregator detects missing case files and synthesises failures, but you lose evidence.
7. **Gemini quota throttling.** With `--max-bg 8` sustained, Gemini Ultra may 429. Backoff is not implemented in v1. If you see frequent 429s, drop to `--max-bg 4`.
8. **Runner outputs invalid JSON.** Gemini occasionally wraps JSON in markdown fences despite the prompt forbidding it. Aggregator quarantines to `cases/<id>.raw` and synthesises a fail.

## Profile

9. **`schema: 1` mismatch.** Hard-fail on read. No silent migration. Bump tooling first, then write profiles with the new schema.
10. **`auto_managed: false` blocks update.** User-edited entries are preserved. To force re-sync, run `update --allow-overwrite-user-edits` (destroys user customisations).
11. **`repo_root` drift.** Cloning the repo to a new path makes `repo_root` stale. Doctor surfaces this; fix via `update`.

## v1 limitations

12. **Only `type: http` runs.** v1 `run` skips cli/grpc/graphql/worker/websocket entries with a clear notice. Schema persists them for v2.
13. **No nested OMC team.** v1 fanout is bg-dispatch only. For >50 concurrent cases, you'll feel the local concurrency cap.

## Intent classification & scout

14. **Single-token prose misclassified.** `x-qa run foo` with no `foo` file
    and no `foo` entry returns `prose, low` and triggers the ask-when-
    ambiguous gate. Tab-complete or quote the input for clarity.
15. **Scout context overflow on large repos.** A `prose` intent in a monorepo
    can balloon scope. Scout caps output at 20 endpoints / 40 edge cases
    (`references/scout-prompt.md`). If the cap fires, the planner sees a
    truncated surface — surface this in QA_REPORT.md as a warning.
16. **Cycle in `depends_on`.** `topo-order.sh` refuses with exit 2 and a
    one-line stderr. An *unknown* dependency id (typo) exits 1 instead.
    Inspect the plan YAML and either fix the typo (exit 1) or remove the
    cycle (exit 2).
17. **Skipped vs failed cases.** A `fail` in wave N skips downstream
    dependents. They show `verdict: skipped` in QA_REPORT.md and do NOT
    count toward `flaky_rate`. Only `fail` blocks the run verdict.
18. **Scout dispatched without gemini_cli.** When `gemini_cli` capability is
    unpinned, `X_QA_SIMPLE_RUNNER` resolves to OMC executor / Explore.
    Scout latency rises (~3-5x); cost lower. Acceptable.
