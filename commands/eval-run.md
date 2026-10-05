---
description: Discover and run the repo's LLM eval suites (pytest markers, promptfoo, deepeval, custom scripts), compare metrics vs baseline or thresholds, and report regressions with provenance. Use after prompt, model, or retrieval changes.
argument-hint: [suite name or eval path — default: all discovered suites] [--suite <name>] [--baseline <ref|file>] [--judge]
allowed-tools: Read, Agent, Glob, Grep, Bash
---

# Eval Run

Discover the eval harnesses the repo actually has, run them with the pinned eval set and deterministic settings via `uv run`, compare metrics against a baseline or the configured thresholds, and report a metrics table, a regression list, and provenance (eval-set version, seeds, model revisions). A metric without its eval-set version and determinism config can't support a delta, so provenance is part of every number.

## CRITICAL BEHAVIORAL RULES

1. **Report only measured metrics.** Every number comes from a command run this session and teed to `.context/logs/`. A suite that didn't run is "not run" — not estimated or copied from an earlier report.
2. **Determinism first.** Run with the harness's pinned eval-set version and temperature 0 / fixed seeds. A suite that is nondeterministic by construction (judge scoring, sampling) is flagged with a pointer to the flake policy in `ai-engineer:regression-gates`; its noisy delta isn't a regression verdict.
3. **Single-command Bash invocations** (`uv run pytest -m eval`, `uv run --project <path> python -m evals`), no `cd`-chains or `&&`, because scoped Bash permissions don't match compound commands.
4. **Judge suites only with `--judge`.** They cost provider tokens per case and are nondeterministic; when included, state the cost basis in the report.
5. **No harness → offer, don't impose.** Offer to scaffold one via `ai-engineer:ai-test-generator` and proceed only on explicit user confirmation — a harness commits the team to maintaining golden sets.
6. **No baseline is not a pass.** Without a baseline or configured thresholds, metrics are reported as a baseline candidate.
7. **A missing runner skips one harness, not the run.** Print the install hint, run the others, report the skip.
8. Execute directly; don't enter plan mode.

## Usage

```bash
/ai-engineer:eval-run                                          # all non-judge suites vs configured thresholds
/ai-engineer:eval-run --suite retrieval
/ai-engineer:eval-run --baseline main                          # baseline artifact committed at a git ref
/ai-engineer:eval-run --baseline evals/baselines/2026-07-01.json
/ai-engineer:eval-run --judge                                  # include judge-based suites
```

## Options

| Option | Default | Effect |
|--------|---------|--------|
| `suite/path` | all discovered | Positional: a suite name or eval directory/file to run instead of everything discovered. |
| `--suite <name>` | all | Run only the named suite (matches the discovery table's suite names/markers). |
| `--baseline <ref\|file>` | configured thresholds | Compare against a stored metrics artifact: a git ref (the committed baseline file at that ref) or a metrics file path. Absent → thresholds from the harness/gate config; absent too → baseline-candidate mode (Rule 6). |
| `--judge` | off | Include judge-based suites, report their per-case cost basis, and mark their metrics judge-scored. |

## Harness Discovery

Record every harness found — a repo can have several. The markers mirror the eval-harness row of `${CLAUDE_PLUGIN_ROOT}/skills/_shared/framework-detection.md`.

| Signal (priority order) | Harness | Run command |
|-------------------------|---------|-------------|
| pytest eval markers (`eval`/`evals` in `[tool.pytest.ini_options] markers`) or `tests/evals/`, `evals/test_*.py` | pytest evals | `uv run pytest -m eval -q` or `uv run pytest evals/ -q` |
| `evals/` dir with a runner (`evals/run.py`, `evals/__main__.py`) | custom Python harness | `uv run python -m evals` (or the runner script) |
| `promptfooconfig.yaml` / `promptfoo.config.*` | promptfoo | `promptfoo eval -c <config> -o <out>.json` |
| deepeval markers (`.deepeval/`, `deepeval` in deps) | deepeval | `uv run deepeval test run <path>` (pytest-backed) |
| Makefile/justfile eval targets, `scripts/eval*.py` | custom script | the declared target/script, via its own runner |

Per suite record: name, harness type, run command, eval-set path + version (version field or content hash), determinism config (temperature/seed), and judge-based vs programmatic.

## Workflow

### Phase 1: Discover

1. Run the discovery scan and print the suite table (name, harness, judge?, eval-set version).
2. Apply the `--suite`/positional filter. Nothing discovered → scaffold offer (below); nothing left after filtering → "suite not found".
3. Probe each selected runner (`command -v promptfoo`, `uv run pytest --version`, …); missing → Rule 7.
4. List judge suites excluded for lack of `--judge` as skipped, with their cost note.

### Phase 2: Resolve Baseline

First match wins:

1. `--baseline <file>` → read the metrics artifact (JSON/CSV).
2. `--baseline <ref>` → `git show <ref>:<baseline-path>` (path from the gate config, else the harness's conventional output location).
3. Configured thresholds: promptfoo assertions, or the pytest gate config per `ai-engineer:regression-gates`.
4. Baseline-candidate mode: report metrics with provenance and state there is nothing to compare against.

For each gated metric record direction (higher- or lower-better), absolute floor/ceiling, relative threshold, and warn band — from the gate config, else the `regression-gates` defaults.

### Phase 3: Run

1. `mkdir -p .context/logs` first — `tee` won't create it.
2. Run each selected suite as one command, teed to the log:
   ```bash
   uv run pytest -m eval -q 2>&1 | tee -a .context/logs/eval-run-<timestamp>.log
   ```
   Judge the outcome by the suite's exit status, not tee's.
3. A nonzero exit with no metrics output is an infrastructure failure: report that suite as ERROR (neither regression nor pass) and keep running the others.
4. Parse metrics from the harness's native output (pytest metrics artifact, promptfoo JSON, deepeval results). Take the eval-set version, temperature/seeds, and model revisions from the run output/config, not from assumptions.
5. With `--judge`, run judge suites after the programmatic ones; record judge model + rubric version and the per-case cost basis (calls × cases).

### Phase 4: Compare & Report

1. Build the metrics table with a verdict per metric: PASS / WARN / REGRESSION / NEW. REGRESSION = beyond the relative threshold or past the absolute floor/ceiling; WARN band is reported but non-blocking.
2. Emit the Output Format report. Judge-scored metrics carry a `judge-scored` marker and the flake-policy pointer.

### No harness found: scaffold offer

Ask: "No eval harness found. Scaffold a minimal one (pytest eval marker + pinned golden-set skeleton + baseline artifact + threshold config) via `ai-engineer:ai-test-generator`?" On explicit confirmation, use the Agent tool with `subagent_type="ai-engineer:ai-test-generator"`. Prompt:

"Scaffold a minimal LLM eval harness for {capability/paths}: a versioned golden-set skeleton (JSONL with a version field), pytest wiring under an `eval` marker, deterministic settings (temperature 0, fixed seed), a metrics artifact the run writes, and a threshold/baseline config per `ai-engineer:regression-gates`. Seed cases from {source}; mark TODO where human labels are required — don't fabricate golden answers. Return the file list and the exact run command."

Then re-run discovery and run the new suite once; its first metrics are the baseline candidate.

## Output Format

```markdown
## Eval Run Report

**Suites run:** {n} of {m} discovered ({names})
**Mode:** {vs baseline {ref|file} | vs configured thresholds | BASELINE CANDIDATE — nothing to compare against}
**Log:** .context/logs/eval-run-{timestamp}.log

### Metrics vs Baseline
| Suite | Metric | Dir | Baseline | Current | Δ | Threshold | Verdict |
|-------|--------|-----|----------|---------|---|-----------|---------|
| retrieval | recall@10 | ↑ | 0.81 | 0.84 | +0.03 | ≥ −0.02 rel | PASS |
| qa | faithfulness | ↑ | 0.92 | 0.88 | −0.04 | ≥ −0.02 rel | REGRESSION (judge-scored — see flake policy) |

### Regressions ({n})
- {suite}/{metric}: {baseline} → {current} ({delta} vs threshold {t}) — {likely cause if evident from the diff, else "cause not established"}

### Provenance
- Eval set: {name}@{version/hash} (pinned)
- Determinism: temperature {t}, seed {s}; judge suites: {judge model}@{revision}, rubric {version} | none run
- Model(s) under eval: {model id}@{revision}
- Commands: {exact commands run}

### Skipped
- {suite}: {judge-based — excluded without --judge (≈{n} judge calls/run) | runner missing — install hint above}
```

Overall verdict line: **PASS** (gate holds) / **REGRESSION** (with the list) / **ERROR** (harness failure) / **BASELINE CANDIDATE**. Report bad numbers as bad.

## Error Handling

| Condition | Response |
|-----------|----------|
| No harness found | `Note: No eval harness discovered — pytest eval markers, evals/ runner, promptfoo config, deepeval, and custom eval scripts are all absent.` Then the scaffold offer (Rule 5). |
| Suite not found | `Error: No discovered suite matches "{name}". Discovered: {suite names}. Pass one of these to --suite, or omit it to run all.` |
| Baseline unreadable | `--baseline` names a ref/file with no parseable metrics artifact → baseline-candidate mode, stated explicitly. Don't reconstruct the old numbers. |
| Runner missing | Skip that harness, run the rest, report the skip. Hints: `promptfoo` → `npm install -g promptfoo` (check promptfoo docs for the current method); `deepeval` → `uv add --dev deepeval`; `pytest` → `uv add --dev pytest`. |
| Harness crash | That suite is ERROR with a log excerpt; the others still run; overall verdict ERROR. |
| Nondeterministic suite without pinned settings | Flag it as not gate-grade and point to the `regression-gates` flake policy (repeat-run medians, cached judge verdicts, warn-only mode) instead of issuing a hard verdict. |

## See Also

- `ai-engineer:regression-gates` — thresholds, warn bands, baseline update ritual, flake policy, escape hatch.
- `ai-engineer:eval-design` — designing the eval set and metrics this command runs.
- `ai-engineer:llm-judge` — judge rubrics and calibration behind `--judge` suites.
- `/ai-engineer:review-code` — expects this command's output as eval evidence for prompt/model/retrieval changes.
