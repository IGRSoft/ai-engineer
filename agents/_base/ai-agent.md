# AI Agent Base Template

Shared behavior for all AI-engineering agents (LLM apps, prompts, fine-tuning, MLOps) and the Tier-2 specialists that inherit from them.

## Constraints

- Python passes `ruff check` and `ruff format --check` with zero findings; type-check touched files with pyright or mypy.
- uv-first: `uv sync`, `uv run`, `uv add`, `uv build`; no bare `pip install` into an ambient environment. `uv.lock` is the version source of truth.
- No secrets or API keys in code, prompts, logs, or datasets: credentials come from env vars or a secret manager; scrub datasets and telemetry before commit.
- Deterministic evals: pin the eval-set version, run at temperature 0 or fixed seeds, and record the eval-set version next to every reported metric.
- No long training runs in DV: smoke-scale only (capped `max_steps`/epochs on a data subsample), with the full-run launch plan (command, data, expected duration/cost) in the DV artifact.
- Pin model revisions (HF `revision` hashes). Verify model IDs, API parameters, pricing, and library APIs against current docs via Context7 (`resolve-library-id` → `query-docs`), not memory; check CLI flags with `<tool> --help`.
- Code runs on macOS (CPU/MPS dev) and Linux (CUDA): select the device at runtime (`cuda`/`mps`/`cpu` fallback), no hardcoded `.cuda()`. Without a GPU or `nvidia-smi`, note the reduced depth in the artifact instead of failing.
- One command per Bash call (`uv run pytest`, `uv sync`), no `cd X && ...` chains or `;`/`|`-joined lines, because scoped `Bash(cmd:*)` permissions can't match compound commands.

## Mandatory Requirements

Code must comply with these skills; flag and correct violations before the code is complete.

| Skill | Rule |
|-------|------|
| `prompt-engineering/prompt-design` | Production prompts are versioned files, not inline strings; untrusted input never goes into privileged instruction segments |
| `llm-apps/llm-api-patterns` | Every provider call has a timeout and retry/backoff |
| `evals/regression-gates` | Prompt, model, or retrieval-config changes ship with an eval run vs. baseline |
| `mlops/experiment-tracking` | Training/tuning runs log config, seed, dataset version, and metrics; artifacts reproducible from the logged config |

## Code Comment Policy

Follows `corpflow:code-comment-standard`: comment the non-obvious why and the contract; rationale, history, and before/after narrative go to the PR, DV artifact, or ADR.

- PEP 257 docstrings on public modules, classes, and functions: one-line summary first, raised exceptions documented.
- Training/eval scripts and prompt-template files carry a header: purpose, expected data, outputs, how to launch the full run, and smoke-scale vs. full-run parameters.
- Inline `#` comments only for a hidden constraint, subtle invariant, bug workaround, or surprising behavior. No comments that restate the code.
- Section banners only in files with 3+ logical sections. `# TODO:`/`# FIXME:` include a ticket or owner.

Applies to DV output and DR fixes; DR and SR reviewers flag violations.

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
| Claude Code meta-prompts (agents, commands, skills) | the orchestrator's meta-prompt engineer; ai-prompt-engineer owns product prompts only |
| Model / effort choice, opus+xhigh override | `skills/_shared/model-selection.md` |

## Standard Response Format

### For Implementation Tasks
1. **Approach**: chosen approach and trade-offs
2. **Code**: the implementation
3. **Reproducibility Notes**: framework versions from `uv.lock`, pinned model revisions, seeds, GPU/CPU-fallback considerations
4. **Testing**: key test scenarios, plus eval evidence when prompts, models, or retrieval configs changed

### For Review Tasks
1. **Summary**: assessment with severity ratings (P0-P3)
2. **Issues**: prioritized list with `file:line` references
3. **Recommendations**: actionable fixes with code examples
