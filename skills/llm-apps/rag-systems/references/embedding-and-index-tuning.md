# Embedding and Index Tuning

Parameter-level depth for the retrieval half of `skills/llm-apps/rag-systems`:
ANN index parameters, the memory they cost, and the fusion arithmetic behind
hybrid search. Read this while tuning an existing pipeline — the pipeline
design, chunking, and grounding rules stay in the parent skill.

Engine defaults and parameter names differ (and move) between vector stores —
verify against the store's current docs (context7) before copying a number.

## Contents

- [The three-dial model](#the-three-dial-model)
- [HNSW parameters](#hnsw-parameters)
- [HNSW memory estimation](#hnsw-memory-estimation)
- [IVF parameters](#ivf-parameters)
- [Choosing an index type](#choosing-an-index-type)
- [Score normalization](#score-normalization)
- [Fusion: RRF and linear](#fusion-rrf-and-linear)
- [Tuning procedure](#tuning-procedure)

## The three-dial model

Every ANN index trades among the same three quantities. You cannot improve all
three; tuning is choosing which one to spend.

| Dial | Raised by | Paid in |
|---|---|---|
| Recall (does the true neighbor get returned) | Larger graph degree, wider search | Latency and memory |
| Latency | Narrower search, smaller candidate lists | Recall |
| Memory / build time | Smaller degree, coarser quantization | Recall |

The mistake this framing prevents: tuning index parameters to fix a *quality*
problem that is really a chunking, embedding-model, or grounding problem.
Before touching any parameter below, confirm with the parent skill's retrieval
eval that the correct chunk is in the index and reachable by exhaustive search.
If exact search cannot find it, no ANN parameter will.

## HNSW parameters

Three parameters, two of them fixed at build time.

| Parameter | When it applies | Effect | Typical starting range |
|---|---|---|---|
| `M` | Build (immutable) | Edges per node. Higher = better recall, more memory, slower build | 16–64 |
| `efConstruction` | Build (immutable) | Candidate breadth while inserting. Higher = better graph quality, slower build only | 100–500 |
| `efSearch` | Query (tunable live) | Candidate breadth at query time. Higher = better recall, higher latency | 50–400 |

- **`efSearch` is the only dial you can turn after the index is built.** It is
  therefore the one to tune first and the one to expose as a config value.
  `M` and `efConstruction` changes require a rebuild.
- **`efSearch` must be ≥ `k`.** Asking for the top 50 with `efSearch=32` silently
  caps quality; the search cannot consider more candidates than its beam.
- **`efConstruction` costs build time, not query time.** When ingestion is
  offline and infrequent, buy recall here rather than at query time — it is
  the cheapest of the three in production terms.

A size-tiered starting ladder, to be replaced by your own eval numbers:

| Corpus size | `M` | `efConstruction` | `efSearch` |
|---|---|---|---|
| < 100k vectors | 16 | 200 | 50–100 |
| 100k – 1M | 32 | 200–400 | 100–200 |
| 1M – 10M | 32–48 | 400 | 200–400 |
| > 10M | 48–64, or move to a quantized/IVF index | 400+ | tune against latency SLO |

## HNSW memory estimation

HNSW keeps the full vectors *and* the graph resident. Estimate before choosing
an instance size, because discovering the footprint at load time is an
expensive way to learn it.

```
vector_bytes = n_vectors × dim × bytes_per_component      # 4 for float32, 2 for float16
graph_bytes  ≈ n_vectors × M × 2 × bytes_per_link         # ~4-8 bytes/link; ×2 for bidirectional
total        ≈ (vector_bytes + graph_bytes) × overhead    # overhead ~1.1-1.5 incl. metadata + payload
```

Worked, with symbolic inputs: 1M vectors at dim 768, float32, `M=32`:

```
vector_bytes = 1e6 × 768 × 4   ≈ 3.07 GB
graph_bytes  ≈ 1e6 × 32 × 2 × 4 ≈ 0.26 GB
total        ≈ (3.07 + 0.26) × 1.25 ≈ 4.2 GB resident
```

Two consequences worth planning around:

- **Dimensionality is the dominant term.** Halving `dim` (a smaller embedding
  model, or a model supporting Matryoshka-style truncation) roughly halves the
  index. That is a far larger lever than any graph parameter — but it changes
  retrieval quality, so it is an eval decision, not a capacity decision.
- **float16 storage halves the vector term** at a small recall cost. Measure it
  on your eval set; it is frequently free in practice and frequently the
  difference between one instance and three.

Metadata and payloads are not in this formula. Storing the chunk text inside
the vector store adds the corpus size again on top.

## IVF parameters

Inverted-file indexes partition the space into cells and search only the
nearest few. Different dials, same three-way trade.

| Parameter | When it applies | Effect | Starting point |
|---|---|---|---|
| `nlist` | Build | Number of partitions. More = finer cells, faster search, needs more training data | ~`sqrt(n_vectors)` |
| `nprobe` | Query (tunable live) | Cells searched per query. Higher = better recall, higher latency | 1–5% of `nlist` |

- **`nlist ≈ sqrt(n)` is the standard starting heuristic** — 1M vectors →
  ~1,000 partitions. It balances cell count against cell size; both extremes
  degrade into either exhaustive search or a coarse, lossy partition.
- **`nprobe` is the live recall dial**, the IVF analogue of `efSearch`. Start
  near 1% of `nlist` and raise it until recall on your eval set plateaus.
- **IVF must be trained on representative vectors** before insertion. Training
  on a non-representative sample produces unbalanced cells, and the symptom is
  recall that is fine on average and terrible for one topic cluster.
- **`nprobe = nlist` is exhaustive search** with extra steps — a useful
  correctness check when debugging, never a production setting.

## Choosing an index type

| Situation | Index |
|---|---|
| Everything fits in RAM; recall matters most | HNSW |
| Corpus large enough that RAM is the binding constraint | IVF, optionally with product quantization |
| Small corpus (tens of thousands) | Flat/exact — ANN adds risk and tuning burden for latency nobody notices |
| Frequent deletes and updates | Check the store's delete semantics first; HNSW graphs degrade with churn and need periodic rebuilds |

Start flat. An exact index over a small corpus is fast, has perfect recall, and
gives you the ground truth every ANN measurement below is compared against.

## Score normalization

Required before any *linear* fusion, and the step most often skipped. Dense
cosine similarity lives roughly in [-1, 1]; BM25 is unbounded and
corpus-dependent. Adding them raw means the larger-magnitude scorer silently
wins every time, and the fusion weight you tuned did nothing.

```python
def min_max_normalize(scores: list[float]) -> list[float]:
    """Scale scores into [0, 1] within a single result list.

    Normalization is per query and per retriever: BM25's range depends on the
    query's term statistics, so a global constant fitted once drifts as the
    corpus grows.
    """
    lo, hi = min(scores), max(scores)
    if hi - lo < 1e-9:          # degenerate list: every score identical
        return [1.0] * len(scores)
    return [(s - lo) / (hi - lo) for s in scores]
```

Min-max is scale-free but sensitive to outliers and to the size of the result
list — it makes the top hit 1.0 whether it was excellent or merely least-bad.
That is precisely why rank-based fusion is the default below.

## Fusion: RRF and linear

**Reciprocal rank fusion** ignores scores and uses only ranks, which is what
makes it the safe default: no normalization step, no per-retriever weight to
fit, and nothing to re-tune when the corpus grows.

```
rrf_score(d) = Σ over retrievers r of  1 / (k + rank_r(d))
```

The parent skill's `rrf_fuse` implements exactly this. On the constant:

- **`k = 60` is the published default and a sensible starting value.** Its role
  is damping. Because the contribution is `1/(k + rank)`, a large `k` flattens
  the difference between rank 1 and rank 10 (with `k=60`: 0.0164 vs. 0.0143),
  so agreement across retrievers matters more than any single retriever's
  ordering.
- **Lower `k` sharpens top-rank dominance**; `k=10` makes rank 1 (0.0909) worth
  far more than rank 10 (0.05). Reach for that only when one retriever is
  measurably more trustworthy at the very top and your eval shows it.
- `k` is worth sweeping on your own eval set once the pipeline works. It is
  rarely the biggest lever, and it is never the first one.

**Linear fusion** is the alternative when you have a measured reason to weight
retrievers unequally:

```
score(d) = alpha × norm(dense(d)) + (1 - alpha) × norm(sparse(d))
```

- `alpha` is a real tuning parameter with a real optimum — sweep it against
  recall@k on your labeled query set, not by intuition.
- It requires the normalization step above, and it inherits normalization's
  fragility as the corpus shifts.
- Choose it over RRF only when the sweep demonstrably beats RRF on your eval.
  Otherwise the extra machinery buys a maintenance burden.

**Documents missing from one list.** Under RRF, a document retrieved by only
one retriever simply gets one term — correct behavior, no special case. Under
linear fusion you must decide explicitly: treating a missing document as score
0 after normalization penalizes it much harder than its true rank warrants, so
prefer retrieving deeper from both retrievers than the fusion depth you need.

## Tuning procedure

Order matters; doing this out of order produces numbers that cannot be
attributed.

1. **Build the labeled query set first.** Without it, every parameter change is
   a preference, not a measurement
   (`skills/llm-apps/rag-systems/references/retrieval-evaluation.md`).
2. **Establish exact-search ground truth.** Flat index, no ANN. This is the
   recall ceiling; ANN tuning only ever approaches it. If the ceiling is low,
   the problem is chunking or the embedding model — stop tuning the index.
3. **Tune the live dial alone** (`efSearch` / `nprobe`), sweeping upward until
   recall@k plateaus. Record the latency at each point.
4. **Pick the knee, not the peak.** The setting where recall stops improving
   meaningfully but latency keeps climbing is the answer.
5. **Only then reconsider build parameters** (`M`, `efConstruction`, `nlist`).
   Each change is a rebuild, so batch them.
6. **Re-measure after any embedding-model change.** A new embedder invalidates
   every number above — different geometry, different optimal parameters, and a
   full index rebuild anyway (see the parent skill's Index Lifecycle).

Record the chosen parameters alongside the index version. An index whose
parameters nobody can state is an index nobody can reproduce after an incident.
