---
name: preference-tuning
description: >-
  Aligns model behavior with preferences: choosing between SFT-only, DPO,
  ORPO/KTO, and full RLHF/PPO; building preference pairs (pair generation,
  labeling rubrics, annotator agreement, synthetic-data caveats); DPO
  mechanics (beta, reference model, smoke-scale TRL loop); detecting reward
  hacking (length bias, sycophancy, style collapse) + mitigations; and
  distillation as the alternative. Use when SFT output is
  close-but-not-quite, when picking a preference method, when building
  chosen/rejected pairs, when tuned outputs grow longer or sycophantic, or
  when measuring win-rate against a baseline.
---

# Preference Tuning

**DPO-first for app teams — and every run is judged by held-out win rate, not vibes**

## Overview

Preference tuning teaches directional judgment — "this answer over that
one" — where SFT teaches imitation of gold outputs. It comes *after* SFT: a
preference method pointed at an incompetent policy spends its signal fixing
basics that gold examples would fix cheaper. The method ladder runs from
SFT-only through DPO-class offline methods to full RLHF, with cost and
fragility rising at each rung; the failure ladder runs alongside it, because
every preference optimizer will exploit whatever its signal underspecifies
(length, flattery, style). This skill covers picking the rung, building the
pairs, running DPO at smoke scale, and catching the exploits.

Owned by `ai-engineer:ml-engineer`. Method escalations (RLHF proposals,
reward-model builds) go through `ai-engineer:ai-architector`.

## When to Use

- An SFT/instruct model is close but systematically off: tone, verbosity, hedging, refusal calibration, judgment calls
- You can articulate "better vs worse" far more easily than you can write gold outputs
- You hold (or can generate) comparison data: ranked samples, edit pairs, thumbs up/down telemetry
- A tuned model has drifted — longer, sycophantic, or samey — and you need to diagnose why

**When NOT to use:**

- No competent SFT baseline yet → `skills/finetuning/peft-lora` first; DPO needs a reasonable starting policy
- The target is objective correctness (exact format, factual QA) → SFT on gold outputs; preference signal only adds noise there
- Pair *format* and dataset hygiene (dedup, scrub, versioning) → `skills/finetuning/dataset-curation` (+ `skills/finetuning/dataset-curation/references/data-formats.md` for the chosen/rejected schema)
- Judge rubrics and bias controls → `skills/evals/llm-judge`
- The run doesn't fit or is slow → `skills/finetuning/training-optimization`

## Method Selection

| Method | Data needed | Compute / infra | Stability | When it wins |
|--------|-------------|-----------------|-----------|--------------|
| SFT-only | Gold outputs | 1 model | Very stable | You can write the right answer; correctness targets |
| DPO | prompt + chosen/rejected pairs | Policy + frozen reference (adapter tricks avoid a second copy) | Stable | **Default first preference method for app teams** |
| ORPO | Pairs | 1 model, no reference | Stable | Single-stage SFT+preference; smaller pipelines |
| KTO | Independent good/bad labels (unpaired) | ~DPO | Stable | You have thumbs-up/down telemetry, not pairs |
| RLHF (PPO-class) | Prompts + trained reward model (+ pairs to train it) | 3–4 models live, online sampling, RL loop | Fragile, expensive | Platform/frontier scale, dense custom rewards — rarely justified for app teams |

The DPO-first default: if DPO on good pairs doesn't move the win rate, the
fix is almost always better pairs, not a fancier algorithm. Any move to
PPO-class RLHF is an architecture decision — `ai-engineer:ai-architector`
signs off, or it doesn't happen. Exact ORPO/KTO availability and trainer
APIs shift across TRL versions — verify current TRL docs (context7).

## Deep Dives

Read `references/dpo-and-preference-data.md` for preference-pair construction and labeling, DPO mechanics (beta, reference model), reward-hacking detection, distillation, and run evaluation.

## Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| DPO before SFT competence | Preference signal wasted on basics | SFT first (`skills/finetuning/peft-lora`); pairs teach judgment, not correctness |
| Pairs that differ mainly in length | Model learns "longer = better" | Length-matched pairs; length-controlled win rate |
| Same judge labels pairs and scores the eval | Self-confirming loop measures judge agreement, not quality | Different judge/config for eval; human-audited slice |
| Beta tuned by training loss | Loss ≠ alignment quality | Sweep beta against held-out win rate |
| RLHF "because that's what the labs do" | 3–4 model infra and fragility for marginal app-scale gains | DPO-first; `ai-engineer:ai-architector` sign-off before any PPO work |
| Unversioned pair set | Wins and regressions can't be attributed | Version pairs like any dataset (`skills/finetuning/dataset-curation`) |
| Win rate measured on training-adjacent prompts | Overfit invisible | Held-out prompt set, pinned version, reported with the number |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "The model just needs RLHF" | It usually needs better pairs or better SFT data; RLHF amplifies whatever signal you have, including the flaws |
| "Longer answers really are better here" | Then encode that in the rubric explicitly — and still report length-controlled win rate |
| "Synthetic pairs are free" | They're paid for in inherited judge bias; a human-audited slice is the price of using them |
| "Win rate went up, ship it" | Check the regression slice; capability tax is silent and cumulative |
| "Kappa is low but the labels are fine" | Low agreement means the rubric doesn't define the preference; scaling it multiplies noise |
| "We'll eyeball drift" | Length creep and sycophancy grow a few percent per run — only the tracked metrics see it |

## Red Flags

- `rewards/accuracies` pinned near 0.5 all run (noise pairs) or at ~1.0 within the first steps (trivial or leaked pairs)
- Mean output length trending upward across training
- The baseline was never evaluated on the same prompt set as the tuned model
- One rubric text used for labeling, judging, and the ship decision
- PPO/reward-model infrastructure being built without an architecture decision record
- Teacher-generated pairs with no license/ToS entry in the provenance ledger
- Beta changed and win-rate delta attributed without re-running the held-out eval

## Verification

- [ ] SFT baseline competent and evaluated before any preference run started
- [ ] Method chosen from the selection table; deviations from DPO-first recorded with `ai-engineer:ai-architector`
- [ ] Pair set versioned, deduped, decontaminated, scrubbed (`skills/finetuning/dataset-curation` gates passed)
- [ ] Rubric written with anchors and tie/both-bad outcomes; IAA measured on a double-labeled slice and reported
- [ ] Synthetic labels (if any) audited against a human slice; judge biases checked per `skills/evals/llm-judge`
- [ ] Smoke DPO run: capped steps, subsample, fixed seed, sane `rewards/accuracies`; transcript in `.context/logs/`
- [ ] Beta swept against held-out win rate, not training loss
- [ ] Win rate vs baseline measured pairwise, position-debiased, pinned eval-set version, judge at temperature 0
- [ ] General-capability regression slice passed (`skills/evals/regression-gates`)
- [ ] Full-run launch plan documented (command, pair-set version, host, expected duration/cost)

## Related Skills

- `skills/finetuning/peft-lora` — the SFT stage that precedes preference tuning; adapter mechanics
- `skills/finetuning/dataset-curation` — pair formats, hygiene gates, provenance ledger
- `skills/finetuning/training-optimization` — fitting and running DPO jobs; loss triage
- `skills/evals/llm-judge` — win-rate judging, rubrics, position/length bias controls
- `skills/evals/regression-gates` — CI gates on win rate and capability regression
- `skills/mlops/experiment-tracking` — logging pair-set/eval-set versions with every metric
