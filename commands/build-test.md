---
description: Detect the Python environment and manifest for an AI/ML project, sync dependencies, verify the package imports, and run the test suite. Use as the build gate for the `ai` platform in DV/DR/QA, or before handing work to review.
argument-hint: [path (default .)] [--manager uv|pip|conda] [--clean] [--no-test] [-k EXPR]
allowed-tools: Read, Glob, Grep, Bash(uv:*), Bash(python3:*), Bash(python:*), Bash(pytest:*), Bash(pip:*), Bash(conda:*), Bash(dvc:*), Bash(ls:*), Bash(mkdir:*), Bash(rm:*), Bash(date:*), Bash(command:*), Bash(tee:*), Bash(jq:*)
estimated-cost:
  min-tokens: 1500
  max-tokens: 12000
  model-distribution:
    haiku: 40%
    sonnet: 55%
    opus: 5%
---

# Build & Test
<!-- Updated: July 2026 -->

Detect an AI/ML project's Python environment, sync its dependencies, verify it imports, and run its tests in one call. The happy path is pure Bash — no agent delegation. Agents are engaged only when a phase fails, and only the domain agent that owns the failing surface, with a tight log excerpt.

[Extended thinking: This is the `ai` platform's build gate — `the orchestrator's platform router § Build Verification` routes here, and DR calls it with `--no-test` as its compile-only check. AI/ML projects have no compile step, so "build" here means *the environment resolves and the package imports*: a dependency-resolution failure and an import failure are different bugs with different owners, and both are invisible to a test-only run. Because raw install and pytest logs are the largest avoidable context cost in the pipeline, everything tees to a log and only a classified excerpt is ever handed to an agent. Where a project's real build is a data pipeline or an eval, say so and route there rather than inventing a compile phase that does not exist.]

## CRITICAL BEHAVIORAL RULES

You MUST follow these rules exactly. Violating any of them is a failure.

1. **Resolve exactly one environment manager.** Walk the detection priority order top-down and stop at the first match. Do NOT run two managers in one invocation. `--manager` overrides detection.
2. **Happy path is shell-only.** When sync, import check, and tests all succeed, do NOT delegate to any agent. Report and stop.
3. **Single-command Bash invocations.** Use each tool's own directory flags (`uv sync --project <path>`, `uv run --project <path> pytest`, `pip install -r <path>/requirements.txt`, `pytest --rootdir <path>`). Never `cd`-chain or `&&`-chain — the scoped Bash patterns in this command's `allowed-tools` do not match compound commands.
4. **Tee every phase to the log.** Each phase pipes through `tee -a` to `.context/logs/build-<timestamp>.log`. The log is the single source of truth for triage; never rely on scrollback.
5. **There is no compile step — do not invent one.** "Build" is sync + import. If a project's real build artifact is a pipeline or an eval, report that and point at the right command (see § Pipeline and Eval Projects) rather than reporting a fabricated build phase.
6. **On failure, classify before delegating.** Parse the first error, classify it as `env` / `import` / `test`, then delegate ONLY to the matching domain agent with the excerpt — never the whole log, never a second agent "just in case."
7. **Tool-missing never hard-fails.** If a manager's binary is absent, print the install hint, skip that manager, and continue down the priority order. Report what was skipped.
8. **Never launch training or a full eval sweep.** This command builds and tests. Smoke-scale only; a `pytest` marker that triggers a training run or a paid eval sweep must be deselected (see § Test Phase).
9. **Never enter plan mode.** This command IS the procedure — execute it.

## Usage

```bash
# Detect, sync, import-check, and test the current directory
/ai-engineer:build-test .

# Build a specific subproject
/ai-engineer:build-test services/rag

# Compile-only gate (what corpflow's DR stage calls)
/ai-engineer:build-test . --no-test

# Force pip on a repo that also carries a uv.lock, fresh env
/ai-engineer:build-test . --manager pip --clean

# Scope the suite to the touched surface
/ai-engineer:build-test . -k retriever
```

## Options

| Option | Default | Effect |
|--------|---------|--------|
| `path` | `.` | Directory to detect and operate on. The detection scan is rooted here. |
| `--manager uv\|pip\|conda` | auto | Force the environment manager when detection is ambiguous (e.g. a repo carrying both `uv.lock` and `environment.yml`). |
| `--clean` | off | Recreate the environment before syncing: `uv sync --reinstall`, a fresh venv for pip, or `conda env create --force`. Slower; use when a stale env is suspected. |
| `--no-test` | off | Sync and import-check only; skip the test phase. **This is the DR compile-only gate** — the orchestrator's platform router depends on this flag existing. |
| `-k EXPR` | none | Pass a pytest `-k` selection expression through to the test phase. Use for scoped re-runs; never as a blanket skip. |

## Detection: Environment Priority

Scan `path` and apply the **first** match top-down. Manifest markers only — never stray imports.

| Priority | Marker | Manager | Sync command |
|----------|--------|---------|--------------|
| 1 | `uv.lock` | uv (locked) | `uv sync --project <path>` |
| 2 | `pyproject.toml` with `[project]` or `[tool.uv]`, no lock | uv (unlocked) | `uv sync --project <path>` |
| 3 | `pyproject.toml` with `[tool.poetry]` only | pip (PEP 517 fallback) | `pip install -e <path>` |
| 4 | `requirements*.txt` | pip | `pip install -r <path>/requirements.txt` |
| 5 | `environment.yml` / `environment.yaml` | conda | `conda env update -f <path>/environment.yml` |
| 6 | `setup.py` with none of the above | pip (legacy) | `pip install -e <path>` |

**Tie-break notes:**

- `uv.lock` beats every other marker: a lockfile is the project's declared resolution, and ignoring it produces a build that does not match CI.
- A repo with both `pyproject.toml` and `requirements*.txt` uses the `pyproject.toml` path; `requirements*.txt` in that case is usually a deploy pin, not the dev env. Mention it in the summary.
- **Poetry and conda are detected, not mastered.** This plugin's own tooling standard is uv (`skills/_shared` house rule). On a Poetry or conda project, run the sync and report faithfully, but say in the summary that the plugin's guidance assumes uv — do not rewrite the project's manifest as a "fix."
- No Python manifest at all → see § Pipeline and Eval Projects before reporting a failure.

## Pipeline and Eval Projects

Some AI/ML repos have no importable package — their real build is a data pipeline or an eval harness. Detect and route rather than reporting a spurious build failure:

| Marker | What the "build" actually is | Route to |
|--------|------------------------------|----------|
| `dvc.yaml` and no importable package | Pipeline reproduction (`dvc repro`) | Report the pipeline stages found; suggest `/ai-engineer:deploy-check` for serving readiness. Do NOT run `dvc repro` here — it can be arbitrarily expensive. |
| `evals/`, `promptfooconfig.yaml`, deepeval config, and no test suite | An eval run, not a unit-test suite | `/ai-engineer:eval-run` — say so and stop; this command does not run eval suites. |
| Notebooks only (`*.ipynb`, no package, no tests) | Nothing buildable | Report "no buildable surface"; suggest extracting testable modules. |

When a project has *both* an importable package and one of these, build and test the package normally and note the pipeline/eval surface in the summary.

## Workflow

### Phase 1: Detect (Bash)

1. Confirm `path` exists. If not, emit the Error Handling "path not found" message and stop.
2. Create `.context/logs/` if absent. Compute `TS="$(date +%Y%m%d-%H%M%S)"` and `LOG=".context/logs/build-${TS}.log"`.
3. Walk the detection priority table top-down; record the first matching marker and manager. `--manager` overrides. If nothing matches, check § Pipeline and Eval Projects before emitting "no recognized Python project".
4. Read the dependency manifest and pre-resolve the **owning domain agent** from the marker table in `skill: framework-detection` (used only if a later phase fails). Do not fork that table — read it.
5. Verify the manager's binary exists (`command -v uv` / `pip` / `conda`). If missing, print the install hint (§ Tool Availability), skip to the next eligible manager, and note the skip.

### Phase 2: Sync (Bash)

1. If `--clean`: recreate the environment first (`uv sync --reinstall --project <path>`, a fresh venv for pip, `conda env create --force`).
2. Run the sync command from the detection table, teeing to the log:
   ```bash
   uv sync --project "$path" 2>&1 | tee -a "$LOG"
   ```
3. Capture the exit status (`${PIPESTATUS[0]}`, not `tee`'s). On non-zero, go to Failure Triage with stage `env`.

### Phase 3: Import Check (Bash)

This is the closest analog to a compile step and the substance of the `--no-test` gate — a package that syncs but does not import is broken, and a test-only run reports that as a confusing collection error.

1. Resolve the top-level package name(s) from `pyproject.toml` (`[project].name`, `[tool.setuptools]`/`[tool.hatch]` package config) or the `src/` layout.
2. Import each without executing entry points, teeing to the log:
   ```bash
   uv run --project "$path" python -c "import importlib,sys; [importlib.import_module(m) for m in sys.argv[1:]]" <pkg> 2>&1 | tee -a "$LOG"
   ```
3. On non-zero, go to Failure Triage with stage `import`.
4. If no importable package exists (pipeline/eval/notebook repo), skip this phase and record why — see § Pipeline and Eval Projects.

### Phase 4: Test (Bash)

1. If `--no-test`: skip; record "tests skipped (--no-test)" and go to Phase 5. This is the DR gate's terminal state and counts as PASS when phases 2-3 are green.
2. Run pytest, teeing to the log. Deselect training and paid-eval markers per rule 8 unless the user asked for them:
   ```bash
   uv run --project "$path" pytest -x -q -m "not slow and not training and not eval_paid" 2>&1 | tee -a "$LOG"
   ```
   Pass `-k EXPR` through when supplied. On pip/conda projects use `pytest --rootdir "$path"` directly.
3. Capture `${PIPESTATUS[0]}`. Exit code 5 (`no tests collected`) is **not** a failure — report "no tests found" and treat the run as PASS for build, N/A for test.
4. On any other non-zero, go to Failure Triage with stage `test`.

### Phase 5: Report (Bash)

Emit the Output Format summary. On full success, stop — no delegation.

## Failure Triage

Triggered only when a phase exits non-zero.

1. **Parse the first error** from the log, top-down.
2. **Classify the stage:**

   | Symptom in log | Stage |
   |----------------|-------|
   | `No solution found`, `ResolutionImpossible`, `Could not find a version`, CUDA/torch wheel-platform conflict, `UnsatisfiableError` (conda), network/index failure | `env` |
   | `ModuleNotFoundError`, `ImportError`, `AttributeError` at import time, `error while loading shared libraries`, pytest `ERROR` during **collection** | `import` |
   | pytest `FAILED`, assertion/expectation failures, a failing eval-gate assertion, nonzero pytest exit other than 5 | `test` |

3. **Extract a tight excerpt** — the first error plus ~10 lines of surrounding context, not the whole log. Include `$LOG` so the agent can read more.
4. **Delegate to the domain agent** resolved in Phase 1 from `skill: framework-detection`:

   - LLM-app surface (`anthropic`, `openai`, `langchain`, `llama-index`, `litellm`, `instructor`):
     **Use Task tool with subagent_type="ai-engineer:llm-engineer"**
     Prompt: "`build-test` failed at the **{stage}** stage for the AI project at `{path}` (manager: {manager}). First error and context from `{LOG}`:\n```\n{excerpt}\n```\nDiagnose the root cause and propose the minimal fix. If the fix touches dependency pins or the lockfile, say so explicitly. Do not re-run the suite; return the analysis and patch."
   - Training/fine-tuning surface (`torch`, `transformers`, `peft`, `trl`, `accelerate`, `bitsandbytes`, `datasets`) → **subagent_type="ai-engineer:ml-engineer"** (same prompt shape). Torch/CUDA wheel conflicts at stage `env` belong here.
   - Serving/MLOps surface (`vllm`, `mlflow`, `wandb`, `dvc`, `bentoml`, `kserve`) → **subagent_type="ai-engineer:mlops-engineer"** (same prompt shape).
   - Ambiguous or multi-surface → **subagent_type="ai-engineer:ai-engineer"** (router) with the excerpt and the detected markers.

5. After the agent returns a fix, re-run from the failing phase (re-sync if the fix touched the manifest, otherwise re-import/re-test). Do NOT iterate silently — report each cycle.

## Tool Availability

Confirm the manager's binary before running it. If missing, print the hint, skip that manager, continue down the priority list, and note the skip.

| Missing tool | Install hint |
|--------------|--------------|
| `uv` | `curl -LsSf https://astral.sh/uv/install.sh \| sh` (verify against your toolchain) |
| `pip` | ships with CPython — `python3 -m ensurepip --upgrade` |
| `conda` | install Miniforge/Miniconda for your platform |
| `pytest` | `uv add --dev pytest`, or `pip install pytest` |

GPU-optional discipline applies: absent `nvidia-smi` is never a build failure. Tests requiring CUDA should be marker-skipped by the project; if they hard-fail on a CPU host, report that as a project defect, not a build failure.

Never hard-fail on a missing tool — skip and report.

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

### Path not found
```
Error: Path not found: {path}
Suggestion: Pass a directory that exists, e.g. /ai-engineer:build-test .
```

### No recognized Python project
```
Error: No Python environment detected under {path}.
Looked for: uv.lock, pyproject.toml, requirements*.txt, environment.yml, setup.py.
Suggestion: Run from the directory holding the manifest. If this is a pipeline or
eval-only repo, see the Other Surfaces note above.
```

### No tests found
Not an error. pytest exit code 5 means nothing was collected. Report "no tests found — sync and import succeeded" and treat the run as PASS for build, N/A for test. Suggest `/ai-engineer:eval-run` if the repo carries an eval harness instead of a unit suite.

### Manager forced but absent
```
Warning: --manager {name} requested but `{binary}` is not installed.
Falling back to detection order. Install hint: {hint}
```

### Every manager skipped
Only when *all* eligible managers are missing does the command report FAIL, with the aggregated install hints.

## See Also

- `skill: framework-detection` — canonical marker → domain → agent routing (read it; do not fork the table).
- `CORPFLOW.md` — how this command's log and verdict feed the DV Build Evidence block and the DR gate.
- `/ai-engineer:eval-run` — run the eval suites; this command deliberately does not.
- `/ai-engineer:review-code` — review once the build is green.
- `/ai-engineer:deploy-check` — serving readiness for a green build.
