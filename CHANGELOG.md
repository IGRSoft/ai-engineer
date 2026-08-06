# Changelog

All notable changes to the **ai-engineer** plugin are documented here. The
format follows [Keep a Changelog](https://keepachangelog.com/) and the project
adheres to [Semantic Versioning](https://semver.org/). Version strings move
together across `plugin.json`, `marketplace.json`, `README.md`, and `MEMORY.md`
per the company-workflow `/cc-update` convention.

## [1.3.0] — 2026-08-06

### Added

- **`finetuning/grpo-rlvr-training`** — reinforcement learning from verifiable
  rewards (GRPO/RLVR): reward function design, group-relative advantage
  mechanics, and when a program (tests, schemas, math) can check the answer
  instead of a preference model.
- **`finetuning/quantized-export`** — the export lifecycle for a promoted
  checkpoint: merged safetensors, LoRA-only, GGUF+imatrix, and FP8 targets,
  vendor-neutral throughout.
- **`finetuning/checkpoint-promotion`** — promotion gating for a finished
  training run: drift budgets, paired comparison, and catastrophic-forgetting
  checks that decide whether a checkpoint ships.
- **`finetuning/trace-to-training-data`** — converting graded eval traces into
  training data: rejection sampling, preference pairs from graded traces, and
  a goldens-holdout gate during conversion.
- **`llm-apps/rag-systems/references/embedding-and-index-tuning.md`** —
  vector-index and embedding tuning depth (hybrid search, index parameters,
  RRF `k` rationale) folded into the existing `rag-systems` skill.
- **Vendor-neutral unified-memory note** folded into
  `finetuning/training-optimization/references/gpu-memory-math.md`.

### Fixed

- **Paired incumbent disambiguation edits** on the four skills each new skill
  collides with (`model-serving`, `finetuning/SKILL.md` + `dataset-curation`,
  `preference-tuning`, `regression-gates` + `ml-pipelines` + `experiment-tracking`)
  — routing seams and `When NOT to use` rows so the two skill pairs each stay
  distinguishable at trigger time.
- **Three folded-YAML trigger-phrase reflows** (`mlops/SKILL.md`,
  `llm-apps/SKILL.md`, `llm-apps/llm-api-patterns/SKILL.md`) so `Use when` /
  `Use PROACTIVELY` stays contiguous on one physical line for regex-based
  trigger scanners.
- **`scripts/test.sh`** — ShellCheck ≥0.11 compatibility; a prose comment
  beginning with the linter's own name was being parsed as a directive.

### Changed

- **Routing** refreshed across `skills/_index.md`, `skills/SKILL.md`,
  `skills/finetuning/_index.md`, `skills/finetuning/SKILL.md`,
  `skills/llm-apps/_index.md`, `skills/llm-apps/rag-systems/SKILL.md`, four
  agents (`ml-engineer`, `mlops-engineer`, `ai-engineer`, `ai-architector`),
  three commands (`finetune-plan`, `deploy-check`, `rag-audit`), and both
  manifests (`.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` —
  keyword lists plus skill registrations for the four new directories).

## [1.2.0] — 2026-07-29

### Added

- **`/ai-engineer:build-test`** — the `ai` platform's build gate. company-workflow's
  build-delegation table (`company-workflow/agents/developer.md § Build
  Verification`) routes every platform's DV/DR/QA build through
  `/<plugin>:build-test`, and its `ai` row pointed at a command that did not
  exist, leaving the platform with no build gate at all. Detects the Python
  environment by manifest priority (`uv.lock` → `pyproject.toml` → Poetry →
  `requirements*.txt` → conda `environment.yml` → `setup.py`), syncs, verifies
  the package imports, and runs pytest — absorbing the log and returning a
  verdict plus a classified excerpt rather than dumping output. Failures are
  classified `env` / `import` / `test` and delegated to the one matching domain
  agent (`llm-engineer` / `ml-engineer` / `mlops-engineer`) resolved through
  `skill: framework-detection`, never a forked copy of that table.

  AI/ML projects have no compile step, so "build" here is *sync + import*, and
  the command says so rather than fabricating one: repos whose real build is a
  DVC pipeline, an eval harness, or notebooks are detected and routed to the
  right command instead of being reported as a build failure. `--no-test` is
  the compile-only gate company-workflow's DR stage depends on. Poetry and conda are
  detected and run faithfully but explicitly *not* mastered — the summary says
  the plugin's guidance assumes uv rather than rewriting the project manifest.

  This does **not** reverse the "ai-engineer keeps its own command set"
  exception recorded in `compatible-plugins.md`; it adds the single command the
  orchestrator structurally requires for the `ai` platform to be routable.
  Registered in `marketplace.json` `commands[]`.

- **AR consultation model documented** in `workflow-integration` — closing the
  last open item of the company-workflow dev-plugin compatibility contract (§ A.6). The
  skill now states explicitly that `company-workflow:software-architector` **owns** the
  AR stage and `analyzing-N.md`, while `ai-architector` is *consulted*: it
  writes `.context/ai-architecture.md` and returns a ≤500-token recommendation
  that the owner merges. The stage-owner exception (`task.metadata.agent` names
  `ai-engineer:ai-architector`) is spelled out so the two modes are not
  conflated. Previously this was implied by a single table cell in `SKILL.md`
  and by `ai-architector`'s own frontmatter, with no artifact path recorded
  anywhere in the plugin.
- **AR row in the per-stage handoff frontmatter matrix**
  (`references/stage-details.md`) — `key_decisions`, `next_stage_focus`,
  `open_questions`; verdict ∈ ok/blocked/escalate. The matrix previously
  covered DV, DR, and QA only.
- **`templates/ar-consultation.md`** — copy-paste AR artifact skeleton
  (context, options table, decision, consequences, revisit-when, eval-plan),
  joining the existing DV/DR/QA templates.
- **`references/dv-worked-example.md`** — a filled-in end-to-end DV takeover by
  `ai-engineer:llm-engineer` with real values: dispatch metadata (including
  `error_file` derivation and `requires_screenshots: false`), emitted `handoff:`
  frontmatter, the Build Evidence block supplied *instead of* screenshots, the
  ≤500-token return, and the gate re-dispatch path. The existing templates show
  the shape; this shows one concrete instance end to end.
- **`§ DV-Support Roles` in `workflow-integration/SKILL.md`** — the stage table
  named `ai-prompt-engineer` and `ai-dependency-manager` but omitted
  `ai-performance-engineer` entirely and never labelled any of the three as
  DV-support, so it did not agree with the `ai-engineer` stage→agent table in
  `company-workflow:cross-plugin-handoff` (which lists all three as DV-support rows).
  The new section restores exact agreement and records the review-only
  constraint on `ai-performance-engineer` / `ai-security-auditor`.

### Fixed

- **`mlops-engineer` can now actually operate W&B**, not just MLflow. The agent
  advertises `MLflow/W&B tracking` in its description, requires
  "MLflow/W&B configured … no anonymous runs" in its own checklist, and owns
  `skills/mlops/experiment-tracking`, whose `MLflow ↔ W&B Mapping` table treats
  the two as equals — but its `tools:` allowlist granted `Bash(mlflow:*)` with
  no `Bash(wandb:*)`. On a W&B-tracked repo the CLI-shaped operations that
  skill prescribes (`wandb login`, `wandb offline`, `wandb sync`) failed
  silently on a permission mismatch rather than a stated limitation. Added
  `Bash(wandb:*)`; `MEMORY.md`'s toolchain inventory is synced to match.
  Every other ecosystem this agent claims was already granted symmetrically
  (`docker`, `dvc`, `nvidia-smi`) or withheld symmetrically (no engine binary
  for any of vLLM/TGI/Ollama/Triton) — tracking was the sole asymmetric pair.

## [1.1.0] — 2026-07-29

### Changed

- **`code-review` → `review-code`** and **`security-scan` → `analyze-security`**
  — the two commands whose names overlapped the company-workflow dev-plugin surface are
  renamed to the `<verb>-<noun>` command standard shared with
  `apple-developer`, so a qualified name is no longer needed to disambiguate
  intent. The six domain-specific commands (`eval-run`, `prompt-optimize`,
  `rag-audit`, `finetune-plan`, `data-audit`, `deploy-check`) keep their names.
  Behavior, `allowed-tools`, and `estimated-cost` bands are unchanged;
  `analyze-security` remains read-only (no `Write`/`Edit`).

  **Migration**: replace `/ai-engineer:code-review` with
  `/ai-engineer:review-code`, and `/ai-engineer:security-scan` with
  `/ai-engineer:analyze-security`. There is no deprecation alias — the old
  names stop resolving on upgrade. References to `/system-developer:code-review`
  are unaffected: that is a different plugin's command.

## [1.0.0] — 2026-07-23

Initial release. The plugin is born on the igrsoft (company-workflow) v3.36.0
baseline — sibling to `system-developer` and `apple-developer` — so it adopts
the current workflow contract from the start: numbered `<stage>-N.md`
artifacts, unconditional `handoff:` frontmatter, the `state-patch.sh` pointer
form, gate-feedback consumption (`metadata.gate_from_stage` +
`metadata.gate_blockers[]`), per-agent error files, the
`requires_screenshots: false` / cli-fallback evidence norm with the
evidence-freshness rule, and the smoke-scale training rule for DV.

### Added

- **11 agents + `agents/_base/ai-agent.md`** — `ai-engineer` (router,
  sonnet/medium), four domain implementers (`llm-engineer`, `ml-engineer`,
  `mlops-engineer`, `ai-prompt-engineer` — sonnet/high), `ai-architector`
  (opus/xhigh AR consultant), and five Tier-2 specialists:
  `ai-test-generator` (sonnet/high), the two review-only auditors
  `ai-security-auditor` and `ai-performance-engineer` (sonnet/high,
  `disallowed-tools: Write, Edit`), `ai-code-fixer` (haiku/medium), and
  `ai-dependency-manager` (haiku/low). Tiered `maxTurns` (20/30/40/50/60),
  scoped `Bash(cmd:*)` allowlists, fully-qualified `Task(ai-engineer:<agent>)`
  delegations, and the context7 MCP pair on every agent.
- **8 commands** — `code-review`, `eval-run`, `prompt-optimize`, `rag-audit`,
  `finetune-plan`, `data-audit`, `deploy-check`, `security-scan`; each with
  restrictive `allowed-tools`, an `estimated-cost` band, and graceful
  degradation when a tool is missing.
- **Skills tree: 24 `SKILL.md` across 5 domains + `_shared`** —
  `prompt-engineering` (prompt-design, context-engineering,
  structured-outputs), `llm-apps` (rag-systems, agent-design,
  llm-api-patterns), `finetuning` (dataset-curation, peft-lora,
  training-optimization, preference-tuning), `mlops` (experiment-tracking,
  model-serving, model-monitoring, ml-pipelines), `evals` (eval-design,
  llm-judge, regression-gates), plus domain entry skills, a root routing
  skill, 7 `_index.md` indexes, 20 deep `references/` files, and the
  `_shared` references (`workflow-integration` + 3 DV/DR/QA templates,
  `framework-detection`, `model-selection`, `severity-matrix`).
  House rules baked in: no hardcoded model IDs/prices (hedge-and-verify via
  context7), GPU-optional discipline (MPS/CPU fallbacks; missing `nvidia-smi`
  is a reduced-depth note, not a failure), deterministic eval examples
  (pinned eval-set versions, temperature 0 / fixed seeds), smoke-scale
  training examples, and `uv`/ruff-clean type-hinted Python.
- **Plugin-scoped advisory hooks** — `audit-tooluse.sh` (PostToolUse),
  `audit-subagent.sh` (SubagentStop), `precompact-checkpoint.sh` (PreCompact),
  wired in `plugin.json`; company-workflow-compatible `dedupe_key` shape,
  `metadata.advisory: true` rows, `--self-test` on each script; never merges
  `state.json` (orchestrator-owned).
- **Scripts** — `validate.sh` (release gate: manifests, frontmatter, link and
  anchor integrity, subagent-type prefix whitelist), `test.sh` (bash -n +
  shellcheck + hook self-tests + `validate --strict` + prose lints, with
  `--strict` CI mode), `desc-lint.sh` (two-tier ambient-description caps,
  fatal), `section-lint.sh` (≤1000-char section cap, warn-only baseline).
- **Manifests** — `.claude-plugin/plugin.json` (hooks wiring, full keyword
  list) and `.claude-plugin/marketplace.json` (directory-source marketplace
  registering agents, commands, and every skill directory; keywords
  duplicated from `plugin.json` per house convention).
- **company-workflow v3.36.0 integration** — `skills/_shared/workflow-integration/`
  documents the DV contract for AI work (AI Build Evidence: `python -VV`,
  framework versions from `uv.lock`, ruff/type status, test transcript under
  `.context/logs/`, eval metrics vs baseline when prompts/models/retrieval
  change), the screenshot cli-fallback procedure with the evidence-freshness
  rule, DR AI review criteria, the QA eval-regression gate, SR/RE
  contributions, dynamic worktask sizing, and qualified-name delegation.
  Registration of ai-engineer as a routable company-workflow platform (`--platform ai`,
  DV auto-routing) is a companion change to the company-workflow repo,
  specified in `docs/company-workflow-registration.md`.

### Notes

- No `tests/` directory in v1 — `scripts/test.sh` drops the bats/pytest
  suites of the system-developer original and documents re-adding them when a
  `tests/` dir exists. `_shared/scripts/detect_ai_stack.sh` is deferred to
  v1.1 (`framework-detection.md` is a pure lookup table; nothing to execute).
- `skills/evals/eval-design` absorbs prompt A/B evaluation — there is no
  separate `prompt-evaluation` skill (see `MEMORY.md § Decisions Log`).
