# Doctor Validation Checks

`doctor.sh` exits 0 when all checks pass, non-zero with first failure surfaced.

## Schema integrity

1. `schema == 1`
2. `entry_points` non-empty array
3. Exactly one entry has `primary: true`, equal to top-level `primary_entry_point`
4. Every entry has `auto_managed` set explicitly (no implicit default)
5. Each `name` is a valid slug (`^[a-z0-9][a-z0-9-]{0,38}[a-z0-9]$`)

## Repo integrity

6. `repo_root` matches `git rev-parse --show-toplevel` (skipped under `--template-mode`)
7. For each entry: `launch.working_dir` resolves under `repo_root` via `realpath -m` (skipped under `--template-mode`)
8. Referenced files exist: `openapi_spec` (if set), `launch.command` first token (if it's a path) (skipped under `--template-mode`)

## Security

9. `auth.token_source` matches `^(env:[A-Za-z0-9_]+|file:[A-Za-z0-9_./-]+)$` AND, for `file:` form, must contain no `..` path segment AND must resolve under `repo_root`. Rejects literal tokens, env-var path traversal, and file-source traversal in one rule.

## Type-specific

10. For `type: http`: `base_url_template` AND `base_url_fallback` AND `health` all present
11. For `type: cli`: `args_schema` recommended (warning, not failure)
12. For `type: worker`: `queue_inspect` recommended (warning)

## Drift detection

13. If `launch.kind == npm-script`: package.json must contain the named script (skipped under `--template-mode`)
14. If `launch.command` references docker compose: a compose file must exist in `working_dir` (skipped under `--template-mode`)

## KB integrity

15. **Precondition cycle check.** Build a directed graph of `precondition_case_id` edges across all cases in `kb/index.json`. Refuse if the graph contains a cycle (Tarjan SCC). Refuse if any `precondition_case_id` points at a missing case.

## Channel stateful-awareness

C8. When a channel sets `singleton_id` AND `<repo_root>/.worktree-isolate/profile.json` exists with a non-empty `singletons[]`, the id MUST resolve to a `singletons[].id`. A dangling ref increments `warnings` (and prints `warn=...` on stderr) — never a hard fail, because isolate is optional. No-op when no isolate profile / no `singletons[]` (survives `--template-mode`).

Info-nudge. When `channels[]` is present but **no channel declares the `singleton_id` key at all** (the not-migrated case — detected with `has("singleton_id")`, NOT `!= null`, so a migrated stateless profile that writes `singleton_id: null` explicitly does NOT keep firing the nudge), doctor prints an `info=channels present but none carry singleton_id — run 'x-qa update' for stateful-aware selection` line on the PASS path. Info-level, distinct from `warnings` — never affects exit code.

## Reporting

Output format:
```
✓ doctor PASS
checks_attempted=14
checks_passed=14
warnings=2
```

or

```
✗ doctor FAIL
checks_attempted=<n>
checks_passed=<n-1>
first_failure=<check-number>
reason=<one-line>
```

`checks_attempted` increments before every check. `checks_passed` increments only on success. The two will diverge on the first failure (and the script exits) — never silently equal.

## --template-mode

`doctor.sh --template-mode <path>` skips checks 6, 7, 8, 13, 14 (anything that compares against the live repo). Used by Task 11's template validation step. The schema-and-security checks (1-5, 9-12) still run.
