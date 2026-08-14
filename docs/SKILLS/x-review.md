# x-review — Review Orchestrator

> **Role:** `reviewer`  
> **Purpose:** Code/plan/PR review orchestrator — cross-model review with Claude + your configured OMO models, structured verdicts.

---

## Role Forbid Block

```
x-review MUST NOT:
- Call Edit or Write during review phase (steps 1-3)
- Propose "while I'm here, let me just fix this" inline fixes
- Run mutating Bash during review phase

Exception — Fix Mode: When user explicitly requests fixes after REQUEST_CHANGES,
enter Fix Mode (step 4). Edit/Write/mutating Bash permitted via receiving-code-review workflow.
```

---

## Workflow (4 Steps)

```
Step 1: Prepare (step-01-prepare.md)
  ├─ Detect target type:
  │   A: Plan/Spec (.md in specs/plans/docs)
  │   B: Code/Files (file paths)
  │   C: Git Diff ("last commit", "staged", "this PR")
  │   D: No Target (auto-detect from git state)
  └─ Construct content/diff for review

Step 2: Review (step-02-review.md)
  ├─ **Target A (Plan/Spec):** Launch 3 reviewers in ONE MESSAGE:
  │   1. Agent tool: subagent_type="oh-my-claudecode:code-reviewer", model="opus" — Claude perspective
  │   2. Bash tool: one `omo-agent --model <id>` lane per `review_models` entry (staggered 3s), same blocker-finder prompt each — OKAY/REJECT verdict. Empty list → single `omo-agent oracle` lane. Replaces UNAVAILABLE `momus` role agent.
  │   3. Skill tool: superpowers:requesting-code-review — structured review workflow
  │   (Architecture-sensitive plans: extend the oracle prompt — no extra lane)
  ├─ **Targets B/C/D (Code/Files/Diff):** Launch 3 reviewers in ONE MESSAGE:
  │   1. Agent tool: subagent_type="oh-my-claudecode:code-reviewer", model="opus" — Claude perspective
  │   2. Bash tool: one `omo-agent --model <id>` lane per `review_models` entry (staggered 3s), same review prompt each. Empty list → single `omo-agent oracle` lane.
  │   3. Skill tool: superpowers:requesting-code-review — structured review workflow
  ├─ Wait for ALL background notifications
  └─ Collect all results before proceeding
  ├─ Launch 3 reviewers in ONE MESSAGE (all tool calls in single response):
  │   1. Agent tool: subagent_type="oh-my-claudecode:code-reviewer", model="opus" — Claude perspective
  │   2. Bash tool: one `omo-agent --model <id>` lane per `review_models` entry (staggered 3s). Empty list → single `omo-agent oracle` lane.
  │   3. Skill tool: superpowers:requesting-code-review — structured review workflow
  ├─ Wait for ALL background notifications
  └─ Collect all results before proceeding

Step 3: Synthesize (step-03-synthesize.md)
  ├─ Verify findings
  ├─ Synthesize cross-model perspectives
  └─ Present structured verdict

Step 4: Act (step-04-act.md)
  ├─ Additional passes menu
  ├─ Verdict routing
  └─ Fix Mode (if user requests fixes)
```

---

## Cross-Model Review Pattern

The **one-message launch** is critical for compliance. All 3 reviewers must be dispatched in a single assistant response:

```
Tool: Agent(subagent_type="oh-my-claudecode:code-reviewer", model="opus", run_in_background=true)
Tool: Bash(command="omo-agent --model <review_models[0]> '...'", run_in_background=true, timeout=600000)
Tool: Bash(command="sleep 3 && omo-agent --model <review_models[1]> '...'", run_in_background=true, timeout=600000)
Tool: Skill(skill="superpowers:requesting-code-review")
```

---

## Dependencies

- **x-omo** — bootstrap + `oracle` agent for the non-Claude perspective (model set by the user's OMO config)
- **x-shared** — severity-guide, invocation-guide, context-envelope, workflow-chains
- **superpowers** — code-reviewer, requesting-code-review, receiving-code-review, verification-before-completion, finishing-a-development-branch
