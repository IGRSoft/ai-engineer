---
name: preference-tuning
description: >-
  Align a tuned model with preferences: pick SFT-only vs DPO vs ORPO/KTO vs
  RLHF, build and label chosen/rejected pairs, run DPO (beta, reference
  model), and catch reward hacking (length bias, sycophancy, style collapse).
  Use when SFT output is close-but-not-quite, when outputs grow longer or
  sycophantic after tuning, or when measuring win rate against a baseline.
  Not verifiable-reward RL (grpo-rlvr-training).
---

# Preference Tuning

Preference tuning teaches directional judgment ("this answer over that
one"); SFT teaches imitation of gold outputs. It comes after SFT, because
preference signal spent on an incompetent policy fixes basics that gold
examples fix cheaper. Every preference optimizer exploits what its signal
underspecifies (length, flattery, style), and every run is judged by
held-out win rate.

Owned by `ai-engineer:ml-engineer`. Method escalations (RLHF proposals,
reward-model builds) go through `ai-engineer:ai-architector`.

**Out of scope — route elsewhere:**

- No competent SFT baseline yet → `skills/finetuning/peft-lora` first
- Objective correctness targets (exact format, factual QA) → SFT on gold outputs; preference signal adds noise
- Success decidable by a program (unit tests, schema validation, math) → `skills/finetuning/grpo-rlvr-training`; a verifiable reward is a stronger signal than pairs
- Sourcing pairs from already-graded traces → `skills/finetuning/trace-to-training-data`; it supplies trajectories, this skill owns the selection formula and the run
- Pair format and hygiene (dedup, scrub, versioning) → `skills/finetuning/dataset-curation` (`skills/finetuning/dataset-curation/references/data-formats.md` for the chosen/rejected schema)
- Judge rubrics and bias controls → `skills/evals/llm-judge`
- Run doesn't fit or is slow → `skills/finetuning/training-optimization`

## Method Selection

| Method | Data needed | Compute / infra | Stability | When it wins |
|--------|-------------|-----------------|-----------|--------------|
| SFT-only | Gold outputs | 1 model | Very stable | You can write the right answer; correctness targets |
| DPO | prompt + chosen/rejected pairs | Policy + frozen reference (adapter tricks avoid a second copy) | Stable | Default first preference method for app teams |
| ORPO | Pairs | 1 model, no reference | Stable | Single-stage SFT+preference; smaller pipelines |
| KTO | Independent good/bad labels (unpaired) | ~DPO | Stable | You have thumbs-up/down telemetry, not pairs |
| RLHF (PPO-class) | Prompts + trained reward model (+ pairs to train it) | 3–4 models live, online sampling, RL loop | Fragile, expensive | Platform/frontier scale, dense custom rewards — rarely justified for app teams |
| GRPO / RLVR | Prompts + a programmatic verifier; no pairs, no reward model | Online generation + RL loop | Sensitive to reward design | Success is machine-checkable — routes to `skills/finetuning/grpo-rlvr-training` |

**DPO for taste, GRPO for reasoning.** The discriminator is whether a program
can decide the outcome, not difficulty.

If DPO on good pairs doesn't move the win rate, the fix is almost always
better pairs, not a fancier algorithm. Moving to PPO-class RLHF is an
architecture decision that needs `ai-engineer:ai-architector` sign-off.
ORPO/KTO availability and trainer APIs shift across TRL versions — check
current TRL docs (context7).

## Deep Dives

Read `references/dpo-and-preference-data.md` for pair construction and labeling, DPO mechanics (beta, reference model, smoke-scale TRL loop), reward-hacking detection, distillation, and run evaluation.

## Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| DPO before SFT competence | Preference signal wasted on basics | SFT first (`skills/finetuning/peft-lora`); pairs teach judgment, not correctness |
| Pairs that differ mainly in length | Model learns "longer = better" | Length-matched pairs; length-controlled win rate |
| Same judge labels pairs and scores the eval | Measures judge agreement, not quality | Different judge/config for eval; human-audited slice |
| Beta tuned by training loss | Loss ≠ alignment quality | Sweep beta (start ~0.1) against held-out win rate |
| RLHF "because that's what the labs do" | 3–4 model infra and fragility for marginal app-scale gains | DPO-first; `ai-engineer:ai-architector` sign-off before any PPO work |
| Unversioned pair set | Wins and regressions can't be attributed | Version pairs like any dataset (`skills/finetuning/dataset-curation`) |
| Win rate measured on training-adjacent prompts | Overfit invisible | Held-out prompt set, pinned version, reported with the number |
| Low inter-annotator agreement waved through | Rubric doesn't define the preference; scaling multiplies noise | Fix the rubric before scaling labeling |

## Red Flags

- `rewards/accuracies` near 0.5 all run (noisy pairs) or ~1.0 within the first steps (trivial or leaked pairs)
- Mean output length trending upward across training
- Teacher-generated pairs with no license/ToS entry in the provenance ledger

## Verification

- [ ] SFT baseline competent and evaluated on the same prompt set before any preference run
- [ ] Method chosen from the selection table; deviations from DPO-first recorded with `ai-engineer:ai-architector`
- [ ] Pair set versioned, deduped, decontaminated, scrubbed (`skills/finetuning/dataset-curation` gates passed)
- [ ] Rubric written with anchors and tie/both-bad outcomes; IAA measured on a double-labeled slice and reported
- [ ] Synthetic labels (if any) audited against a human slice; judge biases checked per `skills/evals/llm-judge`
- [ ] Smoke DPO run: capped steps, subsample, fixed seed, sane `rewards/accuracies`; transcript in `.context/logs/`
- [ ] Beta swept against held-out win rate, not training loss; each beta change re-runs the held-out eval
- [ ] Win rate vs baseline measured pairwise, position-debiased, length-controlled, pinned eval-set version, judge at temperature 0
- [ ] General-capability regression slice passed (`skills/evals/regression-gates`)
- [ ] Full-run launch plan documented (command, pair-set version, host, expected duration/cost)

## Related Skills

- `skills/finetuning/checkpoint-promotion` — drift gate a tuned checkpoint clears before it ships
- `skills/evals/regression-gates` — CI gates on win rate and capability regression
- `skills/mlops/experiment-tracking` — log pair-set and eval-set versions with every metric
