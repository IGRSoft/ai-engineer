---
name: llm-apps
description: >-
  LLM application skills navigation: RAG systems
  (chunk/embed/retrieve/rerank/ground), agent-loop design (escalation ladder,
  tool contracts, stop conditions, guardrails), and production provider-API
  integration (retries, streaming, caching, fallback, cost accounting).
  Use when building or debugging an LLM-backed feature, wiring retrieval over
  a corpus, designing a tool-using agent, or writing any code that calls an
  LLM provider API.
---

# LLM App Skills

**Navigation and stack snapshot for building LLM-backed features — retrieval,
agents, and the provider plumbing underneath them**

## Stack Snapshot

| Layer | Typical pieces | Note |
|-------|----------------|------|
| Provider SDKs | `anthropic`, `openai`; `litellm`/`instructor` as optional glue | Capabilities shift per release — verify via context7 and [llm-api-patterns/references/provider-matrix.md](llm-api-patterns/references/provider-matrix.md) |
| Retrieval | Embedding model + vector store + optional sparse index and reranker | Selection is workload-driven, not brand-driven — see rag-systems |
| Agent runtime | Loop with tool dispatch, budgets, and step-level tracing | Escalate single call → workflow → agent only on demonstrated need |
| Reliability | Timeouts, retry/backoff, fallback chains, circuit breakers | No provider call ships without a timeout |
| Observability | Request-level logging of prompt/model/latency/tokens; traces per agent step | Cost accounting hooks from day one |

Model IDs, context-window sizes, and per-token prices are volatile — never
hardcode them; name the mechanism and verify against current provider docs
(context7).

## Skill Selection Guide

| I need to... | Use this skill |
|--------------|----------------|
| Ground answers in our documents / fix hallucinated answers | [rag-systems/SKILL.md](rag-systems/SKILL.md) |
| Pick a chunker, embedder, or vector store; plan a re-embed | [rag-systems/SKILL.md](rag-systems/SKILL.md) |
| Measure retrieval quality (recall@k, MRR) | [rag-systems/references/retrieval-evaluation.md](rag-systems/references/retrieval-evaluation.md) |
| Decide whether a task needs an agent at all | [agent-design/SKILL.md](agent-design/SKILL.md) (escalation ladder) |
| Bound a loop that overruns iterations or spend | [agent-design/SKILL.md](agent-design/SKILL.md) |
| Fix a model that keeps picking the wrong tool | [agent-design/references/tool-design.md](agent-design/references/tool-design.md) |
| Add retries, streaming, caching, batching, or fallback | [llm-api-patterns/SKILL.md](llm-api-patterns/SKILL.md) |
| Review any code that calls a provider API | [llm-api-patterns/SKILL.md](llm-api-patterns/SKILL.md) |

## Decision Tree

```
LLM app task?
├── Answers must come from documents → rag-systems/SKILL.md
│   ├── Chunking by content type → rag-systems/references/chunking-strategies.md
│   └── Is retrieval the weak link? → rag-systems/references/retrieval-evaluation.md
├── Model must act (tools, multi-step) → agent-design/SKILL.md
│   └── Tool contracts / wrong-tool loops → agent-design/references/tool-design.md
├── Any code calling a provider API → llm-api-patterns/SKILL.md
│   └── Capability dimensions across providers → llm-api-patterns/references/provider-matrix.md
├── Output parsing / JSON reliability → ${CLAUDE_SKILL_DIR}/prompt-engineering/structured-outputs/SKILL.md
├── The prompt itself is the problem → ${CLAUDE_SKILL_DIR}/prompt-engineering/prompt-design/SKILL.md
├── Serving an open-weights model behind the app → ${CLAUDE_SKILL_DIR}/mlops/model-serving/SKILL.md
└── "Is it actually better now?" → ${CLAUDE_SKILL_DIR}/evals/eval-design/SKILL.md
```

## File Overview

| File | Purpose |
|------|---------|
| [_index.md](_index.md) | Full navigation for the llm-apps/ subtree |
| [rag-systems/SKILL.md](rag-systems/SKILL.md) | RAG pipeline end-to-end: chunking, retrieval, reranking, grounding, index lifecycle |
| [rag-systems/references/chunking-strategies.md](rag-systems/references/chunking-strategies.md) | Chunking deep dive by content type |
| [rag-systems/references/retrieval-evaluation.md](rag-systems/references/retrieval-evaluation.md) | Retrieval metrics and evaluation workflow |
| [agent-design/SKILL.md](agent-design/SKILL.md) | Agent loops: escalation ladder, budgets, guardrails, tracing |
| [agent-design/references/tool-design.md](agent-design/references/tool-design.md) | Tool contract deep dive |
| [llm-api-patterns/SKILL.md](llm-api-patterns/SKILL.md) | Provider-API reliability: retries, streaming, caching, fallback, cost hooks |
| [llm-api-patterns/references/provider-matrix.md](llm-api-patterns/references/provider-matrix.md) | Provider capability dimensions (not snapshots) |

## Related Skills

- [structured-outputs](${CLAUDE_SKILL_DIR}/prompt-engineering/structured-outputs/SKILL.md) — the output side of every RAG/agent call
- [context-engineering](${CLAUDE_SKILL_DIR}/prompt-engineering/context-engineering/SKILL.md) — budgeting retrieved chunks and history into the window
- [model-serving](${CLAUDE_SKILL_DIR}/mlops/model-serving/SKILL.md) — self-hosted endpoints behind the same app code
- [eval-design](${CLAUDE_SKILL_DIR}/evals/eval-design/SKILL.md) / [llm-judge](${CLAUDE_SKILL_DIR}/evals/llm-judge/SKILL.md) — measuring RAG faithfulness and agent success

**Owning agent:** `ai-engineer:llm-engineer`. Architecture calls
(RAG-vs-fine-tune, agent topology) → `ai-engineer:ai-architector`;
prompt-injection and tool-surface review → `ai-engineer:ai-security-auditor`;
latency/cost review → `ai-engineer:ai-performance-engineer`.
