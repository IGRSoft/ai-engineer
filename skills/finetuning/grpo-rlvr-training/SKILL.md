---
name: grpo-rlvr-training
description: >-
  Reinforcement learning from verifiable rewards (GRPO/RLVR): reward-function
  design, the inspection gate, and variant selection.
  Use when task success is programmatically checkable (unit tests, schemas,
  math), when writing GRPO reward functions, or when a run reward-hacks. Not
  preference pairs (see preference-tuning).
---

# GRPO / RLVR Training

You are here because the routing decision already landed on reinforcement
learning from a *verifiable* reward — `skills/finetuning/preference-tuning`'s
method ladder or `ai-engineer:ai-architector` pointed here because the target
behavior has a machine-checkable pass/fail signal rather than gold
demonstrations (`skills/finetuning/peft-lora`) or human preference pairs
(`skills/finetuning/preference-tuning`). What follows is the applicability
test, the reference recipe, the reward-inspection gate, and how to pick a
variant when the base recipe misbehaves.

**Input:** a routing decision (RLVR via GRPO), a programmatic verifier for the
target task (test runner, schema validator, executor, or exact-match checker),
and a base model whose success rate on that task is already nonzero.

**Output format:** a validated GRPO config plus reward functions that have been
read against a 50–100-sample inspection set — concrete kwargs and Python, not
free-form advice.

## Overview

GRPO is group-relative policy optimization: for each prompt it samples a group
of completions, scores them with your reward function, and pushes the policy
toward the above-average members of that group. The reward function *is* the
specification. Everything expensive about an RLVR run — GPU hours, instability,
reward hacking — traces back to whether that function measures the thing you
actually want.

The standing rule: **DPO for taste, GRPO for reasoning.** If the signal is a
preference between two acceptable outputs, that is
`skills/finetuning/preference-tuning`. If the signal is a program returning
pass or fail, it is this skill.

Owned by `ai-engineer:ml-engineer`. Adopting RL at all is a method escalation —
`ai-engineer:ai-architector` signs off, because RLVR costs multiples of an SFT
run and adds a failure mode (reward hacking) that SFT does not have.

## When to Use

- Task success is decidable by a program: a unit test passes, a parser accepts
  the output, a tool call matches a schema, an answer equals ground truth
- Writing, reviewing, or debugging GRPO reward functions
- A GRPO run diverges, collapses to degenerate output, or reward climbs while
  human-judged quality does not
- Choosing between plain GRPO and a variant after a specific failure appeared

**When NOT to use:**

- Grading needs human judgment or a subjective rubric → `skills/evals/llm-judge`
  for calibration first; a judge you have not calibrated is not a verifier
- The signal is "this answer is better than that one" →
  `skills/finetuning/preference-tuning` (DPO/ORPO/KTO ladder, pair construction)
- The model never succeeds at the task → `skills/finetuning/peft-lora`; RL
  sharpens an existing capability, it does not install a missing one
- Turning already-graded traces into training rows →
  `skills/finetuning/trace-to-training-data`
- The run OOMs or crawls → `skills/finetuning/training-optimization`

## Is the Reward Actually Verifiable?

Two preconditions, both hard. Failing either sends the work elsewhere before a
single GPU hour is spent.

**1. A program decides success.** Not "a rubric exists" and not "a judge
usually agrees" — a deterministic checker returns pass or fail. An LLM judge
can serve as a verifier only after it clears the calibration bar in
`skills/evals/llm-judge` (measured agreement against human labels), and even
then it is the weakest verifier class because the policy can learn to exploit
the judge rather than the task.

**2. The base model already succeeds sometimes.** Sample the task at
temperature 0.7 across a few dozen prompts and count.

| Base success rate | Meaning | Route |
|---|---|---|
| 0% | Format or task comprehension gap, not a policy gap | SFT first (`skills/finetuning/peft-lora`), return when nonzero |
| Low but nonzero | The GRPO sweet spot — there is signal to reweight toward | Proceed to The Recipe |
| Already near ceiling | Nothing left for RL to sharpen | Spend the budget on evals or a harder task slice |

A zero base rate is the most common wasted RLVR run: with no successful samples
in a group, every completion scores identically and the group-relative
advantage is zero, so the policy receives no gradient signal worth the compute.

## The Recipe

TRL's `GRPOTrainer` with vLLM-backed generation is the reference path. Trainer
kwargs move between TRL minors — verify current names against TRL's docs
(context7) before copying, and pin the version in `uv.lock`.

```python
# uv add trl vllm  — pin in uv.lock; GRPOConfig kwargs move between TRL minors
from trl import GRPOConfig, GRPOTrainer

grpo_args = GRPOConfig(
    output_dir="outputs/grpo-smoke",
    use_vllm=True,
    vllm_mode="colocate",        # single GPU; "server" when generation gets its own device
    num_generations=8,           # floor, not a suggestion — see below
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
  group mean, so a small group makes that baseline noisy and the gradient
  mostly samples variance. Reducing it to fit memory trades the signal you are
  paying for; cut sequence length or batch size instead
  (`skills/finetuning/training-optimization`).
- **Reward is composite, never correctness alone.** Pair a format reward (did
  it parse / match the required shape) with a correctness reward (did it
  verify). If a well-formed wrong answer and unparseable garbage score
  identically, the policy gets no gradient toward well-formedness.
- **`learning_rate=5e-7` and `beta=0.01`** are the settled starting point. `beta`
  is the leash to the reference policy: lower it and the model drifts further
  from its base capabilities, raise it and RL barely moves anything.
- **Smoke scale first.** Capped `max_steps` on subsampled prompts with a fixed
  seed, exactly as `skills/finetuning/peft-lora` runs SFT. The full run is a
  documented launch plan with cost and duration, not an interactive command.

No `nvidia-smi` on the box? RLVR is generation-heavy and does not degrade to
CPU usefully — build and inspect the reward functions locally (that is the
half of this skill that needs no GPU), then run training on a CUDA host.

## The Inspection Gate

**Run the reward function over 50–100 sampled outputs and read the results
yourself before launching training.** This is a gate, not a sanity check.

If the function's verdict disagrees with your reading on any sample, fix the
function before touching a hyperparameter. Training against an uninspected
reward is how a run reward-hacks: the policy optimizes cleanly and efficiently
toward the wrong target, and that never surfaces as a training-loop error. Loss
curves look healthy. Reward goes up. The model gets worse.

What the inspection actually catches, in rough order of frequency:

- Rewards that fire on a substring appearing anywhere in the completion, so
  restating the question earns credit
- Length correlating with reward because the checker scans for any occurrence
  of a correct token
- Exceptions inside the verifier swallowed into a `0.0` return, turning every
  timeout or crash into "wrong answer" and teaching the model to avoid the
  cases that are merely slow
- A schema check that accepts extra keys, so the policy learns to emit
  everything and let the parser sort it out

Complete reward implementations to inspect against — exact match, schema
validation, sandboxed unit-test execution, a length-penalty wrapper, and the
judge-as-reward pattern with its calibration caveat — are in
`references/reward-functions.md`.

## Variant Selection

Plain GRPO is the default. Reach for a variant when a specific symptom appears,
never preemptively — each one trades a stability property for the fix.

| Symptom observed | Variant | What it changes |
|---|---|---|
| Entropy collapse; degenerate or repetitive long chain-of-thought | **DAPO** | Decouples the clip bounds and relaxes the KL penalty that over-regularizes exploration on long traces |
| Reward and output length climb together regardless of quality | **Dr.GRPO** | Removes GRPO's length-normalization bias so reward tracks correctness, not completion length |
| Training a mixture-of-experts model | **GSPO** | Moves importance sampling to the sequence level; per-token ratios are unstable under MoE routing, so this is required rather than optional |

Pre-selecting a variant from a paper before the base recipe has shown its
failure mode means you cannot tell whether the variant helped — you changed two
things at once. Run plain GRPO, name the symptom, then swap.

Vision-language RL is out of scope here: tooling is fragmented, and text-only
GRPO applied to a VLM tends to reward-hack by optimizing the text trace while
ignoring the image. Treat it as a research spike, not a variant of this recipe.

## Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| RL on a task the base model never solves | No successful samples means zero group-relative advantage | SFT first (`skills/finetuning/peft-lora`); return when the base rate is nonzero |
| Correctness-only reward | Malformed and well-formed-but-wrong score alike | Composite reward: format + correctness |
| `num_generations` lowered to fit memory | Noisy baseline; the run measures variance | Cut sequence length or batch size instead |
| Reward function shipped unread | Reward hacking is silent and looks like success | The 50–100-sample inspection gate |
| Uncalibrated LLM judge used as the verifier | The policy learns the judge's blind spots | Calibrate per `skills/evals/llm-judge`, or pick a deterministic checker |
| Variant chosen from a paper up front | Two changes at once; no attribution | Plain GRPO, observe the symptom, then swap |
| Verifier exceptions caught and returned as `0.0` | Crashes become "wrong", teaching avoidance of slow cases | Let the verifier raise, or score errors distinctly and log them |

## Red Flags

- Reward climbing while held-out task accuracy is flat or falling
- Mean completion length trending up across training with no length term in the
  reward
- Nobody can name the verifier, or the verifier is "the model checks itself"
- The reward function has no tests and was never run standalone
- `beta` lowered to make reward move faster, without a capability-drift check
  (`skills/finetuning/checkpoint-promotion`)
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

- `references/reward-functions.md` — runnable reward implementations, the inspection-set recipe, and the judge-as-reward caveat
- `skills/finetuning/preference-tuning` — the sibling for preference pairs rather than verifiable rewards; owns the DPO/ORPO/KTO/RLHF ladder
- `skills/finetuning/peft-lora` — the SFT stage that must precede RL when the base success rate is zero
- `skills/finetuning/trace-to-training-data` — converts graded RLVR rollouts into SFT rows or preference pairs
- `skills/finetuning/training-optimization` — memory and throughput for generation-heavy runs
- `skills/finetuning/checkpoint-promotion` — the drift gate an RL checkpoint clears before export
- `skills/evals/llm-judge` — calibration any judge-based reward needs before it counts as a verifier
- `skills/mlops/experiment-tracking` — logging reward terms, seeds, and prompt-set versions per run
