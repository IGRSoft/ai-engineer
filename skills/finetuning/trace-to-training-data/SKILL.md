---
name: trace-to-training-data
description: >-
  Converts graded eval traces into SFT rows or preference pairs: rejection
  sampling, step-level masking, pair construction, goldens holdout.
  Use when traces already carry a grader verdict, when rejection-sampling
  outputs, or when building DPO pairs from passing and failing runs. Not
  raw/ungraded data (dataset-curation).
---

# Trace To Training Data

You are here because traces already carry a grader's verdict and the question
is which of them become training rows. `skills/evals/eval-design` built the
graders and produced the run results; this skill is the flywheel edge where
those labeled traces turn into a training set. Grading happened upstream —
conversion happens here, and nothing in this skill re-judges anything.

If your data is raw — logs, tickets, docs, transcripts with no verdict attached
— you are in the wrong place. That is `skills/finetuning/dataset-curation`.

**Input:** graded traces — an eval golden set plus run results, each row
carrying a task ID, a `verdict` from the grader, and a `reward` where the task
supports a scalar score (judge score, execution partial credit, or an RLVR
verifier signal):

```json
{"task_id": "t-042", "trace_id": "t-042-a3",
 "messages": [{"role": "user", "content": "..."}],
 "verdict": "pass", "reward": 0.91, "grader": "exact_match"}
```

**Output format:** rows shaped exactly like
`skills/finetuning/dataset-curation`'s format tables — SFT `messages` rows or
preference `prompt`/`chosen`/`rejected` pairs — so this skill's output is that
skill's input with no reshaping step between them.

## Overview

The eval harness already did the labeling. Every trace carries a verdict, and
often a reward, before this skill touches it, which makes the *mechanical* part
— pick a shape, map fields, write JSONL — nearly free.

**Curation is the work that remains**, and it is three questions: which passing
traces are good enough to imitate, which pairs actually teach something, and
which rows must never enter the training set at any quality. Answering those
badly produces a dataset that trains a model to be confidently mediocre, and
the training run will not tell you.

Owned by `ai-engineer:ml-engineer`. Whether the resulting data justifies a tune
at all is a method decision — `ai-engineer:ai-architector`.

## When to Use

- Eval traces or production logs carry grader verdicts and should become training data
- Applying rejection sampling: keeping the best model outputs as SFT targets
- Building preference pairs from passing and failing runs on the same task
- Routing human-corrected failures back into a training set
- Deciding what fraction of a graded run is worth keeping

**When NOT to use:**

- The data has no verdict attached — raw logs, docs, tickets, scraped text →
  `skills/finetuning/dataset-curation` (this skill's input must already be graded)
- Format mechanics, chat templates, dedup, splits, versioning, dataset cards →
  `skills/finetuning/dataset-curation` (it owns the target schema; this skill
  only fills it)
- Designing graders, goldens, or the eval run that produces verdicts →
  `skills/evals/eval-design`
- Calibrating the judge whose scores you are about to trust →
  `skills/evals/llm-judge`
- Choosing a preference method or tuning DPO beta →
  `skills/finetuning/preference-tuning`
- Designing reward functions for an RL run →
  `skills/finetuning/grpo-rlvr-training`

## The Precondition

The discriminator for this skill is not its topic, it is its entry condition:
**a grader already ruled on every trace.** That is what makes conversion
mechanical instead of a labeling project.

So treat any conversion step that requires re-judging a trace as evidence the
harness is missing a grader, not as a gap to paper over here. A trace with no
verdict and no reward is not convertible yet — route it back to
`skills/evals/eval-design` and add the grader. Hand-labeling a few traces to
unblock a conversion is how an unmeasured, unreproducible judgment call ends up
baked into model weights, and it will not be visible in the dataset card.

## SFT From Traces

- **Keep the top-reward fraction of successful trajectories, not every passing
  one.** Rank passing traces by reward and take a fraction. A trace that barely
  cleared the pass bar is a much weaker imitation target than one well above
  it, and the pass bar was set to catch failures, not to identify exemplars.
  Where the fraction lands is a quality/volume tradeoff to measure, not a
  constant to memorize.
- **Expert-corrected failures go straight into the SFT set.** When a human
  edits a failing output into a correct one, that correction needs no reward
  threshold — a human already validated it. These are typically the highest-
  value rows in the whole set and the scarcest, because they cost human time.
- **Step-level masking beats whole-trajectory discard on multi-step traces.**
  When only some steps in a trajectory are bad, mask the loss on those steps
  and keep the good ones instead of throwing the trajectory away. Reported
  gains from the finer-grained cut are real but modest; the larger practical
  win is that long agent trajectories stop being unusable just because they end
  badly.

Reward thresholds and the fraction you keep are dataset parameters. Record them
in the dataset card (`skills/finetuning/dataset-curation`) — "top 25% by reward,
threshold 0.83" is reproducible; "the good ones" is not.

## Preference Pairs From Traces

- **Pair passing against failing trajectories on the SAME task.** Never pair
  the best trace from one task against the worst from another: a cross-task
  pair teaches the model to prefer one *task* over another, which is not a
  preference about response quality and will show up as strange topic bias.
- **Select the rejected member around one to two standard deviations below the
  task's mean reward, not at the absolute minimum.** The worst trace in a task
  is usually broken in an uninteresting way — a crash, a truncation, an empty
  output — and a pair against garbage teaches a distinction the model already
  makes. `skills/finetuning/preference-tuning` owns the full selection formula;
  this skill supplies the graded trajectories it consumes.
- **Filter by judge-score delta to cut volume without cutting signal.** Score
  each candidate pair by the chosen-minus-rejected margin and keep the
  highest-delta subset; a small high-margin subset can match a much larger pool
  downstream. Build the full candidate set first, *then* filter — capping
  generation up front throws away the margin distribution you need to filter on.

## Hygiene

The rules here are the ones whose violations are silent, which is why they are
a checklist rather than advice.

- **Scan for secrets and PII before any row ships, and fail closed.** Traces
  from production logs carry credentials, tokens, and customer data. Run the
  scan over every row; drop what still matches after redaction rather than
  shipping it. A secret in a training set is exfiltrated by the model, not just
  stored.
- **Eval goldens must never enter training data.** Hold every golden ID out of
  every converted set. A trace that is also a golden trains on the exact item
  the checkpoint gets graded against, silently inflating every later eval and
  invalidating the promotion gate that depends on it
  (`skills/finetuning/checkpoint-promotion` stage 1 exists to catch this).
- **Dedup against the existing training set, not just within this batch.** Use
  the same dedup method `skills/finetuning/dataset-curation` records, run
  against whatever training data already exists before this batch merges in.
- **Provenance goes in the dataset card.** Every converted row traces back to
  its source run ID and trace ID. A row with no traceable source cannot be
  audited, re-graded, or withdrawn when its grader turns out to be wrong.

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

- Traces being converted have no `verdict` field, only text
- The reward threshold is described in prose but not recorded anywhere
- The judge that produced the rewards was never calibrated (`skills/evals/llm-judge`)
- Preference pairs where `chosen` and `rejected` come from different `task_id`s
- Golden-set intersection with the training set was never computed
- Converted rows carry no `run_id` / `trace_id` back-reference
- A PII scan was run once, on an earlier batch, and assumed to still hold
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
- [ ] Output validates against `skills/finetuning/dataset-curation`'s format checker before merge

## Related Skills

- `references/conversion-recipes.md` — worked JSONL-to-JSONL conversions, the rejection-sampling loop, step masking, and the goldens-holdout check
- `skills/evals/eval-design` — produces the graded traces this skill consumes; a trace with no verdict goes back here
- `skills/finetuning/dataset-curation` — owns the target schema, dedup, splits, versioning, and the dataset card this skill's provenance feeds
- `skills/finetuning/preference-tuning` — consumes the pairs this skill builds; owns the selection formula and the DPO run
- `skills/finetuning/grpo-rlvr-training` — an alternative use of the same verified signal: train against the verifier directly instead of converting rollouts
- `skills/finetuning/checkpoint-promotion` — its stage-1 data-quality gate is what catches a goldens leak this skill failed to prevent
- `skills/evals/llm-judge` — calibration for any reward this skill filters on
