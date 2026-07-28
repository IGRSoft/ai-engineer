# ML Pipelines — Versioning and CI/CD Deep Dive

Deep-dive companion to [../SKILL.md](../SKILL.md): DVC data/model versioning, the orchestrator ladder, CI/CD for models, lineage, and feature stores.

## DVC for Data and Model Versioning

DVC extends git discipline to artifacts too big for git: data and models live
in a remote object store, git tracks content hashes, and `dvc repro` executes
the DAG while skipping unchanged stages.

```yaml
# dvc.yaml — the DAG as code; `uv run dvc repro` rebuilds only what changed
stages:
  prepare:
    cmd: uv run python -m pipeline.prepare --config params.yaml
    deps: [data/raw, src/pipeline/prepare.py]
    params: [prepare]
    outs: [data/clean]
  train:
    cmd: uv run python -m pipeline.train --config params.yaml
    deps: [data/clean, src/pipeline/train.py]
    params: [train]            # includes train.seed — pinned, not defaulted
    outs: [artifacts/adapter]
  evaluate:
    cmd: uv run python -m pipeline.evaluate --eval-set evals/golden-v12.jsonl
    deps: [artifacts/adapter, evals/golden-v12.jsonl, src/pipeline/evaluate.py]
    metrics:
      - metrics/eval.json: { cache: false }   # small, diffable, lives in git
```

- A git commit + `dvc.lock` pins the exact data and artifacts of that
  revision; the `dataset_version` logged by the experiment tracker *is* this
  revision (`skills/mlops/experiment-tracking`).
- Remotes are plain object storage; `dvc push` / `dvc pull` sync artifacts.
- **When git-lfs is enough**: a few binary files, rarely changing, no DAG to
  execute — LFS versions blobs but runs nothing. The moment you want "re-run
  what changed", you want DVC (or an equivalent), not LFS.

## Orchestrator Selection Ladder

```
make / justfile ─────▶ cron / systemd timer ─────▶ orchestrator-class tool
"runs reproducibly      "runs on a schedule,       (Airflow / Dagster / Prefect-class)
 by hand, anywhere"      alerts on failure"
```

Climb only when the lower rung actually fails you. An orchestrator earns its
operational weight when you need **two or more** of:

- Event/sensor triggers (new data arrival, upstream job completion)
- Backfills over historical partitions as a first-class operation
- Cross-team DAG visibility, audit UI, role-based access
- Managed retries with alerting and SLA tracking
- Parallel fan-out across many partitions or configs

Selection dimensions between orchestrator-class tools (capabilities evolve —
verify current docs via context7): scheduling/trigger model, backfill story,
local-dev loop quality, asset-vs-task orientation, deployment coupling
(K8s-native vs library-first). Whatever you pick, the steps themselves must
stay runnable *without* it — the orchestrator schedules the DAG; it must never
be the only place the DAG is defined.

## CI/CD for Models

```
PR ──▶ lint + unit tests + SMOKE eval (minutes)
 │
merge ──▶ candidate build: full pipeline run → registered model version (alias: dev)
 │
promotion ──▶ FULL eval suite + regression gates (skills/evals/regression-gates)
 │                pass ⇒ alias staging → canary → alias prod
 ▼
deployment = registry alias flip (skills/mlops/model-serving) — never scp-a-checkpoint
```

```yaml
# CI shape (any runner) — the PR stays fast; the full suite guards promotion,
# not review
pr-gate:
  steps:
    - run: uv sync --frozen
    - run: uv run ruff check .
    - run: uv run pytest -q
    - run: uv run python -m evals.smoke --eval-set evals/smoke-v3.jsonl --temperature 0
      # smoke = small pinned slice, deterministic; the full suite runs post-merge
```

- **PR gate**: lint + tests + a smoke eval slice — pinned eval-set version,
  temperature 0, minutes not hours. Full training never runs on a PR.
- **Candidate build** on merge: full pipeline → artifact registered with the
  reproducibility contract (`skills/mlops/experiment-tracking`).
- **Promotion is gated, not scheduled**: the full eval suite plus regression
  thresholds decide; humans approve staging → prod where policy requires it.
- **Deployment is an alias flip**: serving resolves the registry alias, so
  deploy and rollback are metadata operations, not file copies.

## Lineage: Prediction → Source

Every production prediction must be traceable through one chain:

```
response (model alias + version in metadata/logs)
  └─▶ registry version ─▶ tracked run ─▶ { code commit, dataset rev (dvc.lock),
                                            uv.lock hash, config, seed }
```

The chain is free if each link already follows its skill: serving logs the
resolved revision (`skills/mlops/model-serving`), the registry version links
the run, the run carries the six-field contract
(`skills/mlops/experiment-tracking`), and the dataset rev is a git+DVC
revision. Test the chain, don't assume it: pick yesterday's prediction and
walk it back to a commit hash.

## Feature Stores: When They Earn It

The real problem a feature store solves is **batch/online skew**: the same
feature computed twice — offline for training, online at inference — drifting
apart. If you do not have both halves, you do not have the problem.

Adopt one when at least two hold: online inference needs low-latency feature
lookups; multiple models share feature definitions; training requires
point-in-time-correct joins (no leakage from the future); a team maintains
features as a product. Otherwise a `features` pipeline stage writing versioned
tables is simpler and fully lineage-compatible. Most LLM apps skip feature
stores entirely — their analog is retrieval-index freshness, which belongs to
`skills/llm-apps/rag-systems`.
