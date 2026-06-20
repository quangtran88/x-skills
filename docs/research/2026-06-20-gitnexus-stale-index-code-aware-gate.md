# GitNexus stale-index reminder — code-aware gate

**Date:** 2026-06-20
**Status:** Applied locally (not in any repo — see "Recovery" below)
**File patched:** `~/.claude/hooks/gitnexus/gitnexus-hook.cjs` (gitnexus install artifact, outside version control)

## Problem

Running many git worktrees in parallel, the GitNexus "stale index" reminder fires
after **every** `git commit|merge|rebase|cherry-pick|pull` — even for markdown-only
commits that touch no code symbols. Root cause: staleness is a pure SHA comparison
(`git rev-list --count lastCommit..HEAD`) with **no file-type awareness**. The index
is shared across worktrees (canonical root via `--git-common-dir`), so every parallel
worktree drifts ahead of HEAD immediately → the nag is effectively always-on.

GitNexus has no incremental analyze mode (full re-scan = 2–10 min on this repo) and no
built-in suppression flag.

## Fix

Make the PostToolUse staleness check **code-aware**: after confirming HEAD drifted from
the indexed commit, diff the changed files and stay silent if they're all docs. Fails
safe — any code file, unknown extension, or git error still fires the reminder.

This addresses the markdown false-positive and most of the parallel-worktree noise. It
does **not** fix analyze slowness (a GitNexus-internal limitation), but the gate means
you only get nagged when code actually changed, so casual re-analyze is rarely needed.

## Patch (re-appliable)

In `~/.claude/hooks/gitnexus/gitnexus-hook.cjs`, immediately **before** the
`handlePostToolUse` function (the `PostToolUse handler — detect index staleness` block),
add:

```js
// Doc / non-symbol-bearing extensions. Changes confined to these can't move
// the symbol graph, so a stale-index reminder for them is pure noise.
const DOC_EXTENSIONS = new Set(['.md', '.mdx', '.markdown', '.txt', '.rst', '.adoc']);

/**
 * Return true when every file that differs between `fromCommit` and `toCommit`
 * is a doc file (markdown, plain text, etc.) — meaning the GitNexus symbol
 * graph cannot have gone stale. An empty diff (identical trees) also returns
 * true. Fails safe: any non-doc file, or any git error, returns false so the
 * reminder still fires.
 */
function onlyDocsChanged(cwd, fromCommit, toCommit) {
  try {
    const res = spawnSync('git', ['diff', '--name-only', fromCommit, toCommit], {
      encoding: 'utf-8',
      timeout: 3000,
      cwd,
      stdio: ['pipe', 'pipe', 'pipe'],
    });
    if (res.error || res.status !== 0) return false;
    const files = (res.stdout || '')
      .split('\n')
      .map((f) => f.trim())
      .filter(Boolean);
    if (files.length === 0) return true; // identical trees → nothing to reindex
    return files.every((f) => DOC_EXTENSIONS.has(path.extname(f).toLowerCase()));
  } catch {
    return false;
  }
}
```

Then inside `handlePostToolUse`, right after the existing
`if (currentHead && currentHead === lastCommit) return;` line and **before** the
`const analyzeCmd = ...` line, add the gate:

```js
  // Code-aware gate: when every change since the indexed commit is a doc file
  // (markdown/txt/etc.), the symbol graph can't be stale — stay silent. This
  // is the common false-positive in parallel-worktree doc/plan work. Fails
  // safe: unknown/code files or any git error → reminder still fires below.
  if (lastCommit && onlyDocsChanged(cwd, lastCommit, currentHead)) return;
```

## Verification

Drove the actual hook (stdin JSON) against a temp git repo with a faked
`.gitnexus/meta.json`:

| Commit since index | Result |
|---|---|
| docs-only (`.md`) | silent ✓ (the fix) |
| code (`.ts`) | reminder ✓ (signal preserved) |
| mixed code+docs | reminder ✓ (fail-safe) |
| HEAD == index | silent ✓ (unchanged) |
| never indexed (no `lastCommit`) | reminder ✓ (fail-safe) |

## Recovery

`~/.claude/` is not a git repo and the hook has an install-templated CLI path, so a
**gitnexus reinstall / re-setup can overwrite this file**. If the markdown nag returns,
re-apply the patch above. To make it permanent for everyone, upstream the gate to
`abhigyanpatwari/GitNexus` (the hook source ships in the `gitnexus` npm package).

## Not changed

- Analyze slowness — no incremental mode exists in GitNexus; out of scope.
- The secondary staleness source (the `gitnexus://…/context` MCP resource's
  `checkStaleness()`) lives in the vendored submodule and only fires when that resource
  is read, not on every commit — left alone.
- `.json` / `.yaml` are intentionally **not** doc-exempt (can be symbol-bearing config);
  add to `DOC_EXTENSIONS` only if false-positives appear there.
