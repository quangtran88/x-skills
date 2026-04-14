# Iteration Patterns — Concepts from ClaudeKit's ck:loop

Apply these when running iterative loops (ralph, ultrawork, or manual retry cycles).

## 1. Git-Revert-as-Memory

When discarding a failed change, use `git revert HEAD --no-edit` instead of `git reset --hard HEAD~1`.

**Why:** Revert preserves the failed attempt in git history. On the next iteration, `git log --oneline -20` shows what was already tried and failed — the agent learns from history instead of repeating mistakes.

**Fallback:** If revert conflicts, use `git reset --hard HEAD~1` for that iteration only.

## 2. Stuck Detection

Track consecutive iterations without progress. When an approach isn't working, pivot instead of grinding.

### What counts as progress

| Signal | Counts as progress when |
|---|---|
| **Test state** | Any test moved red→green or green→red since last iteration |
| **File state** | Any file was modified with a non-empty diff |
| **Error state** | A previously-failing tool call succeeded, OR a new distinct error message appeared |

If **none** of these changed → that iteration produced no progress.

### What counts as an iteration

One iteration = one mutating tool call (`Edit`/`Write` or mutating `Bash`) + one verification call (test/lint/tsc or reading the edited file). Read-only exploration doesn't count — the guard only tracks mutate+verify pairs.

### Escalation ladder

| No-progress iterations | Action |
|---|---|
| 3 | **Pause.** Re-read last 5 tool outputs in full (no summarization). State the actual blocker in one sentence, plain English. If you can name a different approach, try it. |
| 5 | **Pivot.** Delegate to `oracle` or `hephaestus` for a fresh perspective. State what you tried and why it failed. |
| 7 | **STOP.** Surface to user: state the blocker, list what was tried, propose 2-3 genuinely different alternatives. Wait for user input before continuing. |

*Threshold rationale:* 3 is lenient enough to avoid false positives on slow-but-valid work. 7 is the hard stop — beyond that, the agent is burning tokens. If 3 triggers too often on healthy runs, raise to 4. If stagnation is caught too late, lower 7 to 5. Re-evaluate after one week of usage.

## 3. Auto-Revert on Guard Failure

When a change passes the primary check but breaks something else (types, tests, lint):

1. Run guard command after the primary change
2. If guard fails → revert the change immediately
3. Max 2 rework attempts before discarding
4. Log why it failed so it's not repeated

## 4. TSV Tracking (optional, for metric-driven work)

When iterating toward a numeric goal (coverage, bundle size, error count), track progress:

```
iter	timestamp	metric	delta	kept	description
0	2026-03-31T10:00:00	60.0	+0.0	yes	baseline
1	2026-03-31T10:01:30	62.4	+2.4	yes	add null checks to parser.ts
2	2026-03-31T10:02:45	61.9	-0.5	no	extract helper function (reverted)
```

Save to `loop-results.tsv` in the working directory. Helps identify what's working and what isn't.

## When to Apply

- **Ralph loops** with 5+ stories — use stuck detection + git-revert-as-memory
- **Bug fix retries** (Mode C) — use auto-revert on guard failure
- **Metric improvement** tasks — use all 4 patterns including TSV tracking
- **Quick tasks** (Mode D) — skip all of this
