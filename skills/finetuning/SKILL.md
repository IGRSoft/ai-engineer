---
name: finetuning
description: >-
  Fine-tuning skills navigation: dataset curation, graded-trace conversion,
  LoRA/QLoRA, training optimization, preference tuning (DPO), verifiable-reward
  RL (GRPO), checkpoint promotion, and quantized export. Use when deciding
  whether to fine-tune, preparing training data, configuring or debugging a
  LoRA, DPO, or GRPO run, fitting training into limited VRAM, deciding whether
  a checkpoint ships, or exporting it.
---

# Fine-Tuning Skills

Data first, adapters second, preferences last, evals throughout.

## Stack Snapshot

| Layer | Typical pieces | Note |
|-------|----------------|------|
| Core training | `torch`, `transformers`, `datasets` | APIs move between minors — pin in `uv.lock`, verify via context7 |
| Adapters | `peft` (LoRA/QLoRA), `bitsandbytes` (4-bit quantization) | QLoRA trades step time for VRAM |
| Trainers | `trl` (`SFTTrainer`, `DPOTrainer`), `accelerate` | Smoke-scale first: capped `max_steps`, subsampled data |
| Devices | cuda → mps → cpu strategy | GPU-optional: Mac-dev smoke runs, CUDA full runs as a documented launch plan |
| Artifacts | safetensors only; HF revisions pinned | pickle checkpoints from untrusted sources are a P0 |

Every run records its dataset version, seed, config, and code commit, or it
can't be reproduced (see [experiment-tracking](../mlops/experiment-tracking/SKILL.md)).

## Where to Go

| I need to... | Read |
|--------------|------|
| Decide fine-tune vs prompt vs RAG | [peft-lora § Is LoRA the Right Tool?](peft-lora/SKILL.md) + `ai-engineer:ai-architector` |
| Turn raw, ungraded logs/tickets/docs into training JSONL; chase an inflated eval score (leakage) | [dataset-curation](dataset-curation/SKILL.md) (formats: [data-formats](dataset-curation/references/data-formats.md)) |
| Turn graded eval traces into SFT rows or preference pairs | [trace-to-training-data](trace-to-training-data/SKILL.md) |
| Configure r/alpha/target_modules; debug flat loss or forgetting | [peft-lora](peft-lora/SKILL.md) (starting points: [hyperparameter-guide](peft-lora/references/hyperparameter-guide.md)) |
| Fix an OOM, idle GPU, or diverging loss; estimate VRAM; scale past one GPU | [training-optimization](training-optimization/SKILL.md) ([gpu-memory-math](training-optimization/references/gpu-memory-math.md), [distributed-training](training-optimization/references/distributed-training.md)) |
| Align close-but-not-quite SFT output with preferences | [preference-tuning](preference-tuning/SKILL.md) |
| Train against a programmatic verifier (tests, schemas, math); a run reward-hacks | [grpo-rlvr-training](grpo-rlvr-training/SKILL.md) |
| Decide whether a checkpoint ships; diagnose capability drift | [checkpoint-promotion](checkpoint-promotion/SKILL.md) |
| Export a promoted checkpoint for a target runtime | [quantized-export](quantized-export/SKILL.md) |

Every leaf and reference file with a longer summary: [_index.md](_index.md).

## Adjacent Skills

| Topic | Read |
|-------|------|
| Serving the adapter or merged weights | [model-serving](../mlops/model-serving/SKILL.md) |
| Before/after measurement; no tune ships on loss curves alone | [eval-design](../evals/eval-design/SKILL.md) |
| The run contract every training job logs against | [experiment-tracking](../mlops/experiment-tracking/SKILL.md) |
| DVC stages for repeatable data → train → eval runs | [ml-pipelines](../mlops/ml-pipelines/SKILL.md) |

Owner: `ai-engineer:ml-engineer`. Training-vs-serving seams →
`ai-engineer:mlops-engineer` (tie-breaks in
[framework-detection](../_shared/framework-detection.md)); pickle-vs-safetensors
and dataset-PII review → `ai-engineer:ai-security-auditor`; torch/CUDA pins →
`ai-engineer:ai-dependency-manager`.
