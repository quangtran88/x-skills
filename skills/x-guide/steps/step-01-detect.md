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

1. **From a file**: take the basename without extension. `src/auth.ts` → `auth`. `docs/PRD-billing-v2.md` → `prd-billing-v2`. **Generic-name fallback**: if the basename (case-insensitive) is one of `SKILL`, `README`, `INDEX`, `MAIN`, `__INIT__`, or `MOD`, use the parent directory name instead. `skills/x-verify/SKILL.md` → `x-verify`. `src/auth/index.ts` → `auth`.
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
