# Update Diff Rules

`update.sh` reconciles a fresh `inspect.sh` scan against an existing `profile.json`.

## Diff Categories

| Category | Definition | Action |
|---|---|---|
| ADDED | In scan, not in profile | Prompt user: "Detected new entry point X. Add? [Y/N]". If Y, write with `auto_managed: true`. |
| MISSING | In profile, not in scan | Prompt: "Profile entry Y not found in code. Remove / Keep / Investigate?" |
| CHANGED | Same name, different launch.command | Only update if `auto_managed: true`. Otherwise: surface to user, ask before touching. |
| UNCHANGED | Same name, same launch.command | No action. |

## auto_managed Flag

- Every `init`-created entry: `auto_managed: true` (default).
- User edits a field manually: should also set `auto_managed: false` (encourage via README).
- `update.sh` NEVER mutates an entry where `auto_managed: false` without explicit user `--force-overwrite-user-edits`.

## Re-verification

After reconciliation, smoke-verify changed/added entries only. Existing unchanged entries keep `verified` state.

## Version Bump

Every successful `update` increments `version` (semver) and rewrites `generated_at`. `generated_by: x-qa-update`.

## Channels & QA_MEMORY.md

- `channels[]` reconcile by `name`, same ADDED/MISSING/CHANGED/UNCHANGED rules
  as entry points. `auto_managed: false` channels are preserved; `update`
  refuses to change or drop them without `--allow-overwrite-user-edits`.
- `QA_MEMORY.md` is narrative and not auto-reconciled. `update` emits
  `WARN=QA_MEMORY.md older than profile…` when the profile is newer, prompting a
  re-interview. It is never auto-overwritten (it holds human knowledge).