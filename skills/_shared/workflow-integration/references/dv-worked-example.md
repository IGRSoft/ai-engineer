# Worked Example — DV Takeover by `llm-engineer`

One concrete end-to-end DV handoff with real values, not placeholders. The schema itself is in [stage-details.md § Handoff Frontmatter](stage-details.md#handoff-frontmatter-v400-schema); the blank template is [../templates/dv-development.md](../templates/dv-development.md).

Scenario: worktask `wt-118` adds a reranking step to an existing RAG retriever. `company-workflow:developer` detects the `ai` platform key and delegates DV to `ai-engineer:llm-engineer`.

## 1. Dispatch metadata

The orchestrator stamps this on the DV task before `Task()`:

```json
{
  "metadata": {
    "agent": "ai-engineer:llm-engineer",
    "model": "opus",
    "error_file": ".context/errors/llm-engineer.md",
    "requires_screenshots": false,
    "ui_visual_check": false,
    "test_mode": "scoped",
    "plan_file": "planning-0.md",
    "run_index": 0,
    "retry_count": 0,
    "workspace_path": ".worktrees/wt-118"
  }
}
```

`error_file` basename is `llm-engineer` — the last `:`-separated segment of the qualified agent name, never a shared `error.md`. `requires_screenshots: false` is the plugin default; with it set, `dv-screenshot-gate.sh` is skipped and no manifest is written.

## 2. Emitted artifact frontmatter

`llm-engineer` writes `.context/development-0.md` opening with:

```yaml
---
handoff:
  stage: DV
  verdict: ok
  summary: "Added cross-encoder rerank stage to RAG retriever; top-5 grounding +6.2pt on rag-golden-v3"
  files_touched:
    - src/rag/retriever.py
    - src/rag/rerank.py
    - tests/test_rerank.py
  next_stage_focus: "Review rerank timeout/fallback path and the added model-revision pin; eval delta is in build-evidence"
  key_decisions: []
  open_questions: []
  remediation_consumed: []
  refs:
    plan: planning-0.md#requirements
    decisions: analyzing-0.md#decisions
---
```

`verdict` uses the DV vocabulary (`ok` / `blocked` / `escalate`) — not DR's `pass`/`fail` or QA's `go`/`no-go`. `files_touched` and `next_stage_focus` are the DV-required additions to the base fields.

## 3. Build Evidence supplied instead of screenshots

Under `## tests-added` → `### build-evidence`, with every path existing on disk:

```markdown
- Python: 3.14.0 (main, Oct  7 2026, 09:12:44) [Clang 17.0.0]
- Frameworks (uv.lock): transformers 4.57.1, sentence-transformers 3.4.0
- Lint/type: ruff clean; pyright clean on touched files
- Eval evidence: `uv run python -m app.evals --suite rag-golden-v3 --baseline main`,
  eval-set rag-golden-v3, metrics-vs-baseline at .context/logs/evals-wt-118.md
- Test transcript: .context/logs/pytest-wt-118.log
```

The eval evidence row is mandatory here because retrieval behavior changed. Both log paths were produced by *this* run — QA direct-reads them and re-opens DV on a stale or byte-identical transcript.

## 4. Return summary

`llm-engineer` returns ≤500 tokens to the orchestrator: what changed, the eval delta, the artifact path, and anything DR should look at first. The full detail stays in `development-0.md` — the return is a pointer, not a copy.

## 5. On a DR `fail` re-dispatch

`run_index` bumps, `retry_count` becomes 1, and `metadata.gate_blockers[]` arrives verbatim in the prompt. `llm-engineer` fixes only those blockers, lists them in `remediation_consumed:`, and records per-blocker resolution in `.context/errors/llm-engineer.md` — see [stage-details.md § Gate-Feedback Contract](stage-details.md#gate-feedback-contract-v400).
