---
name: evals
description: >-
  Evaluation skills navigation: eval design (assertion→metric→judge→human
  hierarchy, task-grounded eval sets, honest comparison), LLM-as-judge
  (anchored rubrics, bias mitigation, calibration), and CI regression gates
  (thresholds, baselines, pytest wiring). Use when measuring LLM quality,
  building an eval set, grading with a judge, comparing prompts or models, or
  gating prompt/model/retrieval changes in CI.
---

# Eval Skills

Design the measurement, grade with a judge, gate the regression.

## Determinism Snapshot

| Concern | Mechanism | Note |
|---------|-----------|------|
| Eval sets | Versioned JSONL (`evals/sets/<name>-vN.jsonl`), harvested from real traffic | Version pinned in every reported metric |
| Reproducibility | Temperature 0, fixed seeds, pinned judge config | A metric without its eval-set + judge version is noise |
| Harness | pytest as the spine; metrics written as artifacts | Compared against a stored baseline, not memory |
| Judges | LLM judge with structured output, calibrated to human labels | Uncalibrated "rate 1-10" judges never gate |
| Cost control | Tiered subsets: smoke (PR) → full (nightly/release) | Judge model choice is a cost ladder — verify current options via context7 |

## Where to Go

| I need to... | Read |
|--------------|------|
| Decide what to measure; build, size, or version an eval set; compare two prompts or models | [eval-design](eval-design/SKILL.md) (depth: [eval-methodology](eval-design/references/eval-methodology.md)) |
| Grade what code cannot check (tone, faithfulness); fix a judge that disagrees with humans or drifts | [llm-judge](llm-judge/SKILL.md) |
| Start from a working judge prompt + output schema | [judge-prompt-templates](llm-judge/references/judge-prompt-templates.md) |
| Add CI gates, pick thresholds, handle flakes, update a baseline | [regression-gates](regression-gates/SKILL.md) (depth: [gate-implementation](regression-gates/references/gate-implementation.md)) |

## Adjacent Skills

| Topic | Read |
|-------|------|
| Retrieval metrics (recall@k, MRR) | [retrieval-evaluation](../llm-apps/rag-systems/references/retrieval-evaluation.md) |
| Keeping training data out of eval sets | [dataset-curation](../finetuning/dataset-curation/SKILL.md) |
| Logging eval runs; tracing a reported metric | [experiment-tracking](../mlops/experiment-tracking/SKILL.md) |
| Judge evals on production traffic; failures back into eval sets | [model-monitoring](../mlops/model-monitoring/SKILL.md) |
| The prompts these evals gate | [prompt-design](../prompt-engineering/prompt-design/SKILL.md) |
| pytest mechanics (fixtures, parametrization) | `system-developer:python-testing` |

Harnesses are built by `ai-engineer:ai-test-generator`; eval strategy at the architecture level → `ai-engineer:ai-architector`.
