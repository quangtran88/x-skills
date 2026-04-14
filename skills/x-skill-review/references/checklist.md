# Skill Best Practice Checklist

Score each item: **PASS**, **FAIL**, or **N/A** (not applicable to this skill type).

Items marked `[M]` are **mechanical** — validate with native tools (Bash, Read, Grep) in the pre-check step. Items marked `[J]` require **LLM judgment**.

Source: Anthropic's official skill best practices (2025), supplemented with verified patterns from superpower and claudekit research repos.

## Structure & Progressive Disclosure

- [ ] `[M]` **Folder, not just a file.** Skill directory contains more than just `SKILL.md` — has references/, scripts, assets, or data as appropriate. Check: `ls -la` returns more than one file.
- [ ] `[J]` **Progressive disclosure.** Detailed content (prompt templates, routing tables, examples, API signatures) is in reference files, not front-loaded in `SKILL.md`. Claude reads them when needed.
- [ ] `[M]` **SKILL.md size.** Core file focuses on detection, workflow overview, and pointers to references. Flag if > 500 lines (Anthropic hard limit); note if > 120 lines (optimal target). Check: `wc -l SKILL.md`.
- [ ] `[J]` **No duplicated content.** Information available in other skills or docs is referenced, not copy-pasted. Check for repeated routing tables, invocation protocols, agent catalogs.
- [ ] `[M]` **References are one level deep.** All reference files link directly from SKILL.md — no chains of files referencing other files that reference the actual content. Check: grep reference files for further file references.
- [ ] `[M]` **Referenced files exist.** Every file path mentioned in SKILL.md and other skill files actually resolves. Check: grep for patterns like `references/`, `../x-shared/`, `gotchas.md`, `config.json`, then verify each exists.

## Frontmatter & Description

- [ ] `[M]` **Valid frontmatter.** Has `name` and `description` fields in YAML frontmatter. Check: parse YAML between `---` markers.
- [ ] `[M]` **Field length limits.** `name` ≤ 64 characters, `description` ≤ 1024 characters. Check: measure string lengths.
- [ ] `[J]` **Trigger-specific description.** Description tells the model *when* to activate, not just *what* it does. Should read like "Use when the user asks to..." not "Universal X command."
- [ ] `[M]` **Name is concise.** Short, memorable, lowercase-with-hyphens. Check: regex `^[a-z][a-z0-9-]*$`.

## Content Quality

- [ ] `[J]` **Doesn't state the obvious.** Focuses on information that pushes Claude out of its defaults — not things Claude already knows about coding or the codebase.
- [ ] `[M]` **Has a Gotchas section.** Documents known failure patterns, edge cases, and footguns. Either inline or in a separate `gotchas.md`. Check: file exists or SKILL.md contains "gotcha" heading.
- [ ] `[J]` **Avoids railroading.** Gives Claude the information and flexibility to adapt, rather than rigid step-by-step scripts. Uses language like "consider", "when appropriate", "useful for" instead of mandatory numbered sequences. Exception: some skills genuinely need strict sequences for safety (see gotchas.md).
- [ ] `[J]` **Clean category fit.** Maps to one skill type (see `skill-types.md`). Straddling multiple types is a yellow flag — consider splitting.

## Configuration & Portability

- [ ] `[M]` **Configurable paths.** Paths to external tools, state files, and directories are in `config.json`, not hardcoded in SKILL.md. Check: grep SKILL.md for absolute paths not wrapped in config references.
- [ ] `[J]` **Setup mechanism.** If the skill needs user-specific configuration (channels, credentials, preferences), there's a way to set it up and persist it — typically a `config.json` that the skill checks on first run.

## Persistence & Memory

- [ ] `[J]` **Stores useful data.** If the skill benefits from remembering prior executions (research logs, review history, standup posts), it has a data persistence mechanism (log file, JSONL, SQLite).
- [ ] `[J]` **Stable storage location.** Data is stored in a location that survives skill upgrades — `${CLAUDE_PLUGIN_DATA}` for plugins, or a documented `data/` directory for local skills.

## Scripts & Assets

- [ ] `[J]` **Includes supporting scripts.** If the skill involves repetitive operations, it provides scripts/libraries Claude can compose rather than reconstructing boilerplate each time.
- [ ] `[J]` **Template files for outputs.** If the skill produces structured output (reports, posts, docs), a template file in `assets/` ensures consistent formatting.

## Hooks (Optional)

- [ ] `[J]` **On-demand hooks.** If the skill benefits from session-scoped behavior enforcement (blocking dangerous commands, restricting edits to certain directories), it registers hooks that activate only when the skill is called.

## Distribution Readiness (if sharing)

- [ ] `[J]` **Self-contained.** All dependencies are documented or bundled. Another user can install and use the skill without tribal knowledge.
- [ ] `[M]` **No secrets in skill files.** API keys, tokens, and credentials are in config or environment variables, never in skill source. Check: grep for `sk-`, `api_key`, `apikey`, `token`, `secret`, `password` patterns.
- [ ] `[M]` **Composability documented.** If the skill depends on or references other skills, those dependencies are stated explicitly. Check: grep for skill references and verify a Dependencies section exists.
