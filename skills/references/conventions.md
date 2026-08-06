# Skill Authoring Conventions

Content rules every ai-engineer skill follows. Routing lives in
[`../SKILL.md`](../SKILL.md); this file is the authoring contract behind it.

- **uv-first Python.** Examples use `uv run` / `uv add`, ruff-clean and
  type-hinted; versions live in `pyproject.toml`/`uv.lock`, never in prose.
- **Determinism.** Eval examples pin eval-set versions and run at temperature 0
  with fixed seeds; training examples are smoke-scale (capped `max_steps`,
  subsampled data) with the full run as a documented launch plan.
- **No pricing or model-ID snapshots.** Volatile facts (model IDs, prices,
  context-window sizes, library minors) are named as mechanisms with "verify
  against current provider docs (context7)" — cost formulas and levers are
  encouraged, cost tables are forbidden.
- **GPU-optional.** Content degrades gracefully without CUDA: MPS/CPU notes
  where relevant; absent `nvidia-smi` means reduced depth, never a hard
  failure.
- **Language depth delegates.** Pure-Python questions (typing, packaging,
  concurrency, pytest mechanics) route to `system-developer:python-skills` —
  they are not re-taught here.
- **Agents plugin-qualified.** Agents are always referenced as
  `ai-engineer:<name>` (e.g. `ai-engineer:llm-engineer`); ownership per domain
  is mapped in [`../_shared/framework-detection.md`](../_shared/framework-detection.md).
