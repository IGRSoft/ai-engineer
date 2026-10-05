---
name: skills
description: >-
  Index of the ai-engineer skills: prompt engineering, LLM apps (RAG, agent
  loops, provider APIs), fine-tuning (data, LoRA/QLoRA, DPO, GRPO, promotion,
  export), MLOps (tracking, serving, monitoring, pipelines), and evals (eval
  sets, LLM judges, CI gates). Use when picking the skill for an AI/LLM
  engineering task.
---

# Skills Index

Routing entry for AI engineering skills. Content follows the authoring
contract in [`references/conventions.md`](references/conventions.md):
volatile facts (model IDs, prices, context sizes) are verified against current
docs rather than hardcoded, quality claims are backed by evals, and everything
works without CUDA.

## Domains

| Entry | Leaves | Focus |
|-------|--------|-------|
| [`prompt-engineering/SKILL.md`](prompt-engineering/SKILL.md) | 3 | Prompt anatomy, context-window budgets, structured outputs — the cheapest lever, exhausted before RAG or fine-tuning |
| [`llm-apps/SKILL.md`](llm-apps/SKILL.md) | 3 | RAG pipelines, bounded agent loops, provider-API integration |
| [`finetuning/SKILL.md`](finetuning/SKILL.md) | 8 | Data, LoRA/QLoRA, training optimization, DPO, GRPO/RLVR, promotion, export — once prompting and retrieval hit their ceiling |
| [`mlops/SKILL.md`](mlops/SKILL.md) | 4 | Experiment tracking, model serving, monitoring, pipelines + data versioning |
| [`evals/SKILL.md`](evals/SKILL.md) | 3 | Eval design, LLM-as-judge, CI regression gates |
| [`_shared/_index.md`](_shared/_index.md) | — | Agent routing, model selection, severity matrix |

Per-directory navigation, including every `references/` file: [_index.md](_index.md).

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
