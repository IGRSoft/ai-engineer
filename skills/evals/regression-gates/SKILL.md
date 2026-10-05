---
name: regression-gates
description: >-
  Wire evals into CI so prompt, model, and retrieval quality can't silently
  regress: the pre-commit→PR→nightly→release gate ladder, absolute floors plus
  relative-to-baseline thresholds with warn bands, the baseline update ritual,
  flake policy for judge metrics, cost-bounded subsets, pytest integration, and
  the recorded escape hatch. Use when adding eval gates, choosing thresholds,
  fixing a flaky gate, updating a baseline, or reviewing a merge past a red eval.
---

# Regression Gates

A regression gate turns an eval suite into an enforced contract: eval run + stored baseline + thresholds + failure policy. It backs the plugin rule that every prompt, model, or retrieval change ships with an eval run vs. baseline, and the AI QA verdict, which passes only when tests pass and the eval gate holds. Use it to add gates to CI, set thresholds and warn bands, place metrics on the ladder, handle flaky or bypassed gates, update a baseline after an accepted improvement, or review a PR that wants to merge past a red eval. Gate harnesses are built by `ai-engineer:ai-test-generator`.

**Elsewhere:**

- Designing the eval set and metrics → `skills/evals/eval-design`
- Judge rubrics, biases, calibration → `skills/evals/llm-judge`
- Training-pipeline promotion and rollout mechanics → `skills/mlops/ml-pipelines`
- Whether one trained checkpoint's weights ship (drift budget, paired comparison vs base, forgetting checks) → `skills/finetuning/checkpoint-promotion`; this skill owns the per-change CI ladder
- pytest/fixture depth with no eval surface → `system-developer:python-skills`

## Gate Placement Ladder

Each rung trades latency and cost for depth. A gate developers wait on gets bypassed; one that never runs catches nothing — place each check at the cheapest rung that can catch its failure class.

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

Judge-scored metrics enter at merge/nightly (cost, nondeterminism), so a red PR gate is always trustworthy. Human review appears only at release, per the eval hierarchy in `skills/evals/eval-design`.

## Implementation

Read `references/gate-implementation.md` for threshold design, baseline management and the update ritual, determinism and flake policy, cost engineering, pytest integration, and the escape hatch.

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
| Eval job present but `allow_failure` | The gate observes but never gates | PR rung is a required check; nightly failures page an owner |
| Smoke-subset value vs. full-set baseline | Subset bias masquerades as a regression (or hides one) | Record subset identity in the artifact; compare like with like |
| No thresholds "until we have more data" | A gate that can't fail | Provisional floors from the first baseline run; tighten with data |

## Verification

- [ ] Gate ladder placed: assertions pre-commit, deterministic smoke subset required at PR, full suite + judges nightly, human spot-check at release
- [ ] Every gated metric has direction, absolute floor/ceiling, relative delta, and warn band in a reviewed `gates.yaml`
- [ ] Baseline = last accepted main run; updates are reviewed diffs carrying eval-set version + run config, and keep pace with prompt changes
- [ ] Metrics artifact written every run (eval-set version, run config, judge identity, subset, transcript paths) and machine-comparable via `--baseline`
- [ ] Determinism: temp 0/seeds, pinned models and eval-set version; judge verdicts cached and/or majority-voted in the warn band
- [ ] Flake rate tracked against a budget; quarantined examples have owner, issue, expiry
- [ ] PR subset is stratified and deterministic; full-set cadence documented; subset identity recorded with metrics
- [ ] Gate failures link transcripts for failure analysis (`skills/evals/eval-design`)
- [ ] Escape hatch: overrides recorded in-repo (who/why/expiry + follow-up issue), never only in chat
- [ ] Trained-model promotion gates aligned with `skills/mlops/ml-pipelines`
