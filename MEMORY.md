# ai-engineer Plugin Memory

## Version Tracking

| Field | Value |
|-------|-------|
| Plugin version | 1.2.0 |
| igrsoft compatibility | v3.36.0 |
| Claude Code min required | — (not pinned in the manifests) |
| Last updated | 2026-07-29 |

Version strings move together (plugin.json, marketplace.json metadata, README
header, this table) per the igrsoft `/cc-update` convention.

## CC Features Adopted at 1.0.0

The plugin is born on the igrsoft v3.36.0 baseline, so it adopts the current
capability set from the start rather than migrating into it:

- **Tiered `maxTurns`** — every agent declares a runaway-loop backstop sized to
  its role: haiku/low 20 (`ai-dependency-manager`), haiku/medium 30
  (`ai-code-fixer`), sonnet/medium 40 (`ai-engineer` router), sonnet/high 50
  (the four domain implementers, `ai-test-generator`, `ai-security-auditor`,
  `ai-performance-engineer`), opus/xhigh 60 (`ai-architector`).
- **`disallowed-tools: Write, Edit`** — declared on the two review-only agents
  (`ai-security-auditor`, `ai-performance-engineer`) as defense-in-depth on top
  of their already Write/Edit-free `tools:` allow-lists. Fixes route to
  `ai-code-fixer`.
- **Fully-qualified `Task(plugin:agent)` references** — all delegations use the
  `Task(ai-engineer:<agent>)` / `subagent_type="ai-engineer:<agent>"` form; no
  bare agent names anywhere. Cross-plugin targets keep their own prefix
  (`igrsoft:*`, `system-developer:*`, etc.).
- **Scoped `Bash(cmd:*)` allowlists** — each agent's `tools:` enumerates only
  the toolchain binaries it needs (core set `git`, `uv`, `python3`, `pytest`,
  `ruff`, `jq`; role-specific additions like `nvidia-smi`, `docker`, `dvc`,
  `mlflow`, `wandb`, `pip-audit`, `osv-scanner`, `bandit`, `semgrep`, `gitleaks`,
  `trufflehog`, `hf`/`huggingface-cli`, `py-spy`, `hyperfine`).
- **context7 MCP pair** — `mcp__plugin_context7_context7__resolve-library-id` +
  `query-docs` on every agent for library-docs lookups; the load-bearing half of
  the no-hardcoded-volatile-facts rule (decision h below).
- **Plugin-scoped advisory hooks** — `hooks/{audit-tooluse,audit-subagent,
  precompact-checkpoint}.sh`, wired in `plugin.json` (PostToolUse /
  SubagentStop / PreCompact); igrsoft-compatible `dedupe_key` /
  `dedupe_key_extended` shape and `metadata.advisory: true` rows so igrsoft's
  `audit-dedup.sh` keeps the orchestrator row authoritative when ai-engineer
  runs nested. Each script has `--self-test`.

## Not Adopted (igrsoft-owned infrastructure)

ai-engineer agents are invoked specialists; igrsoft owns orchestration. The
following stay orchestrator-owned and are deliberately **not** implemented here:

- **`audit-dedup.sh`** — igrsoft-owned. ai-engineer emits advisory rows with
  matching dedupe keys for igrsoft's helper to reconcile.
- **`state-merge.sh` / SubagentStop `state.json` merge** — orchestrator-owned.
  The hooks here read and checkpoint state but never merge it. Frontmatter
  emission is unconditional (it is the input igrsoft's merge layer consumes).
- **Screenshot-gate ownership** — igrsoft owns the evidence gate. ai-engineer
  work defaults to `requires_screenshots: false` and, when a gate demands
  proof, supplies a `cli-fallback` manifest (eval reports, loss-curve textual
  summaries, test transcripts — produced this run, per the freshness rule). It
  does not own or override the gate itself.

## Decisions Log (v1.0.0 build)

- **`prompt-evaluation` merged into `evals/eval-design`** — an early roster
  draft had a standalone `prompt-evaluation` skill; it was folded into
  `skills/evals/eval-design/SKILL.md`, whose paired prompt A/B comparison
  section is where prompt-variant evaluation lives (with `evals/llm-judge` and
  `evals/regression-gates` as its siblings). Do not re-create a separate
  prompt-evaluation skill; extend eval-design instead.
- **`_shared/scripts/detect_ai_stack.sh` deferred to v1.1** — the
  marker → domain → agent mapping in `skills/_shared/framework-detection.md`
  is a pure lookup table an agent reads in one pass; a script would add an
  execution dependency without saving tokens. Deferral also keeps v1 free of a
  bats harness: there is **no `tests/` directory** in v1, and
  `scripts/test.sh` documents re-adding the bats/pytest suites when one
  exists.
- **`ai-prompt-engineer` naming** — the bare name `prompt-engineer` collides
  with igrsoft's meta-prompt agent (`igrsoft:prompt-engineer`, which owns
  Claude Code agent/skill/command prompts). The `ai-` prefix on colliding
  Tier-2 names mirrors the sibling plugins' prefix families (`sys-` in
  system-developer, `fe-`/`be-` in frontend/backend-developer). The agent's
  description carries the disambiguation both ways: product prompts here,
  meta-prompts to igrsoft.
- **Smoke-scale training rule** — DV never launches full training runs: capped
  `max_steps`/epochs on a data subsample, verify the loss curve moves
  (decreasing, no NaN), and document the full-run launch plan (command, data,
  expected duration/cost) in `development-N.md`. DR fails a DV artifact whose
  transcripts show an uncapped training invocation. Canonical text in
  `skills/_shared/workflow-integration/references/stage-details.md § DV Contract for AI Work`; training
  examples across the finetuning skills follow it.
- **`validate.sh` `ALLOWED_PREFIX_RE` keeps `system-developer`** — the
  subagent-type prefix whitelist is
  `^(ai-engineer|igrsoft|system-developer|general-purpose)` because ai-engineer
  skills legitimately cross-reference system-developer's Python agents
  (`system-developer:python-developer` for pure language depth, per
  `framework-detection.md § Precedence vs Sibling Plugins`). Do not "clean up"
  the third prefix; it is load-bearing.
- **Hooks ported verbatim from system-developer** — the three hook scripts are
  the system-developer implementations with only name swaps
  (`ai-engineer:hook:*` actors, plugin name in headers) and one comment-path
  fix in `precompact-checkpoint.sh` (the PostCompact-recovery pointer now
  names `skills/_shared/workflow-integration/SKILL.md`, this plugin's path).
  Keep them in lockstep with upstream: a behavior fix in system-developer's
  hooks should be re-ported, not diverged from.
- **`marketplace.json` duplicates `plugin.json`'s full keyword list** — house
  convention (system-developer keeps marketplace keywords a superset of
  plugin.json's; here they are identical). When adding a keyword, add it to
  both manifests in the same change.
- **No pricing/model-ID hardcoding anywhere** — standing rule across agents,
  skills, and commands: volatile facts (model IDs, prices, context-window
  sizes, library minor versions) are never written down; content names the
  mechanism/lever and says "verify against current provider docs (context7)".
  Cost formulas are allowed; cost tables are not. Reviews should flag any
  snapshot number that will rot.
- **Repo-mode lints enumerate via `git ls-files`** — `desc-lint.sh` and
  `section-lint.sh` (no-argument repo mode) list files with
  `git ls-files -- 'agents/*.md' …`, so **untracked files are invisible to
  them**. Stage (`git add -N` at minimum) new agents/commands/skills before a
  repo-mode lint run, or lint the new file explicitly by path
  (`scripts/desc-lint.sh <file>`); `scripts/test.sh` inherits the same
  visibility rule through its desc-lint step.

## igrsoft Registration (pending companion change)

Standalone install works today: slash commands (`/ai-engineer:*`), skills, and
direct `Task(ai-engineer:*)` delegation. Auto-routing from the igrsoft
worktask (DV dispatch on AI markers, `--platform ai`) requires edits **in the
company-workflow repo** — exact before/after snippets in
`docs/igrsoft-registration.md`. Until that PR lands, route AI worktasks by
stamping `metadata.agent: "ai-engineer:ai-engineer"` explicitly.
