# Trace Conversion Recipes

Worked JSONL-to-JSONL conversions for
`skills/finetuning/trace-to-training-data`. Every output shape here matches
`skills/finetuning/dataset-curation`'s format tables exactly — if a field name
below ever diverges from that skill's schema, that skill wins and this file is
the bug.

## Contents

- [Input shape](#input-shape)
- [Graded trace to SFT row](#graded-trace-to-sft-row)
- [The rejection-sampling loop](#the-rejection-sampling-loop)
- [Human correction to SFT row](#human-correction-to-sft-row)
- [Step-level masking](#step-level-masking)
- [Trace pair to preference pair](#trace-pair-to-preference-pair)
- [The goldens-holdout check](#the-goldens-holdout-check)
- [Dataset card fields](#dataset-card-fields)

## Input shape

One row per trace, produced by the eval run — not by this skill.

```json
{"task_id": "t-042", "trace_id": "t-042-a3", "run_id": "2026-05-11-eval-7",
 "messages": [{"role": "user", "content": "Summarize the outage report."},
              {"role": "assistant", "content": "The database..."}],
 "verdict": "pass", "reward": 0.91, "grader": "judge_v3"}
```

`verdict` is required. `reward` is required for anything that filters or ranks
— rejection sampling and pair construction both need it. A row missing
`verdict` is not an input to this skill.

## Graded trace to SFT row

The mechanical core: strip the grading metadata, keep the conversation.

```python
def trace_to_sft(trace: dict) -> dict:
    """Emit a dataset-curation SFT row from one passing graded trace.

    Grading fields are dropped from the row itself and preserved as
    provenance: leaving reward/verdict inside the training row means the
    model trains on text that describes its own grading, which is not the
    behavior anyone wants and is easy to miss in a spot check.
    """
    return {
        "messages": trace["messages"],
        "_provenance": {                      # stripped before training, kept in the card
            "run_id": trace["run_id"],
            "trace_id": trace["trace_id"],
            "reward": trace["reward"],
            "grader": trace["grader"],
        },
    }
```

The `_provenance` block travels with the row through curation and lands in the
dataset card, then is dropped at tokenization time. Losing it is what makes a
bad grader's output impossible to withdraw later.

## The rejection-sampling loop

Keeping the top-reward fraction rather than everything that passed.

```python
import statistics

def rejection_sample(traces: list[dict], *, keep_fraction: float) -> list[dict]:
    """Keep the highest-reward passing traces, one per task.

    Per-task grouping matters: a global top-N over all tasks silently drops
    every hard task, because hard tasks score lower everywhere. The result is
    a training set that teaches the easy half of the distribution.
    """
    by_task: dict[str, list[dict]] = {}
    for t in traces:
        if t["verdict"] == "pass":
            by_task.setdefault(t["task_id"], []).append(t)

    kept = []
    for task_traces in by_task.values():
        ranked = sorted(task_traces, key=lambda t: t["reward"], reverse=True)
        n = max(1, round(len(ranked) * keep_fraction))
        kept.extend(ranked[:n])
    return kept
```

Record what the filter did, not just that it ran:

```python
thresholds = {
    task: min(t["reward"] for t in kept if t["task_id"] == task)
    for task in {t["task_id"] for t in kept}
}
# → dataset card: keep_fraction, per-task effective threshold, input/output counts
```

`keep_fraction` is a parameter to measure, not a constant to inherit. Sweep it
against downstream win rate the same way beta gets swept
(`skills/finetuning/preference-tuning`) — a tighter fraction means fewer, better
rows, and where that stops helping is task-specific.

## Human correction to SFT row

Corrections bypass the reward threshold entirely: a human already validated the
output, which is a stronger signal than any grader score.

```python
def correction_to_sft(trace: dict, corrected_output: str) -> dict:
    """Emit an SFT row from a human-corrected failing trace.

    No reward threshold applies — the correction IS the label. The original
    failing assistant turn is replaced, not appended, so the model never sees
    the failure as part of the target it should imitate.
    """
    messages = [m for m in trace["messages"] if m["role"] != "assistant"]
    messages.append({"role": "assistant", "content": corrected_output})
    return {
        "messages": messages,
        "_provenance": {
            "run_id": trace["run_id"],
            "trace_id": trace["trace_id"],
            "source": "human_correction",     # highest-value, scarcest rows in the set
            "corrected_by": trace.get("corrected_by"),
        },
    }
```

Track the `human_correction` count separately in the dataset card. It is the
only row class whose supply is bounded by human time, so its share of the set
is a planning number.

## Step-level masking

For multi-step agent trajectories where only some steps failed. Discarding the
whole trajectory throws away every good step in it.

```python
def mask_bad_steps(trace: dict, step_verdicts: list[str]) -> dict:
    """Keep a multi-step trajectory, training only on the steps that passed.

    Masked steps stay in the context (the model needs the trajectory's history
    to make later steps coherent) but contribute no loss. Deleting them instead
    would leave a trajectory that never actually happened, teaching a
    step sequence the environment would not produce.
    """
    assistant_idx = [i for i, m in enumerate(trace["messages"]) if m["role"] == "assistant"]
    train_on = {
        i: (v == "pass") for i, v in zip(assistant_idx, step_verdicts, strict=True)
    }
    return {
        "messages": [
            {**m, "train_on": train_on.get(i, False)} if m["role"] == "assistant" else m
            for i, m in enumerate(trace["messages"])
        ],
        "_provenance": {"run_id": trace["run_id"], "trace_id": trace["trace_id"],
                        "masked_steps": sum(1 for v in train_on.values() if not v)},
    }
```

Completion-only and per-turn masking mechanics — how `train_on` becomes a label
mask at tokenization time — are in
`skills/finetuning/dataset-curation`'s data-formats reference. Verify your
trainer honors per-turn masking before relying on it; support varies by TRL
version (context7).

## Trace pair to preference pair

```python
import statistics

def build_pairs(traces: list[dict]) -> list[dict]:
    """Build same-task preference pairs, rejecting near mu-2sigma.

    Same-task is non-negotiable: pairing across tasks teaches a preference
    between topics rather than between responses. Selecting the rejected member
    by distribution rather than by minimum avoids pairing against crashes and
    truncations, which teach a distinction the model already makes.
    """
    by_task: dict[str, list[dict]] = {}
    for t in traces:
        by_task.setdefault(t["task_id"], []).append(t)

    pairs = []
    for task_id, group in by_task.items():
        passing = [t for t in group if t["verdict"] == "pass"]
        failing = [t for t in group if t["verdict"] != "pass"]
        if not passing or len(group) < 4:      # too few traces to have a distribution
            continue
        rewards = [t["reward"] for t in group]
        target = statistics.mean(rewards) - 2 * statistics.pstdev(rewards)
        chosen = max(passing, key=lambda t: t["reward"])
        rejected = min(failing, key=lambda t: abs(t["reward"] - target))
        pairs.append({
            "prompt": _user_turn(chosen["messages"]),
            "chosen": _assistant_turn(chosen["messages"]),
            "rejected": _assistant_turn(rejected["messages"]),
            "_provenance": {"task_id": task_id,
                            "chosen_trace": chosen["trace_id"],
                            "rejected_trace": rejected["trace_id"],
                            "delta": chosen["reward"] - rejected["reward"]},
        })
    return pairs
```

Then filter by margin, having built the full candidate set first:

```python
pairs.sort(key=lambda p: p["_provenance"]["delta"], reverse=True)
kept = pairs[:target_count]     # high-margin subset; the distribution existed to filter on
```

## The goldens-holdout check

Run this as a gate before any merge. It is cheap, and the failure it prevents
invalidates every downstream eval and the promotion gate with them.

```python
def assert_no_golden_leak(rows: list[dict], golden_ids: set[str]) -> None:
    """Fail closed when any converted row derives from an eval golden.

    A golden that leaks into training makes the checkpoint's later score on
    that item a memorization test. The damage is invisible in training metrics
    and only shows up as a tune that evaluates well and behaves worse.
    """
    leaked = {
        r["_provenance"]["task_id"] for r in rows
        if r["_provenance"].get("task_id") in golden_ids
    }
    if leaked:
        raise SystemExit(f"GOLDEN LEAK: {len(leaked)} task ids in training set: {sorted(leaked)[:10]}")
```

Task-ID matching catches the direct case. Near-duplicate leakage — a paraphrase
of a golden that carries a different ID — needs the embedding-similarity sweep
in `skills/finetuning/dataset-curation`'s decontamination section; run both.

## Dataset card fields

What conversion must contribute so the merged set stays auditable.

```yaml
# Merged into the dataset card owned by skills/finetuning/dataset-curation
conversion:
  source_runs: ["2026-05-11-eval-7"]
  grader_versions: {"judge_v3": "<pinned>"}   # a grader change invalidates comparisons
  sft_rows:
    from_rejection_sampling: 0
    keep_fraction: 0.25
    effective_reward_threshold_by_task: {}
    from_human_correction: 0                  # bounded by human time — track separately
    step_masked_trajectories: 0
  preference_pairs:
    built: 0
    kept_after_delta_filter: 0
    rejected_selection: "mu-2sigma"
  hygiene:
    golden_ids_held_out: 0
    golden_leak_check: pass
    dedup_against: "data/train-merged.jsonl@v11"
    pii_scan: pass
    rows_dropped_by_pii_scan: 0
```

The `grader_versions` map is the field most often skipped and most often
needed: when a grader turns out to be wrong, it is the only way to find which
rows it produced and withdraw exactly those.
