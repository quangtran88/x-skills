# Common Gotchas (Shared)

Operational patterns that apply across all x-skills. Each skill also has its own `gotchas.md` for skill-specific pitfalls.

- **OMO agents timeout on very large prompts.** Keep prompts focused. Summarize rather than pasting entire documents.
- **Parallel agents may return at very different times.** The faster one may finish in 30s while the other takes 3 min. Always wait for all results before synthesizing.
- **explore agent returns paths relative to the search root.** Verify paths resolve correctly before passing to other tools.
- **Agent costs matter.** `oracle`, `metis`, `prometheus`, `momus` are EXPENSIVE (1-5 min, >$0.10). `explore` is FREE. `librarian`, `multimodal-looker` are CHEAP. Don't burn expensive agents on questions cheap ones can answer.
- **Never use Agent/Task tool for OMO agents.** It silently downgrades to Claude instead of using the target model. Always use Bash tool with timeout 600000.
