---
name: training-optimization
description: >-
  Make training runs fit in memory and run fast: GPU memory model and
  estimation, the fit ladder (precision, accumulation, checkpointing, 8-bit
  optimizers, QLoRA), cuda/mps/cpu device strategy, throughput and loss-curve
  triage, checkpoint/resume. Use when a run OOMs or crawls, when picking
  batch/accumulation/precision, when a loss curve is flat, spiky, or
  diverging, when planning a Mac smoke → CUDA full run, or when weighing
  distributed training.
---

# Training Optimization

Three failure classes — doesn't fit (memory), too slow (throughput), not
learning (loss pathology) — each with a fixed triage order. Estimate first,
measure second, change one lever at a time. This changes how a run
executes, never what it learns.

Owned by `ai-engineer:ml-engineer`. Works without CUDA: the dev loop runs on
MPS/CPU at smoke scale; the full run is a documented launch plan for a
Linux/CUDA host.

## When Not to Use

- Choosing the training *method* (LoRA vs full FT vs DPO) → `skills/finetuning/peft-lora`, `skills/finetuning/preference-tuning`, `ai-engineer:ai-architector`
- Loss weirdness caused by data (dups, contamination, masking bugs) → `skills/finetuning/dataset-curation`
- Inference latency/throughput → `skills/mlops/model-serving`, review via `ai-engineer:ai-performance-engineer`
- Tracking and comparing runs → `skills/mlops/experiment-tracking`

## The GPU Memory Model

Four consumers plus overhead:

```
total ≈ weights + gradients + optimizer states + activations + overhead
```

| Component | Scales with | Full FT (bf16 mixed) | LoRA | QLoRA |
|-----------|-------------|----------------------|------|-------|
| Weights | total params | 2 B/param | 2 B/param (frozen) | ~0.5–0.7 B/param (4-bit + scales) |
| Gradients | trainable params | 2 B/param | ~0 (adapters only) | ~0 |
| Optimizer (AdamW) | trainable params | 8 B/param fp32 moments (+4 B master copy) | ~0 | ~0 (paged) |
| Activations | batch × seq × hidden × layers | large | large | large |
| Overhead | framework/CUDA context, fragmentation | keep ≥10–15% headroom | same | same |

Rules of thumb: mixed-precision AdamW full FT lands around 12–16 bytes/param
*before* activations; LoRA ≈ 2 B/param + activations; QLoRA ≈ 0.55–0.7 B/param
for the frozen 4-bit base *plus* a roughly fixed ~1.25 GB of adapter, paged
optimizer and dequantization buffers — ≈5–6 GB for a 7B before activations,
not 0.6 B/param all-in. Worked 7B byte-accounting, activation drivers, and the
estimate→verify loop: read `references/gpu-memory-math.md` before any
launch on new hardware.

## The Fit Ladder

When the estimate doesn't fit, apply rungs in order and re-estimate after
each; stop at the first that fits with headroom, since every rung has a cost.

| # | Rung | Effect | Cost |
|---|------|--------|------|
| 1 | bf16, not fp32 | Halves weights/grads | Free on supported HW |
| 2 | Micro-batch ↓ + accumulation | Activations ↓, effective batch kept | Slightly more wall-clock |
| 3 | Gradient checkpointing | Activations ↓↓ | ~20–30% step time |
| 4 | 8-bit / paged optimizer | Optimizer states ↓ | Only helps full FT / large adapters |
| 5 | 4-bit base (QLoRA) | Frozen weights ↓ ~4x | Throughput ↓ — `skills/finetuning/peft-lora` |
| 6 | Sequence cap / packing | Activations scale with seq | Data decision — verify no answer truncation |
| 7 | Distributed / sharding | `references/distributed-training.md` | Complexity tax — last resort |

## Precision

- **bf16 is the default** wherever the hardware supports it: same exponent
  range as fp32, so fp16's overflow/loss-scaling machinery isn't needed.
- **fp16 only when bf16 is unsupported**: keep the loss scaler on, expect
  occasional skipped steps, and treat NaN as an fp16 smell first.
- **tf32** speeds fp32 matmuls on supporting NVIDIA hardware at negligible
  training-accuracy cost — defaults have changed across torch versions, so
  set it explicitly and verify against current torch docs (context7):

```python
import torch

torch.backends.cuda.matmul.allow_tf32 = True
torch.backends.cudnn.allow_tf32 = True
```

- **MPS/CPU**: dtype and kernel support shifts across torch releases — run
  the smoke loop in the default dtype rather than fighting dtype issues on a
  Mac. The full run belongs on CUDA anyway.

## Memory Levers: Batch, Accumulation, Checkpointing, Optimizer

```python
args = SFTConfig(
    per_device_train_batch_size=1,
    gradient_accumulation_steps=16,   # effective batch 16 at micro-batch memory
    gradient_checkpointing=True,      # rung 3: ~20-30% slower steps, far smaller activations
    optim="paged_adamw_8bit",         # bitsandbytes optimizers are CUDA-centric — verify availability
    bf16=torch.cuda.is_available() and torch.cuda.is_bf16_supported(),
)
```

- **effective_batch = micro_batch × accumulation × world_size.** The
  optimizer only sees the effective batch; accumulation buys the same
  gradient math at a fraction of the activation memory, paid in wall-clock.
  LR is calibrated to the *effective* batch — retune it whenever the
  effective batch changes.
- **Gradient checkpointing** recomputes activations during backward instead
  of storing them. Turn it on at rung 3, not by default — if the run fits
  without it, checkpointing is a pure ~20–30% slowdown. (Torch's reentrant
  flag semantics vary by version — verify current docs.)
- **Optimizer variants**: fp32-moment AdamW dominates memory in full FT
  (8 B/param); 8-bit and paged variants cut that sharply, and paged variants
  also absorb allocation spikes. For adapter-only training the optimizer is
  already tiny — rung 4 buys nothing there.

## Device Strategy (cuda / mps / cpu)

Select at runtime rather than hardcoding `.cuda()` or a device string:

```python
import torch


def pick_device() -> torch.device:
    if torch.cuda.is_available():
        return torch.device("cuda")
    if torch.backends.mps.is_available():
        return torch.device("mps")
    return torch.device("cpu")
```

The two-host workflow:

1. **Mac dev loop (MPS/CPU)**: small base model, subsampled data, capped
   steps. It proves the pipeline — data loads, template renders, masking is
   right, loss falls. It proves nothing about full-run memory or throughput.
2. **Linux/CUDA full run**: the documented launch plan (command, dataset
   version, expected duration/cost) executed on the training host, with the
   memory estimate verified there.

When `nvidia-smi` is absent, run the reduced-depth verification (allocator
stats only, `references/gpu-memory-math.md`), note the reduced depth in the
artifact, and continue rather than failing.

## Throughput Triage (in this order)

Measure one number — tokens/sec from the trainer logs — before and after
every change:

1. **Dataloader starving the GPU**: utilization sawtooths to ~0 between
   steps (`nvidia-smi` live view; on MPS, watch step-time variance). Fix:
   pre-tokenize with `dataset.map(..., batched=True)` and cache; raise
   `dataloader_num_workers`; pin memory.
2. **Tokenization on the fly**: same fix — tokenize once, cache, and pack
   short sequences to cut padding waste.
3. **Step time itself**: precision (tf32/bf16), fused or memory-efficient
   attention kernels where the stack supports them (availability varies by
   version — verify), and checkpointing overhead you enabled at rung 3.
4. **Comms (multi-GPU only)**: scaling efficiency well below linear →
   `references/distributed-training.md`.

## Loss-Curve Triage

| Shape | Likely causes | Actions |
|-------|--------------|---------|
| Flat from step 0 | LR too low; nothing trainable; labels fully masked | Check trainable params and one decoded batch; raise LR ×3–10 |
| Falls, then plateaus early | Schedule decayed too fast; capacity ceiling | Longer cosine horizon/warmup; more steps; capacity → `skills/finetuning/peft-lora` |
| Spiky | LR too high; tiny effective batch; outlier records | LR down; accumulation up; grad clip ~1.0; length-cap data |
| Diverging / NaN | fp16 overflow; LR spike; corrupt batch | bf16; warmup; grad clip; bisect the data |
| Train ↓ while val ↑ | Overfit; dup-heavy data | Fewer epochs; dedup → `skills/finetuning/dataset-curation`; dropout/weight decay |
| Val noisy beyond reading | Val split too small or unstratified | Fix the split → `skills/finetuning/dataset-curation` |

Data-shaped causes (masking, dups, splits) outnumber knob-shaped causes —
check the data explanation before the hyperparameter one. NaNs "fixed" by
reseeding are unexplained, not fixed.

## Checkpoint / Resume Discipline

- Size `save_steps` × `save_total_limit` so a crash costs a bounded, known
  amount of compute — cadence matters more as runs get longer.
- A real resume restores model + optimizer + scheduler + RNG state:
  `trainer.train(resume_from_checkpoint=...)`. Weights-only "resume" corrupts
  the schedule and the curve.
- **Verify continuity**: after a resume, the first logged losses continue
  the prior curve. A jump at the resume point is a broken resume — investigate.
- Weights in safetensors; don't load pickle checkpoints from untrusted
  sources. Checkpoints live in a registry/DVC/object storage, out of git;
  the path is recorded in the run config (`skills/mlops/experiment-tracking`).

## Smoke-Scale Rule

DV never launches full training runs. Every DV training invocation is
smoke-scale: capped `max_steps`/epochs, subsampled data, fixed seed, loss
verified decreasing with no NaN. The full run exists only as a documented
launch plan (command, dataset version, host, expected duration and cost) in
`development-N.md` — DR fails an artifact whose transcripts show an uncapped
invocation. The smoke run is also where the memory estimate gets verified
and the peak recorded.

## Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| Hardcoded `.cuda()` | Crashes the Mac/CPU dev loop | Runtime `pick_device()`; device-agnostic code |
| fp32 "to be safe" | Doubles weight/grad memory for nothing | bf16 wherever supported |
| Changing batch and LR together | Effects can't be attributed | One lever at a time; note the effective-batch/LR pairing |
| Checkpointing on by default | ~20–30% slower runs that would have fit anyway | Estimate first; enable at rung 3 |
| OOM-retry as a tuning strategy | Thrash without understanding | Estimate → verify → fit ladder (`references/gpu-memory-math.md`) |
| Weights-only resume | Silent schedule/RNG corruption, curve jump | `resume_from_checkpoint` with full state; verify continuity |
| Peak memory never recorded | Full run launches blind | Log `max_memory_allocated` on every smoke run |
| Multi-GPU before rungs 1–6 exhausted | Complexity tax without need | Fit ladder first; then `references/distributed-training.md` |
| torch/CUDA drift between smoke and full-run hosts | Smoke result doesn't transfer | Pin both; drift → `ai-engineer:ai-dependency-manager` |

## Verification

- [ ] Memory estimated (formulas / `references/gpu-memory-math.md`) and verified on the smoke run; peak recorded
- [ ] Precision decided at runtime (bf16 where supported); no hardcoded devices or dtypes
- [ ] Effective batch documented; LR retuned after any batch/accumulation change
- [ ] Fit-ladder rung recorded (which levers are on, and why)
- [ ] tokens/sec measured before and after each throughput change
- [ ] Loss curve triaged against the table; no unexplained shapes at handoff
- [ ] Checkpoint cadence set; resume tested once with verified loss continuity
- [ ] Smoke run capped + seeded + subsampled; transcript in `.context/logs/`
- [ ] Full-run launch plan documented (command, dataset version, host, duration/cost estimate)
- [ ] Run config, dataset version, and metrics logged per `skills/mlops/experiment-tracking`

## Related Skills

- `skills/finetuning/peft-lora` — the method whose runs this skill makes fit and go fast
- `skills/finetuning/dataset-curation` — data-shaped causes behind many loss pathologies
- `skills/finetuning/preference-tuning` — DPO-class runs; same fit and triage discipline applies
- `skills/mlops/experiment-tracking` — where estimates, peaks, and curves get logged
- `references/gpu-memory-math.md` — byte accounting, worked 7B examples, OOM ladder, unified memory
- `references/distributed-training.md` — DDP/FSDP/DeepSpeed selection, accelerate, multi-node
