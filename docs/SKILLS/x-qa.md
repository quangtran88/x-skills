# x-qa — Profile-Driven E2E QA

> **Role:** *(not declared)*
> **Purpose:** Scan a project once for entry points, persist a test profile, and dispatch parallel test runners against an isolated containerised stack.

---

## Subcommands

| Subcommand | What it does |
|-----------|--------------|
| `init` | Scan the project for entry points (HTTP, CLI, gRPC, GraphQL, worker, websocket) and write `.x-skills/x-qa/profile.json` |
| `update` | Re-scan and merge changes into entries marked `auto_managed: true`; user-edited fields are preserved |
| `inspect` | Pretty-print the active profile + last-run summary |
| `generate` | Produce a `TEST_PLAN.md` (ephemeral run-scoped or persisted with `--persist`) |
| `run` | Launch the stack, dispatch test cases as parallel background runners, collect verdicts |
| `doctor` | Validate profile schema, verify entry points reachable, surface broken state |

---

## Pipeline

1. **Profile gate** — `run` auto-invokes `doctor` first; refuses on broken profile (`--skip-doctor` to override).
2. **Stack launch** — Reuses the `x-worktree-isolate` docker-compose stack when present so per-worktree QA does not collide.
3. **Test fanout** — Bash `run_in_background` for `x-gemini` (simple HTTP cases) and `Agent` `run_in_background` for Claude/Sonnet (complex flows).
4. **Verdict envelope** — Stable, machine-readable JSON so callers (`x-team`, `x-do`, the user) consume the result identically.
5. **Strict by default** — Partial fail = `fail`. Opt into tolerance via `--allow-flaky-rate <pct>`.

---

## State

- `<repo>/.x-skills/x-qa/profile.json` — checked in, source of truth.
- `<repo>/.x-skills/x-qa/runs/<run-id>/` — gitignored transient artifacts.
- `<repo>/.x-skills/x-qa/cache/` — gitignored caches.

v1 only executes `http` entries. Other entry types persist in the profile but `run` skips them with `not-yet-supported in v1`.

---

## Capability Notes

- `gemini_cli` (via `x-gemini`) is the cheap dispatcher.
- `plugin.omc` enables Claude/Sonnet runners through the Agent tool.
- `docker compose ≥ v2.24` is required for stack launch.

---

## Source

- Skill source: [`skills/x-qa/SKILL.md`](../../skills/x-qa/SKILL.md)
