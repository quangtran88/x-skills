# OMO Planning Pipeline

Use when requirements are ambiguous, cross 3+ modules, or the user provides only a vague idea.

## Step Files

The pipeline is implemented as step files in `../steps/`. Read one step at a time — do not load multiple simultaneously.

| Step | File | Goal | Skip When |
|------|------|------|-----------|
| 1 | `steps/step-01-gather.md` | Parallel `oracle` + `explore` (replaces UNAVAILABLE `metis`) | Requirements already clear |
| 2 | `steps/step-02-plan.md` | Create structured plan | — |
| 3 | `steps/step-03-review.md` | Cross-model plan review (ABS) | Plan has < 3 tasks AND single module |
| 4 | `steps/step-04-execute.md` | Ralph or direct execution | — |

## When to Skip the Pipeline Entirely

- Single task → use `--model codex` (replaces UNAVAILABLE `hephaestus`) or direct execution
- Requirements already clear + small scope → go straight to step-02-plan.md
- User already brainstormed in a prior session → pick up at step-02-plan.md
