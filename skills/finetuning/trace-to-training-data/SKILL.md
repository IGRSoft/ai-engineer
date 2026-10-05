---
name: trace-to-training-data
description: >-
  Convert graded eval traces into SFT rows or preference pairs: rejection
  sampling, step-level masking, same-task pair construction, goldens holdout.
  Use when traces already carry a grader verdict. Raw or ungraded data goes
  to dataset-curation.
---

# Trace To Training Data

Turns traces that already carry a grader's verdict into training rows. Grading
happened upstream (`skills/evals/eval-design`); this skill only converts and
curates — which passing traces are worth imitating, which pairs teach
something, and which rows must never ship. Owned by `ai-engineer:ml-engineer`;
whether the data justifies a tune at all is `ai-engineer:ai-architector`'s call.

**Input:** graded traces — each row has a `task_id`, a grader `verdict`, and a
`reward` where the task supports a scalar score (judge score, execution
partial credit, or an RLVR verifier signal):

```json
{"task_id": "t-042", "trace_id": "t-042-a3",
 "messages": [{"role": "user", "content": "..."}],
 "verdict": "pass", "reward": 0.91, "grader": "exact_match"}
```

**Output:** SFT `messages` rows or `prompt`/`chosen`/`rejected` pairs shaped
exactly like `skills/finetuning/dataset-curation`'s format tables, so no
reshaping step sits between the two skills.

**Elsewhere:**

- Raw logs, docs, tickets with no verdict; format mechanics, chat templates,
  dedup method, splits, versioning, dataset cards → `skills/finetuning/dataset-curation`
- Designing graders, goldens, or the eval run → `skills/evals/eval-design`
- Calibrating the judge whose scores you filter on → `skills/evals/llm-judge`
- Choosing a preference method or tuning DPO beta → `skills/finetuning/preference-tuning`
- Reward functions for an RL run → `skills/finetuning/grpo-rlvr-training`

## The Precondition

A grader already ruled on every trace. A trace with no verdict and no reward is
not convertible: route it back to `skills/evals/eval-design` and add the
grader. Don't hand-label traces to unblock conversion — that bakes an
unmeasured, unreproducible judgment into the weights, invisible in the
dataset card.

## SFT From Traces

- **Keep the top-reward fraction of passing trajectories, not every passing
  one.** A barely-passing trace is a weak imitation target; the pass bar was
  set to catch failures, not to pick exemplars. The fraction is a
  quality/volume tradeoff to measure.
- **Expert-corrected failures go straight into the SFT set**, with no reward
  threshold — a human already validated them. Usually the highest-value and
  scarcest rows.
- **Step-level masking beats whole-trajectory discard on multi-step traces.**
  Mask the loss on the bad steps and keep the good ones, so long agent
  trajectories stay usable even when they end badly.

Record the reward threshold and kept fraction in the dataset card
(`skills/finetuning/dataset-curation`) — "top 25% by reward, threshold 0.83"
is reproducible; "the good ones" is not.

## Preference Pairs From Traces

- **Pair passing against failing trajectories on the same task.** A cross-task
  pair teaches a preference between tasks, not responses, and shows up as
  topic bias.
- **Select the rejected member around one to two standard deviations below the
  task's mean reward, not at the minimum.** The worst trace is usually a
  crash, truncation, or empty output — a distinction the model already makes.
  `skills/finetuning/preference-tuning` owns the full selection formula.
- **Filter by judge-score delta.** Keep the highest chosen-minus-rejected
  margin subset; a small high-margin set can match a much larger pool. Build
  the full candidate set first, then filter — capping generation up front
  loses the margin distribution you filter on.

## Hygiene

Violations here are silent.

- **Scan every row for secrets and PII, fail closed.** Production traces carry
  credentials and customer data; drop rows that still match after redaction.
  The model can emit what it trains on.
- **Hold every eval golden ID out of every converted set.** A leaked golden
  inflates every later eval and the promotion gate
  (`skills/finetuning/checkpoint-promotion` stage 1).
- **Dedup against the existing training set, not just this batch**, with the
  method `skills/finetuning/dataset-curation` records.
- **Record `run_id` and `trace_id` provenance in the dataset card**, so a bad
  grader's rows can be audited, re-graded, or withdrawn.

## Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| Hand-labeling traces to unblock conversion | An unmeasured judgment gets baked into weights, invisibly | Add the grader upstream (`skills/evals/eval-design`) |
| Keeping every passing trace | Barely-passing traces are weak imitation targets | Top-reward fraction, with the threshold recorded |
| Pairs built across different tasks | Teaches task preference, not response preference | Same-task pairs only |
| Rejected member = absolute worst trace | Pairs against crashes teach nothing | Select near μ−2σ, not the minimum |
| Capping candidate generation before delta filtering | The margin distribution is gone | Full candidate set first, then filter |
| Goldens left in the converted set | Every downstream eval is inflated | Hold out golden IDs; verify the intersection is empty |
| Dedup within the batch only | Duplicates against existing training data survive | Dedup against the merged set |
| Rows shipped without run/trace provenance | Cannot audit or withdraw a bad grader's output | Provenance in the dataset card |
| Redaction failures shipped as "probably fine" | Model exfiltrates the secret | Fail closed — drop the row |

## Red Flags

- The judge that produced the rewards was never calibrated (`skills/evals/llm-judge`)
- A PII scan ran once on an earlier batch and is assumed to still hold
- Conversion volume grew but the downstream win rate did not move

## Verification

- [ ] Every input row carries a grader `verdict`; rows with rewards name the grader that produced them
- [ ] No trace was hand-labeled during conversion; missing verdicts were routed back to `skills/evals/eval-design`
- [ ] Reward threshold and kept fraction recorded in the dataset card, not just applied
- [ ] Expert-corrected failures routed in directly and marked as such
- [ ] Multi-step trajectories use step-level masking where only some steps failed
- [ ] Preference pairs share `task_id` between `chosen` and `rejected`
- [ ] Rejected members selected by the distribution rule, not the minimum
- [ ] Candidate pairs built in full, then delta-filtered — not capped at generation
- [ ] Golden-ID intersection with the converted set computed and empty
- [ ] Dedup run against the merged training set with the recorded method
- [ ] Secret/PII scan passed; failures dropped, not shipped
- [ ] Every row carries `run_id` and `trace_id` provenance into the dataset card
- [ ] Output validates against `skills/finetuning/dataset-curation`'s messages-schema validator before merge

## Related Skills

- `references/conversion-recipes.md` — worked conversions: rejection-sampling loop, human corrections, step masking, pair building, goldens-holdout gate, dataset-card fields
- `skills/finetuning/grpo-rlvr-training` — alternative use of the same verified signal: train against the verifier directly instead of converting rollouts; also a source of graded rollouts to convert
- `skills/finetuning/checkpoint-promotion` — its stage-1 data-quality gate catches a goldens leak this skill missed
