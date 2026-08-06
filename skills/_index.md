# Skills Index

Root index for all ai-engineer skills (prompt engineering, LLM apps,
fine-tuning, MLOps, evals, and shared references). **28 SKILL.md across 5
domains + _shared, plus shared references.** Start at [`SKILL.md`](SKILL.md)
for the routing entry point.

## Domains

| Directory | Index | Skills | Description |
|-----------|-------|--------|-------------|
| [_shared/](_shared/_index.md) | [`_index.md`](_shared/_index.md) | 1 + refs | Cross-cutting references: company-workflow workflow integration, AI-stack agent routing, model selection, severity matrix |
| [prompt-engineering/](prompt-engineering/SKILL.md) | [`_index.md`](prompt-engineering/_index.md) | 1 + 3 leaves | Production prompt design, context-window engineering, reliable structured outputs |
| [llm-apps/](llm-apps/SKILL.md) | [`_index.md`](llm-apps/_index.md) | 1 + 3 leaves | RAG pipelines, bounded agent loops, production provider-API integration |
| [finetuning/](finetuning/SKILL.md) | [`_index.md`](finetuning/_index.md) | 1 + 8 leaves | Dataset curation, graded-trace conversion, LoRA/QLoRA adapters, training optimization, preference tuning, verifiable-reward RL, checkpoint promotion, quantized export |
| [mlops/](mlops/SKILL.md) | [`_index.md`](mlops/_index.md) | 1 + 4 leaves | Experiment tracking, model serving, production monitoring, ML pipelines + data versioning |
| [evals/](evals/SKILL.md) | [`_index.md`](evals/_index.md) | 1 + 3 leaves | Eval design, LLM-as-judge, CI regression gates |

## All Skills

### _shared

| Skill | Path | Description |
|-------|------|-------------|
| **workflow-integration** | [`_shared/workflow-integration/SKILL.md`](_shared/workflow-integration/SKILL.md) | Guide for integrating with the company-workflow 11-stage workflow system (v4.0.0) — DV contract for AI work, AI Build Evidence, screenshot cli-fallback, gate feedback |
| framework-detection | [`_shared/framework-detection.md`](_shared/framework-detection.md) | AI-stack marker → domain → agent routing table: detection priority, dependency/file markers, mixed-stack tie-breaks, sibling-plugin precedence |
| model-selection | [`_shared/model-selection.md`](_shared/model-selection.md) | Per-agent model/effort/maxTurns assignments, cost tiers, and opus+xhigh override paths |
| severity-matrix | [`_shared/severity-matrix.md`](_shared/severity-matrix.md) | Severity levels, P0-P3 review priorities with AI examples, effort/impact quadrant, coverage requirements |

### prompt-engineering

| Skill | Path | Description |
|-------|------|-------------|
| **prompt-engineering** (entry) | [`prompt-engineering/SKILL.md`](prompt-engineering/SKILL.md) | Prompt engineering skills navigation: prompt design, context engineering, structured outputs, escalation to RAG/fine-tuning |
| **prompt-design** | [`prompt-engineering/prompt-design/SKILL.md`](prompt-engineering/prompt-design/SKILL.md) | Prompt anatomy, instruction hierarchy with injection-resistant layering, few-shot design, prompts as versioned files |
| **context-engineering** | [`prompt-engineering/context-engineering/SKILL.md`](prompt-engineering/context-engineering/SKILL.md) | Context hierarchy, per-segment token budgets, packing and compaction strategies, lost-in-the-middle placement, context observability |
| **structured-outputs** | [`prompt-engineering/structured-outputs/SKILL.md`](prompt-engineering/structured-outputs/SKILL.md) | Extraction-mode selection, JSON schema design, Pydantic validate → repair-once → fail-closed, streaming partial JSON |

### llm-apps

| Skill | Path | Description |
|-------|------|-------------|
| **llm-apps** (entry) | [`llm-apps/SKILL.md`](llm-apps/SKILL.md) | LLM application skills navigation: RAG, agent design, provider-API patterns, cross-domain escalation |
| **rag-systems** | [`llm-apps/rag-systems/SKILL.md`](llm-apps/rag-systems/SKILL.md) | Ingest→chunk→embed→index→retrieve→rerank→ground pipeline, hybrid retrieval, grounded citations with refusal rules, index lifecycle |
| **agent-design** | [`llm-apps/agent-design/SKILL.md`](llm-apps/agent-design/SKILL.md) | Escalation ladder, loop anatomy, stop conditions and budgets, tool contracts, guardrails with human confirmation, step-level tracing |
| **llm-api-patterns** | [`llm-apps/llm-api-patterns/SKILL.md`](llm-apps/llm-api-patterns/SKILL.md) | Timeout/retry discipline, rate limits, streaming, prompt caching, batch APIs, fallback chains, cost accounting, secrets hygiene |

### finetuning

| Skill | Path | Description |
|-------|------|-------------|
| **finetuning** (entry) | [`finetuning/SKILL.md`](finetuning/SKILL.md) | Fine-tuning skills navigation: data → adapter → optimization → preferences, with the fine-tune-at-all decision first |
| **dataset-curation** | [`finetuning/dataset-curation/SKILL.md`](finetuning/dataset-curation/SKILL.md) | Chat-format normalization, exact + near-dup dedup, eval-set decontamination, PII scrubbing, provenance ledgers, stratified splits, versioning |
| **peft-lora** | [`finetuning/peft-lora/SKILL.md`](finetuning/peft-lora/SKILL.md) | When adapters beat full fine-tuning or RAG, LoRA/QLoRA config anatomy, smoke-scale SFTTrainer loops, adapter save/merge/serve, before/after evals |
| **training-optimization** | [`finetuning/training-optimization/SKILL.md`](finetuning/training-optimization/SKILL.md) | GPU memory model with estimation formulas, precision, gradient accumulation vs batch size, checkpointing, throughput and loss-curve triage |
| **preference-tuning** | [`finetuning/preference-tuning/SKILL.md`](finetuning/preference-tuning/SKILL.md) | SFT-only vs DPO vs ORPO/KTO vs RLHF selection, preference-pair construction, DPO mechanics, reward-hacking detection and mitigation |
| **grpo-rlvr-training** | [`finetuning/grpo-rlvr-training/SKILL.md`](finetuning/grpo-rlvr-training/SKILL.md) | Verifiable-reward RL: applicability preconditions, GRPO recipe and group-size floor, the reward-inspection gate, DAPO/Dr.GRPO/GSPO variant selection |
| **trace-to-training-data** | [`finetuning/trace-to-training-data/SKILL.md`](finetuning/trace-to-training-data/SKILL.md) | Graded traces → training rows: top-reward rejection sampling, expert corrections, step-level masking, same-task preference pairs, goldens-holdout hygiene |
| **checkpoint-promotion** | [`finetuning/checkpoint-promotion/SKILL.md`](finetuning/checkpoint-promotion/SKILL.md) | Four-stage weights gate, drift budget with hard fail, budget-derived sample size, catastrophic-forgetting ladder, terminal PROMOTE/REJECT verdict |
| **quantized-export** | [`finetuning/quantized-export/SKILL.md`](finetuning/quantized-export/SKILL.md) | Merged vs LoRA-only, format map (FP8/AWQ INT4/GGUF+imatrix), long-context/code/math INT4 override, mandatory pre/post smoke test |

### mlops

| Skill | Path | Description |
|-------|------|-------------|
| **mlops** (entry) | [`mlops/SKILL.md`](mlops/SKILL.md) | MLOps skills navigation: tracking, serving, monitoring, pipelines — models run as software |
| **experiment-tracking** | [`mlops/experiment-tracking/SKILL.md`](mlops/experiment-tracking/SKILL.md) | Run contract (config, seed, dataset version, commit, environment), MLflow vs W&B mapping, LLM-specific logging, eval-gated registry promotion |
| **model-serving** | [`mlops/model-serving/SKILL.md`](mlops/model-serving/SKILL.md) | Managed-API vs self-hosted ladder, deployment anatomy, quantization, KV-cache capacity math, LoRA hot-swap vs merge, operational hardening |
| **model-monitoring** | [`mlops/model-monitoring/SKILL.md`](mlops/model-monitoring/SKILL.md) | System/quality/business planes, LLM trace observability, drift via scheduled judge evals, cost dashboards and spend alarms, feedback loops |
| **ml-pipelines** | [`mlops/ml-pipelines/SKILL.md`](mlops/ml-pipelines/SKILL.md) | Pipeline-as-DAG with idempotent steps, DVC vs git-lfs, orchestrator ladder, PR smoke gates, eval-gated promotion, lineage, environment discipline |

### evals

| Skill | Path | Description |
|-------|------|-------------|
| **evals** (entry) | [`evals/SKILL.md`](evals/SKILL.md) | Evaluation skills navigation: design the measurement, grade with a judge, gate the regression |
| **eval-design** | [`evals/eval-design/SKILL.md`](evals/eval-design/SKILL.md) | Assertion→metric→judge→human hierarchy, task-grounded eval sets from real traffic, paired A/B comparison, statistical honesty, failure analysis |
| **llm-judge** | [`evals/llm-judge/SKILL.md`](evals/llm-judge/SKILL.md) | Pointwise vs pairwise selection, anchored rubrics, bias mitigations, calibration against human labels (Cohen's kappa), judge regression tests |
| **regression-gates** | [`evals/regression-gates/SKILL.md`](evals/regression-gates/SKILL.md) | Pre-commit→PR→nightly→release gate ladder, floors plus relative thresholds, baseline update ritual, flake policy, pytest integration, escape hatch |

## Child Indexes

| Index Path | Contents |
|------------|----------|
| [`_shared/_index.md`](_shared/_index.md) | Shared references: workflow integration + templates, agent routing, model selection, severity |
| [`prompt-engineering/_index.md`](prompt-engineering/_index.md) | Prompt engineering entry + prompt-design + context-engineering + structured-outputs (with references) |
| [`llm-apps/_index.md`](llm-apps/_index.md) | LLM apps entry + rag-systems + agent-design + llm-api-patterns (with references) |
| [`finetuning/_index.md`](finetuning/_index.md) | Fine-tuning entry + dataset-curation + peft-lora + training-optimization + preference-tuning + grpo-rlvr-training + trace-to-training-data + checkpoint-promotion + quantized-export (with references) |
| [`mlops/_index.md`](mlops/_index.md) | MLOps entry + experiment-tracking + model-serving + model-monitoring + ml-pipelines (with references) |
| [`evals/_index.md`](evals/_index.md) | Evals entry + eval-design + llm-judge + regression-gates (with references) |

## Root References

| Path | Contents |
|------|----------|
| [`references/conventions.md`](references/conventions.md) | Skill authoring contract: uv-first Python, determinism in eval/training examples, no pricing or model-ID snapshots, GPU-optional depth, language-depth delegation, plugin-qualified agent names |
