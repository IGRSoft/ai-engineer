# Eval Skills Index

Quick navigation for the `skills/evals/` subtree. Start at
[SKILL.md](SKILL.md) for the guided entry with determinism snapshot and
decision tree.

## Skills

| Skill | Use it for |
|-------|------------|
| [eval-design/SKILL.md](eval-design/SKILL.md) | Assertion→metric→judge→human hierarchy, task-grounded eval sets harvested from real traffic, metric selection by task type, paired prompt A/B comparison, statistical honesty, eval-set hygiene and versioning, failure-analysis workflow |
| [llm-judge/SKILL.md](llm-judge/SKILL.md) | Pointwise vs pairwise selection, rubric design with anchored descriptors, bias mitigations (position, length, self-preference, sycophancy), calibration against human labels (Cohen's kappa), evidence-first judge prompts with structured output, judge regression tests |
| [regression-gates/SKILL.md](regression-gates/SKILL.md) | Pre-commit→PR→nightly→release gate ladder, absolute floors plus relative-to-baseline thresholds with warn bands, baseline update ritual, determinism and flake policy for judge metrics, cost-bounded subsets, pytest integration with metrics artifacts, recorded escape hatch |

## References

| File | Use it for |
|------|------------|
| [eval-design/references/eval-methodology.md](eval-design/references/eval-methodology.md) | Eval-set construction, metric selection by task type, A/B protocol, statistical honesty, hygiene, failure analysis |
| [llm-judge/references/judge-prompt-templates.md](llm-judge/references/judge-prompt-templates.md) | Complete working judge prompts + output schemas to start a harness from |
| [regression-gates/references/gate-implementation.md](regression-gates/references/gate-implementation.md) | Threshold design, baseline management, flake policy, cost engineering, pytest integration, escape hatch |

## Cross-Tree

| Topic | Location |
|-------|----------|
| Retrieval-specific metrics (recall@k, MRR) | [llm-apps/rag-systems/references/retrieval-evaluation.md](../llm-apps/rag-systems/references/retrieval-evaluation.md) |
| Keeping training data out of eval sets | `${CLAUDE_SKILL_DIR}/finetuning/dataset-curation/SKILL.md` |
| Logging eval runs, tracing reported metrics | `${CLAUDE_SKILL_DIR}/mlops/experiment-tracking/SKILL.md` |
| Judge evals on live traffic, feedback loops | `${CLAUDE_SKILL_DIR}/mlops/model-monitoring/SKILL.md` |
| pytest mechanics (fixtures, parametrization) | `system-developer:python-skills` (python-testing) |
| Workflow stage participation | `${CLAUDE_SKILL_DIR}/_shared/workflow-integration/SKILL.md` |
