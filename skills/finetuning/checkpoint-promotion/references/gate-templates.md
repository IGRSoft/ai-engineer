# Promotion Gate Templates

The full report template, the paired-comparison protocol, the sample-size
arithmetic behind the drift budget, and a replay-mix configuration example for
`skills/finetuning/checkpoint-promotion`.

## Contents

- [Report template](#report-template)
- [Drift scoring table](#drift-scoring-table)
- [Sample size and half-width](#sample-size-and-half-width)
- [Paired-comparison protocol](#paired-comparison-protocol)
- [Replay-mix configuration](#replay-mix-configuration)
- [A cautionary multi-run trajectory](#a-cautionary-multi-run-trajectory)

## Report template

Copy this whole structure. The stage headings are what makes a report
skimmable by whoever inherits the decision six months later, and the verdict
block at the end is parsed by downstream skills.

```markdown
# Promotion Report — <checkpoint-id>

| Field | Value |
|---|---|
| Checkpoint | runs/<run-id>/checkpoint-<step> |
| Base model | <repo>@<revision> |
| Training method | LoRA / DPO / GRPO |
| Drift suite | eval/drift-suite.yaml@<version> |
| Baseline | eval/baseline-<model>.json@<version> |
| Gated by | <name>, <date> |

## Stage 1 — Data Quality

- Dedup: <method>, <n> exact and <n> near-duplicate rows removed
- Decontamination: <n> golden IDs held out; <n> collisions found and dropped
- Label noise: <method>, <n> rows flagged
- Verdict: PASS / FAIL

## Stage 2 — Capability Drift

<the drift scoring table below>

- Verdict: PASS / RERUN → resolved to PASS / HARD FAIL

## Stage 3 — Paired Comparison vs. Base

- Items: <n> | Grader: deterministic / judge (<model>@<version>)
- Position randomized: yes / n-a (deterministic)
- Win / tie / loss: <n> / <n> / <n> — win rate <x>% (half-width <y> pts)
- Agreement with stage 2: yes / no — <explanation if no>
- Verdict: PASS / FAIL

## Stage 4 — Canary

- Traffic fraction, stratification, rollback trigger, observation window
- Or: NOT RUN — local-only deployment, correct stopping point at stage 3

## Verdict

PROMOTE | REJECT

Evidence: <the one measurement that decided it, with its half-width>

Top remediation: <exactly one, only when REJECT>
```

## Drift scoring table

One row per benchmark. The half-width column is not optional — it is what
separates a measured result from a number.

```markdown
| Benchmark | Baseline | Checkpoint | Δ (pts) | Half-width | Band |
|---|---|---|---|---|---|
| General knowledge | 68.4 | 67.9 | −0.5 | ±1.2 | noise (≤1) |
| Reasoning | 54.1 | 52.0 | −2.1 | ±1.8 | rerun (2–5) |
| Instruction following | 79.2 | 73.0 | −6.2 | ±1.4 | HARD FAIL (>5) |
| Domain-adjacent (n=400) | 61.0 | 69.5 | +8.5 | ±2.0 | target gain |
```

Read this table the way the budget intends: the +8.5 on the domain-adjacent
slice does not offset the −6.2. The hard-fail row governs, and the verdict is
`REJECT`.

Note the second row. A −2.1 with a ±1.8 half-width lands in the rerun band, but
the interval also touches noise — that is exactly the case seed variation
exists to resolve, and exactly the case that gets waved through when the
half-width column is missing.

## Sample size and half-width

The drift budget's thresholds are only meaningful if the measurement can
resolve them. For a proportion metric, the half-width of a 95% interval is
approximately:

```
half_width ≈ 1.96 × sqrt(p × (1 − p) / n)
```

At an accuracy around 0.7, that gives roughly:

| n | Half-width | What it can resolve |
|---|---|---|
| 50 | ~±13 pts | Nothing in this budget — even the hard-fail threshold is inside the interval |
| 200 | ~±6 pts | A pragmatic floor: distinguishes a large breach from a clean pass, nothing finer |
| ~1,300 | ~±2.5 pts | Half the 5-pt threshold — resolves the band boundaries |

**The rule that follows:** report the half-width with every margin, and when
the margin is smaller than its own half-width, the stage resolves to
`REJECT (uncertain)`. Not `PROMOTE` (the difference was not demonstrated) and
not `HARD FAIL` (neither was the breach). Escalating an uncertain result to a
larger eval run is a legitimate outcome; calling it either way is not.

Paired designs (same items scored under both models, differenced per item)
resolve smaller margins at the same n than independent samples, because the
item-difficulty variance cancels. Prefer paired scoring whenever the same items
can be run through both models — which, for a drift suite, is always.

## Paired-comparison protocol

Stage 3, in the order the steps have to happen.

1. **Fix the item set before generating anything.** Pulled from the pinned
   suite, not selected after seeing stage-2 results — choosing items after the
   fact is how a stage-2 loss gets rescued by a friendlier slice.
2. **Generate both sides under identical decoding settings**, persisted and
   reused rather than re-specified. Temperature 0 and a fixed seed.
3. **Randomize position per item** when an LLM judge scores the pair. Judges
   carry a position preference; without randomization the win rate partly
   measures which side was shown first (`skills/evals/llm-judge`). Deterministic
   graders make this step not applicable — record that it was N/A rather than
   silently skipping it.
4. **Score ties explicitly.** A rubric with no tie outcome forces the judge to
   invent a difference, which inflates both win and loss rates.
5. **Report win rate with its half-width**, against a threshold declared before
   the run. A win rate whose interval spans 50% is not a win.
6. **Reconcile with stage 2.** Agreement is the expected case. A stage-2 win
   with a stage-3 loss is a finding — usually that the drift suite and the real
   task disagree about what quality means — and it blocks promotion until
   explained.

## Replay-mix configuration

The first rung of the forgetting ladder, expressed as config rather than prose.

```yaml
# Replay mix for a re-run after a drift breach. The critical property is that
# total row count and step count are held constant against the previous run:
# adding general rows instead of swapping them changes the optimizer-step count
# too, and then the drift delta cannot be attributed to the mix.
dataset:
  target_task:
    source: "data/task-sft.jsonl@v7"
    rows: 8000            # was 9000 — 1000 rows swapped out, not added
  general_replay:
    source: "data/general-replay.jsonl@v2"
    rows: 2000            # was 1000 — mix moves 10% → 20%
    # Replay rows must not reuse the drift harness's instruction phrasing;
    # sharing phrasing makes that benchmark's post-replay score an upper bound.
    instruction_overlap_with_drift_suite: none   # none | paraphrased | verbatim
total_rows: 10000         # unchanged
training:
  epochs: 3               # unchanged
  learning_rate: 1.0e-4   # unchanged — one lever per re-run
  seed: 3407
```

One lever moves per re-run. Changing the mix and the learning rate together
produces a number you cannot attribute to either, which means the next decision
is guesswork dressed as evidence.

## A cautionary multi-run trajectory

Why the ladder is labelled a default rather than a procedure. A representative
sequence of five runs chasing one drift breach:

| Run | Change | Task metric | Drift | Read |
|---|---|---|---|---|
| 1 | baseline tune | +8.5 | −6.2 | HARD FAIL — enter the ladder |
| 2 | replay 10% → 20% (swapped) | +7.9 | −2.4 | Improved, still in the rerun band |
| 3 | replay 20% → 30% (swapped) | +6.1 | −3.1 | **Reversal** — more replay made drift worse |
| 4 | back to 20%, LR halved | +7.2 | −0.9 | Clears the budget |
| 5 | run 4 repeated, new seed | +6.8 | −2.0 | Run 4's pass was partly seed |

Two lessons the table teaches better than a rule can. **Run 3 is the reversal**:
replay dose is not monotonic at small-run scale, so "the ladder says more
replay" stops being true the moment the data disagrees. **Run 5 is the reason
seed variation is in the budget at all**: a single passing run at 0.9 pts was
not a clean pass, it was one draw from a distribution straddling the noise
boundary.

Guidance derived from a single before/after pair is a hypothesis. Label it
low-confidence, repeat with seed variation before acting on it, and hand a
two-sided tradeoff — drift cleared but a success-criterion metric now below
target — to a human rather than descending another rung.
