# x-team Gotchas

## Capability + Setup

1. **`plugin.omc` missing.** TeamCreate/SendMessage are OMC-provided. x-team refuses with a clear message. Install OMC first.
2. **No x-qa profile.** x-team blocks at bootstrap. Run `/x-skills:x-qa init` first.
3. **Dirty working tree.** Lead's main session has uncommitted changes. Worktrees inherit committed state only. Warn user; offer to `git stash` first.

## Worktree

4. **Branch already exists.** x-worktree falls through to switch into existing. Means worker may inherit stale state. Suggest unique 6hex suffix in branch slug (already done by Phase 1).
5. **Detached HEAD on lead session.** x-worktree refuses to auto-name from detached HEAD. User must pass `--base <branch>`.
6. **Submodule init failure.** Non-fatal. Worker may need to `git submodule update --init` itself if the feature touches submodules.

## Worker / Skill Tool

7. **x-do dispatches Agents internally.** Allowed (Agent tool, not Task tool). If x-do tries `Task(team_name, ...)` (which it shouldn't), worker preamble's ban kicks in. If issue surfaces: x-do is doing something incompatible with team mode — investigate.
8. **Worker forgets working_directory.** Each Bash/Edit/Write inside x-do/x-qa MUST execute in WORKTREE_PATH. Worker preamble emphasises this. If worker drifts: feature applies to wrong path.
9. **Skill recursion.** Worker MUST NOT call `/x-skills:x-team` (banned in preamble). If somehow it does, infinite team spawn. Lead detects via TaskList showing nested team and refuses to spawn child team.

## QA Gate

10. **x-qa profile drift mid-run.** User edits profile.json while team is running. Workers continue with cached profile (read at start of x-qa run). Doctor on next run catches drift.
11. **Service launch port collision.** Without x-worktree-isolate (or with `--no-isolate`), parallel workers each run `docker compose up` against the same hardcoded host ports. Docker does NOT serialise port binds — the second worker fails fast with `Error response from daemon: ... bind: address already in use` at the launch step (not at health-wait). Even worse: when only `container_name` collides but ports come from env, the second `compose up` may find the first worker's containers already running under the parent-dir-derived `COMPOSE_PROJECT_NAME` and silently treat them as up — both workers then test against worker-1's stack. Mitigation: always run with x-worktree-isolate enabled (the default — bootstrap step 5 enforces it when any x-qa entry has `uses_isolate_profile: true`).
12. **QA report path drift.** Worker emits `qa_report` in metadata as relative path. Lead can't resolve. Worker preamble specifies absolute path.

## Monitor Loop

13. **Worker dies silently.** No `feature_done`, no `feature_blocked`, just gone. Lead's timeout (10min idle) pings, no reply → mark failed, surface to user.
14. **Multiple concurrent blockers.** AskUserQuestion is sequential. Lead queues subsequent blockers, processes one at a time. Surface queue size in question.
15. **Human cancels mid-blocker.** User aborts AskUserQuestion. Lead treats as "abort this feature" — sends shutdown_request to that worker, marks feature failed.

## Auto-merge

16. **Branch protection rules.** `gh` API check catches protected branches; `merge-feature.sh` refuses. If `gh` not installed: detection skipped — manual merge user's responsibility.
17. **Merge conflict between two team features.** Feature-1 merges first, feature-2's merge conflicts. Lead surfaces, doesn't auto-resolve. User picks: abandon feature-2, or hand-merge.
18. **Worktree cleanup after merge.** Worktrees are NOT auto-removed (preserve evidence). User cleans via `git worktree remove <path>` or `wt rm <branch>`.

## State / Resume

19. **Lead crashes mid-monitor.** feature-map.json on disk. `--resume <slug>` rebuilds state. Workers don't auto-die — they sit waiting for messages until shutdown_request arrives.
20. **OMC team config out of sync with feature-map.** TeamDelete called externally clears OMC state. feature-map.json still says `phase: running`. `--resume` validates OMC team exists; if not, rebuilds team or aborts.

## Performance

21. **N docker stacks = laptop pressure.** Default `--max-features 3` caps concurrent feature execution. Don't bump to 10 on a 16GB laptop.
22. **Gemini quota across N x-qa runs.** Each feature's x-qa fires 8 bg gemini calls. 3 features in parallel = 24 concurrent calls. Watch for 429s.
