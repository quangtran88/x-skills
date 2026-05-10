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
