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
<!-- Updated: July 2026 -->

Review changes to AI systems with the right specialist per surface — LLM application code, training code, serving/pipeline configs, prompt assets — plus a dedicated OWASP-LLM security pass, then synthesize one deduplicated, prioritized P0-P3 report. Scope defaults to your working changes; reviewers run read-only and in parallel; `--fix` hands the blocking findings to the code fixer under a minimal-diff gate.

[Extended thinking: An unbounded agent loop, a train/test contamination bug, an unpinned model revision in a serving config, and untrusted input interpolated into a system prompt are four different review skills — one generalist pass misses most of them. This command resolves the scope once, detects which AI surfaces are actually present, fans out one read-only reviewer per detected surface alongside an always-on AI security pass, then merges and ranks the findings. The reviewers never edit; only the explicit `--fix` step does, and only for P0/P1. AI review carries one extra evidence bar: when the diff changes prompts, model choices, or retrieval configs, the review expects an eval run vs. baseline — a behavior change without eval evidence is itself a finding. Keep the synthesis honest: if there are no material issues, say so rather than padding the report.]

## CRITICAL BEHAVIORAL RULES

You MUST follow these rules exactly. Violating any of them is a failure.

1. **Resolve the scope before reviewing.** Apply the scope precedence (explicit args > working diff > branch/PR diff) exactly once, list the concrete files under review, and pass that same file list to every reviewer. Do NOT let reviewers re-scope independently.
2. **Reviewers are read-only.** Phase 2 agents MUST NOT write or edit. They return structured findings only. The single place edits happen is the `--fix` step, after synthesis, and only for P0/P1 findings.
3. **One reviewer per detected surface.** Launch a reviewer only for a surface actually present in the scope (per `skills/_shared/framework-detection.md`). Do NOT spawn `ai-engineer:ml-engineer` for a pure prompt-file change. Run the eligible reviewers in parallel — they have no dependencies on each other.
4. **The security pass ALWAYS runs** (unless `--quick`). `ai-engineer:ai-security-auditor` is cross-cutting: it launches alongside the surface reviewers regardless of which surfaces were detected, not after them.
5. **Synthesize, deduplicate, normalize.** In Phase 3 you merge all reviewer outputs, drop duplicates and speculative claims, and normalize every surviving finding to `{file, line, category, severity, why, fix, confidence}` before ranking into P0-P3 per `skills/_shared/severity-matrix.md`.
6. **Eval evidence is expected when behavior changed.** If the scope touches prompt files, model IDs/revisions, or retrieval configs, check for an eval run vs. baseline (change description, CI artifact, or `.context/logs/`). Missing evidence is a P1 finding pointing at `/ai-engineer:eval-run` — never silently pass it.
7. **Tool-missing never hard-fails.** If a reviewer's underlying scanner/linter is unavailable, print the install hint, note the reduced depth for that lens, and continue. Never abort the whole review over one missing tool.
8. **No manufactured findings — silence is a valid result.** If a reviewer or the synthesis finds no material issue, report that plainly. Do NOT invent P2/P3 nits to fill the report.
9. **Never enter plan mode.** This command IS the procedure — execute it.

## Usage

```bash
# Review your current working changes (staged + unstaged)
/ai-engineer:code-review

# Review a specific directory or file
/ai-engineer:code-review src/rag/
/ai-engineer:code-review training/sft_config.yaml

# Review a branch or PR against the base
/ai-engineer:code-review feature/reranker-v2
/ai-engineer:code-review 87              # PR number

# Fast single-pass review for quick feedback
/ai-engineer:code-review src/agents/ --quick

# Review, then auto-fix the P0/P1 findings
/ai-engineer:code-review --fix
```

## Options

| Option | Default | Effect |
|--------|---------|--------|
| `scope` | working changes | File, directory, PR number, or branch to review. See Phase 0. |
| `--quick` | off | Single combined reviewer pass for rapid feedback. Skips the parallel fan-out and the dedicated security pass; folds a lightweight security check into the one pass. |
| `--fix` | off | After synthesis, delegate P0/P1 findings to `ai-engineer:ai-code-fixer` under a minimal-diff gate. P2/P3 are never auto-fixed. |

## Workflow

### Phase 0: Scope Resolution (ONCE)

Resolve the set of files under review **once**, top-down — the first applicable rule wins:

1. **Explicit args** — a file, directory, PR number, or branch named on the command line.
   - File or directory → review those paths directly.
   - PR number (bare integer) → `gh pr diff <N> --name-only` for the file list (and `gh pr diff <N>` for the patch). If `gh` is unavailable, print the install hint and fall back to rule 3 against the PR's base branch.
   - Branch name → diff against the merge-base with the default branch: `git diff --name-only $(git merge-base origin/HEAD <branch>)..<branch>`. Resolve the default branch first (`git symbolic-ref --short refs/remotes/origin/HEAD`, falling back to `origin/main`/`origin/master`) — never `HEAD`, which yields an empty range when the command runs from the branch under review.
2. **Working changes** (no args) — staged and unstaged tracked changes:
   `git diff --name-only HEAD` (plus `git diff --cached --name-only`). This is the default.
3. **Branch/PR diff** (fallback) — when neither explicit paths nor working changes apply, diff the current branch against the default branch's merge-base.

After resolving, **print the concrete file list** and the line ranges (where a diff is involved) before launching any reviewer. Reviewers receive this exact list — they do not re-derive scope. Exclude vendored/build trees (`.venv/`, `node_modules/`, `build/`, `dist/`). Large binary artifacts (`*.safetensors`, `*.gguf`, checkpoints, datasets) are excluded from line review, but their presence in the diff is passed to the security pass — new or changed model artifacts are supply-chain-relevant.

### Phase 1: Surface Detection

Detect which AI surfaces appear in the resolved file list using `skills/_shared/framework-detection.md` (dependency markers → file markers → project structure) — do not fork its tables. Summary for this command:

| Surface in scope | Markers (shared table has the full list) | Reviewer to launch |
|------------------|------------------------------------------|--------------------|
| LLM app code | `anthropic`/`openai`/`langchain`/`llama-index`/`litellm`/`instructor` deps; RAG, agent-loop, tool-dispatch, provider-client modules | `ai-engineer:llm-engineer` |
| Training code | `torch`/`transformers`/`peft`/`trl` in a training context; trainer scripts/configs; `chat_template.jinja`; dataset-prep code | `ai-engineer:ml-engineer` |
| Serving / pipelines | `vllm`/`mlflow`/`wandb`/`dvc`/`bentoml`/`kserve`; `dvc.yaml`; CUDA Dockerfile; serving/deploy/monitoring configs | `ai-engineer:mlops-engineer` |
| Prompt assets | `prompts/` trees, `*.prompt.md`, prompt-registry configs | `ai-engineer:ai-prompt-engineer` |
| Eval harnesses | `evals/`, `promptfooconfig.yaml`, deepeval configs, pytest eval markers | Folded into the owning surface reviewer (app-side → `llm-engineer`, prompt-side → `ai-prompt-engineer`); presence arms the Rule 6 eval-evidence check |

- Inference-only `torch`/`transformers` use (no trainer scripts, no `max_steps` configs) is NOT the training surface — per the shared tie-breaks: app work → `llm-engineer`, serving work → `mlops-engineer`.
- A change spanning several surfaces launches **one reviewer per surface present** — they run in parallel.
- No AI surface at all → report "no AI surfaces in scope" and point to `/system-developer:code-review` (see Error Handling).

### `--quick` path (single pass)

When `--quick` is set, skip the fan-out entirely:

1. Resolve scope (Phase 0) and detect the dominant surface (Phase 1).
2. **Use Task tool with subagent_type="ai-engineer:<dominant-surface-reviewer>"** (mixed scope with no dominant surface → `ai-engineer:ai-engineer`, the router).
   Prompt: "Quick read-only review of these files: {file_list}. Focus on correctness and security for {surface}: {focus_bullets_for_surface}, plus a lightweight security check (injection paths, unsafe artifact loading, secrets, ungated tool execution). Do NOT edit. Return findings as a list of `{file, line, category, severity (P0-P3), why, fix, confidence}`. If there are no material issues, say so directly."
3. Normalize and print the report (Output Format), including the Rule 6 eval-evidence check.

`--quick` is for fast feedback on a single-surface change; for mixed scopes or pre-merge gates, use the full path.

### Phase 2: Parallel Read-Only Review

Launch every eligible surface reviewer **simultaneously**, plus the security pass. All are read-only and receive the same resolved file list. Each reviewer gets a surface-specific focus:

**LLM app — Use Task tool with subagent_type="ai-engineer:llm-engineer"**
- Focus: provider-call discipline (timeout + retry/backoff + fallback on every call), trust boundaries (untrusted input reaching privileged prompt segments; model output validated before any sink), structured-output schema handling and parse-failure paths, agent-loop bounds (iteration caps, tool allowlists), token/spend caps, streaming/caching correctness, comment hygiene per the base Code Comment Policy.
- Prompt: "Read-only review of the LLM application files: {file_list}. Review for: provider-call discipline (timeouts, retries/backoff, fallbacks on every provider call), trust boundaries (untrusted input into prompt segments; model output validated before shell/DB/file/render sinks), structured-output schema handling and parse-failure paths, agent-loop bounds (iteration caps, tool gating), token/spend caps, streaming and cache correctness, and comment hygiene (WHY/contract only). Do NOT edit any file. Return findings as a list of `{file, line, category, severity (P0-P3), why, fix, confidence}`. If there are no material issues, say so directly."

**Training — Use Task tool with subagent_type="ai-engineer:ml-engineer"**
- Focus: reproducibility (seeds, logged config, dataset versions), smoke-scale discipline (capped `max_steps`/subsample in dev paths, full run as a documented launch plan), device-agnostic code (`cuda`/`mps`/`cpu` fallback, no hardcoded `.cuda()`), train/test contamination, chat-template and label-masking alignment, checkpoint format (safetensors over pickle), pinned HF revisions, hyperparameter/config sanity.
- Prompt: "Read-only review of the training files: {file_list}. Review for: reproducibility (seeds, config logging, dataset versioning), smoke-scale discipline (capped max_steps/subsample in dev paths; full run documented as a launch plan), device-agnostic device selection (cuda/mps/cpu fallback, no hardcoded .cuda()), train/test contamination, chat-template and label-masking alignment, checkpoint/artifact format (safetensors, no pickle), pinned HF revisions, and LoRA/optimizer/scheduler config sanity. Do NOT edit any file. Return findings as a list of `{file, line, category, severity (P0-P3), why, fix, confidence}`. If there are no material issues, say so directly."

**Serving / pipelines — Use Task tool with subagent_type="ai-engineer:mlops-engineer"**
- Focus: pinned model revisions and image digests in serving configs, health checks + rollback paths, resource limits (GPU memory fraction, max concurrency, context/request caps), quantization config sanity, experiment-tracking wiring, DVC/pipeline stage correctness, container hygiene, monitoring/drift hooks.
- Prompt: "Read-only review of the serving/pipeline files: {file_list}. Review for: pinned model revisions and image digests in serving configs, health checks and rollback paths on deploys, resource limits (GPU memory fraction, max concurrency, context/request caps), quantization config sanity, experiment-tracking completeness (config, seed, dataset version logged), DVC/pipeline stage correctness, container hygiene, and monitoring/drift hooks. Do NOT edit any file. Return findings as a list of `{file, line, category, severity (P0-P3), why, fix, confidence}`. If there are no material issues, say so directly."

**Prompt assets — Use Task tool with subagent_type="ai-engineer:ai-prompt-engineer"**
- Focus: versioned prompt files (not ad-hoc inline strings), injection-resistant structure (untrusted input never interpolated into privileged segments; retrieved/user content delimited and privilege-separated), output-contract clarity, few-shot example correctness and eval-set leakage, template-variable hygiene, eval delta shipped with the change.
- Prompt: "Read-only review of the prompt assets: {file_list}. Review for: prompt versioning (files, not inline ad-hoc strings), injection-resistant structure (untrusted input never in privileged instruction segments; retrieved/user content delimited and privilege-separated), output-contract clarity and schema alignment, few-shot example correctness and eval-set leakage, template-variable hygiene, and whether an eval delta accompanies the change. Do NOT edit any file. Return findings as a list of `{file, line, category, severity (P0-P3), why, fix, confidence}`. If there are no material issues, say so directly."

**Security pass (ALWAYS, unless `--quick`) — Use Task tool with subagent_type="ai-engineer:ai-security-auditor"**
- Prompt: "Read-only cross-cutting AI security review of: {file_list} (surfaces present: {surfaces}; changed binary/model artifacts: {artifact_list}). Cover the OWASP LLM Top 10: prompt-injection paths (direct + indirect via retrieval/tool results), insecure output handling (model output reaching exec/subprocess/SQL/render/file sinks), model supply chain (pickle vs safetensors, trust_remote_code, unpinned HF revisions, dependency CVEs), secrets/PII in code, prompts, logs, or datasets, unbounded spend/DoS, and ungated agency (tool execution without allowlists or human-in-the-loop on irreversible actions). Map each finding to its LLM Top 10 ID plus classic CWE where applicable. Do NOT edit any file. Return findings as a list of `{file, line, category (LLMxx/CWE), severity (P0-P3), why, fix, confidence}`. If there are no material issues, say so directly."

[SYNC POINT: Wait for all Phase 2 reviewers before synthesis.]

### Phase 3: Synthesis

1. **Collect** every reviewer's findings (surface reviewers + security pass).
2. **Deduplicate** — the security pass and a surface reviewer will overlap (e.g. both flag an ungated tool call). Merge duplicates at the same `{file, line}`, keeping the higher severity and the clearer fix; credit both lenses in `why`.
3. **Filter** — drop speculative claims with no concrete evidence and pure style nits unless they hide a real defect. Per Rule 8, do not backfill.
4. **Normalize** every survivor to `{file, line, category, severity, why, fix, confidence}` (severity per `skills/_shared/severity-matrix.md`; confidence = high/medium/low).
5. **Eval-evidence check (Rule 6)** — if prompts, model IDs/revisions, or retrieval configs changed and no eval-vs-baseline evidence exists, add a P1 finding: "behavior change without eval evidence — run `/ai-engineer:eval-run --baseline <ref>`" (per `skills/evals/regression-gates`).
6. **Rank** into P0-P3 and **emit** the Output Format report.

### Optional: `--fix` (P0/P1 only)

If `--fix` is set, after synthesis:

**Use Task tool with subagent_type="ai-engineer:ai-code-fixer"**
Prompt: "Apply minimal, targeted fixes for these P0/P1 findings from AI code review: {p0_p1_findings as `{file, line, category, fix}`}. Minimal-diff gate: change only what each finding requires; do not refactor, reformat untouched code, or fix P2/P3 items. Preserve behavior outside the stated defect; prompt-file edits must not change semantics beyond the finding. After fixing, report each change as `{file, line, finding, change}` and list any finding you could NOT safely auto-fix (needs design judgment, an eval run, or a broader change)."

- Only P0/P1 with a concrete, localized fix are eligible. Anything needing design judgment (agent topology, retrieval strategy, training recipe) is returned for manual handling or an `ai-engineer:ai-architector` consult.
- Re-run a focused `--quick` pass over the touched files to confirm the fix introduced no regression. If the fix itself touched prompts/models/retrieval, the Rule 6 eval-evidence expectation applies to the fix too.

## Output Format

```markdown
## AI Code Review Report

**Scope:** {resolved scope — paths / PR# / branch}
**Files reviewed:** {N} ({surfaces present})
**Reviewers:** {list of agents run} {+ security pass}
**Mode:** {full | --quick}
**Eval evidence:** {present ({path/ref}) | not required — no prompt/model/retrieval change | MISSING → P1 finding}

### Summary
{One or two sentences. If clean: "No material issues found — the changes look correct, bounded, and reproducible." Otherwise: counts by priority.}

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
{same table shape}

### P2 — Should Fix
{same table shape}

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

### No AI surfaces in scope
```
Note: No AI surfaces (per skills/_shared/framework-detection.md) in the resolved scope.
Resolved scope: {scope}
Suggestion: For pure Python/C/C++/Bash changes use /system-developer:code-review.
```

### No changes detected (default scope)
```
Note: No staged or unstaged changes to review.
Suggestion: Name a path, branch, or PR number, e.g. /ai-engineer:code-review src/rag/
```

### `gh` unavailable for a PR scope
```
Warning: `gh` CLI not found; cannot fetch PR diff directly.
Install: brew install gh   (then `gh auth login`)
Falling back to a branch diff against the default branch.
```

### Reviewer tool missing (reduced depth)
Print the relevant install hint, note reduced depth in the report, and continue — never hard-fail:

| Missing tool | Install hint |
|--------------|--------------|
| `ruff` (lint context) | `uv tool install ruff` |
| `gitleaks` / `trufflehog` (secrets lens) | `brew install gitleaks trufflehog` |
| `pip-audit` / `osv-scanner` (CVE lens) | `uv tool install pip-audit` / `brew install osv-scanner` |
| `bandit` / `semgrep` (pattern lens) | `uv tool install bandit` / `uv tool install semgrep` |
| `nvidia-smi` (GPU context) | not installable on this host — GPU-config findings reasoned statically; note reduced depth |

### Ambiguous surface
If a file matches no surface cleanly, apply the `skills/_shared/framework-detection.md` tie-breaks; if still ambiguous, route it to `ai-engineer:ai-engineer` (the router) and note the routing in the report.

## See Also

- `skills/_shared/framework-detection.md` — canonical AI-stack marker → surface → agent routing (keep this command's detection in sync).
- `skills/_shared/severity-matrix.md` — P0-P3 definitions used by the synthesis ranking.
- `skills/evals/regression-gates` — the eval-evidence contract behind Rule 6.
- `/ai-engineer:eval-run` — produce the eval evidence this review expects for prompt/model/retrieval changes.
- `/ai-engineer:security-scan` — the deeper, scanner-backed OWASP LLM Top 10 sweep when security is the point.
- `/system-developer:code-review` — language-level review for changes with no AI surface.

If there are no material issues, say that directly instead of manufacturing feedback.
