# Notable Patterns

This repo's value isn't in any code — it's in the **format choices** and the **dataset shape**. These are the patterns worth borrowing for any similar AI-readable reference library.

## 1. Markdown as the Protocol (vs. JSON tokens)

**Pattern:** Ship design systems as prose + tables + hex codes, not as Style Dictionary JSON or Figma exports.

**Why it works:**
- LLMs read markdown natively — no parser, no schema validation, no token transformer
- Prose carries *intent* (philosophy, do's, don'ts) that JSON tokens cannot
- Drop-in usability: `cp DESIGN.md ~/myproject/` is the entire integration step
- Diff-friendly in PR review — humans can spot a wrong hex by skimming

**Tradeoff:** No machine validation, no automated sync to Figma, no type-safe consumption. The bet is that for *generation* (what AI agents do), structured tokens were always the wrong abstraction.

**Borrow when:** Building any reference library where the consumer is an LLM agent rather than a runtime/build system.

## 2. The "AGENTS.md / DESIGN.md" Sibling Convention

**Pattern:** Two parallel files at project root with the same naming convention but different audiences:

| File | Audience | Domain |
|------|----------|--------|
| `AGENTS.md` | Coding agents | How to build |
| `DESIGN.md` | Design agents | How it should look |

**Why it works:** Establishes a discoverability convention. Any agent dropped into a project knows exactly which file to read for which question. No project-specific paths to memorize.

**Borrow when:** Defining a new agent-readable artifact. Pick a name that mirrors `AGENTS.md`'s shape (`*.md`, ALL-CAPS, root-level) — it inherits the convention.

## 3. Rigid Section Numbering as an Implicit Schema

**Pattern:** Every `DESIGN.md` has the *exact same 9 numbered sections in the same order*. No optional sections, no per-site reordering.

**Why it works:**
- Agents can rely on positional extraction ("section 2 is always colors")
- Contributors have a checklist — missing a section is immediately obvious in PR
- The numbering itself acts as a soft schema without needing JSON Schema or YAML frontmatter
- Works as a *cognitive forcing function* on contributors: "what's our depth & elevation story?" can't be skipped

**Borrow when:** Creating any structured-but-prose document type. Numbered sections > frontmatter for human contributors.

## 4. Named Tokens with Brand-Meaningful Labels

**Pattern:** Colors are `**Parchment** (#f5f4ed)` and `**Terracotta Brand** (#c96442)`, never `gray-100` or `primary-500`.

**Why it works:**
- The name primes the agent's word choice in generated copy ("a parchment-toned hero" vs "a gray-100 hero")
- Brand identity transfers through the name itself, not just the value
- When agents reason about color choice, semantic names enable analogical thinking ("we need something parchment-like")

**Borrow when:** Naming anything an LLM will reason about. Generic role names are dead weight; evocative names are free signal.

## 5. The "Quick Reference + Example Prompts" Section

**Pattern:** Section 9 of every file ends with copy-pasteable prompt templates that already inline the right tokens.

```
"Create a hero section on Parchment (#f5f4ed) with a headline at 64px Anthropic Serif weight 500..."
```

**Why it works:** Agents are extremely good at following examples and worse at synthesis. Pre-written prompts short-circuit the synthesis step entirely. The contributor does the synthesis once when authoring the file; every downstream user benefits.

**Borrow when:** Building any agent-facing reference. Always include "here's how you'd use this in a prompt" examples — don't make the agent figure it out from first principles.

## 6. Anti-Patterns as First-Class Content (Don'ts Section)

**Pattern:** Section 7 always has both `### Do` and `### Don't` lists, where the Don'ts call out specific failure modes:

```
- Don't use cool blue-grays anywhere — the palette is exclusively warm-toned
- Don't use bold (700+) weight on Anthropic Serif — weight 500 is the ceiling for serifs
```

**Why it works:** LLMs will confidently produce wrong-but-plausible output unless told what to avoid. Negative constraints are higher signal-per-token than positive guidance for narrowing the output space.

**Borrow when:** Any prompt/skill design. Explicit "don't" rules outperform implicit "do" rules for LLM steering.

## 7. Philosophy Paragraphs Before Every Token Block

**Pattern:** Every section opens with prose explaining the *intent* before listing tokens. Section 2 (Colors) opens with "the entire experience is built on a parchment-toned canvas... where most AI product pages lean into cold, futuristic aesthetics, Claude's design radiates human warmth."

**Why it works:** The intent paragraph is what allows the agent to extrapolate. When a designer asks for "a button that's not in the spec," the agent has the philosophy to fall back on. Without it, the agent has only the literal tokens and breaks down at the first edge case.

**Borrow when:** Any reference document where the consumer might need to *generalize beyond* the explicit examples. Always lead with intent.

## 8. Per-Site Visual Previews as Validation Artifacts

**Pattern:** Every site folder ships `preview.html` and `preview-dark.html` — self-contained HTML pages that render the tokens visually using inline CSS.

**Why it works:**
- Maintainers can eyeball the file in a browser to spot wrong hex codes
- Contributors get instant visual feedback during PR
- Acts as **executable documentation** — if `preview.html` looks wrong, the `DESIGN.md` is wrong
- No build step needed (open the file directly)

**Borrow when:** Any structured-data repo where humans need to validate values. A self-contained visual preview is cheaper than tests and catches different bugs.

## 9. Light + Dark in Lockstep

**Pattern:** Every preview ships in `preview.html` (light) AND `preview-dark.html` (dark). Both surfaces are documented in section 2's color palette as first-class.

**Why it works:** Forces contributors to think about both modes from day one. Many real design systems treat dark mode as an afterthought; this format makes that impossible by structure.

**Borrow when:** Documenting any visual system where dark mode matters. The discipline comes from making both modes equally weighted in the artifact, not from a tickbox in a checklist.

## 10. The Curated List as a "Tasting Menu"

**Pattern:** The root README groups 58 sites into 7 thematic categories with one-line descriptions per site:

> `**Claude**` - Anthropic's AI assistant. Warm terracotta accent, clean editorial layout

**Why it works:** Lets users (human or agent) browse by *aesthetic intent* rather than by name. "I want something warm and editorial" → Claude. "I want stark futuristic" → SpaceX. The one-liner is doing classification work that would otherwise need a tagging system.

**Borrow when:** Cataloging any large reference collection. One memorable adjective + one identifying noun per entry is more useful than hierarchical taxonomies.

## What's Worth Stealing for Other Projects

If you're building **any** AI-readable reference library — skills, agents, prompts, design systems, API references — these are the highest-leverage takeaways:

1. **Markdown over JSON** when the consumer is an LLM
2. **Rigid numbered sections** over frontmatter or YAML schemas
3. **Evocative semantic names** over generic role names
4. **Copy-pasteable example prompts** in every reference doc
5. **Don'ts as first-class content**, not just Do's
6. **Philosophy paragraphs** before every token block
7. **Self-contained visual previews** as executable docs
8. **One-liner catalogs** with adjective+noun descriptions for browsing
