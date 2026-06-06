# Step 1: Gather Context & Brainstorm Design

**Progress: Step 1 of 4** — Next: Plan

## Rules

- **READ COMPLETELY** before acting — do not start executing mid-read
- **FOLLOW SEQUENCE** — complete sections in order
- **NEVER** synthesize partial research results — wait for x-research's full envelope
- **HALT** at the user validation checkpoint — wait for confirmation before proceeding

## Goal

Two outputs depending on mode:

1. **Mode B (no plan/spec ref):** A user-approved `design.md` saved per the project's convention. Brainstorming is **mandatory** — per superpowers `brainstorming/SKILL.md:12-18`, every project (including those that feel simple) runs through this gate. Hidden assumptions are the #1 source of wasted work.
2. **Mode A or B with research signals:** A context envelope from `x-research` covering hidden requirements, conventions, related code.

Most Mode B work produces BOTH (design.md + research envelope when warranted).

## When to Skip

- Mode A (user already provided a plan/spec ref that exists on disk) → skip to `step-02-plan.md` if plan needs refinement, or `step-03-review.md` if plan is ready
- Mode D (trivial single-file change ≤ 10 lines) → skip the entire pipeline
- Brainstorm already completed in this session OR x-research handoff already in session → skip to `step-02-plan.md`
- User explicitly says "I've already designed this" / "skip brainstorm" → skip the brainstorming sub-step (research sub-step may still fire)

## Execution

### 1. Fire parallel detection (single message, multiple tools)

Before deciding what to dispatch, fan out two independent reads in parallel:

```
Agent (subagent_type=Explore, parallel):
  description: "Detect project doc convention"
  prompt: "Find where this project stores design / plan / spec docs. Check:
    - Existing files under docs/**/*.md, specs/**/*.md, plans/**/*.md
    - docs/superpowers/specs/ or docs/superpowers/plans/ paths
    - References in README / CONTRIBUTING / AGENTS.md / CLAUDE.md to spec location
    Return one absolute directory path to save new design.md under.
    If no convention exists, default to: docs/superpowers/specs/.
    Also return the plan-doc directory (often docs/superpowers/plans/).
    Report in under 100 words."
```

Pin the returned directories as `DESIGN_DIR` and `PLAN_DIR` for the rest of the task.

- [ ] **Memory recall** (only when `mcp.agentmemory` pinned in bootstrap-active set): in the same parallel batch, one `mcp__plugin_agentmemory_agentmemory__memory_smart_search({ query: <task keywords + project name>, limit: 5 })` call. Surface prior similar tasks as leads for the brainstorming / planning steps — do NOT auto-apply. **Apply consumer rules from `../../x-shared/mcp-toolbox.md § Consumer rules` — drop hits where `tags` includes `auto-import` OR `confidence < 0.5` before treating them as precedent.** When `mcp.agentmemory` is not pinned, **skip silently** — Claude's native auto-memory file still applies.

### 2. Research gate (optional — only when warranted)

Dispatch `Skill: x-skills:x-research` **only** when ANY of these hold:

- Unfamiliar library, framework, API, or external system involved
- "How does X work in our codebase?" must be answered before building
- User explicitly asks for research / investigation / understanding
- Requirements vague AND scope crosses 3+ modules

Otherwise SKIP — research-for-research's-sake adds latency without value. x-research owns its own multi-lane fan-out (`oracle ∥ OMO explore ∥ native Grep`) per `../x-research/references/prompt-templates.md` § Type F. Do NOT re-classify here.

When dispatched:

```
Skill: x-skills:x-research
args: Pre-planning consult for: {{user's request}}.
      Current codebase context: {{relevant files, stack, constraints}}.
      Identify hidden requirements, scope risks, AI-slop patterns,
      existing related code, and conventions to follow.
```

### 3. Brainstorming (Mode B only — MANDATORY when no plan/spec ref)

When mode is B and the user did NOT provide a plan/spec path:

```
Skill: superpowers:brainstorming
args: {{user's idea}}.
      Save the design doc to: {{DESIGN_DIR}}/YYYY-MM-DD-<slug>-design.md
      Convention detected from project layout in step 1.
```

`brainstorming` produces a design.md following its 9-step workflow (explore → clarifying questions → 2-3 approaches → design doc → spec self-review → user reviews spec). The `superpowers:writing-plans` step in `step-02-plan.md` will be invoked by `brainstorming` automatically at its terminal step, OR you can chain it yourself in step-02.

**Why mandatory:** superpowers `brainstorming/SKILL.md:12-18` Iron Law — "Do NOT invoke any implementation skill...until you have presented a design and the user has approved it." The "too simple to design" exception is explicitly rejected.

### 4. Capture commit-recompose hint (optional, router-only)

If the user mentioned a commit-grouping preference (e.g., "keep granular commits", "squash by feature", "one commit per domain"), persist as `commit_recompose_hint` in run state. Allowed values: `"preserve"` (skip recompose) or `"axis:<topic|domain|feature|item>"`. Step-04 reads this before dispatching the `commit` skill.

### 5. User validation checkpoint (AskUserQuestion)

After all parallel dispatches return, surface ONE question:

```
AskUserQuestion:
  question: "Design + context match your intent? Ready to write the plan?"
  options:
    - label: "Proceed to plan-writing"
      description: "Design.md and research findings (if any) look good — go to step-02-plan.md"
    - label: "Revise the design"
      description: "Re-run brainstorming with adjustments"
    - label: "Add more context"
      description: "Run x-research with a more specific question first"
```

**Wait for explicit confirmation** before proceeding.

## Output

- Mode B: `design.md` saved at `${DESIGN_DIR}/YYYY-MM-DD-<slug>-design.md`
- Optional: x-research context envelope
- Pinned variables: `DESIGN_DIR`, `PLAN_DIR`, optional `commit_recompose_hint`
- User confirmation to proceed

## Next Step

Proceed to `step-02-plan.md` with the design.md path and pinned directories.
