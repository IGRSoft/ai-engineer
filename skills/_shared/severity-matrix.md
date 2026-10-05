# Severity Matrix Reference

Severity levels, P0-P3 finding priorities, effort/impact ranking, code-smell thresholds, and coverage floors.

## Review Finding Priorities (P0-P3)

Used by the review and implementation response formats of all ai-engineer agents. Each priority maps to one severity level.

| Priority | Severity | Definition | Response | AI Examples |
|----------|----------|------------|----------|-------------|
| P0 | Critical | Must fix before merge — correctness/security broken | Immediate | Prompt injection path from untrusted input (worst when it reaches a privileged action), leaked secrets/API keys (in code, prompts, logs, or datasets), unsafe deserialization (pickle from an untrusted source), `eval`/`exec` on model output, eval-gate hard regression, training-data PII exposure, failing tests |
| P1 | High | Fix in this change — defect likely to bite | Within sprint | Eval regression above threshold, unpinned model revision in a production path, missing output validation on model responses, ungated tool execution in agent loops, train/test contamination |
| P2 | Medium | Should fix — quality/maintainability | Quarterly | Missing retries/fallbacks on provider calls, unbounded token spend, missing experiment tracking, chunking/retrieval quality smells, weak test coverage on changed code |
| P3 | Low | Nice to have — style | Opportunistic | Formatting, naming, docs polish, minor reproducibility gaps (auto-fixable via ruff or a config pin) |

## Priority Matrix (effort/impact quadrant)

| Priority | Impact | Effort | Action |
|----------|--------|--------|--------|
| P0 | Critical | Any | Immediate remediation |
| P1 | High | Low | Do first (quick wins) |
| P2 | High | High | Plan and schedule |
| P3 | Low | Low | Batch together |
| — | Low | High | Avoid |

## Code Smell Indicators

| Smell | Thresholds | Impact |
|-------|------------|--------|
| Long function | >30 lines (Python) | Hard to understand/test |
| Large module | >500 lines | Difficult to maintain |
| Monolithic prompt | >2k tokens without sections/versioning | Hard to iterate and eval |
| Cyclomatic complexity | >10 | Error-prone |
| Nesting depth | >3 levels | Reduced readability |
| Parameters | >5 | Hard to use correctly |
| Hardcoded hyperparameters | Any untracked in config/tracker | Irreproducible runs |
| Code duplication | >5% | Maintenance burden |

## Coverage Requirements

| Scope | Minimum | Target |
|-------|---------|--------|
| Critical paths (prompt assembly, tool dispatch, data loaders) | 90% | 95%+ |
| Business logic | 75% | 80%+ |
| Utilities | 60% | 70%+ |
| CLI surfaces / glue scripts | 50% | 60%+ |
