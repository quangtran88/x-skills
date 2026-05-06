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
