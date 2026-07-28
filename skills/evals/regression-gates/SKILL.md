---
name: regression-gates
description: >-
  Wire evals into CI so prompt/model/retrieval quality cannot silently regress:
  the pre-commit→PR→nightly→release gate ladder, absolute floors plus
  relative-to-baseline thresholds with warn bands, the baseline update ritual,
  determinism and flake policy for judge metrics, cost-bounded subsets, pytest
  integration with metrics artifacts, and the recorded escape hatch. Use when
  adding eval gates to CI, choosing thresholds, a gate is flaky, a baseline
  needs updating after an accepted improvement, someone wants to merge past a
  red eval — or when prompt changes are shipping with "tested manually".
---

# Regression Gates

**If quality can regress without a red build, it will**

## Overview

A regression gate turns an eval suite into an enforced contract: eval run +
stored baseline + thresholds + failure policy. This is the mechanism behind the
plugin's core rule — *every prompt, model, or retrieval change ships with an
eval run vs. baseline* — and behind the AI QA verdict, which passes only when
**tests pass AND the eval regression gate holds**
(`skills/_shared/workflow-integration/references/stage-details.md § QA Gate for AI Work`). Trained-model
promotion applies the same pattern at the pipeline level
(`skills/mlops/ml-pipelines`). Gate harnesses are built by
`ai-engineer:ai-test-generator`.

## When to Use

- Adding eval gates to CI for an LLM feature that has an eval set
- Choosing thresholds, warn bands, and which tier each metric runs in
- A gate is flaky, slow, expensive — or routinely bypassed
- Updating the baseline after an accepted improvement
- Reviewing a PR that wants to merge past a red eval
- Deciding which eval subset runs at PR time vs. nightly

**When NOT to use:**

- Designing the eval set and metrics themselves → `skills/evals/eval-design`
- Judge rubrics, biases, calibration → `skills/evals/llm-judge`
- Training-pipeline model promotion and rollout mechanics → `skills/mlops/ml-pipelines`
- pytest/fixture depth with no eval surface → `system-developer:python-skills`

## Gate Placement Ladder

Each rung trades latency and cost for depth. A gate developers wait on gets
bypassed; a gate that never runs catches nothing — place each check at the
cheapest rung that can catch its failure class.

```
rung          runs                        latency   verdict scope
──────────────────────────────────────────────────────────────────────────
pre-commit    tier-1 assertions only      seconds   advisory (hook)
              (schema, format, no-PII)
PR            smoke subset: stratified    minutes   REQUIRED to merge
              sample, deterministic,
              programmatic metrics
merge/nightly full suite + judge dims     ~hours    blocks promotion,
              (cached verdicts)                     alerts owner
pre-release   full suite + judges +       days      release go/no-go
              human spot-check panel                (+ escape hatch only)
──────────────────────────────────────────────────────────────────────────
```

Judge-scored metrics enter at merge/nightly (cost, nondeterminism); the PR rung
stays programmatic and deterministic so a red PR gate is always trustworthy.
Human review appears only at release — per the eval hierarchy in
`skills/evals/eval-design`.

## Implementation Deep Dive

Read `references/gate-implementation.md` for threshold design, baseline management and the update ritual, determinism and flake policy, cost engineering, pytest integration, and the recorded escape hatch.

## Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| Comparing to "last run" instead of accepted baseline | Quality ratchets down one in-tolerance step at a time | Baseline = last accepted main artifact; explicit update ritual |
| Threshold edited to make CI green | Institutionalized silent regression | Escape hatch with recorded rationale; threshold changes reviewed separately |
| Full judge suite on every PR | Slow + expensive → developers route around the gate | Ladder: deterministic smoke at PR, judges at nightly with caching |
| "Re-run until green" | Gate loses authority; real regressions ride the flake | Flake budget, cached/voted verdicts, quarantine with expiry |
| Baseline auto-updates on merge | Regressions that slip through become the new normal | Reviewed baseline diff with old→new numbers |
| Metrics-only failure output | "F1 dropped 0.03" is unactionable | Artifact links transcripts; failure analysis per `skills/evals/eval-design` |
| Comparing across eval-set versions | Different denominators — delta is meaningless | Re-baseline on version bump; one side-by-side run |
| Eval job present but `allow_failure` | Theater: the gate observes but never gates | PR rung is a required check; nightly failures page an owner |
| Smoke-subset value vs. full-set baseline | Subset bias masquerades as a regression (or hides one) | Record subset identity in the artifact; compare like with like |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "The eval is flaky, just re-run it" | Flakiness is a determinism bug with named fixes — caching, voting, quarantine-with-expiry. Re-running until green trains the team to ignore red |
| "It's a tiny prompt tweak, skip the eval" | Tiny prompt tweaks are precisely what the gate exists for — they look safe and change behavior. The smoke subset costs minutes |
| "We'll set thresholds after we've collected more data" | That's a gate that cannot fail. Set provisional floors from the first baseline run today; tighten with data |
| "Judges are too expensive for CI" | Judges don't belong at the PR rung anyway. Nightly + caching + subset selection makes them affordable where they run |
| "I'm sure this drop is noise" | The noise floor is measured, not felt (`skills/evals/eval-design`). If it's noise, the warn band absorbs it; if you're overriding, record it |
| "We're blocked, override now and document later" | "Later" is never. The override record is five lines and merges with the PR — that's the price of keeping the gate meaningful |

## Red Flags

- CI is green while a metric sits below its documented floor — the gate isn't wired
- Baseline file untouched for months while prompts changed weekly
- `gates.yaml` edited in the same PR that first failed it
- Quarantine list growing, no expiries, no linked issues
- Eval job marked optional / `allow_failure` / not a required check
- Overrides happen in chat with no record in the repo
- Nobody can say which eval-set version the current baseline used
- Judge metrics gate PRs directly with no cache and no vote

## Verification

- [ ] Gate ladder placed: assertions pre-commit, deterministic smoke subset required at PR, full suite + judges nightly, human spot-check at release
- [ ] Every gated metric has direction, absolute floor/ceiling, relative delta, and warn band in a reviewed `gates.yaml`
- [ ] Baseline = last accepted main run; updates are reviewed diffs carrying eval-set version + run config
- [ ] Metrics artifact written every run (eval-set version, run config, judge identity, subset, transcript paths) and machine-comparable via `--baseline`
- [ ] Determinism: temp 0/seeds, pinned models and eval-set version; judge verdicts cached and/or majority-voted in the warn band
- [ ] Flake rate tracked against a budget; quarantined examples have owner, issue, expiry
- [ ] PR subset is stratified and deterministic; full-set cadence documented; subset identity recorded with metrics
- [ ] Gate failures link transcripts for failure analysis (`skills/evals/eval-design`)
- [ ] Escape hatch: overrides recorded in-repo (who/why/expiry + follow-up issue); QA verdict semantics per `skills/_shared/workflow-integration`
- [ ] Trained-model promotion gates aligned with `skills/mlops/ml-pipelines`
