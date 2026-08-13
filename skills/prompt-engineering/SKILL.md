---
name: prompt-engineering
description: >-
  Prompt engineering skills navigation: production prompt design (anatomy,
  instruction hierarchy, few-shot), context-window engineering (token budgets,
  packing, compaction), and reliable structured outputs (extraction modes,
  schema design, validate-repair loops). Use when writing or reviewing an
  application prompt, when responses degrade as context grows, when an LLM
  must return JSON, or when deciding whether prompting, RAG, or fine-tuning
  is the right lever for a quality problem.
---

# Prompt Engineering Skills

**Navigation and stack snapshot for production prompt work — the cheapest
quality lever, exhausted before RAG or fine-tuning**

## Stack Snapshot

| Concern | Mechanism | Note |
|---------|-----------|------|
| Prompt storage | Versioned files in git (`prompts/`), never inline strings | Diffable, reviewable, eval-gated |
| Output validation | Pydantic schema + validate → repair-once → fail-closed | Never `eval()` model output |
| Extraction mode | Tool-call vs native structured mode vs prompted JSON | Provider support shifts — verify via context7 |
| Context budgets | Per-segment token budgets with compaction triggers | Window sizes are volatile — verify per model |
| Iteration loop | Change → run versioned eval set (temperature 0) → compare to baseline | See `${CLAUDE_SKILL_DIR}/evals/eval-design/SKILL.md` |

Provider capabilities (structured-output modes, cache mechanics, context-window
sizes) move between releases — name the mechanism and verify against current
provider docs (context7) before relying on a specific limit.

## Skill Selection Guide

| I need to... | Use this skill |
|--------------|----------------|
| Write or restructure a system/user prompt for an LLM feature | [prompt-design/SKILL.md](prompt-design/SKILL.md) |
| Layer untrusted input into a prompt without losing control | [prompt-design/SKILL.md](prompt-design/SKILL.md) (instruction hierarchy) |
| Pick a reusable prompt pattern / Claude-specific technique | [prompt-design/references/](prompt-design/references/prompt-patterns.md) |
| Decide what to include, summarize, or drop from the window | [context-engineering/SKILL.md](context-engineering/SKILL.md) |
| Fix responses that degrade as conversations grow | [context-engineering/SKILL.md](context-engineering/SKILL.md) |
| Get reliable JSON / design an extraction or classification schema | [structured-outputs/SKILL.md](structured-outputs/SKILL.md) |
| Copy a worked schema example | [structured-outputs/references/schema-patterns.md](structured-outputs/references/schema-patterns.md) |

## Decision Tree

```
Prompt task?
├── Writing/restructuring a prompt → prompt-design/SKILL.md
│   ├── Reusable pattern catalog → prompt-design/references/prompt-patterns.md
│   └── Claude-specific techniques → prompt-design/references/claude-prompting.md
├── What goes in the window / budgets / compaction → context-engineering/SKILL.md
├── Model must return JSON or feed downstream code → structured-outputs/SKILL.md
│   └── Worked schema examples → structured-outputs/references/schema-patterns.md
├── Prompt cannot fix it → escalate:
│   ├── Missing knowledge → ${CLAUDE_SKILL_DIR}/llm-apps/rag-systems/SKILL.md
│   ├── Style/format deeply wrong → ${CLAUDE_SKILL_DIR}/finetuning/peft-lora/SKILL.md
│   └── Which lever? → ai-engineer:ai-architector
└── Did the prompt change actually help? → ${CLAUDE_SKILL_DIR}/evals/eval-design/SKILL.md
```

## File Overview

| File | Purpose |
|------|---------|
| [_index.md](_index.md) | Full navigation for the prompt-engineering/ subtree |
| [prompt-design/SKILL.md](prompt-design/SKILL.md) | Prompt anatomy, instruction hierarchy, few-shot design, versioned prompt files |
| [prompt-design/references/prompt-patterns.md](prompt-design/references/prompt-patterns.md) | Reusable prompt pattern catalog |
| [prompt-design/references/claude-prompting.md](prompt-design/references/claude-prompting.md) | Claude-specific prompting techniques |
| [context-engineering/SKILL.md](context-engineering/SKILL.md) | Context hierarchy, token budgets, packing, compaction, observability |
| [context-engineering/references/window-management.md](context-engineering/references/window-management.md) | Deep dive: segment budgets, packing, compaction, hygiene, observability |
| [structured-outputs/SKILL.md](structured-outputs/SKILL.md) | Extraction modes, schema design, validate → repair-once → fail-closed |
| [structured-outputs/references/schema-patterns.md](structured-outputs/references/schema-patterns.md) | Worked schema examples |

## Related Skills

- [eval-design](${CLAUDE_SKILL_DIR}/evals/eval-design/SKILL.md) / [regression-gates](${CLAUDE_SKILL_DIR}/evals/regression-gates/SKILL.md) — every prompt change ships behind an eval, then a CI gate
- [llm-api-patterns](${CLAUDE_SKILL_DIR}/llm-apps/llm-api-patterns/SKILL.md) — calling the provider that runs the prompt (caching interacts with prompt structure)
- [rag-systems](${CLAUDE_SKILL_DIR}/llm-apps/rag-systems/SKILL.md) — when the prompt needs retrieved knowledge instead of more instructions
- [CORPFLOW.md](../../CORPFLOW.md) — stage participation, AI Build Evidence

**Owning agent:** `ai-engineer:ai-prompt-engineer` (product/application prompts
only — Claude Code meta-prompts route to `corpflow:prompt-engineer`).
Prompt-vs-RAG-vs-fine-tune escalation decisions → `ai-engineer:ai-architector`;
injection-surface review → `ai-engineer:ai-security-auditor`.
