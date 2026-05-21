# x-bugfix Gotchas

Known failure patterns specific to x-bugfix. For shared OMO patterns, see `../x-shared/common-gotchas.md`.

- **Jumping to fix before understanding.** The #1 failure mode. If you're writing code before you can state the root cause in one sentence, stop and investigate more.
- **Stacking fixes.** Testing multiple changes at once makes it impossible to isolate what worked. One hypothesis, one change, one test. Always.
- **Confusing symptoms for root cause.** A TypeError at line 50 is a symptom. The null value that propagated from line 12 in a different file is the root cause. Trace backward, fix at the source.
- **Mode B overkill on simple bugs.** Not every bug needs 3 competing hypotheses. If the stack trace points to one file and the error is clear, use Mode A.
- **Forgetting the regression test.** A fix without a failing test is a fix that will regress. Write the test BEFORE implementing the fix to prove it's meaningful.
- **Guessing without observability.** After 2 failed fix attempts, the next move is NOT another guess — it's the **Instrumentation Pivot** (see SKILL.md → Mode A → Hypothesize & Test). If you're tempted to "just try one more thing", instrument first. The bug always lives in the branch you didn't log.
- **Selective logging hides the bug.** When you instrument, cover the FULL call chain — entries, branches, state mutations, exits — and log decision variables (IDs, flags, lengths, set membership), not just "got here" markers. The "obvious suspect" path is rarely where the bug actually lives, otherwise you'd have already fixed it.
- **Oracle delegation too early.** Don't delegate to oracle after the first failed attempt. Give yourself 2 honest tries with different hypotheses first — and run the instrumentation pivot before escalating.
- **Oracle delegation too late.** If you've been grinding for 3+ iterations on the same issue (and instrumentation has already happened), you're past the point of productive solo debugging. Delegate.
- **Sanitize before web search.** Strip hostnames, IPs, file paths, SQL, customer data before searching for error patterns. Search the error category, not the raw message.
- **Blast radius creep.** If your "bug fix" is touching 10+ files, it's probably a refactor disguised as a fix. Flag it and discuss scope with the user.
- **Skipping the prevention gate.** The prevention gate (`references/prevention-gate.md`) is mandatory but easy to forget after a successful fix. Even if your fix incidentally includes defense-in-depth, explicitly read and evaluate the gate — it catches categories you didn't think of.
- **ESLint skip after tsc passes.** TypeScript compilation passing doesn't mean lint passes. Always run both: `npx tsc --noEmit` AND `npx eslint <changed-files>`. They catch different classes of issues.
- **Skipping the debug report template.** After a successful fix + review cycle, it's tempting to skip the formal report. The template (`references/debug-report-template.md`) forces you to document regression test status, blast radius, and prevention measures — all commonly skipped when the fix "obviously works." Output the template even when the fix is clean.
- **Implementing the fix without baseline logs.** tsc passing and the regression test going green don't prove the fix works at runtime — only that it compiles and the test path is exercised. Logs at the affected call chain's decision points (entry/exit, branches, state transitions) let you verify *behavior under real traffic*, not just *correctness under test fixtures*. Ship logs in the same diff as the fix per rule 1 of `../x-shared/instrument-and-verify.md`.
- **Hypothesizing without a citation.** "I think it's a race condition" is not a hypothesis — it's a guess. A real hypothesis cites a stack frame, a log line, a test output, or a `file:line`. If you can only describe the suspected cause in conjecture words ("probably", "should be", "usually"), go produce evidence first (scratch script, instrumentation, source read) per rule 3 of `../x-shared/instrument-and-verify.md`. Speculation-first debugging is how 10-hour rabbit holes start.

## agentmemory: standalone-mode vs proxy-mode

The `@agentmemory/mcp` shim has two modes determined at runtime by backend reachability (verified at `research/rohitg00/agentmemory/src/mcp/standalone.ts:343-415`):

- **Standalone mode** (no backend on `${AGENTMEMORY_URL:-http://localhost:3111}`): only the 7 IMPLEMENTED_TOOLS at `standalone.ts:16-24` are callable via MCP — `memory_smart_search`, `memory_save`, `memory_recall`, `memory_sessions`, `memory_audit`, `memory_export`, `memory_governance_delete`. Calling any other `memory_*` tool returns `Unknown tool`.
- **Proxy mode** (backend reachable): `tools/list` returns the full remote tool list and any non-standalone tool call is forwarded to `/agentmemory/mcp/call`. Server-tier tools (`memory_file_history`, `memory_commit_lookup`, `memory_diagnose`, etc.) become callable as `mcp__plugin_agentmemory_agentmemory__*`.

**Proxy mode is NOT a strict superset of standalone mode.** Empirically against agentmemory v0.9.21 with `AGENTMEMORY_FORCE_PROXY=1`, the upstream's `tools/list` returns 8 MCP tools total: 4 standalone survivors (`memory_smart_search`, `memory_save`, `memory_recall`, `memory_sessions`) + 4 server-tier additions (`memory_diagnose`, `memory_consolidate`, `memory_lesson_save`, `memory_reflect`). Three standalone tools (`memory_audit`, `memory_export`, `memory_governance_delete`) DISAPPEAR from the MCP catalog when proxy mode engages — use the upstream `agentmemory:forget` / `agentmemory:export` skills (separate plugin) for those flows. And many documented "server-tier" tools (`memory_file_history`, `memory_commit_lookup`, `memory_patterns`, `memory_timeline`, `memory_graph_query`, `memory_facet_query`, `memory_vision_search`) are reachable ONLY via direct HTTP routes under `/agentmemory/*`, NOT via MCP proxy in v0.9.21. Re-test the curation against your installed backend version with: ToolSearch `+memory agentmemory` after `memory_diagnose` succeeds.

**Symptom:** A call to `mcp__plugin_agentmemory_agentmemory__memory_file_history` returns `Unknown tool` despite `mcp.agentmemory` being pinned AND `curl ${AGENTMEMORY_URL}/agentmemory/livez` returning ok.

**Cause:** The MCP shim's mode is decided ONCE at MCP-server startup via `probe(url)` (verified at `research/rohitg00/agentmemory/src/mcp/rest-proxy.ts:101-126`). If the agentmemory backend was not running at the moment Claude Code launched the MCP shim, the shim cached `local` mode and the harness's `tools/list` registered only the 7 IMPLEMENTED_TOOLS for the session. Starting the backend later doesn't help — the harness's tool catalog is frozen. The runtime `agentmemory.server_up` probe will show `true` but server-tier MCP tools will still be missing.

**Fix order (lowest blast radius first):**

1. **Start the backend BEFORE Claude Code** — e.g., `npx -y @agentmemory/agentmemory &` in your shell rc, or run it as a launchd / pm2 service. Next Claude Code session starts the MCP shim in proxy mode and registers all server-tier tools.
2. **Force proxy mode** — set `AGENTMEMORY_FORCE_PROXY=1` in the env before Claude Code launches. The shim skips the livez probe and trusts the URL (verified at `rest-proxy.ts:113-119`). Useful when the backend is reliably reachable but a slow first-probe race causes the shim to fall back to standalone.
3. **If you're already mid-session and want the tools NOW** — there is no in-process recovery. Restart Claude Code (or at minimum restart the agentmemory MCP server entry) after the backend is up.
4. **If the backend genuinely IS down** — fall back to `git log -p -- <file>`. Do not retry the MCP call in a loop.

**Distinguishing the two failure modes:** If `curl ${AGENTMEMORY_URL}/agentmemory/livez` returns ok but the MCP tool errors with `Unknown tool`, it's startup-order (case 1/2/3 above). If livez itself fails, the backend really is down (case 4).

**Argument-name gotcha:** `memory_file_history` schema expects `sessionId` (NOT `currentSessionId`) — verified at `research/rohitg00/agentmemory/src/mcp/tools-registry.ts:83-95`. Using the wrong name silently disables current-session exclusion and pollutes regression-candidate ranking.

**Direct HTTP routes (for CLI / non-MCP consumers):** Upstream HTTP routes live under `/agentmemory/*` (kebab-case), NEVER `/api/*` (verified: `grep -rn '"/api/' research/rohitg00/agentmemory/src` returns zero matches). Key routes (`research/rohitg00/agentmemory/src/triggers/api.ts`): `POST /agentmemory/file-context` (:790), `GET /agentmemory/session/by-commit` (:711), `GET /agentmemory/commits` (:738), `POST /agentmemory/patterns` (:919), `POST /agentmemory/timeline` (:1015), `POST /agentmemory/graph/query` (:1206), `POST /agentmemory/facets/query` (:2574), `POST /agentmemory/vision-search` (:1581), `GET /agentmemory/livez` (:152).
