---
name: context-engineering
description: >-
  Decide what enters an LLM app's context window on each call: segment
  hierarchy and token budgets, packing, compaction triggers, lost-in-the-middle
  placement, retrieved-context hygiene, and per-request context manifests.
  Use when responses degrade as sessions grow, retrieval floods the window,
  token spend climbs per request, or a failure can't be traced to what the
  model saw.
---

# Context Engineering

Governs selection, budgeting, placement, and lifecycle of window content for product LLM apps and agents (chat assistants, RAG features, tool-using workflows). Instruction wording and structure belong to [prompt-design](../prompt-design/SKILL.md).

Both failure directions cost: **starvation** (the needed fact isn't in-window) produces hallucination; **flooding** dilutes attention, buries the answer mid-window, and scales cost with waste. Window size is not attention budget — models under-attend to the middle of long contexts regardless of the advertised limit.

**Elsewhere:**

- Making the output machine-parseable → [structured-outputs](../structured-outputs/SKILL.md)
- Retrieval quality itself (chunking, embeddings, reranking) → `skills/llm-apps/rag-systems`
- Prompt caching and per-call cost mechanics → `skills/llm-apps/llm-api-patterns`
- Measuring whether a packing change helped → `skills/evals/eval-design`

## The Context Hierarchy

Five segments ranked by priority — instructions > task spec > retrieved knowledge > history > scratch. Allocate top-down; evict bottom-up. Full segment table (lifetime and overflow policy): `references/window-management.md`.

1. **Eviction order is fixed**: scratch → history → retrieved. Instructions and the task spec are never auto-trimmed; if they don't fit, surface it as a bug rather than shaving content.
2. **Each segment has one overflow policy** — a segment without one is an unbounded queue.

## Deep Dives

Read `references/window-management.md` for per-segment token budgeting, packing strategies, compaction, lost-in-the-middle placement, retrieved-context hygiene, and context observability.

## Anti-Patterns

| Pattern | Problem | Fix |
|---|---|---|
| Append-only history ("the chat log is the state") | Window fills; blunt oldest-first eviction deletes commitments | Sliding window + pinned facts + rolling summary |
| Everything-in packing ("the window is huge") | Attention dilution, lost-in-the-middle, linear cost growth | Budgets + selective include |
| Trimming the rendered string head/tail to fit | Cuts mid-instruction or mid-document, silently | Evict whole items by segment priority |
| Retrieval dumped in arrival order | Near-duplicates displace the answering document | dedupe → rank → cap → label → cite |
| Compaction into freeform prose | IDs, amounts, and decisions vanish | Structured survival note, schema-validated, temperature 0 |
| No record of what was sent | Failures unreproducible after the fact | Context manifest on every request, from day one |
| `len(text) // 4` token math | Budget drift across tokenizers/models | Provider tokenizer or counting endpoint |

## Verification

- [ ] Every segment has a budget share and an explicit overflow policy
- [ ] Instructions/task spec are never auto-trimmed; oversized requests fail loud
- [ ] History = pinned facts + rolling summary + last-N verbatim (not append-only); mid-conversation constraint changes are re-pinned
- [ ] Compaction triggers defined; survival list implemented; summarizer at temperature 0; note schema-validated
- [ ] Question and key constraints placed at window edges; best documents nearest the question
- [ ] Retrieved docs deduped, ranked, capped, source-labeled; citations required in answers
- [ ] Context manifest logged per request; any failure reconstructable from it
- [ ] Token spend per request stays bounded as sessions grow
- [ ] Packing/budget changes ship with an eval run vs baseline (pinned eval-set version, deterministic settings — `skills/evals/eval-design`)

## Related Skills

- [prompt-design](../prompt-design/SKILL.md) — wording, anatomy, and injection-resistant layering of the instructions this skill budgets for
- [structured-outputs](../structured-outputs/SKILL.md) — schema-validating compaction notes and extraction outputs
- `skills/llm-apps/rag-systems` — retrieval quality upstream of the hygiene pipeline
- `skills/llm-apps/llm-api-patterns` — prompt caching (stable-prefix ordering), token counting, cost levers
- `skills/mlops/model-monitoring` — traces and dashboards the context manifest feeds
- Agents: `ai-engineer:llm-engineer` (implementation), `ai-engineer:ai-prompt-engineer` (prompt-side owner)
