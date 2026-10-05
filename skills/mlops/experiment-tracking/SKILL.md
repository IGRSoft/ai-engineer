---
name: experiment-tracking
description: >-
  Reproducible ML experiment tracking: the run contract (config, seed, dataset
  version, commit, environment, metrics), MLflow/W&B mapping, sweep hygiene,
  LLM-specific logging, and eval-gated registry promotion via aliases. Use when
  logging a training, fine-tuning, or eval run, setting up MLflow/W&B,
  promoting or rolling back a model, or when a metric can't be traced to its run.
---

# Experiment Tracking

Tracking turns training and eval runs into evidence: what went in (config, seed, dataset version, commit, environment), what came out (metrics, artifacts), and where it went (registry version, alias). The test: given only the tracker entry, a teammate can rebuild the artifact and get the same numbers. Start on day one (an unlogged run is gone); file-backed MLflow (`./mlruns`) works offline, no server needed. Owning agent: `ai-engineer:mlops-engineer`.

**Elsewhere:**

- CI pass/fail thresholds on eval metrics → `skills/evals/regression-gates`
- Designing evals → `skills/evals/eval-design`, `skills/evals/llm-judge`
- DVC data/pipeline versioning and promotion CI/CD → `skills/mlops/ml-pipelines`
- Whether a checkpoint earns promotion (PROMOTE/REJECT) → `skills/finetuning/checkpoint-promotion`
- Deploying the promoted model and consuming aliases → `skills/mlops/model-serving`; prod trends vs run baselines → `skills/mlops/model-monitoring`

## The Reproducibility Contract

Every tracked run logs all six fields; one missing field breaks the rebuild chain.

| # | Field | Log as | Breaks without it |
|---|-------|--------|-------------------|
| 1 | Config | params: every hyperparameter, flattened (`train.lr`, `lora.r`) | "What settings produced this?" |
| 2 | Seed(s) | param: `seed` (data shuffle, init, sampling) | Same config, different numbers |
| 3 | Dataset version | tag: DVC rev / content hash / eval-set version | Trained on data nobody can reconstruct |
| 4 | Code commit | tag: git SHA — refuse to launch from a dirty tree | Diff between run and repo unknowable |
| 5 | Environment | tag: `uv.lock` hash (+ container image digest if used) | Dependency drift changes results silently |
| 6 | Metrics | step-indexed series + final summary | A run that proves nothing |

`references/tracking-implementation.md` has the tracked-run launcher (MLflow, all six fields logged before any work), the MLflow ↔ W&B mapping, run hygiene, LLM-specific logging fields, and the registry promotion flow.

## Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| Logging metrics only | Numbers with no inputs — nothing is rebuildable | Log the full six-field contract |
| Training on "latest" data | Dataset changed underneath; result unattributable | Pin a DVC rev / content hash as `dataset_version` |
| Launching from a dirty tree | Code state unknowable afterwards | Refuse launch, or auto-attach the diff as an artifact with a `dirty` tag |
| Deleting failed runs | Negative results lost; failures get re-run | Retain with `status: failed` + reason tag |
| Promotion by copying checkpoint files | Prod artifact untracked; rollback is archaeology | Register versions; move aliases |
| Only aggregate eval scores | Cannot see which examples regressed | Log the per-example outputs artifact |
| One experiment for everything | Cross-task comparisons meaningless | Experiment per task + model family; tags for slicing |
| Metric without an eval-set version | Number cannot be compared to anything later | Tag every metric-producing run with `eval_set` |

## Verification

- [ ] Pick a recent run: rebuild its environment from the logged lockfile hash and relaunch from the logged commit + config + seed — metrics match
- [ ] All six contract fields present on every run from the last week
- [ ] LLM runs additionally carry prompt version, eval-set version, judge config, and a per-example outputs artifact
- [ ] Failed runs retained and tagged with reasons
- [ ] Registry aliases `dev` / `staging` / `prod` resolve; serving reads the alias, not a version number
- [ ] Promotion criteria written down and gated on evals (pinned set, temperature 0)
- [ ] A teammate can answer "what is in prod and how was it trained?" from the tracker alone
