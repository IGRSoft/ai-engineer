# Context Engineering — Window Management Deep Dive

Deep-dive companion to [../SKILL.md](../SKILL.md): the full segment table, per-segment token budgeting, packing strategies, compaction, placement, retrieved-context hygiene, and observability.

## Segment Table

```
┌───┬───────────────────────────────┬────────────┬──────────────────────────┐
│ # │ segment                       │ lifetime   │ overflow policy          │
├───┼───────────────────────────────┼────────────┼──────────────────────────┤
│ 1 │ Instructions (system prompt)  │ per deploy │ never trimmed            │
│ 2 │ Task spec (current request)   │ per call   │ never trimmed; oversized │
│   │                               │            │ requests fail loud       │
│ 3 │ Retrieved knowledge           │ per call   │ dedupe → rank → cap      │
│ 4 │ History (conversation state)  │ rolling    │ sliding window + summary │
│ 5 │ Scratch (tool output, drafts) │ transient  │ keep latest, drop rest   │
└───┴───────────────────────────────┴────────────┴──────────────────────────┘
        priority 1 = highest: lower numbers survive when the budget tightens
```

## Token Budgeting per Segment

Express budgets as **fractions of the usable input budget**, never absolute numbers — window sizes vary per model and change across releases (verify the current limit for your configured model via provider docs / context7). Reserve output room first:

```
input_budget = context_window − max_output_tokens − safety_margin
```

| Segment | Share of input budget (starting point) | Enforcement |
|---|---|---|
| Instructions | ~5%, fixed | CI check fails when the rendered template outgrows its share |
| Task spec | ~10% | Reject or split oversized requests — fail loud |
| Retrieved | ~40% | top-k cap + per-document token cap |
| History | ~30% | sliding window + pinned facts + rolling summary |
| Scratch | ~15% | latest tool result verbatim; older results truncated to status lines |

Tune shares per feature with evals — a summarizer needs a bigger task share; a RAG QA feature a bigger retrieved share.

```python
from dataclasses import dataclass


@dataclass(frozen=True)
class SegmentBudget:
    name: str
    share: float  # fraction of input budget
    evictable: bool


BUDGETS: list[SegmentBudget] = [
    SegmentBudget("instructions", 0.05, evictable=False),
    SegmentBudget("task", 0.10, evictable=False),
    SegmentBudget("retrieved", 0.40, evictable=True),
    SegmentBudget("history", 0.30, evictable=True),
    SegmentBudget("scratch", 0.15, evictable=True),
]


def input_budget(window: int, max_output: int, margin: int = 512) -> int:
    """Usable input tokens after reserving output room and a safety margin."""
    return window - max_output - margin
```

Count tokens with the provider's tokenizer or token-counting endpoint — `len(text) // 4` heuristics drift across tokenizers and silently corrupt budgets.

## Packing Strategies

### Selective include

Include only what the *current* call needs, chosen by relevance — not everything available, not recency alone. The question for each candidate item is "does this change the answer?", not "is this related?".

### Hierarchical summary

Keep a compact index of everything; expand only the relevant part. The model sees the whole territory at summary resolution and the working area at full resolution:

```text
<session_summary>
Goal: migrate customer's plan from Legacy-Pro to Team; keep annual billing.
Decided: proration accepted (turn 9); SSO must keep working (turn 14).
Open: data-export add-on compatibility.
</session_summary>

<current_topic verbatim_turns="6">
…last 6 turns in full…
</current_topic>
```

### Sliding window + pinned facts

History = three parts: a **pinned-facts block** (never evicted), a **rolling summary** of evicted turns, and the **last N turns verbatim**. Pinned facts are extracted as structured state — IDs, amounts, names, decisions — because prose summaries lose exactly these under compression:

```python
from collections.abc import Callable


def pack_history(
    turns: list[str],
    pinned_facts: str,
    budget: int,
    count: Callable[[str], int],
    summarize: Callable[[list[str]], str],
) -> str:
    """Pinned facts + rolling summary of evicted turns + newest verbatim turns."""
    used = count(pinned_facts)
    recent: list[str] = []
    for turn in reversed(turns):
        if used + count(turn) > budget:
            break
        recent.insert(0, turn)
        used += count(turn)
    evicted = turns[: len(turns) - len(recent)]
    summary = summarize(evicted) if evicted else ""
    return "\n\n".join(p for p in (pinned_facts, summary, *recent) if p)
```

## Compaction

Compaction rewrites accumulated context into a smaller form. Trigger it **proactively** — on any of:

- **Utilization**: in-window tokens exceed ~70-80% of the input budget
- **Turn count**: a per-feature threshold measured against your evals
- **Phase boundary**: before a long tool chain, a subtask handoff, or a topic switch
- **Repeat overflow**: history blew its share twice in a row

What MUST survive compaction — as a structured note, not a prose blob:

| Survives | Because |
|---|---|
| Task goal + hard constraints | Losing these changes what the app is doing |
| Decisions made (+ one-line rationale) | Prevents re-litigating settled points |
| Pinned facts: IDs, quantities, names, dates, URLs | First casualties of prose summarization |
| Open questions / pending actions | The future work list |
| Last N turns verbatim | Local coherence for the next reply |

What can go: greetings, superseded drafts, resolved errors, duplicate retrievals, exploratory dead ends.

Compaction discipline: run the summarizer at temperature 0; validate the survival note against a schema before it replaces history ([structured-outputs](../structured-outputs/SKILL.md)); log the pre-compaction transcript so compaction never destroys evidence; never compact segments 1-2.

## Placement: Lost in the Middle

Attention is U-shaped — strongest at the start and end of the window, weakest in the middle. Placement rules:

- **Instructions at the start; task/question restated at the end** — after any long content, close with the question and the key constraints (see `references`-level pattern: `skills/prompt-engineering/prompt-design/references/prompt-patterns.md` § Progressive Disclosure).
- **Rank retrieved documents so the best sit nearest the edges** — highest-relevance docs closest to the final question; low-rank material (if included at all) goes mid-window.
- **Never bury a constraint update mid-history** — when the user changes a requirement at turn 12 of 40, re-pin it into the pinned-facts block; don't rely on the model spotting it mid-window.
- **Long documents before the question**, per provider long-context guidance (`skills/prompt-engineering/prompt-design/references/claude-prompting.md` § Long-Context Placement).

## Retrieved-Context Hygiene

Retrieval output is a candidate pool, not a payload. Pipeline before packing:

```
retrieve → dedupe → rank → cap → label → cite
```

- **Dedupe** near-duplicates (content hash, then similarity threshold) — overlapping chunks of the same source crowd out the document that actually answers.
- **Rank** by relevance score, never by arrival order.
- **Cap** three ways: top-k documents, per-document token cap, and the segment budget.
- **Label** every document with a source id and version/timestamp in its delimiter:

```text
<document source="kb-142" version="7" updated="2026-05-11">…</document>
```

- **Cite**: require source ids in answers — grounding becomes auditable, and uncited claims become review flags.
- **Staleness**: on conflict between documents, instruct the model to prefer the newer version and say so.

Chunking, embedding, and reranker quality are upstream — `skills/llm-apps/rag-systems`. This skill assumes retrieval returns *something reasonable* and makes the window survive it.

## Context Observability

For every request, log a **context manifest** — enough to reconstruct what was in-window without storing the full render everywhere:

```json
{
  "request_id": "req_8271",
  "prompt_version": "support-triage@4",
  "model": "<alias from config>",
  "segments": [
    {"name": "instructions", "tokens": 812},
    {"name": "task", "tokens": 240},
    {"name": "retrieved", "tokens": 3120,
     "doc_ids": ["kb-142@7", "kb-201@3"], "dropped_doc_ids": ["kb-77@2"]},
    {"name": "history", "tokens": 1490, "turns_verbatim": 6, "turns_summarized": 18},
    {"name": "scratch", "tokens": 380}
  ],
  "truncations": ["history: 12 turns → summary"],
  "compactions": 1
}
```

- Attach the manifest to the request trace (`skills/mlops/model-monitoring`); store the full rendered prompt where retention policy allows, scrubbed of secrets/PII per the base constraints.
- Failure triage starts at the manifest: *Was the needed fact in-window at all? Which segment? Where placed? Was it truncated or compacted away?* Without the manifest, every context bug is unreproducible.
- Version everything the manifest references: prompt version, doc versions, compaction count — a regression is diagnosable only when the inputs are identifiable.
