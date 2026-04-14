# x-research Gotchas

Known failure patterns specific to x-research. For shared OMO patterns, see `../x-shared/common-gotchas.md`.

- **librarian sometimes returns tutorial content despite "skip tutorials" instruction.** If the output is too introductory, re-prompt with "production patterns only, assume expert audience."
- **oracle is expensive and slow (1-5 min).** Don't use it for questions that explore or librarian can answer. Reserve for genuine architecture trade-offs.
- **metis can over-scope requirements.** It tends to surface every possible edge case. Filter findings by actual project constraints before passing to prometheus.
- **multimodal-looker needs specific prompts.** "Analyze this image" returns vague descriptions. Ask for specific things: "Extract the API endpoint URLs from this diagram."
- **Check session context before re-running expensive queries.** If a similar question was researched earlier in this session, reference the prior findings instead of burning another oracle/metis call.
- **Bootstrap must read the FULL OMO SKILL.md.** Partial reads (e.g., lines 1-30) miss the agent catalog, invocation patterns, and gotchas needed for correct routing. Always read the complete file.
- **Local research repos don't need agent dispatch.** When the target is a local research repo and is small (<50 files), direct file reads are faster and more targeted than `explore`. This is a valid Type A deviation — not a compliance gap.
- **OMO `explore` (Bash) vs OMC `Explore` (Agent tool) are different systems.** For single-repo research, x-research uses OMO agents invoked via Bash (`omo-agent explore "query"`). Do NOT dispatch via Agent tool with `subagent_type=Explore` for single-repo cases — that's the OMC agent, which uses a different model and prompt structure. Exceptions:
  - **Multi-repo parallel scans** (3+ repos): OMC Explore agents are preferred — see `references/type-a-notes.md`.
  - **Multi-aspect single-repo** (e.g., Type D with 2+ distinct features): Multiple targeted OMC Explore agents may be used instead of a single OMO explore call — parallelism and targeted prompts produce better results than one broad query.
  - **Type E (OSS Internals)**: OMC Explore agent is the primary route because it can access the `deepwiki` MCP tool, which OMO agents cannot.
- **OMO agents only have 3 built-in MCPs: context7, websearch_exa, grep_app.** They CANNOT access deepwiki, exa:get_code_context, perplexity_reason, or other Claude Code session MCP tools. When research needs these tools, dispatch OMC agents (Agent tool) instead — they inherit all session MCP tools.
- **OMC agents need ToolSearch before invoking MCP tools.** MCP tools are deferred — subagents must call `ToolSearch` to fetch the schema before invoking. Include this instruction in agent prompts: "Use ToolSearch to fetch the MCP tool schema, then invoke it."
- **deepwiki may not have all repos indexed.** If `mcp__deepwiki__ask_question` returns an error for a repo, fall back to OMO librarian with TYPE B hint. Don't retry deepwiki — if it's not indexed, it won't become indexed during the session.
- **Don't replace librarian for Type B — it already uses context7 internally.** Librarian's TYPE A classification routes to context7 + websearch. Routing Type B away from librarian to "direct context7" removes its multi-source synthesis capability. The "tutorial content" gotcha is a prompting issue (use TYPE A hint), not a tool issue.
- **perplexity_reason lacks codebase access — supplement, not replacement for oracle.** For architecture questions involving local code constraints, oracle reads the codebase. perplexity_reason only has web context. Use perplexity_reason as a parallel supplement for web-grounded tradeoff data, not as the primary route for project-specific architecture.
- **Don't `cat` background agent output files to poll.** Auto-notifications arrive on completion; polling risks truncated reads and bypasses `~/.claude/rules/background-agents.md`.
- **Morph auth errors ≠ insufficient results.** On `invalid username, password or token`, fall back immediately to OMC Explore w/ deepwiki → librarian. Don't retry morph with different params. Direct `mcp__github__get_file_contents` is a supplement after fallback, not a primary replacement for deepwiki.
- **Type E sequencing violation: firing agents "in parallel with morph, just in case".** Morph-first is a HARD GATE — call morph AND read its output BEFORE dispatching any agent. Parallel dispatch alongside morph defeats the principle.
