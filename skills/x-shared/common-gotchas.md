# Common Gotchas (Shared)

Operational patterns that apply across all x-skills. Each skill also has its own `gotchas.md` for skill-specific pitfalls.

- **⚠ Unavailable OMO agents.** `hephaestus`, `atlas`, `prometheus`, `metis`, `momus` will hard-fail. See `omo-routing.md § Unavailable Agents` for the canonical list and replacement model-routing mapping.
- **OMO agents timeout on very large prompts.** Keep prompts focused. Summarize rather than pasting entire documents.
- **Parallel agents may return at very different times.** The faster one may finish in 30s while the other takes 3 min. Always wait for all results before synthesizing.
- **explore agent returns paths relative to the search root.** Verify paths resolve correctly before passing to other tools.
- **Agent costs matter.** `oracle` is EXPENSIVE (1-5 min, >$0.10). `explore` is FREE. `librarian`, `multimodal-looker` are CHEAP. Don't burn expensive agents on questions cheap ones can answer.
- **Never use Agent/Task tool for OMO agents.** It silently downgrades to Claude instead of using the target model. Always use Bash tool with timeout 600000.
- **`omo dispatch` is not a command.** Recurring Claude-side hallucination: assembling `omo dispatch gemini-agent …`, `omo run …`, `omo exec …`, or `omo gemini-agent …`. There is no `omo` binary — only standalone wrappers `gemini-agent` and `omo-agent` (canonical forms in `invocation-guide.md` § Literal binaries). When a lane errors with `command not found: omo`, **retry once** with the documented form before declaring the lane unreachable; dropping a lane on the first command-not-found is a violation.
