# Debug Report Template

Output this structured report after every fix. Adapt sections based on mode — Mode B includes the evidence trail, Mode C includes the timeline.

```
## Debug Report
- **Symptom:** [what the user observed]
- **Root cause:** [what was actually wrong and WHY]
- **Evidence:** [how root cause was confirmed — test output, logs, reproduction]
- **Fix:** [what was changed, with file:line references]
- **Regression test:** [file:line of the new test]
- **Blast radius:** [N files changed, modules affected]
- **Related:** [prior bugs in same area, architectural notes]
```

## Mode B Addition (Deep Investigation)

Add after the standard report:

```
### Investigation Trail
- **Hypotheses tested:** [list with verdict: confirmed/eliminated/inconclusive]
- **Key evidence:** [what confirmed the root cause over alternatives]
- **Eliminated causes:** [what was ruled out and why]
```

## Mode C Addition (System/Infra)

Add after the standard report:

```
### Timeline
- **First observed:** [timestamp]
- **Root cause introduced:** [timestamp, correlating event]
- **Service restored:** [timestamp]
- **Preventive measures:** [monitoring/alerting changes]
```
