# Root Cause Backward Tracing

Trace bugs backward through the call chain to find the original trigger. Fix at source, not symptom.

## When to Use

- Error appears deep in call stack
- Unclear where invalid data originated
- Stack trace shows long call chain
- Need to find which test/code triggers the problem

## The 5-Step Process

### 1. Observe the Symptom
Read the error message and note exactly where it appears (file, line, function).

### 2. Find the Immediate Cause
What code directly causes the error? Read the failing line and its context.

### 3. Ask: "What Called This?"
Trace one level up. What function passed the bad value? What called that function?

### 4. Keep Tracing Up
Repeat step 3 until you find where the bad value *originates* — not where it's consumed.

```
Symptom (where error appears)
  ^ Immediate cause (what triggered the error)
    ^ Contributing factor (what set up the bad state)
      ^ ROOT CAUSE (the original trigger — fix HERE)
```

### 5. Find the Original Trigger
The root cause is where the invalid state is *created*, not where it's *detected*. Fix at this point.

## Stack Trace Tips

- **In tests:** Use `console.error()` not logger — logger output may be suppressed
- **Log BEFORE the dangerous operation**, not after it fails — capture the state that led to failure
- **Include context:** directory, cwd, environment variables, timestamps
- **Capture full call chain:** `new Error().stack` shows the complete trace
- **For test pollution:** Bisect which test creates the bad state — run tests one-by-one, stop at first polluter

## Example

**Symptom:** `git init` runs in source directory instead of temp dir

**Trace chain:**
1. `git init` runs with `cwd = process.cwd()` — empty cwd parameter
2. WorktreeManager called with empty `projectDir`
3. `Session.create()` passed empty string
4. Test accessed `context.tempDir` before `beforeEach` initialized it
5. **Root cause:** `setupCoreTest()` returns `{ tempDir: '' }` at declaration time

**Fix:** Made `tempDir` a getter that throws if accessed before `beforeEach` — plus defense-in-depth at layers 1-4 (see `prevention-gate.md`).

## Key Rule

**NEVER fix just where the error appears.** If you find yourself patching the symptom point, you haven't traced far enough. Go one more level up.
