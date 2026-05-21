# agentmemory Optional Dependency Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire `rohitg00/agentmemory` (vendored at `research/rohitg00/agentmemory@v0.9.21`) as an optional capability in x-skills — detect once at setup, expose to skills via the existing capability manifest, and prove the integration shape with one consumer wiring (x-bugfix Pre-Flight). Skills must degrade gracefully when agentmemory is absent.

**Architecture:**
1. **Two-tier gate.** `mcp.agentmemory` boolean (written by `bin/setup`, mirrors how `perplexity`/`gitnexus` work) proves the MCP transport — that gives us 7 standalone tools (`memory_smart_search`, `memory_save`, `memory_recall`, `memory_sessions`, `memory_audit`, `memory_export`, `memory_governance_delete`). A second runtime-derived session pin `agentmemory.server_up` (one out-of-band HTTP probe to the upstream `/agentmemory/livez` endpoint on first need) unlocks the 46 server-tier tools (`memory_file_history`, `memory_patterns`, `memory_commit_lookup`, etc.). The probe mirrors the existing GitNexus indexed+fresh pattern documented in `capability-loading.md`. **Why HTTP livez and not an MCP tool call:** the `@agentmemory/mcp` shim registers only the 7 standalone tools at startup (verified at `research/rohitg00/agentmemory/src/mcp/standalone.ts:16-24`), so `memory_diagnose` is NEVER callable through Claude Code's MCP transport regardless of backend state. The livez endpoint is the upstream's own server-health convention and works in ~3 ms with no env vars required when the default `http://localhost:3111` is in use.
2. **Standalone-first consumption.** Skills only depend on the 7 standalone tools in their core path. Server-tier tools are opt-in enrichment, never blocking.
3. **Proof-of-shape rollout.** Land detection + schema + docs + ONE consumer (`x-bugfix` Pre-Flight). Fan out to `x-research`, `x-do`, `x-mindful`, `x-review`, `x-design`, `x-qa` only after a one-week soak.

**Tech Stack:** Bash (`bin/setup`), Markdown (skill docs + step files), MCP tool calls via Claude Code's `mcp__plugin_agentmemory_agentmemory__*` namespace, jq (manifest parsing — already a dependency).

**Non-goals:**
- Wiring `memory_action_*`, `memory_sketch_*`, `memory_lease`, `memory_signal_*`, `memory_team_*`, `memory_mesh_sync`, `memory_routine_run`, `memory_sentinel_*`, `memory_checkpoint` (overlaps with TodoWrite + `x-team` + OMC `team`).
- Auto-invoking `memory_governance_delete` / `memory_audit` / `memory_export` (user-driven only; `agentmemory:forget` already wraps them).
- Vendoring the agentmemory plugin source — keep it as an `x-upstream` submodule for reference only.

---

## File Structure

| File | Responsibility | Action |
|---|---|---|
| `bin/setup` | Capability detection script | **Modify** — add one `check_mcp` call near :787 |
| `skills/x-shared/capability-loading.md` | Manifest schema + probe contract | **Modify** — add `agentmemory` after `"gitnexus": true` (line 39), add new "Shared agentmemory.server_up Probe" section after the GitNexus probe (:75-119) |
| `skills/x-shared/mcp-toolbox.md` | Per-MCP routing decision matrix | **Modify** — append `agentmemory` section at end of file (after line 67; the GitNexus section spans lines 32–67) |
| `skills/x-bugfix/SKILL.md` | Consumer — Pre-Flight recall + Post-Fix save | **Modify** — add two checklist items in Pre-Flight (:50), add memory-save step in Post-Fix Verification (:164) |
| `skills/x-bugfix/gotchas.md` | Known failure patterns | **Modify** — document the standalone-vs-server tier confusion |
| `docs/superpowers/plans/2026-05-21-agentmemory-optional-dep.md` | This plan | **Create** — done as part of plan authoring |

No new files outside this plan. No package.json change. No new dependencies (`gh` + `jq` already declared elsewhere).

---

## Task 1: Add `mcp.agentmemory` detection to `bin/setup`

**Files:**
- Modify: `bin/setup:787` (insert after the `check_mcp "gitnexus" …` line)

The existing `check_mcp` helper at `bin/setup:733-774` already does the right pattern-matching for the agentmemory plugin without any change. The plugin's `.mcp.json` at `~/.claude/plugins/cache/agentmemory/agentmemory/0.9.21/.mcp.json` declares server key `"agentmemory"`, which is matched by the existing plugin-cache scan loop at `bin/setup:754-760` via the pattern `\"${name}(-mcp)?\"`. A bare `check_mcp "agentmemory"` invocation is sufficient — **no grep-pattern extension is needed**.

- [ ] **Step 1: Add the agentmemory check_mcp invocation**

Edit `bin/setup`. After line 787:

```bash
check_mcp "gitnexus"    "code knowledge graph (impact / context / rename / route_map)" \
  "npm install -g gitnexus" || true
```

insert:

```bash
check_mcp "agentmemory" "persistent memory + replay (rohitg00/agentmemory)" \
  "/plugin marketplace add rohitg00/agentmemory && /plugin install agentmemory  # or: npx -y @agentmemory/mcp" || true
```

> **Note on the install hint:** `@agentmemory/mcp` is the MCP shim that registers tools with Claude Code (per `~/.claude/plugins/cache/agentmemory/agentmemory/0.9.21/.mcp.json`). Do NOT write `@agentmemory/agentmemory` — that is the engine package, not the MCP shim, and installing it globally will not register any tools.

- [ ] **Step 2: Run `bin/setup` (not just `--check`) to actually write the manifest**

Run:

```bash
./bin/setup
```

(The `--check` mode reports detection without writing `~/.config/x-skills/capabilities.json`. The first time agentmemory is added we need the manifest written.)

- [ ] **Step 3: Verify detection on a session that has agentmemory installed**

Run:

```bash
./bin/setup --check 2>&1 | grep -i agentmemory
```

Expected (this session has the plugin installed):

```
✓ agentmemory — persistent memory + replay (rohitg00/agentmemory)
```

- [ ] **Step 4: Verify the manifest now contains the new key**

Run:

```bash
jq '.capabilities.mcp.agentmemory' ~/.config/x-skills/capabilities.json
```

Expected: `true`

- [ ] **Step 5: Verify negative path (rename the inner `.mcp.json` to simulate missing)**

The negative-path test must defeat ALL four detection loops in `check_mcp` (settings.json grep, .mcp.json glob, plugin-cache glob, `claude mcp list` cache). Renaming only the top-level cache directory is insufficient — the glob `*/*/*/.mcp.json` still matches `agentmemory.bak/agentmemory/0.9.21/.mcp.json`, and `claude mcp list` cache still reports the server as Connected.

Run:

```bash
# Hide the plugin's .mcp.json from the plugin-cache scan
mv ~/.claude/plugins/cache/agentmemory/agentmemory/0.9.21/.mcp.json{,.bak} 2>/dev/null || true
# Disable the MCP transport so `claude mcp list` cache also drops it
claude mcp remove agentmemory 2>/dev/null || true
./bin/setup --check 2>&1 | grep -i agentmemory
# Restore
mv ~/.claude/plugins/cache/agentmemory/agentmemory/0.9.21/.mcp.json{.bak,} 2>/dev/null || true
# Re-add the MCP transport (or re-install the plugin via `/plugin install agentmemory`)
```

Expected: `⚠ agentmemory — not detected (persistent memory + replay (rohitg00/agentmemory))`

(Skip this step if the cache layout differs — what matters is that `cap_set mcp_agentmemory false` runs when no agentmemory MCP is registered anywhere.)

- [ ] **Step 6: Commit**

```bash
git add bin/setup
git commit -m "feat(x-skills): detect agentmemory MCP in bin/setup"
```

---

## Task 2: Extend `capability-loading.md` schema + add `agentmemory.server_up` probe

**Files:**
- Modify: `skills/x-shared/capability-loading.md` (schema block — insert after the `"gitnexus": true` line at :39)
- Modify: `skills/x-shared/capability-loading.md` (insert new section after `## Shared GitNexus Indexed+Fresh Probe`, before `## Drift Handling`)

- [ ] **Step 1: Update the schema block**

Edit `skills/x-shared/capability-loading.md`. Find the JSON schema block starting at line 21, the `mcp` object. Currently:

```json
    "mcp": {
      "perplexity": true,
      "deepwiki": true,
      "exa": true,
      "context7": true,
      "morph": true,
      "gitnexus": true
    },
```

Replace with:

```json
    "mcp": {
      "perplexity": true,
      "deepwiki": true,
      "exa": true,
      "context7": true,
      "morph": true,
      "gitnexus": true,
      "agentmemory": true
    },
```

- [ ] **Step 2: Add the agentmemory.server_up probe section**

Edit `skills/x-shared/capability-loading.md`. Find the line that begins `## Drift Handling`. Insert ABOVE it (and after the existing GitNexus probe section that ends at line 119):

```markdown
## Shared agentmemory.server_up Probe (session-pinned, derived state)

Same shape as the GitNexus probe above — solves the same problem (a single capability boolean cannot distinguish "MCP wired" from "remote backend reachable") for a different MCP.

### Capability key vs. derived probe

- `mcp.agentmemory` — boolean capability key written by `bin/setup`. Answers "is the agentmemory MCP transport available?" When true, the 7 **standalone tools** (`memory_smart_search`, `memory_save`, `memory_recall`, `memory_sessions`, `memory_audit`, `memory_export`, `memory_governance_delete`) are callable.
- `agentmemory.server_up` — runtime-derived session pin. Answers "is the agentmemory HTTP backend reachable at `${AGENTMEMORY_URL:-http://localhost:3111}`?" When true, the 46 **server-tier tools** (`memory_file_history`, `memory_patterns`, `memory_commit_lookup`, `memory_commits`, `memory_timeline`, `memory_consolidate`, `memory_crystallize`, `memory_diagnose`, `memory_graph_query`, `memory_facet_query`, `memory_facet_tag`, `memory_vision_search`, `memory_relations`, `memory_obsidian_export`, etc.) become callable through the HTTP backend.

The probe is gated by `mcp.agentmemory` being pinned. Without the capability key, no probe runs.

**Important:** The `@agentmemory/mcp` shim registers only the 7 standalone tools with Claude Code regardless of backend state (verified at `research/rohitg00/agentmemory/src/mcp/standalone.ts:16-24`). Server-tier tools are NOT exposed through the MCP transport — `memory_diagnose` is never callable as `mcp__plugin_agentmemory_agentmemory__memory_diagnose`. Server-tier consumers must reach the HTTP backend directly via `${AGENTMEMORY_URL:-http://localhost:3111}/api/...` rather than through MCP tool calls.

### Derivation (run once, then session-pinned)

At the first Bootstrap (across any x-skill that needs server-tier memory tools) in a session:

1. **Gate:** `mcp.agentmemory` must be in the bootstrap-active set. If not, **skip entirely** — `agentmemory.server_up = false`, all server-tier rows fall through to their fallback.
2. Probe out-of-band via HTTP — do NOT use an MCP tool call:

   ```bash
   curl -fsS --max-time 3 "${AGENTMEMORY_URL:-http://localhost:3111}/agentmemory/livez"
   ```

   Why HTTP and not MCP: `memory_diagnose` is server-tier-only and is never registered in the MCP transport (see "Important" note above). The `livez` endpoint is the upstream's own server-health convention, returns `{"service":"agentmemory","status":"ok"}` in ~3 ms when reachable, and works without any env vars when the backend is on its default port.
3. Pin the result for the rest of the session.
   - HTTP 2xx with `status: "ok"` in the body ⇒ `agentmemory.server_up = true`.
   - Non-zero curl exit, timeout, or any non-ok body ⇒ `agentmemory.server_up = false`.
4. **It runs exactly once per session.** All consuming skills read the pinned record.

### Use-class asymmetry

- **Correctness-sensitive consumers** (e.g., `x-bugfix` regression bisect via `memory_commit_lookup`) **hard-degrade to fallback** when `agentmemory.server_up = false`. Never call server-tier endpoints speculatively.
- **Advisory consumers** (e.g., `x-research` enrichment via `memory_patterns`) proceed with a one-line note: `[x-skills] agentmemory server not reachable; standalone tools only.`

### Unpinned no-op

With `mcp.agentmemory` NOT pinned in the bootstrap-active set, this probe is a no-op — never run, nothing derived. Consumers fall straight to their non-memory fallback rows. Sessions without agentmemory have **zero behavior change**.
```

- [ ] **Step 3: Verify the doc renders and section ordering is correct**

Run:

```bash
grep -nE "^## " skills/x-shared/capability-loading.md
```

Expected ordering: `Principle`, `Sources of Truth`, `Schema`, `Skill Bootstrap Pattern`, `Shared GitNexus Indexed+Fresh Probe`, `Shared agentmemory.server_up Probe`, `Drift Handling`, `Opt-Out`.

- [ ] **Step 4: Verify schema example is valid JSON**

Run:

```bash
awk '/^```json$/{flag=1; next} /^```$/{if(flag){exit}} flag' skills/x-shared/capability-loading.md | jq '.capabilities.mcp.agentmemory'
```

Expected: `true`

(This extracts only the FIRST ```json fenced block from the file — robust against additional json blocks later in the doc, unlike `sed | head` which depends on byte offsets.)

- [ ] **Step 5: Commit**

```bash
git add skills/x-shared/capability-loading.md
git commit -m "docs(x-skills): add agentmemory to capability schema + server_up probe"
```

---

## Task 3: Add agentmemory row to `mcp-toolbox.md`

**Files:**
- Modify: `skills/x-shared/mcp-toolbox.md` (append new section at end of file; the GitNexus section spans lines 32–67)

- [ ] **Step 1: Append the agentmemory section**

Edit `skills/x-shared/mcp-toolbox.md`. **Append at the end of the file** (after the GitNexus "Freshness gate" bullets that close at line 67). Do NOT insert mid-file — the GitNexus section runs to EOF, and inserting earlier (e.g., after line 49) would split it.

```markdown
## agentmemory (optional, when `mcp.agentmemory` pinned)

Persistent memory MCP from `rohitg00/agentmemory`. Two tiers — standalone (7 tools exposed through MCP, work without a running server) and server (46 more tools, reachable ONLY via the agentmemory HTTP backend at `${AGENTMEMORY_URL:-http://localhost:3111}`; server-tier tools are NOT registered through the MCP transport — see the `agentmemory.server_up` probe defined in `capability-loading.md`). License: Apache-2.0.

### Standalone tier (always available when `mcp.agentmemory` pinned)

| Need | Primary tool | Fallback (when `mcp.agentmemory` not pinned) |
|---|---|---|
| Recall prior decisions/observations on a topic | `agentmemory` → `memory_smart_search` (`{ query, limit }`) | Native Claude memory (`~/.claude/projects/<proj>/memory/MEMORY.md`) |
| Targeted recall with format + token budget | `agentmemory` → `memory_recall` (`{ search, format: 'compact', budget }`) | Native Claude memory grep |
| Save an insight, decision, or lesson | `agentmemory` → `memory_save` (`{ content, type, concepts, files }`) | Append to native Claude memory |
| List sessions for replay | `agentmemory` → `memory_sessions` | Manual `ls ~/.claude/projects/` |

### Server tier (gated by `agentmemory.server_up` — reached via HTTP, not MCP)

| Need | Primary endpoint (correctness class) | Fallback when server down |
|---|---|---|
| Past observations about specific files (regression hunting) | HTTP `POST ${AGENTMEMORY_URL}/api/file_history` (correctness-sensitive) | `git log -p -- <file>` + manual scan |
| Find the session that produced a commit | HTTP `POST ${AGENTMEMORY_URL}/api/commit_lookup` (correctness-sensitive) | `git show <sha>` + manual context reconstruction |
| Recent commits with session linkage | HTTP `GET ${AGENTMEMORY_URL}/api/commits` (advisory) | `git log --oneline` |
| Recurring patterns across sessions | HTTP `POST ${AGENTMEMORY_URL}/api/patterns` (advisory) | Skip — manual review |
| Chronological observations around an anchor | HTTP `POST ${AGENTMEMORY_URL}/api/timeline` (advisory) | `git log --since/--until` |
| Knowledge-graph traversal | HTTP `POST ${AGENTMEMORY_URL}/api/graph_query` (advisory) | Skip — no fallback |
| Typed-dimension filtering | HTTP `POST ${AGENTMEMORY_URL}/api/facet_query` (advisory) | Skip — manual triage |
| Image-similarity search (UI regression) | HTTP `POST ${AGENTMEMORY_URL}/api/vision_search` (advisory) | Manual visual diff |
| Health probe (used for the server_up derivation itself) | HTTP `GET ${AGENTMEMORY_URL}/agentmemory/livez` (probe-only) | n/a |

> Consumers should resolve the canonical request/response shape for each endpoint against the vendored upstream at `research/rohitg00/agentmemory` (see `src/mcp/server.ts` for the function_id ↔ HTTP route mapping). The endpoint paths above mirror the upstream's published REST routes.

### Tools NOT routed through x-skills

`memory_action_*`, `memory_sketch_*`, `memory_lease`, `memory_signal_*`, `memory_team_*`, `memory_mesh_sync`, `memory_routine_run`, `memory_sentinel_*`, `memory_checkpoint`, `memory_claude_bridge_sync` — workflow/multi-agent coordination overlapping with TodoWrite + `x-team` + `oh-my-claudecode:team`. Auto-deletion tools (`memory_governance_delete`, `memory_export`, `memory_obsidian_export`, `memory_audit`) — user-driven, owned by the upstream `agentmemory:forget` skill.

### Disambiguation: agentmemory vs Claude's auto-memory file

Claude Code already injects `~/.claude/projects/<proj>/memory/MEMORY.md` into every session. That file is best for **the user's stable preferences and project facts**. agentmemory is best for **per-session observations, decisions, and file-touch history** that's too granular for MEMORY.md and benefits from semantic search. Use both — they don't compete.
```

- [ ] **Step 2: Verify markdown table well-formedness**

Run:

```bash
awk '/^## agentmemory/,0' skills/x-shared/mcp-toolbox.md | grep -cE '^\|'
```

Expected: at least 18 lines (table rows including headers across two sub-tables).

- [ ] **Step 3: Commit**

```bash
git add skills/x-shared/mcp-toolbox.md
git commit -m "docs(x-skills): add agentmemory entry to mcp-toolbox"
```

---

## Task 4: Wire `x-bugfix` Pre-Flight to read prior bug context

**Files:**
- Modify: `skills/x-bugfix/SKILL.md:50` (Pre-Flight Checklist — add memory-recall checklist item)
- Modify: `skills/x-bugfix/SKILL.md:90` (Investigate — add file-history hint)
- Modify: `skills/x-bugfix/SKILL.md:164` (Post-Fix Verification — add memory_save step)

Rationale: `x-bugfix` is the simplest router with the highest memory-recall payoff (regressions repeat). It exercises both tiers — standalone (`memory_smart_search` via MCP) in Pre-Flight, server (HTTP `file_history`) in Investigate.

- [ ] **Step 1: Add Pre-Flight memory_smart_search checklist item**

Edit `skills/x-bugfix/SKILL.md:50` — the `## Pre-Flight (MANDATORY)` section. Find the existing checklist item:

```markdown
- [ ] `git log --oneline -10 -- <affected-files>` — regression = root cause is in the diff
```

Insert ABOVE it:

```markdown
- [ ] **Memory recall** (only when `mcp.agentmemory` pinned in bootstrap-active set): one `mcp__plugin_agentmemory_agentmemory__memory_smart_search({ query: <symptom keywords + framework>, limit: 5 })` call. If results include prior bug-fix sessions touching the same symptom or files, surface them in the Investigate step as candidate root-cause hypotheses (do not auto-apply — these are leads, not verdicts). When `mcp.agentmemory` is not pinned, **skip silently** — Claude's native auto-memory file still applies.
```

- [ ] **Step 2: Add file-history hint to Investigate**

Edit `skills/x-bugfix/SKILL.md` — the `### Investigate` block (heading at :88; paragraph to extend at :90) under `## Mode A: Quick Bug`. Find:

```markdown
Gather evidence before forming hypotheses. Reproduce the bug, check recent changes, trace the data flow backward from symptom to source. **Use `morph-mcp codebase_search` as your first search tool** for tracing call chains, finding related code, and locating error origins — it's semantic and faster than spawning explore agents. Fall back to OMO `explore` only when you need parallel multi-tool investigation. For deep call stacks, use the backward tracing technique in `references/backward-tracing.md`. Consult `references/pattern-catalog.md` to narrow the search space.
```

Append at the end of that paragraph:

```markdown
 When `agentmemory.server_up` is pinned (per `../x-shared/capability-loading.md`), call the agentmemory HTTP backend directly — server-tier endpoints are NOT exposed through MCP — e.g. `curl -fsS -X POST "${AGENTMEMORY_URL:-http://localhost:3111}/api/file_history" -H 'content-type: application/json' -d '{"files":"<suspected paths, comma-separated>","sessionId":"<this session id>"}'` to surface prior touches on the same files; treat each prior session as a regression-candidate ranked by recency. Note the parameter name is `sessionId` (NOT `currentSessionId`) — using a wrong name silently disables current-session exclusion. When server not up, fall back to `git log -p -- <file>`.
```

- [ ] **Step 3: Add memory_save to Post-Fix Verification**

Edit `skills/x-bugfix/SKILL.md:164` — the `## Post-Fix Verification (MANDATORY)` section. After the existing closing of that section (before `## After This Skill`), add a new checklist item:

```markdown
- [ ] **Persist lesson** (only when `mcp.agentmemory` pinned): one `mcp__plugin_agentmemory_agentmemory__memory_save({ content: "<one-sentence root cause> → <one-sentence fix>", type: "lesson", concepts: "x-bugfix,<area>,<symptom-token>", files: <touched paths comma-sep> })` call. Skip silently when not pinned.
```

- [ ] **Step 4: Run a smoke test (manual — no test harness for skill markdown)**

Open a fresh session, invoke `Skill: x-skills:x-bugfix` against any small project with a real bug. Verify:

a. Pre-Flight section runs `memory_smart_search` once and only when `mcp.agentmemory` is in `[x-skills/capabilities]` snapshot line.
b. When `agentmemory.server_up` is false (server not running), the HTTP `file_history` curl is NOT made and `git log` is used instead. No error surface to user.
c. Post-Fix runs `memory_save` once after verification.

Capture the session's `[x-skills/capabilities]` line + the actual tool call sequence in the verification notes (paste into the commit message body).

- [ ] **Step 5: Commit**

```bash
git add skills/x-bugfix/SKILL.md
git commit -m "feat(x-bugfix): wire agentmemory recall (preflight) + save (post-fix)

Pre-Flight: memory_smart_search on symptom keywords (standalone tier via MCP).
Investigate: HTTP POST /api/file_history when server up (regression hunt).
Post-Fix: memory_save with lesson + concepts + touched files.
All calls gated on capability pins; fall back to native git/grep silently."
```

---

## Task 5: Document the tiering gotcha in `x-bugfix/gotchas.md`

**Files:**
- Modify: `skills/x-bugfix/gotchas.md`

- [ ] **Step 1: Append the gotcha**

Add to `skills/x-bugfix/gotchas.md`:

```markdown
## agentmemory: standalone vs server-tier confusion

`mcp.agentmemory` pinned does NOT mean every `memory_*` tool is callable through MCP. The `@agentmemory/mcp` shim exposes only **7 tools standalone** (`memory_smart_search`, `memory_save`, `memory_recall`, `memory_sessions`, `memory_audit`, `memory_export`, `memory_governance_delete` — verified at `research/rohitg00/agentmemory/src/mcp/standalone.ts:16-24`). The other 46 tools (`memory_file_history`, `memory_patterns`, `memory_commit_lookup`, …) are reachable ONLY via the agentmemory HTTP backend on `${AGENTMEMORY_URL:-http://localhost:3111}` — they are NOT registered as MCP tools regardless of whether the backend is up.

**Symptom:** A call to `mcp__plugin_agentmemory_agentmemory__memory_file_history` returns `Unknown tool` despite the capability being pinned and the backend being reachable.

**Fix:** Check the session-pinned `agentmemory.server_up` flag (derived once per session per `../x-shared/capability-loading.md`). If false, fall back to `git log -p -- <file>` — never retry the MCP call in a loop. If true, reach the backend over HTTP instead (e.g., `curl -fsS -X POST ${AGENTMEMORY_URL}/api/file_history ...`).

**Detection:** The user can start the backend with `npx -y @agentmemory/agentmemory` in a separate terminal, or `curl http://localhost:3111/agentmemory/livez` to confirm. A `{"service":"agentmemory","status":"ok"}` reply means the HTTP-tier endpoints are usable.

**Argument-name gotcha:** the upstream `file_history` endpoint expects `sessionId` (NOT `currentSessionId`) — using a wrong name silently disables current-session exclusion and pollutes regression-candidate ranking. Verified at `research/rohitg00/agentmemory/src/mcp/tools-registry.ts:83-95`.
```

- [ ] **Step 2: Commit**

```bash
git add skills/x-bugfix/gotchas.md
git commit -m "docs(x-bugfix): document agentmemory two-tier gotcha"
```

---

## Task 6: End-to-end validation

- [ ] **Step 1: Run `./bin/setup --check`**

Run:

```bash
./bin/setup --check
```

Expected output includes:

```
✓ agentmemory — persistent memory + replay (rohitg00/agentmemory)
```

And:

```bash
jq '.capabilities.mcp.agentmemory' ~/.config/x-skills/capabilities.json
# → true
```

- [ ] **Step 2: Verify SessionStart hook surfaces the capability**

Start a new Claude Code session in this repo. The SessionStart `[x-skills/capabilities]` snapshot line should now include `mcp.agentmemory` in the comma-separated active set.

Expected (substring):

```
[x-skills/capabilities] active=…,mcp.gitnexus,mcp.agentmemory,…
```

- [ ] **Step 3: Run the full x-bugfix smoke test**

Reproduce a trivial bug (e.g., introduce a typo in a sample script), then run `Skill: x-skills:x-bugfix`. Confirm:

a. `memory_smart_search` called once during Pre-Flight (MCP, standalone tier).
b. `curl … /agentmemory/livez` called once if any server-tier path is hit; otherwise not called.
c. `memory_save` called once after fix verification.
d. If you stop the agentmemory server beforehand, the skill proceeds without error and falls back to `git log`.

- [ ] **Step 4: Verify no regressions in non-agentmemory routes**

Manually mute the capability:

```bash
echo '{"capabilities":{"mcp":{"agentmemory":false}}}' > .x-skills/capabilities.json
```

Restart the session. Invoke `Skill: x-skills:x-bugfix`. Confirm:

a. No `mcp__plugin_agentmemory_*` calls are made.
b. No `curl … /agentmemory/...` calls are made.
c. Behavior matches what x-bugfix did before this plan.

Then clean up:

```bash
rm .x-skills/capabilities.json
```

- [ ] **Step 5: Final commit + push**

```bash
git log --oneline -6
```

Expected sequence (newest first):

```
docs(x-bugfix): document agentmemory two-tier gotcha
feat(x-bugfix): wire agentmemory recall (preflight) + save (post-fix)
docs(x-skills): add agentmemory entry to mcp-toolbox
docs(x-skills): add agentmemory to capability schema + server_up probe
feat(x-skills): detect agentmemory MCP in bin/setup
```

If correct:

```bash
git push origin main
```

---

## Out of Scope (Follow-Up Plans)

After a one-week soak with the x-bugfix wiring, fan out to the remaining consumers — each is its own plan:

| Consumer | Injection points | Tools |
|---|---|---|
| `x-research` | Bootstrap (recall before classification), Synthesis (save) | `memory_smart_search`, `memory_save`, HTTP `/api/patterns` (server) |
| `x-do` | Pre-Flight, step-04 post-execute | `memory_smart_search`, HTTP `/api/file_history` (server), `memory_save` |
| `x-mindful` | Bootstrap, step-04 walkthrough enrichment, step-05 envelope save | `memory_recall`, `memory_save` |
| `x-review` | step-01-prepare (recall), step-03-synthesize (save) | `memory_recall`, HTTP `/api/file_history` (server), `memory_save` |
| `x-design` | DESIGN.md slot store, visual regression | HTTP slot endpoints (server), HTTP `/api/vision_search` (server) |
| `x-qa` | TEST_PLAN.md slot store, pre-run flake recall, post-run save | HTTP slot endpoints (server), `memory_smart_search`, `memory_save` |
| `x-skill-improve` | Replace JSONL scan with structured query | `memory_sessions`, `memory_smart_search` |

---

## Self-Review Notes

- **Spec coverage:** the research turn identified five wiring concerns — detection, schema, docs, consumer, gotcha. All five have a task. ✓
- **Placeholder scan:** every step has either a concrete code block, an exact command, or an exact file:line target. ✓
- **Type consistency:** `mcp.agentmemory` (capability key), `agentmemory.server_up` (runtime probe, derived from HTTP `/agentmemory/livez`), `mcp__plugin_agentmemory_agentmemory__memory_*` (tool namespace — standalone tier ONLY, 7 tools), `${AGENTMEMORY_URL}/api/*` (server tier, reached via HTTP) are used consistently across all tasks. ✓
- **Naming:** matches the existing `mcp.gitnexus` / GitNexus indexed+fresh probe pattern — readers familiar with that section will recognize the shape. ✓
- **Probe-shape correction (post-review):** the probe was originally specified as `memory_diagnose({})` over MCP. That call would have failed because `memory_diagnose` is NOT in the standalone shim's IMPLEMENTED_TOOLS set (verified upstream). The probe was rewritten as an out-of-band HTTP livez call, which matches the upstream's own server-health convention. ✓

---

## Corrections (2026-05-21 post-review)

Cross-model review (x-review: Claude opus + GPT oracle + Gemini-pro + general-purpose agent) caught four substantive issues in the original plan. All applied in the follow-up fix commit (see `git log --oneline -2`).

1. **All `/api/*` HTTP paths were hallucinated.** Actual upstream routes are under `/agentmemory/*` with kebab-case (verified at `research/rohitg00/agentmemory/src/triggers/api.ts`; `grep -rn '"/api/' research/rohitg00/agentmemory/src` returns zero matches). Examples: `/api/file_history` does not exist — `memory_file_history` MCP tool wraps `mem::file-context` whose HTTP equivalent is `POST /agentmemory/file-context` (:790); `/api/commit_lookup` does not exist — equivalent is `GET /agentmemory/session/by-commit` (:711). Full corrected mapping in `skills/x-shared/mcp-toolbox.md` server-tier table.

2. **The "server-tier tools NEVER callable via MCP" premise was false.** Verified at `research/rohitg00/agentmemory/src/mcp/standalone.ts:354-415`: when the shim is in proxy mode (backend reachable), `tools/list` returns the full server tool list and unknown tool calls are forwarded to `/agentmemory/mcp/call`. So server-tier tools ARE callable via the `mcp__plugin_agentmemory_agentmemory__*` namespace when `server_up=true`. The probe is still useful — it tells us which mode the shim is in. The two-tier framing now reads as: standalone mode (7 IMPLEMENTED_TOOLS) vs proxy mode (full set, including `memory_diagnose`).

3. **`memory_recall` documented param shape was wrong.** Upstream validator at `research/rohitg00/agentmemory/src/mcp/standalone.ts:115-133` requires `query` (not `search`) and reads `token_budget` (not `budget`). The standalone-tier table in `mcp-toolbox.md` was corrected.

4. **`bin/setup` plan-gap (LOW).** Task 1 only specified the `check_mcp` call. The actual fix also required `"agentmemory": cap("$(cap_get mcp_agentmemory)")` in the Python manifest builder at `bin/setup:921` for the boolean to round-trip into `~/.config/x-skills/capabilities.json`. The executor caught this at fix time. Future plans of this shape should call out the manifest builder explicitly.

Original plan body above is preserved for traceability. Authoritative behavior is now whatever the corrected skill files say.

### Round 3 corrections (post-empirical-validation, 2026-05-21)

After v1.15.0 shipped and `AGENTMEMORY_FORCE_PROXY=1` was applied, restarting Claude Code exposed the proxy-mode MCP catalog empirically. Two new findings:

1. **Proxy mode exposes 8 MCP tools, not 40+.** Empirical deferred-tools list against agentmemory v0.9.21: `memory_smart_search`, `memory_save`, `memory_recall`, `memory_sessions`, `memory_diagnose`, `memory_consolidate`, `memory_lesson_save`, `memory_reflect`. The previous corrections doc claimed "tools/list returns the full server tool list" — empirically that list is a CURATED subset, not the full tools-registry enumeration. `mcp-toolbox.md`, `capability-loading.md`, `x-bugfix/SKILL.md`, and `x-bugfix/gotchas.md` corrected to split MCP-callable from HTTP-only.

2. **Three standalone tools disappear in proxy mode:** `memory_audit`, `memory_export`, `memory_governance_delete` are in `standalone.ts:16-24` IMPLEMENTED_TOOLS but NOT in the proxy `tools/list`. Asymmetry surfaced in `gotchas.md`.

x-bugfix Investigate switched from `mcp__plugin_agentmemory_agentmemory__memory_file_history` (would fail with "Unknown tool" in proxy mode) to direct HTTP `POST /agentmemory/file-context` with `files: []`. Body shape now matches the HTTP route (array, not CSV), verified at `research/rohitg00/agentmemory/src/triggers/api.ts:783-790`.

These findings were ONLY observable after the v1.15.0 hook fix landed AND `AGENTMEMORY_FORCE_PROXY=1` was set — both prerequisites for the harness to register proxy-mode tools. Future docs touching agentmemory should re-run the proxy-mode catalog probe against the installed backend version rather than trusting tools-registry.ts as a "what's MCP-callable" oracle.

---

## Fan-Out Amendment (2026-05-21, post-Round-3)

The original plan deferred fan-out for a one-week soak. We're overriding that gate at user request — the proxy catalog has been empirically validated (Round 3) and the wiring pattern from x-bugfix has run cleanly through the release cycle. **Soak risk:** if a regression surfaces in any wiring, we now have 7 places to revert instead of 1; mitigated by keeping every call capability-gated with skip-silently fallback and by bundling reverts per skill if needed.

### Phase 1 — MCP-callable wirings (5 skills, no upstream blockers)

All Phase 1 wirings use only tools in the empirical proxy-mode catalog (`memory_smart_search`, `memory_save`, `memory_recall`, `memory_sessions`, `memory_lesson_save`) plus the two HTTP routes confirmed at `research/rohitg00/agentmemory/src/triggers/api.ts` (`POST /agentmemory/file-context`, `POST /agentmemory/patterns`). Every call is gated on `mcp.agentmemory` (for MCP calls) or `agentmemory.server_up` (for HTTP calls) per `skills/x-shared/capability-loading.md`; absent = skip silently, never fail loud.

| Skill | Recall injection point | Recall call | Save injection point | Save call |
|---|---|---|---|---|
| **x-research** | `skills/x-research/SKILL.md` Bootstrap step 4 (new bullet after `gotchas.md`) | `memory_smart_search({ query: <topic + signal>, limit: 5 })` — surface prior research as supplementary context | `skills/x-research/SKILL.md` Synthesis (existing § "Synthesis" :108) — append a save bullet | `memory_save({ content: <one-line synthesis takeaway>, type: "insight", concepts: "x-research,<signal>,<topic-token>" })` |
| **x-do** | `skills/x-do/steps/step-01-gather.md` § 1 "Fire parallel detection" (add to the parallel batch) | `memory_smart_search({ query: <task keywords + project>, limit: 5 })` — leads on prior similar tasks; do NOT auto-apply | `skills/x-do/steps/step-04-execute.md` § "After Execution" (new bullet) | `memory_save({ content: "<one-line: what was built/changed> → <observed outcome>", type: "lesson", concepts: "x-do,<mode A/B/C/D>,<area>", files: <touched paths comma-sep> })` |
| **x-mindful** | `skills/x-mindful/SKILL.md` § Bootstrap (:29, new bullet) | `memory_recall({ query: <plan-slug + architectural keywords>, token_budget: 1500 })` — past arch lessons relevant to this plan | `skills/x-mindful/steps/step-05-handoff.md` § "Persistence" (:71) — extend existing block | `memory_lesson_save({ content: <one-sentence arch lesson confirmed/rejected by walkthrough>, tags: "x-mindful,architecture,<slug>" })` — per envelope item that produced a *new* lesson |
| **x-review** | `skills/x-review/steps/step-01-prepare.md` § "Output" (:68) — new pre-output bullet | `memory_smart_search({ query: <PR title or diff summary>, limit: 5 })` + optional `curl POST /agentmemory/file-context` with `files: <changed paths>` when `agentmemory.server_up` | `skills/x-review/steps/step-03-synthesize.md` § "Synthesis" (:51, new tail bullet) | `memory_save({ content: "<finding summary> → <recommendation>", type: "lesson", concepts: "x-review,<severity>,<area>", files: <files cited in finding> })` per CRITICAL/HIGH finding only |
| **x-skill-improve** | `skills/x-skill-improve/SKILL.md` § Workflow § 1 "Locate Session" (:36) | `memory_sessions({ limit: 20 })` + `memory_smart_search({ query: <skill name + improvement keyword>, limit: 5 })` — replaces ad-hoc JSONL scan when MCP available | `skills/x-skill-improve/SKILL.md` § Persistence (:138) — extend | `memory_save({ content: "<improvement applied to skill X>", type: "lesson", concepts: "x-skill-improve,<skill-name>,<improvement-class>" })` |

### Phase 2 — Best-effort wirings (2 skills, with substitutions for missing upstream routes)

The plan's "Out of Scope" table specified "HTTP slot endpoints" for `x-design` and `x-qa`. **Those endpoints do not exist in agentmemory v0.9.21** (no route under `/agentmemory/*` mentions "slot"; verified via `grep -rn 'slot' research/rohitg00/agentmemory/src/triggers/api.ts` returns zero matches). We substitute `memory_save` with a `category` field as a structured-tag convention. This is a NEW convention not validated by upstream — if upstream adds slot endpoints later, migrate.

| Skill | Recall injection point | Recall call | Save injection point | Save call |
|---|---|---|---|---|
| **x-design** | `skills/x-design/SKILL.md` Workflow (:41, first step) | When `agentmemory.server_up`: `curl -fsS -X POST "${AGENTMEMORY_URL:-http://localhost:3111}/agentmemory/vision-search" -H 'content-type: application/json' -d '{"query":"<design topic>","limit":5}'` — surface prior screenshots/mockups. Skip silently otherwise. | `skills/x-design/SKILL.md` Workflow (last step before "Quick Reference") | `memory_save({ content: <one-line design decision + rationale>, type: "insight", concepts: "x-design,decision,slot:design,<area>" })` — `slot:design` token in `concepts` substitutes for slot-store API (per pre-commit correction below) |
| **x-qa** | `skills/x-qa/SKILL.md` Run Phases (after step 1 Bootstrap, before scout) | `memory_smart_search({ query: <test path or framework + "flake">, limit: 10 })` — surface prior flake notes; treat as test-history context, not autopilot | `skills/x-qa/SKILL.md` § After This Skill (:137) — new save bullet | `memory_save({ content: "<test pattern or flake observation>", type: "lesson", concepts: "x-qa,<framework>,<pattern-kind>,slot:test-plan" })` — `slot:test-plan` token per pre-commit correction below |

### Cross-cutting rules (apply to ALL 7 wirings)

1. **Capability gate is mandatory.** Every call sites starts with: "only when `mcp.agentmemory` pinned in bootstrap-active set" (MCP calls) or "only when `agentmemory.server_up` pinned" (HTTP calls). When absent, **skip silently** — never log a warning, never fail. Pattern verified in x-bugfix Pre-Flight bullet.
2. **Try/catch all MCP and HTTP calls.** If the call errors at runtime (proxy mode race, transient HTTP failure), proceed with degraded behavior — the skill's primary workflow must not depend on agentmemory being reachable.
3. **No auto-apply.** Recall results are CONTEXT, never instructions. Skill prompts must phrase results as "prior sessions saw X — consider as supplementary input" not "do X because prior session did".
4. **Concept-token discipline.** First concept is always the skill name (`x-research`, `x-do`, etc.) so cross-session queries can filter by originating skill.
5. **Per-skill gotchas.md.** Append one bullet pointing at `../x-shared/capability-loading.md § Shared agentmemory.server_up Probe` for the canonical reference; do NOT duplicate the gotcha text.
6. **No probe duplication.** The `agentmemory.server_up` probe lives in `skills/x-shared/capability-loading.md` and is consumed from the session-pinned snapshot — never re-probe per skill dispatch.

### Validation plan (post-wiring)

After all 7 wirings land:

1. **Static read-through:** spot-check each modified file for the capability gate phrase and skip-silently fallback.
2. **TS-noop check:** no TypeScript files touched — pure markdown — so `tsc` is N/A. ESLint also N/A.
3. **Cross-model review:** dispatch x-review on the bundled diff per the v1.15.0 cycle (Claude + GPT oracle + Gemini-pro + general-purpose) with scope guard limited to correctness / capability-gate compliance / false assumptions / plan deviations.
4. **Manual smoke (deferred):** in a fresh session with backend up, invoke `/x-skills:x-research <topic>` and confirm the recall bullet fires (look for `memory_smart_search` in the deferred tools list AND a citation in the synthesis). Mark as PENDING in the release notes — do not block release on it.

### Release

Phase 1 + Phase 2 bundled into one release per user direction. Bump `1.15.0 → 1.16.0` (MINOR — feature-level: 7 skills now agentmemory-aware). Per CLAUDE.md release workflow, bump the three manifests + commit + tag + `gh release create` + push.

### Rationale for overriding the soak

Original soak rationale was "minimize blast radius if x-bugfix wiring has a bug". After Round 3, the wiring has been empirically validated AND every call is capability-gated with skip-silently fallback — failure mode is "skill behaves as if agentmemory weren't installed," which is the existing-user baseline. So the soak protects against a regression class that the gate already prevents. The risk worth respecting is *plan-reality drift in the new injection points* — handled by the static read-through + cross-model review above.

### Pre-commit corrections (advisor-caught, 2026-05-21)

Advisor surfaced two schema-vs-doc bugs in the executor output BEFORE commit — both fixed in the same diff. Pattern: trust upstream `tools-registry.ts` over plan-amendment author intent.

1. **`category` field silently dropped by `memory_save`.** The original Phase 2 rows used `category: "design-slot"` / `category: "test-plan-slot"` as a "convention substituting for slot-store API." But the standalone validator at `research/rohitg00/agentmemory/src/mcp/standalone.ts:104-114` picks only `content`, `type`, `concepts`, `files` from args — any extra top-level field is invisible to backend storage. Fix: encode the slot as a `slot:design` / `slot:test-plan` token inside the `concepts` comma-list, where it stays queryable via `memory_smart_search`.

2. **`memory_lesson_save` uses `tags`, not `concepts`.** Schema at `research/rohitg00/agentmemory/src/mcp/tools-registry.ts:752-774` accepts `{content, context, confidence, project, tags}` — NOT `concepts` (that's `memory_save`'s field). The x-mindful wiring originally used `concepts: "x-mindful,architecture,<slug>"`; corrected to `tags: "x-mindful,architecture,<slug>"`.

Meta-lesson (Rounds 1-4 all share it): **the plan author wrote from generic "tag-like field" intuition rather than per-tool schema citations.** Future agentmemory wiring tasks must cite the tools-registry.ts line range for every distinct MCP tool invoked, and the standalone.ts validator behavior for the standalone-mode subset.

### What was NOT touched

- The pre-existing x-bugfix wiring (shipped in v1.15.0) uses `type: "lesson"` for `memory_save`. The upstream docs list `type` enum as "pattern, preference, architecture, bug, workflow, or fact" — "lesson" is off-spec. BUT the validator (`standalone.ts:110`) accepts any string and defaults to "fact" if absent, so `type: "lesson"` is stored as-is. Consistency with the shipped x-bugfix pattern beats moving to an enum value that wasn't validated either. Phase 1 + Phase 2 wirings keep `type: "lesson"` and `type: "insight"` as-is.
- No `bin/setup`, hook, or capability-loading changes — those shipped in v1.15.0 and remain authoritative.
