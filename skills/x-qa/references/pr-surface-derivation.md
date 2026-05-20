# PR / Branch Surface Derivation

Used by `--pr <num>` and `--branch <name>` flags to compute which endpoints a change touches, narrowing plan generation.

## Procedure

1. Compute diff: `git diff origin/main...HEAD --name-only` (branch) or `gh pr diff <num> --name-only` (PR).
2. Filter excluded paths from `profile.ignore_paths`.
3. For each changed file:
   - If file matches a route declaration pattern (e.g. `**/routes/**`, `**/api/**`, `**/handlers/**`) → mark its declared endpoints as touched.
   - If file is referenced from an OpenAPI spec → mark spec-referenced endpoints as touched.
   - If file is a shared util → walk transitive callers up to depth 2; mark callers' endpoints.
4. Aggregate touched endpoints. Plan generator constrains test surface to this set + `health` smoke tests.

## Transitive Caller Walk

Use `morph-mcp codebase_search` to find references; cap recursion depth at 2 to bound work. If depth-2 walk yields >50 candidate endpoints, emit a warning and fall back to "all endpoints".

## Output

A JSON document:

```json
{
  "touched_endpoints": [
    { "endpoint": "/checkout", "derivation": "file-heuristic", "source_file": "src/pages/checkout.tsx" },
    { "endpoint": "/api/users", "derivation": "caller-walk", "source_file": "src/lib/auth.ts" }
  ],
  "touched_files": ["src/pages/checkout.tsx", "src/lib/auth.ts"],
  "fallback_to_all": false,
  "transitive_depth": 2
}
```

Back-compat: the planner-prompt assembly (the only `touched_endpoints` consumer today, per `references/scout-prompt.md`) renders whichever shape it receives — the back-compat window is prompt-text-only, not a multi-shell-consumer shim. Code that gains a structured consumer later MUST handle both shapes until the v2 schema bump.

The plan generator reads this and only includes test cases for `touched_endpoints` plus mandatory health-check smoke.

## Frontend-File → Route Heuristic

For repositories with file-based routing (Next.js, SvelteKit, Nuxt, Astro, Remix), apply the following path→route mapping before falling back to the generic transitive-caller walk. Precise + zero LLM cost.

| File pattern | Derived route | Routing flavor |
|---|---|---|
| `src/pages/<name>.tsx` | `/<name>` | Next.js Pages Router |
| `src/pages/<name>/index.tsx` | `/<name>` | Next.js Pages Router |
| `src/pages/<segment>/[<param>].tsx` | `/<segment>/:<param>` | Next.js Pages dynamic |
| `src/app/<name>/page.tsx` | `/<name>` | Next.js App Router |
| `src/app/<segment>/[<param>]/page.tsx` | `/<segment>/:<param>` | Next.js App dynamic |
| `src/app/(<group>)/<name>/page.tsx` | `/<name>` | Next.js route group |
| `src/routes/<name>/+page.svelte` | `/<name>` | SvelteKit |
| `pages/<name>.vue` | `/<name>` | Nuxt |
| `src/pages/<name>.astro` | `/<name>` | Astro |
| `app/routes/<name>.tsx` | `/<name>` | Remix |

**Component-file fallback.** Files matching `src/components/**`, `src/lib/**`, or `src/shared/**` are NOT routes — they trigger a transitive-caller walk (existing Step 3 behavior, capped at depth 2).

**Pattern anchoring.** All path patterns in the table are anchored to start-of-(stripped)-path. Monorepo layouts MUST declare `frontend_route_prefixes` so the prefix is stripped before lookup; otherwise the file falls through to the caller-walk fallback. The table also accepts a root-`pages/` variant (`pages/<name>.tsx`, `pages/<name>/index.tsx`) for projects whose Pages Router lives outside `src/`.

**File-extension filter.** Apply route heuristics only when the changed file ends in one of: `.tsx`, `.jsx`, `.ts`, `.js`, `.vue`, `.svelte`, `.astro`. Pure CSS/SCSS changes mark touched routes as "visual-only" (planner uses the smoke runner, not the complex runner).

**Profile override.** Repositories with non-standard layouts (`apps/web/src/pages/...`, monorepo packages) may declare a `frontend_route_prefixes:` array in `profile.json`:

```json
{ "frontend_route_prefixes": ["apps/web/", "packages/frontend/"] }
```

When set, `apps/web/src/pages/checkout.tsx` is normalized to `src/pages/checkout.tsx` before lookup, then resolves to `/checkout`.

**Confidence tagging.** Routes derived from this table emit `derivation: "file-heuristic"`; transitive-walk hits emit `derivation: "caller-walk"`. Planner MAY weight heuristic hits higher.
