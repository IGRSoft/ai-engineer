# AI Engineer Plugin

Claude Code plugin for AI engineering — **LLM applications** (RAG, agent loops, structured outputs), **prompt engineering**, **LLM fine-tuning** (LoRA/QLoRA/DPO), **MLOps** (serving, experiment tracking, monitoring, pipelines), and **LLM evaluation** — with specialized agents, commands, and skills. Collaborates with the igrsoft (company-workflow) plugin v3.36.0 for full 11-stage workflow orchestration (PL→AR→TL→DV→**DR**→SR→QA→DC→RE→FN→ST) including the handoff-protocol (planning-N.md, state.json ledger, `handoff:` frontmatter schema). AI and CLI work defaults to `requires_screenshots: false`; when an evidence gate demands proof, agents attach `cli-fallback` transcripts (eval reports, loss-curve summaries, test transcripts) instead of screenshots.

**Version**: 1.0.0 | **igrsoft Compatibility**: v3.36.0

## What's in 1.0.0

- **11 agents + `_base/ai-agent.md`** — an `ai-engineer` router, four domain implementers (`llm-engineer`, `ml-engineer`, `mlops-engineer`, `ai-prompt-engineer`), `ai-architector` (AR consultant), and five Tier-2 specialists (`ai-test-generator`, `ai-security-auditor`, `ai-performance-engineer`, `ai-code-fixer`, `ai-dependency-manager`). All inherit the shared base.
- **8 commands** — AI-aware code review, eval running, eval-driven prompt optimization, RAG auditing, fine-tune planning, dataset auditing, serving readiness gating, and an OWASP LLM Top 10 sweep, each with restrictive `allowed-tools` and an `estimated-cost` band.
- **Complete skills tree** — 24 `SKILL.md` across 5 domains (`prompt-engineering`, `llm-apps`, `finetuning`, `mlops`, `evals`) plus `_shared`, with deep reference files. **Mechanisms over snapshots** is the product: volatile facts (model IDs, prices, context-window sizes, library minor versions) are never hardcoded — skills name the lever and say "verify against current provider docs (context7)". Every quality claim is backed by an eval; everything degrades gracefully without CUDA.
- **Plugin-scoped advisory hooks** — `audit-tooluse`, `audit-subagent`, `precompact-checkpoint`, wired in `plugin.json` with igrsoft-compatible dedupe keys. Advisory only: never merges `state.json` (orchestrator-owned). See [`hooks/README.md`](hooks/README.md).
- **CC capabilities adopted** — tiered `maxTurns` runaway-loop backstops, `disallowed-tools: Write, Edit` on the two review-only auditors, fully-qualified `Task(ai-engineer:<agent>)` delegations, scoped `Bash(cmd:*)` allowlists per toolchain, and the context7 MCP pair for library-docs lookups.

## Agents (11)

| Agent | Model / Effort | Purpose |
|-------|----------------|---------|
| `ai-engineer` | sonnet / medium | Index + router. AI-stack detection (deps, file markers, project structure), routing to specialists, cross-domain glue (app+serving, training+eval). |
| `llm-engineer` | sonnet / high | Production LLM applications: RAG pipelines, agent loops and tool use, structured outputs, provider SDKs with streaming, caching, fallback routing. |
| `ml-engineer` | sonnet / high | LLM training and fine-tuning: PyTorch, Transformers/TRL/PEFT, LoRA/QLoRA, DPO preference tuning, dataset curation, smoke-scale verification. |
| `mlops-engineer` | sonnet / high | Serving, deployment, and ML operations: vLLM/TGI/Ollama/Triton, quantized deploys, MLflow/W&B tracking, DVC pipelines, drift monitoring. |
| `ai-prompt-engineer` | sonnet / high | Product prompt engineering — the prompts shipped *inside* your LLM product — with eval-driven optimization. (Claude Code meta-prompts belong to `igrsoft:prompt-engineer`.) |
| `ai-architector` | opus / xhigh | AI system architecture: prompt-vs-RAG-vs-fine-tune-vs-hybrid decisions, agent topology, serving stack, build-vs-buy, cost/latency modeling. AR-stage consultant. |
| `ai-test-generator` | sonnet / high | pytest suites plus LLM eval harnesses — golden sets, LLM-judge scoring, regression gates — with pinned eval sets and deterministic settings. |
| `ai-security-auditor` | sonnet / high (review-only) | OWASP LLM Top 10 audit: prompt injection, insecure output handling, model supply chain (pickle vs safetensors, unpinned revisions), secret/PII leakage, ungated agency. `disallowed-tools: Write, Edit`. |
| `ai-performance-engineer` | sonnet / high (review-only) | Inference performance and cost review: TTFT/latency, throughput/batching, KV-cache and context budgets, quantization, GPU utilization, token spend. `disallowed-tools: Write, Edit`. |
| `ai-code-fixer` | haiku / medium | Minimal-diff remediation for findings from review, `ai-security-auditor`, `ai-performance-engineer`, and DR/QA gate blockers. |
| `ai-dependency-manager` | haiku / low | uv lockfiles, torch/CUDA compatibility triage, pip-audit/osv-scanner CVE reports, HF model revision pinning, model/dataset license inventory. |

> `ai-security-auditor` and `ai-performance-engineer` are review-only by default; callers may override to `opus` + `xhigh` for the hardest analyses (`xhigh` is honored only on Opus 4.8 or Fable 5 — the model must be raised with the effort). Fixes always route to `ai-code-fixer`.

## Commands (8)

| Command | Description |
|---------|-------------|
| `/ai-engineer:code-review` | AI-aware review — parallel surface reviewers (LLM app, training, serving, prompts) plus an always-on AI security pass, synthesized into a P0-P3 report. Supports `--quick` and `--fix`. |
| `/ai-engineer:eval-run` | Discover and run the repo's LLM eval suites (pytest markers, promptfoo, deepeval, custom scripts), compare metrics vs baseline or thresholds, report regressions with provenance. |
| `/ai-engineer:prompt-optimize` | Eval-driven prompt optimization — baseline on a pinned eval set, draft single-variable variants, measure and rank; `--apply` ships the winner with a version bump. |
| `/ai-engineer:rag-audit` | Read-only RAG pipeline audit — map ingest→chunk→embed→index→retrieve→rerank→generate→cite from code, grade each stage, run retrieval evals where a harness exists. |
| `/ai-engineer:finetune-plan` | Read-only fine-tuning feasibility plan — prompt-vs-RAG-vs-finetune verdict, data requirements, LoRA/QLoRA/DPO method choice, GPU memory math, eval gates, smoke-then-full launch plan. Never starts training. |
| `/ai-engineer:data-audit` | Read-only dataset quality audit — schema, dedup, train/test contamination, PII/secret scan, license/provenance, distribution stats into a P0-P3 report. |
| `/ai-engineer:deploy-check` | Serving readiness gate for vLLM/TGI/Ollama/Triton deploys — pins, quantization evals, KV-cache math, gateway controls, probes, rollback, monitoring — returning GO / NO-GO / GO-WITH-RISKS. |
| `/ai-engineer:security-scan` | OWASP LLM Top 10 sweep of AI code, prompts, and dependencies via `ai-engineer:ai-security-auditor` — scanner-backed, mapped to LLM01-LLM10 + CWE with P0-P3. |

All commands degrade gracefully when a tool is missing: they print an install hint (for example `uv tool install ruff`, `brew install jq`), reduce depth, and never hard-fail. GPU-optional discipline applies throughout: no `nvidia-smi` → reduced-depth note, never a hard failure.

## Skills (24)

```
skills/
├── SKILL.md                  # routing entry point ("I need help with…" table)
├── _shared/                  # workflow-integration (+ DV/DR/QA templates),
│                             # framework-detection, model-selection, severity-matrix
├── prompt-engineering/       # prompt-design, context-engineering, structured-outputs
├── llm-apps/                 # rag-systems, agent-design, llm-api-patterns
├── finetuning/               # dataset-curation, peft-lora, training-optimization, preference-tuning
├── mlops/                    # experiment-tracking, model-serving, model-monitoring, ml-pipelines
└── evals/                    # eval-design, llm-judge, regression-gates
```

### Shared

| Skill | Description |
|-------|-------------|
| `workflow-integration` | Guide for the igrsoft 11-stage workflow (v3.36.0): DV contract for AI work, AI Build Evidence, the `requires_screenshots: false` / cli-fallback norm, gate feedback, handoff frontmatter. |
| `framework-detection` | AI-stack marker → domain → agent routing: detection priority, dependency/file markers, mixed-stack tie-breaks, sibling-plugin precedence. |
| `model-selection` | Per-agent model/effort/maxTurns assignments, cost tiers, and opus+xhigh override paths. |
| `severity-matrix` | P0-P3 review priorities with AI examples, effort/impact quadrant, coverage requirements. |

### Prompt Engineering

| Skill | Description |
|-------|-------------|
| `prompt-design` | Prompt anatomy (role → context → instructions → examples → output contract), instruction hierarchy with injection-resistant layering, few-shot design, prompts as versioned files. |
| `context-engineering` | Context hierarchy, per-segment token budgets, packing and compaction strategies, lost-in-the-middle placement, context observability. |
| `structured-outputs` | Extraction-mode selection (tool-call vs native structured modes vs prompted JSON), schema design, Pydantic validate → repair-once → fail-closed, streaming partial JSON. |

### LLM Apps

| Skill | Description |
|-------|-------------|
| `rag-systems` | Ingest→chunk→embed→index→retrieve→rerank→ground pipeline, hybrid retrieval, grounded citations with refusal rules, index lifecycle. |
| `agent-design` | Escalation ladder (single call → workflow → agent → multi-agent), loop anatomy, stop conditions and budgets, tool contracts, guardrails with human confirmation, step-level tracing. |
| `llm-api-patterns` | Timeout/retry discipline, rate limits, streaming with TTFT, prompt caching, batch APIs, fallback chains with circuit breakers, cost accounting, secrets hygiene. |

### Fine-Tuning

| Skill | Description |
|-------|-------------|
| `dataset-curation` | Chat-format normalization, exact + near-dup dedup, eval-set decontamination, PII scrubbing, license/provenance ledgers, stratified splits, dataset versioning. |
| `peft-lora` | When adapters beat full fine-tuning or RAG, LoRA/QLoRA config anatomy, smoke-scale SFTTrainer loops, adapter save/merge/serve lifecycle, before/after evals. |
| `training-optimization` | GPU memory model with estimation formulas, bf16/fp16/tf32 precision, gradient accumulation vs batch size, checkpointing, cuda/mps/cpu device strategy, loss-curve triage. |
| `preference-tuning` | SFT-only vs DPO vs ORPO/KTO vs RLHF selection, preference-pair construction, DPO mechanics, reward-hacking detection and mitigation. |

### MLOps

| Skill | Description |
|-------|-------------|
| `experiment-tracking` | Run contract (config, seed, dataset version, commit, environment), MLflow vs W&B mapping, LLM-specific logging, eval-gated registry promotion. |
| `model-serving` | Managed-API vs self-hosted ladder (Ollama, vLLM, TGI, Triton, llama.cpp), quantization (GPTQ/AWQ/GGUF), KV-cache capacity math, LoRA hot-swap vs merge, hardening. |
| `model-monitoring` | System/quality/business planes, LLM trace observability, drift via scheduled judge evals, cost dashboards and spend alarms, feedback loops. |
| `ml-pipelines` | Pipeline-as-DAG with idempotent steps, DVC vs git-lfs, orchestrator ladder, PR smoke gates, eval-gated promotion, lineage, environment discipline. |

### Evals

| Skill | Description |
|-------|-------------|
| `eval-design` | Assertion→metric→judge→human hierarchy, task-grounded eval sets from real traffic, paired prompt A/B comparison, statistical honesty, failure analysis. |
| `llm-judge` | Pointwise vs pairwise selection, anchored rubrics, bias mitigations, calibration against human labels (Cohen's kappa), judge regression tests. |
| `regression-gates` | Pre-commit→PR→nightly→release gate ladder, floors plus relative thresholds, baseline update ritual, flake policy, pytest integration, escape hatch. |

Deep detail lives in `references/` next to each SKILL.md (13 files: judge prompt templates, data formats, hyperparameter guide, GPU memory math, distributed training, tool design, provider matrix, chunking strategies, retrieval evaluation, serving-stack matrix, Claude prompting, prompt patterns, schema patterns), plus 3 workflow handoff templates under `_shared/workflow-integration/templates/`.

## Model & Effort

`maxTurns` is a runaway-loop backstop. Only `ai-architector` runs `opus`/`xhigh` by default; the domain implementers and review/test agents run `sonnet`/`high` with a documented per-invocation `opus`+`xhigh` override path (see `skills/_shared/model-selection.md`).

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
2. Verify the command surface resolves: `/ai-engineer:code-review` appears in the slash-command list and runs against working changes.
3. Verify agent resolution: a `Task` call with `subagent_type: "ai-engineer:ai-engineer"` dispatches the router (which can further delegate to `ai-engineer:llm-engineer` etc.).

Standalone installation gives you the slash commands, the skills, and direct `Task(ai-engineer:*)` delegation. **igrsoft auto-routing** (the `igrsoft:developer` DV stage detecting AI stacks and dispatching ai-engineer specialists, plus `--platform ai` on `/worktask`) additionally requires the companion edits to the company-workflow plugin documented in [`docs/igrsoft-registration.md`](docs/igrsoft-registration.md) — applied via a company-workflow PR, not from this repo.

## Workflow Integration (igrsoft v3.36.0)

This plugin collaborates with the **igrsoft** (company-workflow) plugin v3.36.0. igrsoft owns orchestration, worktree isolation, and `state.json` merge; ai-engineer agents stay invoked specialists and follow the handoff-protocol: plan-file resolution, numbered `<stage>-N.md` artifacts, unconditional `handoff:` frontmatter (≤200 tokens; base fields `stage`/`verdict`/`summary`/`refs`), the `state-patch.sh` pointer form, per-agent error files (`.context/errors/<agent-basename>.md`), and the gate-feedback contract (`metadata.gate_from_stage` + `metadata.gate_blockers[]` consumed verbatim on DR-fail/QA-no-go re-dispatch). During DV, `igrsoft:developer` routes to the appropriate ai-engineer specialist via fully-qualified `Task(ai-engineer:<agent>)` calls using the marker tables in `skills/_shared/framework-detection.md` (once the registration edits are applied).

**Evidence norm**: AI work defaults to `requires_screenshots: false`. When a gate demands evidence, agents produce a `cli-fallback` manifest — eval reports, loss-curve textual summaries, and test transcripts produced *this run* (freshness rule: a stale or duplicated transcript re-opens DV). **Smoke-scale training rule**: DV never launches full training runs — capped `max_steps` on a data subsample, loss-curve sanity check, and a documented full-run launch plan; DR fails an uncapped training invocation.

| Stage | ai-engineer Role | Contribution |
|-------|------------------|--------------|
| **AR** | Consultant | `ai-architector` — RAG-vs-finetune-vs-prompt, agent topology, serving architecture. |
| **DV** | Primary | Router + `llm-engineer` / `ml-engineer` / `mlops-engineer` / `ai-prompt-engineer`; emits `development-N.md` with an AI Build Evidence section (`python -VV`, framework versions from `uv.lock`, ruff/type status, test transcript, eval metrics vs baseline). |
| **DR** | Support | `ai-code-fixer` applies technical-lead findings (minimal-diff gate); `ai-architector` consulted for structural concerns. |
| **SR** | Context Provider | `ai-security-auditor` supplies OWASP LLM Top 10, prompt-injection, leakage, and model supply-chain context. |
| **QA** | Support | `ai-test-generator`; the QA gate is tests pass **and** the eval regression gate holds where a harness exists. |
| **RE** | Context Provider | `ai-dependency-manager` freezes lockfiles and pins (`uv.lock`, HF revisions, eval-set versions) for release readiness. |

**Two human checkpoints**: igrsoft worktasks stop at the **PL gate** (post-PL0 plan approval) and the **FN gate** (pre-finalization commit/push/PR), both carried on `PL0.metadata` and bypassed by `--auto-plan` / `--auto-finalization` (both by `--emergency`). ai-engineer agents run as invoked specialists *between* the gates and do not own gate logic.

## Quick Start

```bash
# AI-aware review of the working changes, then auto-apply minimal-diff fixes
/ai-engineer:code-review --fix

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
