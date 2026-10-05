---
description: Detect the Python environment and manifest for an AI/ML project, sync dependencies, verify the package imports, and run the test suite. Use as the build gate for the `ai` platform in DV/DR/QA, or before handing work to review.
argument-hint: [path (default .)] [--manager uv|pip|conda] [--clean] [--no-test] [-k EXPR]
allowed-tools: Read, Agent, Glob, Grep, Bash(uv:*), Bash(python3:*), Bash(python:*), Bash(pytest:*), Bash(pip:*), Bash(conda:*), Bash(dvc:*), Bash(ls:*), Bash(mkdir:*), Bash(rm:*), Bash(date:*), Bash(command:*), Bash(tee:*), Bash(jq:*)
---

# Build & Test

Detect an AI/ML project's Python environment, sync its dependencies, verify it imports, and run its tests. The happy path is shell-only; an agent is engaged only when a phase fails, and then only the domain agent that owns the failure, with a short log excerpt.

AI/ML projects have no compile step, so "build" means the environment resolves and the package imports. Those are separate failures with separate owners, and a test-only run hides both. This is also the DR compile-only gate (`--no-test`).

## Rules

1. **One environment manager.** Take the first match in the detection table (or `--manager`); don't run two managers in one invocation.
2. **No delegation on success.** When sync, import, and tests pass, report and stop.
3. **Single-command Bash.** Use each tool's directory flag (`uv sync --project <path>`, `uv run --project <path> pytest`, `pytest --rootdir <path>`) instead of `cd` or `&&` chains, which the scoped `allowed-tools` patterns don't match.
4. **Tee every phase to the log** (`tee -a <log>`); triage reads the log, not scrollback.
5. **Don't invent a compile step.** If the real build is a pipeline or eval, report that and route per § Pipeline and Eval Projects.
6. **Classify before delegating.** Pass one domain agent the classified excerpt — never the whole log, never a second agent.
7. **A missing tool never hard-fails.** Print the install hint, skip that manager, continue down the priority order, and report the skip.
8. **No training runs or full eval sweeps.** Smoke-scale only; deselect markers that launch training or paid evals (Phase 4).
9. Execute directly; don't enter plan mode.

## Usage

```bash
/ai-engineer:build-test .                          # detect, sync, import-check, test
/ai-engineer:build-test services/rag               # a subproject
/ai-engineer:build-test . --no-test                # compile-only gate (DR)
/ai-engineer:build-test . --manager pip --clean    # force pip, fresh env
/ai-engineer:build-test . -k retriever             # scope the suite
```

## Options

| Option | Default | Effect |
|--------|---------|--------|
| `path` | `.` | Directory to detect and operate on. |
| `--manager uv\|pip\|conda` | auto | Force the manager when detection is ambiguous (e.g. both `uv.lock` and `environment.yml`). |
| `--clean` | off | Recreate the environment before syncing: `uv sync --reinstall`, a fresh venv for pip, or `conda env create --force`. |
| `--no-test` | off | Sync and import-check only. The DR compile-only gate; callers depend on this flag. |
| `-k EXPR` | none | Passed to pytest `-k` for scoped re-runs; not a blanket skip. |

## Detection: Environment Priority

Scan `path` for manifest markers (not stray imports); the first match wins.

| Priority | Marker | Manager | Sync command |
|----------|--------|---------|--------------|
| 1 | `uv.lock` | uv (locked) | `uv sync --project <path>` |
| 2 | `pyproject.toml` with `[project]` or `[tool.uv]`, no lock | uv (unlocked) | `uv sync --project <path>` |
| 3 | `pyproject.toml` with `[tool.poetry]` only | pip (PEP 517) | `pip install -e <path>` |
| 4 | `requirements*.txt` | pip | `pip install -r <path>/requirements.txt` |
| 5 | `environment.yml` / `.yaml` | conda | `conda env update -f <path>/environment.yml` |
| 6 | `setup.py` only | pip (legacy) | `pip install -e <path>` |

- `uv.lock` wins because it is the project's declared resolution; ignoring it builds something CI doesn't.
- With both `pyproject.toml` and `requirements*.txt`, use `pyproject.toml` (the requirements file is usually a deploy pin) and mention it.
- Poetry and conda are run faithfully but not mastered: say in the summary that this plugin's guidance assumes uv, and don't rewrite the manifest as a "fix".
- No manifest → check § Pipeline and Eval Projects before reporting failure.

## Pipeline and Eval Projects

Some repos have no importable package. Route them instead of reporting a spurious failure:

| Marker | Real "build" | Action |
|--------|--------------|--------|
| `dvc.yaml`, no importable package | `dvc repro` | Report the stages found; suggest `/ai-engineer:deploy-check`. Don't run `dvc repro` — it can be arbitrarily expensive. |
| `evals/`, `promptfooconfig.yaml`, or deepeval config, no test suite | An eval run | Point to `/ai-engineer:eval-run` and stop. |
| Notebooks only | Nothing buildable | Report "no buildable surface"; suggest extracting testable modules. |

If there is also an importable package, build and test it normally and note the other surface in the summary.

## Workflow

### Phase 1: Detect

1. Confirm `path` exists, else Error Handling.
2. Create `.context/logs/` and fix the log path once: `.context/logs/build-<date +%Y%m%d-%H%M%S>.log`. Shell variables don't persist between Bash calls, so use the literal path in every later command.
3. Pick the manager from the detection table (`--manager` overrides); if nothing matches, check § Pipeline and Eval Projects.
4. Note the owning surface (LLM app / training / serving / mixed) from the manifest's dependencies per `${CLAUDE_PLUGIN_ROOT}/skills/_shared/framework-detection.md`; used for the report and for triage.
5. Check the manager's binary with `command -v`; if absent, apply rule 7.

### Phase 2: Sync

1. With `--clean`, recreate the environment first.
2. Run the sync command, e.g. `uv sync --project <path> 2>&1 | tee -a <log>`.
3. Judge success by the sync's exit status, not `tee`'s. Non-zero → Failure Triage, stage `env`.

### Phase 3: Import Check

The `--no-test` gate's substance: a package that syncs but doesn't import otherwise shows up as a confusing collection error.

1. Resolve top-level package names from `pyproject.toml` (`[project].name`, setuptools/hatch package config) or the `src/` layout.
2. Import them without running entry points:
   ```bash
   uv run --project <path> python -c "import importlib,sys; [importlib.import_module(m) for m in sys.argv[1:]]" <pkg> 2>&1 | tee -a <log>
   ```
3. Non-zero → Failure Triage, stage `import`. No importable package → skip and record why.

### Phase 4: Test

1. With `--no-test`, skip and record "tests skipped (--no-test)"; green phases 2-3 are a PASS.
2. Run pytest, deselecting training and paid-eval markers unless the user asked for them, and passing `-k` through:
   ```bash
   uv run --project <path> pytest -x -q -m "not slow and not training and not eval_paid" 2>&1 | tee -a <log>
   ```
   On pip/conda projects run `pytest --rootdir <path>` directly.
3. Exit code 5 (no tests collected) is not a failure: build PASS, test N/A. Any other non-zero → Failure Triage, stage `test`.

### Phase 5: Report

Emit the Output Format report. On success, stop.

## Failure Triage

1. Take the first error in the log and classify it:

   | Symptom | Stage |
   |---------|-------|
   | `No solution found`, `ResolutionImpossible`, `Could not find a version`, torch/CUDA wheel-platform conflict, `UnsatisfiableError`, network/index failure | `env` |
   | `ModuleNotFoundError`, `ImportError`, import-time `AttributeError`, `error while loading shared libraries`, pytest `ERROR` during collection | `import` |
   | pytest `FAILED`, assertion failures, a failing eval-gate assertion | `test` |

2. Extract the first error plus ~10 lines of context, and include the log path.
3. Delegate with the Agent tool to the owning surface's agent: LLM app → `ai-engineer:llm-engineer`; training (including torch/CUDA wheel conflicts) → `ai-engineer:ml-engineer`; serving/MLOps → `ai-engineer:mlops-engineer`; ambiguous or mixed → `ai-engineer:ai-engineer` with the detected markers. Prompt:

   "`build-test` failed at the **{stage}** stage for the AI project at `{path}` (manager: {manager}). First error and context from `{log}`:\n```\n{excerpt}\n```\nDiagnose the root cause and propose the minimal fix. If the fix touches dependency pins or the lockfile, say so explicitly. Do not re-run the suite; return the analysis and patch."

4. After a fix, re-run from the failing phase (re-sync if the manifest changed). Report each cycle.

## Tool Availability

| Missing tool | Install hint |
|--------------|--------------|
| `uv` | `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| `pip` | `python3 -m ensurepip --upgrade` |
| `conda` | install Miniforge/Miniconda |
| `pytest` | `uv add --dev pytest`, or `pip install pytest` |

A missing `nvidia-smi` is never a build failure. CUDA-only tests that hard-fail on a CPU host are a project defect (they should be marker-skipped), not a build failure.

## Output Format

```markdown
## Build & Test Report

**Target:** {path}
**Manager:** {uv | pip | conda} ({marker})
**Owning surface:** {LLM app | training | serving/MLOps | mixed}
**Log:** .context/logs/build-{timestamp}.log

| Phase | Result | Notes |
|-------|--------|-------|
| Sync | ✅ / ❌ / ⏭ skipped | {packages resolved, or skip reason} |
| Import | ✅ / ❌ / ⏭ | {packages imported, or "no importable package"} |
| Test | ✅ / ❌ / ⏭ | {N passed, M failed, or "--no-test" / "no tests found"} |

**Result:** PASS / FAIL ({failing stage})

<!-- On failure only: -->
### Failure Triage
- **Stage:** {env | import | test}
- **First error:** {one-line summary}
- **Delegated to:** ai-engineer:{agent}
- **Proposed fix:** {summary from agent, or "see agent output"}

<!-- When a pipeline/eval surface was detected: -->
### Other Surfaces
- {dvc.yaml | evals/ | notebooks}: {what it is} — {command to use instead}

<!-- On skipped managers only: -->
### Skipped
- {manager}: {missing tool} — install hint printed above.
```

## Error Handling

| Condition | Response |
|-----------|----------|
| Path not found | `Error: Path not found: {path}` — suggest an existing directory, e.g. `/ai-engineer:build-test .` |
| No recognized Python project | `Error: No Python environment detected under {path}.` List the markers looked for (uv.lock, pyproject.toml, requirements*.txt, environment.yml, setup.py); suggest running from the manifest's directory, or see Other Surfaces for pipeline/eval repos. |
| No tests found (pytest exit 5) | Not an error: "no tests found — sync and import succeeded"; build PASS, test N/A. Suggest `/ai-engineer:eval-run` if the repo has an eval harness. |
| `--manager` forced but absent | `Warning: --manager {name} requested but {binary} is not installed.` Fall back to detection order and print the install hint. |
| Every eligible manager missing | FAIL, with the aggregated install hints. |

## See Also

- `${CLAUDE_PLUGIN_ROOT}/skills/_shared/framework-detection.md` — marker → domain → agent routing.
- `/ai-engineer:eval-run` — runs eval suites; this command doesn't.
- `/ai-engineer:review-code` — review once the build is green.
- `/ai-engineer:deploy-check` — serving readiness for a green build.
