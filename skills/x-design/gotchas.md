# x-design — Gotchas

Known failure patterns and how to recognize / fix them.

> **Cross-reference note:** `references/shadcn-handoff.md` references gotcha #10 by number. When inserting new gotchas, append at the end or verify existing cross-references still resolve.

## 1. Irregular slug forms

Slugs in `references/catalog.md` don't always match the brand name. Common traps:

| Brand name said by user | Actual slug | Wrong guess |
|---|---|---|
| Linear | `linear.app` | ~~`linear`~~ |
| Mistral / Mistral AI | `mistral.ai` | ~~`mistral`~~ |
| xAI | `x.ai` | ~~`xai`~~ |
| Cal.com | `cal` | ~~`cal.com`~~ |
| OpenCode AI | `opencode.ai` | ~~`opencode`~~ |
| Together AI | `together.ai` | ~~`together`~~ |

**Always** look up the slug in `references/catalog.md` — never construct from the brand name. A wrong slug yields a 404 from `curl -f`.

## 2. Stale pinned commit

`config.json` pins commit `80bbbc2` from 2026-04-07. If VoltAgent force-pushes or garbage-collects old objects (unlikely but possible), the raw URL will 404. Mitigation:

1. Fetch the current `main` SHA: `curl -s https://api.github.com/repos/VoltAgent/awesome-design-md/commits/main | jq -r .sha`
2. Test a known slug at the new SHA
3. Update `config.json` → `pinned_commit` + `pinned_at`
4. Verify `site_count` still matches (may need to add/remove rows in `catalog.md`)

## 3. Network failure during fetch

`curl -fsSL` returns non-zero on any HTTP error or network failure. When this happens:

- Do NOT write a zero-byte or partial `DESIGN.md` to the project
- Report the failure clearly (exit code + URL that was tried)
- Offer to retry or fall back to `config.json` → `research_fallback_path` (substitute `{slug}`) if that file exists

The research-lib path is the offline fallback; it's the same content pinned by `add-research` at clone time.

## 4. Existing DESIGN.md at target

Before `curl`-ing, check if `<target>/DESIGN.md` exists. If so:
- Show its byte count and first line
- Ask whether to overwrite, rename (e.g. `DESIGN.previous.md`), or abort
- Never silently overwrite — this is destructive of user work

## 5. Not in a project root

The user may run the skill from a parent directory, a subdirectory, or no project at all. Heuristic for "project root":

| Signal | Weight |
|---|---|
| `.git` directory exists | Strong |
| `package.json` / `pyproject.toml` / `Cargo.toml` / `go.mod` exists | Strong |
| `CLAUDE.md` / `AGENTS.md` exists | Medium |
| User explicitly says "install here" | Override |

If no strong signals and no explicit instruction, ASK before writing. `DESIGN.md` conventionally lives at project root, not in subdirectories.

## 6. Slug matches multiple candidates via intent tags

When the user says "dark minimal", many sites match. Don't pick one silently — propose the top 2–3 with their one-liners and let the user decide. Tie-breakers in order:

1. Popularity of the brand (more recognizable first)
2. Tag specificity (more matching tags wins)
3. Alphabetical (stable fallback)

## 7. Fetching files other than DESIGN.md

Only `DESIGN.md` belongs in the user's project. Do NOT fetch:
- `preview.html` / `preview-dark.html` — these are for human eyeballing on github.com
- `README.md` (the per-site one) — redundant with the catalog entry
- `LICENSE` — the MIT license covers use of the content; no need to install it

If the user wants to preview a style, construct `preview_url_template` and print the URL — don't download.

## 8. CLAUDE.md mutation

The "append one-liner to project CLAUDE.md" step is off by default (`auto_update_claude_md: false`). Even when the user opts in for one install, do NOT persist that opt-in globally. Every project is a separate decision.

Never modify existing content in the project's `CLAUDE.md` — only append the single hint line. If the user's `CLAUDE.md` already contains a reference to `DESIGN.md`, skip the append entirely and tell them it's already set up.

## 9. Catalog drift after upstream update

If the user runs `update-research awesome-design-md` separately, the research-lib clone advances but this skill's `config.json` pin does NOT follow automatically. This is intentional — installs should be reproducible. To advance the pin, update `config.json` manually (see gotcha #2).

## 10. shadcn handoff edge cases (step 7)

The shadcn step 7 has several quiet failure modes:

| Symptom | Cause | Fix |
|---|---|---|
| `get_project_registries` returns empty | Project has no `components.json` (not a shadcn project) | Skip step 7 entirely — never push shadcn onto non-shadcn projects |
| `search_items_in_registries` returns 0 results for a tag | Brand intent tag (e.g. `editorial`, `terminal-native`) doesn't map to shadcn vocabulary | Fall back to generic primitive names: `button`, `card`, `input`, `dialog`, `nav` |
| `get_add_command_for_items` returns a multi-package command | Item depends on other primitives | Show the full command + a one-line explanation; let the user decide |
| Existing `components.json` has a custom registry | User already has a curated set | Run `get_audit_checklist` instead of seeding from scratch |
| Auto-running install commands | Step 7c says **print, don't run** | Never execute `npx shadcn add ...` — always show the command and let the user run it |

The detection-first rule is non-negotiable: a non-React/Tailwind project should see no mention of shadcn at all.

## 11. Catalog freshness vs upstream

`references/catalog.md` is manually maintained. After upstream adds or removes sites, the catalog silently drifts. Validate with:

```bash
# Check upstream site count
curl -s https://api.github.com/repos/VoltAgent/awesome-design-md/contents/design-md | jq 'length'
# Compare against config.json → site_count (currently 58)
```

If counts differ: update `catalog.md` rows + `config.json` → `site_count`. If a new site appears upstream, add it to the correct category with slug, intent tags, and one-liner. If a site was removed upstream, remove the catalog row. Always re-pin the commit SHA when updating (see gotcha #2).

## 12. Misrouting between x-design and ui-ux-pro-max

These skills have overlapping triggers. Quick disambiguation:

| User intent | Route |
|---|---|
| "Use Linear's visual style" | `x-design` (install reference) |
| "Design a dashboard for an analytics tool" | `ui-ux-pro-max` (author from scratch) |
| "I want something warm and editorial" | `x-design` (match intent tags) |
| "What color palette should I pick for a fintech app?" | `ui-ux-pro-max` (palette recommendation) |
| "Apply Stripe's gradients to my landing page" | `x-design` + `ui-ux-pro-max` (install + adapt) |

When genuinely ambiguous, ask once: "Do you want me to install an existing design reference (x-design) or help you author one from scratch (ui-ux-pro-max)?"
