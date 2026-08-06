---
name: dataset-curation
description: >-
  Builds fine-tuning datasets that survive review: chat-format normalization
  (messages schema, chat templates, multi-turn handling), exact + near-dup
  dedup, eval-set decontamination, PII/secret scrubbing gates,
  license/provenance ledgers, stratified splits, and dataset versioning tied
  to every downstream metric. Use when assembling or auditing SFT or
  preference data, converting raw logs/docs into JSONL training records,
  sizing a dataset for a task class, chasing inflated eval scores from
  suspected leakage, or preparing data for a LoRA/QLoRA/DPO run.
---

# Dataset Curation

**The dataset is the model behavior — curate it like production code**

## Overview

Fine-tuning quality is decided before the first training step. The model will
faithfully learn whatever the dataset teaches: its format quirks, its
duplicated examples, its leaked secrets, and its contamination of your eval
set. Curation is the discipline of turning raw sources into a versioned,
deduplicated, decontaminated, scrubbed, license-cleared JSONL artifact — and
of treating that artifact's version as part of every metric derived from it.

Owned by `ai-engineer:ml-engineer`. Whether to fine-tune at all (vs RAG vs
prompting) is a method decision — escalate to `ai-engineer:ai-architector`.

## When to Use

- Assembling an SFT or preference dataset from logs, docs, tickets, or synthetic generation
- Converting raw data into the messages format (or between Alpaca/ShareGPT/completion formats)
- Auditing an existing dataset before a training run (dup ratio, contamination, PII, licenses)
- Eval scores look suspiciously good — checking for train/eval leakage
- Sizing a dataset: "how many examples does this task class need?"
- Setting up dataset versioning so training runs are reproducible

**When NOT to use:**

- Sources that already carry a grader *verdict* — eval traces, graded runs, rejection sampling, pairs from passing/failing trajectories → `skills/finetuning/trace-to-training-data` (this skill owns raw, ungraded sources; that one converts graded ones into this skill's schema)
- Training mechanics (LoRA configs, memory, schedules) → `skills/finetuning/peft-lora`, `skills/finetuning/training-optimization`
- Preference-pair *generation strategy* and labeling rubrics → `skills/finetuning/preference-tuning` (this skill owns pair format and hygiene only)
- Retrieval corpora for RAG — chunking hygiene, not messages hygiene → `skills/llm-apps/rag-systems`
- Designing the eval set itself → `skills/evals/eval-design`

## Size: Quality Over Quantity

Order-of-magnitude starting ranges observed in practice — not targets, not
thresholds. A clean 1k set routinely beats a noisy 20k set; volume past the
point of diminishing returns mostly buys longer runs and more curation debt.

| Task class | Working range (starting point) | Notes |
|-----------|-------------------------------|-------|
| Style / tone / persona adapter | ~200–2,000 examples | Consistency of the target style matters more than count |
| Format enforcer (strict JSON, schema, DSL) | ~500–5,000 | Cover every schema branch and failure case; more prose adds nothing |
| Domain assistant (instructions in one domain) | ~1,000–20,000 | Diversity of intents beats volume per intent |
| Preference pairs (DPO-class) | ~2,000–20,000 pairs | Pair quality and clear margins dominate — `skills/finetuning/preference-tuning` |
| Broad capability shift | tens of thousands + | Usually the wrong tool — consult `ai-engineer:ai-architector` before collecting |

When the honest range for your task exceeds what you can curate to standard,
that is a signal to reconsider the method, not to lower the quality bar.

## The Curation Pipeline

Every batch of records passes the same gates, in order. A batch that fails a
gate is quarantined — it never silently proceeds.

```
collect → normalize → dedupe → decontaminate → scrub → license → split → version
   │          │          │           │            │        │        │        │
sources    messages   exact hash  n-gram       PII +   ledger  stratified  DVC or
+ ledger   schema +   + minhash   overlap      secret  complete by task /  hash
entry      template   clusters    vs eval      gates   per      source     manifest
           render                 sets         (fail-  batch
                                               closed)
```

| Stage | Gate to pass | Tooling sketch |
|-------|--------------|----------------|
| Collect | Every batch has a ledger entry (source, license, consent class) | `data/ledger/*.yaml` |
| Normalize | 100% of records validate against the messages schema | validator — `references/data-formats.md` |
| Dedupe | Exact-dup ratio ≈ 0; near-dup clusters resolved or co-split | sha256 + MinHash/LSH |
| Decontaminate | No n-gram overlap with any pinned eval set | n-gram index over eval sets |
| Scrub | PII/secret scanners report zero residual findings | regex + entropy + NER (presidio-class, gitleaks-style rules) |
| License | No unknown-license batch enters training | ledger completeness check |
| Split | Stratified by source and task type; near-dups on one side | seeded splitter |
| Version | Content hash / DVC pointer recorded | `dvc add` or sha256 manifest |

## Chat-Format Normalization

Normalize everything to the messages schema first — every later stage assumes
it. One JSON object per line:

```json
{"messages": [
  {"role": "system", "content": "You are the support assistant for Acme CRM."},
  {"role": "user", "content": "How do I export my contacts?"},
  {"role": "assistant", "content": "Settings → Data → Export as CSV. Exports include archived contacts unless you filter them first."}
]}
```

Rules that prevent silent training bugs:

- **System-turn policy**: pick exactly one — a constant system prompt
  dataset-wide, a per-record system turn, or none. Mixed policies teach the
  model that the system prompt is optional.
- **Role alternation**: after the optional system turn, roles strictly
  alternate user/assistant and end on an assistant turn (the turn that
  carries the loss).
- **Chat template**: the tokenizer's `chat_template` renders messages into
  the actual token stream. Render a sample with
  `tokenizer.apply_chat_template(...)` and inspect it — template drift
  between base and instruct variants is a top cause of "trained fine,
  generates garbage". Templates vary per model family; verify against the
  current tokenizer config (context7), never assume.
- **Multi-turn truncation**: when a conversation exceeds the max length,
  drop whole leading turns (keep the system turn); never cut mid-turn, and
  keep the final assistant turn intact.
- **Loss masking**: train on assistant tokens only (completion-only masking)
  unless you have an explicit reason to learn user turns.

Schemas, preference-pair formats, masking mechanics, tokenizer edge cases,
and converters: read `references/data-formats.md` when touching format code.

## Dedup and Decontamination

Duplication wrecks both training and measurement: within-train dups
overweight examples (memorization, style collapse); dups that straddle the
train/val split leak answers into validation; dups against the *eval set*
inflate every metric you report and every gate you trust
(`skills/evals/regression-gates`). Even modest dup ratios distort loss
curves enough to mislead hyperparameter sweeps.

```python
"""Exact + near-duplicate scan for messages-format JSONL.

Run: uv run python -m data.dedup_scan data/sft/raw.jsonl
"""
import hashlib
import json
from pathlib import Path

from datasketch import MinHash, MinHashLSH  # uv add datasketch

NUM_PERM = 128


def normalize(text: str) -> str:
    return " ".join(text.lower().split())


def record_text(record: dict) -> str:
    return " ".join(m["content"] for m in record["messages"])


def scan(path: Path, threshold: float = 0.85) -> tuple[int, int]:
    """Return (exact, near) duplicate counts; near-dup = Jaccard >= threshold."""
    seen: set[str] = set()
    lsh = MinHashLSH(threshold=threshold, num_perm=NUM_PERM)
    exact = near = 0
    for i, line in enumerate(path.read_text().splitlines()):
        text = normalize(record_text(json.loads(line)))
        digest = hashlib.sha256(text.encode()).hexdigest()
        if digest in seen:
            exact += 1
            continue
        seen.add(digest)
        mh = MinHash(num_perm=NUM_PERM)
        for token in set(text.split()):
            mh.update(token.encode())
        if lsh.query(mh):
            near += 1
        else:
            lsh.insert(f"r{i}", mh)
    return exact, near
```

Resolve near-dup clusters by keeping one representative — or, when
near-dups are legitimate (templated tickets), keep the whole cluster on
**one side** of the split.

**Decontamination** is dedup against your eval sets. Build an n-gram index
over every pinned eval set (internal golden sets *and* any public benchmark
you report) and flag training records sharing any window:

```python
def ngrams(text: str, n: int = 8) -> set[tuple[str, ...]]:
    tokens = normalize(text).split()
    return {tuple(tokens[i : i + n]) for i in range(max(len(tokens) - n + 1, 0))}
```

Common practice uses windows of roughly 8–13 tokens — tune `n` to your text
lengths and review flagged pairs before dropping (short boilerplate overlap
is often benign; verbatim question/answer overlap never is). Re-run the
check whenever either side changes, and record the eval-set version the
check ran against.

## Scrubbing Gates and the Provenance Ledger

PII and secrets in training data become PII and secrets the model can emit.
Scrubbing is a fail-closed gate, not a best-effort pass:

- **Secrets**: entropy + pattern scanners (gitleaks/trufflehog-style rules)
  over the raw text of every record. Any hit quarantines the batch.
- **PII**: NER-based detection (presidio-class) plus domain regexes
  (account IDs, order numbers). Redact with stable placeholders
  (`<CUSTOMER_NAME>`) so text still reads naturally — bare deletion leaves
  ungrammatical holes the model learns to imitate.
- **Re-scan after every transformation** — format conversion can resurface
  content a scrub on the raw form missed.

Every batch carries a ledger entry; a record whose batch has no ledger
entry does not exist for training purposes:

```yaml
# data/ledger/support-tickets-q2.yaml
batch: support-tickets-q2
source: internal Zendesk export, pulled 2026-06-30
license: proprietary-owned            # SPDX id where one applies
consent_class: owned                  # owned | licensed | public-permissive | restricted
pii_scrub: passed 2026-07-02 — presidio + secret rules, 0 residual findings
records: 4212
sha256: 9f2c41…                       # hash of the normalized JSONL
```

`restricted` batches (scraped content, unclear terms, no consent basis)
never enter training. Route disputes to `ai-engineer:ai-security-auditor`
review rather than deciding unilaterally.

## Splits and Versioning

- **Stratify — never random-only across mixed sources.** A random split
  over heterogeneous sources lets one source dominate validation, making
  metrics incomparable across dataset versions. Stratify by source and task
  type; keep near-dup clusters on one side.
- **Seed the splitter** and record the seed — an unreproducible split is an
  unreproducible experiment.
- **Version the artifact, not the folder.** DVC or a content-hash manifest;
  either yields an immutable id:

```bash
uv run python -m data.split --stratify-by source,task_type --seed 17
dvc add data/sft/train.jsonl
dvc add data/sft/val.jsonl
git add data/sft/train.jsonl.dvc data/sft/val.jsonl.dvc data/ledger/
```

**The dataset version is part of every downstream metric.** A loss curve,
an eval score, or a win rate without the dataset hash next to it is not
evidence — log it with the run config per `skills/mlops/experiment-tracking`
and quote it in DV artifacts and release notes.

## Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| "More data is better" collection | Noise and dups dominate; curation debt compounds | Size by task class; cap collection, spend the time cleaning |
| Random split over mixed sources | Val distribution drifts from train; metrics incomparable | Stratify by source/task type with a recorded seed |
| Dedup after splitting | Near-dups straddle the boundary → leaked validation | Dedupe and cluster before the split; co-split clusters |
| Skipping decontamination ("our eval is private") | Shared upstream sources leak eval items into train | n-gram check against every pinned eval set, private included |
| Scrubbing once, on raw data only | Conversions resurface PII/secrets | Re-scan after every transformation; fail closed |
| Mixed system-turn policies | Model learns the system prompt is optional | One policy dataset-wide, enforced by the validator |
| Unversioned "latest" dataset folder | Metrics can't be compared across runs | DVC/hash manifest; version quoted with every metric |
| Training on user turns by default | Model imitates users, wastes capacity | Completion-only masking — `references/data-formats.md` |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "We'll clean it after the first run" | The first run's metrics steer every decision after it; garbage in, garbage steering |
| "A few duplicates won't matter" | Dup ratio compounds: overweighted examples, leaked validation, inflated gates |
| "The eval set is separate — contamination is impossible" | The same upstream sources feed both sides; only the n-gram check knows |
| "It's internal data, no PII concerns" | Internal data is where the real secrets live, and the model will repeat them |
| "License review slows us down" | An unlicensed batch discovered post-launch means retraining, not paperwork |
| "We can eyeball 500 examples" | Eyeballs miss near-dups and template drift; run the scanners, then eyeball |

## Red Flags

- Dedup or contamination scan has never been run on the current dataset version
- Eval metrics jumped after a data refresh with no model change
- A batch with no ledger entry, or `consent_class: restricted` records in train
- `train.jsonl` modified in place with no version bump
- No format validator — schema enforced by "the trainer didn't crash"
- Split seed unrecorded, or the split re-rolled between runs being compared
- Secret-scanner findings waived without `ai-engineer:ai-security-auditor` sign-off

## Verification

- [ ] 100% of records pass the messages-schema validator (roles, alternation, non-empty content)
- [ ] Chat template rendered on samples and inspected — no doubled system turns, EOS present
- [ ] Exact-dup ratio ≈ 0; near-dup clusters resolved or co-split; counts recorded
- [ ] n-gram decontamination run against every pinned eval-set version; hits reviewed
- [ ] PII/secret scan passed after the final transformation; zero residual findings (or signed waiver)
- [ ] Every batch has a ledger entry (source, license, consent class); no restricted batches in train
- [ ] Split stratified by source/task type, seeded, seed recorded
- [ ] Dataset version (DVC/sha256) recorded and referenced by the run config (`skills/mlops/experiment-tracking`)

## Related Skills

- `skills/finetuning/peft-lora` — consuming this dataset in a LoRA/QLoRA run
- `skills/finetuning/preference-tuning` — preference-pair generation strategy and DPO-class training
- `skills/finetuning/training-optimization` — fitting and running the training job
- `skills/mlops/experiment-tracking` — logging dataset versions with run configs and metrics
- `skills/evals/eval-design` — building the eval sets you decontaminate against
- `references/data-formats.md` — JSONL schemas, chat-template mechanics, masking, converters
