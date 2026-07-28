# QA Stage Artifact Template (AI testing)

Primary artifact `.context/testing-N.md` is owned by igrsoft's qa-engineer; use this when ai-test-generator or an ai-engineer agent takes over QA or supplies the evidence body.

```markdown
---
handoff:
  stage: QA
  verdict: go           # go | no-go
  summary: "<test outcome — ≤200 chars>"
  files_touched:        # REQUIRED for QA (= tests added)
    - tests/test_retriever.py
  key_decisions:        # REQUIRED for QA (= results)
    - id: q1
      summary: "<suite result — ≤160 chars, e.g. '54/54 pass; eval gate green vs baseline'>"
      anchor: testing-0.md#results
  open_questions: []
  refs:
    development: development-0.md#tests-added
---

# QA Testing — <worktask_id>

## results

| Suite | Command | Result | Transcript |
|-------|---------|--------|------------|
| unit (pytest) | `uv run pytest` | 54/54 pass | .context/logs/pytest-<worktask_id>.log |
| eval regression | `uv run python -m app.evals --suite rag-golden-v3 --baseline main` | pass, 0 regressions above threshold | .context/logs/evals-<worktask_id>.log |
| lint/type | `uv run ruff check .` | clean | .context/logs/ruff-<worktask_id>.log |

Gate (both required for `go` — workflow-integration/references/stage-details.md § QA Gate):
- [ ] All tests pass (full suite, not only new tests)
- [ ] Eval regression gate holds where a harness exists (pinned eval-set version, temperature 0 / fixed seeds); no harness → gap recorded in ## regressions

## coverage

| Component | Tool | Line % | Target |
|-----------|------|--------|--------|
| src/rag | coverage.py | <n>% | per project threshold |

## regressions

- <failures vs. the pre-change baseline (test or eval metric), with suspected cause and owner, or "None">

## verdict

<go | no-go — one-line justification; on no-go list blocking defects>

## blocking-defects

<no-go only — these become `metadata.gate_blockers[]` verbatim on DV re-dispatch; omit the section on go>
- <self-contained, actionable string with file:line / failing test name / regressed metric vs. baseline>
```

## Notes

- Eval evidence is part of the gate, not optional garnish: run the harness with the pinned eval-set version and deterministic settings (temperature 0 / fixed seeds); attach the transcript path and the metrics-vs-baseline table. Where no harness covers the touched capability, record the gap explicitly — never silently pass.
- Every transcript path in `## results` must exist under `.context/logs/`.
- Test selection for focused re-runs: `pytest -k <expr>`, a single eval slice (`--suite <name> --limit <n>`).
- Frontmatter budget: ≤200 tokens, ≤30 lines.
