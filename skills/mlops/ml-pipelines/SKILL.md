---
name: ml-pipelines
description: >-
  ML pipelines, data versioning, and CI/CD for models: pipeline-as-DAG with
  idempotent steps, DVC vs git-lfs, orchestrator ladder (make → cron →
  Airflow/Dagster/Prefect-class), PR smoke gates, eval-gated promotion, deploys
  as registry alias flips, lineage, pinned environments. Use when structuring
  training or data pipelines, versioning datasets, writing dvc.yaml stages,
  choosing an orchestrator, wiring CI for model changes, or replacing
  checkpoint-copying deploys.
---

# ML Pipelines

A pipeline is a DAG: idempotent steps, explicit inputs and outputs, re-runnable from any node, so the work repeats by machine rather than by the one person who remembers the order. DVC, orchestrators, CI/CD, and lineage only enforce that discipline. Adopt tooling bottom-up: a `make`-runnable DAG that reproduces from a clean clone beats an orchestrator wrapping steps that only work on one laptop. Owning agent: `ai-engineer:mlops-engineer`.

**Elsewhere:**

- Logging runs and the registry aliases this pipeline feeds → `skills/mlops/experiment-tracking`
- Gate thresholds, flake policy, CI eval wiring → `skills/evals/regression-gates`
- The verdict a promotion stage computes (drift budget, paired comparison vs base) → `skills/finetuning/checkpoint-promotion`; this skill owns the DAG stage and the alias flip
- Serving the promoted artifact → `skills/mlops/model-serving`; drift signals that trigger retraining → `skills/mlops/model-monitoring`
- Data-quality steps inside `prepare` → `skills/finetuning/dataset-curation`; Python packaging depth → `system-developer:python-skills`

## The DAG Discipline

```
data/raw ─▶ [prepare] ─▶ data/clean ─▶ [train] ─▶ artifacts/adapter ─▶ [evaluate] ─▶ metrics/eval.json
                ▲                          ▲                                │
           params.yaml                params.yaml                  gates promotion
                                                                   (skills/evals/regression-gates)
```

1. **Idempotent steps** — same inputs ⇒ same outputs; a step never mutates its
   own inputs or appends to shared state. Seeds pinned wherever randomness exists.
2. **Explicit inputs/outputs** — every step declares its deps (data, code,
   params) and its outs. Undeclared dependencies are where reproducibility dies.
3. **Re-runnable from any node** — changing an eval prompt re-runs `evaluate`
   only; the tool (DVC, make with sentinels, an orchestrator) skips unchanged
   upstream steps by content.

`references/versioning-and-cicd.md` covers DVC data/model versioning, the orchestrator selection ladder, CI/CD for models, prediction→source lineage, and when feature stores earn their keep.

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
  data, capped steps), with device selected at runtime rather than a hardcoded
  `.cuda()`; GPU absence reduces depth, not correctness.

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
| `dvc.lock` conflicts resolved by "take mine" | Lock no longer matches the data it claims | Re-run the affected stages and commit the regenerated lock |

## Verification

- [ ] Clean clone + `uv sync --frozen` + one command (`uv run dvc repro` / `make all`) reproduces the pipeline, on any machine
- [ ] Every step declares deps/outs; re-running with nothing changed is a no-op
- [ ] Datasets and artifacts resolve by revision (git + dvc.lock), not by path convention
- [ ] Eval numbers live in a tracked metrics file, not only in a PR description
- [ ] PR CI runs lint + tests + a smoke eval (pinned set, temperature 0) in minutes
- [ ] Promotion is gated on the full eval suite per `skills/evals/regression-gates`
- [ ] Deployment and rollback are registry alias flips — rehearsed, not theoretical
- [ ] A production prediction from yesterday walks back to model version → run → commit + dataset rev + lockfile hash
- [ ] Images build with `uv sync --frozen` from a digest-pinned base; the image digest is recorded on the run
