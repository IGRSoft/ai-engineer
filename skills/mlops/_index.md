# MLOps Skills Index

Quick navigation for the `skills/mlops/` subtree. Guided entry with the
stack snapshot: [SKILL.md](SKILL.md).

## Skills

| Skill | Use it for |
|-------|------------|
| [experiment-tracking/SKILL.md](experiment-tracking/SKILL.md) | Run contract (config, seed, dataset version, commit, environment, metrics), MLflow/W&B mapping, sweep hygiene, LLM-specific logging, eval-gated registry promotion via aliases |
| [model-serving/SKILL.md](model-serving/SKILL.md) | Engine choice (Ollama, vLLM, TGI, Triton, llama.cpp) vs managed API, pinned artifact to OpenAI-compatible endpoint behind a gateway, serve-time quantization, KV-cache capacity math, LoRA hot-swap vs merge, probes/warmup/drain/canary/rollback |
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
| Producing the artifacts being served (adapters, merges) | [finetuning/peft-lora/SKILL.md](../finetuning/peft-lora/SKILL.md) |
| Training-side GPU memory and throughput | [finetuning/training-optimization/SKILL.md](../finetuning/training-optimization/SKILL.md) |
| Client-side reliability against served endpoints | [llm-apps/llm-api-patterns/SKILL.md](../llm-apps/llm-api-patterns/SKILL.md) |
| Judge evals scheduled on production traffic | [evals/llm-judge/SKILL.md](../evals/llm-judge/SKILL.md) |
| Eval thresholds behind promotion gates | [evals/regression-gates/SKILL.md](../evals/regression-gates/SKILL.md) |
