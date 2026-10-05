# Skills Index

Full navigation for ai-engineer skills: 27 SKILL.md across 5 domains, plus
shared references. Routing entry point: [`SKILL.md`](SKILL.md).

## Domains

| Directory | Index | Skills | Description |
|-----------|-------|--------|-------------|
| [_shared/](_shared/_index.md) | [`_index.md`](_shared/_index.md) | refs | Cross-cutting references: AI-stack agent routing, model selection, severity matrix |
| [prompt-engineering/](prompt-engineering/SKILL.md) | [`_index.md`](prompt-engineering/_index.md) | 1 + 3 leaves | Production prompt design, context-window engineering, reliable structured outputs |
| [llm-apps/](llm-apps/SKILL.md) | [`_index.md`](llm-apps/_index.md) | 1 + 3 leaves | RAG pipelines, bounded agent loops, production provider-API integration |
| [finetuning/](finetuning/SKILL.md) | [`_index.md`](finetuning/_index.md) | 1 + 8 leaves | Dataset curation, graded-trace conversion, LoRA/QLoRA adapters, training optimization, preference tuning, verifiable-reward RL, checkpoint promotion, quantized export |
| [mlops/](mlops/SKILL.md) | [`_index.md`](mlops/_index.md) | 1 + 4 leaves | Experiment tracking, model serving, production monitoring, ML pipelines + data versioning |
| [evals/](evals/SKILL.md) | [`_index.md`](evals/_index.md) | 1 + 3 leaves | Eval design, LLM-as-judge, CI regression gates |

## All Skills

### _shared

| Skill | Path | Description |
|-------|------|-------------|
| framework-detection | [`_shared/framework-detection.md`](_shared/framework-detection.md) | AI-stack marker → domain → agent routing table: detection priority, dependency/file markers, mixed-stack tie-breaks, sibling-plugin precedence |
| model-selection | [`_shared/model-selection.md`](_shared/model-selection.md) | Per-agent model/effort/maxTurns assignments, cost tiers, and per-call `model` override paths |
| severity-matrix | [`_shared/severity-matrix.md`](_shared/severity-matrix.md) | Severity levels, P0-P3 review priorities with AI examples, effort/impact quadrant, coverage requirements |

### prompt-engineering

| Skill | Path | Description |
|-------|------|-------------|
| **prompt-engineering** (entry) | [`prompt-engineering/SKILL.md`](prompt-engineering/SKILL.md) | Prompt engineering skills navigation: prompt design (anatomy, instruction hierarchy, few-shot), context-window engineering (budgets, packing, compaction), structured outputs (extraction modes, schemas, validate-repair) |
| **prompt-design**None | [`prompt-engineering/prompt-design/SKILL.md`](prompt-engineering/prompt-design/SKILL.md) | Five-segment prompt anatomy, instruction hierarchy with delimited untrusted input, few-shot design, positive framing, prompts as versioned files; product prompts only |
| **context-engineering**None | [`prompt-engineering/context-engineering/SKILL.md`](prompt-engineering/context-engineering/SKILL.md) | Segment hierarchy and token budgets, packing, compaction triggers, lost-in-the-middle placement, retrieved-context hygiene, per-request context manifests |
| **structured-outputs**None | [`prompt-engineering/structured-outputs/SKILL.md`](prompt-engineering/structured-outputs/SKILL.md) | Extraction-mode choice (tool-call, native structured mode, prompted JSON), flat enum-closed schemas, Pydantic validate → repair-once → fail-closed, streaming partial JSON, common parse failures |

### llm-apps

| Skill | Path | Description |
|-------|------|-------------|
| **llm-apps** (entry) | [`llm-apps/SKILL.md`](llm-apps/SKILL.md) | LLM application skills navigation: RAG systems, agent-loop design (escalation ladder, tool contracts, stop conditions, guardrails), provider-API integration (retries, streaming, caching, fallback, cost accounting) |
| **rag-systems**None | [`llm-apps/rag-systems/SKILL.md`](llm-apps/rag-systems/SKILL.md) | Ingest→chunk→embed→index→retrieve→rerank→ground pipeline, chunking by content type, embedder and vector-store choice, hybrid retrieval, reranking, grounded answers with citations and refusal, index lifecycle (sync, deletes, re-embed) |
| **agent-design**None | [`llm-apps/agent-design/SKILL.md`](llm-apps/agent-design/SKILL.md) | Escalation ladder (single call → workflow → agent with tools → multi-agent), stop conditions and budgets, tool contracts, memory, human approval for irreversible actions, failure handling, step tracing |
| **llm-api-patterns**None | [`llm-apps/llm-api-patterns/SKILL.md`](llm-apps/llm-api-patterns/SKILL.md) | Timeouts and retry/backoff, rate limits, streaming with TTFT and mid-stream recovery, prompt caching, batch APIs, fallback chains with circuit breakers, cost accounting, secrets |

### finetuning

| Skill | Path | Description |
|-------|------|-------------|
| **finetuning** (entry) | [`finetuning/SKILL.md`](finetuning/SKILL.md) | Fine-tuning skills navigation: dataset curation, graded-trace conversion, LoRA/QLoRA, training optimization, preference tuning (DPO), verifiable-reward RL (GRPO), checkpoint promotion, quantized export |
| **dataset-curation**None | [`finetuning/dataset-curation/SKILL.md`](finetuning/dataset-curation/SKILL.md) | Messages-schema normalization, exact and near-dup dedup, eval-set decontamination, PII/secret scrubbing, license ledgers, stratified splits, versioning |
| **peft-lora**None | [`finetuning/peft-lora/SKILL.md`](finetuning/peft-lora/SKILL.md) | Whether an adapter beats RAG or full fine-tuning, LoRA/QLoRA config starting points (r, alpha, dropout, target_modules), QLoRA memory trade-offs, smoke-scale SFTTrainer loops, adapter merge-vs-serve, before/after evals |
| **training-optimization**None | [`finetuning/training-optimization/SKILL.md`](finetuning/training-optimization/SKILL.md) | GPU memory model and estimation, the fit ladder (precision, accumulation, checkpointing, 8-bit optimizers, QLoRA), cuda/mps/cpu device strategy, throughput and loss-curve triage, checkpoint/resume, distributed training |
| **preference-tuning**None | [`finetuning/preference-tuning/SKILL.md`](finetuning/preference-tuning/SKILL.md) | SFT-only vs DPO vs ORPO/KTO vs RLHF selection, building and labeling chosen/rejected pairs, DPO (beta, reference model), reward-hacking detection (length bias, sycophancy, style collapse) |
| **grpo-rlvr-training**None | [`finetuning/grpo-rlvr-training/SKILL.md`](finetuning/grpo-rlvr-training/SKILL.md) | Verifiable-reward RL (GRPO/RLVR) when a program checks success (unit tests, schemas, math): applicability preconditions, reward-function design, the inspection gate, variant selection |
| **trace-to-training-data**None | [`finetuning/trace-to-training-data/SKILL.md`](finetuning/trace-to-training-data/SKILL.md) | Graded eval traces → SFT rows or preference pairs: rejection sampling, step-level masking, same-task pair construction, goldens holdout |
| **checkpoint-promotion**None | [`finetuning/checkpoint-promotion/SKILL.md`](finetuning/checkpoint-promotion/SKILL.md) | Whether a trained checkpoint ships: four-stage gate, capability-drift budget, paired comparison vs base, forgetting checks, terminal PROMOTE or REJECT verdict |
| **quantized-export**None | [`finetuning/quantized-export/SKILL.md`](finetuning/quantized-export/SKILL.md) | Exporting a promoted checkpoint for its target runtime: merged vs LoRA-only, format choice (FP8, AWQ INT4, GGUF), the pre/post smoke test |

### mlops

| Skill | Path | Description |
|-------|------|-------------|
| **mlops** (entry) | [`mlops/SKILL.md`](mlops/SKILL.md) | MLOps skills navigation: experiment tracking and model registry, model serving, production monitoring, ML pipelines with data versioning and CI/CD |
| **experiment-tracking**None | [`mlops/experiment-tracking/SKILL.md`](mlops/experiment-tracking/SKILL.md) | Run contract (config, seed, dataset version, commit, environment, metrics), MLflow/W&B mapping, sweep hygiene, LLM-specific logging, eval-gated registry promotion via aliases |
| **model-serving**None | [`mlops/model-serving/SKILL.md`](mlops/model-serving/SKILL.md) | Engine choice (Ollama, vLLM, TGI, Triton, llama.cpp) vs managed API, pinned artifact to OpenAI-compatible endpoint behind a gateway, serve-time quantization, KV-cache capacity math, LoRA hot-swap vs merge, probes, warmup, drain, canary, rollback |
| **model-monitoring**None | [`mlops/model-monitoring/SKILL.md`](mlops/model-monitoring/SKILL.md) | System, quality, and business planes; LLM traces, scheduled judge evals on sampled traffic, spend alarms, feedback loops into eval sets, canary vs control |
| **ml-pipelines**None | [`mlops/ml-pipelines/SKILL.md`](mlops/ml-pipelines/SKILL.md) | Pipeline-as-DAG with idempotent steps, DVC vs git-lfs, orchestrator ladder, PR smoke gates, eval-gated promotion, deploys as registry alias flips, lineage, pinned environments |

### evals

| Skill | Path | Description |
|-------|------|-------------|
| **evals** (entry) | [`evals/SKILL.md`](evals/SKILL.md) | Evaluation skills navigation: eval design, LLM-as-judge, CI regression gates |
| **eval-design**None | [`evals/eval-design/SKILL.md`](evals/eval-design/SKILL.md) | Task-grounded eval sets from real traffic, the assertion→metric→judge→human hierarchy, metric selection by task type, paired prompt A/B comparison, set sizing and statistical honesty, eval-set versioning, failure analysis |
| **llm-judge**None | [`evals/llm-judge/SKILL.md`](evals/llm-judge/SKILL.md) | Pointwise vs pairwise selection, anchored rubrics, bias mitigations (position, length, self-preference, sycophancy), Cohen's kappa calibration against human labels, evidence-first structured prompts, judge versioning, cost control |
| **regression-gates**None | [`evals/regression-gates/SKILL.md`](evals/regression-gates/SKILL.md) | Pre-commit→PR→nightly→release gate ladder, absolute floors plus relative-to-baseline thresholds with warn bands, baseline update ritual, flake policy for judge metrics, cost-bounded subsets, pytest integration, recorded escape hatch |

## Root References

| Path | Contents |
|------|----------|
| [`references/conventions.md`](references/conventions.md) | Skill authoring contract: uv-first Python, determinism in eval/training examples, no pricing or model-ID snapshots, GPU-optional depth, language-depth delegation, plugin-qualified agent names |
