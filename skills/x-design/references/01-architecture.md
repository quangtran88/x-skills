# Architecture

This is a **static reference repository** — no runtime, no build pipeline, no executable code. The "architecture" is the directory layout and the standardized file shape inside each site folder.

## Repository Layout

```
awesome-design-md/
├── README.md              # Top-level catalog grouped by category
├── CONTRIBUTING.md        # Contribution workflow (issue-first, then PR)
├── LICENSE                # MIT
└── design-md/             # All 58 site folders live here
    ├── claude/
    │   ├── DESIGN.md          # The 9-section design system doc
    │   ├── README.md          # Per-site intro + preview screenshots
    │   ├── preview.html       # Light-mode token catalog
    │   └── preview-dark.html  # Dark-mode token catalog
    ├── cursor/
    │   └── (same 4 files)
    ├── stripe/
    │   └── ...
    └── ... (55 more)
```

Every site folder follows the **exact same 4-file shape**. There are no exceptions, no nested subfolders, no per-site customizations. This uniformity is what makes the dataset usable as drop-in input.

## The Standard Site Folder

| File | Purpose | Size (typical) |
|------|---------|----------------|
| `DESIGN.md` | Source of truth for the design system. The file an AI agent reads. | 200–500 lines |
| `README.md` | Human-facing intro: where the design was extracted from, disclaimer, light/dark screenshot previews of a sample page rendered in the style. | 20–40 lines |
| `preview.html` | Self-contained light-mode HTML page rendering color swatches, type scale, button variants, cards, spacing examples. Inline CSS, no external deps. | 200–600 lines |
| `preview-dark.html` | Same as `preview.html` but for dark surfaces. | 200–600 lines |

## DESIGN.md Internal Structure

Every `DESIGN.md` is a flat markdown document with 9 numbered top-level sections (`## 1.` through `## 9.`). The structure is rigid by design — agents can rely on section ordering when extracting tokens.

```
# {Brand} Inspired Design System
## 1. Visual Theme & Atmosphere   (prose)
## 2. Color Palette & Roles       (subgroups: Primary / Secondary / Surface / Neutrals / Semantic / Gradient)
## 3. Typography Rules            (font families + hierarchy table + principles)
## 4. Component Stylings          (buttons / cards / inputs / nav / image / distinctive components)
## 5. Layout Principles           (spacing / grid / whitespace / radius scale)
## 6. Depth & Elevation           (shadow tiers table + philosophy)
## 7. Do's and Don'ts             (two bulleted lists)
## 8. Responsive Behavior         (breakpoints table + touch / collapse / image)
## 9. Agent Prompt Guide          (quick color reference + example prompts)
```

## Top-Level README as Catalog

The root `README.md` doubles as the index. Sites are grouped into 7 thematic categories with one-line descriptions per entry:

- AI & Machine Learning (12 sites: Claude, Cohere, ElevenLabs, Minimax, Mistral, Ollama, OpenCode, Replicate, Runway, Together, VoltAgent, xAI)
- Developer Tools & Platforms (13: Cursor, Expo, Linear, Lovable, Mintlify, PostHog, Raycast, Resend, Sentry, Supabase, Superhuman, Vercel, Warp, Zapier)
- Infrastructure & Cloud (6: ClickHouse, Composio, HashiCorp, MongoDB, Sanity, Stripe)
- Design & Productivity (10: Airtable, Cal.com, Clay, Figma, Framer, Intercom, Miro, Notion, Pinterest, Webflow)
- Fintech & Crypto (4: Coinbase, Kraken, Revolut, Wise)
- Enterprise & Consumer (7: Airbnb, Apple, IBM, NVIDIA, SpaceX, Spotify, Uber)
- Car Brands (5: BMW, Ferrari, Lamborghini, Renault, Tesla)

## Data Flow (How It's Used)

```
┌─────────────────┐
│  awesome-       │
│  design-md      │   1. Human picks a site that matches desired aesthetic
│  (this repo)    │
└────────┬────────┘
         │ copy
         ▼
┌─────────────────┐
│ user's project  │   2. DESIGN.md dropped at project root
│  /DESIGN.md     │
└────────┬────────┘
         │ read by
         ▼
┌─────────────────┐
│  AI agent       │   3. Agent reads DESIGN.md alongside AGENTS.md
│ (Claude/Cursor/ │      and emits HTML/JSX/Tailwind respecting tokens
│  Stitch/...)    │
└─────────────────┘
```

There is no runtime, no API, no parser. The design is: **markdown is the protocol**.

## What's Deliberately Not Here

- No JSON token files, no Style Dictionary exports
- No Figma plugins or design-token sync tooling
- No CSS variables or framework-specific output
- No tests, CI, or automation
- No package manifest of any kind

The bet is that LLMs reading prose + tables + hex codes outperform any structured-format approach for UI generation, because the agent can pick up the *intent* (philosophy, do's/don'ts, prompt guide) along with the values.
