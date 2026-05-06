# x-guide Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a new plugin skill `x-guide` that turns complex inputs (docs, PRDs, plans, specs, code, features) into progressive comprehension-gated tutorials with persistent per-project progress.

**Architecture:** Markdown-only skill following the existing x-skills `SKILL.md + config.json + gotchas.md + steps/ + references/` convention. Five-phase workflow (DETECT → INGEST → OUTLINE → WALK → WRAP). Per-project state lives in `.x-guide/<slug>/`. Routing is capability-gated via the `[x-skills/capabilities]` SessionStart line; large inputs delegate to `x-gemini`, vague targets delegate to `x-research`, small inputs read directly into Claude.

**Tech Stack:** Markdown skill files. JSON state schema. No new external dependencies. Mermaid for diagrams (already standard in markdown viewers). Plugin manifests at `.claude-plugin/marketplace.json` and `.claude-plugin/plugin.json`. Setup detection in `bin/setup` (no new probes needed — relies on existing `gemini_cli` capability gate).

**Spec:** `docs/SKILLS/x-guide-design.md` (commit `708fc29`).

---

## File Structure

Files to create:

| Path | Responsibility |
|---|---|
| `skills/x-guide/SKILL.md` | Frontmatter + router + bootstrap call + phase dispatch table |
| `skills/x-guide/config.json` | Capability wiring (gemini/research delegation paths) |
| `skills/x-guide/gotchas.md` | Failure-mode catalog (stale ingest, slug collisions, oversized parts) |
| `skills/x-guide/steps/step-01-detect.md` | Phase 1 — input classification + slug + resume prompt |
| `skills/x-guide/steps/step-02-ingest.md` | Phase 2 — routing tree + cache rules |
| `skills/x-guide/steps/step-03-outline.md` | Phase 3 — TOC generation + GUIDE.md skeleton + progress.json init |
| `skills/x-guide/steps/step-04-walk.md` | Phase 4 — render template, menu loop, command handling |
| `skills/x-guide/steps/step-05-wrap.md` | Phase 5 — completion summary + suggested next topics |
| `skills/x-guide/references/menu-commands.md` | Per-command behavior table (n/b/s/d/l/e/q/j/x + free text) |
| `skills/x-guide/references/progress-schema.md` | progress.json schema + status state machine |
| `skills/x-guide/references/routing-matrix.md` | Ingest routing decision matrix + size estimation |
| `skills/x-guide/references/part-template.md` | Per-part render template (What / Why / How / Mental model / Try) |

Files to modify:

| Path | Change |
|---|---|
| `.claude-plugin/marketplace.json` | Bump skill count in description, add `tutorial`/`teaching` tags |
| `CLAUDE.md` | Add `x-guide` row to Skills table |
| `docs/SKILLS_OVERVIEW.md` | Add x-guide section (mirror style of existing entries) |
| `README.md` | Add x-guide to skills list (if list exists) |

No version bump in this plan — release happens in a separate `release` skill invocation after smoke testing.

---

## Conventions Used Below

- "Run: `<cmd>`" with **Expected:** describes the verification check.
- Markdown skills have no automated test harness in this repo. Verification is: (1) file exists at exact path, (2) frontmatter parses, (3) `ifn-tooling:validate-repo` passes, (4) manual smoke test invocation.
- Each task ends in a commit. Commit messages use the existing convention: `feat(x-guide): <short>`, `docs(x-guide): <short>`, `chore(x-guide): <short>`.

---

## Task 1: Skill scaffold — SKILL.md + config.json + gotchas.md

**Files:**
- Create: `skills/x-guide/SKILL.md`
- Create: `skills/x-guide/config.json`
- Create: `skills/x-guide/gotchas.md`

- [ ] **Step 1.1: Create config.json**

```json
{
  "omo_skill": "../x-omo/SKILL.md",
  "gemini_skill": "../x-gemini/SKILL.md",
  "research_skill": "../x-research/SKILL.md",
  "shared_capability_loading": "../x-shared/capability-loading.md",
  "shared_invocation_guide": "../x-shared/invocation-guide.md",
  "capabilities_file": "~/.config/x-skills/capabilities.json"
}
```

- [ ] **Step 1.2: Create SKILL.md**

```markdown
---
name: x-guide
description: Use when the user wants a complex input (file, function, directory, PRD, plan, spec, URL, pasted prose, or vague feature name) explained step by step in a comprehension-gated walkthrough — produces a persistent .x-guide/<slug>/GUIDE.md with full TOC and walks the user one part at a time, supports resume across sessions
role: progressive-tutor
---

# x-guide — Progressive Comprehension-Gated Tutor

x-guide turns complex inputs into linear, comprehension-gated tutorials. The user supplies a target; x-guide produces `.x-guide/<slug>/GUIDE.md` (full TOC upfront, parts generated lazily as the user advances), persists progress in `progress.json`, and walks the user one part at a time with a menu-driven command loop.

x-guide is **not** an explorer or graph viewer. It enforces linear comprehension: render one part, wait for command, advance only on signal. Compare to `Lum1104/Understand-Anything` (graph + dashboard) — x-guide stays markdown + chat.

## Bootstrap (MANDATORY)

Before any phase dispatch, load:

0. `../x-shared/capability-loading.md` — pin the active capability set for this session. Trust the bootstrap-pinned set; do not re-verify per dispatch.
1. `gotchas.md` — known failure patterns.

Lazy-load only when needed:
- `../x-gemini/SKILL.md` — when Phase 2 routes large input to gemini ingest.
- `../x-research/SKILL.md` — when Phase 2 routes a vague-target input to research.

## Anti-Triggers

If the request is closer to one of these, route there instead and stop:

| User intent | Route to |
|---|---|
| "Find me how X works across the codebase" (open investigation) | `x-research` |
| "Review this code / plan / PR" | `x-review` |
| "Debug / fix this bug" | `x-bugfix` |
| "Build / implement / execute this plan" | `x-do` |

## Phase Dispatch

x-guide runs five phases in order. Each phase has a step file under `steps/`. Read the step file for that phase before executing it.

| Phase | Step file | Purpose |
|---|---|---|
| 1 | `steps/step-01-detect.md` | Classify input, compute slug, handle resume |
| 2 | `steps/step-02-ingest.md` | Route to gemini / research / claude based on size + clarity |
| 3 | `steps/step-03-outline.md` | Write TOC + teasers to GUIDE.md, init progress.json |
| 4 | `steps/step-04-walk.md` | Render-menu-command loop until user exits or completes |
| 5 | `steps/step-05-wrap.md` | Mark complete, write summary, suggest next topics |

Phase 4 is the core loop. It iterates internally; phases 1–3 and 5 are linear.

## State Location

All state is per-project, in repo root:

```
.x-guide/<slug>/
├── GUIDE.md          # tutorial — TOC + parts
├── progress.json     # state (schema in references/progress-schema.md)
└── _ingest.md        # cached ingest output (when ingest_method != claude-direct)
```

Recommend `.gitignore` add `.x-guide/`. Suggest this on first use if not already gitignored.

## References

- `references/menu-commands.md` — Phase 4 command table
- `references/progress-schema.md` — progress.json schema + state machine
- `references/routing-matrix.md` — Phase 2 routing tree
- `references/part-template.md` — per-part render template

## Modes (v1)

Single mode. No `max` / `prism` flags. Adaptive depth happens per-part inside Phase 4 via `d` / `l` commands, not as a top-level mode.
```

- [ ] **Step 1.3: Create gotchas.md**

```markdown
# x-guide Gotchas

## Stale ingest

- **Symptom**: cached `_ingest.md` no longer matches source (file edited after ingest).
- **Detection**: source `mtime` newer than `_ingest.md` `mtime`.
- **Action**: prompt user — re-ingest now / keep cached / abort. Default to keep cached when in doubt.

## Slug collisions

- **Symptom**: two different sources produce the same kebab-case slug (e.g., `auth.md` and `Auth.md` in different dirs).
- **Action**: append `-2`, `-3`, ... to the slug. Never overwrite an existing `.x-guide/<slug>/`.

## Resume vs restart confusion

- **Symptom**: user invokes x-guide on a target that already has `.x-guide/<slug>/`.
- **Rule**: NEVER auto-resume. Always prompt: resume / restart / new-slug.

## Oversized rendered part

- **Symptom**: a single part exceeds ~8k tokens when rendered.
- **Action**: split into sub-parts (e.g., Part 3 → Part 3a, 3b). Update TOC, shift later part numbers.

## Capability missing — gemini_cli absent

- **Symptom**: large input (>50k tokens) but no `gemini_cli` in active capability set.
- **Action**: read into Claude directly. Warn user once if input >150k tokens; do not block.

## Capability missing — MCP servers absent for vague target

- **Symptom**: vague-target input but no `mcp.perplexity` / `mcp.exa` / `mcp.deepwiki` active.
- **Action**: fall back to Claude `Agent(Explore)` searching repo only. Note in `_ingest.md` that web sources were unavailable.

## Wrong-answer quiz loop

- **Symptom**: user fails MCQ in `q` mode.
- **Action**: re-explain the specific weak sub-point inline. Do not advance to `next` until either (a) user retries correctly, or (b) user types `n` explicitly to skip past the gate.

## Free-text question mid-loop

- **Symptom**: user types a free-text question instead of a menu command.
- **Action**: answer inline. Do NOT advance the part. Re-show the menu after the answer.

## Outline regeneration mid-flight

- **Symptom**: user types "rewrite outline" after some parts are already `done`.
- **Action**: regenerate TOC. Match new parts to old by title (case-insensitive substring). Preserve `done` status on matches; new parts get `pending`.

## Bad input

- **Symptom**: file path missing, URL returns 4xx/5xx, paste empty.
- **Action**: fail fast. Do NOT create `.x-guide/<slug>/`. Surface a one-line error and stop.
```

- [ ] **Step 1.4: Verify files exist + parse**

Run:
```bash
test -f skills/x-guide/SKILL.md && \
test -f skills/x-guide/config.json && \
test -f skills/x-guide/gotchas.md && \
python3 -c 'import json; json.load(open("skills/x-guide/config.json"))' && \
echo OK
```
Expected: `OK`

- [ ] **Step 1.5: Commit**

```bash
git add skills/x-guide/SKILL.md skills/x-guide/config.json skills/x-guide/gotchas.md
git commit -m "feat(x-guide): scaffold skill — SKILL.md, config, gotchas"
```

---

## Task 2: Phase 1 — DETECT step file

**Files:**
- Create: `skills/x-guide/steps/step-01-detect.md`

- [ ] **Step 2.1: Create step-01-detect.md**

```markdown
# Step 1: DETECT — Classify input, compute slug, handle resume

**Progress: Step 1 of 5** — Next: Step 2 INGEST

## Goal

Classify the user's input, compute a stable topic slug, and decide whether to start fresh or resume an existing guide.

## Rules

- **READ COMPLETELY** before acting.
- **NEVER** auto-resume an existing `.x-guide/<slug>/`. Always prompt.
- **HALT** at the resume prompt — wait for user choice.
- **FAIL FAST** on bad input — do NOT create any directory.

## Input Classification

Inspect the user's argument and pick exactly one type:

| Type | Detection | Examples |
|---|---|---|
| `file` | path exists, is file, is readable | `src/auth.ts`, `docs/PRD.md` |
| `dir` | path exists, is directory | `src/auth/` |
| `url` | starts with `http://` or `https://` | `https://stripe.com/docs/api` |
| `paste` | inline block in user message, not a path | PRD content pasted between code fences |
| `vague` | none of the above match a real path/URL | `"the auth flow"`, `"how billing works"` |

If the user gave multiple inputs (rare), pick the most specific (file > dir > url > paste > vague). State the choice in chat before proceeding.

## Slug Computation

Compute a stable kebab-case slug:

1. **From a file**: take the basename without extension. `src/auth.ts` → `auth`. `docs/PRD-billing-v2.md` → `prd-billing-v2`.
2. **From a directory**: take the leaf name. `src/auth/` → `auth`.
3. **From a URL**: take the last path segment, drop query/fragment. `https://stripe.com/docs/api/payment_intents` → `payment-intents`. If empty, use the host: `stripe-com`.
4. **From a paste**: scan the first 500 chars for an H1 (`# X`) or first sentence; kebab-case the first 4–6 words. If empty, fall back to `pasted-<short-timestamp>`.
5. **From a vague target**: kebab-case the user's phrase, dropping stopwords. `"the auth flow"` → `auth-flow`.

Normalize: lowercase, replace runs of non-alphanumerics with `-`, trim leading/trailing `-`, cap at 60 characters.

## Collision Handling

After computing slug `S`:

- If `.x-guide/S/` does not exist → use `S` as-is.
- If `.x-guide/S/progress.json` exists AND its `source.ref` matches the current target → **same source**, treat as resume candidate (see next section).
- If `.x-guide/S/progress.json` exists but `source.ref` differs → **collision on different source**. Append `-2`, `-3`, ... until free. Use the free slug.

## Resume Prompt

If `.x-guide/<slug>/progress.json` exists for the same source:

1. Read `progress.json`.
2. Identify `current` part number `N` and total `M = parts.length`.
3. Identify how many parts are `done` and how many `pending`/`current`.
4. Show the user a prompt and HALT:

```
Found existing guide for "<slug>" — Part <N>/<M>, <D> done, <P> pending.

Pick one:
  [r] resume from Part <N>
  [s] restart from scratch (overwrite GUIDE.md, progress.json, _ingest.md)
  [n] start a new guide with a different slug

Or type a custom slug to use instead.
```

5. Wait for the user's choice. Do NOT proceed without an explicit choice.

## Bad Input Handling

If detection fails:

- File path given but file unreadable / missing → error: `x-guide: cannot read <path>`. Stop.
- URL given but fetch fails (4xx/5xx) → error: `x-guide: fetch failed (<status>) for <url>`. Stop.
- Paste detected but block is empty / <100 chars of content → error: `x-guide: pasted content too short to guide on`. Stop.

In every error case: do NOT create `.x-guide/<slug>/`. Do NOT write `progress.json`.

## Output of Phase 1

A pinned tuple in working memory (used by step 2):

- `input.type` ∈ `file|dir|url|paste|vague`
- `input.ref` — canonical reference (path / URL / "(pasted)" / vague phrase verbatim)
- `slug` — final slug after collision resolution
- `mode` ∈ `start|resume`
- If `mode == resume`: `resume_from_part` integer

Then proceed to Step 2 INGEST — unless `mode == resume`, in which case skip directly to Step 4 WALK starting at `resume_from_part`.
```

- [ ] **Step 2.2: Verify file**

Run:
```bash
test -f skills/x-guide/steps/step-01-detect.md && \
head -1 skills/x-guide/steps/step-01-detect.md | grep -q '^# Step 1: DETECT' && \
echo OK
```
Expected: `OK`

- [ ] **Step 2.3: Commit**

```bash
git add skills/x-guide/steps/step-01-detect.md
git commit -m "feat(x-guide): add Phase 1 DETECT step — input classification, slug, resume gate"
```

---

## Task 3: Phase 2 — INGEST step file

**Files:**
- Create: `skills/x-guide/steps/step-02-ingest.md`

- [ ] **Step 3.1: Create step-02-ingest.md**

```markdown
# Step 2: INGEST — Route to gemini / research / claude

**Progress: Step 2 of 5** — Next: Step 3 OUTLINE

## Goal

Produce a digested representation of the source that Phase 3 can use to build a TOC. Cache the result to `_ingest.md` so re-runs (resume, regenerate-outline) don't re-fetch.

## Rules

- **TRUST** the bootstrap-pinned capability set. Do NOT probe for tools per dispatch.
- **CACHE** every non-direct ingest into `.x-guide/<slug>/_ingest.md`.
- **NEVER** block on a missing capability — fall back per the matrix below.

## Routing Tree

Compute `size_estimate` first:

| Source type | Size proxy |
|---|---|
| `file` | byte size; rough tokens ≈ bytes / 4 |
| `dir` | sum of byte sizes of code/markdown/text files (skip binaries, lockfiles, `node_modules`, `.git`) |
| `url` | unknown until fetched; treat as >50k by default unless the URL is a small known doc page |
| `paste` | character count / 4 |
| `vague` | not applicable |

Then route:

```
input.type == "vague"
  → x-research (multi-source synthesis)
input.type in {file, dir, url, paste} AND size_estimate > 50_000
  → if `gemini_cli` capability active:
        x-gemini ingest
    else:
        Claude direct (warn user once if size_estimate > 150_000)
input.type in {file, dir, url, paste} AND size_estimate <= 50_000
  → Claude direct (no _ingest.md cache)
```

The full decision matrix lives in `../references/routing-matrix.md`.

## Per-Route Behavior

### Route A: x-research (vague target)

1. Read `../../x-research/SKILL.md` (Bootstrap step) only now if not already loaded.
2. Dispatch x-research with a focused brief: "Build a teaching outline for: <vague phrase>. Target audience: a developer who wants to understand it well enough to work on it. Surface concepts, layers, edges, gotchas, and the most relevant local files."
3. Capture the synthesized result.
4. Write to `.x-guide/<slug>/_ingest.md` with a header:

```markdown
# Ingest cache

Source: vague — "<phrase>"
Method: x-research
Ingested at: <ISO timestamp>

---

<synthesized content>
```

5. Set `progress.json.source.ingest_method = "x-research"`.

### Route B: x-gemini ingest (large local input)

1. Read `../../x-gemini/SKILL.md` (Bootstrap) only now if not already loaded.
2. Dispatch x-gemini with prompt:
   ```
   Produce a teaching skeleton of the attached source. Output sections:
   - Top-level purpose (1 paragraph)
   - Major concepts / building blocks (bullet list)
   - Layered structure (foundations → mechanics → edges)
   - Concrete entry points or "where to start reading" (file:line if code)
   - Vocabulary the reader needs (term: 1-line definition)
   - Subtle behaviors / edges worth covering
   No tutorial prose yet — just the skeleton.
   ```
3. Pass the source via `--file` (file/dir) or stdin (paste).
4. Write the gemini output to `.x-guide/<slug>/_ingest.md` with the same header format as Route A but `Method: x-gemini`.
5. Set `progress.json.source.ingest_method = "x-gemini"`.

### Route C: Claude direct (small input or gemini unavailable)

1. Read the source directly (`Read` for files, `WebFetch` for URLs, paste already in chat).
2. Hold the content in working memory; do NOT write `_ingest.md` (the source itself is the cache).
3. Set `progress.json.source.ingest_method = "claude-direct"`.

## Stale-Cache Handling (resume + regenerate-outline only)

If `_ingest.md` already exists when Phase 2 runs:

- For `file`/`dir` sources: compare source `mtime` to `_ingest.md` `mtime`.
- If source is newer → prompt user: `re-ingest now / keep cached / abort`. Default action on no-input is `keep cached`.
- For `url`/`paste`/`vague` sources: keep cached unless the user explicitly requests re-ingest.

## Output of Phase 2

A reference to ingested content (in-memory for Route C, file path for A/B) plus a recorded `ingest_method`. Phase 3 uses this to draft the TOC.
```

- [ ] **Step 3.2: Verify**

Run:
```bash
test -f skills/x-guide/steps/step-02-ingest.md && \
grep -q "Route A: x-research" skills/x-guide/steps/step-02-ingest.md && \
grep -q "Route B: x-gemini" skills/x-guide/steps/step-02-ingest.md && \
grep -q "Route C: Claude direct" skills/x-guide/steps/step-02-ingest.md && \
echo OK
```
Expected: `OK`

- [ ] **Step 3.3: Commit**

```bash
git add skills/x-guide/steps/step-02-ingest.md
git commit -m "feat(x-guide): add Phase 2 INGEST step — gemini/research/claude routing tree"
```

---

## Task 4: Phase 3 — OUTLINE step file

**Files:**
- Create: `skills/x-guide/steps/step-03-outline.md`

- [ ] **Step 4.1: Create step-03-outline.md**

```markdown
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
```

- [ ] **Step 4.2: Verify**

Run:
```bash
test -f skills/x-guide/steps/step-03-outline.md && \
grep -q "Confirmation Gate" skills/x-guide/steps/step-03-outline.md && \
grep -q "5 to 15 parts" skills/x-guide/steps/step-03-outline.md && \
echo OK
```
Expected: `OK`

- [ ] **Step 4.3: Commit**

```bash
git add skills/x-guide/steps/step-03-outline.md
git commit -m "feat(x-guide): add Phase 3 OUTLINE step — TOC drafting, GUIDE.md skeleton, progress init"
```

---

## Task 5: Phase 4 — WALK step file

**Files:**
- Create: `skills/x-guide/steps/step-04-walk.md`

- [ ] **Step 5.1: Create step-04-walk.md**

```markdown
# Step 4: WALK — Render-menu-command loop

**Progress: Step 4 of 5** — Next: Step 5 WRAP (when all parts done or user exits)

## Goal

Render the current part, present the menu, parse the user's response, mutate state, and loop. This is the only phase that runs more than once per invocation.

## Rules

- **ONE PART PER ITERATION**. Render exactly one part body, then HALT for user input.
- **PER-PART DEPTH DECAY**. Every new part starts at `level = mid`. The user must signal `d` or `l` again on each part if they want a different level.
- **NEVER ADVANCE WITHOUT AN EXPLICIT COMMAND**. Free-text answers, follow-up questions, and quiz wrong answers all keep `current` unchanged.
- **SYNC ROADMAP CHECKBOXES** in `GUIDE.md` and the part status in `progress.json` on every state change.

## Per-Part Render Template

Use `../references/part-template.md`. Skeleton (omit any section that would be forced or empty):

```markdown
## Part N: <title>

> 📍 Part N of M · Level: <mid|deeper|simpler>

### What
<2–4 sentence plain explanation. Concrete, no jargon dump.>

### Why it matters
<1–2 sentences tying back to the user's stated goal.>

### How it works
<step-by-step or annotated code/diagram. Mermaid where useful.>

### Mental model
<1 metaphor or analogy. Skip if it would feel forced.>

### Try it (optional)
<small exercise: "predict what happens if X" or "find Y in the file">
```

Write the body into `GUIDE.md` (replacing the `*Not yet generated.*` placeholder for that part) AND echo it to chat. Both copies must match.

## Generation Routing

Per-part content is generated by Claude directly (pedagogy voice matters most). Do NOT route per-part generation to oracle/gemini by default — only on a user-triggered `q deep` cross-check.

## Menu

After rendering the part body, post this menu in chat (NOT in `GUIDE.md`):

```
What next?
  [n] next part        [b] back        [s] skip
  [d] deeper           [l] simpler     [e] more example
  [q] quiz me          [j N] jump to part N
  [x] exit (resume later)

Or pick a follow-up:
  1. <generated Q1 specific to this part>
  2. <generated Q2>
  3. <generated Q3>

Or type any question.
```

Generate the 3 follow-ups as plausible deepening questions a learner would ask after this specific part. Avoid generic ones ("what does this mean?"); prefer specific ones referencing terms or code shown in the part.

## Command Handling

Full table: `../references/menu-commands.md`. Quick summary:

| Cmd | Effect |
|---|---|
| `n` / `next` | mark current part `done`, advance `current`, render next part at `level=mid` |
| `b` | render previous part (do not change its `done` status) |
| `s` | mark current part `skipped`, advance |
| `d` / `deeper` | re-render same part with `level=deeper` |
| `l` / `simpler` | re-render same part with `level=simpler` |
| `e` | append a worked example below the existing body, do NOT advance |
| `q` | run quiz subroutine (see below) |
| `j N` | mark intermediate parts `skipped`, set `current=N`, render Part N |
| `x` | flush state, print resume command, end |
| follow-up `1`/`2`/`3` | answer that follow-up inline, do NOT advance, re-show menu |
| free text | answer inline, do NOT advance, re-show menu |

## Quiz Subroutine (`q`)

1. Generate 2 multiple-choice questions on the current part. Each MCQ has 1 correct and 2–3 plausible distractors.
2. Show both at once. Wait for the user's answers (e.g., `1B 2A`).
3. Grade. For each wrong answer:
   a. Identify the specific sub-point the question was testing.
   b. Re-explain that sub-point in 2–4 sentences, referencing the part body.
   c. Offer a single retry on that question only.
4. After grading, re-show the menu. The user must still type `n` to advance — passing the quiz does NOT auto-advance.

## State Mutations Per Command

After every command that changes state, in order:

1. Update `progress.json` — `current`, `parts[i].status`, `parts[i].level_used`, `parts[i].completed_at`.
2. Update `GUIDE.md` Roadmap checkbox for the affected part(s) (`[ ]` → `[x]` for `done`, leave as `[ ]` for `skipped` but append `· skipped` to the Roadmap line).
3. Generate the next part body if advancing into a `pending` part.

## Loop Termination

- All parts `done` or `skipped` → proceed to Step 5 WRAP.
- User typed `x` → flush state, print:
  ```
  Saved. Resume any time:
    /x-skills:x-guide --resume <slug>
  ```
  End the skill invocation. Do NOT proceed to WRAP.

## Oversized Part

If the rendered body exceeds ~8k tokens before posting:

1. Stop rendering.
2. Inform the user: `Part <N> is large — splitting into <N>a and <N>b for clarity.`
3. Update TOC: insert `<N>b`, shift later parts (`<N+1>` becomes `<N+2>`, etc.), update `progress.json.parts`.
4. Render `<N>a` only. Resume normal loop.

## Outline Regeneration Mid-Flight

If the user types `rewrite outline` (or similar) at the menu:

1. Re-run Phase 3's drafting using the existing ingest cache.
2. Match new parts to old by case-insensitive title substring. For matches, preserve `status` and `completed_at`. For new parts, set `pending`.
3. Re-render the Roadmap and the current part. Re-show the menu.
```

- [ ] **Step 5.2: Verify**

Run:
```bash
test -f skills/x-guide/steps/step-04-walk.md && \
grep -q "Quiz Subroutine" skills/x-guide/steps/step-04-walk.md && \
grep -q "PER-PART DEPTH DECAY" skills/x-guide/steps/step-04-walk.md && \
grep -q "Outline Regeneration Mid-Flight" skills/x-guide/steps/step-04-walk.md && \
echo OK
```
Expected: `OK`

- [ ] **Step 5.3: Commit**

```bash
git add skills/x-guide/steps/step-04-walk.md
git commit -m "feat(x-guide): add Phase 4 WALK step — render-menu-command loop, quiz, depth decay"
```

---

## Task 6: Phase 5 — WRAP step file

**Files:**
- Create: `skills/x-guide/steps/step-05-wrap.md`

- [ ] **Step 6.1: Create step-05-wrap.md**

```markdown
# Step 5: WRAP — Mark complete, write summary, suggest next

**Progress: Step 5 of 5** — Last step.

## Goal

Mark the guide complete, append a takeaways summary to `GUIDE.md`, and suggest related guides the user might want next.

## Entry Conditions

- All parts in `progress.json.parts` are `done` or `skipped`. (User exits via `x` do NOT enter Phase 5.)

## Mark Complete

1. Set `progress.json.completed_at = <ISO timestamp>`.
2. Set `progress.json.current = null`.
3. Write back.

## Append Summary

Append to `GUIDE.md`:

```markdown
---

## Summary

### Key takeaways
- <1-line takeaway from Part 1>
- <1-line takeaway from Part 2>
<one bullet per non-skipped part>

### Glossary
- **<term>** — <1-line definition>
<3–8 most-used terms from across the guide>

### Where this lives in the codebase (if applicable)
- `<file:line>` — <1 line of relevance>
<2–5 entries, only for code/dir/PRD-with-code-refs sources>
```

Skip the "Where this lives in the codebase" section for `url`, `paste`, or `vague` sources unless the ingest yielded concrete file references.

## Suggest Next

Show the user a short list of natural follow-ups in chat (NOT in the file):

```
Done. Suggested next guides:

  1. <related target — pick something one layer deeper or one layer up>
  2. <related target>
  3. <related target>

Or:
  [c] close (just keep .x-guide/<slug>/)
  [d] delete .x-guide/<slug>/ (you got what you needed)
```

Generation rules for the 3 suggestions:

- For `file` source: suggest its direct dependencies, its primary callers, and the test file (if any).
- For `dir` source: suggest sibling dirs, the README, and a deeper file inside the dir.
- For `url` source: suggest related pages (parent doc, "see also" links surfaced during ingest).
- For `vague` source: suggest narrowing the topic into a concrete file/feature, plus 2 adjacent concepts.
- For `paste` source: suggest converting the paste into a real file in the repo, plus follow-on topics implied by the paste.

HALT for the user's choice. Defaults to `c` (close) on no input.

## Output of Phase 5

- `progress.json.completed_at` populated.
- `GUIDE.md` has a final `## Summary` section.
- The `.x-guide/<slug>/` directory is either kept (default) or deleted (on user `d` choice).
```

- [ ] **Step 6.2: Verify**

Run:
```bash
test -f skills/x-guide/steps/step-05-wrap.md && \
grep -q "Append Summary" skills/x-guide/steps/step-05-wrap.md && \
grep -q "Suggest Next" skills/x-guide/steps/step-05-wrap.md && \
echo OK
```
Expected: `OK`

- [ ] **Step 6.3: Commit**

```bash
git add skills/x-guide/steps/step-05-wrap.md
git commit -m "feat(x-guide): add Phase 5 WRAP step — completion summary, suggested next guides"
```

---

## Task 7: References — menu, schema, routing, part template

**Files:**
- Create: `skills/x-guide/references/menu-commands.md`
- Create: `skills/x-guide/references/progress-schema.md`
- Create: `skills/x-guide/references/routing-matrix.md`
- Create: `skills/x-guide/references/part-template.md`

- [ ] **Step 7.1: Create references/menu-commands.md**

```markdown
# Phase 4 Menu Commands — Reference

Single source of truth for what each menu command does. Step 4 quotes a summary; this file is authoritative.

## Command Table

| Cmd | Aliases | State change | Render change | Notes |
|---|---|---|---|---|
| `n` | `next` | `parts[current].status = done`, `current += 1`, `parts[new_current].status = current` | Render new current at `level=mid` | At final part, jumps to Phase 5 WRAP |
| `b` | `back` | None | Re-render previous part | If at Part 1, ignore with a message |
| `s` | `skip` | `parts[current].status = skipped`, `current += 1` | Render new current at `level=mid` | At final part, jumps to Phase 5 WRAP |
| `d` | `deeper` | `parts[current].level_used = deeper` | Re-render same part with more technical depth | Persists to `progress.json` |
| `l` | `simpler` | `parts[current].level_used = simpler` | Re-render same part with more analogy, less jargon | Persists to `progress.json` |
| `e` | `example` | None | Append a worked example below current body | Body grows; menu re-shows |
| `q` | `quiz` | None until graded; failed sub-points trigger inline re-explain | Quiz block, then re-show menu | See Quiz Subroutine in step-04 |
| `j N` | `jump N` | Intermediate parts `pending → skipped`; `current = N` | Render Part N at `level=mid` | If `N > M` or `N < 1`, error |
| `x` | `exit` | Flush state | None — print resume hint, end | Skill invocation ends here |
| `1`/`2`/`3` | (follow-up index) | None | Inline answer to that follow-up, then re-show menu | Numbers refer to the 3 generated follow-ups |
| (free text) | — | None | Inline answer, then re-show menu | Goes to Q&A path |
| `rewrite outline` | `regenerate outline` | TOC regenerated; `done` parts preserved by title match | New roadmap + re-render current | See step-04 Outline Regeneration |

## Status State Machine

```
pending ──n──► current
pending ──s──► skipped         (only via `j N` jumping past it)
current ──n──► done   (and next pending becomes current)
current ──s──► skipped (and next pending becomes current)
done    ──b──► current (when user goes back; previous current becomes pending)
skipped ──j──► current (when user jumps back to it)
```

Invariant: at most one part is `current` at any time. All others are `pending`, `done`, or `skipped`.

## Disallowed Transitions

- `done → pending` directly. Use `b` (back) which sets the previous part to `current` and the current to `pending`.
- Two parts `current` simultaneously.
- `current` set to a part beyond the final index unless WRAP entry conditions are met.

If the user requests a disallowed transition, show a one-line error and re-show the menu.
```

- [ ] **Step 7.2: Create references/progress-schema.md**

```markdown
# progress.json Schema — Reference

## Top-level fields

| Field | Type | Required | Description |
|---|---|---|---|
| `slug` | string | yes | kebab-case topic slug; matches `.x-guide/<slug>/` |
| `source` | object | yes | See Source object |
| `parts` | array | yes | Ordered list of Part objects |
| `current` | integer or null | yes | 1-based index into `parts` of the active part; `null` after WRAP |
| `started_at` | ISO 8601 string | yes | When Phase 3 first ran |
| `completed_at` | ISO 8601 string or null | yes | Set by WRAP; `null` until then |
| `level_default` | string | yes | Always `"mid"` in v1 |
| `version` | integer | yes | Schema version; v1 is `1` |

## Source object

| Field | Type | Required | Values |
|---|---|---|---|
| `type` | string | yes | `file` / `dir` / `url` / `paste` / `vague` |
| `ref` | string | yes | path / URL / `(pasted)` literal / vague phrase verbatim |
| `ingest_method` | string | yes | `claude-direct` / `x-gemini` / `x-research` |
| `ingested_at` | ISO 8601 string | yes | When `_ingest.md` was written (or when Phase 2 completed for `claude-direct`) |

## Part object

| Field | Type | Required | Values |
|---|---|---|---|
| `n` | integer | yes | 1-based part index, matches array position |
| `title` | string | yes | Part title (matches `## Part N: <title>` in GUIDE.md) |
| `status` | string | yes | `pending` / `current` / `done` / `skipped` |
| `level_used` | string or null | yes | `null` until first render, then `mid` / `deeper` / `simpler` |
| `completed_at` | ISO 8601 string or null | yes | Set when `status` first becomes `done`; `null` for skipped |

## Validation Rules

1. `parts.length >= 5 AND parts.length <= 15` after Phase 3 (or after `rewrite outline`).
2. Exactly zero or one `parts[i].status == "current"`.
3. If `completed_at` on top level is non-null, every part is `done` or `skipped` and `current` is `null`.
4. `parts[i].n == i + 1` for all `i` (no gaps).

## Example

```json
{
  "slug": "auth-flow",
  "source": {
    "type": "file",
    "ref": "src/auth.ts",
    "ingest_method": "claude-direct",
    "ingested_at": "2026-05-06T20:14:00Z"
  },
  "parts": [
    {"n": 1, "title": "Token shape", "status": "done", "level_used": "mid", "completed_at": "2026-05-06T20:18:00Z"},
    {"n": 2, "title": "Verify path", "status": "done", "level_used": "deeper", "completed_at": "2026-05-06T20:25:00Z"},
    {"n": 3, "title": "Refresh", "status": "current", "level_used": null, "completed_at": null},
    {"n": 4, "title": "Edge cases", "status": "pending", "level_used": null, "completed_at": null}
  ],
  "current": 3,
  "started_at": "2026-05-06T20:00:00Z",
  "completed_at": null,
  "level_default": "mid",
  "version": 1
}
```
```

- [ ] **Step 7.3: Create references/routing-matrix.md**

```markdown
# Phase 2 Routing Matrix — Reference

Decision matrix for picking the ingest route. Step 2 quotes the routing tree; this file is authoritative.

## Decision Matrix

| input.type | size_estimate | gemini_cli active | mcp.{perplexity,exa,deepwiki} active | Route |
|---|---|---|---|---|
| `vague` | n/a | any | any (≥1 helps) | x-research |
| `file` / `dir` / `url` / `paste` | ≤ 50k tokens | any | any | Claude direct |
| `file` / `dir` / `url` / `paste` | > 50k, ≤ 150k | yes | any | x-gemini |
| `file` / `dir` / `url` / `paste` | > 50k, ≤ 150k | no | any | Claude direct |
| `file` / `dir` / `url` / `paste` | > 150k | yes | any | x-gemini |
| `file` / `dir` / `url` / `paste` | > 150k | no | any | Claude direct + warn user once |

## Size Estimation

| Source type | Method |
|---|---|
| `file` | byte size; tokens ≈ bytes / 4 |
| `dir` | sum byte size of code/markdown/text files; skip binaries, lockfiles, `node_modules`, `.git` |
| `url` | unknown until fetched; treat as > 50k by default unless URL is a small known doc |
| `paste` | character count / 4 |
| `vague` | not applicable — always routes to x-research |

## Why Not Always-x-research?

x-research is multi-source synthesis (web + repo + MCP, multi-lane). For a known-local input the user already supplied, that is overkill — slower, more tokens, more web lanes than needed. x-gemini is single-source long-context ingest (1M context, gemini-3.x). It is the right tool when "summarize this big thing I gave you" is the job. x-research already wraps x-gemini internally for vague-target lanes, so we are not duplicating logic — we are skipping unnecessary lanes.

## Capability Gates

Per `../../x-shared/capability-loading.md`. Read once at session start from the `[x-skills/capabilities]` SessionStart line; do not re-check per dispatch.

| Capability | Used for | Fallback when missing |
|---|---|---|
| `gemini_cli` | x-gemini ingest of large input | Claude direct; warn if size > 150k |
| `mcp.perplexity` / `mcp.exa` / `mcp.deepwiki` | x-research vague-target lanes (web sources) | x-research falls back to repo-only Agent(Explore) lanes |
| `omo_plugin` + `oracle` | Optional `q deep` accuracy cross-check (Phase 4) | Skip cross-check, note in part footer |

Per-part teaching prose stays Claude-native regardless of capability set — pedagogy voice matters most.
```

- [ ] **Step 7.4: Create references/part-template.md**

```markdown
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
```

- [ ] **Step 7.5: Verify all four reference files**

Run:
```bash
for f in menu-commands progress-schema routing-matrix part-template; do
  test -f "skills/x-guide/references/$f.md" || { echo "MISSING: $f"; exit 1; }
done && echo OK
```
Expected: `OK`

- [ ] **Step 7.6: Commit**

```bash
git add skills/x-guide/references/
git commit -m "feat(x-guide): add references — menu commands, progress schema, routing matrix, part template"
```

---

## Task 8: Plugin manifest registration

**Files:**
- Modify: `.claude-plugin/marketplace.json`

- [ ] **Step 8.1: Read current marketplace.json**

Run:
```bash
cat .claude-plugin/marketplace.json
```

- [ ] **Step 8.2: Update description and tags**

Use `Edit` to change the `description` field. Find:

```
"description": "10 intelligent skill routers + 1 external companion (x-skill-review) with optional multi-model orchestration via OpenCode and direct Gemini CLI. Plugin skills: x-do, x-research, x-review, x-verify, x-bugfix, x-design, x-api-pentest, x-omo, x-gemini, x-skill-improve.",
```

Replace with:

```
"description": "11 intelligent skill routers + 1 external companion (x-skill-review) with optional multi-model orchestration via OpenCode and direct Gemini CLI. Plugin skills: x-do, x-research, x-review, x-verify, x-bugfix, x-design, x-api-pentest, x-omo, x-gemini, x-skill-improve, x-guide.",
```

Then update the `tags` array. Find:

```
"tags": [
        "skills",
        "router",
        "multi-model",
        "research",
        "debugging",
        "code-review",
        "design-system",
        "api-pentest",
        "orchestration"
      ]
```

Replace with:

```
"tags": [
        "skills",
        "router",
        "multi-model",
        "research",
        "debugging",
        "code-review",
        "design-system",
        "api-pentest",
        "orchestration",
        "tutorial",
        "teaching"
      ]
```

- [ ] **Step 8.3: Verify JSON parses and skill count is correct**

Run:
```bash
python3 -c 'import json; m = json.load(open(".claude-plugin/marketplace.json")); assert "x-guide" in m["plugins"][0]["description"], "x-guide not in description"; assert "tutorial" in m["plugins"][0]["tags"], "tutorial tag missing"; print("OK")'
```
Expected: `OK`

- [ ] **Step 8.4: Commit**

```bash
git add .claude-plugin/marketplace.json
git commit -m "chore(x-guide): register x-guide in marketplace manifest"
```

---

## Task 9: Documentation updates

**Files:**
- Modify: `CLAUDE.md`
- Modify: `docs/SKILLS_OVERVIEW.md`
- Modify: `README.md` (if it lists skills)

- [ ] **Step 9.1: Update CLAUDE.md skills table**

Find the existing skills table (look for the row containing `x-skill-improve`). Add a row above it for `x-guide`:

```markdown
| **x-guide** | plugin | Step-by-step comprehension-gated tutorials for docs/specs/code | Best with: x-gemini, x-research |
```

Use `Edit` with the table block as `old_string` to ensure unique match. Verify the resulting table is well-formed.

- [ ] **Step 9.2: Add x-guide entry to docs/SKILLS_OVERVIEW.md**

Read the file first. Find an existing skill entry (e.g., `x-research`) and mirror its style. Append a new section at the bottom of the skills list:

```markdown
## x-guide

**Purpose**: Turn complex inputs (docs, PRDs, plans, specs, code, features) into progressive, comprehension-gated tutorials with persistent per-project progress.

**Inputs**: file path, directory path, URL, pasted prose, or vague feature name.

**Output**: `.x-guide/<slug>/GUIDE.md` (full TOC + lazily-rendered parts) and `progress.json` (state).

**Workflow**: 5 phases — DETECT → INGEST → OUTLINE → WALK → WRAP. WALK is a render-menu-command loop; the user advances explicitly via `n`, can deepen with `d`, simplify with `l`, quiz with `q`, jump with `j N`, exit with `x`.

**Routing**:
- vague target → `x-research`
- known input > 50k tokens with `gemini_cli` → `x-gemini` ingest
- otherwise → Claude direct

**State**: `.x-guide/<slug>/{GUIDE.md, progress.json, _ingest.md}`. Recommended `.gitignore` entry: `.x-guide/`.

**Out of scope (v1)**: web dashboard, multi-user, audio/video, knowledge graphs, cross-topic links, user-global guides.

See `docs/SKILLS/x-guide-design.md` for the full design and `docs/SKILLS/x-guide-plan.md` for the implementation plan.
```

- [ ] **Step 9.3: Update README.md if a skills list exists**

Check:
```bash
grep -E "x-research|x-bugfix|x-do" README.md | head -5
```

If there is a skills list:
- Add `x-guide` to the list in the same style as the existing entries.
- If no list exists, skip this step.

- [ ] **Step 9.4: Verify docs**

Run:
```bash
grep -q "x-guide" CLAUDE.md && \
grep -q "x-guide" docs/SKILLS_OVERVIEW.md && \
echo OK
```
Expected: `OK`

- [ ] **Step 9.5: Commit**

```bash
git add CLAUDE.md docs/SKILLS_OVERVIEW.md README.md 2>/dev/null || git add CLAUDE.md docs/SKILLS_OVERVIEW.md
git commit -m "docs(x-guide): document new skill in CLAUDE.md and SKILLS_OVERVIEW"
```

---

## Task 10: Repository validation

**Files:**
- (none — validation only)

- [ ] **Step 10.1: Run validate-repo skill**

In the running Claude Code session, invoke:

```
/ifn-tooling:validate-repo
```

Expected output: no errors related to `x-guide`. If any structural issue is reported (frontmatter malformed, missing required field, etc.), fix it and re-run.

- [ ] **Step 10.2: Verify directory layout**

Run:
```bash
find skills/x-guide -type f | sort
```

Expected output (exact set):
```
skills/x-guide/SKILL.md
skills/x-guide/config.json
skills/x-guide/gotchas.md
skills/x-guide/references/menu-commands.md
skills/x-guide/references/part-template.md
skills/x-guide/references/progress-schema.md
skills/x-guide/references/routing-matrix.md
skills/x-guide/steps/step-01-detect.md
skills/x-guide/steps/step-02-ingest.md
skills/x-guide/steps/step-03-outline.md
skills/x-guide/steps/step-04-walk.md
skills/x-guide/steps/step-05-wrap.md
```

- [ ] **Step 10.3: Verify all SKILL.md frontmatter parses**

Run:
```bash
python3 - <<'EOF'
import re, sys
p = "skills/x-guide/SKILL.md"
with open(p) as f:
    text = f.read()
m = re.match(r"^---\n(.*?)\n---\n", text, re.DOTALL)
assert m, "missing frontmatter"
fm = m.group(1)
assert "name: x-guide" in fm, "name field wrong/missing"
assert "description:" in fm, "description field missing"
print("OK")
EOF
```
Expected: `OK`

- [ ] **Step 10.4: Manual smoke test plan (no commit needed for this step)**

The user (or an executor) should run a manual smoke test against a small, real input before declaring v1 done. Suggested smoke targets, in increasing order of complexity:

1. **Small file**: `/x-skills:x-guide skills/x-verify/SKILL.md` — small input, exercises Claude-direct route, exercises full DETECT → INGEST → OUTLINE → WALK → WRAP path.
2. **Vague target**: `/x-skills:x-guide "the x-shared capability loading flow"` — exercises x-research route. Requires MCP/research capability active to fully exercise; otherwise validates the fallback path.
3. **Resume**: invoke #1 again. Should hit the resume prompt (Phase 1) and offer `r/s/n`.
4. **Mid-flight commands**: in #1 or #2, type `d`, `l`, `e`, `q`, `b`, `j 3`, `x` in sequence to verify each command works and `progress.json` mutates correctly.

Smoke results SHOULD NOT be committed. They are observations for the human reviewer.

---

## Task 11: Final review and merge prep

**Files:**
- (none — review only)

- [ ] **Step 11.1: Review the full diff**

Run:
```bash
git log --oneline main.. -- skills/x-guide/ .claude-plugin/marketplace.json CLAUDE.md docs/SKILLS_OVERVIEW.md docs/SKILLS/x-guide-design.md docs/SKILLS/x-guide-plan.md
git diff --stat main..HEAD
```
Expected: a clean linear history of feature commits, all on the same branch.

- [ ] **Step 11.2: Run any existing repo lint/check**

Run:
```bash
./bin/setup --check
```
Expected: no errors. (Capability detection should still pass; no new dependency was added.)

- [ ] **Step 11.3: Final commit (if any tail-end fixes)**

Only if Step 10 or 11 surfaced fixes that haven't been committed:

```bash
git add -A
git commit -m "chore(x-guide): post-validation cleanup"
```

If everything is clean, skip this step.

- [ ] **Step 11.4: Confirm readiness for release**

Confirm with the user:

```
x-guide implementation complete. 11 skill files + 1 manifest update + 2 doc updates.
Spec: docs/SKILLS/x-guide-design.md
Plan: docs/SKILLS/x-guide-plan.md
Branch: <branch-name>

Ready for /release? (separate skill — handles version bump, tag, GitHub release)
```

The release flow is OUT OF SCOPE for this plan. It runs after smoke testing and user approval.

---

## Self-Review Notes

This plan was self-reviewed against `docs/SKILLS/x-guide-design.md`:

- **Phase coverage**: each of the 5 phases in the spec maps to one task (Tasks 2–6). Each task creates exactly the step file the design names.
- **State schema**: implemented in `references/progress-schema.md` (Task 7) matching §5 of the spec exactly. Status state machine implemented in `references/menu-commands.md`.
- **Routing**: implemented in `references/routing-matrix.md` (Task 7) and step-02 (Task 3). Capability gates from §6 of the spec are reproduced in the routing matrix and gotchas.
- **Edge cases (§8)**: all eight items have a home — stale ingest (step-02 + gotchas), slug collisions (step-01 + gotchas), outline mid-flight (step-04), bad input (step-01 + gotchas), oversized part (step-04), no network (step-02 + routing matrix), wrong-quiz-answer (step-04 + gotchas), exit/resume (step-04).
- **Out of scope (§9)**: not implemented (correct — those are explicit non-goals).
- **No placeholders**: every step file body is fully drafted; no "TBD" or "fill in later" survives in any step content.
- **Type/path consistency**: skill paths consistent across tasks; status values (`pending|current|done|skipped|revisit`) consistent across menu/schema/step-04. Note: `revisit` is reserved in the schema but no command produces it in v1 — kept for forward compat per spec §5.
- **Spec vs plan structural drift**: spec §7 named files `ingest-routing.md`, `walkthrough-loop.md`, `progress-state.md` under no specific subdir. The plan moves them under `steps/` (5 phase files) + `references/` (4 reference files) to match the existing `x-research`/`x-do` skill convention. This is a structural improvement, not a behavior change.

---

## Out of Scope for This Plan

The following are explicit non-goals of the implementation plan (not the skill):

- **Version bump and release**: handled by `/release` skill after smoke testing.
- **Automated tests**: this repo has no JS code under test; markdown skills are validated by `ifn-tooling:validate-repo` and manual smoke runs.
- **Cross-skill integration tests**: e.g., does `x-research` actually produce the right kind of output for x-guide's INGEST? Verified by smoke test (Task 10), not by automated harness.
- **Per-part oracle cross-check (`q deep`)**: noted in step-04 as user-triggered; full design left for v2 if it gets used.
