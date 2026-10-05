# Fine-Tuning Skills Index

Every leaf and reference in `skills/finetuning/`. Start at
[SKILL.md](SKILL.md) for the stack snapshot and routing table.

## Skills

| Skill | Use it for |
|-------|------------|
| [dataset-curation/SKILL.md](dataset-curation/SKILL.md) | Raw sources → JSONL: messages-schema normalization, exact + near-dup dedup, eval-set decontamination, PII/secret scrubbing, license ledgers, stratified splits, versioning |
| [peft-lora/SKILL.md](peft-lora/SKILL.md) | Whether an adapter beats RAG or full fine-tuning, LoRA/QLoRA config starting points, smoke-scale SFTTrainer loops, merge-vs-serve, before/after evals |
| [training-optimization/SKILL.md](training-optimization/SKILL.md) | GPU memory model and estimation, the fit ladder (precision, accumulation, checkpointing, 8-bit optimizers, QLoRA), cuda/mps/cpu strategy, throughput and loss-curve triage, checkpoint/resume |
| [preference-tuning/SKILL.md](preference-tuning/SKILL.md) | SFT-only vs DPO vs ORPO/KTO vs RLHF, building and labeling chosen/rejected pairs, DPO (beta, reference model), reward-hacking detection |
| [grpo-rlvr-training/SKILL.md](grpo-rlvr-training/SKILL.md) | Verifiable-reward RL (GRPO/RLVR): applicability preconditions, reward-function design, the inspection gate, variant selection |
| [trace-to-training-data/SKILL.md](trace-to-training-data/SKILL.md) | Graded traces → SFT rows or preference pairs: rejection sampling, step-level masking, same-task pairs, goldens holdout |
| [checkpoint-promotion/SKILL.md](checkpoint-promotion/SKILL.md) | Four-stage gate, capability-drift budget, paired comparison vs base, forgetting checks, terminal PROMOTE/REJECT |
| [quantized-export/SKILL.md](quantized-export/SKILL.md) | Merged vs LoRA-only, format choice (FP8, AWQ INT4, GGUF), the pre/post smoke test |

## References

| File | Use it for |
|------|------------|
| [dataset-curation/references/data-formats.md](dataset-curation/references/data-formats.md) | Fine-tuning data formats: SFT vs preference records, chat templates |
| [peft-lora/references/hyperparameter-guide.md](peft-lora/references/hyperparameter-guide.md) | LoRA hyperparameter starting points (r, alpha, lr, dropout) |
| [training-optimization/references/gpu-memory-math.md](training-optimization/references/gpu-memory-math.md) | VRAM estimation formulas before launching a run |
| [training-optimization/references/distributed-training.md](training-optimization/references/distributed-training.md) | Multi-GPU ladder: DDP → FSDP → DeepSpeed |
| [preference-tuning/references/dpo-and-preference-data.md](preference-tuning/references/dpo-and-preference-data.md) | Preference-pair construction, DPO mechanics, reward hacking, distillation, run evaluation |
| [grpo-rlvr-training/references/reward-functions.md](grpo-rlvr-training/references/reward-functions.md) | Runnable reward functions (exact match, schema, sandboxed unit tests, length penalty, judge-as-reward) plus the inspection-set build |
| [trace-to-training-data/references/conversion-recipes.md](trace-to-training-data/references/conversion-recipes.md) | Worked trace→JSONL conversions, rejection-sampling loop, step masking, pair building, goldens-holdout gate, dataset-card fields |
| [checkpoint-promotion/references/gate-templates.md](checkpoint-promotion/references/gate-templates.md) | Promotion-report template, drift scoring table, sample-size/half-width arithmetic, paired-comparison protocol, replay-mix config |
| [quantized-export/references/export-commands.md](quantized-export/references/export-commands.md) | Per-format export commands, adapter merge, imatrix build, smoke-test script skeleton, artifact registration |

## Cross-Tree

| Topic | Location |
|-------|----------|
| Fine-tune vs prompt vs RAG decision | [prompt-design](../prompt-engineering/prompt-design/SKILL.md) + `ai-engineer:ai-architector` |
| Tracking runs and registry promotion | [experiment-tracking](../mlops/experiment-tracking/SKILL.md) |
| Versioned data → train → eval pipelines (DVC) | [ml-pipelines](../mlops/ml-pipelines/SKILL.md) |
| Serving the tuned adapter or merged weights | [model-serving](../mlops/model-serving/SKILL.md) |
| Before/after measurement, win-rates | [eval-design](../evals/eval-design/SKILL.md) |
