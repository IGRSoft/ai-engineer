# MLOps Skills Index

Quick navigation for the `skills/mlops/` subtree. Start at
[SKILL.md](SKILL.md) for the guided entry with stack snapshot and decision
tree.

## Skills

| Skill | Use it for |
|-------|------------|
| [experiment-tracking/SKILL.md](experiment-tracking/SKILL.md) | Run contract (config, seed, dataset version, commit, environment hash, metrics), MLflow vs W&B concept mapping, sweep hygiene, LLM-specific logging (prompt/eval-set versions, judge config), registry promotion through dev → staging → prod gated on evals |
| [model-serving/SKILL.md](model-serving/SKILL.md) | Managed-API vs self-hosted ladder (Ollama, vLLM, TGI, Triton, llama.cpp), deployment anatomy from pinned artifact to OpenAI-compatible endpoint, quantization (GPTQ/AWQ/GGUF), KV-cache capacity math, LoRA hot-swap vs merge, readiness/warmup/drain/canary/rollback |
| [model-monitoring/SKILL.md](model-monitoring/SKILL.md) | System/quality/business monitoring planes, LLM trace observability, drift detection via scheduled judge evals on sampled traffic, per-feature cost dashboards and spend alarms, feedback loops into eval sets and fine-tuning data |
| [ml-pipelines/SKILL.md](ml-pipelines/SKILL.md) | Pipeline-as-DAG with idempotent steps, DVC stages/remotes/metrics vs git-lfs, orchestrator ladder (make → cron → Airflow/Dagster/Prefect-class), PR smoke gates, eval-gated promotion, lineage, environment discipline (uv.lock in images, pinned CUDA bases) |

## References

| File | Use it for |
|------|------------|
| [experiment-tracking/references/tracking-implementation.md](experiment-tracking/references/tracking-implementation.md) | Tracked-run launcher, MLflow ↔ W&B mapping, run hygiene, LLM logging, registry promotion |
| [model-serving/references/serving-stack-matrix.md](model-serving/references/serving-stack-matrix.md) | Serving-engine comparison by dimension (mechanisms, not snapshots) |
| [model-monitoring/references/observability-and-drift.md](model-monitoring/references/observability-and-drift.md) | LLM trace observability, drift detection, cost monitoring, feedback loops, canary/rollback |
| [ml-pipelines/references/versioning-and-cicd.md](ml-pipelines/references/versioning-and-cicd.md) | DVC versioning, orchestrator ladder, CI/CD for models, lineage, feature stores |

## Cross-Tree

| Topic | Location |
|-------|----------|
| Producing the artifacts being served (adapters, merges) | `${CLAUDE_SKILL_DIR}/finetuning/peft-lora/SKILL.md` |
| Training-side GPU memory and throughput | `${CLAUDE_SKILL_DIR}/finetuning/training-optimization/SKILL.md` |
| Client-side reliability against served endpoints | `${CLAUDE_SKILL_DIR}/llm-apps/llm-api-patterns/SKILL.md` |
| Judge evals scheduled on production traffic | `${CLAUDE_SKILL_DIR}/evals/llm-judge/SKILL.md` |
| Eval thresholds behind promotion gates | `${CLAUDE_SKILL_DIR}/evals/regression-gates/SKILL.md` |
| Workflow stage participation | `${CLAUDE_SKILL_DIR}/_shared/workflow-integration/SKILL.md` |
