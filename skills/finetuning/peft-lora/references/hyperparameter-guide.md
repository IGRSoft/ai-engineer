# LoRA Hyperparameter Guide

Use this when:

- Tuning a LoRA/QLoRA run beyond the starting-point table in [../SKILL.md](../SKILL.md)
- Planning a sweep and deciding which knob to move first
- Reading W&B/MLflow curves from a finished or running sweep
- Sanity-checking a config someone else proposed

Skip this file if:

- You haven't confirmed LoRA is the right tool → [../SKILL.md](../SKILL.md) decision table
- The run doesn't fit in memory → [../../training-optimization/SKILL.md](../../training-optimization/SKILL.md)
- Loss pathologies (NaN, spikes) → loss-curve triage in training-optimization

All numbers below are starting points and observed working ranges — treat
them as sweep initializations, never as answers. The eval pair (target
metric + general-capability slice) is the only arbiter.

## Per-Knob Effects

| Knob | Raising it | Lowering it | Common starting point |
|------|-----------|-------------|----------------------|
| `r` (rank) | More capacity; more VRAM; overfit risk on small sets | Cheaper; may underfit domain tasks | 8–16 style/format; 16–64 domain |
| `lora_alpha` | Stronger update scale (`alpha / r`) | Weaker updates | ≈ 2r, held while sweeping r |
| `lora_dropout` | More regularization; slower fit | Faster fit on large clean data | 0.05 (0.1 on small/dup-prone sets) |
| Learning rate | Faster fit; instability, spikes | Flat loss, wasted steps | ~1e-4–3e-4 for LoRA SFT; sweep log-scale |
| LR schedule | — | — | Cosine + warmup; constant is fine for short smoke runs |
| Epochs / steps | More exposure; overfit past the knee | Underfit | 1–3 epochs on small sets |
| Effective batch (micro × accum) | Smoother gradients; LR usually rises with it | Noisier updates | 8–64 |
| Warmup | More stability at start | Earlier progress; spike risk | ratio ≈ 0.03 |
| Weight decay | Mild regularization | — | 0–0.1 |
| NEFTune-style noise | Embedding-noise regularization; can lift instruct quality | Off = default behavior | Try ~5–15 if overfit/repetition shows (flag name varies by TRL version — verify via context7) |

Knob interactions that bite:

- **alpha and r are one knob**: effective scale is `alpha / r`. Doubling r
  while keeping alpha *halves* the update scale — hold alpha ≈ 2r during r
  sweeps or you're sweeping two things at once.
- **LR pairs with effective batch**: change accumulation or micro-batch and
  the LR that worked before is no longer calibrated. Retune LR after any
  batch change.
- **Epochs vs steps**: what matters is *examples seen ÷ dataset size*. On a
  600-example set, 3 epochs is 1,800 exposures — a big dose. Prefer
  `max_steps` for mixed/streaming data, epochs for small fixed sets, and
  always compute the implied epoch count before launching.
- **Dropout and weight decay** are second-order: reach for them only when
  the curves show overfit, after epochs and data dedup are handled.

## Sweep Strategy (on a Subsample)

Never sweep on the full run. Freeze everything, then move one axis at a time:

1. **Freeze the substrate**: dataset version pinned, seed fixed, eval set
   pinned, base revision pinned. Log every run
   (`skills/mlops/experiment-tracking`) — an unlogged sweep run is a wasted
   GPU-hour.
2. **Subsample**: 10–20% of train, stratified by source/task type; short
   runs (a few hundred steps).
3. **Sweep LR first, log-scale** — it is the biggest lever:
   `{5e-5, 1e-4, 2e-4, 4e-4}`. Keep the best two.
4. **Then r** ∈ `{8, 16, 32, 64}` with alpha = 2r, at the surviving LRs.
5. **Then regularization** (dropout, weight decay, NEFTune-style noise) —
   only if the subsample curves show overfit.
6. **Finalists to full data**: top 1–2 configs run on the full set with the
   full before/after eval pair from [../SKILL.md](../SKILL.md).

Grid beats fancy search at this scale — the grid above is ~12–16 short runs.
Keep a sweep manifest (config → run id → metric) in the tracker so the
winning config is reproducible from its logged parameters alone.

## Reading Tracker Curves (W&B / MLflow)

| Curve signature | Meaning | Action |
|-----------------|---------|--------|
| Train loss stair-steps down exactly at epoch boundaries | Memorization setting in | Stop earlier; check dup ratio (`../../dataset-curation/SKILL.md`) |
| Val tracks train, then departs upward | Classic overfit knee | Checkpoint at the knee; reduce epochs; add dropout |
| Loss oscillates at constant amplitude | LR too high for the effective batch | LR down one log-step, or accumulation up |
| Grad-norm spikes on scattered steps | Outlier records (giant/degenerate) | Length-cap and re-validate data; clip grads |
| Loss falls but target eval metric flat | Loss–metric mismatch | Eval set may not measure the target — revisit `skills/evals/eval-design` |
| Smooth loss, general-capability slice degrading | Forgetting in progress | Mix general data; lower r/epochs; earlier stop |

Log both loss curves *and* the periodic eval metric — loss alone cannot
distinguish "learning the task" from "memorizing the set".

## Worked Config Progressions

Illustrative narratives (numbers rounded); the *shape* of each progression is
the lesson — change one thing per iteration, let the eval pair decide.

### Scenario A — style adapter (≈800 examples)

| Iter | Config | Observation | Next move |
|------|--------|-------------|-----------|
| v0 | r=8, α=16, LR 2e-4, 2 epochs, attention-only | Style present; val knee at ~1.2 epochs | Cut exposure |
| v1 | 1 epoch, dropout 0.1 | Knee gone; persona drifts on long multi-turn chats | Capacity, not exposure |
| v2 | r=16, α=32, 1 epoch | Judge win-rate up vs v1; general slice flat | Ship v2; record config + dataset version |

### Scenario B — domain assistant (≈12k examples)

| Iter | Config | Observation | Next move |
|------|--------|-------------|-----------|
| v0 | r=16, α=32, LR 2e-4, 1 epoch, attention-only | Terminology right; multi-step workflows shallow | Widen coverage before rank |
| v1 | + MLP modules (gate/up/down) | Workflows improve; VRAM up ~parameter-count worth; step time up | Check capacity ceiling |
| v2 | r=32, α=64, LR 1e-4 | Marginal gain over v1; slower | Diminishing returns — keep v1 |
| v3 | v1 + 5% general instruction mix | General-capability slice recovers to baseline | Ship v3 |

### Scenario C — format enforcer (strict JSON, ≈2k examples)

| Iter | Config | Observation | Next move |
|------|--------|-------------|-----------|
| v0 | r=8, α=16, LR 2e-4, 2 epochs | Parse rate up, but invalid JSON on edge branches | Data gap, not knobs |
| v1 | Data: add failure-branch examples (`../../dataset-curation/SKILL.md`), same config | Parse rate near-perfect; occasional schema-field hallucination | Tighten exposure |
| v2 | 1 epoch + completion-only masking verified on a decoded batch | Hallucinated fields gone; general slice flat | Ship v2; gate on parse-rate in CI (`skills/evals/regression-gates`) |

The recurring pattern: **data fixes beat knob fixes** (A/v2 is the only pure
capacity win; B/v3 and C/v1 are data moves), and every progression ends with
an eval-pair verdict, not a loss reading.

## Recording the Winner

The shipped config is an experiment artifact, not tribal knowledge. In the
tracker run for the final adapter, confirm these are present:

- Full `LoraConfig` + trainer args (the tracker's params view)
- Dataset version hash + eval-set version + seed
- Base model id + revision
- Sweep manifest link (which runs were compared, on what subsample)

If any of these is missing, the sweep is unreproducible — fix the logging
before the next run, per `skills/mlops/experiment-tracking`.
