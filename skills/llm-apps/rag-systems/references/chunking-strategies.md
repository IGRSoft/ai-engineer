# Chunking Strategies (deep dive)

Use this when:

- Choosing or tuning a chunking strategy for a new corpus
- Sweeping chunk size / overlap and interpreting the recall-precision effects
- Setting up parent-document (small-to-big) retrieval
- Handling tables, figures, or mixed PDF content that plain splitters mangle

Skip this file if:

- You need the pipeline-level view or per-content-type summary — use
  [../SKILL.md](../SKILL.md)
- You are building the measurement harness — use
  [retrieval-evaluation.md](retrieval-evaluation.md)

The chunk is both the *embedding unit* (what the retriever scores) and, unless
you split those roles, the *generation unit* (what the prompt receives). Most
chunking pain comes from forcing one size to serve both jobs — the
parent-document section below is the standard escape.

## Strategy Catalog

| Strategy | Split rule | Best for | Watch out |
|----------|-----------|----------|-----------|
| Fixed-size | Every N tokens, sliding overlap | Quick baseline, uniform prose | Splits mid-sentence and mid-fact; structure-blind |
| Recursive | Separator hierarchy: paragraph → sentence → token | General prose without markup | Still blind to headings and document logic |
| Semantic | Break where inter-sentence embedding similarity drops | Long topic-drifting documents | Extra embedding cost; boundaries shift when the embedder changes |
| Structural: markdown/header | Heading tree; one chunk per section, heading path prepended | Docs, wikis, READMEs | Oversized sections need a secondary recursive split |
| Structural: code-aware | AST / tree-sitter function and class boundaries | Source code | Lost file context — prepend path, signature, docstring |
| Layout-aware | Blocks from a PDF layout parser, then structural | PDFs, reports, scans | Parser quality dominates; garbage blocks → garbage chunks |

Structural strategies win wherever structure exists, because section boundaries
are already semantic boundaries. Fall back to recursive only for unstructured
blobs, and to fixed-size only for a first-day baseline.

## Chunk Size: Recall vs Precision

- **Small chunks** produce sharp, single-topic embeddings — high precision for
  specific queries — but fragment facts across boundaries and multiply index
  size. A fact split across two chunks may be retrievable in neither.
- **Large chunks** keep context intact but dilute the embedding across topics
  (recall drops for specific queries) and drag noise into the prompt, spending
  budget and burying the relevant sentence.
- There is no universal number. A few hundred tokens is a reasonable *starting
  point* for prose; the real answer comes from sweeping size against your
  retrieval eval (see [retrieval-evaluation.md](retrieval-evaluation.md)) —
  chunk size is a measured parameter, not a belief.

```
        retrieval precision          context completeness
small   ██████████ high              ███ facts fragment
large   ████ diluted embeddings      ██████████ intact
              → split the roles: retrieve small, generate big
```

## Overlap Tradeoffs

Overlap duplicates a token window across adjacent chunks.

- **Buys:** facts straddling a boundary survive intact in at least one chunk.
- **Costs:** index size multiplier; near-duplicate neighbors crowd top-k
  (killing result diversity); duplicated text enters the prompt.
- **Guidance:** start around 10-20% of chunk size for fixed/recursive
  splitters; structural chunkers usually need **zero** overlap because their
  boundaries are already semantic. Deduplicate overlapping spans at prompt
  assembly. Treat overlap as a measured recall lever — if the eval shows no
  recall gain, drop it.

## Parent-Document / Small-to-Big Retrieval

Embed small, generate big: index fine-grained child chunks for precise
matching, but hand the generator the parent context the child came from.

```
index time:  parent section ──▶ child paragraphs ──▶ embed children only
query time:  match child ──▶ look up parent_id ──▶ return parent to the prompt
```

```python
from dataclasses import dataclass


@dataclass(frozen=True)
class ChildChunk:
    chunk_id: str
    parent_id: str  # generation unit to fetch on hit
    text: str  # embedded retrieval unit


def expand_to_parents(hits: list[ChildChunk], store: ParentStore) -> list[str]:
    """Map child hits to unique parents, preserving first-hit order."""
    seen: dict[str, None] = {}
    for hit in hits:
        seen.setdefault(hit.parent_id, None)
    return [store.get_text(parent_id) for parent_id in seen]
```

Variants and cautions:

- **Sentence-window:** return the hit sentence ± N neighbors instead of a full
  parent — cheaper, good for dense reference material.
- **Deduplicate parents:** several children of one parent often hit together;
  return the parent once (as above) or top-k fills with copies.
- **Budget:** parents are big — cap parent count by prompt budget, not by k.
- **Citations:** cite the child id (precise) while displaying the parent.

## Tables and Figures

Plain text splitters silently destroy both. Handle explicitly:

- **Never split a table mid-row.** Serialize the whole table (markdown or CSV)
  as one chunk, prepending caption and nearby prose context.
- **Wide/long tables:** emit per-row or per-row-group chunks, each carrying the
  header row and caption so every chunk is self-describing.
- **Numeric lookups are keyword-shaped:** serialized tables match better via
  the sparse/BM25 path — make sure hybrid retrieval covers them.
- **Figures:** the chunk is the caption plus alt text or a generated
  description; store a pointer to the original image in metadata so the UI can
  render it. A figure with no text representation is unfindable.

## Worked Configs

Starting points — every number here is a tuning input for your eval sweep, not
a recommendation to ship blind.

```yaml
# Knowledge-base articles (markdown)
chunker: markdown_headers
heading_path_prefix: true      # "Guide > Install > Linux" prepended to chunk text
max_section_tokens: 400        # secondary recursive split above this
overlap_tokens: 0              # structural boundaries — overlap adds only dupes
```

```yaml
# Source code
chunker: code_aware            # tree-sitter function/class units
prepend: [file_path, signature, docstring]
fallback: recursive            # non-parseable files (configs, notebooks)
max_chunk_tokens: 600
overlap_tokens: 0
```

```yaml
# Mixed PDF corpus (reports with tables + figures)
chunker: layout_aware
tables: serialize_whole        # never split mid-row; header + caption attached
figures: caption_plus_description
parent_document:
  enabled: true
  child_tokens: 200            # embedded retrieval unit
  parent_tokens: 900           # generation unit returned to the prompt
```

## Re-chunking Is an Index Change

Changing strategy, size, or overlap changes every chunk id:

- Retrieval eval labels keyed to chunk ids go stale — label at document level
  and map to chunks, or re-label when chunking changes
  ([retrieval-evaluation.md](retrieval-evaluation.md)).
- Rebuild into a new collection and A/B old-vs-new on the retrieval eval
  before swapping (blue-green, per [../SKILL.md](../SKILL.md) Index Lifecycle).
- Citations in cached/stored answers reference old chunk ids — expire them.
