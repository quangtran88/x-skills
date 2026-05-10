# Lead Monitor Loop

After spawning all workers, the lead enters a monitor loop. Inbound `SendMessage` arrives as new conversation turns automatically.

## Message Classification

OMC's `SendMessage` has no `metadata` field. The classifier therefore reads:

- **Kind** = the prefix of `summary`, before the first `:`. Recognized:
  `feature_done`, `blocker`, `feature_blocked`, `progress_note`, `blocker_resolution`.
- **Task ID** = `summary` after the first `:` (e.g. `feature_done:7` → task_id `7`).
- **Payload** = first fenced ` ```json … ``` ` block extracted from `content`.
  Lead parses it with:
  ```bash
  payload=$(awk '/^```json$/{flag=1;next} /^```$/{flag=0} flag' <<<"$content" | jq -e .)
  ```
  Required fields per kind (validated before acting):
  - `feature_done`: `kind`, `task_id`, `branch`, `worktree`, `qa_report`
  - `blocker`: `kind`, `task_id`, `context` (and optional `options[]`)
  - `feature_blocked`: `kind`, `task_id`, `branch`, `qa_report`
  - `blocker_resolution`: `kind`, `task_id`, `verdict` (and optional `instructions`)
  - `progress_note`: `kind`, `task_id` (no other required fields)

If a message arrives with an unrecognized `summary` prefix, log it and continue — do NOT crash the loop.

## Kinds → Lead Action

| Kind | Source | Lead Action |
|---|---|---|
| `feature_done` | Worker finished impl+QA pass | **Idempotence check first** — if `feature_map.features[].status == "done"` OR `merged_at` is non-null for this task_id, log "duplicate feature_done — skipping" and DO NOT call merge-feature.sh. Otherwise: if `auto_merge`, invoke `merge-feature.sh`. Else enqueue for human review. Update feature-map. |
| `blocker` | Worker hit a question for human | `AskUserQuestion` with worker's payload. Wait for answer. SendMessage(`blocker_resolution:{TASK_ID}`) back to worker. Update `feature_map.blocker`. |
| `feature_blocked` | Worker exhausted retries | Mark feature `failed` in map. Surface to user in final summary. Do NOT auto-shutdown other workers. |
| `progress_note` | Worker still alive, sharing progress | Log only. No action. |

## Loop Pseudocode

```
def parse_inbound(msg):
  prefix, _, task_id_part = msg.summary.partition(":")
  payload = extract_first_json_fence(msg.content)  # awk + jq
  return prefix, task_id_part, payload

def advance_queue():
  # Promote next pending feature into the running set.
  # IMPORTANT: pending features in waves 2+ have NO worktree yet — Phase 3
  # only provisioned wave 1. Provision the worktree HERE before spawning Task(),
  # otherwise Task(working_directory=…) points at a path that does not exist.
  # The persisted worktree path MUST be written back to feature-map via
  # `feature-map-update.sh --worktree <abs>` so resume + monitoring see it.
  if any feature.status == pending and active_count() < max_features:
    next = first(features where status == pending)
    envelope = Skill: x-skills:x-worktree <base> <next.branch> [--no-isolate]
    task_id = TaskCreate(subject=next.name, description=next.spec).task_id
    worker_name = "worker-" + str(next_worker_index())
    # Persist the lazy-provisioned fields so the schema's nullable-only-when-pending
    # invariants hold once the feature transitions out of pending.
    Bash: scripts/feature-map-update.sh --team-slug {TEAM} --task-id <prior_pending_id> \
            --worktree <envelope.WORKTREE_PATH> --worker <worker_name>
    # NOTE: if the feature was inserted with task_id=null (typical for wave-2+),
    # advance_queue must first rewrite features[] to assign the freshly returned
    # task_id. Use a one-shot `jq` to set it by feature.name (unique invariant 1):
    #   jq '(.features[] | select(.name == $n)).task_id = $id' --arg n "<name>" --arg id "<task_id>" …
    Task(subagent_type=executor, team_name, name=worker_name,
         working_directory=envelope.WORKTREE_PATH, prompt=preamble + spec)
    Bash: scripts/feature-map-update.sh --team-slug {TEAM} --task-id <new_task_id> \
            --status in_progress

  # Reconcile orphaned `completed` task entries — worker may have died after
  # TaskUpdate(completed) without (or before) emitting feature_done. Treat as done
  # and merge if auto_merge, but APPLY THE SAME IDEMPOTENCE GUARD as the
  # feature_done handler so we do not double-merge if the message later arrives.
  for t in TaskList where status==completed:
    fm = feature_map.get(task_id=t.id)
    if fm.status == done or fm.merged_at is not None:
      continue  # already finalized, skip
    feature_map.update(task_id=t.id, status=done)
    if auto_merge:
      merge-feature.sh --branch <branch> --base <feature_map.base_branch> --worktree <wt>
      feature_map.update(task_id=t.id, merged_at=<ts>)
    log "reconciled orphaned completed task: " + t.id

while not all features terminal:
  await next inbound message OR timeout(5min)

  if timeout:
    # Cross-reference feature-map BEFORE flagging stuck — workers in
    # feature.status == awaiting_human are intentionally idle pending
    # blocker_resolution and must be excluded from stuck-detection.
    awaiting = read feature_map for task_ids where status == awaiting_human
    poll TaskList for stuck workers (status==in_progress > 10min, no messages,
                                     task_id NOT in awaiting)
    for each stuck worker: SendMessage("status check") and wait 1 more cycle
    advance_queue()
    continue

  if message:
    kind, task_id, payload = parse_inbound(message)
    match kind:
      "feature_done":
        # IDEMPOTENCE GUARD — duplicate handler entry must not double-merge.
        fm = feature_map.get(task_id=task_id)
        if fm is None:
          log "feature_done for unknown task_id: " + task_id; continue
        if fm.status == done or fm.merged_at is not None:
          log "duplicate feature_done for " + task_id + " — skipping"; continue
        feature_map.update(task_id=task_id, status="done")
        if auto_merge:
          merge-feature.sh --branch <payload.branch> --base <feature_map.base_branch> --worktree <payload.worktree>
          feature_map.update(task_id=task_id, merged_at=<ts>)
        advance_queue()
      "blocker":
        feature_map.update(task_id=task_id, status="awaiting_human", blocker=message.content)
        verdict = AskUserQuestion(payload.context + payload.options)  # see blocker-escalation.md for sanitized rendering
        # Reply to worker via SendMessage — kind goes in summary, payload in content fence.
        SendMessage(recipient=message.from_worker,
                    summary="blocker_resolution:" + task_id,
                    content=verdict + "\n\n```json\n{\"kind\":\"blocker_resolution\",\"task_id\":\"" + task_id + "\",\"verdict\":\"" + verdict + "\"}\n```")
        feature_map.update(task_id=task_id, status="in_progress", clear_blocker=True)
      "feature_blocked":
        feature_map.update(task_id=task_id, status="failed")
        advance_queue()
      "progress_note":
        log
      _:
        log "unknown summary prefix: " + kind

# All terminal → shutdown
for each active worker:
  SendMessage(shutdown_request, recipient=worker)
  wait 30s for shutdown_response

TeamDelete

# Cleanup worktrees
for each feature where status == "done" and not merged:
  print "merge command: git merge --no-ff {branch}"
for each feature where status == "failed":
  print "investigate: {worktree}; QA report: {qa_report}"
```

## Concurrency Cap

If `max_features < total_features`, only spawn `max_features` workers initially. As features reach terminal state, spawn the next pending feature's worker. The map's `phase: provisioning` accounts for this.

## Worktree Lifecycle on Failure

A `failed` feature's worktree is NOT auto-removed. User may want to inspect it. On `TeamDelete`, surface the worktree paths so user knows where to look.

For `done` features that are merged: optionally remove worktree via `git worktree remove`. Default: keep until user `/x-team:cleanup`.

## AskUserQuestion Wording for Blockers

Standardize:
```
**[BLOCKER on feature: {feature_name}]**

Worker {worker_name} (branch: {branch}) is blocked.

**Question:** {worker.content_prose}

**Context:** {payload.context}

How should the worker proceed?
```

User can answer free-form OR pick from suggested options:
1. Direct verdict (worker applies)
2. Skip this case / move on
3. Abort this feature
4. Pause whole team for human inspection
