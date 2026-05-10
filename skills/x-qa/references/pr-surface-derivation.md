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
  "touched_endpoints": ["/api/users", "/api/users/:id"],
  "touched_files": ["src/routes/users.ts", "src/lib/auth.ts"],
  "fallback_to_all": false,
  "transitive_depth": 2
}
```

The plan generator reads this and only includes test cases for `touched_endpoints` plus mandatory health-check smoke.
