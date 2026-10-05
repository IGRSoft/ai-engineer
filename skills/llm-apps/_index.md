# LLM Apps Skills Index

Quick navigation for the `skills/llm-apps/` subtree. Guided entry with the
stack snapshot: [SKILL.md](SKILL.md).

## Skills

| Skill | Use it for |
|-------|------------|
| [rag-systems/SKILL.md](rag-systems/SKILL.md) | Ingest→chunk→embed→index→retrieve→rerank→ground pipeline, chunking by content type, embedder and vector-store choice, hybrid retrieval, reranking, grounded answers with citations and refusal, index lifecycle (sync, deletes, re-embed) |
| [agent-design/SKILL.md](agent-design/SKILL.md) | Escalation ladder (single call → workflow → agent → multi-agent), loop anatomy, stop conditions and budgets, tool contracts, memory patterns, guardrails with human confirmation, failure handling, step-level tracing |
| [llm-api-patterns/SKILL.md](llm-api-patterns/SKILL.md) | Timeouts and retry/backoff, rate limits, streaming with TTFT and mid-stream recovery, prompt caching, batch APIs, fallback chains with circuit breakers, cost accounting, secrets |

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
| Reliable JSON from RAG/agent calls | [prompt-engineering/structured-outputs/SKILL.md](../prompt-engineering/structured-outputs/SKILL.md) |
| Budgeting retrieved chunks into the window | [prompt-engineering/context-engineering/SKILL.md](../prompt-engineering/context-engineering/SKILL.md) |
| The prompt behind the feature | [prompt-engineering/prompt-design/SKILL.md](../prompt-engineering/prompt-design/SKILL.md) |
| Self-hosting the model behind the app | [mlops/model-serving/SKILL.md](../mlops/model-serving/SKILL.md) |
| Measuring RAG faithfulness / agent success | [evals/eval-design/SKILL.md](../evals/eval-design/SKILL.md) |
