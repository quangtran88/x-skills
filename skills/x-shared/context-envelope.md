# Context Envelope

Optional convention for passing context between x-skills. Include this block when the "After This Skill" section routes to the next skill.

## Format

```
## Handoff Context
- **From:** [skill name] | **Type/Mode:** [classification used]
- **Key finding:** [one-liner summary of what was learned/decided]
- **Agents used:** [list of agents that contributed]
- **Recommendation:** [next skill + mode/type to use]
- **Artifacts:** [file paths of any documents produced]
```

## Examples

After x-research (Type F: Pre-Planning):
```
## Handoff Context
- **From:** x-research | **Type:** F (Pre-Planning)
- **Key finding:** Auth system needs RBAC, current implementation only has binary auth
- **Agents used:** metis, explore
- **Recommendation:** x-do Mode B (new feature)
- **Artifacts:** none (findings synthesized above)
```

After x-do (Mode B: New Feature):
```
## Handoff Context
- **From:** x-do | **Mode:** B (New Feature)
- **Key finding:** RBAC implemented with 3 roles, 47 files changed
- **Agents used:** ralph (12 stories), code-reviewer
- **Recommendation:** x-review Target C (branch diff vs main)
- **Artifacts:** docs/superpowers/plans/2026-03-29-rbac.md
```
