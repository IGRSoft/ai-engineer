---
name: framework-detection
description: Shared AI-stack marker-to-domain-to-agent routing table for the ai-engineer router, corpflow DV dispatch, and commands. Reference when deciding which ai-engineer agent owns a task, file, or repository.
effort: low
---

# Framework Detection & Agent Routing

Single source of truth for the AI-stack marker → domain → agent mapping used by `ai-engineer:ai-engineer` (router), `corpflow:developer` DV dispatch, and every ai-engineer command that scopes work per domain. Keep command-local detection logic in sync with this file — do not fork the tables.

## Detection Priority Order

Evaluate top-down; the first matching tier wins. Within a tier, apply the tie-breaks below.

| Priority | Signal | Why it ranks here |
|----------|--------|-------------------|
| 1 | Explicit user or task override ("fine-tune this model", `--platform ai`, `task.metadata.agent`) | Stated intent overrides inference |
| 2 | Dependency manifests — deps declared in `pyproject.toml`, `requirements*.txt`, `uv.lock` | Declares the stack authoritatively |
| 3 | File markers (`dvc.yaml`, `*.safetensors`, `chat_template.jinja`, CUDA `Dockerfile`, …) | Artifacts reveal the actual workflow |
| 4 | Project structure (`prompts/`, `evals/`, `training/`, `serving/`, `notebooks/` trees) | Layout reflects the work split |
| 5 | Ask — one clarifying question (see § Ambiguity Rule) | Cheaper than a misrouted specialist |

## Dependency Markers → Domain → Agent

Read deps from `pyproject.toml` (`[project.dependencies]` + dependency groups), `requirements*.txt`, and `uv.lock` — manifest declarations, not stray imports. Dist names as they appear in manifests:

| Markers | Domain | Agent |
|---------|--------|-------|
| `anthropic`, `openai`, `langchain`, `llama-index`, `litellm`, `instructor` | LLM apps — RAG, agent loops/tool use, structured outputs, provider calls | `ai-engineer:llm-engineer` |
| `torch`, `transformers`, `peft`, `trl`, `accelerate`, `bitsandbytes`, `datasets` — in a training context (training scripts/configs present; tie-break 3) | Fine-tuning / training | `ai-engineer:ml-engineer` |
| `vllm`, `mlflow`, `wandb`, `dvc`, `bentoml`, `kserve` | MLOps — serving, experiment tracking, pipelines, monitoring | `ai-engineer:mlops-engineer` |
| Prompt asset dirs: `prompts/`, `*.prompt.md`, prompt-registry configs (Langfuse/LangSmith exports) | Prompt engineering | `ai-engineer:ai-prompt-engineer` |
| Eval harnesses: `evals/`, `promptfooconfig.yaml`, deepeval configs (`.deepeval/`, `deepeval` dep) | Evals / regression harnesses | `ai-engineer:ai-test-generator` |

## File Markers

| Marker | Indicates | Default route |
|--------|-----------|---------------|
| `*.ipynb` | Experimentation — classify by the notebook's imports against the deps table | Owning domain agent; mixed → `ai-engineer:ai-engineer` |
| `dvc.yaml`, `.dvc/` | Data/pipeline versioning | `ai-engineer:mlops-engineer` |
| `*.safetensors`, `*.gguf` | Model weights / quantized artifacts | Producing them (training, merge, quantize) → `ai-engineer:ml-engineer`; serving/loading them → `ai-engineer:mlops-engineer` |
| CUDA `Dockerfile` (`FROM nvidia/cuda:…`, GPU torch/vLLM base images) | GPU serving or training image | `ai-engineer:mlops-engineer` |
| `chat_template.jinja` | Tokenizer chat template — dataset formatting / SFT alignment | `ai-engineer:ml-engineer` |
| Model cards (`README.md` with HF model-card YAML header in a model dir, `MODEL_CARD.md`) | Published or consumed model artifact | Authoring → `ai-engineer:ml-engineer`; registry/publishing flow → `ai-engineer:mlops-engineer` |

## Mixed-Stack Tie-Breaking

1. **Training + serving in one task** → `ai-engineer:ml-engineer` implements; `ai-engineer:mlops-engineer` is consulted on the handover surface (export format, quantization, runtime config). One owner, one DV artifact.
2. **App + prompt assets** → `ai-engineer:llm-engineer` implements the app; `ai-engineer:ai-prompt-engineer` owns changes to the prompt files themselves (versioning, eval-driven iteration).
3. **torch/transformers without training signals** (no trainer scripts, no TRL/`max_steps` configs — inference-only use inside an app) → route by the task: app work → `ai-engineer:llm-engineer`, serving work → `ai-engineer:mlops-engineer`. The "(training context)" qualifier in the deps table is load-bearing.
4. **Whole features spanning domains** (app + serving endpoint, fine-tune + eval gate) → `ai-engineer:ai-engineer` — the router sequences the specialists and owns the integration seams.

## Precedence vs Sibling Plugins

| Situation | Route | Rationale |
|-----------|-------|-----------|
| Task targets model/prompt/eval/serving work in a Python repo with AI markers | **ai-engineer** — AI markers beat the generic `.py`/`pyproject.toml` → `system-developer` rule | The AI surface is the work; Python is just the medium |
| Pure Python language depth — typing, packaging, async/concurrency — with no AI surface | `system-developer:python-developer` | Language expertise; nothing model/prompt/eval/serving-shaped |
| On-device Apple ML — Core ML, `coremltools` conversion, MLX | `apple-developer:apple-developer` | Apple platform toolchain owns on-device inference |

The precedence claim is task-scoped, not repo-scoped: an `anthropic` dep does not annex the repository. A typing refactor or packaging fix in the same repo still routes to `system-developer:python-developer`; only tasks touching the model/prompt/eval/serving surface route here.

## Ambiguity Rule

When tiers conflict irreconcilably, or an AI-shaped task matches no marker: ask **one** clarifying question. If asking is impossible (worktask dispatch, batch mode) or the answer still spans domains, route to `ai-engineer:ai-engineer` — the router splits the work and owns the seams. Never guess between `ai-engineer:ml-engineer` and `ai-engineer:mlops-engineer` on a serving-adjacent training task; a misroute costs a full re-dispatch.

## Related References

- `skills/_shared/workflow-integration/SKILL.md` — how the routed agent participates in DV
- `skills/_shared/model-selection.md` — model/effort to pass with the routed `Task()` call
