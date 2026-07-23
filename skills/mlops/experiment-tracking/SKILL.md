---
name: experiment-tracking
description: >-
  Reproducible ML experiment tracking: the run contract (config, seed, dataset
  version, code commit, environment hash, metrics), MLflow vs W&B concept
  mapping, run hygiene for sweeps, LLM-specific logging (prompt and eval-set
  versions, judge config, per-example outputs), and model-registry promotion
  through dev → staging → prod aliases gated on evals. Use when logging a
  training, fine-tuning, or eval run, setting up or reviewing MLflow/W&B,
  organizing sweep runs, promoting or rolling back a registered model, or when
  a reported metric cannot be traced back to the run that produced it.
---

# Experiment Tracking

## Overview

A run you cannot reproduce is a rumor. Experiment tracking turns training and
eval runs into evidence: each run records what went in (config, seed, dataset
version, code commit, environment), what came out (metrics, artifacts), and
where it went (registry version, alias). The acceptance test is one question:
*given only the tracker entry, can a teammate rebuild the artifact and get the
same numbers?*

Tracking is cheap to add on day one and impossible to retrofit — the run you
did not log is gone. It needs no infrastructure to start: file-backed MLflow
(`./mlruns`) works offline on a laptop; a tracking server is an upgrade, not a
prerequisite.

## When to Use

- Launching any training, fine-tuning, or eval run whose numbers someone will act on
- Setting up MLflow or W&B for a project, or reviewing an existing setup
- Organizing hyperparameter sweeps and comparing their results
- Promoting a model toward production, or rolling one back
- Nobody can answer "which model is in prod and how exactly was it trained?"

**When NOT to use:**

- CI pass/fail thresholds on eval metrics → `skills/evals/regression-gates` (the tracker stores results; gates decide)
- Designing the eval itself (sets, metrics, judges) → `skills/evals/eval-design`
- Data/pipeline versioning mechanics (DVC stages, remotes) → `skills/mlops/ml-pipelines` — runs *reference* the DVC revision; DVC owns it
- Deploying the promoted model → `skills/mlops/model-serving`

## The Reproducibility Contract

Every tracked run logs all six fields. Five of six is zero of six — one
missing field breaks the rebuild chain.

| # | Field | Log as | Breaks without it |
|---|-------|--------|-------------------|
| 1 | Config | params: every hyperparameter, flattened (`train.lr`, `lora.r`) | "What settings produced this?" |
| 2 | Seed(s) | param: `seed` (data shuffle, init, sampling) | Same config, different numbers |
| 3 | Dataset version | tag: DVC rev / content hash / eval-set version | Trained on data nobody can reconstruct |
| 4 | Code commit | tag: git SHA — refuse to launch from a dirty tree | Diff between run and repo unknowable |
| 5 | Environment | tag: `uv.lock` hash (+ container image digest if used) | Dependency drift changes results silently |
| 6 | Metrics | step-indexed series + final summary | A run that proves nothing |

Worked tracked-run launcher (MLflow, all six fields logged before any work): `references/tracking-implementation.md`.

## Deep Dives

Read `references/tracking-implementation.md` for the tracked-run launcher example, MLflow ↔ W&B concept mapping, run hygiene, LLM-specific logging fields, and the registry promotion flow.

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

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "I'll remember what this run was" | You will not, and your teammate never knew. Names + tags cost seconds. |
| "Tracking slows down research iteration" | File-backed MLflow is offline and adds milliseconds. Re-running lost experiments is what slows iteration. |
| "We only care about the best run" | The comparison *is* the result. Failed and mediocre runs are the evidence the best run beat something. |
| "The checkpoint filename encodes the settings" | Filenames are not queryable, not complete, and lie after one rename. |
| "We'll add tracking when we productionize" | The runs you most need to compare against are the early ones — exactly the ones that are gone. |
| "Our team is one person" | Future-you at three months is a second person with no memory. |

## Red Flags

- Results live in a spreadsheet, a Slack thread, or terminal scrollback
- A checkpoint named `final_v2_best.safetensors` with no run attached
- Nobody can state the dataset version behind the model currently in prod
- A reported metric with no eval-set version next to it
- Sweep analysis means eyeballing a directory of output folders
- A registry exists but serving loads a hardcoded version number (alias flip cannot roll back)
- The same config re-run "to be sure" produces different numbers and nobody can say why

## Verification

- [ ] Pick a recent run: rebuild its environment from the logged lockfile hash and relaunch from the logged commit + config + seed — metrics match
- [ ] All six contract fields present on every run from the last week
- [ ] LLM runs additionally carry prompt version, eval-set version, judge config, and a per-example outputs artifact
- [ ] Failed runs retained and tagged with reasons
- [ ] Registry aliases `dev` / `staging` / `prod` resolve; serving reads the alias, not a version number
- [ ] Promotion criteria written down and gated on evals (pinned set, temperature 0)
- [ ] A teammate can answer "what is in prod and how was it trained?" from the tracker alone

## Related Skills

- `skills/mlops/ml-pipelines` — DVC data versioning that runs reference; CI/CD wiring around promotion
- `skills/mlops/model-serving` — consuming registry aliases at deploy; revision pinning
- `skills/mlops/model-monitoring` — production trends compared against run baselines
- `skills/evals/regression-gates` — the gate logic promotion criteria delegate to
- `skills/evals/eval-design` and `skills/evals/llm-judge` — building the evals whose results get logged

Owning agent: `ai-engineer:mlops-engineer`.
