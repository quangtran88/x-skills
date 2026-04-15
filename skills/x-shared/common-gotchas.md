# Common Gotchas (Shared)

Operational patterns that apply across all x-skills. Each skill also has its own `gotchas.md` for skill-specific pitfalls.

- **⚠ NEVER DISPATCH to these OMO agents — they are UNAVAILABLE.** `hephaestus`, `atlas`, `prometheus`, `metis`, `momus` are blocked by a known opencode + oh-my-opencode plugin compat bug and will hard-fail. The only OMO agents safe to call via `omo-agent <name>` are: **`oracle`, `explore`, `librarian`, `multimodal-looker`**. For autonomous implementation use `omo-agent --model codex "<prompt>"`; for plan review / blocker-finding use `omo-agent --model gpt "<prompt>"`; for pre-planning and architecture advice use `oracle`. See `~/.claude/skills/x-omo/gotchas.md` for the full writeup.
- **OMO agents timeout on very large prompts.** Keep prompts focused. Summarize rather than pasting entire documents.
- **Parallel agents may return at very different times.** The faster one may finish in 30s while the other takes 3 min. Always wait for all results before synthesizing.
- **explore agent returns paths relative to the search root.** Verify paths resolve correctly before passing to other tools.
- **Agent costs matter.** `oracle` is EXPENSIVE (1-5 min, >$0.10). `explore` is FREE. `librarian`, `multimodal-looker` are CHEAP. Don't burn expensive agents on questions cheap ones can answer.
- **Never use Agent/Task tool for OMO agents.** It silently downgrades to Claude instead of using the target model. Always use Bash tool with timeout 600000.
