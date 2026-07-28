---
name: llm-judge
description: >-
  Use LLMs to grade LLM outputs reliably: pointwise-vs-pairwise selection, rubric
  design with anchored descriptors, bias mitigations (position, length,
  self-preference, sycophancy), calibration against human labels (Cohen's kappa),
  evidence-first judge prompts with structured output, cost ladders, and judge
  regression tests. Use when a quality dimension cannot be checked by code (tone,
  faithfulness, helpfulness), when building or editing a judge prompt, when judge
  scores disagree with humans, when ranking prompt variants — or when someone
  proposes an uncalibrated "rate 1-10" judge as a gate.
---

# LLM-as-Judge

**A judge is a measurement instrument: calibrated, versioned, and itself under test**

## Overview

LLM judges buy *scale* for quality dimensions that code cannot check — tone,
faithfulness, helpfulness, rubric adherence. They are also biased, drifting
instruments that reward verbosity and confidence unless engineered otherwise.
This skill covers when a judge is the right tier, how to write rubrics and judge
prompts, how to measure whether the judge measures anything (calibration), and
how to keep judge cost bounded. Judge harnesses are built by
`ai-engineer:ai-test-generator`; pairwise A/B consumers route through
`ai-engineer:ai-prompt-engineer`.

Full worked judge prompts (binary correctness, 3-level rubric, pairwise with swap
protocol, RAG faithfulness, refusal appropriateness) with output schemas live in
`references/judge-prompt-templates.md` — read it when implementing a harness.

## When to Use

- Grading subjective or semantic quality at scale (tone, helpfulness, faithfulness, style-guide adherence)
- Ranking two prompt/model variants where programmatic metrics can't separate them
- Scoring the generation dimensions selected in `skills/evals/eval-design` (its metric table routes here)
- Reviewing an existing judge that disagrees with human intuition or drifts over time
- Deciding pointwise vs. pairwise for a new judged dimension

**When NOT to use:**

- The fact is checkable by code — schema validity, exact values, regex, must-contain, length: tier-1 assertions per `skills/evals/eval-design`. Never pay tokens for `json.loads`.
- High-stakes decisions (legal, safety sign-off, money movement) — human review decides; a judge may pre-screen and prioritize, never gate alone.
- Retrieval metrics (recall@k, MRR) — programmatic: `skills/llm-apps/rag-systems/references/retrieval-evaluation.md`
- Choosing which dimensions to measure at all → `skills/evals/eval-design`
- Wiring judge metrics into CI (thresholds, caching, flake policy) → `skills/evals/regression-gates`

## Judge Mode Selection

```
Property checkable by code? ──────────── yes ─► assertion / metric. NOT a judge.
        │ no
High-stakes (legal/safety/money)? ────── yes ─► human decides; judge pre-screens only
        │ no
Question is "which is better, A or B"? ─ yes ─► PAIRWISE + swap protocol
        │ no                                     (ranking, prompt A/B)
Need absolute pass/fail or score? ─────────────► POINTWISE vs anchored rubric
                                                 (CI gates, production sampling)
```

| Mode | Use for | Strengths | Costs |
|------|---------|-----------|-------|
| Pairwise | Ranking, prompt/model A/B | Relative judgment is easier — more reliable on close calls | Position bias (mandatory swap-and-average, 2× calls); no absolute bar |
| Pointwise | Absolute gates, monitoring samples | Comparable across time; one call per output | Needs behaviorally anchored rubric; drifts more — calibrate on a schedule |

Pairwise verdicts answer "is B better than A?" but never "is B good enough?" —
release gates need a pointwise floor even when A/B chose the candidate.

## Rubric Design

- **One dimension per rubric.** "Overall quality 1–10" confounds correctness,
  tone, length, and format into one unactionable number. Run separate
  faithfulness / completeness / tone judges — each is cheap, auditable, and
  independently gateable.
- **Behaviorally anchored descriptors.** Every level is defined by observable
  behavior, not adverbs. "Mostly accurate" is vibes; "contains no claim
  unsupported by the source" is checkable.
- **Binary decomposition beats 1–10 vagueness.** Five yes/no questions get far
  tighter judge–human agreement than one 10-point scale, and the failing
  question tells you what to fix. Score = count of yes.

```yaml
# BAD — unanchored, multi-dimensional, uninterpretable
rubric: "Rate the answer's overall quality from 1 to 10."

# GOOD — one dimension, binary-decomposed, behaviorally anchored
dimension: groundedness
questions:
  - id: no_unsupported_claims
    text: "Does every factual claim have supporting text in the provided sources?"
  - id: no_contradictions
    text: "Is every claim free of contradiction with the sources?"
  - id: uncertainty_marked
    text: "Where sources are silent, does the answer say so instead of guessing?"
scoring: sum of yes (0-3); gate at 3/3 for release, 2/3 warn
```

## Known Biases and Mitigations

| Bias | Symptom | Mitigation |
|------|---------|------------|
| Position | In pairwise, the first (or last) slot wins more often regardless of content | Swap-and-average: judge (A,B) and (B,A); order-disagreement counts as a tie |
| Length / verbosity | Longer answers score higher at equal substance | Rubric explicitly scores padding as a defect; keep length-matched control pairs in the judge's own eval set; report mean length delta beside win rate |
| Self-preference | Judge favors outputs of its own model family | Judge from a different family than the candidates — or validate the same-family judge against human labels before trusting it |
| Style over substance | Fluent-confident-wrong beats hedged-correct | Evidence-first prompting (quote-then-score); separate correctness from style into different judges |
| Sycophancy toward confident tone | Assertive phrasing and self-praise raise scores | Anchor descriptors to verifiable behavior; instruct the judge to ignore the answer's self-assessment and meta-commentary |

Every mitigation is testable: the bias probes (length-matched pairs, swapped
orders, confident-nonsense) belong in the judge's own eval set (see
Meta-Evaluation).

## Calibration Against Human Labels

An uncalibrated judge is a random-looking number generator with good grammar.
Before a judge's verdicts count:

1. **Label a seed set** — 50–100 examples spanning the full score range and the
   hard tags, labeled by 2+ humans using the same rubric.
2. **Measure judge–human agreement.** Raw percent agreement flatters on skewed
   labels (a judge that always says "pass" scores 90% on a 90%-pass set).
   Cohen's kappa corrects for chance agreement:

```python
def cohen_kappa(a: list[str], b: list[str]) -> float:
    """Chance-corrected agreement between two label sequences."""
    n = len(a)
    labels = set(a) | set(b)
    p_o = sum(x == y for x, y in zip(a, b)) / n
    p_e = sum((a.count(lab) / n) * (b.count(lab) / n) for lab in labels)
    return (p_o - p_e) / (1 - p_e)
```

   Practical bars: κ < 0.4 unusable; 0.4–0.6 directional signal only; > 0.6
   good enough to gate. Always compare κ(judge, human) against κ(human, human)
   — the judge cannot beat the human-agreement ceiling, and if humans disagree
   with each other, fix the rubric before blaming the judge.
3. **Re-calibrate on drift triggers:** judge model version change, judge prompt
   or rubric edit, domain shift in the graded traffic. Each requires a seed-set
   rerun before verdicts count again.

## Judge Prompt Mechanics

- **Evidence-first: quote-then-score.** The judge extracts verbatim quotes
  supporting its verdict *before* emitting the score. Score-first prompts
  produce post-hoc rationalization — the evidence no longer constrains the
  number. Enforce ordering structurally: evidence fields precede score fields
  in the output schema, so generation order matches reasoning order.
- **Structured output.** Verdicts return as schema-validated JSON
  (`skills/prompt-engineering/structured-outputs`) — never regex-parsed prose.
  On validation failure, re-ask once with the error; then record `judge_error`
  and track the error rate as a monitored metric. Never guess a score.
- **Determinism.** Temperature 0. Pin the judge model to an exact version —
  never a `latest` alias (verify current identifiers via context7, don't recall
  them from memory). Record the full judge identity — model version + judge
  prompt version + rubric version — next to every metric, exactly like the
  eval-set version rule in `skills/evals/eval-design`.

```text
[system]  You are a strict evaluator. Judge ONLY <dimension> per the rubric.
          Ignore style, length, and the answer's own confidence claims.
[user]    <rubric with anchored levels>
          <input + sources + candidate answer, clearly delimited>
          First list verbatim evidence quotes, then decide.
          Respond with JSON: {"evidence": [...], "score": ..., "rationale": "..."}
```

Complete production-grade templates with schemas and calibration notes:
`references/judge-prompt-templates.md`.

## Cost Control

Climb this ladder before accepting "judges are too expensive":

1. **Assertions screen first.** Outputs that fail tier-1 checks (schema, format,
   empty) are scored fail programmatically — never spend judge tokens on them.
2. **Sample, don't exhaust.** Production monitoring judges a stratified sample;
   CI judges the subset tiers defined in `skills/evals/regression-gates`.
3. **Cache verdicts** keyed by `hash(input, output, judge_identity)` — unchanged
   candidate outputs re-judge free across runs, and caching doubles as
   determinism (same key, same verdict).
4. **Cheap-judge screen + strong-judge verify.** A small/cheap judge scores
   everything; the strong judge re-scores only the band near the gate threshold
   plus a fixed random audit slice. Monitor the cheap↔strong disagreement rate —
   when it climbs, the cheap judge has drifted out of its depth.

## Meta-Evaluation: the Judge's Own Eval Set

The judge is a model + prompt — so it gets the same treatment as any model +
prompt:

- **Judge eval set** = the human-labeled seed set + adversarial probes:
  verbose-but-wrong, terse-but-right, confident nonsense, position-swapped
  pairs, answers that flatter the rubric wording.
- **Judge regression tests** run whenever the judge prompt, rubric, or judge
  model version changes: agreement with human labels must not drop, bias probes
  must not flip. Wire it like any other gate (`skills/evals/regression-gates`).
- **Drift watch.** Score a fixed probe set on a schedule; movement without any
  change on your side means the provider moved under you — which is why the
  judge model version is pinned, and why unexplained drift blocks gating until
  re-calibration.

## Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| Judging what code can check | Tokens + nondeterminism spent on a free deterministic check | Assertions first; judge only the subjective residual |
| "Rate 1–10 overall quality" | Unanchored, confounded; 6-vs-7 carries no information | One dimension per rubric; binary decomposition with anchored descriptors |
| Single-order pairwise | Position bias decides close calls | Swap-and-average; order-disagreement = tie |
| Uncalibrated judge as a gate | Gating on an unvalidated instrument | Human-labeled seed set + κ ≥ bar before verdicts count |
| Score-then-justify prompt | Post-hoc rationalization — evidence doesn't constrain the score | Quote-then-score; evidence fields precede score in the schema |
| Judge model on `latest` | Verdicts drift with provider updates; metrics incomparable over time | Pin exact version; record judge identity with every metric |
| Judge family == candidate family, unvalidated | Self-preference silently inflates your own model's scores | Cross-family judge, or human-validate the same-family judge first |
| Parsing scores from freeform prose | Brittle; silent parse failures skew metrics | Structured output + schema validation + tracked `judge_error` rate |
| One mega-judge for all dimensions | Cross-dimension contamination; unactionable failures | Parallel single-dimension judges, independently calibrated |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "The model is smart enough to just rate quality" | Smart ≠ calibrated. Uncalibrated judges measurably reward verbosity and confidence. Calibrate, or the number is decoration |
| "We can't afford human labels" | 50–100 seed labels cost hours once. Without them you cannot distinguish a working judge from a coin with better vocabulary |
| "Temperature 0 makes the judge deterministic" | It reduces variance; provider nondeterminism remains — and determinism says nothing about validity. Cache verdicts and calibrate |
| "The judge agreed with me on the examples I checked" | You checked the easy ones. Agreement is measured on a labeled set spanning the range, including adversarial probes |
| "A strong judge on every output is too expensive" | Screen with assertions, sample, cache, ladder cheap→strong. Cost control is a design problem, not a reason to skip measurement |
| "We tweaked the judge prompt, it's basically the same" | The judge is an instrument: any prompt/rubric edit is a version bump and a re-calibration, or all following metrics are on a new, uncompared scale |

## Red Flags

- Judge verdicts gating CI with no judge–human agreement number ever measured
- "Overall quality: 7/10" anywhere in a report
- Pairwise win rates reported without a swap protocol
- Judge model unpinned, or silently updated mid-experiment
- Judge scores regex-parsed from prose; unexplained gaps in judged rows
- Judge prompt edited without a seed-set recalibration run
- Win rate correlates with answer length — check this, it's one `groupby` away
- The judge and the graded model are the same family and nobody validated that

## Verification

- [ ] Everything code-checkable is an assertion; the judge grades only the subjective residual
- [ ] Each judged dimension has its own rubric with behaviorally anchored levels or binary decomposition — no bare 1–10
- [ ] Pairwise runs use swap-and-average; order disagreements counted as ties; pointwise gates have anchored rubrics
- [ ] Judge calibrated on a human-labeled seed set; κ measured, above the bar, and below-ceiling checked against human–human agreement
- [ ] Judge prompt is evidence-first (quote-then-score) with schema-validated structured output and a tracked `judge_error` rate
- [ ] Temperature 0; judge model pinned; judge identity (model + prompt + rubric versions) recorded next to every metric
- [ ] Cost ladder active: assertion screen, sampling, verdict cache, cheap→strong verify with monitored disagreement
- [ ] Judge has its own eval set (seed labels + bias probes) and regression-tests on any judge/rubric/model change
