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

## Knowledge base (KB)

19. **Stale baseline trap.** `kb/baselines/*.json` are observational, not
    ground-truth. A baseline that hasn't been hit for weeks can encode an
    old endpoint shape; doctor warns via `last_seen_at`. To prune by hand,
    `rm` the JSON and `jq 'del(.baselines["<endpoint>"])'` the index.
20. **Corpus drift on endpoint rename.** When code renames an endpoint
    (`POST /api/v1/x` → `/api/v2/x`), the matching corpus case still
    targets the old path. The planner emits `corpus-stale` and skips the
    case; doctor does NOT auto-fail. Resolution: edit the case YAML in
    place, or `git rm` it and let the planner mint a fresh one on the
    next run.
21. **Schema pin.** `schema: 1` is hard-pinned in `kb/index.json`, every
    `kb/cases/*.yaml`, `kb/flows/*.yaml`, `kb/baselines/*.json`. v1
    refuses unknown schema; there is no migration tool yet.
22. **Cross-team merge conflicts.** Two devs auto-promoting the same case
    in parallel branches produces conflicting `kb/index.json` entries +
    duplicate `cases/*.yaml`. Resolution: keep the entry with the higher
    `green_streak`; manually merge YAML if bodies differ. `kb-prune.sh
    --orphans` cleans up dangling files post-merge.
23. **Auto-promotion of flaky cases.** A `pass` from a flaky-recovered
    retry does NOT count toward the streak (only the verdict literally
    `pass` does). A case that consistently passes after transient fails
    can still drift in — review the corpus periodically with `kb-list`
    and `kb-inspect`.
24. **Empty body_path in ledger.** If a case JSON is malformed, its
    `body_path` may be absent from the ledger line. Auto-promote skips
    these with `[skip] <id>: streak=N but no body file recorded`. Look
    at runner stderr to fix the upstream JSON shape.
25. **Flow promotion needs all-promoted constituents.** A flow only
    promotes when every case in its chain is already a corpus case. New
    chains light up on the run *immediately after* the last constituent
    promotes. Expect a one-run lag.
26. **`--no-kb` skips ALL KB ops.** No corpus consult, no baseline
    update, no ledger append, no auto-promote. Use for one-off
    experimental runs you do not want to pollute the corpus.
27. **bash 3.2 compatibility.** macOS ships bash 3.2 — no `declare -A`.
    All KB scripts compute streaks / fail-streaks via jq instead of
    associative arrays so they run on stock macOS.

### Regression False-Positive on Single-Run History

`kb-writeback.sh --check-regression <slug>` requires `history[-2].pass AND history[-1].fail|error`. A signature with only one entry returns `false` — it cannot have regressed yet. But a flaky case whose history is `..., pass, pass, fail` correctly emits `regression: true` even though the underlying issue might be transient. Cross-reference the flaky-rate gate (`tests.flakyRate`) before treating a single regression as actionable; if the same signature also has a high `flakyRate`, the regression is likely a flake and not a true bug. Do NOT auto-page on regression alone.

### Gate Threshold Drift

Quality-gate thresholds are static in `TEST_PLAN.yml` or `profile.json.gates.defaults`. When upstream services tighten their SLOs (p95 drops from 500ms to 300ms) or the team adds new auth-required endpoints, the local gates can drift out of alignment. `aggregate-results.sh` records every gate evaluation with its bound and measured value in `gate_results[]`, but it does NOT alert on a string of `warn`s that suggest the threshold is too loose. Audit `gate_results` periodically; bump thresholds when the team agrees the new floor is the real floor, not when one run happens to be warmer.

### Gap-Analyzer Clock Skew

`scripts/gap-analyze.sh` computes `staleness_days` against `date +%s` on the host running the analyzer. If the host's clock is significantly skewed (CI runner with wrong NTP, a developer machine asleep mid-run), the `stale` category can spike or collapse. The script logs `gap-analyze: skipping <sig> — unparseable timestamp <ts>` for obviously bad timestamps but does NOT detect "the host is off by 14 days." Run `date -u` before trusting a large stale set; if the host clock is suspect, set `--staleness-days 99999` to suppress staleness while you investigate, never to mark stale signatures as fresh.
