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
13. **Exploratory tier uses a native Claude team when available; deterministic fanout stays bg-dispatch.** Phase 13.5 (the exploratory bug-hunt) spawns a **native Claude team + shared bug-board** when team orchestration (`plugin.omc`) is pinned — workers see each other's findings live and avoid duplicate hunting. When team orchestration is absent it degrades to **background `Agent` fanout** (one bg-dispatch per cluster, findings appended to `board.jsonl`). The deterministic case fanout (Phase 11) always uses bg-dispatch regardless of capability. Bootstrap pins `X_QA_EXPLORE_MODE` (`team` or `bg-fanout`) so the orchestrator never has to re-check mid-run.

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
18. **Scout dispatched without agy_cli.** When `agy_cli` capability is
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

### Precondition Cycle Detected at Plan Time

`doctor.sh` shells out to `scripts/run/resolve-preconditions.sh` for every case in `kb/index.json` and rejects the KB if any resolution exits non-zero with `precondition cycle detected: …`. If you see `plan rejected: precondition cycle detected: tc-a → tc-b → tc-a`, run `scripts/kb-prune.sh --orphans` to surface stale entries, then manually break the cycle by setting one case's `precondition_case_id` to `null` or pointing it at a fresh setup case.

### Auth Case Staleness

`auth_case_id` points at a single case that ages independently. If the login endpoint changes and the case is not updated, EVERY authenticated case fails with `precondition tc-login-* failed: ...`. The gap-analyzer flags the auth case's regression first; fix it before re-running feature cases.

### Forward-Compat Fallback Drift

`references/fallback-contract.md` defines `FallbackResponse` NOW for a tier that wires LATER. If the wiring lands and the contract has drifted (new field added without versioning, types changed), runner outputs will silently miscompile. Bump the schema header from `fallback.v0` to `fallback.v1` BEFORE the first wiring PR, and reject runner outputs whose top-level keys don't match.

- **basic-memory project targeting.** When wiring basic-memory calls in this skill, tool selection and placement/tagging conventions are canonical in `../x-shared/mcp-toolbox.md § basic-memory`. Tools take an optional `project` — omit for the session default; wrong-project writes succeed silently into the wrong store. Do not duplicate; do not work around the capability gate.

## Channels

(a) **Capture-vs-execute.** Non-`http` drivers (`browser`, `computer-use`) are captured at `init` — they appear in `channels[]` and in `QA_MEMORY.md` — but are **skipped at `run`** until their required MCP capability is wired. `run` emits `CHANNEL_SKIPPED=<name> reason=driver '<driver>' not executable` and continues; it does NOT fall back silently to a different channel. See `references/channel-drivers.md` for the feature-gate table and the follow-on plan order.

(b) **Agentic-driver blast radius.** `browser` and `computer-use` drivers operate a real logged-in session. They carry a large prompt-injection blast radius and can take irreversible actions (send messages, submit forms, spend credits). Always use a **dedicated test account**, never a personal one. `QA_MEMORY.md` records the session bootstrap *location* only — never the secret value (`~/.claude/rules/security.md`).

(c) **`entry_point: "external"` has no launch/teardown.** A channel with `entry_point: "external"` (e.g. a hosted chat bot, a third-party SaaS dashboard) is not started by `run`. `launch.command` and `launch.teardown` do not exist for it. `run` MUST NOT attempt to launch or tear down an external channel; it reaches it via the channel's `base_url_template` / `app` + `target` directly. Doctor check C4 enforces that `entry_point` is either `"external"` or a name in `entry_points[]`.

(d) **`--channel` selecting a non-executable driver yields `CHANNEL_SKIPPED`, not a failure.** Passing `--channel dashboard` when `browser` MCP is absent is not an error — it is an expected capture-only state. The run exits with a clear notice, not a failure verdict. This is intentional: teams can profile all channels upfront and activate drivers incrementally without breaking existing runs.

## Research-Driven Generation

(a) **Code-first domain research.** The scout's Domain Research step reads models, validators, and route handlers first. An external research lane (x-research / web) fires **only when the code does not reveal the rule** — not as a default first step. This is a cost guard: LLM-driven web research on every run is expensive and slow; code is cheaper and more authoritative for your actual deployed constraints.

(b) **Obligations are the gate, not categories.** `coverage-check.sh` enforces **`required` obligation ids** from `scope.json.obligations[]`. A test plan can have a perfectly valid `happy` case and still be refused if a `required` `xtrans:` or `inv:` obligation has no case with a matching `covers:` entry. The coverage gate does not look at case categories (`happy`/`error`/`edge`) — it looks at obligation ids. A category label without a `covers:` tag covers nothing.

(c) **The false case needs an assertion on the success response, not just status.** An `inv:` obligation (invariant) is satisfied only by a case that drives the **success path** AND **asserts the correctness of the result** — re-reading state, checking side effects, verifying the caller only sees their own data. A case that asserts `status == 200` alone does NOT satisfy an `inv:` obligation. The most dangerous production bug is a 200 carrying a wrong result; the coverage gate exists precisely to force cases that catch it.

(d) **`domain_model` is ephemeral in the run-dir.** The researched domain model (`scope.json.domain_model`) lives under the current run directory only — it is **not KB-promoted** in this plan. Each run re-researches. This is intentional for v1 (promoting requires staleness/curation machinery the KB already has; see Roadmap item 4). Do not expect `domain_model` to persist across runs or appear in `kb/`.

(e) **`--allow-coverage-gaps` is for spikes, not defaults.** The flag exists so a team can run QA on a legacy surface that has no `obligations[]` yet, or on a spike branch where coverage is aspirational. Uncovered `required` obligations then surface as `QA_REPORT.md` warnings rather than a blocking exit. Do not make it the default; every surface that has been researched should have its obligations covered before merging.

## Exploratory QA Team

(a) **Default-local, skipped-in-CI.** Phase 13.5 (the exploratory bug-hunt) runs by default on a **local/dev run** but is **skipped in CI** — it reuses the Phase-11 CI predicate (`[[ -z "$CI" && -z "$GITHUB_ACTIONS" && -z "$BUILDKITE" && -z "$GITLAB_CI" ]]`). CI stays deterministic-only. Use `--explore` to force the bug-hunt even in CI; use `--no-explore` to disable it locally. The `EXPLORE_RAN` envelope counter reflects whether the phase actually executed.

(b) **Bounded swarm — cost is capped on purpose.** The exploratory tier runs ≤6 concurrent workers, each with a ≤15-probe budget (`references/explorer-prompts.md`). "Do everything to find bugs" is deliberately budget-capped: open-ended exploration against a live service is expensive and can run indefinitely. Gotcha #7 (Gemini quota throttling) still applies — if workers are hitting 429s, reduce `--max-bg` to 3–4. Workers stop early once they stop finding new behavior.

(c) **Workers never self-confirm.** A worker's finding is `suspected` until the triage gate (`references/triage-verify.md`) independently reproduces it with a fresh verifier instance. The triage verifier defaults to **`rejected` on uncertainty** — a false bug report costs more team trust than a missed minor edge. Only `confirmed` findings are minted into cases and surfaced in `QA_REPORT.md`. Never count `finding-merge.sh` output totals as confirmed; count `EXPLORE_CONFIRMED` from the post-triage set.

(d) **Novel findings grow coverage for the next run.** A worker finding with `obligation: "none"` means the worker broke something the scout's enumeration did not anticipate. `finding-to-case.sh` mints a fresh `fmode:` obligation id for it (printed to stderr as `MINTED_OBLIGATION=…`) and carries it in `covers[]`. On the next run, the coverage gate will enforce that obligation — curiosity-discovered rules close the enumeration gap incrementally. `EXPLORE_OBLIGATIONS_ADDED` in the envelope counts these.

(e) **Needs a live service.** Phase 13.5 requires the service to be up. It is **skipped when Phase 8 (launch) was skipped** — i.e. when `--no-launch` is set or when an external `--service` URL was not provided and the service could not be reached. Do not expect exploratory workers to probe a service that is not running; they will produce only errors, not findings.

(f) **Dedup is by signature.** Two workers can independently discover the same bug — especially on shared invariants or popular endpoints. `finding-merge.sh` collapses all findings with the same `signature` (`<channel>|<endpoint>|<obligation>|<failure_class>`) into one, keeping the **highest-severity** instance. Run `finding-merge.sh` output's `unique` count, not `total`, when reasoning about how many distinct bugs were found.

(g) **Minted cases are RED repro stubs — never auto-promoted.** A confirmed finding is minted into a *currently-failing* repro stub for the `x-bugfix` route. It is NOT added to the green KB corpus (the KB is the proven-passing corpus). The repro earns a **regression slot** only after the fix lands, the case goes green, and the existing Phase-16 auto-promote path picks it up with a green streak. `EXPLORE_CONFIRMED` is counted after triage (post-`finding-merge.sh` + triage pass), not from the pre-triage merge output where every finding is still `suspected`.

## Eval scorers

(a) **Uncalibrated judge can't block.** An `llm-rubric`/`semantic-similarity` case whose
rubric has no `kb/evals/calibration/<rubric_id>.json` (or κ < 0.90) cannot set `fail` — it
surfaces as `evals.uncalibrated` → `warn`. Run `kb eval-calibrate` to earn fail-gating.
Calibration is ignored if its `judge_model` ≠ the runner's judge model (re-calibrate when you
switch judge models).

(b) **N-sample ≠ flaky-retry.** `samples` measures inherent LLM output variance into a
pass-rate; `--retry-flaky` recovers transient infra failures. They are independent — do not
conflate. Eval cases do not participate in `flaky-recovered`.

(c) **Judge == SUT model is a bug.** Using the same model to generate and grade invites
self-preference bias and circularity. Keep `judge_model` distinct from the system-under-test.
