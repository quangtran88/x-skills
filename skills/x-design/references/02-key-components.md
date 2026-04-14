# Key Components

There is no code in this repo, so "components" means **the building blocks of a `DESIGN.md` file**. Anyone wanting to author a new entry — or build tooling that consumes the format — needs to know how each section is shaped and what conventions hold across all 58 examples.

## 1. The Color Palette Block

Every color is named with a **brand-meaningful semantic label**, not a generic role. Example from `design-md/claude/DESIGN.md`:

```
- **Anthropic Near Black** (`#141413`): The primary text color and dark-theme surface — not pure black but a warm, almost olive-tinted dark...
- **Terracotta Brand** (`#c96442`): The core brand color — a burnt orange-brown used for primary CTA buttons...
- **Parchment** (`#f5f4ed`): The primary page background — a warm cream with a yellow-green tint that feels like aged paper.
```

**Convention:** `**{Semantic Name}** (\`#hex\`): {functional role + emotional/intent description}`

The descriptive sentence after the hex is doing real work — it tells the agent *when* to reach for the color, not just what it is. This is the core difference vs. a JSON token file.

Subgroups always present (even if empty):
- Primary
- Secondary & Accent
- Surface & Background
- Neutrals & Text
- Semantic & Accent
- Gradient System (often "gradient-free" — explicit absence is meaningful)

## 2. The Typography Hierarchy Table

A markdown table with these exact columns:

```
| Role | Font | Size | Weight | Line Height | Letter Spacing | Notes |
```

Roles span Display → Section Heading → Sub-heading (Large/Standard/Small) → Feature Title → Body (Serif/Large/Standard/Small) → Caption → Label → Overline → Micro → Code. Not every site uses every row, but the column shape never varies.

After the table, a `### Principles` subsection captures the *why* — e.g. "single weight for serifs," "relaxed body line-height." This is the prose that lets an agent generalize beyond the explicit tokens.

## 3. Component Stylings — The Variant Pattern

Buttons are documented as **named variants**, each with a fixed bullet shape:

```
**Warm Sand (Secondary)**
- Background: Warm Sand (`#e8e6dc`)
- Text: Charcoal Warm (`#4d4c48`)
- Padding: 0px 12px 0px 8px (asymmetric — icon-first layout)
- Radius: comfortably rounded (8px)
- Shadow: ring-based (`#e8e6dc 0px 0px 0px 0px, #d1cfc5 0px 0px 0px 1px`)
- The workhorse button — warm, unassuming, clearly interactive
```

Same shape for cards, inputs, navigation. The trailing italic/plain sentence after the bullets describes the variant's *role in the system* — critical hint for agents picking which button to use.

There's also an open-ended `### Distinctive Components` subsection for site-specific patterns (e.g. Claude's "Model Comparison Cards" and "Organic Illustrations"). This is the format's escape hatch for things that don't generalize.

## 4. The Depth & Elevation Table

Standardized as a 5-row tier table:

```
| Level | Treatment | Use |
|-------|-----------|-----|
| Flat (Level 0) | No shadow, no border | ... |
| Contained (Level 1) | ... | ... |
| Ring (Level 2) | ... | ... |
| Whisper (Level 3) | ... | ... |
| Inset (Level 4) | ... | ... |
```

Followed by a `**Shadow Philosophy**:` paragraph. This consistent 0–4 tier scheme makes it trivial for an agent to map "give this card more elevation" to a concrete CSS value.

## 5. Do's and Don'ts as Imperative Bullets

```
### Do
- Use Parchment (`#f5f4ed`) as the primary light background — the warm cream tone IS the personality
- ...

### Don't
- Don't use cool blue-grays anywhere — the palette is exclusively warm-toned
- ...
```

These act as **negative prompts** — the agent learns what to avoid, not just what to emit. Each rule names a specific token and a one-line justification.

## 6. The Responsive Breakpoints Table

```
| Name | Width | Key Changes |
```

Five rows: Small Mobile / Mobile / Large Mobile / Tablet / Desktop. Followed by `### Touch Targets`, `### Collapsing Strategy`, `### Image Behavior` subsections.

## 7. Agent Prompt Guide — The Killer Section

This is the part that makes the format actually agent-friendly:

```
### Quick Color Reference
- Brand CTA: "Terracotta Brand (#c96442)"
- Page Background: "Parchment (#f5f4ed)"
- ...

### Example Component Prompts
- "Create a hero section on Parchment (#f5f4ed) with a headline at 64px Anthropic Serif weight 500, line-height 1.10. Use Anthropic Near Black (#141413) text. Add a subtitle in Olive Gray (#5e5d59) at 20px Anthropic Sans with 1.60 line-height. Place a Terracotta Brand (#c96442) CTA button with Ivory text, 12px radius."
```

The example prompts are pre-written, copy-pasteable instructions an agent can use as templates. This is the "telephone game" prevention layer — instead of asking the agent to synthesize prompts from tokens, the file ships with proven phrasings.

## Extension Points (for the format itself)

The format isn't versioned or formally specified, but contribution patterns suggest these are the soft extension hooks:

| Extension | Where |
|-----------|-------|
| New site | Add a 4-file folder under `design-md/<site>/` and link from root README catalog |
| New component variant | Add a `**{Variant Name}**` block under section 4 |
| Site-specific pattern | Add to `### Distinctive Components` under section 4 |
| New shadow tier | Add a row to the section 6 table (rare — most sites stay 0–4) |
| New prompt example | Add a bullet under section 9's `### Example Component Prompts` |

## What Makes a "Good" DESIGN.md (per the corpus)

Looking across all 58 examples, the highest-quality ones share:

1. **Named colors carry brand meaning** — "Parchment," "Terracotta Brand," not "gray-100" or "primary-500"
2. **Philosophy paragraphs precede every token table** — the *why* before the *what*
3. **Anti-patterns in Don'ts reference real failure modes** — "don't introduce saturated colors beyond X"
4. **Distinctive Components capture the unrepeatable details** — the parts that aren't just Tailwind defaults
5. **Prompt examples use concrete phrasings** with actual hex codes inline, not abstract roles
