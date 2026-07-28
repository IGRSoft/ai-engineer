# Fine-Tuning Skills Index

Quick navigation for the `skills/finetuning/` subtree. Start at
[SKILL.md](SKILL.md) for the guided entry with stack snapshot and decision
tree.

## Skills

| Skill | Use it for |
|-------|------------|
| [dataset-curation/SKILL.md](dataset-curation/SKILL.md) | Chat-format normalization (messages schema, chat templates), exact + near-dup dedup, eval-set decontamination, PII/secret scrubbing gates, license/provenance ledgers, stratified splits, dataset versioning |
| [peft-lora/SKILL.md](peft-lora/SKILL.md) | When adapters beat full fine-tuning or RAG, LoRA/QLoRA config anatomy (r, alpha, dropout, target_modules), smoke-scale SFTTrainer loops, adapter save/merge/serve lifecycle, before/after eval discipline |
| [training-optimization/SKILL.md](training-optimization/SKILL.md) | GPU memory model with estimation formulas, bf16/fp16/tf32 precision, gradient accumulation vs batch size, gradient checkpointing, 8-bit optimizers, cuda/mps/cpu strategy, throughput and loss-curve triage, checkpoint/resume |
| [preference-tuning/SKILL.md](preference-tuning/SKILL.md) | SFT-only vs DPO vs ORPO/KTO vs RLHF/PPO selection, preference-pair construction and labeling rubrics, DPO mechanics (beta, reference model), reward-hacking detection (length bias, sycophancy) and mitigations |

## References

| File | Use it for |
|------|------------|
| [dataset-curation/references/data-formats.md](dataset-curation/references/data-formats.md) | Fine-tuning data formats: SFT vs preference records, chat templates |
| [peft-lora/references/hyperparameter-guide.md](peft-lora/references/hyperparameter-guide.md) | LoRA hyperparameter starting points (r, alpha, lr, dropout) |
| [training-optimization/references/gpu-memory-math.md](training-optimization/references/gpu-memory-math.md) | VRAM estimation formulas before launching a run |
| [training-optimization/references/distributed-training.md](training-optimization/references/distributed-training.md) | Multi-GPU ladder: DDP → FSDP → DeepSpeed |
| [preference-tuning/references/dpo-and-preference-data.md](preference-tuning/references/dpo-and-preference-data.md) | Preference-pair construction, DPO mechanics, reward hacking, distillation, run evaluation |

## Cross-Tree

| Topic | Location |
|-------|----------|
| Fine-tune vs prompt vs RAG decision | `${CLAUDE_SKILL_DIR}/prompt-engineering/prompt-design/SKILL.md` + `ai-engineer:ai-architector` |
| Tracking runs and registry promotion | `${CLAUDE_SKILL_DIR}/mlops/experiment-tracking/SKILL.md` |
| Versioned data → train → eval pipelines (DVC) | `${CLAUDE_SKILL_DIR}/mlops/ml-pipelines/SKILL.md` |
| Serving the tuned adapter or merged weights | `${CLAUDE_SKILL_DIR}/mlops/model-serving/SKILL.md` |
| Before/after measurement, win-rates | `${CLAUDE_SKILL_DIR}/evals/eval-design/SKILL.md` |
| Workflow stage participation | `${CLAUDE_SKILL_DIR}/_shared/workflow-integration/SKILL.md` |
