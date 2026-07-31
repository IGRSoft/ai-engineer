# DR Stage Artifact Template (AI review)

Primary artifact `.context/developer-review-N.md` is owned by company-workflow's technical-lead; use this when an ai-engineer agent takes over DR or contributes the review body. ai-code-fixer appends retry narratives to `.context/errors/ai-code-fixer.md` instead.

```markdown
---
handoff:
  stage: DR
  verdict: pass         # pass | fail
  summary: "<review outcome — ≤200 chars>"
  key_decisions:        # REQUIRED for DR (= findings)
    - id: f1
      summary: "<P0 finding — ≤160 chars>"
      anchor: developer-review-0.md#findings
  files_touched: []     # only when ai-code-fixer applied fixes
  next_stage_focus: "<security surface / eval focus for SR/QA — ≤240 chars>"
  refs:
    development: development-0.md#files-changed
---

# Developer Review — <worktask_id>

## findings

| ID | Priority | Area | Location | Issue | Fix |
|----|----------|------|----------|-------|-----|
| f1 | P0 | Prompt injection | src/agent/tools.py:42 | <issue> | <fix> |

Checked areas (AI criteria — see workflow-integration/references/stage-details.md § DR AI Review Criteria):
- [ ] Prompt & injection surfaces: untrusted input isolated from privileged instructions, output validated at trust boundaries
- [ ] Provider-call discipline: timeouts + retry/backoff, bounded token spend, no swallowed API errors, verified model IDs
- [ ] Training discipline: smoke-scale in DV, seeds pinned, full-run launch plan documented, loss curve sane
- [ ] Unsafe constructs: pickle.loads/torch.load on untrusted checkpoints, eval on model output, shell=True from agent tools, unpinned HF revisions
- [ ] Reproducibility hygiene: ruff + type-check clean, uv.lock current, model revisions + eval-set versions pinned, no committed checkpoints

## verdict

<pass | fail — with one-line justification tied to findings>

## blockers

- <P0/P1 findings that force verdict: fail — these become metadata.gate_blockers[] verbatim on DV re-dispatch; empty list when pass>

## follow-ups

- <P2/P3 findings deferred to backlog, or "None">
```

## Notes

- `blockers` entries are injected **verbatim** into the DV retry prompt (Gate-Feedback Contract) — write them as self-contained, actionable strings with `file:line`.
- Priorities follow `_shared/severity-matrix.md` (P0 = prompt injection/leaked secrets/unsafe deserialization, P1 = eval regression/unpinned revision/ungated tool execution, P2 = quality, P3 = style).
- ai-code-fixer on a fix-application pass: populate `files_touched`, enforce minimal diff, and record per-blocker resolution in `.context/errors/ai-code-fixer.md`.
