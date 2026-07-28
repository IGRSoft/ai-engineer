---
name: finetuning
description: >-
  Fine-tuning skills navigation: dataset curation (chat formats, dedup,
  decontamination), LoRA/QLoRA adapters via PEFT + TRL, training optimization
  (memory math, precision, throughput), and preference tuning (DPO/ORPO/KTO
  vs RLHF). Use when deciding whether to fine-tune at all, preparing or
  auditing training data, configuring or debugging a LoRA/QLoRA or DPO run,
  fitting training into limited VRAM, or proving a tune beat its baseline.
---

# Fine-Tuning Skills

**Navigation and stack snapshot for changing model weights — data first,
adapters second, preferences last, evals throughout**

## Stack Snapshot

| Layer | Typical pieces | Note |
|-------|----------------|------|
| Core training | `torch`, `transformers`, `datasets` | APIs move between minors — pin in `uv.lock`, verify via context7 |
| Adapters | `peft` (LoRA/QLoRA), `bitsandbytes` (4-bit quantization) | QLoRA trades step time for VRAM |
| Trainers | `trl` (`SFTTrainer`, `DPOTrainer`), `accelerate` | Smoke-scale first: capped `max_steps`, subsampled data |
| Devices | cuda → mps → cpu strategy | GPU-optional: Mac-dev smoke runs, CUDA full runs as a documented launch plan |
| Artifacts | safetensors only; HF revisions pinned | pickle checkpoints from untrusted sources are a P0 |

Every run records its dataset version, seed, config, and code commit — an
untracked run is an unreproducible run (see
`${CLAUDE_SKILL_DIR}/mlops/experiment-tracking/SKILL.md`).

## Skill Selection Guide

| I need to... | Use this skill |
|--------------|----------------|
| Decide fine-tune vs prompt vs RAG | [peft-lora/SKILL.md](peft-lora/SKILL.md) (Is LoRA the Right Tool?) + `ai-engineer:ai-architector` |
| Turn raw logs/tickets/docs into training JSONL | [dataset-curation/SKILL.md](dataset-curation/SKILL.md) |
| Chase an inflated eval score / suspected leakage | [dataset-curation/SKILL.md](dataset-curation/SKILL.md) (decontamination) |
| Pick messages-schema / chat-template formatting | [dataset-curation/references/data-formats.md](dataset-curation/references/data-formats.md) |
| Configure r/alpha/target_modules; debug flat loss or forgetting | [peft-lora/SKILL.md](peft-lora/SKILL.md) |
| Choose LoRA hyperparameter starting points | [peft-lora/references/hyperparameter-guide.md](peft-lora/references/hyperparameter-guide.md) |
| Fix an OOM, idle GPU, or diverging loss curve | [training-optimization/SKILL.md](training-optimization/SKILL.md) |
| Estimate VRAM before launching | [training-optimization/references/gpu-memory-math.md](training-optimization/references/gpu-memory-math.md) |
| Scale past one GPU (DDP/FSDP/DeepSpeed) | [training-optimization/references/distributed-training.md](training-optimization/references/distributed-training.md) |
| Align close-but-not-quite SFT output with preferences | [preference-tuning/SKILL.md](preference-tuning/SKILL.md) |

## Decision Tree

```
Fine-tuning task?
├── Should we fine-tune at all? → peft-lora § Is LoRA the Right Tool? + ai-engineer:ai-architector
├── Data not yet in clean messages-JSONL → dataset-curation/SKILL.md
│   └── SFT vs preference record formats → dataset-curation/references/data-formats.md
├── Configuring or debugging an adapter run → peft-lora/SKILL.md
│   └── r/alpha/lr starting points → peft-lora/references/hyperparameter-guide.md
├── Run OOMs / slow / loss curve wrong → training-optimization/SKILL.md
│   ├── VRAM estimation formulas → training-optimization/references/gpu-memory-math.md
│   └── Multi-GPU ladder → training-optimization/references/distributed-training.md
├── SFT close-but-not-quite (tone, style, judgment) → preference-tuning/SKILL.md
├── Serving the tuned artifact (merge vs hot-swap) → ${CLAUDE_SKILL_DIR}/mlops/model-serving/SKILL.md
└── Did it beat baseline? → ${CLAUDE_SKILL_DIR}/evals/eval-design/SKILL.md
    └── Runs tracked in → ${CLAUDE_SKILL_DIR}/mlops/experiment-tracking/SKILL.md
```

## File Overview

| File | Purpose |
|------|---------|
| [_index.md](_index.md) | Full navigation for the finetuning/ subtree |
| [dataset-curation/SKILL.md](dataset-curation/SKILL.md) | Dataset building: normalization, dedup, decontamination, scrubbing, splits, versioning |
| [dataset-curation/references/data-formats.md](dataset-curation/references/data-formats.md) | Fine-tuning data formats (SFT, preference, chat templates) |
| [peft-lora/SKILL.md](peft-lora/SKILL.md) | LoRA/QLoRA: config anatomy, smoke-scale loops, adapter lifecycle, eval discipline |
| [peft-lora/references/hyperparameter-guide.md](peft-lora/references/hyperparameter-guide.md) | LoRA hyperparameter starting points |
| [training-optimization/SKILL.md](training-optimization/SKILL.md) | Memory model, precision, accumulation/checkpointing, throughput and loss triage |
| [training-optimization/references/gpu-memory-math.md](training-optimization/references/gpu-memory-math.md) | GPU memory estimation formulas |
| [training-optimization/references/distributed-training.md](training-optimization/references/distributed-training.md) | DDP/FSDP/DeepSpeed ladder |
| [preference-tuning/SKILL.md](preference-tuning/SKILL.md) | DPO/ORPO/KTO vs RLHF, preference pairs, reward-hacking detection |
| [preference-tuning/references/dpo-and-preference-data.md](preference-tuning/references/dpo-and-preference-data.md) | Deep dive: pair construction, DPO mechanics, reward hacking, distillation |

## Related Skills

- [dataset versioning + pipelines](${CLAUDE_SKILL_DIR}/mlops/ml-pipelines/SKILL.md) — DVC stages for repeatable data → train → eval runs
- [experiment-tracking](${CLAUDE_SKILL_DIR}/mlops/experiment-tracking/SKILL.md) — the run contract every training job logs against
- [model-serving](${CLAUDE_SKILL_DIR}/mlops/model-serving/SKILL.md) — deploying the resulting adapter or merged weights
- [eval-design](${CLAUDE_SKILL_DIR}/evals/eval-design/SKILL.md) — before/after measurement; no tune ships on loss curves alone

**Owning agent:** `ai-engineer:ml-engineer`. Training-vs-serving seams →
`ai-engineer:mlops-engineer` (tie-breaks in
`${CLAUDE_SKILL_DIR}/_shared/framework-detection.md`); pickle-vs-safetensors
and dataset-PII review → `ai-engineer:ai-security-auditor`; torch/CUDA
compatibility pins → `ai-engineer:ai-dependency-manager`.
