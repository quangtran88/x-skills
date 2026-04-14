# x-skill-review Gotchas

Known review pitfalls specific to x-skill-review. For shared OMO patterns, see `../x-shared/common-gotchas.md`.

- **Not every skill needs every checklist item.** A simple 10-line skill for a quick task doesn't need config.json, hooks, and a data directory. Score items N/A when the overhead exceeds the benefit.
- **"Folder structure" doesn't mean more files for the sake of it.** Only extract content to references/ if it genuinely enables progressive disclosure.
- **Don't penalize small skills for being small.** A focused 30-line skill that does one thing well is better than a bloated 200-line skill with every best practice checkbox ticked.
- **Gotchas sections are built over time.** A brand new skill won't have gotchas yet — flag it as MEDIUM, not CRITICAL.
- **Check the OMO/OMC skill catalogs before flagging "duplicated content."** If a routing table is genuinely specific to this skill's context, it's not duplication.
- **Railroading vs. necessary structure.** Some skills genuinely need strict step sequences for safety. "Avoids railroading" means unnecessary rigidity, not the absence of all structure.
- **Never modify external plugin skills.** Skills in `~/.claude/plugins/` are managed by their upstream plugin. Present findings as advisory only — recommend the user update the plugin, don't edit cache files directly.
- **Mechanical checks before LLM judgment.** Run all `[M]` checklist items first with native tools. This catches deterministic failures (broken references, missing frontmatter, secrets) without relying on LLM analysis. Only then run `[J]` items that need judgment.
- **Reference validation catches real bugs.** Skills that reference files like `../x-shared/severity-guide.md` or `references/checklist.md` can silently break when files are moved or renamed. Always verify referenced paths resolve.
