# Output Template

Use this format when presenting alignment findings.

```
## Skill Alignment: {{skill name}} ({{mode/type if applicable}})

**Session summary:** {{1-line what the session accomplished}}
**Skill files analyzed:** {{count}} ({{file list}})
**Instructions checked:** {{total}} ({{followed}} followed, {{issues}} issues found)

### Findings

| # | Severity | Instruction | Session Did | Verdict | Recommendation |
|---|----------|-------------|-------------|---------|----------------|
| 1 | HIGH | "Run plan review for 3+ tasks" | Skipped, went to ralph | UPDATE SKILL | Add urgent-skip exception |
| ... | ... | ... | ... | ... | ... |

### Summary
- {{X}} UPDATE SKILL, {{X}} COMPLIANCE GAP
- Top improvements by impact: ...

### Proposed Updates ({{count}})
1. [file:location] Description of change
2. ...

Apply? [A] All  [P] Pick which  [N] Done
```
