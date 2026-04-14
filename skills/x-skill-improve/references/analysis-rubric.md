# Analysis Rubric

What to check when analyzing session alignment for each x-skill.

## Universal Checks (All x-skills)

These apply regardless of which skill was used:

| Check | What to Look For |
|-------|-----------------|
| **Skill detection** | Was the correct mode/type/target identified? |
| **Pre-flight checklist** | Were mandatory pre-flight items completed? |
| **Invocation correctness** | Were OMO agents invoked via Bash (not Agent tool)? Were OMC agents invoked via Agent tool? |
| **Background result collection** | Were all background agent results collected before synthesis? |
| **Verification gate** | Was verification run before claiming completion? |
| **Gotchas awareness** | Were known gotchas from gotchas.md avoided? |
| **Workflow chain** | Was the recommended next skill suggested? |

## x-do Specific

| Check | What to Look For |
|-------|-----------------|
| **Mode classification** | Was the correct mode (A-E) detected? |
| **Research gate** | Was research needed? Was it done or skipped? |
| **Plan review gate** | For 3+ tasks: was cross-model plan review run? |
| **Post-implementation review** | Were all 3 reviewers launched in one message? |
| **Ralph for 3+ tasks** | Was ralph used (not manual batch edits) for 3+ tasks? |
| **Complexity scaling** | Was ceremony scaled appropriately to task size? |
| **TS/ESLint verification** | For TS/JS projects: were typecheck and lint run? |
| **Step file reading** | Were step files read one at a time (not all at once)? |

## x-research Specific

| Check | What to Look For |
|-------|-----------------|
| **Type classification** | Was the correct research type (A-F) detected? |
| **Agent selection** | Were appropriate OMO agents dispatched for the type? |
| **Parallel execution** | Were independent agents launched in parallel? |
| **Synthesis quality** | Were all agent results collected and synthesized? |
| **Handoff offered** | Was x-do handoff offered when research supports implementation? |

## x-review Specific

| Check | What to Look For |
|-------|-----------------|
| **Target detection** | Was the correct target (A-D) identified? |
| **Cross-model review** | Were multiple reviewers launched (Claude + GPT perspectives)? |
| **All results collected** | Were all reviewer results waited for before synthesis? |
| **Findings format** | Were findings presented with severity ratings? |
| **Fix offering** | Was the user offered to fix issues? |

## x-skill-review Specific

| Check | What to Look For |
|-------|-----------------|
| **Full directory read** | Was the entire skill directory read (not just SKILL.md)? |
| **Checklist scored** | Was each checklist item scored PASS/FAIL/N/A? |
| **Skill type classified** | Was the skill type identified from skill-types.md? |
| **Fix offering** | Was the user offered to fix findings? |

## x-skill-improve Specific

| Check | What to Look For |
|-------|-----------------|
| **Argument parsing** | Were session ID, project dir, and skill name correctly detected from positional args? |
| **workingDirectory consistency** | Was workingDirectory passed to ALL session_search calls (not just later batches)? |
| **Search parallelism** | Were auto-detect/discovery queries launched in parallel (single message)? |
| **Fallback ladder** | When session_search failed, was JSONL-direct tried before paste? |
| **Full skill directory read** | Were ALL files in the target skill directory actually read (not just claimed)? |
| **Instruction inventory** | Was every rule/gate/checklist item from the target skill tracked in analysis? |
| **Dual-perspective format** | Does each finding quote the instruction AND describe the session behavior? |
| **Output template compliance** | Does the report match references/output-template.md structure? |
| **Fix application restraint** | Were fixes targeted (exceptions, gotchas) rather than bloating SKILL.md? |
| **Workflow chain** | Was /x-skill-review offered after fixes were applied? |

## Weighting

Not all checks are equal. When building findings:

- **Mandatory gates skipped** → CRITICAL or HIGH (these exist to prevent real problems)
- **Wrong agent invocation** → HIGH (silently degrades to wrong model)
- **Missing verification** → HIGH (claiming done without evidence)
- **Workflow deviations** → MEDIUM (may be justified by context)
- **Missing suggestions** → LOW (nice to have, not blocking)
