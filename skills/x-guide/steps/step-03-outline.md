# Step 3: OUTLINE — Build TOC, init GUIDE.md and progress.json

**Progress: Step 3 of 5** — Next: Step 4 WALK

## Goal

Produce a complete table of contents (5–15 parts) ordered for progressive learning, write the `GUIDE.md` skeleton, and initialize `progress.json`. Part bodies stay empty until the user reaches them in Phase 4.

## Rules

- **5 to 15 parts**. Fewer than 5 = the topic is too small for x-guide (offer to inline-explain instead). More than 15 = the topic should be decomposed into sub-guides; show the user a proposed split and ask which sub-guide to start with.
- **ORDER** parts foundations → mechanics → edges. A reader should never need a later concept to understand an earlier one.
- **TEASERS** are 1 line, ≤ 100 characters. They appear in the Roadmap; full bodies are generated later.
- **WRITE FULL TOC FIRST**, then ask whether to adjust before walking.

## Drafting the TOC

Inputs from Phase 2:
- The ingest result (cache file or in-memory content)
- The user's stated goal (if given) — tailor focus to that goal

Steps:
1. Identify foundations: terms, primitives, the system's purpose.
2. Identify mechanics: data flow, control flow, primary operations.
3. Identify edges: error paths, retries, security implications, performance considerations.
4. Order parts so each part stands on those before it.
5. Write a 1-line teaser for each part.

Aim for parts that are roughly equal in conceptual weight. If one is much heavier than the others, split it.

## Writing GUIDE.md

Path: `.x-guide/<slug>/GUIDE.md`. Template:

```markdown
# x-guide: <topic title>

Source: <input.ref>  ·  Started: <YYYY-MM-DD>  ·  Slug: <slug>

## Roadmap

- [ ] Part 1 — <title> · *<teaser>*
- [ ] Part 2 — <title> · *<teaser>*
- [ ] Part 3 — <title> · *<teaser>*
<...>

---

## Part 1: <title>
*Not yet generated. Reach this part to expand.*

## Part 2: <title>
*Not yet generated. Reach this part to expand.*

<...>
```

The Roadmap checkboxes mirror `progress.json.parts[].status` — Phase 4 keeps them in sync on every `next`.

## Writing progress.json

Path: `.x-guide/<slug>/progress.json`. Initial value:

```json
{
  "slug": "<slug>",
  "source": {
    "type": "<input.type>",
    "ref": "<input.ref>",
    "ingest_method": "<claude-direct|x-gemini|x-research>",
    "ingested_at": "<ISO timestamp>"
  },
  "parts": [
    {"n": 1, "title": "<title>", "status": "current", "level_used": null, "completed_at": null},
    {"n": 2, "title": "<title>", "status": "pending", "level_used": null, "completed_at": null}
  ],
  "current": 1,
  "started_at": "<ISO timestamp>",
  "completed_at": null,
  "level_default": "mid",
  "version": 1
}
```

Schema details: `../references/progress-schema.md`.

## Confirmation Gate

After writing both files, show the user the Roadmap and ask:

```
Outline ready (<M> parts). Start walking from Part 1, or adjust the outline first?

  [g] go (start Part 1)
  [a] adjust (rename / reorder / merge / split parts)
  [r] regenerate (try a different angle)
```

HALT until the user picks.

- On `g` → proceed to Step 4 WALK.
- On `a` → enter an adjust loop: take the user's edit instructions, rewrite the relevant TOC entries, sync `progress.json`, re-prompt.
- On `r` → discard current TOC, re-draft using the same ingest cache, re-prompt.

## Output of Phase 3

`.x-guide/<slug>/GUIDE.md` and `.x-guide/<slug>/progress.json` both exist and are consistent. `parts[0].status == "current"`.
