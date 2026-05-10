# x-worktree — Isolated Git Worktree Provisioner

> **Role:** `worktree-provider`
> **Purpose:** Spin up an isolated git worktree on a new branch — used by sibling skills via `--wt` and invokable directly.

---

## Two Provisioning Backends

| Backend | When picked |
|---------|-------------|
| `worktrunk` `wt` CLI | Selected when `wt` is on PATH — wraps the user's existing tooling |
| native `git worktree` | Selected on systems without `wt` (git ≥ 2.5 required) |

Both backends end with the Bash session `cwd` switched into the new worktree so subsequent commands run in the isolated tree.

---

## Result Envelope

`x-worktree` always emits a stable JSON envelope so callers (`x-do`, `x-bugfix`, `x-team`) consume the result identically:

```json
{
  "ok": true,
  "branch": "<new-branch>",
  "base": "<base-branch>",
  "path": "<absolute path to worktree>",
  "backend": "wt | git",
  "isolated": true,
  "isolation": { "skipped": false, "profile": "<...>" }
}
```

---

## Auto-Isolation

When `.x-skills/x-worktree-isolate/profile.json` is present, `x-worktree` invokes `x-worktree-isolate` to write `compose.override.yml` + `.env.worktree` for the new worktree. Skip with `--no-isolate`.

---

## Capability Notes

- Required: `git ≥ 2.5`.
- Optional: `worktrunk` `wt` CLI (preferred when present).
- Auto-isolation requires `docker compose ≥ v2.24` and `python3` with `pyyaml`.

---

## Source

- Skill source: [`skills/x-worktree/SKILL.md`](../../skills/x-worktree/SKILL.md)
