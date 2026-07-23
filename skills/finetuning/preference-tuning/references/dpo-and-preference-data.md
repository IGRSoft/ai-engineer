# Preference Tuning — Data and DPO Deep Dive

Deep-dive companion to [../SKILL.md](../SKILL.md): preference-pair construction, DPO mechanics with the smoke-scale run, reward hacking, distillation, and run evaluation.

## Building Preference Data

Pair-generation strategies and their traps:

| Strategy | How | Watch out |
|----------|-----|-----------|
| Sample-and-rank | N samples from the current policy at temp > 0; label best/worst | Pairs only cover the policy's existing range |
| Edit-based | Human edits a model output; edited = chosen, original = rejected | Strongest signal per hour; edits must target the preference dimension, not incidental typos |
| Cross-model | Stronger model = chosen vs current = rejected | Teaches imitation + style confounds; teacher license/ToS goes in the provenance ledger (`skills/finetuning/dataset-curation`) |
| Telemetry | Production thumbs up/down → KTO, or in-session pairs | Noisy labels, selection bias, PII scrubbing mandatory |
| Synthetic (judge-labeled) | LLM judge ranks sampled candidates | Inherits judge biases — length, position, self-preference (`skills/evals/llm-judge`); audit a human-labeled slice |

Labeling discipline:

- **Rubric first**: name the preference dimensions explicitly (groundedness?
  brevity? actionability?), give anchored examples, include "tie" and
  "both bad" outcomes. A pair labeled without a rubric encodes the
  annotator's mood.
- **Inter-annotator agreement**: double-label a slice (10–20%) and compute
  agreement (Cohen's kappa or similar; commonly ~0.6+ is treated as
  workable — task-dependent, so hedge and report the number). Low agreement
  means the *rubric* is broken — fix it before scaling labeling, and gate
  synthetic labeling on judge-vs-human agreement over the same slice.
- **Kill the confounds**: chosen/rejected must share the prompt exactly;
  strip systematic length/format differences unless they *are* the
  preference — otherwise the optimizer learns the confound (see Reward
  Hacking below).
- Pairs are a dataset: versioned, deduped, decontaminated, scrubbed through
  the full `skills/finetuning/dataset-curation` pipeline before training.

## DPO Mechanics

DPO raises the log-probability margin of chosen over rejected *relative to a
frozen reference model*; `beta` sets how hard the policy may push away from
that reference:

- **Low beta (~0.05)**: bigger behavioral moves, more drift and hacking risk.
- **High beta (~0.5)**: conservative, stays near the reference.
- **Start around 0.1 and sweep against held-out win rate** — never against
  training loss. These are conventional starting points, not constants;
  verify current TRL defaults (context7).
- **Reference model**: a frozen copy of the starting policy. With PEFT
  adapters, TRL derives the reference by disabling the adapter
  (`ref_model=None`) — no second full model in memory.
- **Watch `rewards/accuracies` and `rewards/margins`** in the logs: accuracy
  stuck near 0.5 = pairs too noisy/hard (data problem); accuracy at ~1.0
  within the first steps = pairs trivial or leaked (also a data problem).

```python
"""Smoke-scale DPO on chosen/rejected pairs — pipeline check, not the full run.

Smoke: capped MAX_STEPS on a 256-pair subsample (this file, as-is).
Full run: launch plan in .context/development-N.md, executed on the CUDA host.
"""
import torch
from datasets import load_dataset
from peft import LoraConfig
from trl import DPOConfig, DPOTrainer

SEED = 17
MAX_STEPS = 30


def main() -> None:
    pairs = load_dataset("json", data_files="data/pref/train.jsonl", split="train")
    smoke = pairs.shuffle(seed=SEED).select(range(min(256, len(pairs))))

    args = DPOConfig(
        output_dir="runs/dpo-smoke",
        beta=0.1,                          # starting point — sweep against held-out win rate
        max_steps=MAX_STEPS,               # smoke cap — never uncapped in DV
        per_device_train_batch_size=1,
        gradient_accumulation_steps=8,
        learning_rate=5e-7,                # DPO LRs sit far below SFT LRs — verify current TRL guidance
        bf16=torch.cuda.is_available(),    # MPS/CPU smoke: default dtype
        logging_steps=5,
        seed=SEED,
        report_to="mlflow",                # pair-set version + config logged — skills/mlops/experiment-tracking
    )
    trainer = DPOTrainer(
        model="<sft-checkpoint-or-adapter>",   # start from the SFT policy, revision-pinned
        ref_model=None,                        # PEFT path: frozen reference = adapter disabled
        args=args,
        train_dataset=smoke,
        peft_config=LoraConfig(r=16, lora_alpha=32, task_type="CAUSAL_LM"),
    )
    trainer.train()
    trainer.save_model("runs/dpo-smoke/adapter")


if __name__ == "__main__":
    main()
```

Run: `uv run python -m training.dpo_smoke`. Success: DPO loss falling,
`rewards/accuracies` climbing off 0.5 without saturating instantly, no NaN.
TRL argument names drift across minor versions — verify against current TRL
docs (context7) before running.

## Reward Hacking and Overoptimization

Every preference optimizer exploits what the signal underspecifies. Watch
for these from the first eval, not after shipping:

| Signal | What it looks like | Mitigation |
|--------|--------------------|------------|
| Length bias | Outputs grow across training; win rate correlates with length | Length-controlled win rate; length-matched pairs; brevity in the rubric |
| Sycophancy | Agrees with false premises; flattery inflation | Adversarial (wrong-premise) prompts in pairs and evals; rubric penalizes agreement-with-error |
| Style collapse | Every answer converges on one skeleton and stock phrases | More diverse pair sources; raise beta; fewer steps |
| Refusal miscalibration | Over- or under-refusing vs baseline | Safety slice in the eval pair; targeted pairs both directions |
| Eval-set overfit | Dev win rate climbs; held-out win rate flat or falling | Held-out rubric eval; early stop on held-out, never on dev |

Structural mitigations: diversify pair sources (no single generator/judge);
evaluate on **held-out rubrics** phrased differently from the labeling
rubric; tune beta up (or steps down) at the first drift signal; and keep a
fixed probe-prompt set whose generations you diff against the reference
model each run — a cheap KL-drift proxy that catches collapse early.

## Distillation as the Alternative

Teacher→student SFT on curated teacher outputs often beats preference tuning
on cost and stability:

- **When it wins**: a stronger model already produces the target behavior —
  you are transferring, not discovering. Generate with the teacher, filter
  and edit through the curation gates, SFT the student
  (`skills/finetuning/peft-lora`). No pair labeling, no reference model, no
  hacking dynamics beyond ordinary overfit.
- **Caveats**: teacher license/ToS for training on outputs is a ledger entry
  (`skills/finetuning/dataset-curation`) — check it before generating, not
  after; imitation transfers style more readily than capability; the same
  before/after eval pair still applies.
- **Combined pattern**: distill to competence, then a small DPO pass for
  taste — frequently cheaper than either method stretched to do both jobs.

## Evaluating Preference Runs

1. **Win rate vs the pre-tuning baseline** on a pinned, held-out prompt set,
   scored pairwise via `skills/evals/llm-judge` — position-debiased (swap
   sides), length-aware, judge at temperature 0, eval-set version recorded.
2. **General-capability regression slice** must hold
   (`skills/evals/regression-gates`) — preference tuning is the leading
   cause of silent capability tax.
3. **Report the triple** with every number: pair-set version + eval-set
   version + judge config (`skills/mlops/experiment-tracking`).
4. **Ship gate**: win rate over threshold AND no regression beyond the gate;
   wire both into CI so the gate outlives the person who ran it.
