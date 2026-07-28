---
description: Read-only dataset quality audit for fine-tuning and eval sets — schema, dedup, train/test contamination, PII/secret scan, license/provenance, distribution stats into a P0-P3 report. Use before a training run or when eval scores look too good.
argument-hint: [dataset path(s) (default: auto-discover)] [--sample N (default 5000)] [--eval-set PATH]
allowed-tools: Read, Glob, Grep, Bash
estimated-cost:
  min-tokens: 4000
  max-tokens: 16000
  model-distribution:
    sonnet: 85%
    haiku: 15%
---

# Data Audit
<!-- Updated: July 2026 -->

Audit fine-tuning and eval datasets before they steer a training run: schema/format validation against the messages schema, exact + near-duplicate analysis, train/test contamination via n-gram overlap, a pointer-only PII/secret scan, license/provenance verification, and distribution statistics — synthesized with `ai-engineer:ml-engineer`'s deep pass into a P0-P3 report whose every remediation item is routed to an owner. Strictly read-only; large files are streamed or sampled, never loaded whole.

[Extended thinking: The dataset is the model behavior — it will faithfully learn the dups, the leaked secrets, and the contamination of the eval set you trust. This audit runs the dataset-curation gates in read-only mode, and its two disciplines are non-negotiable. First, honesty about coverage: cheap checks (schema, exact-dup hashing, pattern scans) stream the full file; expensive checks (MinHash near-dup, language ID) run on a seeded sample and say so — a number without its sample size is not evidence. Second, containment: a matched credential is reported as a file:line pointer and a pattern class, never echoed — copying a secret into a report is a second leak; and an audit that Reads a 2 GB JSONL into context is itself a defect, so every scanner is a streamed single-command `uv run python -c` or `rg` pass. Contamination is only claimed against a located, pinned eval set; absent one, the report says "not checked" instead of inventing an overlap.]

## CRITICAL BEHAVIORAL RULES

You MUST follow these rules exactly. Violating any of them is a failure.

1. **Strictly read-only.** No edits to datasets, ledgers, splits, or configs. Remediation is *routed* in the report (fixer / curation step), never applied here. Near-dup tooling runs ephemerally (`uv run --with datasketch …`) — never `uv add` into the project.
2. **Never echo sensitive values.** PII/secret findings are reported as `file:line` + pattern class + count ONLY. Never quote the matched value — not truncated, not masked, not "just the prefix". The report must be safe to paste anywhere.
3. **Stream or sample — never load a dataset via Read.** Sizes via `wc -l`/`stat`; scanners as streamed single-command `uv run python -c` or `rg` passes. The Read tool touches at most a small head/sample for eyeballing structure, never the body of a large file.
4. **Every sampled number states its sample size and seed** next to the value; full-pass checks say "full". A percentage without its denominator is not a finding.
5. **Contamination is only measured against a located eval set.** No pinned eval set found → "not checked — no eval set located", stated plainly. Never invent or extrapolate an overlap number.
6. **Normalize and route — no manufactured findings.** Findings are `{file:line, check, severity (P0-P3), why, fix, confidence}` per `skills/_shared/severity-matrix.md`; each remediation is routed (mechanical fix → `ai-engineer:ai-code-fixer` follow-up; process gap → its `skills/finetuning/dataset-curation` pipeline stage). A clean check is reported clean — do not backfill nits.
7. **Tool-missing degrades, never fails.** No `uv`/Python → `rg`/`wc`-level checks with a reduced-depth note; `datasketch` unavailable → near-dup "not measured". Print the hint, continue.
8. **Never enter plan mode.** This command IS the procedure — execute it.

## Usage

```bash
# Auto-discover datasets (dvc.yaml outs → data/ dirs → HF layouts) and audit them
/ai-engineer:data-audit

# Audit one training file
/ai-engineer:data-audit data/sft/train.jsonl

# Bigger near-dup/language sample
/ai-engineer:data-audit data/sft/ --sample 20000

# Check contamination against a specific eval set
/ai-engineer:data-audit data/sft/train.jsonl --eval-set evals/support-v3.jsonl
```

## Options

| Option | Default | Effect |
|--------|---------|--------|
| `dataset path(s)` | auto-discover | Files or directories to audit. See Phase 1 precedence. |
| `--sample N` | 5000 | Seeded sample size for the expensive checks (near-dup MinHash, language mix). Cheap checks always stream the full file. |
| `--eval-set PATH` | discover | Pin the eval set(s) contamination is measured against instead of discovering them. |

## Workflow

### Phase 1: Locate Datasets

Resolve top-down — first applicable source wins; union when several apply at the same level:

1. **Explicit args** — the given files/directories.
2. **DVC** — `dvc.yaml` stage `outs` plus `*.dvc` pointer files (these also carry the version hashes the report quotes).
3. **`data/` conventions** — `data/**/*.jsonl`, `datasets/**/*.jsonl`, `train/val/test`-named files.
4. **HF layouts** — `load_dataset(`/`save_to_disk(` call sites, dataset directories with `dataset_info.json`, dataset cards (`README.md` with `license:` frontmatter).

Print the inventory before any check: `path | records (wc -l) | size | format | dvc-tracked | role guess (train/val/eval)`. Classify roles now — contamination (Phase 4) needs the train-vs-eval distinction.

### Phase 2: Schema & Format Validation (full stream)

Stream every JSONL line through a validator (`uv run python -c` single command) against `skills/finetuning/dataset-curation` → `references/data-formats.md`:

- Line parses as one JSON object; `messages` present for SFT records.
- Roles ∈ `system|user|assistant` (+ `tool` only where the chat template supports it); at most one system turn, only at index 0.
- Strict user/assistant alternation; final turn is `assistant`; `content` non-empty.
- Preference pairs: `chosen`/`rejected` share the identical `prompt`; responses are assistant turns.
- One system-turn policy dataset-wide (mixed policies are a finding).

Report % valid (full count) and the first ~10 violating line numbers per violation class.

### Phase 3: Duplication (exact full, near-dup sampled)

- **Exact**: normalized (lowercase, whitespace-collapsed) sha256 over the full stream → dup count/ratio.
- **Near**: MinHash/LSH (Jaccard ≥ 0.85) over the seeded sample of `--sample` records via `uv run --with datasketch python -c …` → estimated near-dup cluster rate; state `sample={N}, seed={s}` (Rule 4). Unavailable → "not measured".
- Flag near-dup clusters that straddle a train/val boundary (co-split violation → leaked validation).

### Phase 4: Train/Test Contamination

1. Identify eval sides: `--eval-set` > discovered `evals/*-v*.jsonl` > val/test splits from Phase 1. None → "not checked — no eval set located" (Rule 5) and move on.
2. Build an n-gram index (8-13 token windows, tuned to text lengths) over the eval records; stream train records against it. Full pass when sizes allow; otherwise sampled — stated.
3. Report overlapping pair counts with line pointers on both sides, and note which eval-set version the check ran against. Verbatim question/answer overlap is P1 (train/test contamination per the severity matrix); short boilerplate overlap is reviewed, not auto-flagged.

### Phase 5: PII / Secret Scan (full stream, pointers only)

- **Secrets**: gitleaks-style pattern classes (API keys, cloud credentials, private-key blocks, bearer tokens) via `rg`, plus a streamed entropy check for high-entropy strings.
- **PII**: pattern classes for emails, phone numbers, card-shaped numbers, and domain identifiers (account/order ids).
- Output per Rule 2: `file:line | pattern class | count | severity` — values never echoed. Credential hits and training-data PII exposure are P0 (`skills/_shared/severity-matrix.md`); waiver disputes route to `ai-engineer:ai-security-auditor`, noted in the report.
- Note whether the scan ran on post-transformation data — scrubs must be re-run after every format conversion.

### Phase 6: License / Provenance

- **Ledger presence**: every discovered batch has a `data/ledger/*.yaml` entry (source, SPDX license, `consent_class`, scrub status, sha256) per `skills/finetuning/dataset-curation`. Missing entry = finding: a batch without a ledger entry does not exist for training purposes.
- **HF datasets**: dataset-card `license:` field present and compatible; `dataset_info.json` consistency.
- `consent_class: restricted` material in a train split is a P1; unknown-license batches are flagged for the license gate.

### Phase 7: Distribution Stats

Streamed counters over the full file: class balance by `task_type`/`source` keys, length percentiles (p50/p90/p99, chars; token estimates only when the project's tokenizer is runnable). Language mix on the seeded sample (`sample={N}, seed={s}`). Flag dominant-class skew, truncation-risk tails vs the training max length, and unexpected languages.

### Phase 8: Deep Pass (delegate)

**Use Task tool with subagent_type="ai-engineer:ml-engineer"**
Prompt: "Read-only deep audit of the datasets at {paths} (roles: {train/val/eval}). Raw results — schema: {summary}; duplication: {exact ratio full, near-dup rate sample={N} seed={s}}; contamination: {pairs + eval-set version | not checked}; PII/secrets: {classes + counts, pointers only}; license/provenance: {ledger status}; distribution: {stats}. Intended use: {task class if known}. Assess fitness against `skills/finetuning/dataset-curation`: size-vs-task-class working ranges, system-turn policy, split hygiene (stratification by source/task_type, recorded seed), dataset versioning (DVC/hash manifest quoted with metrics), and review the flagged contamination pairs for benign-boilerplate vs verbatim leakage. Do NOT edit any file, and never echo scanned values. Return findings as `{file, line, check, severity (P0-P3), why, fix, confidence}` plus a remediation list. If a dimension is clean, say so directly."

### Phase 9: Synthesis & Routing

Merge Phase 2-8 findings, deduplicate at `{file, line}`, rank P0-P3, and route every remediation item:

| Remediation kind | Route |
|------------------|-------|
| Mechanical fix (converter bug behind schema violations, format normalization, co-splitting a near-dup cluster) | `ai-engineer:ai-code-fixer` — follow-up change; NOT applied by this read-only command |
| Curation-process gap (no ledger, unseeded split, no version manifest, no decontamination step, scrub not re-run post-transform) | the matching `skills/finetuning/dataset-curation` pipeline stage |
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
{overlapping pairs + both-side pointers + eval-set version | not checked, stated plainly}

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

### No datasets found
```
Error: No datasets detected — checked args, dvc.yaml outs, data/ + datasets/ dirs, and HF layouts under {path}.
Suggestion: Pass explicit paths, e.g. /ai-engineer:data-audit data/sft/train.jsonl
```

### Non-JSONL formats (parquet / arrow / csv)
Stream via `uv run --with pyarrow python -c …` (or the csv module) when Python is available; otherwise record the file with a reduced-depth note. Schema conformance beyond structural parsing applies to messages-format JSONL only.

### No eval set located
Not an error: contamination reads "not checked — no eval set located" (Rule 5), plus a P2 finding recommending a pinned eval set (`skills/evals/eval-design`).

### File too large for a full n-gram pass
Fall back to a seeded sample and state it in Coverage — never silently downgrade a "full" claim.

### `uv` / Python unavailable
```
Warning: `uv` not found — deep scanners unavailable.
Install: curl -LsSf https://astral.sh/uv/install.sh | sh   (verify against your toolchain)
Continuing with rg/wc-level checks; near-dup, entropy, and distribution depth reduced.
```

### `datasketch` unavailable under `uv run --with`
Near-dup reads "not measured"; exact-dup (full) still reported. Never guess a near-dup rate.

## See Also

- `skills/finetuning/dataset-curation` — the curation pipeline whose gates this audit checks read-only (`references/data-formats.md` for the schemas and masking rules).
- `skills/evals/eval-design` — building and versioning the eval sets contamination is measured against.
- `skills/mlops/experiment-tracking` — dataset versions quoted next to every downstream metric.
- `skills/_shared/severity-matrix.md` — P0-P3 definitions (leaked secrets/PII = P0, contamination = P1).
- `ai-engineer:ml-engineer` — the deep-pass agent; `ai-engineer:ai-code-fixer` — mechanical-fix follow-ups; `ai-engineer:ai-security-auditor` — secret/PII waiver sign-off.
- `/ai-engineer:rag-audit` — corpus-side hygiene for retrieval pipelines fed from the same sources.
