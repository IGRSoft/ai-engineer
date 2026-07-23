---
name: severity-matrix
description: Reusable severity and priority definitions for ai-engineer commands and agents
---

# Severity Matrix Reference

Shared definitions for severity levels, priority matrices, and effort/impact assessments.

## Severity Levels

| Level | Description | Response Time | AI Examples |
|-------|-------------|---------------|-------------|
| Critical | Security, data integrity, system down | Immediate | Prompt injection reaching a privileged action, leaked API key in code/prompt/log/dataset, pickle load of an untrusted checkpoint, training-data PII exposure |
| High | Performance blockers, major functionality | Within sprint | Eval regression above threshold, ungated tool execution in an agent loop, unpinned model revision in a production path, train/test contamination |
| Medium | Code quality, minor performance | Quarterly | Missing retries/fallbacks on provider calls, unbounded token spend, missing experiment tracking, weak chunking/retrieval strategy |
| Low | Style, nice-to-have | Opportunistic | Formatting drift, naming, missing docstring, minor reproducibility gaps |

## Review Finding Priorities (P0-P3)

Used by the Implementation/Review response formats of all ai-engineer agents:

| Priority | Definition | AI Examples |
|----------|------------|-------------|
| P0 | Must fix before merge — correctness/security broken | Prompt injection path from untrusted input, leaked secrets/API keys (in code, prompts, logs, or datasets), unsafe deserialization (pickle from untrusted source), eval-gate hard regression, training-data PII exposure, failing tests |
| P1 | Fix in this change — defect likely to bite | Eval regression above threshold, unpinned model revision in a production path, missing output validation on model responses, ungated tool execution in agent loops, train/test contamination |
| P2 | Should fix — quality/maintainability | Missing retries/fallbacks, unbounded token spend, missing experiment tracking, chunking/retrieval quality smells, weak test coverage on changed code |
| P3 | Nice to have — style | Formatting, naming, docs polish, minor reproducibility gaps (auto-fixable via ruff or a config pin) |

## Priority Matrix (impact × effort)

| Priority | Impact | Effort | Action |
|----------|--------|--------|--------|
| P0 | Critical | Any | Immediate remediation |
| P1 | High | Low | Do first (quick wins) |
| P2 | High | High | Plan and schedule |
| P3 | Medium | Low | Batch together |
| P4 | Low | High | Deprioritize or skip |

## Effort/Impact Quadrant

```
High Impact ┌──────────────┬──────────────┐
            │   SCHEDULE   │  DO FIRST    │
            │  (P2: Plan)  │ (P1: Quick)  │
            ├──────────────┼──────────────┤
            │    AVOID     │  FILL-INS    │
            │ (P4: Defer)  │ (P3: Batch)  │
Low Impact  └──────────────┴──────────────┘
             High Effort    Low Effort
```

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

## Usage

Reference this file in commands using:
```markdown
See: skills/_shared/severity-matrix.md for severity definitions
```
