---
name: grpo-rlvr-training
description: >-
  Train with verifiable rewards (GRPO/RLVR) when a program checks success
  (unit tests, schemas, math): applicability preconditions, reward-function
  design, the inspection gate, and variant selection. Use when writing GRPO
  reward functions or when a run reward-hacks. Not preference pairs
  (preference-tuning).
---

# GRPO / RLVR Training

**Input:** a routing decision (RLVR via GRPO), a programmatic verifier for the
target task (test runner, schema validator, executor, or exact-match checker),
and a base model whose success rate on that task is already nonzero.

**Output:** a validated GRPO config plus reward functions that have been read
against a 50–100-sample inspection set — concrete kwargs and Python, not
free-form advice.

GRPO samples a group of completions per prompt, scores them with your reward
function, and pushes the policy toward the above-average members. The reward
function is the specification: GPU hours, instability, and reward hacking all
trace back to whether it measures what you want.

DPO for taste, GRPO for reasoning. A preference between two acceptable outputs
belongs in `skills/finetuning/preference-tuning`; a program returning pass/fail
belongs here.

Owned by `ai-engineer:ml-engineer`. Adopting RL is a method escalation that
`ai-engineer:ai-architector` signs off, because RLVR costs multiples of an SFT
run and adds reward hacking as a failure mode.

**Route elsewhere when:**

- Grading needs human judgment → calibrate first per `skills/evals/llm-judge`; an uncalibrated judge is not a verifier
- The signal is "this answer beats that one" → `skills/finetuning/preference-tuning`
- The model never succeeds at the task → `skills/finetuning/peft-lora`; RL sharpens a capability, it does not install one
- Turning already-graded traces into training rows → `skills/finetuning/trace-to-training-data`
- The run OOMs or crawls → `skills/finetuning/training-optimization`

## Is the Reward Actually Verifiable?

Two preconditions; failing either sends the work elsewhere before any GPU time.

**1. A program decides success.** A deterministic checker returns pass or fail
— not "a rubric exists". An LLM judge qualifies only after clearing the
calibration bar in `skills/evals/llm-judge`, and even then it is the weakest
verifier class: the policy can learn to exploit the judge instead of the task.

**2. The base model already succeeds sometimes.** Sample the task at
temperature 0.7 across a few dozen prompts and count.

| Base success rate | Meaning | Route |
|---|---|---|
| 0% | Format or comprehension gap, not a policy gap | SFT first (`skills/finetuning/peft-lora`), return when nonzero |
| Low but nonzero | The GRPO sweet spot — signal to reweight toward | Proceed to The Recipe |
| Near ceiling | Nothing left for RL to sharpen | Spend the budget on evals or a harder task slice |

A zero base rate is the most common wasted run: every completion in a group
scores the same, so the group-relative advantage is zero and there is no
gradient.

## The Recipe

TRL's `GRPOTrainer` with vLLM-backed generation is the reference path. Trainer
kwargs move between TRL minors — verify names against TRL's docs (context7)
and pin the version in `uv.lock`.

```python
# uv add trl vllm  — pin in uv.lock; GRPOConfig kwargs move between TRL minors
from trl import GRPOConfig, GRPOTrainer

grpo_args = GRPOConfig(
    output_dir="outputs/grpo-smoke",
    use_vllm=True,
    vllm_mode="colocate",        # single GPU; "server" when generation gets its own device
    num_generations=8,           # floor — see below
    learning_rate=5e-7,          # settled range for GRPO; orders below SFT
    beta=0.01,                   # KL coefficient against the frozen reference policy
    per_device_train_batch_size=8,
    gradient_accumulation_steps=4,
    bf16=True,
    max_steps=50,                # smoke scale first; full run is a launch plan
    seed=3407,
)

trainer = GRPOTrainer(
    model=SFT_CHECKPOINT,
    args=grpo_args,
    reward_funcs=[format_reward, correctness_reward],   # references/reward-functions.md
    train_dataset=prompts,       # prompt-only: GRPO generates its own completions
    processing_class=tokenizer,
)
trainer.train()
```

### Why these values

- **`num_generations` ≥ 8 is a floor.** The advantage is measured against the
  group mean; a small group makes that baseline noisy. To fit memory, cut
  sequence length or batch size instead (`skills/finetuning/training-optimization`).
- **Reward is composite: format + correctness.** If a well-formed wrong answer
  and unparseable garbage score the same, the policy gets no gradient toward
  well-formedness.
- **`learning_rate=5e-7`, `beta=0.01`** are the starting point. `beta` is the
  leash to the reference policy: lower drifts further from base capabilities,
  higher barely moves anything.
- **Smoke scale first** — capped `max_steps`, subsampled prompts, fixed seed,
  as `skills/finetuning/peft-lora` runs SFT. The full run is a documented
  launch plan with cost and duration.

No `nvidia-smi` on the box? RLVR is generation-heavy and does not degrade
usefully to CPU — build and inspect reward functions locally, then train on a
CUDA host.

## The Inspection Gate

Run the reward function over 50–100 sampled outputs and read the results
yourself before launching training. If its verdict disagrees with your reading
on any sample, fix the function before touching a hyperparameter. An
uninspected reward is how a run reward-hacks: loss looks healthy, reward goes
up, and the model gets worse, with no training-loop error.

What inspection catches, roughly by frequency:

- Rewards firing on a substring anywhere in the completion, so restating the question earns credit
- Length correlating with reward because the checker scans for any occurrence of a correct token
- Verifier exceptions swallowed into `0.0`, turning timeouts into "wrong" and teaching the model to avoid slow cases — let the verifier raise, or score errors distinctly and log them
- A schema check that accepts extra keys, so the policy learns to emit everything

Reward implementations to inspect against (exact match, schema validation,
sandboxed unit tests, length-penalty wrapper, judge-as-reward) and the
inspection-set recipe are in `references/reward-functions.md`.

## Variant Selection

Plain GRPO is the default. Switch to a variant only after its symptom appears
on plain GRPO — choosing one up front changes two things at once and leaves no
way to tell whether it helped.

| Symptom observed | Variant | What it changes |
|---|---|---|
| Entropy collapse; degenerate or repetitive long chain-of-thought | **DAPO** | Decouples the clip bounds and relaxes the KL penalty that over-regularizes exploration on long traces |
| Reward and output length climb together regardless of quality | **Dr.GRPO** | Removes GRPO's length-normalization bias so reward tracks correctness, not length |
| Training a mixture-of-experts model | **GSPO** | Moves importance sampling to the sequence level; per-token ratios are unstable under MoE routing, so this is required |

Vision-language RL is out of scope: tooling is fragmented, and text-only GRPO
on a VLM tends to reward-hack the text trace while ignoring the image. Treat it
as a research spike.

## Red Flags

- Reward climbing while held-out task accuracy is flat or falling
- Mean completion length trending up with no length term in the reward
- `beta` lowered to make reward move faster, without a capability-drift check (`skills/finetuning/checkpoint-promotion`)
- The same prompts used for RL training and for the final eval

## Verification

- [ ] Verifier named, deterministic (or judge calibrated per `skills/evals/llm-judge`), and unit-tested standalone
- [ ] Base-model success rate on the target task measured and nonzero, recorded with the sample count
- [ ] Reward is composite (format + correctness), with the two terms logged separately
- [ ] 50–100-sample reward inspection completed and read by a human; disagreements fixed in the function, not the hyperparameters
- [ ] `num_generations` ≥ 8; deviations justified in writing
- [ ] Smoke run first: capped `max_steps`, subsampled prompts, fixed seed, transcript in `.context/logs/`
- [ ] Completion length and per-term reward tracked as run metrics (`skills/mlops/experiment-tracking`)
- [ ] Variant (if any) adopted only after the matching symptom was observed on plain GRPO
- [ ] Capability drift gated before the checkpoint ships (`skills/finetuning/checkpoint-promotion`)

## Related Skills

- `references/reward-functions.md` — runnable reward implementations, the inspection-set recipe, the judge-as-reward caveat
- `skills/finetuning/preference-tuning` — sibling for preference pairs; owns the DPO/ORPO/KTO/RLHF ladder
- `skills/finetuning/peft-lora` — the SFT stage that precedes RL when the base success rate is zero
- `skills/finetuning/trace-to-training-data` — converts graded RLVR rollouts into SFT rows or preference pairs
- `skills/finetuning/training-optimization` — memory and throughput for generation-heavy runs
- `skills/finetuning/checkpoint-promotion` — the drift gate an RL checkpoint clears before export
- `skills/evals/llm-judge` — calibration any judge-based reward needs before it counts as a verifier
- `skills/mlops/experiment-tracking` — logging reward terms, seeds, and prompt-set versions per run
