---
name: x-worktree
description: Use when the user (or a sibling skill via --wt flag) wants to spin up an isolated git worktree for a task — wraps the worktrunk `wt` CLI when present, falls back to native `git worktree`, switches the Bash session cwd into the new worktree, auto-applies docker isolation when profile present (skip with --no-isolate), and emits a machine-readable result envelope
role: worktree-provider
---

# x-worktree — Isolated Worktree Provisioner

Provisions a fresh worktree on a new branch so callers (x-do, x-bugfix, ad-hoc users) can mutate files in isolation from the user's current checkout. Always creates a new branch — never switches into an existing one.

## Invocation

| Form | Behavior |
|------|----------|
| `/x-skills:x-worktree` | Base = current HEAD branch. Auto-generated new branch name. |
| `/x-skills:x-worktree <target_branch>` | Base = `<target_branch>`. Auto-generated new branch name. |
| `/x-skills:x-worktree <target_branch> <new_branch>` | Base = `<target_branch>`. New branch = `<new_branch>`. |
| `/x-skills:x-worktree "" <new_branch>` | Base = current HEAD. New branch = `<new_branch>`. |
| `/x-skills:x-worktree <doc.md> [<more.md>…]` | Base = current HEAD. New branch derived from doc metadata (`<type>/<slug>`, see `references/doc-naming.md`). Docs are moved into the worktree and committed. |
| `/x-skills:x-worktree <target_branch> <doc.md> [<more.md>…]` | Base = `<target_branch>`. Branch derived from doc. Docs migrated + committed. |
| `/x-skills:x-worktree <args…> --no-isolate` | Skip the auto-isolate step entirely. Envelope omits `ISOLATE_APPLIED`. |

Arg parsing: any positional arg matching `*.md` AND resolving to an existing file is classified as a **doc**; everything else is a **positional**. Of the positionals, `$1` = target_branch, `$2` = new_branch. The `--no-isolate` flag may appear anywhere and is stripped before classification. An explicit `$2` (new branch) overrides doc-derived naming.

Env: `XWI_AUTO_ISOLATE=0` disables auto-isolate persistently for the shell session (envelope emits `ISOLATE_APPLIED=skipped, ISOLATE_REASON=env-disabled`). The `--no-isolate` flag wins when both are set (flag → omit line entirely).

## Hard requirements

- `git` ≥ 2.5 on PATH and cwd inside a git work tree
- `openssl` or `xxd` (auto-detected) for the 6-char hex
- Optional: `wt` (worktrunk) — auto-detected, native git fallback otherwise

## Steps

0. **Partition args.** After stripping `--no-isolate`, walk the remaining args in order. For each arg: if it ends in `.md` AND `[ -f "$arg" ]` → classify as doc (resolve to **absolute path now**, before any cwd change, via `python3 -c 'import os,sys; print(os.path.abspath(sys.argv[1]))' "$arg"`). Else → positional. Let `DOCS[]` be the doc list (preserve order) and `POSITIONAL[]` the rest. Use `POSITIONAL[0]` as `$1` and `POSITIONAL[1]` as `$2` in the steps below.

1. **Validate environment.** `git rev-parse --is-inside-work-tree`. On failure → emit standard error envelope with `REASON=cwd is not a git work tree`, `PROVIDER_ATTEMPTED=none`. STOP. Also capture `SOURCE_REPO_ROOT=$(git rev-parse --show-toplevel)` here — needed for the doc-migration step after the cwd switch.

2. **Resolve base branch (`$1`).** If `$1` empty → `BASE_BRANCH=$(git rev-parse --abbrev-ref HEAD)`. If result is `HEAD` (detached) → emit error envelope with `REASON=HEAD is detached; pass an explicit target_branch`. STOP.

2.5. **Validate docs (if `DOCS[]` non-empty).** For each doc absolute path:
   - Must be inside `SOURCE_REPO_ROOT` (else → error envelope with `REASON=doc '<path>' is outside the repo work tree`). STOP.
   - Run `git status --porcelain -- "<rel-path-from-repo-root>"`. Acceptable states:
     - `??` (untracked) → mark for migration.
     - empty output (clean / already committed) → skip migration for this file (it's already in HEAD and will be inherited by the worktree).
   - Any other state (`M `, ` M`, `MM`, `A `, etc.) → error envelope with `REASON=doc '<rel-path>' is tracked + modified; commit or stash before passing to x-worktree`. STOP.

3. **Resolve new branch name (`$2`).**
   - If `$2` provided → validate with `git check-ref-format --branch "$2"`. On failure → emit error envelope with `REASON=branch name '<value>' fails git check-ref-format`. STOP.
   - Else if `DOCS[]` non-empty → derive `<type>/<slug>` from `DOCS[0]` per `references/doc-naming.md`. Validate with `git check-ref-format --branch`. On validation failure, fall through to the auto-gen bullet below (do NOT abort — the docs still migrate under the auto-gen name).
   - Else → auto-generate `<base-slug>-<6hex>` where `<base-slug>` = `BASE_BRANCH` with `/` and non-`[A-Za-z0-9._-]` chars replaced by `-`, truncated to 32 chars; `<6hex>` = `openssl rand -hex 3` (fallback `head -c 4 /dev/urandom | xxd -p | head -c 6`).

4. **Provision (Steps 4–5 use absolute path / `git -C` — cwd switch happens in Step 6).**
   - **`wt` present** (`command -v wt`): `wt switch --create --base "$BASE_BRANCH" "$NEW_BRANCH" --no-cd`. On `Branch already exists`: `wt switch "$NEW_BRANCH" --no-cd`. Capture path from `wt list`.
   - **`wt` absent**: `REPO_ROOT=$(git rev-parse --show-toplevel); WORKTREE_PATH="${REPO_ROOT%/*}/$(basename "$REPO_ROOT")-wt/$NEW_BRANCH"; mkdir -p "$(dirname "$WORKTREE_PATH")"; git worktree add -b "$NEW_BRANCH" "$WORKTREE_PATH" "$BASE_BRANCH"`. On `already exists`: `git worktree add "$WORKTREE_PATH" "$NEW_BRANCH"`.
   - On any other error → emit error envelope with `REASON=<exact git/wt stderr>` and the attempted provider. STOP.

5. **Submodule init (best-effort).** `git -C "$WORKTREE_PATH" submodule update --init --recursive 2>/dev/null || true`. Never fail the skill on submodule errors.

6. **Switch session cwd.** `cd "$WORKTREE_PATH" && pwd`. Bash tool persists cwd across calls; subsequent plain Bash calls now run inside the worktree.

6.25. **Migrate docs and commit (only when `DOCS[]` has migration-marked entries).** Runs inside the worktree (cwd already switched). The worktree creation already succeeded — this step is allowed to surface a hard error and STOP, because the user's intent ("docs committed in the new worktree") fails if migration fails.

   For each doc marked for migration in Step 2.5:
   ```
   rel="${doc_abs_path#$SOURCE_REPO_ROOT/}"
   dest="$WORKTREE_PATH/$rel"
   mkdir -p "$(dirname "$dest")"
   mv "$doc_abs_path" "$dest"   # physical move — file is untracked at source
   ```
   Track each successful move so it can be reversed on later failure (`MOVED[]` parallel arrays of `source` and `dest`).

   After all moves succeed:
   ```
   git -C "$WORKTREE_PATH" add -- "${REL_PATHS[@]}"
   git -C "$WORKTREE_PATH" commit -m "docs: add $(printf '%s, ' "${BASENAMES[@]}" | sed 's/, $//')"
   DOC_COMMIT_SHA=$(git -C "$WORKTREE_PATH" rev-parse HEAD)
   DOCS_COMMITTED=${#REL_PATHS[@]}
   ```

   **Rollback on any failure** (mv error, add error, commit error — e.g., pre-commit hook rejects):
   - For each entry in `MOVED[]` (reverse order): `mv "$dest" "$source"` to restore the originals.
   - Emit a partial-success envelope (worktree exists, docs not committed). Set `DOCS_COMMITTED=0` and `DOCS_ERROR=<one-line, sanitized stderr, ≤200 chars>` (same sanitization pipeline as Step 6.5). Skip the isolate step (6.5) — surface the user-facing problem first.
   - The worktree is still usable; the user just needs to migrate docs manually or fix the hook and retry.

   When `DOCS[]` is empty OR contains only already-committed docs: this step is a no-op. Envelope omits `DOCS_COMMITTED` and `DOC_COMMIT_SHA`.

6.5. **Auto-isolate (best-effort).** Runs after the cwd switch; never fails the skill itself (worktree creation already succeeded).

   **Gate (skip cases):**
   - `--no-isolate` flag passed → omit `ISOLATE_APPLIED` line entirely from the envelope (user opted out, no signal needed).
   - `XWI_AUTO_ISOLATE=0` in env → set `ISOLATE_APPLIED=skipped`, `ISOLATE_REASON=env-disabled`. Skip apply.
   - `command -v x-worktree-isolate` non-zero → `ISOLATE_APPLIED=skipped`, `ISOLATE_REASON=binary-missing`. Skip apply.

   **Otherwise run apply (cwd is already inside `<WORKTREE_PATH>` from step 6).** Allocate stderr capture files via `mktemp` (NOT `/tmp/xwi-*.$$` — predictable PID paths are vulnerable to symlink attack and collide across parallel invocations):
   ```bash
   xwi_stderr="$(mktemp -t xwi-stderr.XXXXXX)"
   xwi_rel_stderr="$(mktemp -t xwi-rel.XXXXXX)"
   timeout 5 x-worktree-isolate apply --quiet --if-profile-exists 2>"$xwi_stderr"
   xwi_rc=$?
   ```
   apply.sh resolves the profile from either `<worktree>/.worktree-isolate/profile.json` or `<main-checkout>/.worktree-isolate/profile.json`; x-worktree never replicates that detection.

   **Decide envelope additions by exit code:**

   - `xwi_rc == 0` AND `<WORKTREE_PATH>/.worktree-isolate/state.local.json` exists → success → set `ISOLATE_APPLIED=true`. (No `ISOLATE_REASON`, no `ISOLATE_HINT`.)
   - `xwi_rc == 0` AND state.local.json absent → `--if-profile-exists` short-circuited (no profile in repo, OR cwd was main checkout) → set `ISOLATE_APPLIED=skipped`, `ISOLATE_REASON=no-profile`.
   - `xwi_rc == 124` (timeout) → set `ISOLATE_APPLIED=false`, `ISOLATE_REASON=apply-timeout-5s`. Run orphan cleanup (below). Set `ISOLATE_HINT=run x-worktree-isolate apply manually to retry` (or with `release-failed` suffix per below).
   - `xwi_rc != 0` (other) → set `ISOLATE_APPLIED=false`, `ISOLATE_REASON=$(LC_ALL=C tr -cd '\11\12\15\40-\176' < "$xwi_stderr" | tr '\n\r\t' ' ' | head -c 200)`. Run orphan cleanup (below). Set `ISOLATE_HINT=...` per below.

   **Orphan cleanup (only on `xwi_rc != 0`, includes timeout).** apply.sh writes `state.local.json` BEFORE claiming the registry slot (apply.sh:382 → :406); on SIGTERM mid-apply, the state file can outlive an unclaimed slot. Cleanup is mandatory:
   ```bash
   rm -f "$WORKTREE_PATH/.worktree-isolate/state.local.json"
   x-worktree-isolate release --quiet 2>"$xwi_rel_stderr" || true
   ```
   Both run from inside `<WORKTREE_PATH>` (step 6's cwd is still active). `release` is idempotent — no-ops when no claim exists.

   **`ISOLATE_HINT` construction:**
   - Default (release succeeded): `ISOLATE_HINT=run x-worktree-isolate apply manually to retry`
   - Release also failed (release stderr non-empty): `ISOLATE_HINT=run x-worktree-isolate apply manually to retry; release-failed: $(LC_ALL=C tr -cd '\11\12\15\40-\176' < "$xwi_rel_stderr" | tr '\n\r\t' ' ' | head -c 100)`

   **Stderr sanitization.** Always pipe stderr through `LC_ALL=C tr -cd '\11\12\15\40-\176'` first (drops every byte outside printable ASCII + tab/LF/CR — kills ANSI escapes, control chars, shell metas), then `tr '\n\r\t' ' '` (collapse to single line), then `head -c 200` (reason) or `head -c 100` (release-failed suffix). Reasoning: `ISOLATE_REASON=` ships into caller LLM prompts as DOCKER CONTEXT material; un-sanitized escape sequences could inject terminal-control or shell-meta characters.

   **Always cleanup tempfiles after envelope emission:**
   ```bash
   rm -f "$xwi_stderr" "$xwi_rel_stderr"
   ```

7. **Emit success envelope** (exactly these lines, nothing above):
   ```
   ✓ Worktree ready
   WORKTREE_PATH=<absolute-path>
   BRANCH=<new-branch-name>
   BASE=<base-branch-name>
   PROVIDER=<wt|git>
   CWD_SWITCHED=true
   DOCS_COMMITTED=<N>                         # only when ≥1 doc was migrated and committed
   DOC_COMMIT_SHA=<sha>                       # only when DOCS_COMMITTED present
   DOCS_ERROR=<one-line>                      # only when doc migration was attempted and failed (DOCS_COMMITTED=0 also emitted)
   ISOLATE_APPLIED=<true|false|skipped>       # always present unless --no-isolate OR doc migration failed
   ISOLATE_REASON=<one-line>                  # required when false; advisory when skipped
   ISOLATE_HINT=<one-line>                    # only when false
   ```

## Error envelope (unified)

Every failure path emits this exact shape — no other error formats:
```
✗ Worktree FAILED
REASON=<one-line>
PROVIDER_ATTEMPTED=<wt|git|none>
CWD_SWITCHED=false
```

See `references/examples.md` for concrete examples of each failure mode.

## Always-create-new-branch (by design)

x-worktree never switches into an existing branch's worktree — it always creates a new branch from a base. Callers want a clean slate, not to land on an existing branch.

| Args | Behavior |
|---|---|
| 0 args | base = current HEAD, auto-generated new branch |
| 1 arg | use the arg as **base**, auto-generate new branch |
| 2 args | base + new branch (both explicit) |

To open an *existing* worktree, use `wt switch <branch> --no-cd` directly — outside x-worktree's scope.

## Caller integration (x-do, x-bugfix, others)

See `references/caller-integration.md` for: `--wt` flag parsing, dispatch shape, **non-negotiable cwd-propagation rules** for Agent / OMC / OMO / morph-mcp dispatches, the `--wt-no-isolate` passthrough, the DOCKER CONTEXT block construction, and verification.

## Auto-isolation contract

See `references/auto-isolation.md` for: tri-state `ISOLATE_APPLIED` semantics, skip / failure reason vocabulary, state.local.json schema v1, slot-leak cleanup invariant, idempotence guarantee, and `--no-isolate` ↔ `XWI_AUTO_ISOLATE=0` precedence.

## Doc-driven branch naming

See `references/doc-naming.md` for: detection order (front-matter → H1 → filename prefix → filename slug), type normalization (`feature` → `feat`, `bugfix` → `fix`), slug rules, and worked examples. Used whenever `.md` paths appear in args and `$2` (explicit new branch) is not provided.

## Examples

See `references/examples.md` for success and failure envelope examples.

## Anti-Patterns

See `references/anti-patterns.md`.

## Gotchas

- **Detached HEAD** — refuses to auto-name a branch from a detached HEAD. User must pass an explicit base.
- **Branch already exists** — falls through to `wt switch <name> --no-cd` or `git worktree add <path> <branch>`. Never force-deletes.
- **wt vs git path divergence** — worktrunk writes worktrees as `<repo>.<branch>`; native fallback uses `<parent>/<repo>-wt/<branch>`. Callers MUST consume the emitted `WORKTREE_PATH=` line, never reconstruct it.
- **Submodule init failure** — non-fatal. Worktree is still usable.
- **Symlinks / non-standard layouts** — native fallback uses the `git rev-parse --show-toplevel` resolved path. Treat `WORKTREE_PATH` as opaque.
- **Doc arg collides with a branch name** — `.md`-suffixed args that resolve to existing files are ALWAYS classified as docs. If you want a branch literally named `feat.md`, pass it as `$2` (explicit new branch positional) where it bypasses the doc filter — e.g., `x-worktree main feat.md`. The classifier only inspects the doc-vs-positional partition; once a string is in `POSITIONAL[1]`, it's treated as a branch regardless of suffix.
- **Doc already committed in current branch** — when a passed doc is already tracked + clean (already in HEAD), x-worktree skips its migration and the worktree inherits it via the base branch. Branch name is still derived from it. No commit is created if all passed docs are already-committed.
- **Pre-commit hooks block the docs commit** — the docs commit runs under the worktree's hooks; if a hook rejects, x-worktree rolls back the file moves and emits `DOCS_ERROR=…`. Worktree itself stays. Common cause: a `commit-msg` linter that doesn't accept `docs:` — adjust the hook, then `cd $WORKTREE_PATH && git add <docs> && git commit -m "<your-msg>"` manually.

## Dependencies

- `git` (mandatory, ≥ 2.5)
- `wt` (optional, auto-detected)
- `openssl` or `xxd` (one is on every macOS/Linux box)
- `../x-shared/context-envelope.md` — caller handoff format

No skills are hard dependencies. Caller is responsible for cwd discipline downstream of the success envelope.

Task: {{ARGUMENTS}}
