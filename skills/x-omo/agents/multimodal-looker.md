# Multimodal Looker — Visual & Document Analysis

## Identity

Analyzes media files (PDFs, images, diagrams) that require interpretation beyond raw text. Extracts specific information, describes visual content, and returns only the relevant data — saving context tokens by keeping raw file content out of the main conversation.

## Quick Reference

| Field | Value |
|---|---|
| Short name | `multimodal-looker` |
| OpenCode display name | `multimodal-looker` |
| Default model | `openai/gemini-3.1-pro-preview` |
| Mode | Read-only (only `read` tool allowed) |
| Temperature | 0.1 |
| Cost tier | CHEAP |

## When to Use

- PDF documents needing text/table/data extraction
- Images with UI mockups, diagrams, or screenshots to interpret
- Architecture diagrams that need to be described as text
- Charts/graphs needing data extraction
- Any media file the Read tool cannot interpret as plain text

## When NOT to Use

- Source code or plain text files (use Read directly)
- Files that need editing afterward (need literal content from Read)
- Simple file reading where no interpretation is needed
- **Image/PDF analysis where Claude's native Read tool works** — Claude Code can read images natively

## Prompt Template

```bash
~/.claude/skills/x-omo/omo-agent multimodal-looker --file /path/to/file.pdf "Extract the API endpoint specifications from this document. Focus on: URL patterns, HTTP methods, request/response schemas, and authentication requirements."
```

**Key:** Always attach the file via `--file` flag and describe what to extract in the prompt.

## Example Prompts

### PDF Data Extraction
```bash
~/.claude/skills/x-omo/omo-agent multimodal-looker --file docs/api-spec.pdf "Extract all REST API endpoints from this specification. Return as a markdown table with columns: Method, Path, Description, Auth Required."
```

### UI Mockup Analysis
```bash
~/.claude/skills/x-omo/omo-agent multimodal-looker --file designs/dashboard-v2.png "Describe this dashboard mockup in detail. List all UI components visible, their layout (grid positions), data they display, and any interactive elements (buttons, dropdowns, etc.). I need this to implement the frontend."
```

### Architecture Diagram
```bash
~/.claude/skills/x-omo/omo-agent multimodal-looker --file docs/system-architecture.png "Describe this architecture diagram. List all services/components, their connections, data flow direction, and any labeled protocols or technologies. Return as structured markdown."
```

## Output Format

Returns extracted information directly — no preamble, no wrapper. The output goes straight to the main agent for continued work.

- For PDFs: extracted text, structure, tables, data from specific sections
- For images: described layouts, UI elements, text, diagrams, charts
- For diagrams: explained relationships, flows, architecture
- If info not found: states clearly what's missing

## Tool Access

Multimodal Looker has extremely restricted tool access — it can ONLY use `read`. This is intentional: it reads and interprets the file, then returns its analysis as text.

## Note on Claude's Native Vision

Claude Code can read images natively via the Read tool. Use multimodal-looker when:
- You specifically want Gemini's vision capabilities
- The file format is better handled by Gemini
- You want to keep the raw file content out of the main Claude context
