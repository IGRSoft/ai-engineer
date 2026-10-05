---
description: AI-aware code review — parallel surface reviewers (LLM app, training, serving, prompts) plus an always-on AI security pass, synthesized into a P0-P3 report. Use before merging changes to LLM apps, prompts, training, or serving code.
argument-hint: [scope: file/dir/PR#/branch — default: working changes] [--quick] [--fix]
allowed-tools: Read, Glob, Grep, Bash
estimated-cost:
  min-tokens: 4000
  max-tokens: 28000
  model-distribution:
    haiku: 15%
    sonnet: 75%
    opus: 10%
---

# AI-Aware Code Review

Review changes to AI systems with one read-only specialist per surface present — LLM application code, training code, serving/pipeline configs, prompt assets — plus an OWASP-LLM security pass, then synthesize one deduplicated P0-P3 report. One generalist pass misses most of these defects, because an unbounded agent loop, train/test contamination, an unpinned serving revision, and an injectable system prompt each need a different review skill. `--fix` hands P0/P1 findings to the code fixer under a minimal-diff gate.

## CRITICAL BEHAVIORAL RULES

1. **Resolve the scope once** (Phase 0), print the concrete file list, and pass that same list to every reviewer; reviewers don't re-scope.
2. **Reviewers are read-only** and return findings only. Edits happen only in the `--fix` step, after synthesis, for P0/P1.
3. **One reviewer per detected surface**, launched only for surfaces present in scope (e.g. no `ml-engineer` for a prompt-only change), all in parallel.
4. **The security pass always runs** (except `--quick`), alongside the surface reviewers, whatever surfaces were detected.
5. **Normalize every finding** to `{file, line, category, severity, why, fix, confidence}` and rank P0-P3 per `skills/_shared/severity-matrix.md`.
6. **Behavior changes need eval evidence.** If the scope touches prompt files, model IDs/revisions, or retrieval configs, look for an eval run vs. baseline (change description, CI artifact, or `.context/logs/`). Missing evidence is a P1 finding pointing at `/ai-engineer:eval-run`.
7. **A missing tool reduces depth, never aborts.** Print the install hint, note the reduced depth for that lens, and continue.
8. **Silence is a valid result.** If there are no material issues, say so; don't add P2/P3 nits to fill the report.
9. Execute directly; don't enter plan mode.

## Usage

```bash
/ai-engineer:review-code                              # working changes (staged + unstaged)
/ai-engineer:review-code src/rag/                     # a directory or file
/ai-engineer:review-code feature/reranker-v2          # a branch vs its base
/ai-engineer:review-code 87                           # a PR number
/ai-engineer:review-code src/agents/ --quick          # fast single pass
/ai-engineer:review-code --fix                        # review, then fix P0/P1
```

## Options

| Option | Default | Effect |
|--------|---------|--------|
| `scope` | working changes | File, directory, PR number, or branch to review. See Phase 0. |
| `--quick` | off | Single combined reviewer pass for rapid feedback. Skips the parallel fan-out and the dedicated security pass; folds a lightweight security check into the one pass. |
| `--fix` | off | After synthesis, delegate P0/P1 findings to `ai-engineer:ai-code-fixer` under a minimal-diff gate. P2/P3 are never auto-fixed. |

## Workflow

### Phase 0: Scope Resolution

The first applicable rule wins:

1. **Explicit args.** File or directory → those paths. PR number → `gh pr diff <N> --name-only` (and `gh pr diff <N>` for the patch); without `gh`, print the install hint and fall back to rule 3 against the PR's base branch. Branch → `git diff --name-only $(git merge-base <default> <branch>)..<branch>`, where `<default>` comes from `git symbolic-ref --short refs/remotes/origin/HEAD` (fallback `origin/main`/`origin/master`) — not `HEAD`, which gives an empty range when run from the branch under review.
2. **Working changes** (no args): `git diff --name-only HEAD` plus `git diff --cached --name-only`.
3. **Branch diff** (fallback): current branch vs the default branch's merge-base.

Print the file list and diff line ranges before launching reviewers. Exclude `.venv/`, `node_modules/`, `build/`, `dist/`. Binary artifacts (`*.safetensors`, `*.gguf`, checkpoints, datasets) skip line review but are passed to the security pass, since new or changed model artifacts are supply-chain-relevant.

### Phase 1: Surface Detection

Detect surfaces with `skills/_shared/framework-detection.md` (dependency markers → file markers → structure; its tie-breaks apply). Summary:

| Surface | Markers (shared table has the full list) | Reviewer |
|---------|------------------------------------------|----------|
| LLM app | `anthropic`/`openai`/`langchain`/`llama-index`/`litellm`/`instructor`; RAG, agent-loop, tool-dispatch, provider-client modules | `ai-engineer:llm-engineer` |
| Training | `torch`/`transformers`/`peft`/`trl` in a training context; trainer scripts/configs; `chat_template.jinja`; dataset prep | `ai-engineer:ml-engineer` |
| Serving / pipelines | `vllm`/`mlflow`/`wandb`/`dvc`/`bentoml`/`kserve`; `dvc.yaml`; CUDA Dockerfile; serving/deploy/monitoring configs | `ai-engineer:mlops-engineer` |
| Prompt assets | `prompts/`, `*.prompt.md`, prompt-registry configs | `ai-engineer:ai-prompt-engineer` |
| Eval harnesses | `evals/`, `promptfooconfig.yaml`, deepeval configs, pytest eval markers | folded into the owning reviewer (app → `llm-engineer`, prompt → `ai-prompt-engineer`); arms Rule 6 |

Inference-only `torch`/`transformers` use (no trainer scripts or `max_steps` configs) is app or serving work, not training. No AI surface → see Error Handling.

### Phase 2: Parallel Read-Only Review

Launch every eligible reviewer plus the security pass in one message with the Agent tool. Each prompt is:

"Read-only review of the {surface} files: {file_list}. Review for: {focus}. Don't edit any file. Return findings as a list of `{file, line, category, severity (P0-P3), why, fix, confidence}`. If there are no material issues, say so directly."

| `subagent_type` | {focus} |
|-----------------|---------|
| `ai-engineer:llm-engineer` | provider-call discipline (timeout, retry/backoff, fallback on every call); trust boundaries (untrusted input into prompt segments; model output validated before shell/DB/file/render sinks); structured-output schemas and parse-failure paths; agent-loop bounds (iteration caps, tool gating); token/spend caps; streaming and cache correctness; comment hygiene (WHY/contract only) |
| `ai-engineer:ml-engineer` | reproducibility (seeds, config logging, dataset versions); smoke-scale discipline (capped `max_steps`/subsample in dev paths, full run as a documented launch plan); device-agnostic selection (cuda/mps/cpu, no hardcoded `.cuda()`); train/test contamination; chat-template and label-masking alignment; safetensors over pickle; pinned HF revisions; LoRA/optimizer/scheduler config sanity |
| `ai-engineer:mlops-engineer` | pinned model revisions and image digests; health checks and rollback paths; resource limits (GPU memory fraction, max concurrency, context/request caps); quantization config; experiment tracking (config, seed, dataset version logged); DVC/pipeline stage correctness; container hygiene; monitoring/drift hooks |
| `ai-engineer:ai-prompt-engineer` | prompts as versioned files, not inline strings; injection-resistant structure (untrusted input never in privileged segments; retrieved/user content delimited); output-contract clarity and schema alignment; few-shot correctness and eval-set leakage; template-variable hygiene; eval delta shipped with the change |

**Security pass** (`ai-engineer:ai-security-auditor`): "Read-only cross-cutting AI security review of: {file_list} (surfaces: {surfaces}; changed binary/model artifacts: {artifact_list}). Cover the OWASP LLM Top 10: prompt injection (direct and indirect via retrieval/tool results), insecure output handling (exec/subprocess/SQL/render/file sinks), model supply chain (pickle vs safetensors, `trust_remote_code`, unpinned HF revisions, dependency CVEs), secrets/PII in code, prompts, logs, or datasets, unbounded spend/DoS, and ungated agency (tools without allowlists or human confirmation on irreversible actions). Map each finding to its LLM Top 10 ID plus CWE where applicable. Don't edit any file. Return `{file, line, category (LLMxx/CWE), severity (P0-P3), why, fix, confidence}`. If there are no material issues, say so directly."

### `--quick` path

Skip the fan-out: after Phases 0-1, launch only the dominant surface's reviewer (no dominant surface → `ai-engineer:ai-engineer`) with the Phase 2 prompt for that surface, plus "and a lightweight security check (injection paths, unsafe artifact loading, secrets, ungated tool execution)". Then synthesize as below. Use the full path for mixed scopes and pre-merge gates.

### Phase 3: Synthesis

1. Merge all reviewer findings. Where the security pass and a surface reviewer flag the same `{file, line}`, keep the higher severity and the clearer fix, crediting both lenses in `why`.
2. Drop claims without concrete evidence and pure style nits that hide no defect.
3. Normalize and rank (Rule 5; confidence high/medium/low).
4. Apply Rule 6: a missing eval is the P1 "behavior change without eval evidence — run `/ai-engineer:eval-run --baseline <ref>`" (per `skills/evals/regression-gates`).
5. Emit the Output Format report.

### `--fix` (P0/P1 only)

After synthesis, launch `ai-engineer:ai-code-fixer`: "Apply minimal, targeted fixes for these P0/P1 findings from AI code review: {findings as `{file, line, category, fix}`}. Change only what each finding requires — no refactors, reformatting of untouched code, or P2/P3 fixes. Prompt-file edits must not change semantics beyond the finding. Report each change as `{file, line, finding, change}` and list any finding you could not safely auto-fix (needs design judgment, an eval run, or a broader change)."

- Only findings with a concrete, localized fix qualify. Design-level items (agent topology, retrieval strategy, training recipe) go to manual handling or an `ai-engineer:ai-architector` consult.
- Then run a `--quick` pass over the touched files to confirm no regression. Rule 6 applies to fixes that touch prompts, models, or retrieval.

## Output Format

```markdown
## AI Code Review Report

**Scope:** {resolved scope — paths / PR# / branch}
**Files reviewed:** {N} ({surfaces present})
**Reviewers:** {agents run} {+ security pass}
**Mode:** {full | --quick}
**Eval evidence:** {present ({path/ref}) | not required — no prompt/model/retrieval change | MISSING → P1 finding}

### Summary
{One or two sentences. If clean: "No material issues found — the changes look correct, bounded, and reproducible." Otherwise counts by priority.}

| Priority | Count |
|----------|-------|
| P0 (block merge) | {n} |
| P1 (fix in this change) | {n} |
| P2 (should fix) | {n} |
| P3 (nice to have) | {n} |

### P0 — Must Fix Before Merge
| File:Line | Category | Why | Fix | Confidence |
|-----------|----------|-----|-----|------------|
| {file}:{line} | {category/LLMxx/CWE} | {why it's broken} | {minimal fix} | {high/med/low} |

### P1 — Fix In This Change
### P2 — Should Fix
### P3 — Nice To Have
{same table shape}

<!-- When --fix ran: -->
### Fixes Applied
| File:Line | Finding | Change |
|-----------|---------|--------|
| {file}:{line} | {finding} | {what changed} |

**Not auto-fixed (manual):** {findings needing design judgment or an eval run, or "none"}

<!-- When a tool was unavailable: -->
### Reduced-Depth Notes
- {lens}: {missing tool} unavailable — reviewed via manual patterns only. Install: {hint}.
```

## Error Handling

| Condition | Response |
|-----------|----------|
| No AI surfaces in scope | `Note: No AI surfaces (per skills/_shared/framework-detection.md) in the resolved scope: {scope}.` Suggest `/system-developer:review-code` for pure Python/C/C++/Bash changes. |
| No changes (default scope) | `Note: No staged or unstaged changes to review.` Suggest naming a path, branch, or PR number, e.g. `/ai-engineer:review-code src/rag/`. |
| `gh` unavailable for a PR scope | `Warning: gh CLI not found; cannot fetch PR diff directly. Install: brew install gh (then gh auth login).` Fall back to a branch diff against the default branch. |
| Ambiguous surface | Apply the framework-detection tie-breaks; if still ambiguous, route the file to `ai-engineer:ai-engineer` and note the routing in the report. |
| Reviewer tool missing | Note reduced depth (Rule 7) with the hint below. |

| Missing tool | Install hint |
|--------------|--------------|
| `ruff` (lint context) | `uv tool install ruff` |
| `gitleaks` / `trufflehog` (secrets lens) | `brew install gitleaks trufflehog` |
| `pip-audit` / `osv-scanner` (CVE lens) | `uv tool install pip-audit` / `brew install osv-scanner` |
| `bandit` / `semgrep` (pattern lens) | `uv tool install bandit` / `uv tool install semgrep` |
| `nvidia-smi` (GPU context) | not installable on this host — reason about GPU configs statically and note reduced depth |

## See Also

- `skills/_shared/framework-detection.md` — canonical marker → surface → agent routing (keep Phase 1 in sync).
- `skills/_shared/severity-matrix.md` — P0-P3 definitions.
- `skills/evals/regression-gates` — the eval-evidence contract behind Rule 6.
- `/ai-engineer:eval-run` — produce that eval evidence.
- `/ai-engineer:analyze-security` — deeper, scanner-backed OWASP LLM Top 10 sweep.
- `/system-developer:review-code` — language-level review for changes with no AI surface.
