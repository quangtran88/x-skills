---
name: x-design
description: "Use when the user wants to apply a visual design system to a project, references a specific brand's style (Linear-like, Stripe-like, Claude-like), asks for a DESIGN.md, or describes aesthetic intent (warm editorial, dark minimal, stark futuristic) for AI UI generation"
---

# x-design — Visual Design System Router

Resolves user design intent to a curated `DESIGN.md` file from [VoltAgent/awesome-design-md](https://github.com/VoltAgent/awesome-design-md) and installs it into the current project. Index-only by design — fetches via GitHub raw URLs, never bundles upstream files.

## When to Use

**Trigger phrases:**
- "Use Linear's style" / "make it look like Stripe" / "apply Claude's design"
- "Drop a DESIGN.md here" / "install a design reference"
- "Make this look warm editorial / dark minimal / stark futuristic / premium luxury / playful / terminal-native"
- "What design styles are available?"

**When NOT to use:**
- User wants bespoke design with **no brand reference** → use `ui-ux-pro-max` directly (note: if there *is* a brand reference, `x-design` will chain into `ui-ux-pro-max` via step 6 anyway)
- User wants to review an existing design → use `x-review`
- User wants to generate a DESIGN.md from a screenshot → delegate to `multimodal-looker` + write directly
- Project already has a `DESIGN.md` the user is happy with → point to it, don't overwrite

## Bootstrap

Read these two files before routing any request:
1. `config.json` — pinned commit, URL templates, defaults
2. `references/catalog.md` — 58 sites with slugs, categories, intent tags, tag vocabulary

## Detection

| Signal | Route |
|---|---|
| Named brand ("Linear", "Stripe", "Claude") | Direct slug lookup in catalog |
| Descriptive intent ("warm editorial", "dark minimal") | Match against intent tags → propose 2–3 candidates |
| "What's available?" / "list styles" | Show catalog section(s) the user cares about |
| "Something like X but Y" | Look up X's tags, filter by Y, propose candidates |
| "Refresh catalog" / "update pin" | See "Re-pinning" section in `references/catalog.md` |

## Workflow

1. **Resolve target directory.** Confirm cwd is a project root (has `.git`, `package.json`, `pyproject.toml`, or user confirms explicitly). If ambiguous, ask before proceeding. Never write outside the user-confirmed directory.

2. **Resolve slug from intent.**
   - **Named:** find catalog row whose slug or name matches. Slugs are irregular (`linear.app`, `mistral.ai`, `x.ai`, `cal`, not `cal.com`) — always verify against the catalog.
   - **Descriptive:** match user's adjectives against the `Intent Tags` column. Return top 2–3 candidates with their one-liners. Ask the user to pick.
   - **Listing:** print the category section verbatim from `references/catalog.md`.

3. **Preview before install.** Show the user:
   - Chosen slug + site name + category
   - Preview URL (substitute `{commit}` and `{slug}` into `preview_url_template` from `config.json`)
   - One-liner from the catalog
   Ask for confirmation before fetching.

4. **Fetch the DESIGN.md.** Build the raw URL from `config.json` `raw_url_template`, substituting `{repo}`, `{commit}`, `{slug}`:
   ```bash
   curl -fsSL "https://raw.githubusercontent.com/VoltAgent/awesome-design-md/<commit>/design-md/<slug>/DESIGN.md" -o <target>/DESIGN.md
   ```
   `curl -f` fails loudly on 404 (stale commit or wrong slug). If a `DESIGN.md` already exists at the target, warn and ask before overwriting.

5. **Report.** Show:
   - Where the file landed + its byte count
   - Brand name + one-liner
   - **Philosophy-first framing:** Before showing section 9 prompts, remind the user: "Read sections 1 (Visual Theme), 5 (Layout Principles), and 7 (Do's and Don'ts) first — agents that absorb the design philosophy produce far better results than those that cherry-pick hex values from the prompt guide."
   - The first paragraph of section 9 "Agent Prompt Guide" from the fetched file (these copy-pasteable prompts are the highest-leverage part of the install — surface them every time)
   - **Stack-aware hint:** Check the project for `package.json` (React/Next → Tailwind `bg-[#hex]` or `className`), `nuxt.config` / `vue` deps (Vue → scoped `<style>`), `svelte.config` (Svelte → `style:` directives), `pubspec.yaml` (Flutter → `Color(0xFFhex)`), or plain HTML. Append one line: "Section 9 prompts use raw CSS values — adapt to `bg-[#f5f4ed]` (Tailwind), `style={{ background }}` (React), or your framework's convention."
   - **AI slop warning:** Append a brief advisory referencing `references/ai-slop-patterns.md` — name the top 3–4 pitfalls inline (3-column feature grid, gradient backgrounds, icons in colored circles, cookie-cutter rhythm) and note: "See the full list in the AI slop reference. The site-specific Don'ts in section 7 take precedence."

6. **Offer the `ui-ux-pro-max` handoff.** `DESIGN.md` captures aesthetic intent; `ui-ux-pro-max` captures enforceable rules (a11y, palettes, stack guidelines, anti-patterns). **Detect first:** if `ui-ux-pro-max` isn't in the available skills list, skip step 6 silently. Otherwise ask once:
   > "Want me to also generate a `design-system/MASTER.md` with implementation rules via `ui-ux-pro-max`? It complements `DESIGN.md` — vision vs. rules."

   If yes, invoke `ui-ux-pro-max` with the same intent (brand name + product type + descriptive tags from the catalog row). The two files coexist: `DESIGN.md` is the north-star; `MASTER.md` is the rules engine. If no, skip silently — never push twice.

7. **Offer the `shadcn` MCP handoff.** `DESIGN.md` + `MASTER.md` describe *what* the UI looks like; `shadcn` MCP is *how* to install matching components. **Conditional** — call `mcp__shadcn__get_project_registries` first; empty/error result triggers the **non-shadcn advisory** below, then proceeds to step 8 (never push shadcn onto non-shadcn projects). If registries exist, follow the workflow in `references/shadcn-handoff.md` (detect → ask once → seed primitives with `search_items_in_registries` + `get_add_command_for_items` → optional `get_audit_checklist`). **Print install commands; never auto-run.**

   **Non-shadcn framework advisory:** When `get_project_registries` returns empty, check for a detectable framework and offer a one-line hint (never push, just inform):
   - `nuxt.config.*` or `vue` in deps → "Apply DESIGN.md tokens via CSS custom properties or scoped `<style>` in Vue SFCs."
   - `svelte.config.*` → "Apply tokens via Svelte's `style:` directives or a shared `tokens.css`."
   - `pubspec.yaml` (Flutter) → "Map DESIGN.md hex values to `Color(0xFF...)` constants in a theme file."
   - `index.html` only (vanilla) → "Apply tokens as CSS custom properties in a `<style>` block or linked stylesheet."
   - No framework detected → skip silently.

8. **Optionally hint the project CLAUDE.md.** Default (`auto_update_claude_md: false`) is to ASK first. If user consents, append one line matched to what was installed:

   | Files present | Line to append |
   |---|---|
   | Only `DESIGN.md` | `When generating or modifying UI, read DESIGN.md in the project root for visual styling rules.` |
   | `DESIGN.md` + `design-system/MASTER.md` | `When generating UI: read DESIGN.md (brand vision) and design-system/MASTER.md (rules).` |
   | Above + shadcn registries detected | `When generating UI: read DESIGN.md (vision) and design-system/MASTER.md (rules); use the shadcn MCP (search_items_in_registries, get_add_command_for_items) to install matching components.` |

   Never modify any other content in `CLAUDE.md`.

## Quick Reference

| Task | How |
|---|---|
| Install a named brand to cwd | Resolve slug from catalog → `curl -fsSL <raw_url> -o DESIGN.md` |
| List styles in a category | Read `references/catalog.md` → print the category table |
| Show tag vocabulary | Read the "Tag Vocabulary" section at the bottom of `references/catalog.md` |
| Refresh to newer upstream commit | Follow "Re-pinning" procedure in `references/catalog.md` |
| Preview without installing | Construct `preview_url_template` and print it — don't `curl` |
| Generate matching `MASTER.md` (rules) | Step 6 — invoke `ui-ux-pro-max` with brand + tags |
| Find matching shadcn components | Step 7 — `search_items_in_registries` then `get_add_command_for_items` |
| Non-shadcn framework hint | Step 7 — when shadcn detection fails, check for Vue/Svelte/Flutter and advise |
| Offline fallback when curl 404s | Use `research_fallback_path` from `config.json` |

## Dependencies

- `curl` (fail-loud with `-f`) — fetches raw files from GitHub
- `config.json` — pinned commit + URL templates + defaults
- `references/catalog.md` — 58-site index, authoritative slug + tag source
- Upstream: `VoltAgent/awesome-design-md` at the pinned commit in `config.json`
- Optional: `ui-ux-pro-max` skill (step 6 handoff) — generates `design-system/MASTER.md`
- Optional: `shadcn` MCP (step 7 handoff) — `get_project_registries`, `search_items_in_registries`, `get_add_command_for_items`, `get_audit_checklist`

## Related Skills

- `ui-ux-pro-max` — bespoke design authoring (styles, palettes, accessibility). `x-design` routes to *existing* references; `ui-ux-pro-max` helps *author* decisions from scratch.
- `update-research` — maintains the research-library clone (path in `config.json` → `research_fallback_path`); separate from this skill's index-only footprint
- `x-review` — post-install visual review pass

**Three-stage pipeline (steps 4 → 6 → 7):**
1. `x-design` fetches `DESIGN.md` — brand vision (the *what*)
2. `ui-ux-pro-max` generates `design-system/MASTER.md` — enforceable rules (the *constraints*)
3. `shadcn` MCP finds and installs matching components — execution (the *how*)

Each stage is opt-in. Stages 2 and 3 are skipped silently if the user declines or the project can't support them.

## Common Mistakes

| Mistake | Fix |
|---|---|
| Fetching without confirming project root | Always resolve cwd first; ask user if ambiguous |
| Overwriting existing `DESIGN.md` silently | Always warn + confirm |
| Modifying `CLAUDE.md` without consent | Default is ask-first; never auto-append |
| Hardcoding the commit SHA | Always read from `config.json` → `pinned_commit` |
| Bundling upstream files into the skill | Skill is index-only — never copy `design-md/` into the skill dir |
| Guessing slugs | Always check `references/catalog.md` (slugs have irregular forms) |
| Skipping section 9 in the report | The agent prompt examples are the highest-leverage takeaway |
| Showing section 9 without philosophy framing | Always remind to read sections 1, 5, 7 first |
| Omitting stack-aware hint | Detect framework and suggest how to adapt CSS values |
| Omitting AI slop warning | Always append the generation pitfalls advisory |
| Fetching `preview.html` to the project | Only `DESIGN.md` belongs in the project; previews are for eyeballing on github.com |
| Pushing shadcn on non-shadcn projects | Step 7 must call `get_project_registries` first; empty result = non-shadcn advisory |
| Skipping non-shadcn framework advisory | When shadcn detection fails, check for Vue/Svelte/Flutter and offer a one-line token-application hint |
| Auto-running `npx shadcn add ...` commands | Step 7c **prints** install commands; the user runs them |
| Forcing `ui-ux-pro-max` when it isn't installed | Step 6 must check the available skills list before invoking |

## Gotchas

See `gotchas.md` for known failure patterns.
