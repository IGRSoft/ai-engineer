# Retrieval Evaluation (deep dive)

Use this when:

- Building the labeled query set that makes retrieval measurable
- Computing recall@k, MRR, or nDCG and interpreting what moved
- Separating retrieval failures from generation failures end-to-end
- Wiring retrieval metrics into pytest as a regression gate

Skip this file if:

- You want the pipeline design or debugging order — use [../SKILL.md](../SKILL.md)
- You are tuning chunk size/overlap — use
  [chunking-strategies.md](chunking-strategies.md) (then come back to measure)
- You need general eval-harness design or LLM-judge mechanics — use
  `skills/evals/eval-design` and `skills/evals/llm-judge`

Retrieval metrics are cheap, deterministic, and LLM-free — measure them first,
because retrieval quality is the ceiling on everything downstream.

## Building the Eval Set

A useful set is small, labeled, versioned, and honestly sourced.

- **Queries** (50-200 covers most corpora): production query logs are the gold
  source; add SME-authored queries for coverage and synthetic LLM-generated
  queries only after human review — and record provenance per query. Stratify
  by archetype: fact lookup, how-to, exact identifier, multi-hop, and
  *no-answer* (the refusal path needs eval too).
- **Labels:** for each query, the set of relevant document ids — plus chunk
  ids only if your chunking is stable. Label at document level and map to
  chunks at eval time; chunk-level labels die on every re-chunk. Binary
  relevance (0/1) is enough to start and already supports nDCG; graded (0-3)
  makes nDCG more discriminating.
- **Versioning:** ship as `evals/retrieval-vN.jsonl` with a changelog. Metrics
  are only comparable within one version; bump N on any label or query change
  and re-baseline.

```json
{"query_id": "q014", "query": "How do I rotate an API key?", "relevant_doc_ids": ["kb-142", "kb-097"], "archetype": "how-to", "provenance": "prod-logs-2026-06"}
```

## Metrics: Formulas and a Worked Example

For one query: `R` = relevant set, ranked results `r_1, r_2, …`.

```
recall@k = |R ∩ {r_1..r_k}| / |R|
RR       = 1 / rank of the first relevant result   (0 if none retrieved)
MRR      = mean of RR over all queries
DCG@k    = Σ (i=1..k)  rel_i / log2(i + 1)
nDCG@k   = DCG@k / IDCG@k          (IDCG = DCG of the ideal ordering)
```

Worked example — relevant `R = {c2, c5}`, system returns `[c7, c2, c9, c5, c1]`:

| Metric | Computation | Value |
|--------|-------------|-------|
| recall@3 | top-3 = {c7, c2, c9}; hits = {c2} → 1/2 | 0.50 |
| recall@5 | top-5 contains c2 and c5 → 2/2 | 1.00 |
| RR | first relevant (c2) at rank 2 → 1/2 | 0.50 |
| DCG@3 | 0/log2(2) + 1/log2(3) + 0/log2(4) = 0 + 0.631 + 0 | 0.631 |
| IDCG@3 | ideal = both relevant first: 1/log2(2) + 1/log2(3) | 1.631 |
| nDCG@3 | 0.631 / 1.631 | 0.39 |

Reading them: **recall@k** answers "is the evidence findable at all" (gate this
first — k should match how many chunks your prompt actually receives), **MRR**
answers "does the best evidence rank early", **nDCG** weighs graded relevance
across the whole cutoff. A healthy recall@50 with poor precision@5 is the
signature that a reranker (or fusion fix) will pay off.

## End-to-End: Faithfulness vs Answer Relevance

Retrieval metrics stop at the prompt boundary. Score the generated answer on
two separate axes — merging them hides which stage is broken:

- **Faithfulness:** is every claim supported by the retrieved evidence?
  Catches hallucination even when retrieval was perfect.
- **Answer relevance:** does the answer actually address the query? Catches
  evasive, partial, or padded answers that are technically faithful.

| Retrieval | Faithful | Relevant | Diagnosis |
|-----------|----------|----------|-----------|
| good | yes | yes | Healthy |
| good | no | — | Grounding/prompt fault — model ignores or embellishes evidence |
| good | yes | no | Prompt/task fault — answers beside the question |
| bad | — | — | Fix retrieval first; generation scores are noise |

Both axes are LLM-judged — rubrics, pairwise vs pointwise, and judge-bias
controls live in `skills/evals/llm-judge`. Run judges deterministically:
temperature 0, pinned judge prompt version, pinned eval-set version recorded
next to every reported number.

## Contamination Pitfalls

- **Paraphrased-from-the-chunk queries:** authoring a query while reading the
  gold chunk copies its vocabulary — lexical overlap inflates BM25 and hybrid
  scores. Author from logs or from task memory, not from the open document.
- **Eval leakage into the system:** gold queries or chunks used as few-shot
  examples in the production prompt, or included in fine-tuning data, turn the
  eval into a memorization test.
- **Embedder tuned on the eval:** fine-tuning the embedding model on pairs
  derived from the eval set invalidates it — regenerate a fresh test split.
- **Tuning on the test set:** every size/overlap/k sweep must run against a
  dev slice; hold out a test slice you touch only for final numbers — even at
  100 queries, split dev/test.
- **Near-duplicate queries:** dedupe before averaging, or one over-represented
  archetype dominates the mean.

## Minimal pytest Harness

Deterministic gate: pinned eval-set version, fixed k, no sampling anywhere in
the retrieval path. Run scoped via `uv run pytest tests/eval_retrieval.py -q`;
CI wiring and flake policy live in `skills/evals/regression-gates`.

```python
"""Retrieval regression gate.

Eval set: evals/retrieval-v3.jsonl (pinned — bump N and re-baseline on change).
Run: uv run pytest tests/eval_retrieval.py -q
"""

import json
from pathlib import Path

from app.retrieval import retrieve  # returns ranked chunk ids, deterministic

EVAL_SET = Path("evals/retrieval-v3.jsonl")
K = 5
THRESHOLDS = {"mean_recall_at_k": 0.85, "mrr": 0.70}  # ratchet up, never silently down


def load_cases() -> list[dict[str, object]]:
    return [json.loads(line) for line in EVAL_SET.read_text().splitlines() if line]


def recall_at_k(ranked: list[str], relevant: set[str], k: int) -> float:
    return len(set(ranked[:k]) & relevant) / len(relevant)


def reciprocal_rank(ranked: list[str], relevant: set[str]) -> float:
    return next(
        (1.0 / rank for rank, cid in enumerate(ranked, start=1) if cid in relevant),
        0.0,
    )


def test_retrieval_regression() -> None:
    cases = load_cases()
    recalls: list[float] = []
    rrs: list[float] = []
    for case in cases:
        ranked_chunks = retrieve(str(case["query"]), k=max(K, 20))  # retrieve wide
        ranked_docs = [cid.split("#")[0] for cid in ranked_chunks]  # "{doc_id}#{n}" → doc
        relevant = {str(d) for d in case["relevant_doc_ids"]}  # doc-level labels
        if not relevant:
            # no-answer archetype: no labels means no recall to compute. Score it
            # as must-not-retrieve and keep it out of the means it would distort.
            forbidden = {str(d) for d in case.get("must_not_retrieve", [])}
            assert not (set(ranked_docs[:K]) & forbidden)
            continue
        recalls.append(recall_at_k(ranked_docs, relevant, K))
        rrs.append(reciprocal_rank(ranked_docs, relevant))
    assert recalls, "eval set contains no labeled cases"
    assert sum(recalls) / len(recalls) >= THRESHOLDS["mean_recall_at_k"]
    assert sum(rrs) / len(rrs) >= THRESHOLDS["mrr"]
```

Report per-archetype breakdowns alongside the mean — a healthy average hides a
dead archetype (exact-identifier queries failing while prose lookups coast is
the classic hybrid-retrieval bug). When the gate fails, debug with the
layer-order procedure in [../SKILL.md](../SKILL.md) Debug Retrieval First.
