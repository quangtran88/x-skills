# Decomposition Rules

The lead splits the user's request into N "features" — each independently implementable, testable, and mergeable.

## Feature Definition

A feature is:
1. **Independent** — can be implemented without touching files another feature is editing (or with clearly bounded shared touches).
2. **Atomic** — passes/fails as a unit. Has its own acceptance criteria.
3. **Branch-scoped** — lives on its own branch + worktree.
4. **QA-able** — has at least one E2E test scenario in its TEST_PLAN.md.

## Splitting Heuristics

| Signal | Suggested Split |
|---|---|
| User mentions "and" between distinct nouns ("auth and billing") | Split per noun. |
| User says "for these N pages" | Split per page. |
| User mentions multiple endpoints | Split per endpoint group. |
| User describes 3 phases ("first X, then Y, then Z") | Sequential, NOT parallel. Use plan instead of team. |
| User says "across the codebase" | Likely single feature, decompose internally via x-do plan. |

## When to Refuse Team Mode

If decomposition yields:
- 1 feature → not a team task. Suggest `/x-skills:x-do` instead.
- Cross-cutting changes touching shared files heavily → not parallelizable. Suggest sequential plan.
- More than 10 features → too many. Cap at 5 per recommendation, ask user to prioritize.

## Auto-detection vs User-Specified

If user passes `--features <N>` or names features explicitly, honor that.

Else: lead reads request, proposes N features with names, asks user to confirm via:

```
Detected N features:
1. <name> — <one-line scope>
2. <name> — <one-line scope>
...

Proceed with team of N? [Y/edit/cancel]
```

## Branch Slug Generation

For each feature: slug = `feat-<short-noun>-<6hex>`. Example: `feat-auth-a1b2c3`. The 6-hex suffix is intended to avoid collisions but is NOT collision-proof on its own — `x-worktree` falls through to switch into an existing branch (gotcha #4), so a hex collision silently reuses a stale worktree.

**Pre-check (mandatory):** for every generated slug, verify the branch does NOT already exist before passing to `x-worktree`:

```bash
for attempt in 1 2 3; do
  slug="feat-<short-noun>-$(openssl rand -hex 3)"
  git rev-parse --verify "refs/heads/$slug" >/dev/null 2>&1 || break
  slug=""  # collision; regenerate
done
[[ -n "$slug" ]] || { echo "REASON=could not generate unique slug after 3 attempts" >&2; exit 2; }
```

## Dependency Detection

If two features touch the same file (per a quick `morph-mcp codebase_search` for likely files), surface the conflict and ask:
- Run sequentially (one feature first, second after merge)
- Accept conflict risk and merge with `--no-ff` + manual resolution at end
- Refactor first to remove shared edits

Default: surface and ask.
