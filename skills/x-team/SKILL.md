---
name: x-team
description: Use when the user asks for parallel team-style execution of multiple features in one project — orchestrates a team lead + N dev workers, one feature per worktree, each gated on x-qa E2E tests, with blocker escalation to human via SendMessage. Hard requires `plugin.omc` (TeamCreate/SendMessage primitives) and `.x-skills/x-qa/profile.json` (E2E gate).
role: team-orchestrator
disable-model-invocation: true
---

# x-team — Parallel Feature Team Orchestrator

## Bootstrap (MANDATORY)

Before any phase:

1. Pin capabilities per `../x-shared/capability-loading.md`. **HARD requirement: `plugin.omc == true`.** Refuse with a clear message otherwise.
2. Read `../x-omo/SKILL.md` for the OMO catalog (used inside dev workers via x-do, not directly here).
3. Read `gotchas.md`.
4. Verify the x-qa skill is installed: check that `skills/x-qa/SKILL.md` exists in the plugin tree (the skill itself, not just a profile). If missing, refuse with: `x-team requires the x-qa skill. Ensure x-skills plugin is up-to-date (≥ version that includes x-qa).` Then verify `<repo-root>/.x-skills/x-qa/profile.json` exists. If missing, surface:
   > x-team requires an x-qa profile. Run `/x-skills:x-qa init` first.
   Offer to invoke it inline; block until profile ready.
5. **Isolation prerequisite check.** When any entry in `<repo-root>/.x-skills/x-qa/profile.json` has `launch.uses_isolate_profile == true` AND `--no-isolate` was NOT passed, ALSO require `<repo-root>/.worktree-isolate/profile.json` to exist. If missing, refuse with:
   > x-team requires an x-worktree-isolate profile because your x-qa profile sets `uses_isolate_profile: true`. Run `x-worktree-isolate init` first, or pass `--no-isolate` to skip per-feature docker isolation (NOT recommended for parallel docker-compose stacks — workers will fail at `docker compose up` with "address already in use").

   Detection: `jq -e '[.entry_points[].launch.uses_isolate_profile] | any' <profile>` returns `true`. Skip the check entirely when `--no-isolate` is set.
6. Verify `git rev-parse --is-inside-work-tree` succeeds and the user's main branch is clean (`git status --porcelain` empty), or warn explicitly.

## Invocation

| Form | Behavior |
|---|---|
| `/x-skills:x-team "<request>"` | Decompose into N features, provision team, run. |
| `/x-skills:x-team --features <N> "<request>"` | Force feature count (else auto-decompose). |
| `/x-skills:x-team --max-features <N> "<request>"` | Cap parallel concurrency (default 3). NEVER drops features — extra features are queued and promoted as in-flight slots free up. |
| `/x-skills:x-team --base <branch> "<request>"` | Base branch for worktrees (default: current HEAD). |
| `/x-skills:x-team --auto-merge` | On feature pass, auto-merge to base. Default OFF. |
| `/x-skills:x-team --resume <team-slug>` | Resume an interrupted run. |
| `/x-skills:x-team --no-isolate` | Skip `x-worktree-isolate` per-feature (passes the equivalent flag through to `x-worktree`). |

## Phase 1: Decompose

Per `references/decomposition-rules.md`:

- [ ] **Memory recall** (only when `mcp.basic_memory` pinned in the bootstrap-active set): one `mcp__basic-memory__search_notes({ query: "<request keywords>", page_size: 5 })` call BEFORE decomposition — surface prior failed-feature root causes / blocker verdicts as leads, not verdicts, per `../x-shared/mcp-toolbox.md § Memory Reflex`. Skip silently when not pinned.

1. Read user request.
2. If `--features <N>` not given: use native `Grep` / OMO `explore` to scan project, propose feature split, ask user via `AskUserQuestion` (header: "Feature split"). Allow edit/cancel.
3. For each feature, generate:
   - `name` (short slug)
   - `spec` (full description)
   - `acceptance` (bullet list)
   - `branch` slug: `feat-<name>-<6hex>`
4. If total features > `--max-features` (default 3), run in waves of `--max-features` parallel: provision the first wave's worktrees now, queue the rest as `pending`. NEVER drop features — the monitor loop's `advance_queue()` (see `references/monitor-loop.md`) provisions each pending feature's worktree and spawns its worker as in-flight slots free up. Surface the wave plan to the user.

## Phase 2: TeamCreate

Slug: `<sanitized request 30char>-<6hex>` e.g. `ship-q2-features-a1b2c3`.

```
TeamCreate {
  "team_name": "ship-q2-features-a1b2c3",
  "description": "<original user request, truncated 200>"
}
```

The current session becomes `team-lead@<slug>`.

## Phase 3: Provision Worktrees

For each feature in this wave (parallel):

```
Skill: x-skills:x-worktree <base-branch> <feature-branch>
```

Pass `--no-isolate` if `--no-isolate` flag is set on x-team invocation.

Capture each envelope:
- `WORKTREE_PATH=<abs>`
- `BRANCH=<feat-...>`
- `ISOLATE_APPLIED=true|false|skipped`

If any worktree provisioning fails: abort the wave, run `TeamDelete`, surface to user.

## Phase 4: TaskCreate + Pre-assign

For each feature:

```
TaskCreate {
  "subject": "<feature name>",
  "description": "<full spec + acceptance>",
  "activeForm": "Implementing <feature name>"
}
→ task_id

TaskUpdate { "taskId": "<id>", "owner": "worker-<n>" }
```

Initialize feature-map:

```bash
Bash: scripts/feature-map-init.sh --team-slug <slug> --request "<req>" --base <branch> --features-json <features.json>
```

## Phase 5: Spawn Workers

Spawn ALL workers in parallel via `Task()` with `team_name`, `name`, and `working_directory`. Inject `references/worker-preamble.md` with substitutions filled in:

```
Task {
  "subagent_type": "executor",
  "team_name": "<slug>",
  "name": "worker-<n>",
  "working_directory": "<WORKTREE_PATH_n>",
  "prompt": "<filled-in worker preamble + feature spec + acceptance criteria>"
}
```

Update feature-map: `phase: running`.

## Phase 6: Monitor Loop

See `references/monitor-loop.md`. Per inbound `SendMessage`, classify by `summary` prefix (kind) and extract structured payload from the first ` ```json … ``` ` fence in `content` — OMC's SendMessage has no `metadata` field. Recognized prefixes: `feature_done`, `blocker`, `feature_blocked`, `progress_note`. Per kind:

- `feature_done` → idempotence guard: skip if `feature_map.status == done` or `merged_at` non-null. Otherwise optionally invoke `merge-feature.sh --branch <branch> --base <feature_map.base_branch> --worktree <wt>`. Update map. Wave-next: spawn next pending feature if any.
- `blocker` → `AskUserQuestion`, relay back via SendMessage with `summary: blocker_resolution:{TASK_ID}` and a JSON-fence payload. Update `map.blocker`.
- `feature_blocked` → mark failed in map. Continue (do not abort sibling features).

Concurrency: keep at most `--max-features` workers in `in_progress` simultaneously. As features reach terminal state, advance the queue.

## Phase 7: Shutdown

When all features are terminal (`done` or `failed`):

For each active worker:
```
SendMessage {
  "type": "shutdown_request",
  "recipient": "worker-<n>",
  "content": "All features complete; shutting down"
}
```

Wait up to 30s per worker for `shutdown_response`. Then:

```
TeamDelete { "team_name": "<slug>" }
```

Update feature-map: `phase: complete` (or `aborted` if user cancelled).

## Phase 8: Final Summary

Print to user:

```
✓ x-team complete
Team: <slug>
Features: <n>
  Done: <m>
  Failed: <k>
  Auto-merged: <a>
  Awaiting human merge: <b>

Awaiting merge:
  - <feature-name> @ <branch> (worktree: <path>) — QA: pass (<p>/<t>)
    Merge: git merge --no-ff <branch>

Failed:
  - <feature-name> @ <branch> — see <qa_report> for failures
    Inspect: cd <worktree>

Feature map: .x-skills/x-team/teams/<slug>/feature-map.json
```

If `--auto-merge` and any merges failed (conflict, protected branch): list separately with reasons.

## Persist Lessons (always-run, gated)

- [ ] **Persist run lessons** (only when `mcp.basic_memory` pinned in the bootstrap-active set): for each **failed** feature, one `mcp__basic-memory__write_note` to `lessons/<project-slug>/` capturing the root cause (from its `qa_report`); for each human-resolved **blocker**, one `write_note` to `decisions/<project-slug>/` capturing the verdict + rationale. project-slug per § Consumer rules; tag each with the project slug + `x-team`. Persist durable output only — root causes and blocker verdicts, never per-feature run summaries. When the Phase-1 recall already surfaced a note on the same root cause / blocker, apply *Update over duplicate* (append via its permalink — same-kind only: a failed-feature lesson appends only onto a `lessons/` hit, a blocker verdict only onto a `decisions/` hit). Placement, tagging, and dedup per `../x-shared/mcp-toolbox.md § Memory Reflex` / § Consumer rules. Skip silently when not pinned.

## Hard Requirements

- `plugin.omc == true`
- `.x-skills/x-qa/profile.json` exists
- `git ≥ 2.5`
- Clean working tree on the lead session (or explicit `--allow-dirty`)

## After This Skill

If all features pass + auto-merge: surface merged branches list.
If features pass without auto-merge: print merge commands for human.
If any feature blocked: surface blocker reasons, ask user how to proceed.

## Dependencies

- `../x-shared/capability-loading.md`, `invocation-guide.md`, `context-envelope.md`
- `../x-worktree/SKILL.md` (provisioning)
- `../x-qa/SKILL.md` (E2E gate inside workers)
- `../x-do/SKILL.md` (impl inside workers)

## Gotchas

See `gotchas.md`.

Task: {{ARGUMENTS}}
