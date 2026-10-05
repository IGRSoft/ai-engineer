# AI Engineer Plugin

Claude Code plugin for AI engineering — **LLM applications** (RAG, agent loops, structured outputs), **prompt engineering**, **LLM fine-tuning** (LoRA/QLoRA/DPO), **MLOps** (serving, experiment tracking, monitoring, pipelines), and **LLM evaluation** — with specialized agents, commands, and skills. Collaborates with the corpflow plugin v4.0.13 for full 11-stage workflow orchestration (PL→AR→TL→DV→**DR**→SR→QA→DC→RE→FN→ST) including the handoff-protocol (planning-N.md, state.json ledger, `handoff:` frontmatter schema). AI and CLI work defaults to `requires_screenshots: false`; when an evidence gate demands proof, agents attach `cli-fallback` transcripts (eval reports, loss-curve summaries, test transcripts) instead of screenshots.

**Version**: 1.3.0

## What's in 1.3.0

- **Fine-tuning lifecycle tail** — four new skills close the gap between a finished training run and a shipped artifact: `grpo-rlvr-training` (reinforcement learning from verifiable rewards), `trace-to-training-data` (rejection sampling and preference pairs from graded eval traces), `checkpoint-promotion` (drift budgets, paired comparison, forgetting checks — does this checkpoint ship?), and `quantized-export` (merged safetensors, LoRA-only, GGUF+imatrix, FP8 — export lifecycle for a promoted checkpoint). Each ships paired with a disambiguation edit on the incumbent skill it collides with. See [`skills/finetuning/`](skills/finetuning/).
- **RAG index-tuning depth** — `skills/llm-apps/rag-systems/references/embedding-and-index-tuning.md` adds vector-index and hybrid-search tuning detail, plus a vendor-neutral unified-memory note folded into `training-optimization`.
- **Routing refreshed** across both skill indexes, 4 agents, 3 commands, and both manifests to cover the new lifecycle skills.
- **Fixed** `scripts/test.sh` for ShellCheck ≥0.11 compatibility (a comment line was misread as a shellcheck directive).

## What's in 1.2.0


## What's in 1.1.0

- **11 agents** — an `ai-engineer` router, four domain implementers (`llm-engineer`, `ml-engineer`, `mlops-engineer`, `ai-prompt-engineer`), `ai-architector` (AR consultant), and five Tier-2 specialists (`ai-test-generator`, `ai-security-auditor`, `ai-performance-engineer`, `ai-code-fixer`, `ai-dependency-manager`). Shared agent rules are documented in `skills/_shared/agent-base.md`; each agent carries the ones it needs.
- **9 commands** — AI-aware code review, eval running, eval-driven prompt optimization, RAG auditing, fine-tune planning, dataset auditing, serving readiness gating, an OWASP LLM Top 10 sweep, and the `build-test` platform build gate, each with restrictive `allowed-tools`.
- **Complete skills tree** — 24 `SKILL.md` across 5 domains (`prompt-engineering`, `llm-apps`, `finetuning`, `mlops`, `evals`) plus `_shared`, with deep reference files. **Mechanisms over snapshots** is the product: volatile facts (model IDs, prices, context-window sizes, library minor versions) are never hardcoded — skills name the lever and say "verify against current provider docs (context7)". Every quality claim is backed by an eval; everything degrades gracefully without CUDA.
- **Plugin-scoped advisory hooks** — `audit-tooluse`, `audit-subagent`, `precompact-checkpoint`, wired in `plugin.json` with corpflow-compatible dedupe keys. Advisory only: never merges `state.json` (orchestrator-owned). See [`hooks/README.md`](hooks/README.md).
- **CC capabilities adopted** — tiered `maxTurns` runaway-loop backstops, Write/Edit-free `tools` lists on the two review-only auditors, fully-qualified `Agent(ai-engineer:<agent>)` delegations, scoped `Bash(cmd:*)` allowlists per toolchain, and the context7 MCP pair for library-docs lookups.

## Agents (11)

| Agent | Model / Effort | Purpose |
|-------|----------------|---------|
| `ai-engineer` | sonnet / medium | Index + router. AI-stack detection (deps, file markers, project structure), routing to specialists, cross-domain glue (app+serving, training+eval). |
| `llm-engineer` | sonnet / high | Production LLM applications: RAG pipelines, agent loops and tool use, structured outputs, provider SDKs with streaming, caching, fallback routing. |
| `ml-engineer` | sonnet / high | LLM training and fine-tuning: PyTorch, Transformers/TRL/PEFT, LoRA/QLoRA, DPO preference tuning, dataset curation, smoke-scale verification. |
| `mlops-engineer` | sonnet / high | Serving, deployment, and ML operations: vLLM/TGI/Ollama/Triton, quantized deploys, MLflow/W&B tracking, DVC pipelines, drift monitoring. |
| `ai-prompt-engineer` | sonnet / high | Product prompt engineering — the prompts shipped *inside* your LLM product — with eval-driven optimization. |
| `ai-architector` | opus / xhigh | AI system architecture: prompt-vs-RAG-vs-fine-tune-vs-hybrid decisions, agent topology, serving stack, build-vs-buy, cost/latency modeling. AR-stage consultant. |
| `ai-test-generator` | sonnet / high | pytest suites plus LLM eval harnesses — golden sets, LLM-judge scoring, regression gates — with pinned eval sets and deterministic settings. |
| `ai-security-auditor` | sonnet / high (review-only) | OWASP LLM Top 10 audit: prompt injection, improper output handling, model supply chain (pickle vs safetensors, unpinned revisions), secret/PII leakage, ungated agency. No Write/Edit in `tools`. |
| `ai-performance-engineer` | sonnet / high (review-only) | Inference performance and cost review: TTFT/latency, throughput/batching, KV-cache and context budgets, quantization, GPU utilization, token spend. No Write/Edit in `tools`. |
| `ai-code-fixer` | haiku / medium | Minimal-diff remediation for findings from review, `ai-security-auditor`, `ai-performance-engineer`, and DR/QA gate blockers. |
| `ai-dependency-manager` | haiku / low | uv lockfiles, torch/CUDA compatibility triage, pip-audit/osv-scanner CVE reports, HF model revision pinning, model/dataset license inventory. |

> `ai-security-auditor` and `ai-performance-engineer` are review-only by default; callers may override the model to `opus` for the hardest analyses (effort stays at the agent's frontmatter `effort:`). Fixes always route to `ai-code-fixer`.

## Commands (9)

| Command | Description |
|---------|-------------|
| `/ai-engineer:review-code` | AI-aware review — parallel surface reviewers (LLM app, training, serving, prompts) plus an always-on AI security pass, synthesized into a P0-P3 report. Supports `--quick` and `--fix`. |
| `/ai-engineer:eval-run` | Discover and run the repo's LLM eval suites (pytest markers, promptfoo, deepeval, custom scripts), compare metrics vs baseline or thresholds, report regressions with provenance. |
| `/ai-engineer:prompt-optimize` | Eval-driven prompt optimization — baseline on a pinned eval set, draft single-variable variants, measure and rank; `--apply` ships the winner with a version bump. |
| `/ai-engineer:rag-audit` | Read-only RAG pipeline audit — map ingest→chunk→embed→index→retrieve→rerank→generate→cite from code, grade each stage, run retrieval evals where a harness exists. |
| `/ai-engineer:finetune-plan` | Read-only fine-tuning feasibility plan — prompt-vs-RAG-vs-finetune verdict, data requirements, LoRA/QLoRA/DPO method choice, GPU memory math, eval gates, smoke-then-full launch plan. Never starts training. |
| `/ai-engineer:data-audit` | Read-only dataset quality audit — schema, dedup, train/test contamination, PII/secret scan, license/provenance, distribution stats into a P0-P3 report. |
| `/ai-engineer:deploy-check` | Serving readiness gate for vLLM/TGI/Ollama/Triton deploys — pins, quantization evals, KV-cache math, gateway controls, probes, rollback, monitoring — returning GO / NO-GO / GO-WITH-RISKS. |
| `/ai-engineer:analyze-security` | OWASP LLM Top 10 sweep of AI code, prompts, and dependencies via `ai-engineer:ai-security-auditor` — scanner-backed, mapped to LLM01-LLM10 + CWE with P0-P3. |
| `/ai-engineer:build-test` | Detect the Python environment (uv/pip/conda), sync, verify the package imports, and run pytest. The `ai` platform's build gate — the orchestrator's platform router routes here, and DR calls it with `--no-test`. |

All commands degrade gracefully when a tool is missing: they print an install hint (for example `uv tool install ruff`, `brew install jq`), reduce depth, and never hard-fail. GPU-optional discipline applies throughout: no `nvidia-smi` → reduced-depth note, never a hard failure.

**Migration (1.0.0 → 1.1.0)** — two commands were renamed to the `<verb>-<noun>` standard shared with the corpflow dev plugins; the old names no longer resolve, and there is no alias.

| Old | New |
|-----|-----|
| `/ai-engineer:code-review` | `/ai-engineer:review-code` |
| `/ai-engineer:security-scan` | `/ai-engineer:analyze-security` |

`/system-developer:review-code` is a different plugin's command and is unaffected.

## Skills (27)

```
skills/
├── SKILL.md                  # routing entry point ("I need help with…" table)
│                             # framework-detection, model-selection, severity-matrix
├── prompt-engineering/       # prompt-design, context-engineering, structured-outputs
├── llm-apps/                 # rag-systems, agent-design, llm-api-patterns
├── finetuning/               # dataset-curation, peft-lora, training-optimization, preference-tuning,
│                             # grpo-rlvr-training, trace-to-training-data, checkpoint-promotion, quantized-export
├── mlops/                    # experiment-tracking, model-serving, model-monitoring, ml-pipelines
└── evals/                    # eval-design, llm-judge, regression-gates
```

### Shared

| Skill | Description |
|-------|-------------|
| `framework-detection` | AI-stack marker → domain → agent routing: detection priority, dependency/file markers, mixed-stack tie-breaks, sibling-plugin precedence. |
| `model-selection` | Per-agent model/effort/maxTurns assignments, cost tiers, and per-call `model` override paths. |
| `severity-matrix` | P0-P3 review priorities with AI examples, effort/impact quadrant, coverage requirements. |

### Prompt Engineering

| Skill | Description |
|-------|-------------|
| `prompt-design` | Five-segment prompt anatomy, instruction hierarchy with delimited untrusted input, few-shot design, positive framing, prompts as versioned files; product prompts only. |
| `context-engineering` | Segment hierarchy and token budgets, packing, compaction triggers, lost-in-the-middle placement, retrieved-context hygiene, per-request context manifests. |
| `structured-outputs` | Extraction-mode choice (tool-call, native structured mode, prompted JSON), flat enum-closed schemas, Pydantic validate → repair-once → fail-closed, streaming partial JSON, common parse failures. |

### LLM Apps

| Skill | Description |
|-------|-------------|
| `rag-systems` | Ingest→chunk→embed→index→retrieve→rerank→ground pipeline, chunking by content type, embedder and vector-store choice, hybrid retrieval, reranking, grounded answers with citations and refusal, index lifecycle (sync, deletes, re-embed). |
| `agent-design` | Escalation ladder (single call → workflow → agent with tools → multi-agent), stop conditions and budgets, tool contracts, memory, human approval for irreversible actions, failure handling, step tracing. |
| `llm-api-patterns` | Timeouts and retry/backoff, rate limits, streaming with TTFT and mid-stream recovery, prompt caching, batch APIs, fallback chains with circuit breakers, cost accounting, secrets. |

### Fine-Tuning

| Skill | Description |
|-------|-------------|
| `dataset-curation` | Messages-schema normalization, exact and near-dup dedup, eval-set decontamination, PII/secret scrubbing, license ledgers, stratified splits, versioning. |
| `peft-lora` | Whether an adapter beats RAG or full fine-tuning, LoRA/QLoRA config starting points (r, alpha, dropout, target_modules), QLoRA memory trade-offs, smoke-scale SFTTrainer loops, adapter merge-vs-serve, before/after evals. |
| `training-optimization` | GPU memory model and estimation, the fit ladder (precision, accumulation, checkpointing, 8-bit optimizers, QLoRA), cuda/mps/cpu device strategy, throughput and loss-curve triage, checkpoint/resume, distributed training. |
| `preference-tuning` | SFT-only vs DPO vs ORPO/KTO vs RLHF selection, building and labeling chosen/rejected pairs, DPO (beta, reference model), reward-hacking detection (length bias, sycophancy, style collapse). |
| `grpo-rlvr-training` | Verifiable-reward RL (GRPO/RLVR) when a program checks success (unit tests, schemas, math): applicability preconditions, reward-function design, the inspection gate, variant selection. |
| `trace-to-training-data` | Graded eval traces → SFT rows or preference pairs: rejection sampling, step-level masking, same-task pair construction, goldens holdout. |
| `checkpoint-promotion` | Whether a trained checkpoint ships: four-stage gate, capability-drift budget, paired comparison vs base, forgetting checks, terminal PROMOTE or REJECT verdict. |
| `quantized-export` | Exporting a promoted checkpoint for its target runtime: merged vs LoRA-only, format choice (FP8, AWQ INT4, GGUF), the pre/post smoke test. |

### MLOps

| Skill | Description |
|-------|-------------|
| `experiment-tracking` | Run contract (config, seed, dataset version, commit, environment, metrics), MLflow/W&B mapping, sweep hygiene, LLM-specific logging, eval-gated registry promotion via aliases. |
| `model-serving` | Engine choice (Ollama, vLLM, TGI, Triton, llama.cpp) vs managed API, pinned artifact to OpenAI-compatible endpoint behind a gateway, serve-time quantization, KV-cache capacity math, LoRA hot-swap vs merge, probes, warmup, drain, canary, rollback. |
| `model-monitoring` | System, quality, and business planes; LLM traces, scheduled judge evals on sampled traffic, spend alarms, feedback loops into eval sets, canary vs control. |
| `ml-pipelines` | Pipeline-as-DAG with idempotent steps, DVC vs git-lfs, orchestrator ladder, PR smoke gates, eval-gated promotion, deploys as registry alias flips, lineage, pinned environments. |

### Evals

| Skill | Description |
|-------|-------------|
| `eval-design` | Task-grounded eval sets from real traffic, the assertion→metric→judge→human hierarchy, metric selection by task type, paired prompt A/B comparison, set sizing and statistical honesty, eval-set versioning, failure analysis. |
| `llm-judge` | Pointwise vs pairwise selection, anchored rubrics, bias mitigations (position, length, self-preference, sycophancy), Cohen's kappa calibration against human labels, evidence-first structured prompts, judge versioning, cost control. |
| `regression-gates` | Pre-commit→PR→nightly→release gate ladder, absolute floors plus relative-to-baseline thresholds with warn bands, baseline update ritual, flake policy for judge metrics, cost-bounded subsets, pytest integration, recorded escape hatch. |


## Model & Effort

`maxTurns` is a runaway-loop backstop. Only `ai-architector` runs `opus`/`xhigh` by default; the domain implementers and review/test agents run `sonnet`/`high` with a documented per-invocation `opus` model override path (see `skills/_shared/model-selection.md`).

| Agent | Model | Effort | maxTurns |
|-------|-------|--------|----------|
| `ai-engineer` | sonnet | medium | 40 |
| `llm-engineer` | sonnet | high | 50 |
| `ml-engineer` | sonnet | high | 50 |
| `mlops-engineer` | sonnet | high | 50 |
| `ai-prompt-engineer` | sonnet | high | 50 |
| `ai-architector` | opus | xhigh | 60 |
| `ai-test-generator` | sonnet | high | 50 |
| `ai-security-auditor` | sonnet | high (review-only) | 50 |
| `ai-performance-engineer` | sonnet | high (review-only) | 50 |
| `ai-code-fixer` | haiku | medium | 30 |
| `ai-dependency-manager` | haiku | low | 20 |

## Installation & Registration

### From a marketplace checkout

```bash
/plugin marketplace add /path/to/ai-engineer     # register this repo as a marketplace
/plugin install ai-engineer@ai-engineer          # install the plugin from it
```

### Manual registration in `~/.claude/settings.json`

Register the marketplace as a directory source and enable the plugin:

```jsonc
{
  "extraKnownMarketplaces": {
    "ai-engineer": {
      "source": {
        "source": "directory",
        "path": "/path/to/ai-engineer"
      },
      "autoUpdate": true
    }
  },
  "enabledPlugins": {
    "ai-engineer@ai-engineer": true
  }
}
```

After editing `settings.json`, run `/plugins` (or restart the session) to load the plugin.

### Smoke test

1. `/plugin marketplace add /path/to/ai-engineer`, then install `ai-engineer` and reload the session.
2. Verify the command surface resolves: `/ai-engineer:review-code` appears in the slash-command list and runs against working changes.
3. Verify agent resolution: an Agent tool call with `subagent_type: "ai-engineer:ai-engineer"` dispatches the router (which can further delegate to `ai-engineer:llm-engineer` etc.).

Standalone installation gives you the slash commands, the skills, and direct `Agent(ai-engineer:*)` delegation. **corpflow auto-routing** (the the orchestrator's platform router DV stage detecting AI stacks and dispatching ai-engineer specialists, plus `--platform ai` on `/worktask`) additionally requires the companion edits to the corpflow plugin documented in [`docs/corpflow-registration.md`](docs/corpflow-registration.md) — applied via a corpflow PR, not from this repo.

## corpflow Integration

This plugin runs standalone. It also participates in [corpflow](https://github.com/IGRSoft/corpflow)
worktasks, and the whole of that integration lives in one file at the repository root:
**[CORPFLOW.md](CORPFLOW.md)**. Delete that file and the plugin is fully standalone; restore it
and it participates again. Nothing else here references corpflow.

## Quick Start

```bash
# AI-aware review of the working changes, then auto-apply minimal-diff fixes
/ai-engineer:review-code --fix

# Run every discovered eval suite and compare against the baseline
/ai-engineer:eval-run --baseline main

# Audit a RAG pipeline that has started hallucinating
/ai-engineer:rag-audit src/rag --focus retrieval

# Plan a LoRA fine-tune without touching a GPU
/ai-engineer:finetune-plan "domain-tune the support-reply model" --data data/tickets.jsonl

# Use an agent directly, outside the workflow
Use the ai-engineer agent to add streaming with fallback routing to our provider client
```

## Development

```bash
scripts/validate.sh            # release gate: manifests, frontmatter, link/anchor integrity, subagent refs
scripts/validate.sh --strict   # CI mode: WARN findings also fail
scripts/test.sh                # bash -n + shellcheck + hook self-tests + validate --strict + prose lints
scripts/test.sh --strict       # a missing tool fails instead of skipping
```

`scripts/test.sh` degrades gracefully when `shellcheck`/`jq` are absent (it SKIPs and prints an install hint). The prose lints are `desc-lint.sh` (fatal: 250-char agent/command and 600-char skill description caps) and `section-lint.sh` (warn-only ≤1000-char section cap). Both repo-wide lint modes enumerate files via `git ls-files` — stage new files before running them, or they are invisible to the lint.

## License

Apache License 2.0 — see [LICENSE](LICENSE) for details.
