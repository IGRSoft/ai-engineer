---
name: eval-design
description: >-
  Design evals that predict production quality: task-grounded eval sets harvested
  from real traffic, the assertion→metric→judge→human hierarchy, metric selection
  by task type, paired prompt A/B comparison, set sizing and statistical honesty,
  eval-set versioning and hygiene, and failure analysis. Use when building or
  expanding an eval set, choosing metrics, comparing two prompts or models,
  triaging a metric drop, or before shipping a change because it "looks better".
---

# Eval Design

An eval set is the test suite of an LLM feature: what to measure, on which data, and how to compare honestly. Every prompt, model, or retrieval change ships with an eval run; the CI gate is `skills/evals/regression-gates`. Harnesses are built by `ai-engineer:ai-test-generator`; prompt A/B consumers route through `ai-engineer:ai-prompt-engineer`.

**Elsewhere:**

- Writing or debugging an LLM judge (rubrics, biases, calibration) → `skills/evals/llm-judge`
- Wiring evals into CI (thresholds, baselines, flake policy) → `skills/evals/regression-gates`
- Retrieval-metric depth (recall@k, MRR, nDCG) → `skills/llm-apps/rag-systems/references/retrieval-evaluation.md`
- Training-data curation and contamination scrubbing → `skills/finetuning/dataset-curation`

## The Eval Hierarchy

Four tiers — assertions, programmatic metrics, LLM judge, human review — with cost per example rising as you climb. Use the cheapest tier that measures the property; escalate only when the lower tier can't express the check. A healthy suite is a pyramid: many assertions, a solid programmatic layer, a few judged dimensions, a thin human panel. Tier diagram with cost anchors: `references/eval-methodology.md`.

## Deep Dives

Read `references/eval-methodology.md` when building or versioning an eval set, choosing metrics by task type, running a paired prompt A/B, sizing N and testing significance, checking set hygiene, or doing failure analysis.

## Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| Imagined eval set ("what users might ask") | Measures the author's imagination, not production | Harvest from traffic and failure reports; synthetic only for taxonomy gaps, tagged |
| Deferring evals until after launch | You iterate blind through the riskiest period | Start with 30 harvested examples now; launch traffic is the harvest source |
| "Subjective, so unmeasurable" | Nothing gets measured | Decompose: format, groundedness, must-mentions are assertions; the subjective core gets a calibrated judge (`skills/evals/llm-judge`) |
| Judge-first eval design | Pays judge cost and nondeterminism for properties an assertion checks free | Climb the hierarchy from tier 1 |
| Metric reported without eval-set version | Unreproducible; deltas across set versions are meaningless | Version the set; print `name@version` next to every metric |
| Whole-blob equality for structured output | One wrong field zeroes the example; no signal about what to fix | Field-level precision/recall + tier-1 schema assertion |
| Shipping on eyeballed samples or small-N deltas | Regressions hide in the tail; +5% at N=20 is one flipped example | Paired A/B on a pinned set sized to the stakes; sign test on discordant pairs |
| Changing prompt and model in one comparison | Delta unattributable | One variable per A/B; run a 2-step ladder if both must change |
| Static eval set for months | Team overfits it; production drifts away | Refresh cadence + hidden holdout slice |
| Mean of ordinal judge scores as the verdict | 3.8 vs 3.9 on a 1–5 scale is noise | Win/loss counts + sign test; distribution over levels |

## Verification

- [ ] Every metric is reported with its eval-set version and run config (model, temperature/seed)
- [ ] Eval set is version-controlled with a manifest and per-example provenance (traffic / failure / synthetic)
- [ ] Examples carry taxonomy tags; set size matches the decision-stakes table
- [ ] Metrics match the task-type table (field-level for extraction; retrieval and generation split for RAG)
- [ ] A/B runs are paired, single-variable, deterministic (temp 0/seeded), sign-tested on discordant pairs
- [ ] Noise floor measured by rerunning one variant; temperature 0 alone doesn't make one run enough
- [ ] Contamination scan run against any fine-tuning data (`skills/finetuning/dataset-curation`)
- [ ] No eval examples appear in few-shot exemplars or system prompts
- [ ] Failure analysis reads transcripts, tags modes, fixes the biggest cluster first
- [ ] New failure modes fed back into the set with a version bump, then gated (`skills/evals/regression-gates`)
