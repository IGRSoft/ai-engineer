---
name: eval-design
description: >-
  Design evaluations that predict production quality: the assertion→metric→judge→human
  hierarchy, task-grounded eval sets harvested from real traffic, metric selection by
  task type, paired prompt A/B comparison, statistical honesty, eval-set hygiene, and
  the failure-analysis workflow. Use when creating or expanding an eval set, choosing
  metrics for an LLM feature, comparing two prompts or models, sizing an eval set for
  a decision, versioning eval data, triaging a metric drop — or when a prompt/model/
  retrieval change is about to ship "because it looks better". Measure it; never ship
  on vibes.
---

# Eval Design

**Evals that predict production quality — task-grounded, versioned, statistically honest**

## Overview

An eval set is the test suite of an LLM feature: without one, every prompt tweak,
model swap, and retrieval change ships blind. This skill covers *what to measure and
on which data* — building eval sets from real traffic, picking metrics per task type,
running paired A/B comparisons, and reading failures. It is the plugin's core
discipline: **every prompt, model, or retrieval change ships with an eval run**
(enforced by `skills/evals/regression-gates`; QA verdict per
`skills/_shared/workflow-integration`).

Harness construction is owned by `ai-engineer:ai-test-generator`; prompt A/B
consumers route through `ai-engineer:ai-prompt-engineer`.

## When to Use

- Creating the first eval set for a new LLM feature, or expanding a stale one
- Choosing metrics for a classification, extraction, generation, RAG, or agent task
- Comparing two prompts, models, or retrieval configs before shipping one
- Deciding how many examples a decision needs (dev loop vs. release gate)
- A metric moved and you need to find out *why*, not just *that*
- Reviewing whether an existing eval still predicts production quality

**When NOT to use:**

- Writing or debugging an LLM judge (rubrics, biases, calibration) → `skills/evals/llm-judge`
- Wiring evals into CI (thresholds, baselines, flake policy) → `skills/evals/regression-gates`
- Retrieval-metric depth (recall@k, MRR, nDCG mechanics) → `skills/llm-apps/rag-systems/references/retrieval-evaluation.md`
- Training-data curation and contamination scrubbing workflow → `skills/finetuning/dataset-curation`

## The Eval Hierarchy

Four tiers. Cost per example rises as you climb; **use the cheapest tier that
actually measures the property**, and escalate only when the lower tier cannot
express the check.

Full tier diagram with per-tier cost anchors: `references/eval-methodology.md`.

A healthy suite is a pyramid: many assertions, a solid programmatic layer, a few
judged dimensions, a thin human panel. A suite that starts at tier 3 for
properties `json.loads` could check is burning money and determinism.

## Deep Dives

Read `references/eval-methodology.md` when building or versioning an eval set, choosing metrics by task type, running a paired prompt A/B, sizing N and testing significance, checking set hygiene, or doing failure analysis.

## Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| Imagined eval set ("what users might ask") | Measures the author's imagination, not production | Harvest from traffic and failure reports; synthetic only for taxonomy gaps, tagged |
| Judge-first eval design | Pays judge cost and nondeterminism for properties an assertion checks free | Climb the hierarchy from tier 1; cheapest sufficient tier |
| Metric reported without eval-set version | Unreproducible; deltas across set versions are meaningless | Version the set; print `name@version` next to every metric |
| Whole-blob equality for structured output | One wrong field zeroes the example; no signal about what to fix | Field-level precision/recall + tier-1 schema assertion |
| Shipping on eyeballed samples | N=3 vibes; regressions hide in the tail | Paired A/B on a pinned set; sign test on discordant pairs |
| Changing prompt and model in one comparison | Delta unattributable | One variable per A/B; run a 2-step ladder if both must change |
| Static eval set for six months | Team overfits it; production drifts away | Refresh cadence + hidden holdout slice |
| Mean of ordinal judge scores as the verdict | 3.8 vs 3.9 on a 1–5 scale is numerology | Win/loss counts + sign test; distribution over levels |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "The output is subjective — you can't measure it" | Decompose: format, groundedness, must-mentions are objective assertions; the residual subjective core gets a calibrated rubric judge (`skills/evals/llm-judge`) |
| "We'll build evals after launch" | Post-launch you iterate blind through your riskiest period. 30 harvested examples today beat 300 planned ones later — and launch traffic is the harvest source, so start collecting day one |
| "The new prompt is obviously better" | Obvious on the five examples you tried. Paired runs regularly flip "obvious" wins once the tail is included |
| "N=20 showed +5%, ship it" | +5% at N=20 is one flipped example. Size the set to the decision stakes before trusting the delta |
| "Temperature 0 means one run is enough" | Provider-side nondeterminism persists at temp 0. Learn the noise floor with reruns before reading small deltas |
| "We don't have time to read transcripts" | Then you will fix the wrong cluster and re-run everything twice. Transcript reading is the fastest debugging step, not overhead |

## Red Flags

- A reported metric with no eval-set version next to it
- Eval set authored in one afternoon from imagination, untouched since
- Nobody has read a failing transcript this month — dashboards only
- Prompt change merged with "tested manually" in the PR description
- The same examples for months while the team tunes against them, no holdout
- Eval examples visible verbatim inside few-shot prompts
- A/B verdict based on aggregate means of 1–5 judge scores
- Fine-tuning data and eval data never cross-checked for overlap

## Verification

- [ ] Every metric is reported with its eval-set version and run config (model, temperature/seed)
- [ ] Eval set is version-controlled with a manifest and per-example provenance (traffic / failure / synthetic)
- [ ] Examples carry taxonomy tags; set size matches the decision stakes table
- [ ] Metrics match the task-type table (field-level for extraction; retrieval and generation split for RAG)
- [ ] A/B runs are paired, single-variable, deterministic (temp 0/seeded), sign-tested on discordant pairs
- [ ] Contamination scan run against any fine-tuning data (`skills/finetuning/dataset-curation`)
- [ ] No eval examples appear in few-shot exemplars or system prompts
- [ ] Failure analysis reads transcripts, tags modes, fixes the biggest cluster first
- [ ] New failure modes fed back into the set with a version bump, then gated (`skills/evals/regression-gates`)
