---
description: Read-only dataset quality audit for fine-tuning and eval sets — schema, dedup, train/test contamination, PII/secret scan, license/provenance, distribution stats into a P0-P3 report. Use before a training run or when eval scores look too good.
argument-hint: [dataset path(s) (default: auto-discover)] [--sample N (default 5000)] [--eval-set PATH]
allowed-tools: Read, Agent, Glob, Grep, Bash
---

# Data Audit

Audit fine-tuning and eval datasets before they steer a training run. Runs the `ai-engineer:dataset-curation` gates read-only — schema, duplication, contamination, PII/secrets, license/provenance, distribution — adds an `ai-engineer:ml-engineer` deep pass, and emits a P0-P3 report with every remediation routed to an owner.

## CRITICAL BEHAVIORAL RULES

1. **Read-only.** Don't edit datasets, ledgers, splits, or configs; remediation is routed (Phase 9), not applied. Ephemeral tooling only (`uv run --with datasketch …`), never `uv add`.
2. **Never echo sensitive values.** Report PII/secret hits as `file:line` + pattern class + count. Don't quote the value in any form — truncated, masked, or prefix — because a secret copied into a report is a second leak.
3. **Stream or sample; don't Read a dataset body.** Get sizes from `wc -l`/`stat` and run scanners as single-command `uv run python -c` or `rg` passes. Read only a small head to eyeball structure.
4. **State coverage on every number.** Full-stream checks say "full"; sampled checks give `sample={N}, seed={s}` next to the value.
5. **Contamination needs a located eval set.** Without one, report "not checked — no eval set located"; never estimate an overlap.
6. **Normalize findings, don't manufacture them.** Each finding is `{file:line, check, severity (P0-P3), why, fix, confidence}` per `${CLAUDE_PLUGIN_ROOT}/skills/_shared/severity-matrix.md`. A clean check is reported clean.
7. **A missing tool degrades depth, not the run.** No `uv`/Python → `rg`/`wc`-level checks with a reduced-depth note; no `datasketch` → near-dup "not measured".
8. Execute directly; don't enter plan mode.

## Usage

```bash
/ai-engineer:data-audit                                  # auto-discover
/ai-engineer:data-audit data/sft/train.jsonl
/ai-engineer:data-audit data/sft/ --sample 20000
/ai-engineer:data-audit data/sft/train.jsonl --eval-set evals/support-v3.jsonl
```

## Options

| Option | Default | Effect |
|--------|---------|--------|
| `dataset path(s)` | auto-discover | Files or directories to audit (Phase 1). |
| `--sample N` | 5000 | Seeded sample size for near-dup MinHash and language mix. Other checks stream the full file. |
| `--eval-set PATH` | discover | Eval set(s) to measure contamination against. |

## Workflow

### Phase 1: Locate Datasets

First applicable source wins (union within a level):

1. Explicit args.
2. DVC — `dvc.yaml` stage `outs` and `*.dvc` pointers (their hashes are the versions the report quotes).
3. `data/**/*.jsonl`, `datasets/**/*.jsonl`, `train`/`val`/`test`-named files.
4. HF layouts — `load_dataset(`/`save_to_disk(` call sites, `dataset_info.json` dirs, dataset cards with `license:` frontmatter.

Print the inventory (`path | records | size | format | dvc-tracked | role`) before any check, classifying each file as train, val, or eval; Phase 4 needs the roles.

### Phase 2: Schema & Format (full)

Stream every JSONL line through a validator against `${CLAUDE_PLUGIN_ROOT}/skills/finetuning/dataset-curation/references/data-formats.md`:

- One JSON object per line; `messages` present for SFT records.
- Roles ∈ `system|user|assistant` (`tool` only where the chat template supports it); at most one system turn, at index 0.
- Strict user/assistant alternation, ending on `assistant`; `content` non-empty.
- Preference pairs: `chosen`/`rejected` share the identical `prompt`.
- One system-turn policy dataset-wide.

Report % valid and the first ~10 line numbers per violation class.

### Phase 3: Duplication

- **Exact (full):** sha256 over normalized text (lowercased, whitespace-collapsed) → dup count and ratio.
- **Near (sampled):** MinHash/LSH at Jaccard ≥ 0.85 over `--sample` records via `uv run --with datasketch python -c …` → near-dup cluster rate.
- Flag clusters that straddle train/val (leaked validation).

### Phase 4: Train/Test Contamination

1. Eval side: `--eval-set`, else discovered `evals/*-v*.jsonl`, else Phase 1 val/test splits. None → Rule 5, next phase.
2. Index eval records by 8-13-token n-grams (tuned to text length) and stream train records against it; full pass when sizes allow, otherwise sampled.
3. Report overlapping pairs with line pointers on both sides and the eval-set version. Verbatim question/answer overlap is P1; short boilerplate overlap is reviewed, not auto-flagged.

### Phase 5: PII / Secret Scan (full)

- Secrets: gitleaks-style pattern classes (API keys, cloud credentials, private-key blocks, bearer tokens) via `rg`, plus a streamed entropy check.
- PII: emails, phone numbers, card-shaped numbers, domain identifiers (account/order ids).
- Output `file:line | pattern class | count | severity`. Credential hits and training-data PII are P0; note that waiver disputes go to `ai-engineer:ai-security-auditor`.
- Note whether the scanned files are post-transformation — scrubs must re-run after every format conversion.

### Phase 6: License / Provenance

- Every batch has a `data/ledger/*.yaml` entry (source, SPDX license, `consent_class`, scrub status, sha256). A missing entry is a finding.
- HF datasets: card `license:` present and compatible; `dataset_info.json` consistent.
- `consent_class: restricted` in a train split is P1; unknown-license batches are flagged for the license gate.

### Phase 7: Distribution Stats

Full-stream counters: class balance by `task_type`/`source`, length percentiles (p50/p90/p99 in chars; tokens only if the project's tokenizer runs). Language mix on the sample. Flag dominant-class skew, tails past the training max length, and unexpected languages.

### Phase 8: Deep Pass

Use the Agent tool with `subagent_type="ai-engineer:ml-engineer"`. Prompt:

"Read-only deep audit of the datasets at {paths} (roles: {train/val/eval}). Raw results — schema: {summary}; duplication: {exact ratio (full), near-dup rate (sample={N}, seed={s})}; contamination: {pairs + eval-set version | not checked}; PII/secrets: {classes + counts, pointers only}; license/provenance: {ledger status}; distribution: {stats}. Intended use: {task class if known}. Assess fitness against `ai-engineer:dataset-curation`: size vs task-class range, system-turn policy, split hygiene (stratified by source/task_type, recorded seed), dataset versioning, and whether each flagged contamination pair is benign boilerplate or verbatim leakage. Don't edit files or quote scanned values. Return findings as `{file, line, check, severity (P0-P3), why, fix, confidence}` plus a remediation list; say so directly when a dimension is clean."

### Phase 9: Synthesis & Routing

Merge Phase 2-8 findings, dedupe at `{file, line}`, rank P0-P3, and route each remediation:

| Remediation kind | Route |
|------------------|-------|
| Mechanical fix (converter bug behind schema violations, format normalization, co-splitting a near-dup cluster) | `ai-engineer:ai-code-fixer` follow-up |
| Curation-process gap (no ledger, unseeded split, no version manifest, no decontamination step, scrub not re-run post-transform) | matching `ai-engineer:dataset-curation` pipeline stage |
| Secret/PII waiver dispute | `ai-engineer:ai-security-auditor` sign-off |

## Output Format

```markdown
## Dataset Audit Report

**Datasets:**
| Path | Records | Size | Format | DVC | Role |
|------|---------|------|--------|-----|------|

**Coverage:** schema/exact-dup/PII/distribution = full stream; near-dup/language = sample {N}, seed {s}
**Contamination checked against:** {evals/<name>-vN.jsonl, …} | not checked — no eval set located

### Summary
{One or two sentences; if clean: "No material issues — the dataset is schema-valid, deduplicated, decontaminated, and scrubbed." Otherwise counts.}

| Priority | Count |
|----------|-------|
| P0 | {n} |
| P1 | {n} |
| P2 | {n} |
| P3 | {n} |

### Schema & Format
{% valid (full), violation classes with first line numbers}

### Duplication
{exact ratio (full); near-dup rate (sample {N}, seed {s}) | not measured; co-split violations}

### Contamination
{overlapping pairs + both-side pointers + eval-set version | not checked}

### PII / Secrets (pointers only)
| File:Line | Pattern class | Count | Severity |
|-----------|---------------|-------|----------|

### License / Provenance
{ledger coverage, consent classes, HF card licenses}

### Distribution
{class balance, length percentiles, language mix (sample {N})}

### P0 — Must Fix Before Training
| File:Line | Check | Why | Fix | Confidence |
|-----------|-------|-----|-----|------------|

### P1 / P2 / P3
{same table shape}

### Remediation Routing
| Item | Route |
|------|-------|
| {fix} | ai-engineer:ai-code-fixer (follow-up) |
| {gap} | dataset-curation § {stage} |

### Not Measured / Reduced Depth
- {near-dup: datasketch unavailable | contamination: no eval set | …}
```

## Error Handling

| Condition | Response |
|-----------|----------|
| No datasets found | `Error: No datasets detected — checked args, dvc.yaml outs, data/ + datasets/ dirs, and HF layouts under {path}.` Suggest an explicit path, e.g. `/ai-engineer:data-audit data/sft/train.jsonl`. |
| Parquet / arrow / csv | Stream via `uv run --with pyarrow python -c …` (or the csv module); without Python, list the file with a reduced-depth note. Schema checks beyond parsing apply to messages-format JSONL only. |
| No eval set located | Not an error: contamination "not checked", plus a P2 finding recommending a pinned eval set (`ai-engineer:eval-design`). |
| Too large for a full n-gram pass | Use a seeded sample and say so in Coverage. |
| `uv` / Python missing | Warn, print `curl -LsSf https://astral.sh/uv/install.sh \| sh`, continue with `rg`/`wc` checks; near-dup, entropy, and distribution depth reduced. |
| `datasketch` unavailable | Near-dup "not measured"; exact-dup still reported. |

## See Also

- `ai-engineer:dataset-curation` — the curation gates this audit checks.
- `${CLAUDE_PLUGIN_ROOT}/skills/_shared/severity-matrix.md` — P0-P3 definitions.
- `ai-engineer:eval-design` — building the eval sets contamination is measured against.
- `/ai-engineer:rag-audit` — corpus-side hygiene for retrieval pipelines fed from the same sources.
