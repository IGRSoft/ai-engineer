---
name: checkpoint-promotion
description: >-
  Gates trained checkpoints on capability drift: four-stage gate, drift
  budgets, paired comparison vs base, forgetting checks, ending in PROMOTE or
  REJECT.
  Use when a training run produces a checkpoint, when deciding whether tuned
  weights ship, or when re-gating against new goldens. Not CI eval gates
  (regression-gates).
---

# Checkpoint Promotion

You are here because a training run finished and someone has to decide whether
those weights ship. `skills/finetuning/peft-lora`,
`skills/finetuning/preference-tuning`, or `skills/finetuning/grpo-rlvr-training`
produced the checkpoint; `skills/evals/eval-design` built the suite this skill
re-runs. This is where that suite's numbers stop being observations and become
a verdict. A checkpoint that trained cleanly and beat its target metric still
does not ship until it clears all four stages below.

**Input:** a trained checkpoint, a frozen baseline for the pre-tune model on
the same eval suite, and a capability-drift suite pinned to a version.

**Output format:** a promotion report covering all four stages as evidence,
ending in a terminal `PROMOTE` or `REJECT` plus exactly one remediation when
the verdict is `REJECT`.

## Overview

A fine-tune trades general capability for target-task performance, and the
trade is invisible if you only measure the target task. This skill exists to
measure the other side of it: what the model *lost*. That is a weights-level
question with a numeric budget — how many points of general capability may a
tune spend to buy its task gain — and it is decided once per checkpoint, not
per commit.

The distinction that keeps this skill from colliding with its neighbors: this
is a **verdict on model weights against a drift budget**. It is not a CI
threshold on prompt or retrieval changes (`skills/evals/regression-gates`), not
a registry alias flip (`skills/mlops/experiment-tracking`), not a pipeline
stage (`skills/mlops/ml-pipelines`), and it has nothing to do with software
release versioning.

Owned by `ai-engineer:ml-engineer`. A `REJECT` that the team wants to override
is an architecture decision — `ai-engineer:ai-architector`, recorded, not a
verbal exception.

## When to Use

- A training run produced a checkpoint and someone must decide whether it ships
- Deciding whether tuned weights beat their base model in practice, not just on
  the target metric
- Re-gating a previously promoted checkpoint against an updated golden set
- A tune gained on its task and you need to know what it cost elsewhere
- Diagnosing suspected catastrophic forgetting after a fine-tune

**When NOT to use:**

- CI gates on prompt, model, or retrieval changes with warn bands and baseline
  update rituals → `skills/evals/regression-gates`
- Designing the eval set, metrics, or judge itself → `skills/evals/eval-design`
- Registry aliases, run lineage, and promotion bookkeeping →
  `skills/mlops/experiment-tracking`
- Wiring promotion into a DAG or CI/CD → `skills/mlops/ml-pipelines`
- Exporting the artifact once promoted → `skills/finetuning/quantized-export`
- Fixing the training config that caused the drift →
  `skills/finetuning/peft-lora`, `skills/finetuning/training-optimization`

## The Four-Stage Gate

Each stage gates the next: a stage-2 failure means stage 3 does not run. Stages
2 and 3 share one expensive inference pass, so running them concurrently and
applying gate order at verdict time is fine when every grader is
deterministic — a judge-based comparison should still wait for stage 2, where
the savings actually are.

**1. Data quality.** Before any eval touches the checkpoint: confirm the
training set was deduped, scan for eval-golden leakage, and check for label
noise. A checkpoint trained on leaked goldens invalidates every later stage,
because the numbers those stages produce are measuring memorization.
Mechanics: `skills/finetuning/dataset-curation`.

**2. Held-out plus frozen capability drift.** Re-run the pinned drift suite —
general-capability benchmarks plus 200–500 domain-adjacent items — against the
checkpoint and diff per benchmark against the frozen baseline, scored against
the Drift Budget below.

**3. Paired comparison vs. base.** Same prompts, checkpoint against base model,
position-randomized when a judge is involved (`skills/evals/llm-judge`).
**A holdout win that loses the paired comparison does not ship.** Stage-2
numbers and stage-3 judgments have to agree; a win on frozen goldens plus a
loss head-to-head is a real signal, not a discrepancy to explain away.

**4. Canary.** A stratified small-percentage rollout with automatic rollback,
for any checkpoint reaching production traffic
(`skills/mlops/model-monitoring`). **Local-only deployments stop at stage 3** —
that is the correct stopping point, not a shortcut.

### Drift Budget

| Drift vs. baseline | Verdict |
|---|---|
| ≤1 pt | Noise — proceed |
| 2–5 pts | Re-run with seed variation before deciding |
| >5 pts | **HARD FAIL** — no exception for task gains |

The hard-fail row governs the others. A checkpoint that gained 8 points on its
target task and lost 6 points of general capability still fails here: task
improvement never buys back a drift-budget breach. If the product genuinely
accepts that trade, it is an `ai-engineer:ai-architector` decision with a
written rationale, not a threshold adjustment.

**`RERUN` is not a verdict.** A 2–5 pt drift resolves to `PROMOTE` or `REJECT`
only after the seed-variation re-run completes. `PROMOTE` requires landing back
at ≤1 pt; any re-run still above 1 pt — whether in the 2–5 band or past the
breach — resolves stage 2 to `REJECT`. No report reaches its verdict section
with stage 2 still showing `RERUN`.

### Item count derives from the budget

The sample size is set by the decision you are making, not by convenience. A
half-width smaller than the margin you are judging is the whole requirement: at
typical accuracy, a few hundred items give a several-point half-width, and
resolving a difference well inside the 5-point threshold takes on the order of
a thousand.

**Report the half-width with every verdict.** A margin smaller than its own
confidence interval is `REJECT (uncertain)` — not `PROMOTE`, and not
`HARD FAIL`. Calling a 2-point drift measured with a 6-point half-width either
way is a coin flip wearing a verdict's clothes. Worked arithmetic and a
cautionary multi-run example: `references/gate-templates.md`.

## Catastrophic Forgetting

Unmanaged fine-tuning loses real general capability, and stage 2 is what
catches it. Reported loss rates cluster in three regimes:

| Regime | Typical general-capability loss |
|---|---|
| Unmanaged — no replay, no regularization | Large (tens of percent) |
| Basic management — some replay or a conservative learning rate | Roughly a third of unmanaged |
| Replay plus regularization, disciplined | Small single digits |

**A 10–30% general-data replay mix is the standard mitigation**: blend
general-domain data into training rather than training on target-task data
alone. Construction recipe: `skills/finetuning/dataset-curation`.

When a checkpoint hits the hard fail in stage 2, work this ladder in order:

1. **Adjust the replay-mix fraction by swapping rows, not adding them.** Adding
   rows confounds the mix fraction with total optimizer steps, so you cannot
   attribute the change. Dose is not monotonic at small-run scale — re-check
   drift after any swap rather than assuming more replay helps more.
2. **Lower the learning rate.**
3. **Fewer epochs.**
4. **Smaller adapter rank** — the same rank and learning-rate levers
   `skills/finetuning/peft-lora` and `skills/finetuning/preference-tuning` tune
   for the run, applied here in reverse.

This order is a default, not a law. **Remediation guidance derived from a
single before/after run pair is a hypothesis** — label it low-confidence as
soon as any lever produces a reversal, and prefer a seed-variation repeat over
trusting the next rung blindly. A lever that clears the drift breach but drops
a success-criterion metric below target is a two-sided tradeoff for a human,
not a reason to keep descending.

**Disclose drift-suite instruction reuse.** A replay row that copies the drift
harness's exact instruction phrasing — not merely disjoint source items — makes
that benchmark's post-replay score an upper bound. Flag it as
instruction-familiar, or re-probe with a paraphrase, before treating a
near-budget pass as clean.

## The Verdict

The report covers all four stages as evidence sections and **must end with a
terminal `PROMOTE` or `REJECT`**, the evidence that produced it, and exactly
one remediation when the verdict is `REJECT`. Downstream skills parse this
block, so its shape is a contract:

```
## Verdict

REJECT

Evidence: domain-adjacent drift suite dropped 6.2 pts (half-width 1.4;
threshold: >5 pt hard fail) despite +8 pts on the target task.

Top remediation: swap the replay-mix fraction from 10% toward 20%, holding
step count constant.
```

- **`REJECT` is a result, not an error.** A checkpoint that fails the drift
  budget or the paired comparison did its job by revealing that. Do not treat a
  `REJECT` as a failed run needing this skill re-run; it is the correct output
  of a working gate.
- **One remediation, not a menu.** Evidence sections may list everything
  observed; the verdict names the single highest-leverage fix from the ladder
  above. A report hedging across three possible fixes has not done the
  prioritization this skill exists to do.
- **No auto-retraining.** This skill produces a verdict and a report, never a
  re-triggered run. A `REJECT` hands remediation back to a human decision.

Full report template with all four stage sections, the drift scoring table, the
paired-comparison protocol, and a replay-mix configuration example:
`references/gate-templates.md`.

## Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| Promoting on the target metric alone | The capability tax is invisible and cumulative | Run the drift suite; budget it |
| Adjusting the threshold to pass a checkpoint | The budget stops meaning anything the first time it bends | `ai-engineer:ai-architector` decision, written down |
| Reporting a margin without its half-width | An unresolvable difference gets read as a result | `REJECT (uncertain)` when the margin is inside the interval |
| Drift suite unpinned or regenerated per run | Every comparison is against a different ruler | Freeze and version the suite; re-gate deliberately |
| Stage 3 skipped because stage 2 passed | Holdout wins that lose head-to-head do exist | Run both; require agreement |
| Adding replay rows instead of swapping them | Confounds mix fraction with step count | Swap rows, hold steps constant |
| Descending the whole ladder in one pass | Multiple changes, no attribution | One lever, re-measure, then decide |
| `RERUN` left as the stage-2 outcome | The report has no verdict | Resolve to `PROMOTE` or `REJECT` after seed variation |

## Red Flags

- No frozen baseline exists for the pre-tune model on the same suite
- The drift suite was built after the checkpoint, from the checkpoint's failures
- Target-task gain quoted to two decimals; capability drift not quoted at all
- The training set was never checked for eval-golden leakage
- Replay rows copy the drift harness's instruction phrasing verbatim
- A previously promoted checkpoint has never been re-gated against updated goldens
- The verdict section lists three possible remediations

## Verification

- [ ] Stage 1: training set deduped, decontaminated against goldens, label-noise scanned (`skills/finetuning/dataset-curation`)
- [ ] Frozen baseline exists for the base model on the identical, version-pinned suite
- [ ] Stage 2: drift measured per benchmark against the budget; half-width reported alongside every margin
- [ ] Any 2–5 pt drift resolved by a seed-variation re-run; no stage left showing `RERUN`
- [ ] Stage 3: paired comparison run on the same prompts, position-randomized if judged; stage-2 and stage-3 conclusions agree
- [ ] Stage 4 run for production traffic with predeclared rollback criteria, or explicitly stopped at stage 3 for a local deployment
- [ ] Replay-mix fraction recorded; instruction reuse against the drift harness disclosed
- [ ] Report ends in a terminal `PROMOTE` or `REJECT` with exactly one remediation on `REJECT`
- [ ] Verdict, suite version, and checkpoint ID logged together (`skills/mlops/experiment-tracking`)
- [ ] On `PROMOTE`, handoff to `skills/finetuning/quantized-export` carries the verdict

## Related Skills

- `references/gate-templates.md` — full report template, drift scoring table, paired-comparison protocol, sample-size arithmetic, replay-mix example
- `skills/evals/eval-design` — builds the suite and the frozen baseline this skill re-runs and diffs
- `skills/evals/regression-gates` — the CI ladder for prompt/model/retrieval changes; this skill is the one-off weights verdict, not a per-commit threshold
- `skills/evals/llm-judge` — position and length bias controls for the stage-3 paired comparison
- `skills/finetuning/quantized-export` — the only valid next step after `PROMOTE`
- `skills/finetuning/dataset-curation` — dedup, decontamination, and replay-mix construction
- `skills/finetuning/peft-lora`, `skills/finetuning/preference-tuning` — own the rank and learning-rate levers the forgetting ladder reaches for
- `skills/mlops/experiment-tracking` — records the verdict against the run; owns registry aliases
- `skills/mlops/model-monitoring` — the monitors a stage-4 canary compares against
