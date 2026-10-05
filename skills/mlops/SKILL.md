---
name: mlops
description: >-
  MLOps skills navigation: experiment tracking and model registry (MLflow/W&B),
  model serving (vLLM/TGI/Ollama/Triton, quantization, KV-cache sizing),
  production monitoring (drift, quality, cost), and ML pipelines with data
  versioning and CI/CD (DVC, orchestrators). Use when logging runs, promoting
  or rolling back a model, deploying or sizing a serving stack, wiring LLM-app
  observability, versioning datasets, or building training/data pipelines.
---

# MLOps Skills

Running models as software: tracked, served, monitored, and rebuilt from
versioned pipelines.

## Stack Snapshot

| Layer | Typical pieces | Note |
|-------|----------------|------|
| Tracking/registry | MLflow or W&B; registry aliases dev → staging → prod | Promotion gated on evals, deploys are alias flips |
| Serving | Ollama / vLLM / TGI / Triton / llama.cpp ladder | Engine capabilities shift fast — verify via context7 and [serving-stack-matrix](model-serving/references/serving-stack-matrix.md) |
| Monitoring | System + model-quality + business planes; LLM traces | Drift watched via scheduled judge evals on sampled traffic |
| Pipelines | DVC for data/model versioning; make → cron → orchestrator ladder | Idempotent, re-runnable steps; `uv.lock` baked into images |
| Environments | Pinned CUDA base images, uv-locked deps | GPU-optional: CPU/MPS paths for dev, GPU sizing as capacity math |

Throughput, VRAM-per-request, and price facts are volatile: reason with
capacity formulas (KV-cache math, concurrency budgets) and verify concrete
numbers against your hardware and current docs (context7).

## Where to Go

| I need to... | Read |
|--------------|------|
| Log a training/fine-tuning/eval run reproducibly; trace a number back to its run; promote, alias, or roll back a registered model | [experiment-tracking](experiment-tracking/SKILL.md) |
| Deploy an open-weights model or LoRA adapter; choose or size a serving engine; quantize for inference | [model-serving](model-serving/SKILL.md) (engine comparison: [serving-stack-matrix](model-serving/references/serving-stack-matrix.md)) |
| Wire observability, alerts, and cost dashboards; investigate a quality regression or spend spike | [model-monitoring](model-monitoring/SKILL.md) |
| Version datasets, write dvc.yaml stages, pick an orchestrator; wire CI for model changes; replace checkpoint-copy deploys | [ml-pipelines](ml-pipelines/SKILL.md) |

Every leaf and reference file with a longer summary: [_index.md](_index.md).

## Adjacent Skills

| Topic | Read |
|-------|------|
| Judge evals on sampled production traffic | [llm-judge](../evals/llm-judge/SKILL.md) |
| Eval thresholds behind pipeline and promotion gates | [regression-gates](../evals/regression-gates/SKILL.md) |
| The model itself needs work (data, adapter, preferences) | [finetuning](../finetuning/SKILL.md) |
| Training-side GPU memory and throughput | [training-optimization](../finetuning/training-optimization/SKILL.md) |
| Merge-vs-serve for the adapters being deployed | [peft-lora](../finetuning/peft-lora/SKILL.md) |
| The app calling the endpoint; client-side reliability | [llm-apps](../llm-apps/SKILL.md) / [llm-api-patterns](../llm-apps/llm-api-patterns/SKILL.md) |

Owner: `ai-engineer:mlops-engineer`. Serving-architecture and capacity
trade-offs → `ai-engineer:ai-architector`; latency/throughput/GPU-util review →
`ai-engineer:ai-performance-engineer`; CUDA-compat and lockfile pins →
`ai-engineer:ai-dependency-manager`.
