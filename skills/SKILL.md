---
name: skills
description: >-
  Comprehensive AI engineering skills across five domains: prompt engineering,
  LLM applications, fine-tuning, MLOps, and evals. Use when building LLM
  applications (RAG, agent loops, provider APIs), engineering prompts, context
  windows, or structured outputs, fine-tuning models (dataset curation,
  LoRA/QLoRA, DPO, GRPO/RLVR, checkpoint promotion, quantized export), setting
  up MLOps (experiment tracking, model serving, monitoring, ML pipelines), or
  designing evals (eval sets, LLM judges, CI regression gates).
---

# Skills Index

## Overview

This collection provides guidance for AI engineering across five domains —
prompt engineering, LLM applications, fine-tuning, MLOps, and evals — plus the
shared routing, model-selection, severity, and workflow references that tie
them into an orchestrated pipeline. The emphasis is on **mechanisms over
snapshots**: volatile facts (model IDs, prices, context-window sizes, library
minor versions) are never hardcoded — skills name the lever and say "verify
against current provider docs (context7)". Every quality claim is backed by an
eval, not vibes, and everything degrades gracefully without CUDA.

## Quick Navigation

| Domain | Entry | Skills | Focus |
|--------|-------|--------|-------|
| [Prompt Engineering](#prompt-engineering) | [`prompt-engineering/SKILL.md`](prompt-engineering/SKILL.md) | 1 + 3 leaves | Prompt anatomy, context-window budgets, reliable structured outputs |
| [LLM Apps](#llm-apps) | [`llm-apps/SKILL.md`](llm-apps/SKILL.md) | 1 + 3 leaves | RAG pipelines, bounded agent loops, production provider-API integration |
| [Fine-Tuning](#fine-tuning) | [`finetuning/SKILL.md`](finetuning/SKILL.md) | 1 + 8 leaves | Data (raw + graded), LoRA/QLoRA, training optimization, DPO, GRPO/RLVR, promotion, export |
| [MLOps](#mlops) | [`mlops/SKILL.md`](mlops/SKILL.md) | 1 + 4 leaves | Experiment tracking, model serving, monitoring, pipelines + data versioning |
| [Evals](#evals) | [`evals/SKILL.md`](evals/SKILL.md) | 1 + 3 leaves | Eval design, LLM-as-judge, CI regression gates |
| [Shared](#shared) | [`_shared/_index.md`](_shared/_index.md) | 1 + references | Workflow integration, agent routing, model selection, severity |

**Total: 28 SKILL.md across 5 domains + _shared, plus shared references.**

## I need help with...

| Task | Go to |
|------|-------|
| Making RAG answers accurate / stop hallucinating past the corpus | [llm-apps/rag-systems/SKILL.md](llm-apps/rag-systems/SKILL.md) |
| A prompt that returns broken JSON or unparseable output | [prompt-engineering/structured-outputs/SKILL.md](prompt-engineering/structured-outputs/SKILL.md) |
| Writing or restructuring a system prompt for an LLM feature | [prompt-engineering/prompt-design/SKILL.md](prompt-engineering/prompt-design/SKILL.md) |
| Responses degrading as conversations grow / token spend climbing | [prompt-engineering/context-engineering/SKILL.md](prompt-engineering/context-engineering/SKILL.md) |
| Deciding whether a task needs an agent; bounding a tool-using loop | [llm-apps/agent-design/SKILL.md](llm-apps/agent-design/SKILL.md) |
| Retries, streaming, rate limits, caching, provider fallback | [llm-apps/llm-api-patterns/SKILL.md](llm-apps/llm-api-patterns/SKILL.md) |
| Fine-tuning on our support tickets (or any raw corpus) | [finetuning/dataset-curation/SKILL.md](finetuning/dataset-curation/SKILL.md) then [finetuning/peft-lora/SKILL.md](finetuning/peft-lora/SKILL.md) |
| Picking LoRA r/alpha, fitting a fine-tune into limited VRAM | [finetuning/peft-lora/SKILL.md](finetuning/peft-lora/SKILL.md) |
| A training run that OOMs, crawls, or shows a flat/spiky loss curve | [finetuning/training-optimization/SKILL.md](finetuning/training-optimization/SKILL.md) |
| SFT output close-but-not-quite; DPO vs RLHF; longer/sycophantic outputs | [finetuning/preference-tuning/SKILL.md](finetuning/preference-tuning/SKILL.md) |
| Training where a program checks the answer (tests, schemas, math) | [finetuning/grpo-rlvr-training/SKILL.md](finetuning/grpo-rlvr-training/SKILL.md) |
| Turning graded eval traces into training data | [finetuning/trace-to-training-data/SKILL.md](finetuning/trace-to-training-data/SKILL.md) |
| Deciding whether a checkpoint ships; capability drift | [finetuning/checkpoint-promotion/SKILL.md](finetuning/checkpoint-promotion/SKILL.md) |
| Exporting a promoted model for a target runtime | [finetuning/quantized-export/SKILL.md](finetuning/quantized-export/SKILL.md) |
| A metric nobody can trace back to the run that produced it | [mlops/experiment-tracking/SKILL.md](mlops/experiment-tracking/SKILL.md) |
| Deploying an open-weights or fine-tuned model (vLLM/TGI/Ollama-class) | [mlops/model-serving/SKILL.md](mlops/model-serving/SKILL.md) |
| Watching production quality, drift, and spend | [mlops/model-monitoring/SKILL.md](mlops/model-monitoring/SKILL.md) |
| Versioning datasets, structuring pipelines, CI/CD for models | [mlops/ml-pipelines/SKILL.md](mlops/ml-pipelines/SKILL.md) |
| Building an eval set / comparing two prompts or models honestly | [evals/eval-design/SKILL.md](evals/eval-design/SKILL.md) |
| Grading tone or faithfulness with a judge that agrees with humans | [evals/llm-judge/SKILL.md](evals/llm-judge/SKILL.md) |
| A CI gate for prompt changes so quality cannot silently regress | [evals/regression-gates/SKILL.md](evals/regression-gates/SKILL.md) |
| Routing a task, file, or repo to the right ai-engineer agent | [_shared/framework-detection.md](_shared/framework-detection.md) |
| Picking model/effort for a delegation | [_shared/model-selection.md](_shared/model-selection.md) |

---

## Prompt Engineering

The cheapest quality lever, exhausted before RAG or fine-tuning.
Leaves: [prompt-engineering/SKILL.md](prompt-engineering/SKILL.md).

## LLM Apps

Building LLM-backed features and the provider plumbing under them.
Leaves: [llm-apps/SKILL.md](llm-apps/SKILL.md).

## Fine-Tuning

Changing model weights once prompting and retrieval hit their ceiling — data
first, adapters second, preference or verifiable-reward signal next, then the
lifecycle tail (promote → export) that decides whether the weights ship and in
what shape. Leaves: [finetuning/SKILL.md](finetuning/SKILL.md).

## MLOps

Running models as software: tracked, served, monitored, rebuilt from pipelines.
Leaves: [mlops/SKILL.md](mlops/SKILL.md).

## Evals

Measurement discipline for everything above — nothing ships without one.
Leaves: [evals/SKILL.md](evals/SKILL.md).

## Shared

Cross-cutting references used by every agent, command, and skill.
Files: [_shared/_index.md](_shared/_index.md).

---

## Conventions

Authoring contract for skill content — uv-first Python, determinism in eval and
training examples, no pricing or model-ID snapshots, GPU-optional depth,
language depth delegated to `system-developer:python-skills`, and
plugin-qualified agent names: [`references/conventions.md`](references/conventions.md).

## Related Documentation

All shared references are tabulated in [_shared/_index.md](_shared/_index.md);
the full per-directory navigation index is [_index.md](_index.md).
