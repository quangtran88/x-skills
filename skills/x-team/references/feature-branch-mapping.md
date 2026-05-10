# Feature-Branch Mapping (state file)

Lives at `<repo-root>/.x-skills/x-team/teams/<team-slug>/feature-map.json`.
Gitignored — Task 10 Step 1 adds `.x-skills/` to `.gitignore`. (The repo's existing `.gitignore` only covers `.omc/` and `skills/*/data/` — `.x-skills/` is NOT covered without the explicit append.)

## Schema (v1)

```json
{
  "schema": 1,
  "team_name": "ship-q2-features-a1b2c3",
  "created_at": "ISO-8601",
  "request": "<original user request>",
  "base_branch": "main",
  "auto_merge": false,
  "max_features": 3,
  "phase": "decomposing | provisioning | running | finalizing | complete | aborted",
  "features": [
    {
      "task_id": "1",
      "name": "auth refactor",
      "spec": "<full feature spec>",
      "acceptance": ["criterion 1", "criterion 2"],
      "branch": "feat-auth-a1b2c3",
      "worktree": "/abs/path/to/wt",
      "worker": "worker-1",
      "status": "pending | in_progress | qa | awaiting_human | blocked | done | failed",
      "attempts": 0,
      "qa_runs": [
        { "run_id": "...", "verdict": "fail", "report": "<path>" },
        { "run_id": "...", "verdict": "pass", "report": "<path>" }
      ],
      "blocker": null,
      "merged_at": null
    }
  ]
}
```

**Nullable fields (wave-2+ pending features):** `task_id`, `worker`, and `worktree` MAY be `null` for queued features that have not yet been promoted into the running set. They are populated by the lead's monitor loop (`advance_queue()`) when an in-flight slot frees up: x-worktree returns the worktree path, TaskCreate returns the task_id, the lead picks the next worker name. Schema-strict consumers must accept null for these three fields when the feature's `status == "pending"`.

## Invariants

1. `features[].name` unique within map.
2. `features[].task_id` is unique when non-null (matches OMC TaskCreate response). May be `null` for `pending` wave-2+ features.
3. `features[].worker` follows `worker-<n>` where `n` is 1..N when non-null. May be `null` for `pending` wave-2+ features.
4. `features[].branch` matches an actual branch on disk OR is the slug reserved for a future provisioning step (the slug is allocated in Phase 1 even for wave-2+ features so collision-checks happen up front).
5. `features[].worktree` — if non-null, is an absolute path that exists at write-time. May be `null` for `pending` wave-2+ features whose worktree has not yet been provisioned.

## Update Rules

- Each meaningful state transition rewrites the file (no append-log).
- File-locked via mkdir-based lockdir (`$MAP_PATH.lockd`) — portable on macOS and Linux without `flock`. Both `feature-map-init.sh` and `feature-map-update.sh` MUST acquire the same lock before any read-modify-write. Stale lock auto-reclaimed after 600s.
- On `phase: complete` or `aborted`, the file remains for post-mortem inspection.

## Resume

`/x-skills:x-team --resume <team-slug>`:
1. Read feature-map.json.
2. Validate every worktree still exists.
3. Re-read OMC team config: ensure `team_name` still active.
4. For each `features[].status == in_progress` whose worker is no longer in OMC config: re-spawn the worker with the same task ID + worktree.
5. For `features[].status == blocked`: re-surface the blocker question to user.
6. Resume monitor loop.
