# Distributed Training

Use this when:

- One GPU can't hold the run even after the full Fit Ladder ([../SKILL.md](../SKILL.md))
- Wall-clock on one GPU is genuinely unacceptable for the full run
- Choosing between DDP, FSDP, and DeepSpeed-class sharding
- Setting up `accelerate` for a multi-GPU launch, or consolidating sharded checkpoints

Skip this file if:

- The run fits on one GPU → single GPU + accumulation wins (see below)
- You're sizing memory → [gpu-memory-math.md](gpu-memory-math.md)
- The topology question is architectural (serving, multi-model) → `ai-engineer:ai-architector`

## Do You Need Distributed at All?

Single GPU + gradient accumulation beats multi-GPU whenever all three hold:

1. Model + optimizer fit on one card ([gpu-memory-math.md](gpu-memory-math.md) says so, verified);
2. The full-run wall-clock is acceptable (an overnight run is not a reason to distribute);
3. The team has better things to debug than NCCL.

Distributed adds launch complexity, comms debugging, checkpoint sharding,
extra nondeterminism sources, and a bigger failure blast radius. Accumulation
gives you any effective batch size on one device for free. Exhaust the Fit
Ladder first; treat multi-GPU as rung 7, not rung 2. For fine-tuning
workloads, LoRA/QLoRA on one GPU replaces the most common historical reason
to shard.

## Strategy Selection

| Strategy | What it does | Use when | Cost |
|----------|--------------|----------|------|
| DDP | Full model replica per GPU; all-reduce gradients | Model + optimizer fit on one GPU; you want data-parallel speedup | Comms per step; per-GPU memory unchanged |
| FSDP (ZeRO-3-class) | Shards params + grads + optimizer states across GPUs | Model/optimizer do NOT fit on one GPU | More comms; wrap-policy and state-dict config complexity |
| DeepSpeed ZeRO-1/2/3 | Shards optimizer / +grads / +params (stage-selectable) | Same class of problem as FSDP; ecosystem preference | JSON config surface; version coupling |
| CPU/NVMe offload (FSDP or ZeRO variants) | Spills shards to host memory/disk | Last resort before more GPUs | Severe throughput hit |
| Tensor / pipeline parallel | Splits individual layers/stages across GPUs | Very large models, pretraining scale | Out of scope for this plugin's fine-tuning work — consult `ai-engineer:ai-architector` |

FSDP vs DeepSpeed: overlapping capability classes; both integrate with HF
Trainer/TRL via `accelerate`. Choose by ecosystem fit, team familiarity, and
what your checkpoint/serving tooling expects — feature details shift between
releases, so verify current accelerate/DeepSpeed docs (context7) before
committing.

Decision sketch:

```
fits on 1 GPU? ── yes → single GPU + accumulation (done)
      │ no
      ├─ fits with QLoRA/checkpointing? → yes → still single GPU
      │ no
      ├─ replica fits, need speed → DDP
      └─ replica doesn't fit     → FSDP / ZeRO-3 (+offload only if forced)
```

## accelerate Basics

Generate the config interactively — do not hand-write it from memory (field
names and values change across accelerate versions):

```bash
uv run accelerate config
uv run accelerate launch -m training.sft
```

A minimal FSDP config for orientation (regenerate rather than copy —
field names are version-dependent, verify via context7):

```yaml
compute_environment: LOCAL_MACHINE
distributed_type: FSDP
num_processes: 4
mixed_precision: bf16
fsdp_config:
  fsdp_sharding_strategy: FULL_SHARD
  fsdp_auto_wrap_policy: TRANSFORMER_BASED_WRAP
  fsdp_state_dict_type: SHARDED_STATE_DICT
```

Launch-time discipline:

- **Effective batch multiplies by world size** (micro × accumulation ×
  num_processes). Re-derive it and retune LR — the single-GPU LR is no
  longer calibrated.
- **Seed everything** and record the world size in the run config: the same
  seed at a different world size is a different run.
- **Data sharding**: each rank sees a shard; keep the dataset version pinned
  (`skills/finetuning/dataset-curation`) so shard membership is reproducible.
- **Smoke it first**: the smoke-scale rule applies to distributed too — a
  capped-step multi-GPU smoke run validating that all ranks print the
  expected device and world size, loss falls, and a checkpoint round-trips,
  before the full launch plan executes.

## Multi-Node Cautions

- **Interconnect dominates.** Without fast inter-node links, scaling
  efficiency collapses and two nodes can be slower than one. Measure
  scaling efficiency (throughput per GPU vs single-node) before committing
  a long run.
- **NCCL debugging**: `NCCL_DEBUG=INFO` on a tiny job is the first tool for
  hangs and rendezvous failures; check firewall/interface selection before
  suspecting the code.
- **Version skew kills silently**: identical torch/CUDA/driver and `uv.lock`
  environments on every node — drift belongs to
  `ai-engineer:ai-dependency-manager` to pin down.
- **Blast radius**: one rank OOM or one node reboot kills the whole job —
  checkpoint cadence matters more than on one GPU, and the launch plan
  should state the restart procedure.
- Prefer exhausting one node (more accumulation, QLoRA, checkpointing)
  before adding a second; multi-node is a step change in operational cost.

## Checkpoint Sharding and Consolidation

- FSDP/ZeRO save **sharded state dicts** (one file set per rank) — fast to
  write, but loadable only into the same topology.
- **Consolidate offline** into a single full state dict for serving, evals
  outside the training topology, or archival. Do it with the stack's
  dedicated utility or a rank-0 gather in a separate script — consolidating
  inline at save time risks OOM gathering the full model on one rank.
  (Utility names differ per stack and version — verify current FSDP/
  DeepSpeed/accelerate docs via context7.)
- Never assume a sharded checkpoint loads at a different world size without
  conversion; record sharding strategy, world size, and consolidation
  status in the run config (`skills/mlops/experiment-tracking`).
- Consolidated artifacts are safetensors, stored in a registry/DVC/object
  storage — never git, never pickle.

## Pre-Launch Checklist

- [ ] Fit Ladder exhausted; the reason distributed is required is written down
- [ ] Strategy chosen from the table (DDP vs FSDP/ZeRO) with the memory math attached
- [ ] `accelerate` config generated (not hand-written) and committed with the launch plan
- [ ] Effective batch re-derived for the world size; LR retuned
- [ ] Capped-step distributed smoke run passed: ranks/devices correct, loss falls, checkpoint round-trips
- [ ] Checkpoint cadence + restart procedure in the launch plan
- [ ] Consolidation step planned for the final checkpoint; target format safetensors
- [ ] Environments identical across nodes (`uv.lock`, torch/CUDA) — verified, not assumed
