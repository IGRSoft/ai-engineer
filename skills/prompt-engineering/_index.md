# Prompt Engineering Skills Index

Quick navigation for the `skills/prompt-engineering/` subtree. Guided entry
with the stack snapshot: [SKILL.md](SKILL.md).

## Skills

| Skill | Use it for |
|-------|------------|
| [prompt-design/SKILL.md](prompt-design/SKILL.md) | Five-segment prompt anatomy, instruction hierarchy with delimited untrusted input, few-shot design, positive framing, prompts as versioned files |
| [context-engineering/SKILL.md](context-engineering/SKILL.md) | Segment hierarchy and token budgets, packing, compaction triggers, lost-in-the-middle placement, retrieved-context hygiene, per-request context manifests |
| [structured-outputs/SKILL.md](structured-outputs/SKILL.md) | Extraction-mode choice (tool-call, native structured, prompted JSON), flat enum-closed schemas, Pydantic validate → repair-once → fail-closed, streaming partial JSON, parse failures |

## References

| File | Use it for |
|------|------------|
| [prompt-design/references/prompt-patterns.md](prompt-design/references/prompt-patterns.md) | Reusable prompt pattern catalog |
| [prompt-design/references/claude-prompting.md](prompt-design/references/claude-prompting.md) | Claude-specific prompting techniques |
| [context-engineering/references/window-management.md](context-engineering/references/window-management.md) | Segment table, token budgeting, packing, compaction, hygiene, observability |
| [structured-outputs/references/schema-patterns.md](structured-outputs/references/schema-patterns.md) | Worked schema examples for extraction and classification |

## Cross-Tree

| Topic | Location |
|-------|----------|
| Measuring whether a prompt change helped | [evals/eval-design/SKILL.md](../evals/eval-design/SKILL.md) |
| CI gates for prompt changes | [evals/regression-gates/SKILL.md](../evals/regression-gates/SKILL.md) |
| Retrieval when the prompt needs knowledge | [llm-apps/rag-systems/SKILL.md](../llm-apps/rag-systems/SKILL.md) |
| Provider calls, caching, streaming | [llm-apps/llm-api-patterns/SKILL.md](../llm-apps/llm-api-patterns/SKILL.md) |
| Fine-tuning when prompting hits its ceiling | [finetuning/peft-lora/SKILL.md](../finetuning/peft-lora/SKILL.md) |
