# DV Stage Artifact Template (AI work)

Copy this to `.context/development-N.md` (`N` from `task.metadata.run_index`; e.g. `development-0.md`). H2 anchors are fixed by corpflow's anchor allow-list — keep them exactly as written (kebab-case, H2); AI sections nest as H3.

```markdown
---
handoff:
  stage: DV
  verdict: ok           # ok | blocked | escalate
  summary: "<what was implemented — ≤200 chars>"
  files_touched:        # REQUIRED for DV
    - src/rag/retriever.py
    - tests/test_retriever.py
  next_stage_focus: "<hint for DR/QA — ≤240 chars>"
  key_decisions: []
  open_questions: []
  remediation_consumed: []   # rework only (metadata.retry_count>0): gate_blockers[] addressed this run
  refs:
    plan: planning-0.md#requirements
    decisions: analyzing-0.md#decisions
---

# DV Development — <worktask_id>

## files-changed

| File | Change | Why |
|------|--------|-----|
| src/rag/retriever.py | <summary> | <reason> |

### decisions

- <non-obvious implementation choice + rationale; reference analyzing-N.md anchors>

### tool-invocations

- `uv run ruff check src tests`
- `uv run pytest -k retriever`
- `uv run python -m app.evals --suite rag-golden-v3 --baseline main`

## tests-added

| Test | Framework | Covers |
|------|-----------|--------|
| tests/test_retriever.py | pytest | <behavior> |
| evals/rag_golden.jsonl (v3) | LLM-judge harness | <capability, e.g. retrieval grounding> |

### build-evidence

- Python: <`python -VV` output — verify against your environment>
- Frameworks (uv.lock): <torch/transformers/peft/vllm versions as applicable>
- Lint/type: ruff clean; <pyright/mypy> clean on touched files
- Eval evidence (prompts/models/retrieval changed): <eval command>, eval-set <name+version>, metrics-vs-baseline table at <path> (or "not applicable — no behavior surface touched")
- Test transcript: .context/logs/<tool>-<worktask_id>.log

## deviations

- <departures from analyzing-N.md, or "None">

## follow-ups

- <deferred work, flagged risks, or "None">
```

## Notes

- **Screenshots**: AI/CLI work defaults `metadata.requires_screenshots: false` — no manifest needed. If the flag is unset/true and cannot be changed, write a **cli-fallback** manifest at `.context/images/<worktask_id>/screenshots.md` (rows with `source: cli-fallback` pointing at eval reports, loss-curve textual summaries, or test-transcript `.txt` files produced this run; `screenshot_count` = row count) before returning, or `dv-screenshot-gate.sh` blocks `SubagentStop`. See `workflow-integration/references/stage-details.md § Screenshot Gate for CLI Work`.
- **Training work**: smoke-scale only — capped `max_steps`/epochs on a data subsample; record the full-run launch plan under `### decisions`. See `workflow-integration/references/stage-details.md § DV Contract for AI Work`.
- `remediation_consumed:` is populated only on a rework re-dispatch — list the `metadata.gate_blockers[]` strings (from the DR/QA gate) this run fixed. See `workflow-integration/references/stage-details.md § Gate-Feedback Contract`.
- Frontmatter budget: ≤200 tokens, ≤30 lines. Emit it unconditionally — it is the state.json merge input regardless of filename.
- **state.json patch**: on completion run `state-patch.sh --stage DV --prev <PREV>` when its path is supplied (`task.metadata.state_patch_script`; ships under corpflow `skills/worktask/scripts/`) to merge `stages.DV` + the `<PREV>→DV` edge from this frontmatter; if the script/`jq`/`state.json` is absent, skip — never hand-roll the merge; Layers 2/3 repair from the frontmatter. See `workflow-integration/SKILL.md § Artifact Filename Contract`.
- Tee raw test/eval output to `.context/logs/` — the AI Build Evidence transcript path must exist on disk.
