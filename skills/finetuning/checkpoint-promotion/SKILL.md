---
name: checkpoint-promotion
description: >-
  Decide whether a trained checkpoint ships: four-stage gate, capability-drift
  budget, paired comparison vs base, forgetting checks, terminal PROMOTE or
  REJECT. Use when a training run produces a checkpoint or when re-gating one
  against new goldens. Not CI eval gates (regression-gates).
---

# Checkpoint Promotion

A fine-tune trades general capability for target-task performance, and the
trade is invisible if you only measure the target task. This skill measures
what the model lost and turns it into a verdict on the weights against a drift
budget, once per checkpoint. A checkpoint that trained cleanly and beat its
target metric still ships only after clearing all four stages.

**Input:** a trained checkpoint (from `skills/finetuning/peft-lora`,
`preference-tuning`, or `grpo-rlvr-training`), a frozen baseline for the
pre-tune model on the same suite, and a version-pinned capability-drift suite
(built per `skills/evals/eval-design`).

**Output:** a promotion report with all four stages as evidence, ending in a
terminal `PROMOTE` or `REJECT`, plus exactly one remediation on `REJECT`.

Owned by `ai-engineer:ml-engineer`. Overriding a `REJECT` is an architecture
decision for `ai-engineer:ai-architector`, recorded in writing.

**Elsewhere:**

- Per-change CI gates on prompt, model, or retrieval changes → `skills/evals/regression-gates`
- Eval set, metrics, frozen baseline → `skills/evals/eval-design`
- Judge position/length bias for stage 3 → `skills/evals/llm-judge`
- Registry aliases, run lineage, logging the verdict → `skills/mlops/experiment-tracking`
- Wiring promotion into a DAG or CI/CD → `skills/mlops/ml-pipelines`
- Canary monitors for stage 4 → `skills/mlops/model-monitoring`
- Exporting after `PROMOTE` (the only valid next step) → `skills/finetuning/quantized-export`
- Dedup, decontamination, replay-mix construction → `skills/finetuning/dataset-curation`
- Training config behind the drift (rank, LR) → `skills/finetuning/peft-lora`, `preference-tuning`, `training-optimization`

## The Four-Stage Gate

Each stage gates the next: a stage-2 failure means stage 3 does not run.
Stages 2 and 3 share one inference pass, so running them concurrently and
applying gate order at verdict time is fine when every grader is
deterministic; a judge-based comparison should wait for stage 2.

1. **Data quality.** Before any eval: training set deduped, scanned for
   eval-golden leakage, checked for label noise
   (`skills/finetuning/dataset-curation`). Leaked goldens invalidate every
   later stage because those numbers then measure memorization.
2. **Held-out plus frozen capability drift.** Re-run the pinned drift suite
   (general-capability benchmarks plus 200–500 domain-adjacent items) and diff
   per benchmark against the frozen baseline, scored with the Drift Budget.
3. **Paired comparison vs. base.** Same prompts, checkpoint vs. base model,
   position-randomized when a judge is involved. A holdout win that loses the
   paired comparison does not ship: stages 2 and 3 have to agree.
4. **Canary.** Stratified small-percentage rollout with automatic rollback for
   any checkpoint reaching production traffic. Local-only deployments stop at
   stage 3; that is the correct stopping point.

### Drift Budget

| Drift vs. baseline | Verdict |
|---|---|
| ≤1 pt | Noise — proceed |
| 2–5 pts | Re-run with seed variation before deciding |
| >5 pts | Hard fail — no exception for task gains |

The hard-fail row governs: +8 on the target task with −6 general still fails.
Accepting that trade is an `ai-engineer:ai-architector` decision with a
written rationale, not a threshold adjustment.

`RERUN` is not a verdict. A 2–5 pt drift resolves only after the
seed-variation re-run: `PROMOTE` requires landing back at ≤1 pt; anything
still above 1 pt resolves stage 2 to `REJECT`.

### Sample size and half-width

Size the suite so the half-width is smaller than the margin you are judging.
At typical accuracy a few hundred items give a several-point half-width;
resolving differences well inside the 5-pt threshold takes on the order of a
thousand.

Report the half-width with every margin. A margin smaller than its own
interval resolves to `REJECT (uncertain)` — neither `PROMOTE` nor hard fail.
Arithmetic and a multi-run example: `references/gate-templates.md`.

## Catastrophic Forgetting

Stage 2 is what catches lost general capability. Reported loss rates cluster
in three regimes:

| Regime | Typical general-capability loss |
|---|---|
| Unmanaged — no replay, no regularization | Large (tens of percent) |
| Basic management — some replay or a conservative learning rate | Roughly a third of unmanaged |
| Replay plus regularization, disciplined | Small single digits |

The standard mitigation is a 10–30% general-data replay mix
(`skills/finetuning/dataset-curation`).

On a stage-2 hard fail, work this ladder in order, one lever per re-run:

1. **Adjust the replay-mix fraction by swapping rows, not adding them** —
   adding rows confounds mix fraction with optimizer steps. Dose is not
   monotonic at small-run scale, so re-check drift after every swap.
2. **Lower the learning rate.**
3. **Fewer epochs.**
4. **Smaller adapter rank.**

The order is a default. Guidance from a single before/after run pair is a
hypothesis: label it low-confidence once any lever produces a reversal, and
prefer a seed-variation repeat over the next rung. A lever that clears drift
but drops a success-criterion metric below target is a tradeoff for a human,
not a reason to keep descending.

**Disclose drift-suite instruction reuse.** Replay rows that copy the drift
harness's exact instruction phrasing make that benchmark's post-replay score
an upper bound. Flag it as instruction-familiar or re-probe with a paraphrase
before treating a near-budget pass as clean.

## The Verdict

Downstream skills parse this block, so its shape is a contract:

```
## Verdict

REJECT

Evidence: domain-adjacent drift suite dropped 6.2 pts (half-width 1.4;
threshold: >5 pt hard fail) despite +8 pts on the target task.

Top remediation: swap the replay-mix fraction from 10% toward 20%, holding
step count constant.
```

- `REJECT` is a correct output of a working gate, not an error or a run to
  retry.
- Name one remediation — the highest-leverage rung of the ladder — not a menu.
  Evidence sections may list everything observed.
- No auto-retraining. The skill produces a verdict and report; remediation goes
  back to a human.

Full report template, drift scoring table, paired-comparison protocol, and
replay-mix config: `references/gate-templates.md`.

## Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| Promoting on the target metric alone | The capability tax is invisible and cumulative | Run the drift suite; budget it |
| Adjusting the threshold to pass a checkpoint | The budget stops meaning anything the first time it bends | `ai-engineer:ai-architector` decision, written down |
| Reporting a margin without its half-width | An unresolvable difference gets read as a result | `REJECT (uncertain)` when the margin is inside the interval |
| Drift suite unpinned, regenerated per run, or built from the checkpoint's failures | Every comparison is against a different ruler | Freeze and version the suite before training; re-gate deliberately |
| Promoted checkpoint never re-gated after goldens change | The old verdict was against a ruler no longer in use | Re-gate against the updated suite |
| Stage 3 skipped because stage 2 passed | Holdout wins that lose head-to-head do exist | Run both; require agreement |
| Adding replay rows instead of swapping them | Confounds mix fraction with step count | Swap rows, hold steps constant |
| Descending the whole ladder in one pass | Multiple changes, no attribution | One lever, re-measure, then decide |
| `RERUN` left as the stage-2 outcome | The report has no verdict | Resolve to `PROMOTE` or `REJECT` after seed variation |

## Verification

- [ ] Stage 1: training set deduped, decontaminated against goldens, label-noise scanned
- [ ] Frozen baseline exists for the base model on the identical, version-pinned suite
- [ ] Stage 2: drift measured per benchmark against the budget; half-width reported with every margin
- [ ] Any 2–5 pt drift resolved by a seed-variation re-run; no stage left showing `RERUN`
- [ ] Stage 3: paired comparison on the same prompts, position-randomized if judged; stages 2 and 3 agree
- [ ] Stage 4 run for production traffic with predeclared rollback criteria, or explicitly stopped at stage 3 for a local deployment
- [ ] Replay-mix fraction recorded; instruction reuse against the drift harness disclosed
- [ ] Report ends in a terminal `PROMOTE` or `REJECT` with exactly one remediation on `REJECT`
- [ ] Verdict, suite version, and checkpoint ID logged together (`skills/mlops/experiment-tracking`)
- [ ] On `PROMOTE`, handoff to `skills/finetuning/quantized-export` carries the verdict
