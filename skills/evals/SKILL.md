---
name: evals
description: >-
  Evaluation skills navigation: eval design (assertion→metric→judge→human
  hierarchy, task-grounded eval sets, honest comparison), LLM-as-judge
  (anchored rubrics, bias mitigation, calibration against humans), and CI
  regression gates (thresholds, baselines, pytest wiring). Use when measuring
  LLM quality, building or expanding an eval set, grading outputs with a
  judge, comparing prompts or models, or gating prompt/model/retrieval changes
  in CI so quality cannot silently regress.
---

# Eval Skills

**Navigation and determinism snapshot for measuring LLM quality — design the
measurement, grade with a judge, gate the regression**

## Determinism Snapshot

| Concern | Mechanism | Note |
|---------|-----------|------|
| Eval sets | Versioned JSONL (`evals/sets/<name>-vN.jsonl`), harvested from real traffic | Version pinned in every reported metric |
| Reproducibility | Temperature 0, fixed seeds, pinned judge config | A metric without its eval-set + judge version is noise |
| Harness | pytest as the spine; metrics written as artifacts | Compared against a stored baseline, not memory |
| Judges | LLM judge with structured output, calibrated to human labels | Uncalibrated "rate 1-10" judges never gate |
| Cost control | Tiered subsets: smoke (PR) → full (nightly/release) | Judge model choice is a cost ladder — verify current options via context7 |

Language-level pytest mechanics (fixtures, parametrization, coverage) are not
re-taught here — see `system-developer:python-skills` (python-testing).

## Skill Selection Guide

| I need to... | Use this skill |
|--------------|----------------|
| Decide what and how to measure for an LLM feature | [eval-design/SKILL.md](eval-design/SKILL.md) |
| Build or expand an eval set; size it for a decision | [eval-design/SKILL.md](eval-design/SKILL.md) |
| Compare two prompts or models without fooling myself | [eval-design/SKILL.md](eval-design/SKILL.md) (paired comparison) |
| Grade a dimension code cannot check (tone, faithfulness) | [llm-judge/SKILL.md](llm-judge/SKILL.md) |
| Fix a judge that disagrees with humans or drifts | [llm-judge/SKILL.md](llm-judge/SKILL.md) (calibration) |
| Start from a working judge prompt + schema | [llm-judge/references/judge-prompt-templates.md](llm-judge/references/judge-prompt-templates.md) |
| Add eval gates to CI; pick thresholds | [regression-gates/SKILL.md](regression-gates/SKILL.md) |
| Handle a flaky gate or update a baseline after an accepted win | [regression-gates/SKILL.md](regression-gates/SKILL.md) |

## Decision Tree

```
Eval task?
├── What/how to measure, building or sizing the set → eval-design/SKILL.md
├── Quality dimension code cannot check → llm-judge/SKILL.md
│   └── Working prompt + output schema → llm-judge/references/judge-prompt-templates.md
├── Wiring evals into CI (thresholds, baselines, flakes) → regression-gates/SKILL.md
├── Retrieval-specific metrics (recall@k, MRR)
│   → ${CLAUDE_SKILL_DIR}/llm-apps/rag-systems/references/retrieval-evaluation.md
├── Logging eval runs / tracing a reported metric
│   → ${CLAUDE_SKILL_DIR}/mlops/experiment-tracking/SKILL.md
└── Judge evals on live production traffic
    → ${CLAUDE_SKILL_DIR}/mlops/model-monitoring/SKILL.md
```

## File Overview

| File | Purpose |
|------|---------|
| [_index.md](_index.md) | Full navigation for the evals/ subtree |
| [eval-design/SKILL.md](eval-design/SKILL.md) | Metric hierarchy, eval-set construction, paired comparison, statistical honesty |
| [eval-design/references/eval-methodology.md](eval-design/references/eval-methodology.md) | Deep dive: eval-set construction, metric selection, A/B protocol, statistics |
| [llm-judge/SKILL.md](llm-judge/SKILL.md) | Judge selection, rubrics, bias mitigations, calibration, judge regression tests |
| [llm-judge/references/judge-prompt-templates.md](llm-judge/references/judge-prompt-templates.md) | Complete judge prompts + output schemas to start from |
| [regression-gates/SKILL.md](regression-gates/SKILL.md) | Gate ladder, thresholds, baseline ritual, flake policy, pytest integration |
| [regression-gates/references/gate-implementation.md](regression-gates/references/gate-implementation.md) | Deep dive: thresholds, baselines, flake policy, pytest wiring, escape hatch |

## Related Skills

- [prompt-design](${CLAUDE_SKILL_DIR}/prompt-engineering/prompt-design/SKILL.md) — the prompts these evals gate
- [rag-systems](${CLAUDE_SKILL_DIR}/llm-apps/rag-systems/SKILL.md) — faithfulness and retrieval quality as eval targets
- [dataset-curation](${CLAUDE_SKILL_DIR}/finetuning/dataset-curation/SKILL.md) — decontamination: training data must never leak into eval sets
- [model-monitoring](${CLAUDE_SKILL_DIR}/mlops/model-monitoring/SKILL.md) — production failures feeding back into eval sets

**Owning agent:** `ai-engineer:ai-test-generator` (pytest + LLM eval
harnesses). Eval strategy at the architecture level →
`ai-engineer:ai-architector`; pytest/fixture depth →
`system-developer:python-skills`.
