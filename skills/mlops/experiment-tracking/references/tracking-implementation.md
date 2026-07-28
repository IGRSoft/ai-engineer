# Experiment Tracking — Implementation Deep Dive

Deep-dive companion to [../SKILL.md](../SKILL.md): the tracked-run launcher, MLflow ↔ W&B mapping, run hygiene, LLM-specific logging, and registry promotion.

## Tracked-Run Launcher

```python
"""Tracked-run launcher. Full run: uv run python -m train --config configs/sft.yaml"""

import hashlib
import subprocess
from pathlib import Path
from typing import Any

import mlflow


def git_commit() -> str:
    """Current HEAD; refuses a dirty tree — an untracked diff is irreproducible."""
    dirty = subprocess.run(
        ["git", "status", "--porcelain"], capture_output=True, text=True, check=True
    ).stdout.strip()
    if dirty:
        raise RuntimeError("dirty working tree — commit before a tracked run")
    return subprocess.run(
        ["git", "rev-parse", "HEAD"], capture_output=True, text=True, check=True
    ).stdout.strip()


def lockfile_hash() -> str:
    """Environment identity = hash of uv.lock, not a mutable `pip freeze`."""
    return hashlib.sha256(Path("uv.lock").read_bytes()).hexdigest()[:16]


def run_tracked(config: dict[str, Any], seed: int, dataset_rev: str) -> None:
    """Wrap a training run so the six-field contract is logged before any work."""
    mlflow.set_experiment("sft-support-summarizer")
    with mlflow.start_run(run_name=f"lora-r{config['lora.r']}-seed{seed}"):
        mlflow.log_params({**config, "seed": seed})
        mlflow.set_tags(
            {
                "dataset_version": dataset_rev,
                "code_commit": git_commit(),
                "env_lock": lockfile_hash(),
                "purpose": "lora-rank-sweep",
            }
        )
        # ... training loop logs step metrics; final artifacts below ...
        mlflow.log_metrics({"eval/loss": 0.83, "eval/rougeL": 0.41})
        mlflow.log_artifact("artifacts/adapter/", artifact_path="adapter")
```

## MLflow ↔ W&B Mapping

The contract is tool-agnostic; only the vocabulary changes. Surface names and
APIs shift between releases — verify current calls against provider docs
(context7) rather than memory.

| Concept | MLflow | W&B |
|---------|--------|-----|
| Container for related runs | Experiment | Project |
| One execution | Run | Run |
| Sweep structure | Parent run + nested child runs | Sweeps / run groups |
| Inputs | `log_params` | `wandb.config` |
| Time-series outputs | `log_metric(step=…)` | `wandb.log` |
| Files/blobs | Run artifacts | Artifacts (versioned, lineage graph) |
| Promotion surface | Model Registry + aliases | Registry + artifact aliases |
| Offline / local-first | File backend `./mlruns` — no server needed | Offline mode, sync later |

Local-first default: start with file-backed MLflow in the repo workspace
(`uv run mlflow ui` to browse). Move to a shared tracking server when a second
person needs the history — migrate by repointing the tracking URI, never by
re-running experiments.

## Run Hygiene

- **Names carry the variable under test**, not timestamps: `lora-r16-seed42`,
  not `run_final_v3`. The tracker already records time.
- **Tags carry the queryable dimensions**: `purpose`, `dataset_version`,
  `model_family`, `status`. Filtering by tag is how sweeps stay analyzable.
- **Sweeps are parent/child**: one parent run holds the sweep definition; each
  trial is a child. Comparing trials = filtering the parent's children — never
  a directory of loose runs.
- **Keep failed runs.** Tag `status: failed` + `failure_reason: oom|nan_loss|…`.
  Deleted failures get re-run by the next person; retained failures map the
  part of the search space that does not work.
- **One experiment per task + model family.** A single dumping-ground
  experiment makes every comparison apples-to-oranges.

## Logging for LLM Work

LLM runs (fine-tunes, prompt changes, eval sweeps) extend the contract —
aggregate scores alone cannot tell you *which* behavior changed:

| Extra field | Log as | Why |
|-------------|--------|-----|
| Prompt / chat-template version | param: `prompt_version: support-v14` | The prompt is part of the model's behavior surface |
| Eval-set version | tag: `eval_set: golden-v12` | A metric without its eval-set version is meaningless |
| Judge config | param + artifact: judge model, rubric version, temperature 0 | Judge drift fakes quality trends — see `skills/evals/llm-judge` |
| Per-example outputs | artifact: `eval_outputs.jsonl` (example id, output, score) | Aggregates hide which cases regressed |
| Decoding params | params: temperature / top_p / max_tokens used in eval | Sampling settings change scores; evals pin temperature 0 |

```python
mlflow.log_param("prompt_version", "support-v14")
mlflow.set_tag("eval_set", "golden-v12")
mlflow.log_artifact("eval_outputs.jsonl", artifact_path="eval")  # one row per example
```

Diffing two runs' `eval_outputs.jsonl` example-by-example is the fastest
regression-triage tool you can own.

## Registry Promotion Flow

The registry is the handoff point between training and serving. Versions are
immutable; **aliases move**.

```
train run ──register──▶ model version N (immutable, linked to the run)
                            │
                            ├─ alias dev      — automatic on register
                 eval gates ▼
                            ├─ alias staging  — promotion = alias move
              canary passes ▼
                            └─ alias prod     — serving resolves the alias, never a pinned N
                                  ▲
                    rollback = point prod back at version N-1 (alias flip, no rebuild)
```

| Promotion | Criteria (all required) |
|-----------|-------------------------|
| dev → staging | Reproducibility contract complete on the source run; eval suite passed vs the pinned eval-set at temperature 0; no regression beyond `skills/evals/regression-gates` thresholds; artifact is safetensors with a recorded revision |
| staging → prod | Staging soak/canary clean on the monitors in `skills/mlops/model-monitoring`; rollback path rehearsed; approver recorded on the version |

```python
from mlflow import MlflowClient

client = MlflowClient()
client.set_registered_model_alias("support-summarizer", "staging", version="7")
# Serving loads "models:/support-summarizer@prod" — promotion and rollback are
# alias moves, so a rollback takes seconds, not a redeploy.
```

Serving-side consumption of the alias (revision pinning at deploy time, canary
mechanics) is covered in `skills/mlops/model-serving`.
