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

Apply this policy in DV stage output and when responding to DR findings. Reviewers (DR, SR) should flag policy violations alongside other issues. This policy aligns with `skill: corpflow:code-comment-standard` — comment the non-obvious *why* and the contract only; route rationale, history, and before/after narrative to the PR / `.context/development-N.md` / ADR, not to source comments.

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
| Claude Code meta-prompts (agents, commands, skills) | the orchestrator's meta-prompt engineer — this plugin's ai-prompt-engineer owns product/application prompts only |
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

