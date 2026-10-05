---
description: Eval-driven prompt optimization — baseline on a pinned eval set, draft single-variable variants, measure and rank them; --apply ships the winner with a version bump. Use when a prompt underperforms or a prompt edit needs evidence.
argument-hint: [prompt path (default: discover prompts/)] [--variants N (default 3)] [--eval-set PATH] [--apply]
allowed-tools: Read, Agent, Write, Edit, Glob, Grep, Bash
---

# Prompt Optimize

Optimize a production application prompt by measurement: baseline it on a pinned eval set, have the prompt engineer draft N single-variable variants, measure each under identical deterministic settings, and rank them with the winning diff. Default is report-only; `--apply` writes the winner back as a version bump. A prompt edit is a behavior change to a probabilistic dependency, so without a fixed measurement "better" is an anecdote.

## CRITICAL BEHAVIORAL RULES

1. **No eval set, no optimization.** If none exists and `--eval-set` wasn't given, offer one scaffold via `ai-engineer:ai-test-generator`. If the user declines, stop with the "no eval set" error.
2. **Apply only a measured winner.** `--apply` runs only after the baseline and every variant were measured on the same pinned eval set, and only for a variant that beats the baseline with no guard-metric regression. Otherwise apply nothing and say so.
3. **One eval set for the whole run.** Pin the eval set (file + version) in Phase 2 and reuse it unchanged for the baseline and every variant. Don't drop or subset cases mid-run — that invalidates every number; restart instead.
4. **Deterministic settings.** Temperature 0 (or the provider's deterministic equivalent) and fixed seeds on every run; record the eval-set version next to every metric. If repeat baseline runs disagree, fix the nondeterminism before comparing anything.
5. **Single-variable variants.** Each variant changes one variable (one anatomy segment, one example, one rule reframed), so every delta is attributable. Redraft any variant that changes two.
6. **Judge-scored metrics name their judge.** Report the judge prompt version and judge model next to each judge score (`ai-engineer:llm-judge`); scores from different judge versions don't go in one ranking.
7. **Report-only leaves the repo untouched.** Variants live in scratch files (`.context/prompt-optimize/` or a temp dir); revert any temporary repoint right after its run. Apply follows `ai-engineer:prompt-design` versioning: new version file + CHANGELOG line with the eval delta, never an in-place overwrite.
8. Execute directly; don't enter plan mode.

## Usage

```bash
/ai-engineer:prompt-optimize                                                      # discovered prompt, report-only
/ai-engineer:prompt-optimize prompts/support-triage/system@4.md --variants 5
/ai-engineer:prompt-optimize prompts/summarize/system@2.md --eval-set evals/summarize-v3.jsonl
/ai-engineer:prompt-optimize prompts/support-triage/system@4.md --apply             # version bump + CHANGELOG
```

## Options

| Option | Default | Effect |
|--------|---------|--------|
| `prompt path` | discover | Target prompt file. Precedence: explicit arg > `prompts/` discovery > ask the user. |
| `--variants N` | 3 | Variants drafted and measured. Each adds one full eval run — size N to the eval set's cost. |
| `--eval-set PATH` | discover | Pin a specific eval set / harness instead of discovering one. |
| `--apply` | off (report-only) | After ranking, write the winner as a version bump per `ai-engineer:prompt-design`. |

## Workflow

### Phase 1: Locate the Target Prompt

First applicable rule wins:

1. **Explicit arg** — the given path.
2. **Discovery** — `prompts/**/*.md` (versioned `name@N.md` layout), then `app/prompts/`, `src/**/prompts/`, `*.prompt.md`. A prompt that exists only as a string literal in code is still a valid target; flag it as unversioned.
3. **Ask** — several plausible candidates or none: list them and ask the user to pick.

Note the current version (`@N` filename, CHANGELOG, or "unversioned") and print `target + version`.

### Phase 2: Require the Eval Set

1. `--eval-set` given → use it. Otherwise discover versioned `evals/*-v*.jsonl` sets, pytest eval harnesses (`tests/eval_*.py`), and eval runner modules/configs. Record the file, version, case count, and run command.
2. **None exists** → offer the scaffold via the Agent tool, `subagent_type="ai-engineer:ai-test-generator"`:
   "Scaffold a golden eval set for the prompt at {path} ({feature summary}). Harvest 20-50 cases from real examples — production logs, test fixtures, docs examples — sanitized; don't invent the distribution. Cover typical cases, edge cases, and the refusal/escape-hatch path. Ship as a versioned `evals/{feature}-v1.jsonl` plus a runnable deterministic harness (`uv run` entry point, temperature 0, fixed seed) per `ai-engineer:eval-design`. Record provenance per case."
3. **Scaffold declined** → stop (Rule 1).

### Phase 3: Baseline Run

Run the harness against the current prompt as documented (e.g. `uv run pytest tests/eval_support.py -q`), with Rule 4 settings, teeing the transcript to `.context/logs/`. Capture every metric plus per-case results where available — failing cases feed the variant brief. When the harness is cheap, run the baseline twice and require identical metrics; on jitter, fix determinism (temperature, seeds, sampling in any retrieval step) first.

### Phase 4: Draft Variants

Agent tool, `subagent_type="ai-engineer:ai-prompt-engineer"`:
"Draft {N} optimization variants of the prompt at {path} (version {v}). Baseline: {metrics} on eval set {eval_set} v{ev}; worst cases: {failing case ids/summaries}. Each variant changes exactly one variable from the `ai-engineer:prompt-design` levers (tighten or reorder one anatomy segment, swap or add one few-shot example, convert one negative rule to a positive contract, tighten the output contract, move one load-bearing rule to an edge). Name the changed variable and the hypothesis for each. Keep the instruction hierarchy and untrusted-input delimiting exactly as they are — injection posture is not a tuning knob. Return each variant as complete prompt text plus a one-line change description. Don't apply anything."

Write each variant to a scratch file (Rule 7) and redraft any that changed more than one variable.

### Phase 5: Measure Every Variant

Run the same harness once per variant, pointed at it via the harness's documented mechanism (prompt-path flag, env var, or a temporary repoint reverted right after). Collect per-variant metrics and, where reported, per-case flips (newly fixed vs newly broken).

### Phase 6: Rank and Report

1. Rank by the primary metric. A variant with a guard-metric regression beyond the harness thresholds can't win. Ties go to the smaller diff.
2. Emit the Output Format report.
3. **No variant beats the baseline** → say so, apply nothing, and recommend the next lever from prompt-design's escalation table (knowledge gap → RAG, behavior gap → fine-tuning); that call belongs to `ai-engineer:ai-architector`.

### `--apply` (measured winner only)

- **Versioned layout** (`name@N.md`): write `name@{N+1}.md`; append to `CHANGELOG.md` — `{N+1} | {changed variable} | {metric delta} on {eval_set} v{ev}{, judge {jp} @ {jm} when judge-scored}`; repoint the loader/config from `N` to `N+1` (or list the repoint for the user when ambiguous). Leave `name@N.md` in place so rollback is a repoint.
- **Unversioned file or inline literal**: apply the minimal edit, add the version note (create a sibling `CHANGELOG.md` if missing), and flag migration to the versioned `prompts/` layout as a follow-up.
- **Confirm**: re-run the harness once on the applied file and check it reproduces the winning metrics, which catches escaping or template drift from the write.

## Output Format

```markdown
## Prompt Optimization Report

**Prompt:** {path} (version {v})
**Eval set:** {evals/<name>-vN.jsonl} ({M} cases, pinned)
**Settings:** temperature 0, seed {s}; judge: {judge prompt v{X} @ {judge model} | none — code-checked metrics}
**Mode:** {report-only | --apply}

### Baseline
| Metric | Value |
|--------|-------|
| {metric} | {value} |

### Ranked Variants
| Rank | Variant | Changed variable | {primary metric} | Δ vs baseline | Guard regressions | Verdict |
|------|---------|------------------|------------------|---------------|-------------------|---------|
| 1 | v2 | {one-line change} | {value} | {+Δ} | none | WINNER |
| 2 | v1 | {one-line change} | {value} | {+Δ} | {metric −Δ} | rejected (guard) |

### Winning Diff
{unified diff, fenced as a `diff` block: current prompt → winner}

### Applied
{--apply: wrote {name@N+1.md}, CHANGELOG line added, loader repointed, confirm-run reproduced winner | not applied (report-only) | no winner — nothing applied}

### Next Lever
{only when the measured ceiling is reached: escalation per prompt-design § When to Stop Prompt-Engineering, routed to ai-engineer:ai-architector}
```

## Error Handling

| Condition | Response |
|-----------|----------|
| No prompt found / ambiguous target | `Note: {No prompt files found \| N candidate prompts found: {list}}.` + `Suggestion: Pass an explicit path, e.g. /ai-engineer:prompt-optimize prompts/<feature>/system@N.md` |
| No eval set, scaffold declined | `Stopped: no eval set exists and the scaffold offer was declined. Re-run after building a golden set (ai-engineer:eval-design), or accept the ai-test-generator scaffold.` |
| Baseline harness fails | Report the failing command and its log location, then stop; don't draft variants against a partial baseline. |
| Nondeterministic metrics | `Stopped: repeat baseline runs disagree ({metric}: {v1} vs {v2}). Fix determinism first: temperature 0, fixed seeds, no sampling in any retrieval step, pinned eval-set version. Then re-run.` |
| No variant beats baseline | Not an error: report it, apply nothing, emit Next Lever. |
| `--apply` without a measured winner | Refuse in one line and return the report as-is (Rule 2). |

## See Also

- `ai-engineer:prompt-design` — anatomy, levers (`references/prompt-patterns.md`), and the versioning rules apply follows.
- `ai-engineer:eval-design` — golden-set construction, metric selection, paired comparison.
- `ai-engineer:regression-gates` — wire the winner's eval into CI so it can't silently regress.
- `/ai-engineer:rag-audit` — when failures are knowledge gaps, audit retrieval instead of tuning the prompt around it.
