# Doc-Driven Branch Naming

When the caller passes one or more `.md` files as positional args, x-worktree derives the new branch name from the **primary doc** (the first `.md` arg) instead of auto-generating `<base>-<6hex>`.

## Detection order (first match wins)

For the primary doc, run these probes in order. The first probe that yields BOTH a valid `<type>` and a non-empty `<slug>` wins:

### 1. Front-matter

```yaml
---
type: feat
slug: add-user-auth
title: Add user auth
---
```

Parse only the leading `---` … `---` block (lines 1..N up to the second `---`). Look for `^type:\s*(\S+)\s*$`, `^slug:\s*(\S+)\s*$`, and `^title:\s*(.+?)\s*$`. If `slug:` is present, Slug = `<slug>` — it is the author-chosen kebab slug that also names the doc file (`docs/backlog/<slug>.md` for x-backlog docs), so using it keeps the branch `<type>/<slug>` aligned with the doc filename, which a freeform `title:` does not guarantee. Otherwise Slug = `<title>`. Either value still passes Slug normalization below.

### 2. H1 line

Scan from the top, skipping front-matter block and blank lines, for the first line matching:

```
^#\s+(?P<type>feat|fix|chore|refactor|docs|test|perf|style|ci|build|feature|bugfix)[:\s]\s*(?P<title>.+?)\s*$
```

Case-insensitive on `<type>`. Slug = `<title>`.

### 3. Filename prefix

Strip `.md`, then match:

```
^(?P<type>feat|fix|chore|refactor|docs|test|perf|style|ci|build|feature|bugfix)[-_](?P<rest>.+)$
```

Slug = `<rest>`.

### 4. Fallback

Type = `feat`. Slug = filename without `.md` extension.

## Type normalization

| Input         | Canonical |
|---------------|-----------|
| `feature`     | `feat`    |
| `bugfix`      | `fix`     |
| (others)      | (as-is)   |

Only canonical types are emitted into branch names.

## Slug normalization

Apply in order:

1. Lowercase.
2. Replace `_` and whitespace with `-`.
3. Drop every character not in `[a-z0-9-]`.
4. Collapse runs of `-` to a single `-`.
5. Trim leading/trailing `-`.
6. Truncate to 40 chars; trim trailing `-` again after truncation.

If the result is empty, fall back to `untitled`.

## Final branch name

```
<type>/<slug>
```

Validate with `git check-ref-format --branch "$NEW_BRANCH"`. On failure, the skill falls back to the standard auto-generated name (`<base-slug>-<6hex>`) and proceeds — the doc-migration step still runs.

## Multiple docs

When 2+ `.md` files are passed, the **first** doc in arg order is the primary. Other docs share the same branch — they are migrated and committed in the same commit as the primary.

If the primary doc yields no usable name (all probes fail), but a later doc would, the skill still uses the **first** doc — predictability over cleverness. Users wanting a specific naming source should pass that doc first.

## Examples

| Input | Derived branch |
|-------|---------------|
| `PLAN.md` with `# feat: Add user auth` H1 | `feat/add-user-auth` |
| `feat-payment-flow.md` (no H1, no front-matter) | `feat/payment-flow` |
| `BACKLOG.md` (no metadata) | `feat/backlog` (fallback) |
| `fix_login_crash.md` | `fix/login-crash` |
| Front-matter `type: refactor`, `title: Extract auth module` | `refactor/extract-auth-module` |
| Front-matter `type: feat`, `slug: user-billing-portal`, `title: User Billing Portal v2` | `feat/user-billing-portal` (`slug:` wins over `title:`) |
| `Feature - User onboarding.md` (no H1, no front-matter) | `feat/feature-user-onboarding` (fallback) |
