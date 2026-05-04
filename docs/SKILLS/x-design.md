# x-design — Design System Router

> **Purpose:** Resolves user design intent to a curated `DESIGN.md` file from `VoltAgent/awesome-design-md` and installs it into the current project.

---

## Workflow (8 Steps)

```
1. Resolve target directory
   └─ Confirm cwd is project root (has .git, package.json, etc.)

2. Resolve slug from intent
   ├─ Named brand: direct slug lookup in catalog
   ├─ Descriptive intent: match against intent tags → propose 2-3 candidates
   └─ Listing: print category section from catalog

3. Preview before install
   └─ Show slug + site name + category + preview URL + one-liner. Ask for confirmation.

4. Fetch the DESIGN.md
   └─ curl -fsSL "https://raw.githubusercontent.com/VoltAgent/awesome-design-md/<commit>/design-md/<slug>/DESIGN.md"

5. Report
   ├─ File location + byte count
   ├─ Brand name + one-liner
   ├─ Philosophy-first framing: read sections 1, 5, 7 first
   ├─ First paragraph of section 9 "Agent Prompt Guide"
   ├─ Stack-aware hint (Tailwind, Vue, Svelte, Flutter, vanilla)
   └─ AI slop warning (top 3-4 pitfalls)

6. Offer ui-ux-pro-max handoff
   └─ Generate design-system/MASTER.md with enforceable rules

7. Offer shadcn MCP handoff
   └─ Find and install matching components (conditional on shadcn detection)

8. Optionally hint the project CLAUDE.md
   └─ Append one-line reference to DESIGN.md/MASTER.md (ask first, default false)
```

---

## Three-Stage Pipeline

1. `x-design` fetches `DESIGN.md` — brand vision (the *what*)
2. `ui-ux-pro-max` generates `design-system/MASTER.md` — enforceable rules (the *constraints*)
3. `shadcn` MCP finds and installs matching components — execution (the *how*)

Each stage is opt-in. Stages 2 and 3 are skipped only if the user explicitly declines. When `ui-ux-pro-max` is not installed, the install pointer is surfaced once (do NOT silently no-op). When `shadcn` registries are absent, a non-shadcn framework advisory is offered instead.

---

## Dependencies

- `curl` — fetches raw files from GitHub
- `config.json` — pinned commit + URL templates
- `references/catalog.md` — 58-site index
- Optional: `ui-ux-pro-max` skill (external), `shadcn` MCP
