---
name: context-engineering
description: >-
  Manage what goes into an LLM app's context window: the context hierarchy
  (instructions > task spec > retrieved knowledge > history > scratch),
  per-segment token budgets, packing strategies, compaction triggers,
  lost-in-the-middle placement, retrieved-context hygiene, and context
  observability. Use when responses degrade as conversations grow, when
  deciding what to include vs summarize vs drop, when retrieval floods the
  window with near-duplicates, when token spend climbs per request, or when
  you cannot reconstruct what the model actually saw for a failed request.
---

# Context Engineering

**The model can only be as good as its window — curate context like an API payload, not a chat log**

## Overview

Context engineering decides what enters the window on every call: which instructions, which retrieved documents, how much history, in what order, and what gets summarized or dropped. It is distinct from [prompt-design](../prompt-design/SKILL.md) (the wording and structure of instructions) — this skill governs selection, budgeting, placement, and lifecycle for product LLM apps and agents: chat assistants, RAG features, tool-using workflows.

Both failure directions are expensive. **Starvation** — the needed fact isn't in-window — produces hallucination. **Flooding** — everything is in-window — dilutes attention, buries the answer mid-window, and scales cost linearly with waste. Window *size* is not attention *budget*: models under-attend to the middle of long contexts regardless of the advertised limit.

## When to Use

- Answer quality degrades as a conversation or session grows
- Designing what a new LLM feature sends per call (segments, budgets, order)
- Retrieval floods the window with near-duplicate or low-relevance chunks
- Token spend per request climbs with session length
- Planning summarization/compaction for long-running sessions or agents
- A failure postmortem cannot establish what the model actually saw

**When NOT to use:**

- Wording/structure of the instructions themselves → [prompt-design](../prompt-design/SKILL.md)
- Making the *output* machine-parseable → [structured-outputs](../structured-outputs/SKILL.md)
- Retrieval quality itself — chunking, embeddings, reranking → `skills/llm-apps/rag-systems`
- Prompt caching and per-call cost mechanics → `skills/llm-apps/llm-api-patterns`
- Measuring whether a packing change helped → `skills/evals/eval-design`

## The Context Hierarchy

Five segments, ranked by priority. Allocate top-down; evict bottom-up.

Full segment table (lifetime and overflow policy per segment): `references/window-management.md`.

Two rules make the hierarchy real:

1. **Eviction order is fixed**: scratch → history → retrieved. Instructions and the task spec are never auto-trimmed — if they don't fit, that is a bug to surface, not content to shave.
2. **Each segment has one owner policy** — a segment without an overflow policy is an unbounded queue wearing a nicer name.

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
| No record of what was sent | Failures unreproducible; "the model was dumb" postmortems | Context manifest on every request |
| `len(text) // 4` token math | Budget drift across tokenizers/models | Provider tokenizer or counting endpoint |

## Common Rationalizations

| Excuse | Reality |
|---|---|
| "The context window is big enough for everything" | Window ≠ attention. Mid-window content under-performs, and you pay for every wasted token on every call. |
| "We can always re-send the full history" | Cost grows linearly with session length while answer quality falls. A budget forces the useful subset. |
| "Summarization loses information" | Uncontrolled eviction loses *more*, and randomly. Structured compaction chooses what survives. |
| "We'll add context logging when there's a problem" | The first bad answer needs the manifest you didn't log. Observability is cheap before the incident, impossible after. |
| "More retrieved docs = better grounding" | Past the relevance knee, extra docs displace the answering one and add contradiction surface. |

## Red Flags

- Answer quality reliably drops after ~N turns in a session
- The model re-asks for or contradicts a fact the user stated earlier
- The retrieved segment exceeds half the window and contains near-identical chunks
- Nobody can print the exact prompt a production request rendered
- Token spend per request grows unboundedly through a session
- Failure tickets contain a screenshot of the bad answer but nothing about what was in-window
- A constraint update from mid-conversation never made it into pinned facts

## Verification

- [ ] Every segment has a budget share and an explicit overflow policy
- [ ] Instructions/task spec are never auto-trimmed; oversized requests fail loud
- [ ] History = pinned facts + rolling summary + last-N verbatim (not append-only)
- [ ] Compaction triggers defined; survival list implemented; summarizer at temperature 0; note schema-validated
- [ ] Question and key constraints placed at window edges; best documents nearest the question
- [ ] Retrieved docs deduped, ranked, capped, source-labeled; citations required in answers
- [ ] Context manifest logged per request; any failure reconstructable from it
- [ ] Packing/budget changes ship with an eval run vs baseline (pinned eval-set version, deterministic settings — `skills/evals/eval-design`)

## Related Skills

- [prompt-design](../prompt-design/SKILL.md) — wording, anatomy, and injection-resistant layering of the instructions this skill budgets for
- [structured-outputs](../structured-outputs/SKILL.md) — schema-validating compaction notes and extraction outputs
- `skills/llm-apps/rag-systems` — retrieval quality upstream of the hygiene pipeline
- `skills/llm-apps/llm-api-patterns` — prompt caching (stable-prefix ordering), token counting, cost levers
- `skills/mlops/model-monitoring` — traces and dashboards the context manifest feeds
- Agents: `ai-engineer:llm-engineer` (implementation), `ai-engineer:ai-prompt-engineer` (prompt-side owner)
