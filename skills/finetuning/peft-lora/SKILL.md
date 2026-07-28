---
name: peft-lora
description: >-
  Parameter-efficient fine-tuning with LoRA and QLoRA via PEFT + TRL: when
  adapters beat full fine-tuning or RAG, config anatomy (r, alpha, dropout,
  target_modules) with starting points, QLoRA memory trade-offs, smoke-scale
  SFTTrainer loops, adapter save/merge/serve lifecycle, and before/after eval
  discipline. Use when adding a LoRA adapter, picking r/alpha/learning-rate
  values, fitting a fine-tune into limited VRAM, deciding merge-vs-serve for
  an adapter, or debugging flat loss, catastrophic forgetting, or an overfit
  adapter.
---

# PEFT / LoRA

**Adapt behavior with ~0.1–1% of the parameters — and prove it with before/after evals**

## Overview

LoRA freezes the base model and injects trainable low-rank matrices into
targeted linear layers; only those matrices train. That makes fine-tuning
cheap to run, fast to iterate, and swappable at serve time — an adapter is a
small file, not a new model. QLoRA additionally quantizes the frozen base to
4-bit so the same job fits on far smaller GPUs. The craft is in three
decisions: whether an adapter is the right tool at all, which config to start
from, and how to prove the adapter helped without breaking anything else.

Owned by `ai-engineer:ml-engineer`. The dataset must clear
`skills/finetuning/dataset-curation` before any config discussion matters.

## When to Use

- Teaching a style, tone, or persona the base model doesn't hold consistently
- Enforcing an output format (strict JSON, DSL, report structure) prompts can't lock in
- Adapting to a domain's phrasing and workflows from a curated instruction set
- Fine-tuning under a VRAM budget (single workstation or consumer GPU)
- Serving several per-tenant or per-task behaviors over one shared base

**When NOT to use:**

- Injecting fresh or changing knowledge → retrieval (`skills/llm-apps/rag-systems`); weights go stale, and facts don't compress into low-rank updates
- Deep capability shifts (new language, large reasoning gains) → full fine-tune territory; run the method decision with `ai-engineer:ai-architector` first
- Aligning behavior with preference pairs → `skills/finetuning/preference-tuning` (DPO also trains over LoRA adapters)
- The run doesn't fit in memory or is slow → `skills/finetuning/training-optimization`
- The dataset isn't curated/versioned yet → `skills/finetuning/dataset-curation`

## Is LoRA the Right Tool?

| You want the model to… | Right tool | Why |
|------------------------|-----------|-----|
| Follow a house style / tone / persona | LoRA | Behavior, not knowledge; small curated data suffices |
| Emit a strict format every time | LoRA | Format is a learnable surface pattern |
| Speak a domain's language (terms, workflows) | LoRA, often + RAG | Phrasing learns well; facts stay in retrieval |
| Answer from changing or private facts | RAG, not tuning | Retrieval updates daily; adapters don't |
| Gain a new capability (language, tool-use depth, reasoning) | Full FT or a different base | Low-rank updates can't carry it |
| Prefer some answers over others | SFT-LoRA, then DPO | `skills/finetuning/preference-tuning` |

Contested or high-stakes calls: `ai-engineer:ai-architector` owns the
RAG-vs-finetune-vs-prompt decision framework — consult before collecting
data, not after a failed run.

## Config Anatomy

```python
from peft import LoraConfig

peft_config = LoraConfig(
    r=16,                     # rank of the update matrices — adapter capacity
    lora_alpha=32,            # scaling; effective update scale ≈ alpha / r
    lora_dropout=0.05,        # regularization on the adapter path
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj"],
    task_type="CAUSAL_LM",
)
```

Starting points by scenario — initialization values to sweep from, not
answers:

| Scenario | r | alpha | target_modules | dropout |
|----------|---|-------|----------------|---------|
| Style / persona adapter | 8–16 | ≈2r | attention projections (q, k, v, o) | 0.05 |
| Format enforcer | 8–16 | ≈2r | attention projections | 0.05–0.1 |
| Domain assistant | 16–64 | ≈2r | attention + MLP (gate/up/down) | 0.05 |
| Any of the above via QLoRA | same | same | often all linear layers | 0.05–0.1 |

- **alpha ≈ 2r is a heuristic starting point, not a law.** Effective scale is
  `alpha / r`, so the two knobs are coupled — hold the ratio, sweep r and
  learning rate first, and only then revisit alpha.
- Raising r buys capacity, VRAM, and overfit risk together. Before going past
  r ≈ 64, widen `target_modules` to the MLP blocks instead — coverage usually
  beats rank.
- Module names differ per architecture — print the model to list them, or use
  the all-linear-layers option where your PEFT version supports it (verify
  current PEFT docs via context7).
- Per-knob effects, sweep order, and three worked config progressions: read
  `references/hyperparameter-guide.md` before tuning anything.

## QLoRA: 4-bit Base + Adapters

```python
import torch
from transformers import AutoModelForCausalLM, BitsAndBytesConfig

bnb = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_compute_dtype=torch.bfloat16,
    bnb_4bit_use_double_quant=True,
)
model = AutoModelForCausalLM.from_pretrained(
    "<base-model-id>", revision="<pinned-sha>", quantization_config=bnb
)
```

Trade-offs to decide with eyes open:

- **Memory**: the frozen base shrinks ~4x vs bf16, putting 7B-class SFT on a
  single consumer GPU. Worked byte accounting:
  `skills/finetuning/training-optimization/references/gpu-memory-math.md`.
- **Throughput**: on-the-fly dequantization slows steps versus bf16 LoRA —
  fine for iteration, but count it in the full-run duration estimate.
- **Quality**: for style/format/domain adaptation, QLoRA typically tracks
  bf16 LoRA closely; degradation shows first on precision-sensitive targets
  (math, code edge cases, long structured outputs). Decide with the
  before/after eval, never by assumption.
- **Platform**: bitsandbytes is CUDA-centric; support elsewhere varies —
  verify current docs. On a no-CUDA dev box (Mac), skip 4-bit: smoke-test the
  pipeline with a small base model instead, and run QLoRA on the Linux/CUDA
  host.

## Smoke-Scale Training Loop (TRL SFTTrainer)

DV rule: training runs in development are smoke-scale only — capped
`max_steps`, subsampled data, fixed seed. The full run is a documented launch
plan (command, dataset version, host, expected duration/cost) in the DV
artifact, executed outside DV.

```python
"""Smoke-scale LoRA SFT: verifies data → template → falling loss end to end.

Smoke run: capped at MAX_STEPS on a 256-record subsample (this file, as-is).
Full run: launch plan in .context/development-N.md — same module, step cap
lifted, executed on the CUDA host, never in DV.
"""
import torch
from datasets import load_dataset
from peft import LoraConfig
from trl import SFTConfig, SFTTrainer

SEED = 17
MAX_STEPS = 30


def pick_device() -> str:
    if torch.cuda.is_available():
        return "cuda"
    if torch.backends.mps.is_available():
        return "mps"
    return "cpu"


def main() -> None:
    device = pick_device()
    full = load_dataset("json", data_files="data/sft/train.jsonl", split="train")
    smoke = full.shuffle(seed=SEED).select(range(min(256, len(full))))

    args = SFTConfig(
        output_dir="runs/sft-smoke",
        max_steps=MAX_STEPS,               # smoke cap — never uncapped in DV
        per_device_train_batch_size=1,
        gradient_accumulation_steps=8,     # effective batch 8
        learning_rate=2e-4,
        lr_scheduler_type="cosine",
        warmup_ratio=0.03,
        bf16=device == "cuda",             # MPS/CPU smoke: default dtype — see training-optimization
        logging_steps=5,
        seed=SEED,
        report_to="mlflow",                # config + dataset version logged — skills/mlops/experiment-tracking
    )
    trainer = SFTTrainer(
        model="<base-model-id>",           # pin revision=<sha>; never a floating tag
        args=args,
        train_dataset=smoke,
        peft_config=LoraConfig(
            r=16, lora_alpha=32, lora_dropout=0.05,
            target_modules=["q_proj", "k_proj", "v_proj", "o_proj"],
            task_type="CAUSAL_LM",
        ),
    )
    trainer.model.print_trainable_parameters()  # expect ~0.1-1% trainable
    trainer.train()
    trainer.save_model("runs/sft-smoke/adapter")


if __name__ == "__main__":
    main()
```

Run: `uv run python -m training.sft_smoke`. Success criteria: loss clearly
decreasing across the capped steps, no NaN, trainable-parameter percentage
sane, and one generated sample renders through the chat template correctly.
TRL renames constructor arguments across minor versions (tokenizer→
processing_class and max_seq_length→max_length have both happened) — verify
the current TRL docs (context7) rather than trusting any example, including
this one.

## Adapter Lifecycle

Save the adapter separately — it is a few MB to a few hundred MB
(`adapter_model.safetensors` + `adapter_config.json`); never re-save the
base. Record alongside it: base model id + revision, dataset version, LoRA
config, seed (`skills/mlops/experiment-tracking`).

| Situation | Choice |
|-----------|--------|
| Several tenants/tasks over one base | Serve adapters — multi-LoRA serving keeps one base in memory (`skills/mlops/model-serving`) |
| Single behavior on a latency-critical path | Merge (`merge_and_unload()`) and save the merged model |
| Downstream quantization (GPTQ/AWQ/GGUF) of the final model | Merge first, then quantize the merged weights |
| QLoRA-trained adapter | Do not merge into the 4-bit base — merging there is lossy; merge into the full-precision base weights (verify current PEFT guidance) |

```python
merged = trainer.model.merge_and_unload()
merged.save_pretrained("runs/sft-final/merged", safe_serialization=True)  # safetensors, never pickle
```

Merged models and adapters live in a registry/DVC/object storage — never in
git.

## Evaluating Adapters

An adapter without a before/after eval is an anecdote:

1. **Baseline first**: run the pinned eval set (version recorded) against the
   bare base model — temperature 0, fixed seeds, per the determinism rules in
   `skills/evals/eval-design`.
2. **Same command, adapter on**: the target metrics must move.
3. **General-capability slice**: a held-out slice of unrelated tasks must NOT
   regress — this is the catastrophic-forgetting detector.
4. **Gate it**: wire both into `skills/evals/regression-gates`; subjective
   quality (style, tone) goes through `skills/evals/llm-judge`.

## Failure Modes

| Symptom | Likely cause | Action |
|---------|--------------|--------|
| Loss flat from step 0 | LR too low; wrong `target_modules` (nothing trainable); labels fully masked | `print_trainable_parameters()`; raise LR; decode one batch's unmasked labels |
| Loss falls, generations unchanged | Adapter not loaded at inference; chat-template mismatch | Load the adapter explicitly; render-and-diff train vs serve templates |
| Train loss down, val loss up early | Overfit: too many epochs, dup-heavy data | Fewer epochs; dedup (`skills/finetuning/dataset-curation`); dropout up |
| General capability regressed | Catastrophic forgetting | Mix in general instruction data (a small single-digit % is a common starting point); lower r/epochs |
| NaN loss | fp16 overflow; LR spike; corrupt batch | bf16 instead of fp16; warmup; grad clipping; bisect the data |
| OOM | Model + activations over budget | Fit ladder in `skills/finetuning/training-optimization` (QLoRA, checkpointing, accumulation) |

## Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| LoRA to inject facts | Facts don't fit low-rank updates and go stale immediately | RAG (`skills/llm-apps/rag-systems`); `ai-engineer:ai-architector` consult |
| Raising r before fixing data | Capacity amplifies noise | Curate first, then sweep r on a subsample |
| Tuning alpha as a free knob | Scale is `alpha / r` — the knobs are coupled | Hold alpha ≈ 2r; sweep r and LR first |
| "Loss went down, ship it" | Loss ≠ behavior; regressions are invisible without evals | Before/after pinned evals + general-capability slice |
| Committing a merged model to git | Multi-GB repo, unusable history | Save the adapter; artifacts go to a registry/DVC |
| Pickle checkpoints | Unsafe deserialization on load | safetensors everywhere (`safe_serialization=True`) |
| Unpinned base revision | Upstream update silently breaks adapter compatibility | Pin `revision=<sha>` for model and tokenizer; record it |
| Uncapped training in DV | Violates the smoke-scale rule; DR fails the artifact | `max_steps` cap + documented full-run launch plan |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "The loss curve looks great, ship it" | Overfit adapters produce beautiful loss and broken behavior; only the eval pair knows |
| "r=256, more capacity can't hurt" | It can: overfit, VRAM, slower steps; widen modules or fix data instead |
| "QLoRA quality loss won't matter here" | Maybe — but that's an eval result, not an assumption |
| "One more epoch won't overfit" | On a 1k-example set, one epoch is a large dose; watch val each epoch |
| "Skip the general-capability slice, we only changed style" | Forgetting is silent; the target metric can improve while everything else degrades |
| "The default chat template will be fine" | Template mismatch is the top "trained fine, serves garbage" cause |

## Red Flags

- `print_trainable_parameters()` never checked — or shows 0% or ~100%
- No baseline eval existed before training started
- Adapter trained against one base revision, served against another
- fp16 NaNs being "fixed" by restarting the run
- An uncapped training invocation in a DV transcript
- Adapter files tracked in git, or checkpoints saved via pickle
- Eval-set version or dataset version missing from the run config

## Verification

- [ ] Method decision recorded (LoRA vs RAG vs full FT); `ai-engineer:ai-architector` consulted when contested
- [ ] Dataset versioned and curated — `skills/finetuning/dataset-curation` checklist passed
- [ ] Base model id + revision pinned (model and tokenizer); recorded in the run config
- [ ] Trainable-parameter count printed and sane (~0.1–1%)
- [ ] Smoke run: capped steps, subsample, fixed seed, decreasing loss, no NaN; transcript in `.context/logs/`
- [ ] Full-run launch plan documented (command, dataset version, host, expected duration/cost)
- [ ] Adapter saved separately as safetensors; merge decision recorded with rationale
- [ ] Before/after evals on the pinned set at temperature 0; general-capability slice non-regressing
- [ ] Run config + metrics logged per `skills/mlops/experiment-tracking`

## Related Skills

- `skills/finetuning/dataset-curation` — the dataset gates that precede any config tuning
- `skills/finetuning/training-optimization` — memory fit, precision, throughput, loss triage
- `skills/finetuning/preference-tuning` — DPO-class alignment on top of an SFT adapter
- `skills/evals/regression-gates` — gating adapter deployment on eval evidence
- `skills/mlops/model-serving` — serving adapters vs merged models
- `references/hyperparameter-guide.md` — per-knob effects, sweep strategy, worked progressions
