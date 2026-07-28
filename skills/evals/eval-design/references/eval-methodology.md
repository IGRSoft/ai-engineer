# Eval Design — Methodology Deep Dive

Deep-dive companion to [../SKILL.md](../SKILL.md): the tier diagram, eval-set construction, metric selection by task type, the prompt A/B protocol, statistical honesty, eval-set hygiene, and the failure-analysis workflow.

## Tier Diagram

```
  cost / example
       ▲
┌──────┴──────────────────────────────────────────────────────────┐
│ 4. HUMAN REVIEW      expert labels, spot checks                 │ dollars/example
│    → high-stakes calls, judge calibration, release sign-off     │
├─────────────────────────────────────────────────────────────────┤
│ 3. LLM-AS-JUDGE      rubric scoring, pairwise A/B               │ cents/example
│    → subjective quality at scale (skills/evals/llm-judge)       │
├─────────────────────────────────────────────────────────────────┤
│ 2. PROGRAMMATIC      accuracy/F1, field precision-recall,       │ ~free, needs
│    METRICS           recall@k, exact match                      │ references
├─────────────────────────────────────────────────────────────────┤
│ 1. ASSERTIONS /      schema-valid, must-contain, regex,         │ free, run on
│    GOLDEN SETS       no-PII, length bounds, refusal-required    │ every commit
└─────────────────────────────────────────────────────────────────┘
```

## Building Task-Grounded Eval Sets

**Harvest, don't imagine.** Eval examples come from, in order of value:

1. **Real traffic** — sanitized production inputs (scrub PII/secrets before commit)
2. **Failure reports** — support tickets, incident post-mortems, user thumbs-down
3. **Expert-written hard cases** — domain experts enumerate what *should* be hard
4. **Red-team probes** — injection attempts, off-policy requests, degenerate inputs
5. **Synthetic backfill** — only to fill taxonomy gaps, always tagged `synthetic`

An imagined eval set measures the author's imagination. Production finds the cases
you didn't think of — harvest them from day one.

**Edge-case taxonomy.** Enumerate the dimensions along which inputs vary and tag
every example: input length, language, ambiguity, adversarial intent, empty or
degenerate input, multi-intent, out-of-scope. Tags drive stratified CI subsets
(`skills/evals/regression-gates`) and failure clustering (below).

**Size by decision stakes:**

| Decision | Examples | Why |
|----------|----------|-----|
| Directional signal in the dev loop | 20–50 | Catches gross regressions in minutes |
| Prompt A/B you will ship on | 100–300 | Small deltas need N (see MDD below) |
| Model/provider swap, release gate | 300–1000 | Expensive to reverse; tails matter |
| Safety/compliance behavior | Full risk-taxonomy coverage + human review | Coverage beats raw N |

**Version eval sets like code.** The set is a versioned artifact — JSONL in git (or
DVC-tracked when large), with a manifest. Bump the version on *any* example change.
**The eval-set version appears next to every reported metric**; a metric without
its eval-set version is unreproducible and incomparable.

```jsonl
{"id": "inv-0042", "tags": ["extraction", "multi-currency", "adversarial"], "source": "prod-2026-05", "input": {"document": "…"}, "expected": {"total": "1,204.50", "currency": "EUR"}}
{"id": "inv-0107", "tags": ["extraction", "empty-input"], "source": "failure-report", "input": {"document": ""}, "expected": {"error": "empty_document"}}
```

```yaml
# evals/datasets/invoice-extraction/manifest.yaml
name: invoice-extraction
version: 2026.06.2            # bump on ANY example change; metrics cite this
size: 240
provenance: {prod_traffic: 180, failure_reports: 38, synthetic_backfill: 22}
tags: [multi-currency, handwritten, adversarial, empty-input, multi-page]
license_note: prod examples scrubbed per data-handling policy 2026-04
```

## Metric Selection by Task Type

| Task type | Primary metrics | Notes |
|-----------|-----------------|-------|
| Classification / routing | Accuracy, per-class F1, confusion matrix | Macro-F1 when classes are imbalanced; report the confusion matrix, not one number |
| Extraction (structured fields) | Field-level precision/recall/F1; per-field exact match | Never whole-blob equality — one wrong field must not zero the example. Schema validity is a tier-1 assertion (`skills/prompt-engineering/structured-outputs`) |
| Generation (freeform) | Judge rubric dimensions + targeted assertions (must-mention, must-not-mention, format, length bounds) | ROUGE/BLEU correlate weakly with quality — use them as tripwires, never as gates |
| Summarization | Faithfulness judge + coverage assertions on key facts | Split "faithful to source" from "covers what matters" |
| RAG | Faithfulness + answer relevance (judge) **and** retrieval metrics (recall@k, MRR) measured separately | Separate retrieval failure from generation failure or you cannot fix either — `skills/llm-apps/rag-systems/references/retrieval-evaluation.md` |
| Agent / tool use | End-to-end task success rate, tool-call validity, step/token budget adherence | Trajectory assertions (tool X called before Y, no forbidden tools) |
| Safety / refusal | Refusal-when-required recall + over-refusal rate on a benign probe set | Always measure both directions — optimizing one silently degrades the other |

## Prompt A/B Comparison

This skill owns prompt A/B. The protocol:

1. **Same eval set** — identical pinned version for both variants
2. **One variable** — change the prompt only; same model, params, retrieval config.
   Change two things and the delta is unattributable.
3. **Deterministic runs** — temperature 0 (plus a fixed seed where the provider
   supports one), pinned model ID (verify identifiers against current provider
   docs via context7 — never hardcode from memory)
4. **Paired comparison** — record per-example results side by side; compare
   wins/losses/ties, not aggregate means alone
5. **Report** — deltas + win/loss counts + eval-set version + run config

```python
"""Paired prompt A/B over a pinned eval set.

Deterministic: temperature 0, pinned model, eval-set version recorded in output.
Launch: uv run python -m evals.ab_run --dataset evals/datasets/invoice-extraction
"""
import json
from pathlib import Path

def run_pair(dataset_dir: Path, prompt_a: str, prompt_b: str) -> dict[str, object]:
    manifest = load_manifest(dataset_dir)          # carries version + size
    records: list[dict[str, object]] = []
    for ex in load_examples(dataset_dir):
        score_a = score(complete(prompt_a, ex, temperature=0), ex["expected"])
        score_b = score(complete(prompt_b, ex, temperature=0), ex["expected"])
        records.append({"id": ex["id"], "tags": ex["tags"], "a": score_a, "b": score_b})
    wins = sum(r["b"] > r["a"] for r in records)   # B improves over A
    losses = sum(r["b"] < r["a"] for r in records)
    return {
        "eval_set": f"{manifest['name']}@{manifest['version']}",
        "wins_b": wins, "losses_b": losses, "ties": len(records) - wins - losses,
        "records": records,                        # keep per-example rows for the sign test
    }
```

**Minimum-detectable-difference intuition.** In a paired design only *discordant*
pairs (B wins or B loses) carry signal; ties are inert. With ~30 discordant pairs
you can reliably detect only lopsided splits (roughly 2:1 or worse). A true 1–2%
quality delta needs several hundred examples to distinguish from noise — below
that N, an apparent small win is a coin flip. **Ties go to the simpler/cheaper
variant. Don't ship on vibes.**

## Statistical Honesty

- **Learn your noise floor.** Even temperature-0 API runs vary (provider-side
  nondeterminism, judge ties). Rerun the *same* variant 2–3× once; the spread you
  see is your noise floor. Any delta inside it is not a result.
- **Small-N humility.** Report counts, not just percentages: "3 of 20 failed",
  never "15%". One flipped example at N=20 moves a metric 5 points.
- **Sign test over means for paired judge scores.** Judge scores are ordinal —
  a mean of 1–5 ratings is not meaningful. Count per-example wins/losses and run
  an exact sign test on the discordant pairs:

```python
from math import comb

def sign_test_p(wins: int, losses: int) -> float:
    """Two-sided exact sign test on discordant pairs (ties dropped)."""
    n = wins + losses
    k = max(wins, losses)
    tail = sum(comb(n, i) for i in range(k, n + 1)) / 2**n
    return min(1.0, 2 * tail)

sign_test_p(14, 4)   # 82 ties → p ≈ 0.031: likely a real improvement
sign_test_p(6, 3)    # 91 ties → p ≈ 0.51: noise — do not report as a win
```

- **No metric shopping.** Decide the primary metric and the shipping threshold
  *before* the run. Rerunning until significance, or picking the one metric that
  moved, is p-hacking with extra tokens.

## Eval-Set Hygiene

- **Contamination vs. training data.** If you fine-tune, eval examples must be
  provably absent from training data — run exact and near-duplicate scans across
  both sets. A model that memorized the eval set produces flawless, meaningless
  metrics. The scrubbing workflow lives in `skills/finetuning/dataset-curation`.
- **Leakage into prompts.** Never paste eval examples into few-shot exemplars or
  system prompts — the eval silently becomes a memorization test. Keep exemplar
  sources disjoint from eval data, and re-check after every prompt edit.
- **Refresh cadence.** Production drifts. Harvest new failures into the set on a
  schedule (monthly is a sane default) and after every incident post-mortem.
  Version-bump each refresh; retired examples stay in git history so historical
  metrics remain interpretable.
- **Hidden holdout.** When the team iterates hard against the visible set, hold
  out a slice nobody tunes against and check it at release — overfitting your own
  eval is real and looks exactly like progress.

## Failure Analysis Workflow

Metrics say *that* something failed; only transcripts say *why*.

```
run eval ──► read failing transcripts (10–20 minimum — never metrics alone)
         ──► tag each failure with a mode
             (wrong-field, hallucinated-value, format-break,
              unwarranted-refusal, retrieval-miss, truncation, …)
         ──► cluster tags ──► fix the BIGGEST cluster only
         ──► add cluster examples to the eval set (version bump)
         ──► re-run on the SAME pinned version ──► compare ──► repeat
```

1. **Read the transcripts.** Sample failures across tags, not just the first page.
2. **Tag failure modes**, extending the edge-case taxonomy as new modes appear.
3. **Fix one cluster per iteration.** Batching five fixes hides which one worked
   — and which one caused the new regression.
4. **Feed failures back** into the set so the fix is pinned by a regression
   example forever (`skills/evals/regression-gates` picks these up).
