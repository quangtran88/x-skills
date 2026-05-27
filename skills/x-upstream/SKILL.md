---
name: x-upstream
description: Use when the user wants to vendor or track an upstream GitHub repo as a research reference inside the current project — adds, updates, lists, or removes `research/<owner>/<repo>` git submodules pinned to the latest stable release (not main/HEAD). Invoked for upstream code reference, dependency mirroring, or research material management.
disable-model-invocation: true
triggers:
  - "x-upstream"
  - "add research repo"
  - "vendor upstream"
  - "track upstream"
  - "update research repo"
matching: fuzzy
---

# x-upstream — Pin Upstream Repos as Stable-Tagged Submodules

Manages `research/<owner>/<repo>` submodules in the current project. Each submodule is checked out at the **latest stable release tag** — never `main`, never a prerelease. Use this when you want a local, read-only mirror of an upstream repo for reference, code lookup, or dependency study without depending on the upstream remote at runtime.

## Bootstrap

1. Pin capabilities for the session per `../x-shared/capability-loading.md`. None of the multi-model flags gate this skill — it is a self-contained shell wrapper around `git submodule` + `gh`.
2. Confirm `git` is on PATH and cwd is inside a git work tree. The script enforces this.
3. `gh` + `jq` are preferred for stable detection; if absent the script falls back to `git ls-remote --tags` filtered by semver — no setup needed.

## Quick Dispatch

The dispatcher is at `$SKILL_DIR/scripts/x-upstream.sh` (where `$SKILL_DIR` is the "Base directory for this skill" line injected at invocation). Call it via Bash from the target project's root:

```bash
bash $SKILL_DIR/scripts/x-upstream.sh add https://github.com/anthropics/anthropic-sdk-python
bash $SKILL_DIR/scripts/x-upstream.sh update anthropic-sdk-python
bash $SKILL_DIR/scripts/x-upstream.sh update all
bash $SKILL_DIR/scripts/x-upstream.sh list
bash $SKILL_DIR/scripts/x-upstream.sh remove anthropic-sdk-python
```

The script `cd`s to the git repo root before any operation — invocation cwd does not need to be the root.

## Commands

| Command | Behavior |
|---|---|
| `add <github-url> [owner]` | Parse owner/repo from URL, resolve latest stable tag, run `git submodule add` at `research/<owner>/<repo>`, checkout that tag, stage `.gitmodules` and the submodule pointer. `[owner]` overrides the owner directory (use when forking or grouping). |
| `update <repo>` | Fetch tags for that submodule, resolve latest stable, checkout the tag if different. Stages the new pointer. |
| `update all` | Same as above for every submodule under `research/`. |
| `list` | Print path / pinned tag / origin URL for every research submodule. |
| `remove <repo>` | `git submodule deinit -f`, `git rm`, clean `.git/modules/<path>`. Stages the deletion. |

`<repo>` accepts bare name (`anthropic-sdk-python`), owner-qualified (`anthropics/anthropic-sdk-python`), or full path (`research/anthropics/anthropic-sdk-python`).

## Stable Release Detection (per user-chosen spec)

1. **Primary:** `gh release list --repo <owner>/<repo> --limit 30 --json tagName,isPrerelease,isDraft` → jq-filter to non-prerelease, non-draft → take first (most recent).
2. **Fallback:** `git ls-remote --tags --refs <url>` → keep refs matching `^v?\d+\.\d+(\.\d+)?$` (no `-alpha`, `-beta`, `-rc`, `-pre`, `-dev`, `-snapshot`) → `sort -V` → take last.

If both fail, `add` aborts and `update` skips with a warning. The user must then either tag the upstream or pick a commit manually.

## Examples

```bash
# Vendor the Anthropic Python SDK for offline reference
bash $SKILL_DIR/scripts/x-upstream.sh add https://github.com/anthropics/anthropic-sdk-python
# → research/anthropics/anthropic-sdk-python @ v0.39.0

# Bump everything under research/ to current stable
bash $SKILL_DIR/scripts/x-upstream.sh update all

# Inspect what's pinned
bash $SKILL_DIR/scripts/x-upstream.sh list
# PATH                                         PINNED             URL
# research/anthropics/anthropic-sdk-python     v0.39.0            https://github.com/...

# Drop one
bash $SKILL_DIR/scripts/x-upstream.sh remove anthropic-sdk-python
```

After any mutating command, the script leaves changes staged but **not committed** — review with `git diff --cached`, then commit yourself. This preserves caller control over commit message conventions.

## When NOT to Use

| Situation | Use Instead |
|---|---|
| You need the upstream code installed as a runtime dep | Native package manager (`npm install`, `pip install`, etc.) |
| You need to fork and modify upstream | `git clone` + your own remote; submodules are read-only mirrors |
| Project is not a git repo | `git init` first, or just clone the upstream into a plain folder |
| Upstream is not on GitHub | The script's `gh` path requires GitHub; semver-tag fallback still works for any git host but stable detection is weaker |

## Dependencies

- `git` ≥ 2.13 (for `submodule deinit -f` semantics) — **required**
- `gh` CLI — **optional but recommended**; without it, stable detection falls back to semver tag heuristic
- `jq` — **optional**; required only when `gh` is used
- Network access to the upstream remote — **required** for `add` and `update`

## Gotchas

See `gotchas.md` for known failure patterns — update it when you encounter new ones.

Task: {{ARGUMENTS}}
