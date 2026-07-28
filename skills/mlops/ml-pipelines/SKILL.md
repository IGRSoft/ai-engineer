---
name: ml-pipelines
description: >-
  ML pipelines, data versioning, and CI/CD for models: pipeline-as-DAG with
  idempotent re-runnable steps, DVC stages/remotes/metrics vs git-lfs,
  orchestrator ladder (make → cron → Airflow/Dagster/Prefect-class), PR smoke
  gates and eval-gated promotion, deploys as registry alias flips,
  prediction-to-source lineage, feature-store tradeoffs, environment
  discipline (uv.lock in images, pinned CUDA bases). Use when structuring
  training or data pipelines, versioning datasets, writing dvc.yaml stages,
  choosing an orchestrator, wiring CI for model changes, or replacing
  checkpoint-copying deploys.
---

# ML Pipelines

## Overview

A pipeline is a DAG or it is a ritual. The DAG discipline — idempotent steps,
explicit inputs and outputs, re-runnable from any node — is what makes ML work
repeatable by machines instead of by the one person who remembers the order.
Everything else in this skill (DVC, orchestrators, CI/CD, lineage) is
infrastructure for enforcing that discipline; none of it substitutes for it.

Adopt tooling bottom-up: a `make`-runnable DAG that reproduces from a clean
clone beats an orchestrator wrapping steps that only work on one laptop.

## When to Use

- Structuring a training / data-prep / eval workflow that will run more than once
- Versioning datasets and model artifacts alongside code
- Choosing between make, cron, and an orchestrator (Airflow/Dagster/Prefect-class)
- Wiring CI for model-affecting changes and gating promotion on evals
- Tracing a production prediction back to its model, data, and code
- Deciding whether a feature store earns its complexity

**When NOT to use:**

- Logging runs and comparing experiments → `skills/mlops/experiment-tracking` (pipelines *produce* runs; the tracker records them)
- Gate thresholds and flake policy for CI evals → `skills/evals/regression-gates`
- Serving the promoted artifact → `skills/mlops/model-serving`
- Watching the deployed model and triggering retraining on drift → `skills/mlops/model-monitoring`

## The DAG Discipline

```
data/raw ─▶ [prepare] ─▶ data/clean ─▶ [train] ─▶ artifacts/adapter ─▶ [evaluate] ─▶ metrics/eval.json
                ▲                          ▲                                │
           params.yaml                params.yaml                  gates promotion
                                                                   (skills/evals/regression-gates)
```

Three properties, non-negotiable:

1. **Idempotent steps** — same inputs ⇒ same outputs; a step never mutates its
   own inputs or appends to shared state. Seeds pinned wherever randomness exists.
2. **Explicit inputs/outputs** — every step declares its deps (data, code,
   params) and its outs. Undeclared dependencies are where reproducibility dies.
3. **Re-runnable from any node** — changing an eval prompt re-runs `evaluate`
   only; the tool (DVC, make with sentinels, an orchestrator) skips unchanged
   upstream steps by content, not by faith.

## Deep Dives

Read `references/versioning-and-cicd.md` for DVC data/model versioning, the orchestrator selection ladder, CI/CD for models, prediction→source lineage, and when feature stores earn their keep.

## Environment Discipline

```dockerfile
# Digest-pin the accelerator base image — CUDA/toolchain drift breaks torch
# wheels silently; the digest makes the break explicit and bisectable
FROM nvidia/cuda:<version>-runtime-<os>@sha256:<digest>
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev    # uv.lock is the only version authority — no bare pip
COPY src/ src/
```

- `uv sync --frozen` in images: the build fails if the lock is stale, instead
  of silently resolving something new.
- Record the image digest on the tracked run (the environment field of the
  reproducibility contract).
- CPU-only and MPS dev boxes run the same pipeline at smoke scale (subsampled
  data, capped steps) — device selection at runtime, never a hardcoded
  `.cuda()`; GPU absence degrades depth, never correctness.

## Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| Notebook-as-pipeline | Hidden state, no re-runnability, no diff | Extract steps with explicit deps/outs into a DAG |
| Orchestrator-first | Airflow standing before a working `make` target | Climb the ladder only on demonstrated need |
| Data in git / data nowhere | Repo bloat, or unversioned training data | DVC-tracked outs; LFS only for small static blobs |
| scp-a-checkpoint deploys | Untraceable prod, no rollback | Registry alias flip; serving resolves the alias |
| Full training on every PR | Hours-long reviews, GPU-starved CI | Smoke eval on PR; full suite gates promotion |
| Steps mutating shared paths in place | A re-run corrupts previous outputs | Idempotent, declared outs; content-addressed caching |
| DAG defined only inside the orchestrator | Pipeline unrunnable locally; vendor lock | Steps runnable standalone; orchestrator only schedules |
| `pip install` in Dockerfiles, floating bases | Environment drift, unbisectable breaks | `uv sync --frozen` + digest-pinned base image |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "We'll make it reproducible after the deadline" | The deadline model is exactly the one you will be asked to rebuild. |
| "The data barely changes" | Barely is not never, and the unversioned change is always the one that bites. |
| "Adopting Airflow will give the project structure" | Structure comes from the DAG contract; `make` gives you that for free today. |
| "Running the full eval on every PR keeps us safe" | It keeps PRs unmerged. Smoke on PR, full suite at the promotion gate. |
| "A feature store is MLOps best practice" | It is a solution to batch/online skew. Without that problem it is standing complexity. |
| "The checkpoint is on the server — that's our deploy" | A file on a box has no version, no gate, and no rollback. It is not a deployment. |

## Red Flags

- "Which data trained the prod model?" gets a shrug or an archaeology session
- Retraining requires a specific person's laptop or home directory
- Eval numbers exist in a PR description but in no metrics file
- The pipeline only runs end-to-end from step zero — no resume, no skip-unchanged
- The orchestrator UI is the only definition of the DAG
- A Dockerfile with unpinned `pip install` lines produced the prod image
- `dvc.lock` (or equivalent) conflicts get resolved by "take mine"

## Verification

- [ ] Clean clone + `uv sync --frozen` + one command (`uv run dvc repro` / `make all`) reproduces the pipeline
- [ ] Every step declares deps/outs; re-running with nothing changed is a no-op
- [ ] Datasets and artifacts resolve by revision (git + dvc.lock), not by path convention
- [ ] PR CI runs lint + tests + a smoke eval (pinned set, temperature 0) in minutes
- [ ] Promotion is gated on the full eval suite per `skills/evals/regression-gates`
- [ ] Deployment and rollback are registry alias flips — rehearsed, not theoretical
- [ ] A production prediction from yesterday walks back to model version → run → commit + dataset rev + lockfile hash
- [ ] Images build with `uv sync --frozen` from a digest-pinned base; the image digest is recorded on the run

## Related Skills

- `skills/mlops/experiment-tracking` — the run contract and registry aliases this pipeline feeds
- `skills/mlops/model-serving` — the deploy target of the alias flip
- `skills/mlops/model-monitoring` — drift signals that trigger refresh/retraining runs
- `skills/evals/regression-gates` — gate thresholds, flake policy, CI integration
- `skills/finetuning/dataset-curation` — the data-quality steps inside `prepare`
- `system-developer:python-skills` — Python/packaging depth beyond pipeline scope

Owning agent: `ai-engineer:mlops-engineer`.
