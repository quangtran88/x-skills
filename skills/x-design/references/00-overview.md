# awesome-design-md — Overview

**Project:** Awesome DESIGN.md
**One-liner:** Curated collection of `DESIGN.md` files extracted from real developer-focused websites — drop-in design systems for AI UI generation.
**URL:** https://github.com/VoltAgent/awesome-design-md
**Maintainer:** [VoltAgent](https://github.com/VoltAgent)
**Version:** No tagged releases — rolling collection. Snapshot at commit `80bbbc2` (2026-04-06).
**License:** MIT (Copyright 2026 VoltAgent)

## What It Is

`DESIGN.md` is a plain-text design-system document format introduced by [Google Stitch](https://stitch.withgoogle.com/docs/design-md/overview/). It's the visual counterpart to `AGENTS.md`:

| File | Who reads it | What it defines |
|------|-------------|-----------------|
| `AGENTS.md` | Coding agents | How to build the project |
| `DESIGN.md` | Design agents | How the project should look and feel |

This repo provides 58 ready-to-use `DESIGN.md` files reverse-engineered from public websites. The pitch: copy a `DESIGN.md` into your project, tell your AI agent "build a page that looks like this," and get pixel-aligned UI without Figma exports, JSON tokens, or special tooling. Markdown is what LLMs read best.

## Tech Stack

**Pure documentation repo — no runtime code.** Every site folder is static markdown + HTML:

- Markdown (CommonMark) — the `DESIGN.md` files themselves
- Vanilla HTML/CSS — `preview.html` and `preview-dark.html` token catalogs
- No build step, no package.json, no dependencies

## Key Features

- **58 sites covered** across 6 categories: AI/ML, Developer Tools, Infrastructure/Cloud, Design/Productivity, Fintech/Crypto, Enterprise/Consumer, plus Car Brands
- **Standardized 9-section format** for every site (extends Stitch DESIGN.md spec)
- **Visual previews per site**: light + dark HTML token catalogs showing colors, type scale, buttons, cards
- **Drop-in usage**: no install, no parser, no schema — just copy the file
- **Agent prompt guides** baked into every file (ready-to-paste prompts for the styled elements)
- **Per-site README** with screenshot previews of a sample landing page rendered in that style

## The 9 DESIGN.md Sections

| # | Section | Captures |
|---|---------|----------|
| 1 | Visual Theme & Atmosphere | Mood, density, design philosophy |
| 2 | Color Palette & Roles | Semantic name + hex + functional role |
| 3 | Typography Rules | Font families, full hierarchy table |
| 4 | Component Stylings | Buttons, cards, inputs, navigation with states |
| 5 | Layout Principles | Spacing scale, grid, whitespace philosophy |
| 6 | Depth & Elevation | Shadow system, surface hierarchy |
| 7 | Do's and Don'ts | Design guardrails and anti-patterns |
| 8 | Responsive Behavior | Breakpoints, touch targets, collapsing strategy |
| 9 | Agent Prompt Guide | Quick color reference, ready-to-use prompts |

## Why This Matters as Research

For anyone building AI design/UI generation tooling, this repo is a **reference dataset** of what a high-quality, LLM-readable design system looks like in practice. The format is the contribution — the curated examples are the proof it scales across very different brand identities (Apple, SpaceX, Stripe, Notion, Ferrari, etc.).
