# x-team — Multi-Feature Team Orchestrator

> **Role:** *(not declared)*
> **Purpose:** Decompose a multi-feature request into N parallel features, provision a worktree per feature, run dev workers in parallel, and gate every feature on `x-qa` passing.

---

## Architecture

- Lead orchestrator session calls OMC `TeamCreate`, decomposes work, then spawns one dev worker per feature via `Task(team_name, name, working_directory=<worktree>)`.
- Each worker invokes `/x-skills:x-do` for implementation and `/x-skills:x-qa run --worktree <wt>` for E2E verification.
- Workers report progress via `SendMessage`. The lead's monitor loop classifies inbound messages by the `summary:` prefix:

| Summary prefix | Lead action |
|----------------|-------------|
| `feature_done:{TASK_ID}` | Mark feature green; queue for review (default) or auto-merge (`--auto-merge`) |
| `blocker:{TASK_ID}` | `AskUserQuestion` to the human, relay verdict back via `blocker_resolution:{TASK_ID}` |
| `feature_blocked:{TASK_ID}` | Retry exhausted — escalate to human attention |

---

## Hard Requirements

- **`plugin.omc`** — uses `TeamCreate`, `SendMessage`, `Task` primitives. Without OMC the skill refuses with a clear error.
- **`x-qa` profile** — `.x-skills/x-qa/profile.json` must exist for the project. If missing, `x-team` blocks and runs `/x-skills:x-qa init` first.

---

## Locked Decisions

- One feature = one branch = one worktree = one dev worker. Worktrees come from `x-worktree`, not OMC's helper.
- Default concurrency cap: 3 parallel features. Override with `--max-features <N>`.
- Worker preamble is intentionally relaxed vs OMC `/team`: `Skill` tool is allowed (so x-do/x-qa can dispatch), `Task` is banned (no nested team spawning).
- All x-team artifacts live under `.x-skills/x-team/`.
- Auto-merge is opt-in; default is to queue passing features for human review with a merge command suggestion.

---

## Source

- Skill source: [`skills/x-team/SKILL.md`](../../skills/x-team/SKILL.md)
