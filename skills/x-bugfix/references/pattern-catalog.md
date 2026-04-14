# Bug Pattern Catalog

Common bug patterns to check during Phase 2 (Analyze). Match the symptom to narrow the investigation.

| Pattern | Signature | Where to Look |
|---------|-----------|---------------|
| Race condition | Intermittent, timing-dependent | Concurrent access to shared state |
| Nil/null propagation | TypeError, undefined is not a function | Missing guards on optional values |
| State corruption | Inconsistent data, partial updates | Transactions, callbacks, hooks |
| Integration failure | Timeout, unexpected response | External API calls, service boundaries |
| Configuration drift | Works locally, fails in staging/prod | Env vars, feature flags, DB state |
| Stale cache | Shows old data, fixes on cache clear | Redis, CDN, browser cache |
| Import/dependency | Module not found, version mismatch | package.json, lock files, node_modules |
| Type mismatch | Unexpected type at runtime | Serialization boundaries, API responses |
| Regression | Was working, now broken | Recent commits touching affected files |
| Resource leak | Gradual degradation, OOM | Unclosed connections, event listeners, timers |

## Using the Catalog

- Match the bug's **signature** first — this narrows the search space
- Check `git log` for prior fixes in the same area — recurring bugs in the same files are an architectural smell
- Find **working examples** of similar code in the codebase and compare
- If no pattern matches, the bug may be novel — proceed to hypothesis testing without anchoring on a pattern
