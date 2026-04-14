# shadcn MCP handoff (workflow step 7)

After `DESIGN.md` lands (step 4) and `MASTER.md` is optionally generated (step 6), this step bridges from *design intent* to *installed components*. The handoff is **conditional** — non-shadcn projects must see no mention of it.

## Decision gate

| Check | Outcome |
|---|---|
| `mcp__shadcn__get_project_registries` returns empty or errors | **No-op** — skip the entire step. Do not mention shadcn. |
| Returns one or more registries | Proceed to "Ask once" |

The detection-first rule is non-negotiable. A non-React/Tailwind project should never be asked about shadcn.

## Sub-steps

### a. Detect

```
mcp__shadcn__get_project_registries
```

Empty result → step 7 ends here. Do not ask, do not search, do not announce.

### b. Ask once

If at least one registry is configured, surface a single offer:

> "This project has shadcn configured. Want me to search the registry for base components matching `<brand>`'s style and show the install commands?"

Decline → skip silently to step 8. Never push twice in the same conversation.

### c. Seed a starter set

If yes:

1. Pull intent tags from the catalog row used in step 2 (e.g., `minimal`, `dark`, `editorial`, `terminal-native`)
2. For each of ~4–6 primitives, call `mcp__shadcn__search_items_in_registries` with the tags as keywords:
   - `button`, `card`, `input`, `dialog`, `nav` / `navbar`, `table`
3. For matched items, call `mcp__shadcn__get_add_command_for_items` to produce install commands
4. **Print the commands. Never auto-run them.** The user decides what to install.

If a tag yields zero results, fall back to the bare primitive name without tag filtering — better to surface generic components than nothing.

### d. Audit (when components already exist)

If the project already has installed shadcn components, offer:

```
mcp__shadcn__get_audit_checklist
```

This produces a checklist future UI work can be measured against. Useful when the user is *adopting* a brand on an existing shadcn codebase rather than starting fresh.

## Tool reference

| Tool | Purpose |
|---|---|
| `mcp__shadcn__get_project_registries` | Detection — must succeed before anything else |
| `mcp__shadcn__search_items_in_registries` | Tag-driven component discovery |
| `mcp__shadcn__view_items_in_registries` | Preview a specific component before install |
| `mcp__shadcn__get_item_examples_from_registries` | Pull usage examples for context |
| `mcp__shadcn__get_add_command_for_items` | Generate the `npx shadcn add ...` command |
| `mcp__shadcn__get_audit_checklist` | Audit existing installations |

## Failure modes

See `../gotchas.md` gotcha #10 for the full failure-mode matrix.

## Why this is conditional

Other projects may use Vue, Svelte, SwiftUI, native HTML, or Flutter — none of which are shadcn-compatible. Surfacing shadcn on those would be noise. The detection check makes step 7 a true zero-cost no-op when it doesn't apply.
