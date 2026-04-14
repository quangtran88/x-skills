# Evidence Strength Hierarchy

Rank evidence when evaluating competing hypotheses. Higher tiers override lower tiers when they conflict.

| Tier | Type | Examples |
|------|------|---------|
| 1 (Strongest) | Controlled reproduction / direct experiment | Failing test that isolates the bug, minimal repro script |
| 2 | Primary source artifacts with tight provenance | Stack traces, error logs with timestamps, git blame, config diffs |
| 3 | Multiple independent sources converging | Logs + metrics + code path all pointing to the same cause |
| 4 | Single-source code-path inference | "This function returns null when X, which would explain Y" |
| 5 | Weak circumstantial | Timing correlation, similar bug in past, naming resemblance |
| 6 (Weakest) | Intuition / analogy / speculation | "This feels like the same kind of bug as..." |

## How to Use

- When ranking hypotheses, explicitly note which evidence tier supports each
- Down-rank a hypothesis when its strongest evidence is tier 4+ while a rival has tier 1-2 evidence
- A tier 1 piece of evidence (reproduction) that contradicts a hypothesis eliminates it, regardless of how many tier 5 clues support it
- "I have a feeling" (tier 6) is valid for generating hypotheses but never for confirming them
