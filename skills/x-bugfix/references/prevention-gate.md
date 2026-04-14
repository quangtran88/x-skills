# Prevention Gate

After fixing a bug, prevent the same *class* of issues from recurring. A fix without prevention is incomplete.

## Checklist (check all that apply)

### 1. Regression Test (ALWAYS required)

Every fix MUST have a test that:
- **Fails** without the fix (proves the test catches the bug)
- **Passes** with the fix (proves the fix works)

No test framework? Add an inline assertion or runtime guard at minimum. Note in the debug report.

### 2. Defense-in-Depth (when applicable)

Add validation at EVERY layer the bad data passes through. Single checks get bypassed by different code paths, refactoring, or mocks.

| Layer | Purpose | Example |
|-------|---------|---------|
| **Entry point** | Reject invalid input at API boundary | Validate not empty, exists, correct type |
| **Business logic** | Ensure data makes sense for this operation | Assert preconditions before processing |
| **Environment guards** | Prevent dangerous ops in wrong context | Refuse destructive ops outside tmpdir in tests |
| **Debug instrumentation** | Capture context for forensics | Log before dangerous operations with stack trace |

Not every fix needs all 4 layers. But consider each — different layers catch different failure modes.

### 3. Type Safety (when applicable)

| Scenario | Prevention |
|----------|-----------|
| Null/undefined caused the bug | Add strict null checks, `??` or `?.` |
| Wrong type passed | Add type guard or runtime validation |
| Missing property | Add required field to interface/type |
| Implicit any | Add explicit types |

### 4. Error Handling (when applicable)

| Scenario | Prevention |
|----------|-----------|
| Unhandled promise rejection | Add `.catch()` or try/catch |
| Silent failure | Add explicit error logging |
| No fallback for external dependency | Add timeout + fallback |
| Missing error boundary | Add error boundary component |

## Output Format

Include in the debug report after the fix:

```
### Prevention Measures
- Regression test: [file:line] — covers [scenario]
- Guard added: [file:line] — [description]
- Type safety: [file:line] — [what was strengthened]
- Error handling: [file:line] — [what was added]
```

## Quick Mode Exception

For trivial issues (type errors, lint): regression test optional (type system IS the test), defense-in-depth skip (not applicable). Still require before/after comparison.
