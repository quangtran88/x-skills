# Severity Guide (Shared)

All review and audit findings across x-skills use this consistent severity scale.

| Severity | Meaning | Action | Examples |
|----------|---------|--------|----------|
| **CRITICAL** | Security vulnerability, data loss risk, crash in production path | Fix immediately, block merge | SQL injection, exposed secrets, null deref in hot path, missing SKILL.md |
| **HIGH** | Logic defect, spec deviation, broken functionality, significant best-practice gap | Fix before merge | Wrong return value, missing validation, race condition, no progressive disclosure |
| **MEDIUM** | Quality concern, maintainability issue, test gap, missing recommended element | Should fix, can negotiate | Missing error handling, no test for edge case, no gotchas section, hardcoded paths |
| **LOW** | Style preference, minor improvement, documentation, polish | Optional, author's call | Variable naming, comment wording, description not trigger-specific |

## Triage Rules

- **CRITICAL + HIGH** = must fix before marking review/audit complete
- **MEDIUM** = recommend fixing, but author can defer with justification
- **LOW** = note it, don't block on it
- If a finding's severity is ambiguous, lean toward the higher severity
