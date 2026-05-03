# x-shared — Reference Library (NOT a skill)

This directory holds shared reference docs consumed by the other x-skills via relative paths (`../x-shared/<file>.md`). It has no `SKILL.md` and is **not invokable** as `/x-shared`.

## Contents

| File | Purpose |
|------|---------|
| `capability-loading.md` | Bootstrap-pinned capability contract |
| `common-gotchas.md` | Cross-skill operational pitfalls |
| `completion-cascade.md` | x-verify cascade specification |
| `context-envelope.md` | Handoff context block format |
| `invocation-guide.md` | Tool invocation patterns + precedence ladder |
| `mcp-toolbox.md` | Plugin-local MCP decision matrix with fallbacks |
| `omo-routing.md` | Signal → OMO agent routing table |
| `reactions-vocabulary.md` | Cross-skill reaction signals |
| `severity-guide.md` | Finding severity scale (CRITICAL/HIGH/MEDIUM/LOW) |
| `slot-schema.md` | Slot-fill schema for skills |
| `workflow-chains.md` | Common cross-skill chain sequences |

## Why no SKILL.md

The Claude Code skill loader registers a directory as a skill only when it contains a `SKILL.md`. Omitting that file keeps `x-shared/` invisible to skill discovery while the files remain reachable via relative paths from sibling skills. Do not add a `SKILL.md` here.
