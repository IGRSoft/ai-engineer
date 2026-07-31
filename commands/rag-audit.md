---
description: Read-only RAG pipeline audit — map ingest→chunk→embed→index→retrieve→rerank→assemble→generate→cite from code, grade each stage against rag-systems checklists, run retrieval evals where a harness exists. Use when RAG answers hallucinate or go stale.
argument-hint: [path (default .)] [--focus chunking|embedding|retrieval|generation|security] [--no-eval]
allowed-tools: Read, Glob, Grep, Bash
estimated-cost:
  min-tokens: 5000
  max-tokens: 20000
  model-distribution:
    sonnet: 90%
    opus: 10%
---

# RAG Audit
<!-- Updated: July 2026 -->

Audit a retrieval-augmented generation pipeline end to end, read-only. Map the pipeline as implemented (not as documented) straight from the code, grade every present stage against the `skills/llm-apps/rag-systems` checklists, run the retrieval eval harness when one exists, and fan out to the LLM engineer for the deep pass plus the security auditor for the injection/ACL slice. The deliverables are the discovered pipeline map and a P0-P3 findings report with grounding and freshness issues called out explicitly.

[Extended thinking: Most "the model hallucinates" bugs are retrieval bugs wearing a disguise, and most RAG audits fail by reviewing the prompt while ignoring the index. This command starts from code: it discovers which of the nine stages actually exist, and it emits that map as the first deliverable — because missing stages are findings in themselves (no refusal rule, no ACL pre-filter, no citations), not gaps in the audit. Metrics discipline is absolute: recall@k/MRR appear only when a harness executed this run; otherwise the report says "not measured" in plain words — a plausible invented number is strictly worse than an honest gap. The security slice runs in parallel with the deep audit because retrieved content is untrusted input and ACL enforcement is a store-side security boundary, never a prompt nicety. Everything is read-only; remediation is routed, not applied.]

## CRITICAL BEHAVIORAL RULES

You MUST follow these rules exactly. Violating any of them is a failure.

1. **Strictly read-only.** No Write, no Edit, no index mutations, no config changes. Every Bash invocation is a query (grep, wc, `uv run` of an existing harness) — never a mutation. Remediation is routed in the report, not applied here.
2. **Map first, audit second.** Emit the discovered pipeline map (stage → implementation → `file:line`, or MISSING) before any finding. A missing stage is itself a finding, graded by consequence: absent rerank may be fine; absent refusal rule, citations, or ACL pre-filter is not.
3. **No invented metrics.** Report recall@k / MRR / nDCG only from a harness executed this run. No harness, or a harness that fails → the metrics section reads "NOT MEASURED", stated plainly. Never estimate, never extrapolate, never quote stale numbers as current.
4. **Grade against the checklists — no manufactured findings.** Each present stage is audited against `skills/llm-apps/rag-systems` (and its references). A clean stage is reported clean; do NOT invent P2/P3 nits to fill the tables.
5. **The security slice always runs.** Injection hardening on retrieved content and ACL filtering go to `ai-engineer:ai-security-auditor` in parallel with the deep audit. ACL enforcement that lives only in the prompt is a P0/P1, never a style note.
6. **Normalize every finding** to `{file:line, stage, category, severity (P0-P3), why, fix, confidence}` per `skills/_shared/severity-matrix.md`, and call out grounding + freshness issues in their own report section.
7. **Tool-missing never hard-fails.** `uv`/`pytest` absent → print the install hint, continue the static audit, and mark metrics "not measured (no runnable harness)". Never abort the audit over a missing tool.
8. **Never enter plan mode.** This command IS the procedure — execute it.

## Usage

```bash
# Audit the RAG pipeline discovered under the current directory
/ai-engineer:rag-audit

# Audit a specific service
/ai-engineer:rag-audit services/kb-search/

# Deep-dive one dimension only
/ai-engineer:rag-audit --focus retrieval

# Static audit only — skip the eval harness run
/ai-engineer:rag-audit --no-eval
```

## Options

| Option | Default | Effect |
|--------|---------|--------|
| `path` | `.` | Root to scan for the pipeline. |
| `--focus chunking\|embedding\|retrieval\|generation\|security` | all | Restrict Phase 2/4 depth to one dimension. The pipeline map (Phase 1) always covers all stages. |
| `--no-eval` | off | Skip Phase 3 even when a harness exists; metrics report "not measured (skipped by --no-eval)". |

## Workflow

### Phase 1: Map the Pipeline from Code

Grep-driven discovery over `{path}` — find each stage's implementation, or establish that it is missing:

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

**Emit the map before anything else** (Rule 2), each row anchored `file:line` or marked MISSING with the consequence graded.

### Phase 2: Static Stage Audit (checklists)

Audit every present stage against `skills/llm-apps/rag-systems`:

- **Chunking** — strategy fits the content type (prose/code/tables/chat/legal table); tables never split mid-row, code never split mid-function; sizes/overlap measured, not tutorial-copied. Deep dive: `references/chunking-strategies.md`.
- **Embedding** — model + revision pinned and recorded in collection metadata; one model per collection; input window ≥ max chunk size; re-embed handled as a blue-green collection swap.
- **Index lifecycle** — stable `doc_id`/`content_hash` upserts, `indexed_at` recorded, delete path removes all chunks (must-not-retrieve verification exists).
- **Retrieval** — hybrid dense+sparse (or eval-justified BM25-only); exact-identifier queries covered; k matches what the prompt actually receives; tenant/ACL/date filters applied **store-side as pre-filters**.
- **Rerank** — present with recall@50-vs-precision@5 rationale, or absent with healthy first-stage precision; not cargo-culted either way.
- **Grounded generation** — per-claim citations against stable chunk ids; explicit refusal rule with a no-evidence eval slice; freshness stamps ("as of <date>"); low temperature for factual QA.
- **Injection hardening** — retrieved text delimited as data with an ignore-instructions-inside rule; delimiter-collision escaping; model output validated at trust boundaries (`skills/prompt-engineering/prompt-design` hierarchy).

### Phase 3: Retrieval Eval (when a harness exists; skipped by `--no-eval`)

1. Locate the harness: `tests/eval_retrieval*.py`, versioned `evals/retrieval-v*.jsonl`, documented eval runner modules.
2. Run it scoped and deterministic, e.g. `uv run pytest tests/eval_retrieval.py -q` (single command; per `references/retrieval-evaluation.md`). Inside a worktask, tee the transcript to `.context/logs/` (`company-workflow:logging-conventions`).
3. Compare against the repo's recorded baseline/thresholds where they exist (harness `THRESHOLDS`, metrics artifacts); report per-archetype breakdowns when the harness emits them — a healthy mean hides a dead archetype.
4. **No harness** → metrics "NOT MEASURED" + a finding: no labeled retrieval eval set is a red flag per the skill (typically P2). **Harness fails** → metrics "NOT MEASURED (harness failed: {stage})" + a finding. Never substitute an estimate (Rule 3).

### Phase 4: Parallel Deep Audit

Launch both simultaneously — they are independent and read-only:

**Use Task tool with subagent_type="ai-engineer:llm-engineer"**
Prompt: "Read-only deep audit of the RAG pipeline at {path}. Pipeline map: {map with file:line anchors}. Static findings so far: {phase-2 findings}. Eval status: {metrics or NOT MEASURED}. {--focus: 'Restrict depth to {dimension}.'} Audit each present stage's implementation quality against `skills/llm-apps/rag-systems` — chunking fit, embedding/revision pinning, index lifecycle (sync, deletes, re-embed), hybrid/rerank rationale, grounded-generation rules (citations, refusal, freshness), and apply the debug order (fix the first failing layer — never the prompt to mask a retrieval miss). Do NOT edit any file. Return findings as `{file, line, stage, category, severity (P0-P3), why, fix, confidence}`. If a stage is clean, say so directly."

**Use Task tool with subagent_type="ai-engineer:ai-security-auditor"**
Prompt: "Read-only injection/ACL audit of the RAG pipeline at {path}. Pipeline map: {map}. Cover: poisoned-document prompt injection through retrieved content (delimiting, ignore-instructions rule, delimiter-collision escaping), ACL/tenant filtering enforced store-side vs prompt-side, leakage through citations or evidence blocks, unvalidated model output reaching trust boundaries, and OWASP LLM Top 10 mapping where applicable. Return findings as `{file, line, stage, category, severity (P0-P3), why, fix, confidence}`. If a surface is clean, say so directly."

[SYNC POINT: Wait for both agents before synthesis.]

### Phase 5: Synthesis

1. Merge Phase 2/3/4 findings; deduplicate at `{file, line}` keeping the higher severity and the clearer fix, crediting both lenses.
2. Drop speculative claims without concrete anchors; per Rule 4, do not backfill.
3. Normalize, rank P0-P3, pull grounding + freshness issues into their own section, and emit the Output Format report.

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

### No RAG pipeline detected
```
Note: No embedding, vector-store, or retrieval markers found under {path}.
Suggestion: Pass the service root explicitly, e.g. /ai-engineer:rag-audit services/kb-search/
If retrieval lives behind a managed API, name the client module to audit the integration surface.
```

### Eval harness present but fails
Not silent: record the failing command and stage, mark metrics "NOT MEASURED (harness failed)", add a finding, and continue the static audit (Rule 7).

### `uv` unavailable
```
Warning: `uv` not found; cannot execute the retrieval eval harness.
Install: curl -LsSf https://astral.sh/uv/install.sh | sh   (verify against your toolchain)
Continuing with the static audit; metrics: NOT MEASURED.
```

### `--focus` names an absent stage
Report the stage as MISSING in the map with its graded consequence, and audit the nearest present neighbors (e.g. `--focus generation` with no citation plumbing still audits assemble/generate).

### Partial pipeline (framework-managed stages)
When a framework hides stages (a managed retriever, an opaque indexer), audit the visible configuration and integration surface, and mark hidden internals "not auditable from code" — never guess their behavior.

## See Also

- `skills/llm-apps/rag-systems` — the stage checklists, debug order, and lifecycle rules this audit grades against (`references/chunking-strategies.md`, `references/retrieval-evaluation.md`).
- `skills/prompt-engineering/prompt-design` — instruction hierarchy and untrusted-input delimiting behind the assemble-stage checks.
- `skills/evals/eval-design` / `skills/evals/regression-gates` — building the missing retrieval eval set and wiring it into CI.
- `skills/_shared/severity-matrix.md` — P0-P3 definitions used in the ranking.
- `ai-engineer:llm-engineer` / `ai-engineer:ai-security-auditor` — the deep-audit and injection/ACL agents this command fans out to.
- `/ai-engineer:prompt-optimize` — measured grounding-prompt iteration after retrieval is fixed (never before).
- `/ai-engineer:data-audit` — hygiene for the datasets and eval sets this pipeline is measured with.
