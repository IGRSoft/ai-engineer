---
name: llm-apps
description: >-
  LLM application skills navigation: RAG systems, agent-loop design (escalation
  ladder, tool contracts, stop conditions, guardrails), and provider-API
  integration (retries, streaming, caching, fallback, cost accounting). Use
  when building or debugging an LLM-backed feature, wiring retrieval over a
  corpus, designing a tool-using agent, or writing code that calls an LLM API.
---

# LLM App Skills

Retrieval, agents, and the provider plumbing underneath them.

## Stack Snapshot

| Layer | Typical pieces | Note |
|-------|----------------|------|
| Provider SDKs | `anthropic`, `openai`; `litellm`/`instructor` as optional glue | Capabilities shift per release — verify via context7 and [provider-matrix](llm-api-patterns/references/provider-matrix.md) |
| Retrieval | Embedding model + vector store + optional sparse index and reranker | Selection is workload-driven, not brand-driven — see rag-systems |
| Agent runtime | Loop with tool dispatch, budgets, and step-level tracing | Escalate single call → workflow → agent only on demonstrated need |
| Reliability | Timeouts, retry/backoff, fallback chains, circuit breakers | No provider call ships without a timeout |
| Observability | Request-level logging of prompt/model/latency/tokens; traces per agent step | Cost accounting hooks from day one |

Model IDs, context-window sizes, and per-token prices are volatile: don't
hardcode them; verify against current provider docs (context7).

## Where to Go

| I need to... | Read |
|--------------|------|
| Ground answers in our documents; fix hallucinated answers; pick a chunker, embedder, or vector store; plan a re-embed | [rag-systems](rag-systems/SKILL.md) (chunking by content type: [chunking-strategies](rag-systems/references/chunking-strategies.md)) |
| Measure retrieval quality (recall@k, MRR) | [retrieval-evaluation](rag-systems/references/retrieval-evaluation.md) |
| Decide whether a task needs an agent at all; bound a loop that overruns iterations or spend | [agent-design](agent-design/SKILL.md) |
| Fix a model that keeps picking the wrong tool | [tool-design](agent-design/references/tool-design.md) |
| Add retries, streaming, caching, batching, or fallback; review any code that calls a provider API | [llm-api-patterns](llm-api-patterns/SKILL.md) |

Every leaf and reference file with a longer summary: [_index.md](_index.md).

## Adjacent Skills

| Topic | Read |
|-------|------|
| Output parsing / JSON reliability | [structured-outputs](../prompt-engineering/structured-outputs/SKILL.md) |
| The prompt itself is the problem | [prompt-design](../prompt-engineering/prompt-design/SKILL.md) |
| Budgeting retrieved chunks and history into the window | [context-engineering](../prompt-engineering/context-engineering/SKILL.md) |
| Serving an open-weights model behind the app | [model-serving](../mlops/model-serving/SKILL.md) |
| "Is it actually better now?" — RAG faithfulness, agent success | [eval-design](../evals/eval-design/SKILL.md) / [llm-judge](../evals/llm-judge/SKILL.md) |

Owner: `ai-engineer:llm-engineer`. Architecture calls (RAG-vs-fine-tune, agent
topology) → `ai-engineer:ai-architector`; prompt-injection and tool-surface
review → `ai-engineer:ai-security-auditor`; latency/cost review →
`ai-engineer:ai-performance-engineer`.
