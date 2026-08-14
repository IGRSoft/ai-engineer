# LLM Apps Skills Index

Quick navigation for the `skills/llm-apps/` subtree. Start at
[SKILL.md](SKILL.md) for the guided entry with stack snapshot and decision
tree.

## Skills

| Skill | Use it for |
|-------|------------|
| [rag-systems/SKILL.md](rag-systems/SKILL.md) | Ingest→chunk→embed→index→retrieve→rerank→ground pipeline, chunking by content type, embedder/vector-store selection, hybrid dense+sparse retrieval, grounded answers with citations and refusal rules, index lifecycle |
| [agent-design/SKILL.md](agent-design/SKILL.md) | Escalation ladder (single call → workflow → agent → multi-agent), loop anatomy, stop conditions and budgets, tool contracts, memory patterns, guardrails with human confirmation, failure handling, step-level tracing |
| [llm-api-patterns/SKILL.md](llm-api-patterns/SKILL.md) | Timeout/retry/backoff discipline, rate-limit handling, streaming with mid-stream recovery, prompt caching, batch APIs, fallback chains with circuit breakers, cost accounting, observability, secrets hygiene |

## References

| File | Use it for |
|------|------------|
| [rag-systems/references/chunking-strategies.md](rag-systems/references/chunking-strategies.md) | Chunking deep dive by content type |
| [rag-systems/references/retrieval-evaluation.md](rag-systems/references/retrieval-evaluation.md) | Retrieval metrics (recall@k, MRR) and evaluation workflow |
| [rag-systems/references/embedding-and-index-tuning.md](rag-systems/references/embedding-and-index-tuning.md) | ANN index parameters (HNSW `M`/`efSearch`, IVF `nlist`/`nprobe`), index memory estimation, score normalization, RRF vs linear fusion |
| [agent-design/references/tool-design.md](agent-design/references/tool-design.md) | Tool contract deep dive: naming, parameters, errors, wrong-tool loops |
| [llm-api-patterns/references/provider-matrix.md](llm-api-patterns/references/provider-matrix.md) | Provider capability dimensions to check (not snapshots) |

## Cross-Tree

| Topic | Location |
|-------|----------|
| Reliable JSON from RAG/agent calls | `${CLAUDE_SKILL_DIR}/prompt-engineering/structured-outputs/SKILL.md` |
| Budgeting retrieved chunks into the window | `${CLAUDE_SKILL_DIR}/prompt-engineering/context-engineering/SKILL.md` |
| The prompt behind the feature | `${CLAUDE_SKILL_DIR}/prompt-engineering/prompt-design/SKILL.md` |
| Self-hosting the model behind the app | `${CLAUDE_SKILL_DIR}/mlops/model-serving/SKILL.md` |
| Measuring RAG faithfulness / agent success | `${CLAUDE_SKILL_DIR}/evals/eval-design/SKILL.md` |
| Workflow stage participation | `CORPFLOW.md` |
