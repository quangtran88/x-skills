# Mode C: System/Infra Investigation

For CI/CD failures, deployment issues, performance degradation, and server-level problems where the bug isn't in application code.

## When to Use

- CI/CD pipeline failures
- Server returning 500 errors or unexpected responses
- Performance degradation or latency spikes
- Environment-specific failures (works locally, breaks in staging/prod)
- Database issues (slow queries, connection exhaustion, migration failures)

## Phase 1: Initial Assessment

Gather scope and impact before diving in:
- **Collect symptoms** — error messages, affected endpoints, user reports
- **Identify affected components** — which services, databases, queues involved?
- **Determine timeframe** — when did it start? Correlate with deployments
- **Assess severity** — users affected? Data at risk?

## Phase 2: Data Collection

Gather evidence systematically:
- Server/application logs (filter by timeframe)
- CI/CD pipeline logs (`gh run view <run-id> --log-failed`)
- Database state (recent migrations, query performance)
- System metrics (CPU, memory, disk, network)
- External dependencies (third-party API status)

## Phase 3: Analysis & Root Cause

1. **Timeline reconstruction** — order events chronologically across all log sources
2. **Pattern identification** — recurring errors, timing patterns, affected user segments
3. **Systematic elimination** — list hypotheses ranked by evidence, test each

## Phase 4: Fix & Verify

Prioritize: restore service first, then fix root cause, then prevent recurrence.

1. **Immediate fix** — minimum change to restore service (hotfix, rollback, config)
2. **Root cause fix** — address underlying issue permanently
3. **Preventive measures** — monitoring, alerting, validation to catch recurrence
4. **Verification plan** — confirm fix works in the target environment
