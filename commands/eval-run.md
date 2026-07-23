---
description: Discover and run the repo's LLM eval suites (pytest markers, promptfoo, deepeval, custom scripts), compare metrics vs baseline or thresholds, and report regressions with provenance. Use after prompt, model, or retrieval changes.
argument-hint: [suite name or eval path — default: all discovered suites] [--suite <name>] [--baseline <ref|file>] [--judge]
allowed-tools: Read, Glob, Grep, Bash
estimated-cost:
  min-tokens: 3000
  max-tokens: 15000
  model-distribution:
    sonnet: 90%
    haiku: 10%
---

# Eval Run
<!-- Updated: July 2026 -->

Discover the eval harnesses the repo actually has, run them (scoped or full) with deterministic settings via `uv run`, compare metrics against a baseline or the configured thresholds, and report a metrics table, a regression list, and full provenance (eval-set version, seeds, model revisions). The product is honest numbers — never fabricated, never compared against unpinned history.

[Extended thinking: Evals are the regression tests of LLM behavior, but eval harnesses are heterogeneous — pytest markers, promptfoo configs, deepeval suites, hand-rolled scripts — and a metric without its eval-set version and determinism config is anecdote, not evidence. This command discovers what exists rather than assuming, runs it with the pinned eval set and deterministic settings, and reports every number with the provenance a reviewer needs to trust a delta. Judge-scored suites cost provider tokens and are nondeterministic, so they stay opt-in behind `--judge`. When no harness exists, the honest output is "no harness" plus an offer to scaffold one via ai-test-generator — gated on user confirmation, because a harness is a commitment to maintain golden sets, not a checkbox.]

## CRITICAL BEHAVIORAL RULES

You MUST follow these rules exactly. Violating any of them is a failure.

1. **Never fabricate metrics.** Every reported number comes from a command executed this session, teed to `.context/logs/`. A suite that did not run is reported as "not run" — never estimated, interpolated, or copied from a previous report.
2. **Determinism first.** Run with the harness's pinned eval-set version and deterministic settings (temperature 0 / fixed seeds). If a suite is nondeterministic by construction (judge scoring, sampling), flag it and point to the flake policy in `skills/evals/regression-gates` — do not present a noisy delta as a regression verdict.
3. **Single-command Bash invocations.** `uv run pytest -m eval`, `uv run --project <path> python -m evals` — never `cd`-chains or `&&`-joined command lines; scoped Bash permissions do not match compound commands.
4. **Judge suites only with `--judge`.** Judge-based suites cost provider tokens per case and are nondeterministic; exclude them by default and, when included, state the cost basis in the report.
5. **No harness → offer, never impose.** When no harness is found, offer to scaffold one via `ai-engineer:ai-test-generator` — proceed ONLY on explicit user confirmation.
6. **Honest baseline semantics.** No baseline and no configured thresholds → metrics are reported as a baseline candidate, NOT as "pass". A missing baseline is not a green gate.
7. **Tool-missing never hard-fails.** Runner binary absent → print the install hint, skip that harness, run the others, and report the skip.
8. **Never enter plan mode.** This command IS the procedure — execute it.

## Usage

```bash
# Discover and run all non-judge eval suites, compare vs configured thresholds
/ai-engineer:eval-run

# Run one suite by name
/ai-engineer:eval-run --suite retrieval

# Compare against the baseline artifact committed at a git ref
/ai-engineer:eval-run --baseline main

# Compare against a metrics artifact file
/ai-engineer:eval-run --baseline evals/baselines/2026-07-01.json

# Include judge-based suites (provider-token cost; nondeterministic)
/ai-engineer:eval-run --judge
```

## Options

| Option | Default | Effect |
|--------|---------|--------|
| `suite/path` | all discovered | Positional: a suite name or eval directory/file to run instead of everything discovered. |
| `--suite <name>` | all | Run only the named suite (matches the discovery table's suite names/markers). |
| `--baseline <ref\|file>` | configured thresholds | Compare against a stored metrics artifact: a git ref (read the committed baseline file at that ref) or a metrics file path. Absent → fall back to thresholds configured in the harness/gate config; absent too → baseline-candidate mode (Rule 6). |
| `--judge` | off | Include judge-based suites. Report their per-case cost basis and mark their metrics judge-scored (nondeterministic — flake policy applies). |

## Harness Discovery

Scan top-down and record **every** harness found — a repo can have several. Keep this table in sync with the eval-harness row of `skills/_shared/framework-detection.md`; do not fork it.

| Signal (priority order) | Harness | Run command |
|-------------------------|---------|-------------|
| pytest eval markers (`eval`/`evals` in `[tool.pytest.ini_options] markers`) or `tests/evals/`, `evals/test_*.py` | pytest evals | `uv run pytest -m eval -q` or `uv run pytest evals/ -q` |
| `evals/` dir with a runner (`evals/run.py`, `evals/__main__.py`) | custom Python harness | `uv run python -m evals` (or the runner script) |
| `promptfooconfig.yaml` / `promptfoo.config.*` | promptfoo | `promptfoo eval -c <config> -o <out>.json` |
| deepeval markers (`.deepeval/`, `deepeval` in deps) | deepeval | `uv run deepeval test run <path>` (pytest-backed) |
| Makefile/justfile eval targets, `scripts/eval*.py` | custom script | the declared target/script, via its own runner |

For each discovered suite record: name, harness type, run command, eval-set path + version (version field or content hash), determinism config (temperature/seed), and whether it is judge-based or programmatic. The positional arg / `--suite` filters this list.

## Workflow

### Phase 1: Discover (Glob + Read)

1. Run the discovery scan; print the discovered-suite table (name, harness, judge?, eval-set version).
2. Apply the `--suite`/positional filter. Empty after filtering → Error Handling "suite not found".
3. Nothing discovered at all → Error Handling "no harness found" (scaffold offer, Rule 5).
4. Probe each selected harness's runner (`command -v promptfoo`, `uv run pytest --version`, …). Missing → install hint + skip that harness (Rule 7).
5. Judge-based suites excluded by a missing `--judge` are listed as skipped, with their cost note.

### Phase 2: Resolve Baseline

1. `--baseline <file>` → Read the metrics artifact (JSON/CSV) directly.
2. `--baseline <ref>` → `git show <ref>:<baseline-path>` for the committed baseline artifact (path from the gate config, else the harness's conventional output location).
3. Neither → use configured thresholds: promptfoo assertions, the pytest gate/thresholds config per `skills/evals/regression-gates`.
4. None of the above → **baseline-candidate mode**: run and report metrics with provenance, and state explicitly that there is nothing to compare against (Rule 6).

For each gated metric record its direction (higher-better vs lower-better), absolute floor/ceiling, relative threshold, and warn band — from the gate config where present, defaults per `skills/evals/regression-gates`.

### Phase 3: Run (Bash)

1. Run each selected suite as a **single command**, teeing to the log:
   ```bash
   uv run pytest -m eval -q 2>&1 | tee -a .context/logs/eval-run-<timestamp>.log
   ```
   Capture `${PIPESTATUS[0]}` per run.
2. A harness crash (nonzero exit with no metrics output) is an **infrastructure failure** — report that suite as ERROR, not as a regression and not as a pass; the other suites still run.
3. Parse metrics from the harness's native output (pytest metrics artifact, promptfoo JSON, deepeval results). Record the eval-set version, temperature/seeds, and model revisions **actually used** — read from run output/config, never assumed.
4. With `--judge`: run judge suites after the programmatic ones; record the judge model + rubric version and the per-case cost basis (calls × cases).

### Phase 4: Compare & Report

1. Build the metrics-vs-baseline table: metric, direction, baseline, current, delta, threshold, verdict (PASS / WARN / REGRESSION / NEW).
2. REGRESSION = beyond the relative threshold or past the absolute floor/ceiling; WARN band is reported but non-blocking (`skills/evals/regression-gates`).
3. Emit the Output Format report with the provenance block. Judge-scored metrics carry a `judge-scored` marker and the flake-policy pointer (Rule 2).

### No harness found: scaffold offer (confirmation-gated)

Ask: "No eval harness found. Scaffold a minimal one (pytest eval marker + pinned golden-set skeleton + baseline artifact + threshold config) via `ai-engineer:ai-test-generator`?" Proceed ONLY on explicit user confirmation, then:

**Use Task tool with subagent_type="ai-engineer:ai-test-generator"**
Prompt: "Scaffold a minimal LLM eval harness for {capability/paths}: a versioned golden-set skeleton (JSONL with a version field), pytest wiring under an `eval` marker, deterministic settings (temperature 0, fixed seed), a metrics artifact the run writes, and a threshold/baseline config per `skills/evals/regression-gates`. Seed cases from {source}; mark TODO where human labels are required — do NOT fabricate golden answers. Return the file list and the exact run command."

Then re-run discovery and execute the new suite once to prove it runs; its first metrics are reported as the baseline candidate.

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

Overall verdict line: **PASS** (gate holds) / **REGRESSION** (with the list) / **ERROR** (harness failure) / **BASELINE CANDIDATE**.

## Error Handling

### No harness found
```
Note: No eval harness discovered — pytest eval markers, evals/ runner, promptfoo config,
deepeval, and custom eval scripts are all absent.
Offer: scaffold a minimal harness via ai-engineer:ai-test-generator?
(Requires your explicit confirmation — a harness implies maintained golden sets.)
```

### Suite not found
```
Error: No discovered suite matches "{name}".
Discovered: {suite names}. Pass one of these to --suite, or omit it to run all.
```

### Baseline unreadable
`--baseline` names a ref/file with no parseable metrics artifact → fall back to baseline-candidate mode and say so explicitly. Never reconstruct or guess the old numbers (Rule 1).

### Runner missing (reduced scope)
| Missing tool | Install hint |
|--------------|--------------|
| `promptfoo` | `npm install -g promptfoo` (verify the current install method against promptfoo docs) |
| `deepeval` | `uv add --dev deepeval` |
| `pytest` | `uv add --dev pytest` |

Skip the affected harness, run the rest, report the skip — never hard-fail the whole run.

### Harness crash
Report that suite as ERROR with a log excerpt; keep running the other suites. The overall verdict is ERROR — a crashed harness is neither PASS nor REGRESSION.

### Nondeterministic suite without pinned settings
Flag the suite: its results are not gate-grade. Point to the flake policy in `skills/evals/regression-gates` (repeat-run medians, cached judge verdicts, warn-only mode) instead of issuing a hard verdict from noisy numbers.

## See Also

- `skills/evals/regression-gates` — thresholds, warn bands, baseline update ritual, flake policy, escape hatch.
- `skills/evals/eval-design` — designing the eval set and metrics this command runs.
- `skills/evals/llm-judge` — judge rubrics and calibration behind `--judge` suites.
- `skills/_shared/framework-detection.md` — the shared eval-harness markers this discovery table syncs with.
- `/ai-engineer:code-review` — expects this command's output as eval evidence for prompt/model/retrieval changes.
- `ai-engineer:ai-test-generator` — builds or extends harnesses beyond the minimal scaffold.

If the numbers are bad, report them bad — a red eval that reaches the developer is this command working, not failing.
