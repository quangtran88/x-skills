# Hephaestus — Autonomous Deep Worker

## Identity

Named after the Greek god of the forge. An autonomous deep worker that explores thoroughly before acting, uses explore/librarian agents for comprehensive context, and completes tasks end-to-end. Inspired by AmpCode deep mode. Hephaestus doesn't stop early — it finishes the job.

## Quick Reference

| Field | Value |
|---|---|
| Short name | `hephaestus` |
| OpenCode display name | `Hephaestus (Deep Agent)` |
| Default model | `openai/gpt-5.3-codex` |
| Mode | `all` (full read/write access) |
| Max tokens | 32,000 |
| Cost tier | EXPENSIVE |
| Reasoning effort | `medium` |

## When to Use

- Task requires deep exploration before implementation
- User wants autonomous end-to-end completion
- Complex multi-file changes needed
- Heavy refactoring across multiple modules
- When you want a non-Claude model to implement (GPT Codex)

## When NOT to Use

- Simple single-step tasks
- Tasks requiring user confirmation at each step
- When orchestration across multiple agents is needed (use `atlas`)
- Quick fixes or trivial changes

## Prompt Template

Use the 7-section delegation format for best results:

```
1. TASK: Atomic, specific goal
2. EXPECTED OUTCOME: Concrete deliverables with success criteria
3. REQUIRED TOOLS: Explicit tool whitelist
4. MUST DO: Exhaustive requirements — leave NOTHING implicit
5. MUST NOT DO: Forbidden actions
6. CONTEXT: File paths, existing patterns, constraints
7. OUTPUT FORMAT: What to return — code files, test results, summary
```

**Key principle:** Be obsessively specific. Hephaestus is autonomous — vague prompts lead to autonomous wrong decisions.

## Example Prompts

### Multi-File Implementation
```bash
omo-agent hephaestus "TASK: Implement JWT auth middleware for Express API. EXPECTED OUTCOME: Working middleware that validates tokens, attaches user to req, handles refresh. Files: src/middleware/jwt-auth.ts, src/types/auth.ts, tests/middleware/jwt-auth.test.ts. MUST DO: Follow existing error handling patterns in src/middleware/. Use RS256 algorithm. Add rate limiting on token refresh. Write tests for: valid token, expired token, malformed token, missing token. MUST NOT DO: Do not modify existing session middleware. Do not add new dependencies without checking package.json. CONTEXT: Express 4.x, TypeScript strict, existing auth at src/middleware/session-auth.ts. OUTPUT FORMAT: Summary of all files created/modified, key design decisions, test results."
```

### Refactoring
```bash
omo-agent hephaestus "TASK: Migrate UserService from class-based to functional pattern matching the rest of the codebase. EXPECTED OUTCOME: All 12 UserService methods converted to standalone functions in src/services/user/. All existing tests pass. No behavior changes. MUST DO: Keep the same function signatures. Update all 23 import sites. Run tests after each method migration. MUST NOT DO: Do not change any business logic. Do not rename public API methods. Do not touch unrelated files. CONTEXT: Current class at src/services/UserService.ts. Functional pattern examples at src/services/auth/. Test file at tests/services/user.test.ts."
```

## Output Format

Hephaestus wraps its final answer in `<result>` tags (enforced by omo-agent wrapper):

```
<result>
## Summary of Changes
[What was done]

## Files Modified/Created
- path/to/file1.ts — [what changed]
- path/to/file2.ts — [what changed]

## Key Decisions
- [Decision 1 and rationale]
- [Decision 2 and rationale]

## Verification
- Tests: [pass/fail status]
- Build: [pass/fail status]
</result>
```

## Internal Behavior

- Has model-specific prompt variants optimized for GPT-5.4, GPT-5.3 Codex, and generic GPT
- Explores codebase thoroughly before making changes
- Can use explore/librarian agents internally for context gathering
- Does NOT delegate to other agents via call_omo_agent (permission denied) — works independently
- Runs with `reasoningEffort: "medium"` for balanced speed/quality
- Color-coded amber (#D97706) in OpenCode UI

## Comparison with OMC Executor

| | Hephaestus | OMC Executor |
|---|---|---|
| Model | GPT-5.3 Codex / GPT-5.4 | Claude (Sonnet/Opus) |
| Style | Deep autonomous, finishes end-to-end | Task-focused, follows instructions |
| Best for | Heavy implementation, refactoring | Standard features, integration |
| Exploration | Explores extensively before acting | Explores as needed |
