---
description: Eval-driven prompt optimization — baseline on a pinned eval set, draft single-variable variants, measure and rank them; --apply ships the winner with a version bump. Use when a prompt underperforms or a prompt edit needs evidence.
argument-hint: [prompt path (default: discover prompts/)] [--variants N (default 3)] [--eval-set PATH] [--apply]
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
estimated-cost:
  min-tokens: 6000
  max-tokens: 30000
  model-distribution:
    sonnet: 85%
    opus: 15%
---

# Prompt Optimize
<!-- Updated: July 2026 -->

Optimize a production application prompt the only defensible way: measure a baseline on a pinned eval set, have the prompt engineer draft N single-variable variants, measure every variant under identical deterministic settings, and rank the results with the winning diff. Default is report-only; `--apply` writes the winner back as a proper version bump. No eval set means no optimization — the command offers to scaffold a golden set first and stops if that offer is declined.

[Extended thinking: A prompt edit is a behavior change to a probabilistic dependency — without a fixed measurement, "better" is an anecdote and regressions ship with confidence. This command pins one eval set for the entire run (baseline plus every variant), forces deterministic generation (temperature 0, fixed seeds, eval-set version recorded next to each metric), and restricts each variant to exactly one changed variable so the ranked table attributes every delta to its cause. The eval-set requirement is absolute: `ai-engineer:ai-test-generator` scaffolds a golden set from real examples when none exists, and a declined scaffold ends the run. Judge-scored metrics carry their judge prompt version and judge model, because a judge is a measurement instrument that itself drifts. Apply is the only mutation, it needs a measured winner, and it follows the prompt-design versioning rules — a new version file plus a CHANGELOG line, never a silent overwrite.]

## CRITICAL BEHAVIORAL RULES

You MUST follow these rules exactly. Violating any of them is a failure.

1. **No eval set, no optimization.** If no eval set exists (and `--eval-set` was not given), offer exactly one scaffold via `ai-engineer:ai-test-generator` — a golden set built from real examples. If the user declines, STOP with the error block. Never optimize on vibes.
2. **Never apply without eval evidence.** `--apply` runs only after the baseline AND every variant were measured on the same pinned eval set, and only for a variant that beats the baseline with no guard-metric regression. No winner → report honestly, apply nothing. `--apply` given without a measured winner is refused, not honored.
3. **One eval set, whole run, never reduced.** Pin the eval set (file + version) in Phase 2 and reuse it byte-identical for the baseline and every variant. Never drop, subset, or "temporarily skip" cases mid-run — a mid-run set change invalidates every number; restart the run instead.
4. **Deterministic settings are mandatory.** Temperature 0 (or the provider's deterministic equivalent) and fixed seeds on every measurement run; record the eval-set version next to every metric. If repeat baseline runs disagree, stop and fix the nondeterminism before comparing anything.
5. **Single-variable variants only.** Each variant changes exactly one variable (one anatomy segment, one example swap, one rule reframed). A variant that changes two things produces an unattributable delta — reject it and have it redrafted.
6. **Judge-based metrics name their judge.** Any judge-scored metric is reported with its judge prompt version and judge model pinned alongside the score (`skills/evals/llm-judge`). Scores from different judge versions are not comparable — never mix them in one ranking.
7. **Report-only leaves the repo untouched.** Variants live in scratch files (`.context/prompt-optimize/` or a temp dir); any temporary repoint used to measure a variant is reverted immediately after that run. Apply mode follows `skills/prompt-engineering/prompt-design` versioning: new version file + CHANGELOG line with the eval delta — never overwrite the live version in place.
8. **Never enter plan mode.** This command IS the procedure — execute it.

## Usage

```bash
# Optimize the discovered production prompt (report-only)
/ai-engineer:prompt-optimize

# Optimize a specific versioned prompt with 5 variants
/ai-engineer:prompt-optimize prompts/support-triage/system@4.md --variants 5

# Pin a specific eval set explicitly
/ai-engineer:prompt-optimize prompts/summarize/system@2.md --eval-set evals/summarize-v3.jsonl

# Measure, then apply the winner (version bump + CHANGELOG entry)
/ai-engineer:prompt-optimize prompts/support-triage/system@4.md --apply
```

## Options

| Option | Default | Effect |
|--------|---------|--------|
| `prompt path` | discover | Target prompt file. Precedence: explicit arg > `prompts/` discovery > ask the user. |
| `--variants N` | 3 | Number of single-variable variants drafted and measured. Each adds one full eval run — size N to the eval set's cost. |
| `--eval-set PATH` | discover | Pin a specific eval set / harness instead of discovering one. |
| `--apply` | off (report-only) | After ranking, write the winning variant to the prompt file as a version bump per `skills/prompt-engineering/prompt-design`. |

## Workflow

### Phase 1: Locate the Target Prompt

Resolve the target once, top-down — first applicable rule wins:

1. **Explicit arg** — the given file path.
2. **`prompts/` discovery** — glob `prompts/**/*.md` (versioned `name@N.md` layout per `skills/prompt-engineering/prompt-design`), then other common homes (`app/prompts/`, `src/**/prompts/`, `*.prompt.md`). A prompt that exists only as a string literal inside code is still a valid target — flag it as an unversioned-prompt finding and plan the apply path accordingly.
3. **Ask** — multiple plausible candidates or none: list what was found and ask the user to pick. Do not guess.

Read the target, note its current version (from `@N` filename, CHANGELOG, or "unversioned"), and print `target + version` before proceeding.

### Phase 2: Require the Eval Set (BINDING)

1. `--eval-set` given → use it. Otherwise discover: versioned `evals/*-v*.jsonl` sets, pytest eval harnesses (`tests/eval_*.py`), eval runner modules/configs. Record the eval-set file, its version, its case count, and the documented run command.
2. **If none exists**, offer the scaffold — **Use Task tool with subagent_type="ai-engineer:ai-test-generator"**
   Prompt: "Scaffold a golden eval set for the prompt at {path} ({feature summary}). Harvest 20-50 cases from REAL examples — production logs, test fixtures, docs examples — sanitized; do not invent the distribution. Cover typical cases, edge cases, and the escape hatch/refusal path. Ship as a versioned `evals/{feature}-v1.jsonl` plus a runnable deterministic harness (`uv run` entry point, temperature 0, fixed seed) per `skills/evals/eval-design`. Record provenance per case."
3. **If the user declines the scaffold → STOP** (Rule 1) with the "no eval set" error block. There is no measurement-free path through this command.

### Phase 3: Baseline Run (deterministic)

Run the harness against the current prompt exactly as documented — e.g. `uv run pytest tests/eval_support.py -q` or `uv run python -m app.evals --eval-set evals/support-v3.jsonl`. Deterministic settings per Rule 4. Capture every metric the harness reports (plus per-case results where available — failing cases feed the variant brief). When the harness is cheap, run the baseline twice and require identical metrics; on jitter, stop and fix determinism (temperature, seeds, sampling in any retrieval step) before continuing. Inside a worktask, tee the harness transcript to `.context/logs/` (`company-workflow:logging-conventions`).

### Phase 4: Draft Variants

**Use Task tool with subagent_type="ai-engineer:ai-prompt-engineer"**
Prompt: "Draft {N} optimization variants of the prompt at {path} (version {v}). Baseline: {metrics} on eval set {eval_set} v{ev} — worst-performing cases: {failing case ids/summaries}. Each variant must change exactly ONE variable, chosen from the `skills/prompt-engineering/prompt-design` levers (reorder/tighten one anatomy segment, swap or add one few-shot example, convert one negative rule to a positive contract, tighten the output contract, move one load-bearing rule to an edge). Name the changed variable and the hypothesis for each. Preserve the instruction hierarchy and untrusted-input delimiting exactly — injection posture is not a tuning knob. Return each variant as complete prompt text plus a one-line change description. Do NOT apply anything."

Materialize each variant as a scratch file under `.context/prompt-optimize/` (or a temp dir when no `.context/` exists). Reject and redraft any variant that changed more than one variable (Rule 5).

### Phase 5: Measure Every Variant

Run the identical harness once per variant — same pinned eval set, same deterministic settings, no set edits between runs (Rule 3). Point the harness at each variant via its documented mechanism (prompt-path flag, env var, or a temporary version repoint reverted immediately after the run — Rule 7). Collect per-variant metrics and, where the harness reports them, per-case flips (newly-fixed vs newly-broken cases).

### Phase 6: Rank and Report

1. Rank variants by the primary metric; a variant with any guard-metric regression beyond the harness's thresholds cannot win regardless of primary gain. Ties break toward the smaller diff.
2. Emit the Output Format report: baseline, ranked table, and the unified diff current → winner.
3. **No variant beats the baseline** → say so plainly, apply nothing, and recommend the next lever from the prompt-design escalation table (knowledge gap → RAG, behavior gap → fine-tuning; the call is `ai-engineer:ai-architector`'s).

### Optional: `--apply` (measured winner only)

- **Versioned layout** (`name@N.md`): Write the winner as `name@{N+1}.md`; append a `CHANGELOG.md` line — `{N+1} | {changed variable} | {metric delta} on {eval_set} v{ev}{, judge {jp} @ {jm} when judge-scored}`; repoint the loader/config reference from `N` to `N+1` (or list the repoint for the user when it is ambiguous). Leave `name@N.md` untouched — rollback is repointing.
- **Unversioned file or inline literal**: apply the minimal edit, add the version-bump note (create the sibling `CHANGELOG.md` if missing), and flag migration to the versioned `prompts/` layout as a follow-up finding.
- **Confirm**: re-run the harness once against the applied file and verify it reproduces the winning metrics — catches escaping/template drift introduced by the write.

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

### No prompt found / ambiguous target
```
Note: {No prompt files found | N candidate prompts found: {list}}.
Suggestion: Pass an explicit path, e.g. /ai-engineer:prompt-optimize prompts/<feature>/system@N.md
```

### No eval set and scaffold declined
```
Stopped: no eval set exists and the scaffold offer was declined.
This command never optimizes on vibes — an unmeasured prompt change is a
regression shipped with confidence. Re-run after building a golden set
(skills/evals/eval-design), or accept the ai-test-generator scaffold.
```

### Baseline harness fails
Report the failing command and its output location, then stop — a broken harness measures nothing. Do not proceed to variants against a partial baseline.

### Nondeterministic metrics
```
Stopped: repeat baseline runs disagree ({metric}: {v1} vs {v2}).
Fix determinism first: temperature 0, fixed seeds, no sampling in any
retrieval step, pinned eval-set version. Then re-run.
```

### No variant beats baseline
Not an error — report it plainly (Rule 2), apply nothing, and emit the Next Lever section. Manufacturing a "winner" from noise is a failure.

### `--apply` without a measured winner
Refuse with a one-line explanation and the report as-is. Rule 2 has no exceptions.

## See Also

- `skills/prompt-engineering/prompt-design` — anatomy, single-variable levers, and the versioned-files rules the apply step follows (`references/prompt-patterns.md` for the lever catalog).
- `skills/evals/eval-design` — golden-set construction, metric selection, paired comparison, statistical honesty.
- `skills/evals/llm-judge` — judge versioning and calibration behind Rule 6.
- `skills/evals/regression-gates` — wire the winning prompt's eval into CI so it cannot silently regress later.
- `ai-engineer:ai-prompt-engineer` / `ai-engineer:ai-test-generator` — variant drafting / eval-set scaffolding.
- `ai-engineer:ai-architector` — owns the prompt-vs-RAG-vs-fine-tune escalation when the measured ceiling is reached.
- `/ai-engineer:rag-audit` — when failures are knowledge gaps, audit retrieval instead of tuning the prompt around it.
