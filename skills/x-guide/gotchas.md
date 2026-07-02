# x-guide Gotchas

## Stale ingest

- **Symptom**: cached `_ingest.md` no longer matches source (file edited after ingest).
- **Detection**: source `mtime` newer than `_ingest.md` `mtime`.
- **Action**: prompt user — re-ingest now / keep cached / abort. Default to keep cached when in doubt.

## Slug collisions

- **Symptom**: two different sources produce the same kebab-case slug (e.g., `auth.md` and `Auth.md` in different dirs).
- **Action**: append `-2`, `-3`, ... to the slug. Never overwrite an existing `.x-guide/<slug>/`.

## Resume vs restart confusion

- **Symptom**: user invokes x-guide on a target that already has `.x-guide/<slug>/`.
- **Rule**: NEVER auto-resume. Always prompt: resume / restart / new-slug.

## Oversized rendered part

- **Symptom**: a single part exceeds ~8k tokens when rendered.
- **Action**: split into sub-parts (e.g., Part 3 → Part 3a, 3b). Update TOC, shift later part numbers.

## Capability missing — agy_cli absent

- **Symptom**: large input (>50k tokens) but no `agy_cli` in active capability set.
- **Action**: read into Claude directly. Warn user once if input >150k tokens; do not block.

## Capability missing — MCP servers absent for vague target

- **Symptom**: vague-target input but no `mcp.perplexity` / `mcp.exa` / `mcp.deepwiki` active.
- **Action**: fall back to Claude `Agent(Explore)` searching repo only. Note in `_ingest.md` that web sources were unavailable.

## Wrong-answer quiz loop

- **Symptom**: user fails MCQ in `q` mode.
- **Action**: re-explain the specific weak sub-point inline. Do not advance to `next` until either (a) user retries correctly, or (b) user types `n` explicitly to skip past the gate.

## Free-text question mid-loop

- **Symptom**: user types a free-text question instead of a menu command.
- **Action**: answer inline. Do NOT advance the part. Re-show the menu after the answer.

## Outline regeneration mid-flight

- **Symptom**: user types "rewrite outline" after some parts are already `done`.
- **Action**: regenerate TOC. Match new parts to old by title (case-insensitive substring). Preserve `done` status on matches; new parts get `pending`.

## Bad input

- **Symptom**: file path missing, URL returns 4xx/5xx, paste empty.
- **Action**: fail fast. Do NOT create `.x-guide/<slug>/`. Surface a one-line error and stop.
