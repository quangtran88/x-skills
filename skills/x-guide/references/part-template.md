# Per-Part Render Template — Reference

The shape every Phase 4 part follows. Sections marked `(optional)` may be omitted when they would be forced or empty; do NOT include an empty header.

## Template

```markdown
## Part N: <title>

> 📍 Part N of M · Level: <mid|deeper|simpler>

### What
<2–4 sentences. Plain language. Concrete. No jargon dump. The reader should be able to paraphrase what this part is about after reading these sentences.>

### Why it matters
<1–2 sentences tying back to the user's stated goal or the broader system. Answers "why am I learning this?".>

### How it works
<step-by-step explanation, annotated code excerpt, or mermaid diagram. Pick the form best suited to this specific part. For code, quote real lines from the source — do NOT invent code. For diagrams, use mermaid `flowchart` / `sequenceDiagram` / `classDiagram`.>

### Mental model (optional)
<1 metaphor or analogy. ONE sentence. If the analogy would be forced, distract, or weaken the technical content, OMIT this section. Empty mental models are worse than none.>

### Try it (optional)
<1 small exercise. Forms that work:
- "Predict what happens if X" (then user types prediction; Claude grades)
- "Find Y in the source — which file/line?"
- "What would break if we removed Z?"
Skip if no useful exercise exists for this part.>
```

## Level Variations

The same part rendered at different levels emphasizes different things:

| Level | What grows | What shrinks |
|---|---|---|
| `mid` | balanced What/Why/How | n/a (default) |
| `deeper` | How (internals, edge cases, references to other parts of source); add a "Behind the scenes" subsection | Mental model, Try-it |
| `simpler` | What, Why, Mental model (more analogy); shorten How to the headline beats | Internals, edge cases |

When re-rendering at a different level, REPLACE the previous body in `GUIDE.md` — do NOT append a second copy.

## Diagrams

- Mermaid is the default. It renders in most markdown viewers and degrades to readable code blocks elsewhere.
- ASCII art only when the relationship is too small for mermaid to be worth it (e.g., 3 boxes in a line).
- Never embed images / SVGs / external assets. The guide must be readable without network.

## Length Budget

Aim for 800–2000 words per part body. If a part would exceed ~2500 words, split into sub-parts (`Na`, `Nb`) per Step 4's oversized-part rule.
