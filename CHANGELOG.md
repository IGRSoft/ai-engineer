# Changelog

All notable changes to the **ai-engineer** plugin are documented here. The
format follows [Keep a Changelog](https://keepachangelog.com/) and the project
adheres to [Semantic Versioning](https://semver.org/). Version strings move
together across `plugin.json`, `marketplace.json`, `README.md`, and `MEMORY.md`
per the igrsoft `/cc-update` convention.

## [1.1.0] — 2026-07-29

### Changed

- **`code-review` → `review-code`** and **`security-scan` → `analyze-security`**
  — the two commands whose names overlapped the igrsoft dev-plugin surface are
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
  wired in `plugin.json`; igrsoft-compatible `dedupe_key` shape,
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
- **igrsoft v3.36.0 integration** — `skills/_shared/workflow-integration/`
  documents the DV contract for AI work (AI Build Evidence: `python -VV`,
  framework versions from `uv.lock`, ruff/type status, test transcript under
  `.context/logs/`, eval metrics vs baseline when prompts/models/retrieval
  change), the screenshot cli-fallback procedure with the evidence-freshness
  rule, DR AI review criteria, the QA eval-regression gate, SR/RE
  contributions, dynamic worktask sizing, and qualified-name delegation.
  Registration of ai-engineer as a routable igrsoft platform (`--platform ai`,
  DV auto-routing) is a companion change to the company-workflow repo,
  specified in `docs/igrsoft-registration.md`.

### Notes

- No `tests/` directory in v1 — `scripts/test.sh` drops the bats/pytest
  suites of the system-developer original and documents re-adding them when a
  `tests/` dir exists. `_shared/scripts/detect_ai_stack.sh` is deferred to
  v1.1 (`framework-detection.md` is a pure lookup table; nothing to execute).
- `skills/evals/eval-design` absorbs prompt A/B evaluation — there is no
  separate `prompt-evaluation` skill (see `MEMORY.md § Decisions Log`).
