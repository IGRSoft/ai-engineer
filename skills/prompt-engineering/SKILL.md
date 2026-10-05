---
name: prompt-engineering
description: >-
  Prompt engineering skills navigation: prompt design (anatomy, instruction
  hierarchy, few-shot), context-window engineering (budgets, packing,
  compaction), and structured outputs (extraction modes, schemas,
  validate-repair). Use when writing or reviewing an application prompt, when
  responses degrade as context grows, when an LLM must return JSON, or when
  choosing between prompting, RAG, and fine-tuning.
---

# Prompt Engineering Skills

The cheapest quality lever: exhaust it before RAG or fine-tuning.

## Stack Snapshot

| Concern | Mechanism | Note |
|---------|-----------|------|
| Prompt storage | Versioned files in git (`prompts/`), not inline strings | Diffable, reviewable, eval-gated |
| Output validation | Pydantic schema + validate → repair-once → fail-closed | Never `eval()` model output |
| Extraction mode | Tool-call vs native structured mode vs prompted JSON | Provider support shifts — verify via context7 |
| Context budgets | Per-segment token budgets with compaction triggers | Window sizes are volatile — verify per model |
| Iteration loop | Change → run versioned eval set → compare to baseline | See [eval-design](../evals/eval-design/SKILL.md) |

Structured-output modes, cache mechanics, and context-window sizes change
between releases: name the mechanism and verify against current provider docs
(context7) before relying on a specific limit.

## Where to Go

| I need to... | Read |
|--------------|------|
| Write or restructure a system/user prompt; layer untrusted input without losing control | [prompt-design](prompt-design/SKILL.md) |
| Pick a reusable prompt pattern or Claude-specific technique | [prompt-patterns](prompt-design/references/prompt-patterns.md) / [claude-prompting](prompt-design/references/claude-prompting.md) |
| Decide what to include, summarize, or drop from the window; fix responses that degrade as sessions grow | [context-engineering](context-engineering/SKILL.md) |
| Get reliable JSON; design an extraction or classification schema | [structured-outputs](structured-outputs/SKILL.md) (worked examples: [schema-patterns](structured-outputs/references/schema-patterns.md)) |

Every leaf and reference file with a longer summary: [_index.md](_index.md).

## Adjacent Skills

| Topic | Read |
|-------|------|
| Did the prompt change help? Gate it in CI | [eval-design](../evals/eval-design/SKILL.md) / [regression-gates](../evals/regression-gates/SKILL.md) |
| Prompt lacks knowledge, not instructions | [rag-systems](../llm-apps/rag-systems/SKILL.md) |
| Style or format still wrong after prompting | [peft-lora](../finetuning/peft-lora/SKILL.md) |
| Calling the provider (caching depends on prompt structure) | [llm-api-patterns](../llm-apps/llm-api-patterns/SKILL.md) |

Owner: `ai-engineer:ai-prompt-engineer` (product prompts only; Claude Code
meta-prompts go to the orchestrator's meta-prompt engineer). Prompt vs RAG vs
fine-tune → `ai-engineer:ai-architector`; injection-surface review →
`ai-engineer:ai-security-auditor`.
