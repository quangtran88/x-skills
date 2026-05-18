# x-review — Review Orchestrator

> **Role:** `reviewer`  
> **Purpose:** Code/plan/PR review orchestrator — cross-model review with Claude + GPT perspectives, structured verdicts.

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
  │   2. Bash tool: omo-agent --model gpt "<plan blocker-finder prompt>" — GPT-5.5 blocker-finder (OKAY/REJECT verdict). Replaces UNAVAILABLE `momus` role agent.
  │   3. Skill tool: superpowers:requesting-code-review — structured review workflow
  │   (Optional 4th: omo-agent oracle for architecture-sensitive plans)
  ├─ **Targets B/C/D (Code/Files/Diff):** Launch 3 reviewers in ONE MESSAGE:
  │   1. Agent tool: subagent_type="oh-my-claudecode:code-reviewer", model="opus" — Claude perspective
  │   2. Bash tool: omo-agent oracle "<review prompt with diff/file content>" — GPT perspective
  │   3. Skill tool: superpowers:requesting-code-review — structured review workflow
  ├─ Wait for ALL background notifications
  └─ Collect all results before proceeding
  ├─ Launch 3 reviewers in ONE MESSAGE (all tool calls in single response):
  │   1. Agent tool: subagent_type="oh-my-claudecode:code-reviewer", model="opus" — Claude perspective
  │   2. Bash tool: omo-agent oracle "<review prompt>" — GPT perspective
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
Tool: Bash(command="omo-agent oracle '...'", run_in_background=true, timeout=600000)
Tool: Skill(skill="superpowers:requesting-code-review")
```

---

## Dependencies

- **x-omo** — bootstrap + oracle agent for GPT perspective
- **x-shared** — severity-guide, invocation-guide, context-envelope, workflow-chains
- **superpowers** — code-reviewer, requesting-code-review, receiving-code-review, verification-before-completion, finishing-a-development-branch
