# Step 1: Prepare Review Content

**Progress: Step 1 of 4** — Next: Review

## Rules

- **READ COMPLETELY** before acting
- Complete detection BEFORE loading review content
- For large targets, summarize scope — don't attempt to review everything at once
- **NEVER** skip to step 3 — step 2 (cross-model review) is mandatory

## Detection

Classify the target from user input:

| Target | Signals | Action |
|--------|---------|--------|
| **A: Plan/Spec** | `.md` in specs/plans/docs, "review the plan" | Read the document fully. **Resolve the plan path to an absolute path** (via `realpath` or equivalent) and persist it for the step-04 plan-mode envelope's `target_path` field — callers re-dispatch on `REQUEST_CHANGES` using this value. |
| **B: Code/Files** | File paths, "review the code/implementation" | Use OMO `explore` (or native `Grep`) to understand context around the files, then read key files |
| **C: Git Diff** | "last commit", "staged", "this PR", "branch diff" | Construct the diff |
| **D: No Target** | Just says "review" | Auto-detect from git state |

### Git Diff Commands (Target C)

| User Says | Command |
|-----------|---------|
| `last commit` / `latest` | `git diff HEAD~1` |
| `last N commits` | `git diff HEAD~N` |
| `staged` | `git diff --staged` |
| `this PR` / `vs main` | `git diff main...HEAD` |
| `<sha1>..<sha2>` | `git diff <sha1>..<sha2>` |

### Auto-Detection (Target D)

Check in priority order: staged changes → uncommitted changes → branch diff vs main → nothing to review.

## Optional: Blast-Radius Enrichment (gitnexus, gated)

This step is **OPTIONAL and gated**. It runs ONLY for Target B (code/files) and Target C/D (git diff) where changed code symbols or API route handlers are identifiable. It never runs for Target A (plan/spec).

**Gate (resolve in this order — do NOT run a new `gitnexus list`):**

1. Read the **indexed+fresh signal** from the already-pinned shared probe (`../../x-shared/capability-loading.md` § "Shared GitNexus Indexed+Fresh Probe"). x-review consumes this single session-pinned record from its Bootstrap (step 0 capability pin); it does **not** run its own `gitnexus list`.
2. Resolve tool class via `../../x-shared/mcp-toolbox.md` § "Use-class index (F2)": `impact`, `route_map`, and `api_impact` are all **correctness-sensitive**.
3. Gate passes only when: `mcp.gitnexus` pinned **AND** the target repo is in the indexed-path set **AND** that repo's index is fresh (`staleness` absent or `commitsBehind === 0`).

**If the gate fails for ANY reason (not pinned, repo not indexed, or stale):** skip this entire section. Contribute NOTHING to Output. Proceed directly to `## Output` exactly as if this section did not exist. Correctness-sensitive tools hard-degrade on stale per the use-class index — there is no stale-with-note path here.

**When the gate passes:**

- **Changed code symbols** → call `gitnexus impact` with `direction: upstream`. Emit one **summarized depth-1-only** line per changed symbol:

  `<symbol>: K depth-1 callers, flows: [<flow names>]`

  Hard cap at the **top-8 callers**, ordered deterministically so two reviewers see the same 8:
  1. edge confidence **descending**
  2. ties broken by depth **ascending**
  3. further ties broken by caller name **ascending**

  Depth-1 only — do NOT walk deeper. Counts only; never read or surface gitnexus's `risk` field (C1).

- **Changed API route handlers** → ADDITIONALLY call `gitnexus route_map` / `api_impact` → emit the consumer list. The canonical in-scope false-assumption finding ("PR says handler is internal-only; N external consumers exist") comes from **`route_map` consumers**, NOT from `impact` depth-1 callers — these are distinct signals; both feed the Scope Contract block.

Every enrichment line is reviewer-facing and MUST carry the C2 disclaimer when surfaced (see the Scope Contract block in `../SKILL.md`): *static call graph — may miss dynamic dispatch; a 0-caller result is NOT a safety proof.*

This enrichment **sharpens in-scope findings only** (false-assumption / spec-deviation). It MUST NOT introduce refactor/coupling/architecture observations — the Scope Contract block fences those out.

## Output

A clear description of WHAT is being reviewed and the content/diff ready for reviewers. When the enrichment gate passed, include the per-symbol depth-1 summary / route_map consumer list (each line carrying the C2 disclaimer); when it did not, this is byte-identical to the pre-enrichment output.

- [ ] **Memory recall** (only when `mcp.basic_memory` pinned in bootstrap-active set): one `mcp__basic-memory__search_notes({ query: "<PR title or diff summary>", page_size: 5 })` call; optionally a second with the changed file basenames as the query to surface prior lessons touching the same files. Treat results as supplementary review context — leads, not verdicts. **Apply consumer rules from `../../x-shared/mcp-toolbox.md § Consumer rules`.** When `mcp.basic_memory` is not pinned, **skip silently** — Claude's native auto-memory file still applies.

## Next Step

Read fully and follow `step-02-review.md` with the prepared content.
