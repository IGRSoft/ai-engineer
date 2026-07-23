# Prompt Engineering Skills Index

Quick navigation for the `skills/prompt-engineering/` subtree. Start at
[SKILL.md](SKILL.md) for the guided entry with stack snapshot and decision
tree.

## Skills

| Skill | Use it for |
|-------|------------|
| [prompt-design/SKILL.md](prompt-design/SKILL.md) | Prompt anatomy (role → context → instructions → examples → output contract), instruction hierarchy with injection-resistant layering, few-shot design, positive framing, prompts as versioned files |
| [context-engineering/SKILL.md](context-engineering/SKILL.md) | Context hierarchy, per-segment token budgets, packing strategies (selective include, hierarchical summary, sliding window + pinned facts), compaction triggers, lost-in-the-middle placement, context observability |
| [structured-outputs/SKILL.md](structured-outputs/SKILL.md) | Extraction-mode selection (tool-call vs native structured vs prompted JSON), schema design, Pydantic validate → repair-once → fail-closed, streaming partial JSON, failure modes |

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
| Measuring whether a prompt change helped | `${CLAUDE_SKILL_DIR}/evals/eval-design/SKILL.md` |
| CI gates for prompt changes | `${CLAUDE_SKILL_DIR}/evals/regression-gates/SKILL.md` |
| Retrieval when the prompt needs knowledge | `${CLAUDE_SKILL_DIR}/llm-apps/rag-systems/SKILL.md` |
| Provider calls, caching, streaming | `${CLAUDE_SKILL_DIR}/llm-apps/llm-api-patterns/SKILL.md` |
| Fine-tuning when prompting hits its ceiling | `${CLAUDE_SKILL_DIR}/finetuning/peft-lora/SKILL.md` |
| Workflow stage participation | `${CLAUDE_SKILL_DIR}/_shared/workflow-integration/SKILL.md` |
