# x-skill-improve — Skill Improvement

> **Purpose:** Evaluates how well an x-skill was followed during a real session, then improves the skill based on findings.

---

## Workflow (5 Steps)

```
Step 1: Locate Session
  ├─ Use session_search MCP tool to find sessions where target skill was invoked
  ├─ Parse arguments per references/argument-parsing.md
  └─ Search and extract per references/session-discovery.md

Step 2: Load Skill Files
  ├─ Read full skill directory (SKILL.md, steps/, references/, gotchas.md, config.json)
  └─ Build instruction inventory — list of every rule, gate, checklist, workflow step

Step 3: Analyze Alignment
  ├─ Walk instruction inventory
  ├─ Classify each item: Followed / Deviated / Skipped / Worked Around / N/A
  └─ Focus on high-signal misalignments (mandatory gates skipped, repeated patterns)

Step 4: Dual-Perspective Findings
  ├─ For each misalignment:
  │   - What the skill says (quote instruction)
  │   - What the session did (describe actual behavior)
  │   - Verdict: UPDATE SKILL or COMPLIANCE GAP
  │   - Recommendation: specific proposed change

Step 5: Present Report
  └─ Use template from references/output-template.md
```

---

## Verdict Types

| Verdict | Meaning |
|---------|---------|
| **UPDATE SKILL** | The skill is wrong, incomplete, or too rigid. The execution was reasonable. |
| **COMPLIANCE GAP** | The skill is right. The execution should have followed it. |

---

## Applying Fixes

- For `x-*` skills: edit the **source repo** (never plugin cache)
- Default edit tool: `morph-mcp edit_file`
- UPDATE SKILL: Make targeted edits (add exceptions, add gotchas, add missing guidance)
- COMPLIANCE GAP: No skill change; optionally add to gotchas.md as reminder

---

## Persistence

Append summary line to `data/alignment-log.jsonl`:
```json
{"skill":"x-bugfix","sessionId":"f7035623","date":"2026-04-01","findings":8,"updateSkill":3,"complianceGap":5,"applied":true}
```

---

## Dependencies

- `session_search` MCP tool from oh-my-claudecode plugin (falls back to JSONL-direct read)
- `../x-shared/invocation-guide.md`, `severity-guide.md`, `workflow-chains.md`
