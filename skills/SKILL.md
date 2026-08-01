---
name: skills
description: >-
  Comprehensive AI engineering skills across five domains: prompt engineering,
  LLM applications, fine-tuning, MLOps, and evals. Use when building LLM
  applications (RAG, agent loops, provider APIs), engineering prompts, context
  windows, or structured outputs, fine-tuning models (dataset curation,
  LoRA/QLoRA, DPO), setting up MLOps (experiment tracking, model serving,
  monitoring, ML pipelines), or designing evals (eval sets, LLM judges, CI
  regression gates).
---

# Skills Index

## Overview

This collection provides guidance for AI engineering across five domains —
prompt engineering, LLM applications, fine-tuning, MLOps, and evals — plus the
shared routing, model-selection, severity, and workflow references that tie
them into the company-workflow pipeline. The emphasis is on **mechanisms over
snapshots**: volatile facts (model IDs, prices, context-window sizes, library
minor versions) are never hardcoded — skills name the lever and say "verify
against current provider docs (context7)". Every quality claim is backed by an
eval, not vibes, and everything degrades gracefully without CUDA.

## Quick Navigation

| Domain | Entry | Skills | Focus |
|--------|-------|--------|-------|
| [Prompt Engineering](#prompt-engineering) | [`prompt-engineering/SKILL.md`](prompt-engineering/SKILL.md) | 1 + 3 leaves | Prompt anatomy, context-window budgets, reliable structured outputs |
| [LLM Apps](#llm-apps) | [`llm-apps/SKILL.md`](llm-apps/SKILL.md) | 1 + 3 leaves | RAG pipelines, bounded agent loops, production provider-API integration |
| [Fine-Tuning](#fine-tuning) | [`finetuning/SKILL.md`](finetuning/SKILL.md) | 1 + 4 leaves | Dataset curation, LoRA/QLoRA, training optimization, preference tuning (DPO) |
| [MLOps](#mlops) | [`mlops/SKILL.md`](mlops/SKILL.md) | 1 + 4 leaves | Experiment tracking, model serving, monitoring, pipelines + data versioning |
| [Evals](#evals) | [`evals/SKILL.md`](evals/SKILL.md) | 1 + 3 leaves | Eval design, LLM-as-judge, CI regression gates |
| [Shared](#shared) | [`_shared/_index.md`](_shared/_index.md) | 1 + references | Workflow integration, agent routing, model selection, severity |

**Total: 24 SKILL.md across 5 domains + _shared, plus shared references.**

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
| A metric nobody can trace back to the run that produced it | [mlops/experiment-tracking/SKILL.md](mlops/experiment-tracking/SKILL.md) |
| Deploying an open-weights or fine-tuned model (vLLM/TGI/Ollama-class) | [mlops/model-serving/SKILL.md](mlops/model-serving/SKILL.md) |
| Watching production quality, drift, and spend | [mlops/model-monitoring/SKILL.md](mlops/model-monitoring/SKILL.md) |
| Versioning datasets, structuring pipelines, CI/CD for models | [mlops/ml-pipelines/SKILL.md](mlops/ml-pipelines/SKILL.md) |
| Building an eval set / comparing two prompts or models honestly | [evals/eval-design/SKILL.md](evals/eval-design/SKILL.md) |
| Grading tone or faithfulness with a judge that agrees with humans | [evals/llm-judge/SKILL.md](evals/llm-judge/SKILL.md) |
| A CI gate for prompt changes so quality cannot silently regress | [evals/regression-gates/SKILL.md](evals/regression-gates/SKILL.md) |
| Routing a task, file, or repo to the right ai-engineer agent | [_shared/framework-detection.md](_shared/framework-detection.md) |
| Picking model/effort for a delegation | [_shared/model-selection.md](_shared/model-selection.md) |
| Participating in a company-workflow workflow stage | [_shared/workflow-integration/SKILL.md](_shared/workflow-integration/SKILL.md) |

---

## Prompt Engineering

Production prompt design, context-window management, and machine-readable
output — the cheapest quality lever, exhausted before RAG or fine-tuning.
Leaves: prompt-design, context-engineering, structured-outputs.
Full leaf table: [prompt-engineering/SKILL.md](prompt-engineering/SKILL.md).

## LLM Apps

Building LLM-backed features: RAG pipelines, bounded agent loops, and the
provider-API plumbing underneath them. Leaves: rag-systems, agent-design,
llm-api-patterns. Full leaf table: [llm-apps/SKILL.md](llm-apps/SKILL.md).

## Fine-Tuning

Changing model weights when prompting and retrieval have hit their ceiling —
data first, adapters second, preferences last. Leaves: dataset-curation,
peft-lora, training-optimization, preference-tuning.
Full leaf table: [finetuning/SKILL.md](finetuning/SKILL.md).

## MLOps

Running models as software: tracked experiments, hardened serving, monitored
production, versioned pipelines. Leaves: experiment-tracking, model-serving,
model-monitoring, ml-pipelines. Full leaf table: [mlops/SKILL.md](mlops/SKILL.md).

## Evals

Measurement discipline for everything above — no prompt, model, or retrieval
change ships without one. Leaves: eval-design, llm-judge, regression-gates.
Full leaf table: [evals/SKILL.md](evals/SKILL.md).

## Shared

Cross-cutting references used by every agent, command, and skill:
workflow-integration (company-workflow 11-stage contract), framework-detection
(agent routing), model-selection, severity-matrix.
Full file table: [_shared/_index.md](_shared/_index.md).

---

## Conventions

- **uv-first Python.** Examples use `uv run` / `uv add`, ruff-clean and
  type-hinted; versions live in `pyproject.toml`/`uv.lock`, never in prose.
- **Determinism.** Eval examples pin eval-set versions and run at temperature 0
  with fixed seeds; training examples are smoke-scale (capped `max_steps`,
  subsampled data) with the full run as a documented launch plan.
- **No pricing or model-ID snapshots.** Volatile facts (model IDs, prices,
  context-window sizes, library minors) are named as mechanisms with "verify
  against current provider docs (context7)" — cost formulas and levers are
  encouraged, cost tables are forbidden.
- **GPU-optional.** Content degrades gracefully without CUDA: MPS/CPU notes
  where relevant; absent `nvidia-smi` means reduced depth, never a hard
  failure.
- **Language depth delegates.** Pure-Python questions (typing, packaging,
  concurrency, pytest mechanics) route to `system-developer:python-skills` —
  they are not re-taught here.
- **Agents plugin-qualified.** Agents are always referenced as
  `ai-engineer:<name>` (e.g. `ai-engineer:llm-engineer`); ownership per domain
  is mapped in [_shared/framework-detection.md](_shared/framework-detection.md).

## Related Documentation

All shared references are tabulated in [_shared/_index.md](_shared/_index.md);
the full per-directory navigation index is [_index.md](_index.md).
