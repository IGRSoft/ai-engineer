# Workflow Integration — Stage Details

Per-stage contracts for ai-engineer agents inside the corpflow worktask pipeline. Read alongside [../SKILL.md](../SKILL.md) (pipeline, invocation, artifact filename contract, agent names).

## AR Consultation Model

`corpflow:software-architector` **owns the AR stage** and its `analyzing-N.md` artifact. `ai-architector` is consulted, never handed ownership:

1. It writes the full analysis to `.context/ai-architecture.md` — ADR-style: chosen option, rejected options with the criterion each failed, consequences, revisit triggers.
2. It returns a compressed recommendation of **≤500 tokens**, not the document body.
3. `software-architector` merges that return into `analyzing-N.md` and stays the handoff author for the `PL→AR` edge.

`.context/ai-architecture.md` carries its own `handoff:` frontmatter (`stage: AR`, `key_decisions` required) so the consultation survives a lost merge.

**Stage-owner exception**: when `task.metadata.agent` names `ai-engineer:ai-architector`, it owns `analyzing-N.md` directly; the ≤500-token cap then bounds the return summary only.

Template: [../templates/ar-consultation.md](../templates/ar-consultation.md).

## DV Contract for AI Work

The DV agent writes `.context/development-N.md`. Mandatory H2 anchors are fixed by corpflow's anchor allow-list (`handoff-protocol.md#anchor-allow-list`): `## files-changed`, `## tests-added`, `## deviations`, `## follow-ups`. AI-specific sections nest as H3 under them:

| Section | Anchor level | Content |
|---------|--------------|---------|
| Files Changed | `## files-changed` | File / change / why table |
| Decisions | `### decisions` (under files-changed) | Non-obvious implementation choices with rationale |
| Tool Invocations | `### tool-invocations` (under files-changed) | Exact lint/test/eval commands run (`uv run pytest`, `uv run ruff check`, `uv run python -m app.evals`, …) |
| Tests Added | `## tests-added` | Test files + eval suites, what each covers |
| AI Build Evidence | `### build-evidence` (under tests-added) | `python -VV`, key framework versions from `uv.lock` (torch/transformers/peft/vllm as applicable), ruff + type-check status, scoped test transcript path in `.context/logs/` — plus, when prompts/models/retrieval configs changed, an eval evidence row (eval command, eval-set version, metrics-vs-baseline table path) |
| Deviations | `## deviations` | Departures from `analyzing-N.md` decisions |
| Follow-ups | `## follow-ups` | Deferred work, flagged risks |

AI Build Evidence is non-negotiable: a DV artifact without a `python -VV` line, framework versions from `uv.lock`, a ruff/type-check status, and a test transcript path under `.context/logs/` is incomplete — and when prompts, models, or retrieval configs changed, so is one without the eval evidence row. Tee raw test/eval output to `.context/logs/<tool>-<worktask_id>.log`.

**Smoke-scale training rule** (the sanitizer-clause analog): DV never launches full training runs — cap `max_steps`/epochs on a data subsample, verify the loss curve moves (decreasing, no NaN), and document the full-run launch plan (command, data, expected duration/cost) in `development-N.md`. DR fails a DV artifact whose transcripts show an uncapped training invocation.

Source comments follow the compact code-documentation standard (`corpflow:code-comment-standard` / corpflow `skills/shared/code-documentation.md`): comment the non-obvious WHY and the contract only — never the WHAT, history, or call sites; rationale lives in the PR / `.context/development-N.md`. DR flags violations.

Copy-paste template: [../templates/dv-development.md](../templates/dv-development.md).

## Screenshot Gate for CLI Work (HIGHEST INTEGRATION RISK — read this)

corpflow's `dv-screenshot-gate.sh` blocks `SubagentStop` when `metadata.requires_screenshots != false` and no manifest exists at `.context/images/<worktask_id>/screenshots.md`. The corpflow default is **TRUE** — but AI/CLI work has no UI to screenshot. Handle it in this order:

1. **Preferred**: the dispatcher sets `metadata.requires_screenshots: false` for ai-engineer DV stages (non-UI changes). Then no manifest is required and the gate is skipped. Plugin norm: `requires_screenshots: false` is the **default expectation** for AI work — flag it in your return summary if the metadata says otherwise.
2. **cli-fallback procedure** (when the flag is unset/true and you cannot change it): produce the manifest anyway using terminal transcripts —
   - Capture each meaningful CLI surface as text: test run, eval report, loss-curve textual summary, `--help`, a representative invocation with real output. Save as `.txt`/`.md` under `.context/images/<worktask_id>/`.
   - Write `.context/images/<worktask_id>/screenshots.md` with one row per capture, `source: cli-fallback`, and a `notes` cell explaining why (e.g. "LLM pipeline, no UI; transcript capture").
   - Frontmatter `screenshot_count` MUST equal the number of table rows.
3. **Never** fabricate image files or return without either the `false` flag or a cli-fallback manifest — the gate re-dispatches DV until one exists.
4. **Evidence freshness**: every `cli-fallback` row — eval report, loss-curve textual summary, or test transcript — must be produced *this run* from the actual test/eval invocation — never reuse a transcript from a prior run or another workdir. corpflow QA direct-reads the evidence files and cross-checks them against the log paths recorded in the DV artifact's `### build-evidence` section; a stale or duplicated transcript is flagged and re-opens DV. This is the text-evidence corollary of rule 3 — the "never fabricate" integrity bar applies to reused transcripts as much as to invented image files.

Manifest row format mirrors corpflow's `dv-screenshot-capture` output: `| name | path | source | design_ref | notes |` with `source` ∈ {`cli-fallback`} for AI work; `design_ref` stays blank (no mockups for CLI).

`ui_visual_check` (the v4.0.0 DV metadata contract field) is **not applicable** to AI/CLI work — leave it `false`; it gates live-driven UI-capture provenance on UI platforms, which have no analog here.

## Per-Agent Error Files

Parallel-safe retry narratives live in `.context/errors/<agent-basename>.md` — basename = last `:`-separated segment of the qualified name (`task-system.md § error_file derivation`):

| File | Purpose |
|------|---------|
| `.context/errors/llm-engineer.md` | LLM-app DV retry narratives |
| `.context/errors/ml-engineer.md` | Training/fine-tuning DV retry narratives |
| `.context/errors/mlops-engineer.md` | Serving/pipeline DV retry narratives |
| `.context/errors/ai-prompt-engineer.md` | Prompt-optimization DV retry narratives |
| `.context/errors/ai-code-fixer.md` | DR fix-application retries |
| `.context/errors/<agent-basename>.md` | One file per agent — never overwrite a shared `error.md` |

Derive your own path from `task.metadata.error_file` or your frontmatter `name:`.

## DR AI Review Criteria

technical-lead reads `development-N.md` + error files and produces `developer-review-N.md` (verdict `pass`/`fail`). ai-engineer agents support DR and pre-check against these criteria before returning from DV:

| Area | What DR checks |
|------|----------------|
| Prompt & injection surfaces | Untrusted input never interpolated into privileged instruction segments; delimiting/privilege separation in place; model output validated before crossing a trust boundary (shell, DB, file APIs) |
| Provider-call discipline | Timeout + retry/backoff on every LLM call; streaming handled; token spend bounded; no swallowed API errors; model IDs/params verified, not guessed |
| Training discipline | DV runs are smoke-scale (capped `max_steps`/epochs on a subsample); seeds pinned; full-run launch plan documented; loss curve sane (decreasing, no NaN) |
| Unsafe constructs | `pickle.loads`/`torch.load` on untrusted checkpoints (use safetensors); `eval` on model output; `subprocess(..., shell=True)` reachable from agent tools; unpinned `revision` on HF downloads |
| Reproducibility hygiene | ruff + type-check clean; `uv.lock` updated with manifest changes; model revisions + eval-set versions pinned; experiment config logged; no committed artifacts/checkpoints |
| Comment hygiene | Comments follow the compact code-documentation standard (`corpflow:code-comment-standard`): WHY/contract only, no design provenance, history, or call-site enumeration; no restated code |

Template: [../templates/dr-review.md](../templates/dr-review.md).

## QA Gate for AI Work

QA (`testing-N.md`, verdict `go`/`no-go`) passes only when **both** hold:

1. **All tests pass** — full suite, not just new tests (`uv run pytest`, plus any project-native suites).
2. **Eval regression gate holds where a harness exists** — re-run the eval harness with the pinned eval-set version and deterministic settings (temperature 0 / fixed seeds); no metric regresses beyond the gate threshold vs. baseline. Where no harness exists for the touched capability, record the gap explicitly in `testing-N.md` — never silently pass. For pure infra/serving changes with no behavior surface, tests + lint clean suffices.

ai-test-generator supports QA with framework-native generation (pytest, golden sets, LLM-judge harnesses, regression gates). Template: [../templates/qa-testing.md](../templates/qa-testing.md).

## SR and RE Contributions

- **SR** — ai-security-auditor provides platform context to corpflow's security-reviewer: OWASP LLM Top 10 mapping, prompt-injection review (untrusted input → privileged prompts, tool-execution gating), data-leakage scan (secrets/PII in code, prompts, logs, datasets), model-artifact safety (safetensors over pickle, pinned HF revisions), supply-chain audit (`pip-audit`, `osv-scanner`, model provenance). Review-only: findings route to ai-code-fixer for application.
- **RE** — release-engineer owns the stage; ai-engineer contributes packaging: ai-dependency-manager freezes lockfiles and pins (`uv.lock`, HF model revisions, eval-set versions), and the domain agents produce release artifacts (wheels/sdists via `uv build`, container images, adapter/model artifact versions, changelog entries) recorded in `release-N.md`.

## Handoff Frontmatter (v4.0.0 schema)

Every stage artifact MUST start with a YAML block between `---` markers. Budgets: ≤200 tokens, ≤30 lines. Base required fields: `stage`, `verdict`, `summary` (≤200 chars), `refs`. Per-stage additions (from `handoff-protocol.md#frontmatter-schema`):

| Stage | Required beyond base | Verdict vocabulary |
|-------|----------------------|--------------------|
| AR | `key_decisions`, `next_stage_focus`, `open_questions` | ok / blocked / escalate |
| DV | `files_touched`, `next_stage_focus` | ok / blocked / escalate |
| DR | `key_decisions` (= findings) | pass / fail |
| QA | `files_touched` (= tests added), `key_decisions` (= results) | go / no-go |

`key_decisions[].anchor` and `refs.*` MUST resolve to a real `## <kebab-case>` heading in the target file (anchor-lint enforces this at DR and via PostToolUse hook). Copy-paste blocks: `../templates/` beside this file.

## Gate-Feedback Contract (v4.0.0)

When DR returns `verdict: fail` or QA returns `verdict: no-go`, the orchestrator re-dispatches DV (`run_index` bumped, `retry_count`++) and carries the upstream remediation **verbatim** into the retry prompt (corpflow `worktask/SKILL.md` step 4.6). ai-engineer agents **consume** this contract; the injection is orchestrator-owned.

| Surface | Mechanism | ai-engineer action |
|---------|-----------|--------------------|
| Orchestrator → DV prompt | On re-dispatch (`metadata.retry_count > 0`) the prompt is prepended with `REMEDIATION (from <DR\|QA> gate — fix these specific findings before re-stop:)`; `metadata.gate_from_stage` ∈ {DR, QA}; `metadata.gate_blockers[]` = DR `blockers[]` / QA `blocking_defects[]` strings. | Read both fields; fix those exact findings *first*; do not re-scope. |
| SubagentStop hook → next dispatch | A blocked gate emits `hookSpecificOutput.additionalContext` telling the next run what to fix. | Treat as additional remediation context; consume the same way. |

On a rework dispatch the DV/ai-code-fixer agent MUST:

1. Read `metadata.gate_from_stage` + `metadata.gate_blockers[]` (and any `REMEDIATION` block in the prompt).
2. Address each listed blocker individually; record per-blocker resolution in `.context/errors/<agent-basename>.md`.
3. Keep the diff minimal — change only what the blockers require; do not re-implement passing code.

## Token Budgets

- **Incoming compressed context** (from corpflow): 300-500 tokens (planning summary 300, architecture summary 300, development handoff 500)
- **Full stage output**: write to `.context/<stage>-N.md` (no token cap)
- **Outgoing return summary**: 500 tokens max (for the orchestrator)
- **Inter-stage handoffs**: DV→DR 300, DR→QA 300 (`corpflow:context-compression § Context Budget by Handoff`)

## Dynamic Worktask Sizing (v4.0.0)

PL0 assesses complexity (0-50) and creates only the stages needed:

| Score | Complexity | PL0 Creates |
|-------|------------|-------------|
| 0-10 | Low | DV0, DR0, QA0 |
| 11-20 | Medium | AR0, DV0, DR0, QA0 |
| 21-30 | Moderate | AR0, TL0, DV0, DR0, QA0 |
| 31-40 | High | AR0, TL0, DV0, DR0, QA0, DC0, FN0, ST0 |
| 41-50 | Critical | AR0, TL0, DV0, DR0, SR0, QA0, DC0, RE0, FN0, ST0 |

Security-sensitive features (authentication, payment, PII, cryptography, secrets, file uploads) auto-include SR0 regardless of score.

PL0 stamps `metadata.skipped_stages = [{stage, reason}]` for every stage dropped from the full 9-stage pipeline (PL→AR→TL→DV→DR→QA→DC→FN→ST), so `state.json` self-documents the drops. It also stamps `metadata.test_mode` (`build-only` / `scoped` / `full` — defaulted by score and marker coverage) and `metadata.ui_visual_check` (the UI-capture provenance gate, left `false` for AI/CLI work). The stage table above, the `test_mode` defaults, and these stamps are all defined by corpflow `estimation-methodology § PL0 Stage-Set` (the source of truth) — keep them in lockstep with it so the next sync is a mechanical copy.

