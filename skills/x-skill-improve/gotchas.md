# Gotchas — x-skill-improve

Known pitfalls when running session alignment analysis. Update this when you encounter new ones.

## Session Search

- **Working directory matters.** `session_search` scopes to the current project's working directory by default. If the skill was used in a different project, results will be empty. Pass a directory path (starts with `/`, `~`, or `.`) as a positional arg to target a different project (maps to `workingDirectory` param). Pass it through to ALL `session_search` calls — both discovery and deep extraction.
- **Excerpt gaps.** `session_search` returns excerpts, not full transcripts. Run multiple targeted queries (skill invocation, decision points, verification steps) to reconstruct the execution flow. Don't assume a step was skipped just because it wasn't in one excerpt.
- **Session ID format.** If the user provides a session ID, pass it directly to `sessionId` param — skip the discovery search entirely.
- **Combining project dir + session ID.** When both are provided (positionally or via flags), this is the most direct path — no discovery needed. Pass `workingDirectory` and `sessionId` to every `session_search` deep extraction call. The skill name can be auto-detected from session content if not provided.
- **workingDirectory from first batch.** When both project dir and session ID are provided, include `workingDirectory` in ALL `session_search` calls from the very first batch — not just after the first round returns 0 results. Omitting it scopes to the current project, wasting a search round.
- **Parallel search queries.** Run all search query variants for a skill in parallel (e.g., `"/x-do"`, `"Mode A"`, `"x-do skill"`) to maximize coverage in one round.
- **Multiple sessions.** When analyzing multiple sessions, run deep extraction for each in parallel. A deviation that appears in 2+ sessions is a pattern (higher confidence for UPDATE SKILL). A deviation in only 1 session is an outlier (lower confidence). Note session count in recommendations.
- **Fallback to paste.** If session_search returns no results (wrong project, old sessions, etc.), use the fallback ladder: JSONL-direct first, then paste. Don't fail silently.
- **Verify reads match claims.** When listing "Skill files analyzed: N" in the report header, only count files you actually Read. Don't extrapolate from a directory listing — if you didn't load it, don't claim you analyzed it.

## Session Parsing

- **Truncated transcripts.** Users may paste only part of a session. If you don't see a skill invocation but the user says one was used, ask which skill and mode/type — don't guess.
- **Multiple skills in one session.** A session may chain skills (e.g., x-research → x-do). Analyze each skill invocation separately and note the handoff quality between them.
- **Compressed context.** Long sessions may have `<context_window_compressed>` markers. Acknowledge that some steps may be hidden and note it in findings.

## Analysis

- **Context-justified deviations.** Not every deviation is a problem. If the executor skipped a step with good reason (e.g., user said "skip review"), mark it as a deviation but note the justification. Don't auto-classify as COMPLIANCE GAP.
- **Skill version drift.** The skill may have been updated since the session was recorded. Compare against the current skill files, but note if the session may have used an older version.
- **Over-counting.** Don't create separate findings for the same root cause. If the plan review was skipped AND the post-implementation review was skipped, that's one finding about review discipline, not two.

## Fixes

- **Bloating SKILL.md.** Resist adding lengthy new sections. Prefer adding to gotchas.md or references/ files. SKILL.md should stay under ~120 lines.
- **Over-generalizing from one session.** One session where a gate was awkward doesn't mean the gate should be removed. Consider whether the finding represents a pattern or an outlier. Note confidence in the recommendation.
