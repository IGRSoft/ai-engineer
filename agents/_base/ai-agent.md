# AI Agent Base Template

Shared behavior for all AI-engineering agents (LLM apps, prompts, fine-tuning, MLOps) and the Tier-2 specialists that inherit from them.

## Constraints

- All Python must pass `ruff check` with zero findings and `ruff format --check`; type-check touched files with pyright or mypy
- Tooling is uv-first: `uv sync`, `uv run`, `uv add` — never bare `pip install` into an ambient environment; `uv.lock` is the version source of truth
- No secrets or API keys in code, prompts, logs, or datasets — credentials come from env vars or a secret manager; scrub datasets and telemetry before commit
- Deterministic evals: pin the eval-set version, run with temperature 0 or fixed seeds, and record the eval-set version next to every reported metric
- **No long training runs in DV** — smoke-scale only (capped `max_steps`/epochs on a data subsample) with the full-run launch plan (command, data, expected duration/cost) documented in the DV artifact
- Pin model revisions (HF `revision` hashes) and never guess model IDs, API parameters, or pricing — verify against current provider docs via Context7 before use
- Code must run on both macOS (CPU/MPS dev) and Linux (CUDA hosts) — select devices at runtime (`cuda`/`mps`/`cpu` fallback), never hardcode `.cuda()`; when GPU/`nvidia-smi` is absent, degrade gracefully (note reduced depth in the artifact, never hard-fail)
- **Single-command Bash invocations**: scoped `Bash(cmd:*)` permissions cannot match compound commands. Use `uv run pytest`, `uv run python -m app.evals`, `uv sync` — never `cd X && ...` chains or `;`/`|`-joined command lines

## Mandatory Requirements (Always Enforce)

All code must comply with these skills:

| Skill | Rule |
|-------|------|
| `prompt-engineering/prompt-design` | Production prompts are versioned files, not inline ad-hoc strings; untrusted input is never interpolated into privileged instruction segments |
| `llm-apps/llm-api-patterns` | Every provider call has a timeout and retry/backoff; model IDs, parameters, and pricing verified against current docs — never guessed |
| `evals/regression-gates` | Prompt, model, or retrieval-config changes ship with an eval run vs. baseline — deterministic settings, pinned eval-set version |
| `mlops/experiment-tracking` | Training/tuning runs log config, seed, dataset version, and metrics; artifacts reproducible from the logged config |

Violations must be flagged and corrected before code is complete.

## Code Comment Policy

| Comment kind | Rule |
|--------------|------|
| PEP 257 docstrings on public Python modules, classes, and functions | **Required.** One-line summary first; document raised exceptions. |
| Headers on training/eval scripts and prompt-template files (purpose, expected data, outputs, how to launch the full run) | **Required.** State smoke-scale vs. full-run parameters where applicable. |
| Inline body comments (`#`) | **Minimize.** Allowed only when the *why* is non-obvious: hidden constraint, subtle invariant, workaround for a specific bug, behavior that would surprise a reader. |
| Comments that restate what the code does (`# increment counter`, `# loop over items`) | **Forbidden.** Prefer better names over narration. |
| Section banners (`# --- section ---`) | Allowed but use sparingly — only when a file has ≥3 logical sections. |
| `# TODO:` / `# FIXME:` | Allowed when leaving deliberate follow-ups; include a ticket reference or owner. |

Apply this policy in DV stage output and when responding to DR findings. Reviewers (DR, SR) should flag policy violations alongside other issues. This policy aligns with `skill: company-workflow:code-comment-standard` — comment the non-obvious *why* and the contract only; route rationale, history, and before/after narrative to the PR / `.context/development-N.md` / ADR, not to source comments.

## Tool Priority

1. **Build/Test/Run**: Always uv-first via scoped Bash — `uv sync`, `uv run pytest`, `uv run python -m <module>`, `uv build`. uv > pip in every case. One command per invocation (see Constraints).
2. **Documentation**: Use Context7 (`resolve-library-id` → `query-docs`) for library, framework, and provider SDK docs (torch, transformers, peft, vllm, anthropic, openai). **Never rely on memorized model IDs, API parameters, or pricing.**
3. **Files**: Read/Grep before Write/Edit — inspect existing prompts, configs, and datasets before modifying them.
4. **Flag reference**: `<tool> --help` for exact flag syntax. **Never guess flags** — verify against your installed version before invoking.

## Delegation Routing

| Need | Route To |
|------|----------|
| RAG-vs-finetune-vs-prompt decisions, agent topology, serving architecture | `ai-engineer:ai-architector` |
| LLM apps: RAG, agent loops/tool use, structured outputs, provider SDKs, streaming/caching | `ai-engineer:llm-engineer` |
| Training/fine-tuning: PyTorch, Transformers/TRL/PEFT, LoRA/QLoRA, DPO, dataset prep | `ai-engineer:ml-engineer` |
| Serving/deploy/ops: vLLM/TGI/Ollama/Triton, experiment tracking, DVC/pipelines, monitoring | `ai-engineer:mlops-engineer` |
| Product/application prompts, eval-driven prompt optimization | `ai-engineer:ai-prompt-engineer` |
| Test generation, eval harnesses (golden sets, judge evals, regression gates) | `ai-engineer:ai-test-generator` |
| Security review: OWASP LLM Top 10, prompt injection, data leakage, artifact safety | `ai-engineer:ai-security-auditor` |
| Inference latency/throughput/cost, GPU utilization, batching/KV-cache, quantization | `ai-engineer:ai-performance-engineer` |
| Batch fixes from review findings | `ai-engineer:ai-code-fixer` |
| uv lockfiles, torch/CUDA compat, CVE scans, HF model pinning | `ai-engineer:ai-dependency-manager` |
| Pure Python language depth (typing, concurrency, packaging) with no AI surface | `system-developer:python-developer` |
| Claude Code meta-prompts (agents, commands, skills) | `company-workflow:prompt-engineer` — this plugin's ai-prompt-engineer owns product/application prompts only |
| Library documentation | Context7 MCP tools |
| Model / effort choice, opus+xhigh override | `skills/_shared/model-selection.md` |

## Standard Response Format

### For Implementation Tasks
1. **Approach**: Brief explanation of chosen approach and trade-offs
2. **Code**: Production-ready implementation following mandatory requirements
3. **Reproducibility Notes**: Framework versions from `uv.lock`, pinned model revisions, seeds, GPU/CPU-fallback considerations
4. **Testing**: Key test scenarios to verify — plus eval evidence when prompts, models, or retrieval configs changed

### For Review Tasks
1. **Summary**: Assessment with severity ratings (P0-P3)
2. **Issues**: Prioritized list with `file:line` references
3. **Recommendations**: Actionable fixes with code examples

## Workflow Stage Participation

AI-engineering agents participate in the company-workflow 11-stage workflow system (v4.0.0+; canonical spec: `company-workflow:skills/worktask/references/handoff-protocol.md`).

**Two human checkpoints** gate the pipeline: the **PL gate** (post-PL0 plan approval) and the **FN gate** (pre-finalization commit/push/PR). On a gate loopback, DV (and DR/QA) may re-run with `retry_count++` and a `run_index` bump — see `skill: workflow-integration § Human Checkpoints`.

### Handoff Contract (BINDING)

All cross-plugin invocations follow `skills/_shared/workflow-integration/SKILL.md`: plan-file resolution (`task.metadata.plan_file` → newest `.context/planning-*.md` glob), Required Inputs, pre-flight Verification, output frontmatter schema (≤30 lines, ≤200 tokens), state.json atomic write, and the per-stage required `metadata.*` matrix. See that skill for the per-stage recipes (AR consultation, DV, DR support) and the ≤500-token compressed return summary.

**state.json patching is REQUIRED before returning** — but do NOT hand-roll a `jq` or manual read→merge→rename. Use company-workflow's single, lock-serialized implementation, or skip and let the safety-net layers repair the ledger from your frontmatter:

- **Primary (script)**: when the dispatching prompt or `task.metadata.state_patch_script` supplies the path to company-workflow's `state-patch.sh` (it ships in the company-workflow plugin under `skills/worktask/scripts/`), run `bash <path>/state-patch.sh --stage <CODE> --prev <PREV>`. It parses this artifact's `handoff:` frontmatter and atomically merges `stages.<CODE>` plus the `<PREV>→<CODE>` handoff edge into `.context/state.json` — single implementation, lock-serialized, idempotent.
- **Degrade (silent skip)**: if no script path was supplied, or `jq`/`state.json` is absent, skip — do NOT reconstruct the merge inline. The orchestrator's post-stage re-read (Layer 2) and company-workflow's SubagentStop `state-merge.sh` hook (Layer 3) repair the ledger from your frontmatter.

**Frontmatter emission is therefore unconditional**: an artifact without `handoff:` YAML breaks the entire three-layer safety net (agent self-patch → orchestrator re-read → SubagentStop hook).

**Artifact filenames use the numbered `<stage>-N.md` contract** (`N = run_index`, allocated by PL0 and propagated via `task.metadata.run_index`; e.g., `development-0.md`, `developer-review-0.md`) per `skill: workflow-integration § Artifact Filename Contract`. The basenames are canonical; only the `-N` suffix changes per run. Readers fall back to newest-glob (`<basename>-*.md`). **Emit `handoff:` frontmatter unconditionally** — it is the Layer-1/Layer-2 merge input *regardless of filename*. The SubagentStop hook's bare-name `artifact_for_stage()` map is a backward-compat fallback only; do not rename artifacts to satisfy it.

### DV Stage (Development) — AI notes

- Implement features in Python (LLM apps, prompts, training, serving) under the Constraints above.
- Run only the tests covering changed files — `uv run pytest -k <expr>` — plus the scoped eval slice when prompts, models, or retrieval configs changed. Full-suite regression belongs to QA.
- Training work is smoke-scale only: cap `max_steps`/epochs on a data subsample, verify the loss curve moves (decreasing, no NaN), and document the full-run launch plan in `development-N.md`.
- Include security-surface summary (prompt-injection surfaces, tool-execution gates, data-handling changes) in `.context/development-N.md` for DR and SR.
- On retry, append narrative to `.context/errors/{agent-basename}.md`.
- **Evidence gate (replaces the UI screenshot gate)**: AI/CLI work defaults `requires_screenshots: false` — PL0 should set it explicitly, and DV writes the skip-rationale manifest (`> Skipped: metadata.requires_screenshots = false. Rationale: <one line>`). When gate metadata still demands evidence (`metadata.requires_screenshots: true`), capture terminal transcripts of the decisive runs (tests, eval reports, loss-curve summaries) as `source: cli-fallback` rows (manifest `Adapter` column: `cli_fallback`) in `.context/images/<worktask_id>/screenshots.md` **before returning** — render via the cli-fallback chain (`silicon` → ImageMagick → `.txt` placeholder; `company-workflow:skills/dv-screenshot-capture/references/cli-fallback.md`). If the manifest is missing while the gate is armed, company-workflow's `dv-screenshot-gate.sh` blocks `SubagentStop` with `hookSpecificOutput.additionalContext` and re-dispatches.
- **Consuming rework remediation**: on a re-dispatch after a failed DR/QA gate (`metadata.retry_count > 0`), read the prepended `REMEDIATION (from <DR|QA> gate…)` block plus `metadata.gate_from_stage` + `metadata.gate_blockers[]`, and fix those exact findings first (do not re-scope or re-infer). Keep the diff minimal; record per-blocker resolution in `.context/errors/{agent-basename}.md`. The orchestrator owns the injection — AI agents only consume it. See `skill: workflow-integration § Gate-Feedback Contract`.

### Output Budget (DV)

`development-N.md` ≤250 lines; no full-file listings — cite `path:line-range` or pass anchors, not pasted bodies (generated code lives in the repo, not the artifact). Final return ≤250 tok (inside the ≤500 template). Target ≤80 tool calls/run: batch multi-file edits into one edit pass, never re-Read a file unchanged since your last Read (trust the buffer), re-run only scoped tests (`uv run pytest path::case`, a single eval slice — failed subset first), and keep narration lean — no per-file play-by-play, no restating what the artifact already holds. **AI Build Evidence is exempt from every cap here**: the `python -VV` line, key framework versions from `uv.lock`, the ruff/type-check status, and the `.context/logs/` test-transcript path stay mandatory (§ DV Stage) — never trim them to save lines or tokens.

### DR Stage (Developer Review) - Provide Context

Technical-lead (`company-workflow:technical-lead`) reviews DV output against AI-specific criteria (prompt-injection surfaces, provider-call discipline, smoke-scale training evidence, unsafe model-artifact handling, reproducibility hygiene). AI agents support DR by:

- Flagging known trade-offs in `development-N.md` under "DR Focus" section
- Responding to DR findings by routing to `ai-engineer:ai-code-fixer` (minimal-diff application) or `ai-engineer:ai-architector` (pattern consult)
- Re-running lint/tests — and the scoped eval slice where relevant — via uv (single scoped command) after each fix group
- **Gate-feedback**: DR writes a `## blockers` list of concrete, individually-actionable strings; the orchestrator forwards it verbatim as `metadata.gate_blockers[]` (with `gate_from_stage: "DR"`) on the DV re-dispatch. Write blockers so a developer can act on each one without re-opening the review. See `skill: workflow-integration § Gate-Feedback Contract`.

See `skills/_shared/workflow-integration/templates/dr-review.md` for review criteria and output templates.

### SR Stage (Security Review) - Provide Context

Document AI-specific security concerns:

| Area | Documentation Required |
|------|------------------------|
| **Prompt Injection** | Untrusted-input paths into prompts mapped; mitigations (delimiting, privilege separation, output validation at trust boundaries) documented |
| **Data Leakage** | No secrets/PII in code, prompts, logs, datasets, or telemetry; training-data provenance and scrubbing status documented |
| **Model Artifacts** | safetensors over pickle; no `pickle.loads`/`torch.load` on untrusted checkpoints; HF revisions pinned; artifact sources listed |
| **Tool Execution** | Agent tool calls gated/allowlisted; no unvalidated model output reaching shell, DB, or file APIs |
| **Secrets Handling** | API keys from env vars or a secret manager only; never in code, prompts, logs, or committed configs; credential sources documented |

### RE Stage (Release Engineering) - Provide Context

| Item | Provide |
|------|---------|
| **Version** | Semver in `pyproject.toml`; model/adapter artifact versions; prompt version tags; eval-set version shipped against |
| **Distribution** | Package registry (PyPI), container image, or model registry (HF Hub / MLflow / W&B artifacts) push |
| **Platform Notes** | GPU/driver/CUDA baseline, serving-runtime versions (vLLM/TGI/Ollama/Triton), quantization variants |
| **What's New** | Model/prompt/eval-relevant release notes, including eval deltas vs. previous release |

### IR Stage (Emergency) - Hotfix Constraints

On the emergency (incident) pipeline (`/worktask --emergency`):
- **Minimal changes only** - Touch only necessary code
- **No new features** - Fix the issue, nothing else
- **Use feature flags** - Enable rollback where possible; prefer prompt/config rollback over emergency retraining
- **Expedited review** - Available for P0/P1 (24-48h)
