# x-worktree-isolate — Per-Worktree Docker-Compose Isolation

> **Role:** *(not declared)*
> **Purpose:** Make multiple worktrees of the same repo coexist without docker-compose `container_name` / port / named-volume collisions.

---

## Pipeline

1. **Scan once** — Inspect the project's compose files for collision-prone fields (`container_name`, fixed host ports, named volumes, fixed networks).
2. **Emit profile** — Write `.x-skills/x-worktree-isolate/profile.json` capturing the surface that needs per-worktree overrides.
3. **Per-worktree apply** — On every new worktree (invoked by `x-worktree` or directly), write:
   - `compose.override.yml` with `!reset null` for collision-prone fields, plus per-worktree replacements derived from the worktree slug.
   - `.env.worktree` with the slug, port offsets, and volume suffixes referenced by the override.

---

## Hard-Block Footguns

The skill refuses to apply isolation when it detects:

- Ambiguous compose project name across worktrees.
- Host-bound services without a port mapping it can offset.
- Named volumes with hardcoded host paths the user explicitly opted into.

In each case `x-worktree-isolate` reports the offending entry and the minimal manual fix needed.

---

## Capability Notes

- Required: `docker compose ≥ v2.24` (for the `!reset null` directive in overrides) and `python3` with `pyyaml`.
- Optional: `worktrunk` `wt` for hooking the apply step into worktree creation.

---

## Source

- Skill source: [`skills/x-worktree-isolate/SKILL.md`](../../skills/x-worktree-isolate/SKILL.md)
