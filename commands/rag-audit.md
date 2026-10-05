---
description: Read-only RAG pipeline audit — map ingest→chunk→embed→index→retrieve→rerank→assemble→generate→cite from code, grade each stage against rag-systems checklists, run retrieval evals where a harness exists. Use when RAG answers hallucinate or go stale.
argument-hint: [path (default .)] [--focus chunking|embedding|retrieval|generation|security] [--no-eval]
allowed-tools: Read, Agent, Glob, Grep, Bash
---

# RAG Audit

Audit a retrieval-augmented generation pipeline end to end, read-only. Map the pipeline as implemented (not as documented) from the code, grade every present stage against the `ai-engineer:rag-systems` checklists, run the retrieval eval harness when one exists, and fan out to the LLM engineer for the deep pass and the security auditor for the injection/ACL slice. Deliverables: the pipeline map and a P0-P3 findings report with grounding and freshness issues called out. Start from code, not the prompt, because most "the model hallucinates" bugs are retrieval bugs.

## Rules

1. **Read-only.** No file edits, index mutations, or config changes; Bash is for queries (grep, wc, `uv run` of an existing harness). Remediation is routed in the report, not applied.
2. **Map first.** Emit the pipeline map (stage → implementation → `file:line`, or MISSING) before any finding. A missing stage is itself a finding, graded by consequence: absent rerank may be fine; absent refusal rule, citations, or ACL pre-filter is not.
3. **Report only measured metrics.** recall@k / MRR / nDCG come only from a harness executed this run. No harness, a failing harness, or `--no-eval` → the metrics section reads "NOT MEASURED" with the reason; no estimates or stale numbers, because a plausible invented number is worse than an honest gap.
4. **Grade against the checklists.** Each present stage is audited against `ai-engineer:rag-systems` and its references. A clean stage is reported clean; don't add P2/P3 nits to fill the tables.
5. **The security slice always runs**, in parallel with the deep audit, because retrieved content is untrusted input and ACL enforcement is a store-side boundary. ACL enforcement that lives only in the prompt is P0/P1.
6. **Normalize every finding** to `{file:line, stage, category, severity (P0-P3), why, fix, confidence}` per `${CLAUDE_PLUGIN_ROOT}/skills/_shared/severity-matrix.md`.
7. **A missing tool reduces depth, never aborts.** `uv`/`pytest` absent → print the install hint, continue the static audit, metrics "NOT MEASURED (no runnable harness)".
8. Execute directly; don't enter plan mode.

## Usage

```bash
/ai-engineer:rag-audit                              # pipeline under the current directory
/ai-engineer:rag-audit services/kb-search/          # a specific service
/ai-engineer:rag-audit --focus retrieval            # deep-dive one dimension
/ai-engineer:rag-audit --no-eval                    # static audit only
```

## Options

| Option | Default | Effect |
|--------|---------|--------|
| `path` | `.` | Root to scan for the pipeline. |
| `--focus chunking\|embedding\|retrieval\|generation\|security` | all | Restrict Phase 2/4 depth to one dimension. The Phase 1 map always covers all stages. |
| `--no-eval` | off | Skip Phase 3 even when a harness exists; metrics "NOT MEASURED (skipped by --no-eval)". |

## Workflow

### Phase 1: Map the Pipeline from Code

Grep `{path}` for each stage's implementation, or establish that it is missing:

| Stage | Discovery markers |
|-------|-------------------|
| ingest | loaders/connectors, source pulls, ACL/tenant/date metadata tagged at ingest |
| chunk | splitter code (header/recursive/AST splitters), size + overlap constants |
| embed | embedding client calls, model name/revision constants, collection metadata writes |
| index | vector-store client (pgvector, qdrant, faiss, chroma, pinecone, …), upsert/delete paths, sparse/BM25 index alongside |
| retrieve | similarity query, top-k constants, store-side metadata pre-filters, hybrid fusion (RRF) |
| rerank | cross-encoder / rerank API calls, top-k→n cutoffs |
| assemble | grounded prompt template, evidence delimiting, truncation handling |
| generate | provider call, temperature, structured-output enforcement |
| cite | chunk-id plumbing into per-claim markers, freshness stamps, refusal string |

Emit the map (Rule 2).

### Phase 2: Static Stage Audit (checklists)

Audit every present stage against `ai-engineer:rag-systems`:

- **Chunking** — strategy fits the content type (prose/code/tables/chat/legal table); tables never split mid-row, code never split mid-function; sizes/overlap measured, not tutorial-copied. Deep dive: `references/chunking-strategies.md`.
- **Embedding** — model + revision pinned and recorded in collection metadata; one model per collection; input window ≥ max chunk size; re-embed handled as a blue-green collection swap.
- **Index lifecycle** — stable `doc_id`/`content_hash` upserts, `indexed_at` recorded, delete path removes all chunks (must-not-retrieve verification exists).
- **Retrieval** — hybrid dense+sparse (or eval-justified BM25-only); exact-identifier queries covered; k matches what the prompt actually receives; tenant/ACL/date filters applied **store-side as pre-filters**.
- **Rerank** — present with recall@50-vs-precision@5 rationale, or absent with healthy first-stage precision; not cargo-culted either way.
- **Grounded generation** — per-claim citations against stable chunk ids; explicit refusal rule with a no-evidence eval slice; freshness stamps ("as of <date>"); low temperature for factual QA.
- **Injection hardening** — retrieved text delimited as data with an ignore-instructions-inside rule; delimiter-collision escaping; model output validated at trust boundaries (`ai-engineer:prompt-design` hierarchy).

### Phase 3: Retrieval Eval (when a harness exists, unless `--no-eval`)

1. Locate the harness: `tests/eval_retrieval*.py`, versioned `evals/retrieval-v*.jsonl`, documented eval runner modules.
2. Run it scoped and deterministic as a single command, e.g. `uv run pytest tests/eval_retrieval.py -q` (per `references/retrieval-evaluation.md`). Inside a worktask, append the transcript to a log under `.context/logs/` with `>> <log> 2>&1` (not a `tee` pipe, so the exit code is the tool's own).
3. Compare against the repo's recorded baseline/thresholds where they exist (harness `THRESHOLDS`, metrics artifacts); report per-archetype breakdowns when the harness emits them — a healthy mean hides a dead archetype.
4. No harness → metrics "NOT MEASURED" plus a finding (no labeled retrieval eval set, typically P2). Harness fails → "NOT MEASURED (harness failed: {stage})" plus a finding.

### Phase 4: Parallel Deep Audit

Launch both in one message with the Agent tool; they are independent and read-only. Wait for both before synthesis.

**`subagent_type="ai-engineer:llm-engineer"`** — prompt: "Read-only deep audit of the RAG pipeline at {path}. Pipeline map: {map with file:line anchors}. Static findings so far: {phase-2 findings}. Eval status: {metrics or NOT MEASURED}. {--focus: 'Restrict depth to {dimension}.'} Audit each present stage's implementation quality against `ai-engineer:rag-systems` — chunking fit, embedding/revision pinning, index lifecycle (sync, deletes, re-embed), hybrid/rerank rationale, grounded-generation rules (citations, refusal, freshness), and apply the debug order (fix the first failing layer, not the prompt to mask a retrieval miss). Don't edit any file. Return findings as `{file, line, stage, category, severity (P0-P3), why, fix, confidence}`. If a stage is clean, say so."

**`subagent_type="ai-engineer:ai-security-auditor"`** — prompt: "Read-only injection/ACL audit of the RAG pipeline at {path}. Pipeline map: {map}. Cover: poisoned-document prompt injection through retrieved content (delimiting, ignore-instructions rule, delimiter-collision escaping), ACL/tenant filtering enforced store-side vs prompt-side, leakage through citations or evidence blocks, unvalidated model output reaching trust boundaries, and map each finding to its OWASP LLM Top 10 2025 ID (mainly LLM01 prompt injection, LLM08 vector and embedding weaknesses, LLM05 improper output handling) where applicable. Return findings as `{file, line, stage, category, severity (P0-P3), why, fix, confidence}`. If a surface is clean, say so."

### Phase 5: Synthesis

1. Merge Phase 2/3/4 findings; deduplicate at `{file, line}` keeping the higher severity and the clearer fix, crediting both lenses.
2. Drop claims without concrete anchors.
3. Rank P0-P3, pull grounding and freshness issues into their own section, and emit the Output Format report.

## Output Format

```markdown
## RAG Audit Report

**Target:** {path}
**Mode:** {full | --focus {dim} | --no-eval}

### Pipeline Map
| Stage | Status | Implementation | Anchor |
|-------|--------|----------------|--------|
| ingest | present | {lib/approach} | {file}:{line} |
| rerank | MISSING | — | finding P{n} / accepted: {rationale} |

### Retrieval Metrics
{recall@{k} = {v}, MRR = {v} on {evals/retrieval-vN.jsonl} ({M} queries, k={k}) vs baseline {v} — per-archetype: {…}}
{— or —}
NOT MEASURED — {no labeled eval harness in the repo | harness failed: {stage} | skipped by --no-eval}.

### Summary
{One or two sentences. If clean: "No material issues — the pipeline is well-grounded and its lifecycle is sound." Otherwise counts by priority.}

| Priority | Count |
|----------|-------|
| P0 | {n} |
| P1 | {n} |
| P2 | {n} |
| P3 | {n} |

### P0 — Must Fix
| File:Line | Stage | Category | Why | Fix | Confidence |
|-----------|-------|----------|-----|-----|------------|

### P1 / P2 / P3
{same table shape}

### Grounding & Freshness
- Citations: {per-claim ids present | absent — finding ref}
- Refusal: {explicit rule + eval slice | absent — finding ref}
- Freshness: {stamps surfaced | silence implies current — finding ref}

### Reduced-Depth Notes
- {missing tool / skipped pass / harness status}
```

## Error Handling

| Condition | Response |
|-----------|----------|
| No RAG pipeline detected | `Note: No embedding, vector-store, or retrieval markers found under {path}.` Suggest passing the service root (e.g. `/ai-engineer:rag-audit services/kb-search/`), or naming the client module if retrieval lives behind a managed API. |
| Eval harness fails | Record the failing command and stage, mark metrics "NOT MEASURED (harness failed)", add a finding, continue the static audit. |
| `uv` unavailable | `Warning: uv not found; cannot execute the retrieval eval harness. Install: curl -LsSf https://astral.sh/uv/install.sh \| sh (verify against your toolchain). Continuing with the static audit; metrics: NOT MEASURED.` |
| `--focus` names an absent stage | Mark it MISSING in the map with its graded consequence, and audit the nearest present neighbors (e.g. `--focus generation` with no citation plumbing still audits assemble/generate). |
| Framework-managed stages | Audit the visible configuration and integration surface; mark hidden internals "not auditable from code" rather than guessing their behavior. |

## See Also

- `ai-engineer:rag-systems` — stage checklists, debug order, lifecycle rules; `references/embedding-and-index-tuning.md` for HNSW/IVF parameters, index memory, score normalization, and fusion when a finding is "index tuned by guesswork".
- `ai-engineer:prompt-design` — instruction hierarchy and untrusted-input delimiting behind the assemble-stage checks.
- `ai-engineer:eval-design` / `ai-engineer:regression-gates` — building the missing retrieval eval set and wiring it into CI.
- `/ai-engineer:prompt-optimize` — measured grounding-prompt iteration after retrieval is fixed.
- `/ai-engineer:data-audit` — hygiene for the datasets and eval sets this pipeline is measured with.
