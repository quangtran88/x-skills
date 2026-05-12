# x-upstream — Gotchas

Known failure patterns. Append new ones with date + symptom + cause + fix.

## Empty (no gotchas observed yet)

The skill is a thin wrapper around `git submodule` and `gh release list`. Expected failure modes the script already handles:

- **Not a git repo** → `require_repo_root` aborts with a clear message.
- **Malformed URL** → `parse_github_url` returns non-zero, `add` aborts.
- **No stable release exists** → both `gh` and semver fallback return empty; `add` aborts, `update` warns and skips.
- **Target path already exists** → `add` aborts before touching the index.
- **Upstream rate-limits `gh`** → script still falls back to `git ls-remote`, which is anonymous.

Append below when you hit something the script does NOT handle gracefully.
