---
name: mlops
description: >-
  MLOps skills navigation: experiment tracking and model registry (MLflow/W&B),
  serving open-weights and fine-tuned models (vLLM/TGI/Ollama/Triton-class,
  quantization, KV-cache sizing), production monitoring (drift, quality, cost),
  and ML pipelines with data versioning and CI/CD (DVC, orchestrators). Use
  when logging runs, promoting or rolling back a model, deploying or sizing a
  serving stack, wiring observability for an LLM app, versioning datasets, or
  building training/data pipelines.
---

# MLOps Skills

**Navigation and stack snapshot for running models as software — tracked,
served, monitored, and rebuilt from versioned pipelines**

## Stack Snapshot

| Layer | Typical pieces | Note |
|-------|----------------|------|
| Tracking/registry | MLflow or W&B; registry aliases dev → staging → prod | Promotion gated on evals, deploys are alias flips |
| Serving | Ollama / vLLM / TGI / Triton / llama.cpp ladder | Engine capabilities shift fast — verify via context7 and [model-serving/references/serving-stack-matrix.md](model-serving/references/serving-stack-matrix.md) |
| Monitoring | System + model-quality + business planes; LLM traces | Drift watched via scheduled judge evals on sampled traffic |
| Pipelines | DVC for data/model versioning; make → cron → orchestrator ladder | Idempotent, re-runnable steps; `uv.lock` baked into images |
| Environments | Pinned CUDA base images, uv-locked deps | GPU-optional: CPU/MPS paths for dev, GPU sizing as capacity math |

Throughput, VRAM-per-request, and price facts are volatile — reason with
capacity formulas (KV-cache math, concurrency budgets) and verify concrete
numbers against your hardware and current docs (context7).

## Skill Selection Guide

| I need to... | Use this skill |
|--------------|----------------|
| Log a training/fine-tuning/eval run so it is reproducible | [experiment-tracking/SKILL.md](experiment-tracking/SKILL.md) |
| Promote, alias, or roll back a registered model | [experiment-tracking/SKILL.md](experiment-tracking/SKILL.md) |
| Deploy an open-weights model or LoRA adapter | [model-serving/SKILL.md](model-serving/SKILL.md) |
| Choose/size a serving engine; quantize for inference | [model-serving/SKILL.md](model-serving/SKILL.md) |
| Compare serving engines by dimension | [model-serving/references/serving-stack-matrix.md](model-serving/references/serving-stack-matrix.md) |
| Wire observability, alerts, and cost dashboards for an LLM app | [model-monitoring/SKILL.md](model-monitoring/SKILL.md) |
| Investigate a production quality regression or spend spike | [model-monitoring/SKILL.md](model-monitoring/SKILL.md) |
| Version datasets / write dvc.yaml stages / pick an orchestrator | [ml-pipelines/SKILL.md](ml-pipelines/SKILL.md) |
| Wire CI for model changes; replace checkpoint-copy deploys | [ml-pipelines/SKILL.md](ml-pipelines/SKILL.md) |

## Decision Tree

```
MLOps task?
├── Logging runs / registry promotion / "which run made this number?"
│   → experiment-tracking/SKILL.md
├── Deploying or exposing a model endpoint → model-serving/SKILL.md
│   └── Engine comparison dimensions → model-serving/references/serving-stack-matrix.md
├── Production visibility (quality, drift, cost, alerts) → model-monitoring/SKILL.md
│   └── Judge evals on sampled traffic → ${CLAUDE_SKILL_DIR}/evals/llm-judge/SKILL.md
├── Pipelines, dataset versioning, CI/CD for models → ml-pipelines/SKILL.md
│   └── Eval-gated promotion thresholds → ${CLAUDE_SKILL_DIR}/evals/regression-gates/SKILL.md
├── The model itself needs work (data, adapter, preferences)
│   → ${CLAUDE_SKILL_DIR}/finetuning/SKILL.md
└── The app calling the endpoint needs work → ${CLAUDE_SKILL_DIR}/llm-apps/SKILL.md
```

## File Overview

| File | Purpose |
|------|---------|
| [_index.md](_index.md) | Full navigation for the mlops/ subtree |
| [experiment-tracking/SKILL.md](experiment-tracking/SKILL.md) | Run contract, MLflow vs W&B mapping, LLM-specific logging, registry promotion |
| [experiment-tracking/references/tracking-implementation.md](experiment-tracking/references/tracking-implementation.md) | Deep dive: launcher example, tool mapping, run hygiene, registry flow |
| [model-serving/SKILL.md](model-serving/SKILL.md) | Serving ladder, deployment anatomy, quantization, KV-cache math, hardening |
| [model-serving/references/serving-stack-matrix.md](model-serving/references/serving-stack-matrix.md) | Serving-engine comparison dimensions |
| [model-monitoring/SKILL.md](model-monitoring/SKILL.md) | Three monitoring planes, traces, drift, cost alarms, feedback loops |
| [model-monitoring/references/observability-and-drift.md](model-monitoring/references/observability-and-drift.md) | Deep dive: traces, drift detection, cost, feedback loops, canary/alerts |
| [ml-pipelines/SKILL.md](ml-pipelines/SKILL.md) | Pipeline DAGs, DVC, orchestrator ladder, CI gates, lineage, environments |
| [ml-pipelines/references/versioning-and-cicd.md](ml-pipelines/references/versioning-and-cicd.md) | Deep dive: DVC, orchestrators, CI/CD, lineage, feature stores |

## Related Skills

- [training-optimization](${CLAUDE_SKILL_DIR}/finetuning/training-optimization/SKILL.md) — the training side of the GPU-capacity coin
- [peft-lora](${CLAUDE_SKILL_DIR}/finetuning/peft-lora/SKILL.md) — merge-vs-serve decisions for the adapters being deployed
- [llm-api-patterns](${CLAUDE_SKILL_DIR}/llm-apps/llm-api-patterns/SKILL.md) — client-side reliability against the endpoints served here
- [regression-gates](${CLAUDE_SKILL_DIR}/evals/regression-gates/SKILL.md) — the eval gates that pipelines and promotions enforce

**Owning agent:** `ai-engineer:mlops-engineer`. Serving-architecture and
capacity trade-offs → `ai-engineer:ai-architector`; latency/throughput/GPU-util
review → `ai-engineer:ai-performance-engineer`; CUDA-compat and lockfile pins →
`ai-engineer:ai-dependency-manager`.
