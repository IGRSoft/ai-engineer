# GPU Memory Math

Use this when:

- Sizing a training job for specific hardware before launching it
- Explaining an OOM instead of retry-thrashing it
- Choosing between full FT, LoRA, and QLoRA on memory grounds
- Verifying that a smoke run's peak memory matches the estimate

Skip this file if:

- You want the ordered levers to make a run fit → [../SKILL.md](../SKILL.md) Fit Ladder
- The model fits but training is slow → throughput triage in [../SKILL.md](../SKILL.md)
- One GPU can't hold it even after the ladder → [distributed-training.md](distributed-training.md)

All numbers are estimates for planning; overheads (CUDA context, allocator
fragmentation, framework buffers) are real, so plan with ≥10–15% headroom
and always verify on the smoke run.

## Bytes per Component

| Component | Formula | Notes |
|-----------|---------|-------|
| Weights | params × bytes/param | fp32 4, bf16/fp16 2, int8 1, 4-bit ≈ 0.5 + quantization scales (~0.05–0.2 extra) |
| Gradients | trainable params × 2 (bf16) or 4 (fp32) | Only trainable params gradients exist |
| AdamW states | trainable params × 8 (two fp32 moments) | 8-bit optimizer ≈ 2 B/param states |
| fp32 master weights | trainable params × 4 | Mixed-precision recipes keep them; pure-bf16 recipes skip — framework-dependent |
| Activations | ≈ c × layers × batch × seq × hidden | c depends on kernels; attention adds a seq² term without memory-efficient/flash kernels |

## Worked Example: 7B-Class Model (~7 × 10⁹ params)

### Full fine-tune, bf16 mixed precision, AdamW

| Component | Math | Bytes |
|-----------|------|-------|
| Weights (bf16) | 7e9 × 2 | 14 GB |
| Gradients (bf16) | 7e9 × 2 | 14 GB |
| AdamW moments (fp32 × 2) | 7e9 × 8 | 56 GB |
| fp32 master weights | 7e9 × 4 | 28 GB (skipped in some pure-bf16 recipes) |
| **Subtotal before activations** | | **84–112 GB** |

Verdict: does not fit any single commodity GPU — this is sharding territory
([distributed-training.md](distributed-training.md)) or a reason to use
adapters instead.

### LoRA, bf16 base (r=16 on attention ≈ 0.2% trainable ≈ 15M params)

| Component | Math | Bytes |
|-----------|------|-------|
| Frozen base (bf16) | 7e9 × 2 | 14 GB |
| Adapter weights + grads (bf16) | 15e6 × 4 | ~60 MB |
| AdamW moments + master (fp32) | 15e6 × 12 | ~180 MB |
| **Subtotal before activations** | | **≈ 14.3 GB** |

Verdict: workable on a 24 GB card with room for activations; tight on 16 GB
(short sequences + checkpointing required).

### QLoRA, nf4 base + bf16 adapters

| Component | Math | Bytes |
|-----------|------|-------|
| Frozen base (4-bit + scales, double-quant) | 7e9 × ~0.55–0.7 | ≈ 3.9–4.9 GB |
| Adapter + optimizer (as above) | | ~0.25 GB |
| Dequant buffers + paged-optimizer headroom | | ~1 GB order |
| **Subtotal before activations** | | **≈ 5–6 GB** |

Verdict: workable on 12–16 GB cards; activations become the dominant term,
so sequence length and micro-batch set the ceiling.

## Activation Memory Drivers

- Scales ~linearly with **micro-batch** and (with flash/memory-efficient
  attention kernels) ~linearly with **sequence length**; naive attention
  adds a seq² term that dominates at long context.
- Scales with **hidden size × layers** — fixed per model choice.
- **Gradient checkpointing** stores only block-boundary activations and
  recomputes the rest in backward: a large reduction bought with ~20–30%
  step time.
- Practical magnitudes: at seq 1–4k and micro-batch 1–4 on a 7B-class model,
  activation footprints commonly land in the one-to-tens-of-GB range
  depending on kernels and checkpointing. Closed-form activation math is
  only order-of-magnitude reliable — measure it (below) rather than trusting
  a formula beyond that.

## Unified-Memory Systems

Where host and accelerator share one physical pool (integrated and
shared-memory architectures, including Apple silicon), the accounting above
still holds but the *budget* changes: weights + gradients + optimizer states +
activations all draw from the same pool the OS, the dataloader, and every other
process are using. There is no separate host-side headroom to fall back on.

Consequences for planning:

- **Budget against the pool minus what the system already holds**, not against
  the nominal total. The gap is not small on a workstation.
- **Host-side spill is not a rescue.** Offloading optimizer states "to CPU"
  moves bytes within the same pool — it can still help by changing *when*
  allocations live, but it does not add capacity the way it does on a discrete
  device.
- **Dataloader workers and cached batches compete with the model.** They are a
  line item here, not rounding error.
- Verify with the framework allocator plus process RSS, since a
  device-only view understates the true footprint.

## The Estimate → Verify Loop

1. **Estimate** with the tables above for your params/dtype/method.
2. **Smoke run** (capped steps, subsample — the [../SKILL.md](../SKILL.md)
   smoke-scale rule).
3. **Verify** with the allocator, not vibes:

```python
"""Peak-memory report for a smoke run. Call after trainer.train()."""
import torch


def report_peak() -> str:
    if torch.cuda.is_available():
        peak = torch.cuda.max_memory_allocated() / 2**30
        return f"cuda peak allocated: {peak:.1f} GiB\n{torch.cuda.memory_summary()}"
    if torch.backends.mps.is_available():
        return f"mps current: {torch.mps.current_allocated_memory() / 2**30:.2f} GiB"
    return "cpu run: use process RSS (psutil) — reduced-depth verification"
```

   Cross-check with `nvidia-smi` (process view: includes CUDA context, so it
   reads higher than `max_memory_allocated` — expect a ~0.5–1 GB+ gap).
   Record both numbers in the run log. When `nvidia-smi` is absent (Mac/CPU
   host), record allocator numbers only and note the reduced verification
   depth in the artifact — never hard-fail on a missing GPU.
4. **Compare** to the estimate. An unexplained gap beyond ~20–30% must be
   found before the full run — usual suspects: an eval loop building
   gradient graphs (missing `torch.inference_mode()`), a second model copy
   (reference model, EMA), fragmentation, or activations far above the
   guess (seq outliers in data).

## OOM Debugging Ladder

Work down; re-run the smoke test and record the peak after each rung; stop
at the first rung that fits with headroom.

1. **Read the error**: requested vs free vs reserved. A tiny request failing
   against a large reserved pool = fragmentation — try the torch allocator's
   expandable-segments option (env var name varies by torch version — verify
   current docs via context7).
2. **Micro-batch → 1**, cap sequence length (structured truncation only —
   never cut off the answer span; see
   [../../dataset-curation/references/data-formats.md](../../dataset-curation/references/data-formats.md)).
3. **Gradient checkpointing on.**
4. **8-bit / paged optimizer** (matters for full FT or very large adapters).
5. **4-bit base (QLoRA)** → [../../peft-lora/SKILL.md](../../peft-lora/SKILL.md).
6. **Audit the non-training memory**: eval/generation inside the loop under
   `torch.inference_mode()`, smaller eval batch, drop cached tensors;
   `torch.cuda.empty_cache()` between phases is a band-aid — note it as one.
7. **Still OOM** → sharding/offload: [distributed-training.md](distributed-training.md).

## Recording the Result

Every sized run leaves three numbers in the tracker
(`skills/mlops/experiment-tracking`): the estimate, the smoke-run peak, and
the headroom on the target card. A full-run launch plan that lacks them is
incomplete — the DV artifact should quote all three.
