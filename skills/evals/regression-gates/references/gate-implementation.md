# Regression Gates — Implementation Deep Dive

Deep-dive companion to [../SKILL.md](../SKILL.md): threshold design, baseline management, determinism and flake policy, cost engineering, pytest integration, and the escape-hatch protocol.

## Threshold Design

Every gated metric carries four decisions, recorded in a config reviewed like
code:

1. **Direction** — higher-better (F1, faithfulness) vs. lower-better (over-refusal
   rate, p95 latency, cost/query). Gates must know which way is bad.
2. **Absolute floor/ceiling** — the never-acceptable line, independent of history
   ("field F1 never below 0.85").
3. **Relative-to-baseline delta** — the regression trigger ("no drop > 0.02 vs.
   baseline"), which catches decay long before the floor.
4. **Warn band (quarantine band)** — deltas inside the measured noise floor
   (`skills/evals/eval-design/references/eval-methodology.md § Statistical Honesty`) warn and annotate instead
   of failing; beyond it, fail. Without a warn band you either chase noise or
   widen thresholds until they catch nothing.

```yaml
# evals/gates.yaml — reviewed like code; versions pinned
eval_set: invoice-extraction@2026.06.2     # metrics only comparable within this
metrics:
  field_f1:      {direction: higher, floor: 0.85, max_drop: 0.02, warn_band: 0.01}
  faithfulness:  {direction: higher, floor: 0.90, max_drop: 0.02, warn_band: 0.01}
  over_refusal:  {direction: lower, ceiling: 0.05, max_rise: 0.01, warn_band: 0.005}
  p95_latency_s: {direction: lower, ceiling: 8.0, max_rise: 1.0, warn_band: 0.5}
policy:
  warn: annotate PR + require acknowledgment
  fail: block merge; escape hatch per protocol below
```

## Baseline Management

- **Baseline = the metrics artifact of the last accepted main run** — never
  "whatever ran last". Comparing to the previous run lets quality ratchet
  downward 1% at a time, each step individually inside tolerance.
- **Stored artifact.** Each gate run writes a metrics JSON (eval-set version,
  run config, per-metric values, transcript paths). The accepted one is
  committed (or stored in the CI artifact store keyed by main-branch commit).
- **Explicit baseline-update ritual.** When an improvement is accepted, the
  *same PR or an immediate follow-up* updates the baseline file — a reviewed
  diff showing old→new numbers, eval-set version, and run config. Baselines
  never auto-ratchet in either direction: silent auto-update on merge converts
  every regression that slips through into the new normal.
- **Eval-set version bump ⇒ re-baseline.** Metrics across set versions have
  different denominators and are incomparable. On a bump, run old and new sets
  side-by-side once, record both, then gate on the new baseline.

```json
{
  "eval_set": "invoice-extraction@2026.06.2",
  "commit": "9f31c2d",
  "run_config": {"model": "<pinned-model-id>", "temperature": 0, "seed": 7},
  "judge_identity": "<pinned-judge-id>+rubric@3",
  "metrics": {"field_f1": 0.912, "faithfulness": 0.951, "over_refusal": 0.021},
  "transcripts": "evals/out/2026-07-22/transcripts/"
}
```

## Determinism and Flake Policy

- **Deterministic settings everywhere:** temperature 0, fixed seeds where
  supported, pinned model IDs (verify against current provider docs via
  context7), pinned eval-set version. This is the base agent contract — a gate
  without it measures the weather.
- **Judge nondeterminism** survives temperature 0. Two remedies, use both:
  **cached verdicts** keyed by `hash(input, output, judge_identity)` — unchanged
  outputs re-judge identically and free — and an **N-run majority vote** (N=3)
  for uncached verdicts that land inside the warn band, where single-call noise
  decides pass/fail.
- **Flake budget.** Track gate flake rate: same commit, different verdicts. When
  it exceeds a small budget (a percent, not a vibe), fix determinism — do not
  widen thresholds, and do not normalize "re-run until green".
- **Quarantine list**, exactly like flaky tests: a known-unstable example moves
  to quarantine — still executed and reported, no longer blocking — with an
  owner, a linked issue, and an **expiry date**. Quarantine growth without
  expiries is a gate quietly dissolving.

## Cost Engineering

The full suite with judges is too expensive per-PR by design — subset instead
of dilute:

| Strategy | How | Where |
|----------|-----|-------|
| Stratified by tag | Deterministic sample per taxonomy tag (`skills/evals/eval-design`) so every failure mode keeps coverage | PR smoke subset |
| Rotating panels | Nightly run covers slice `k` of `K`; full coverage every `K` nights, seeded by date | Nightly full-suite budget control |
| Failure-biased sampling | Oversample examples that failed in the last M runs — regressions recur where they happened before | PR + nightly extras |
| Cached judge verdicts | Only changed outputs hit the judge; the rest replay | Every judged rung |

Full-set cadence: nightly if budget allows, else weekly + always pre-release.
Record which subset a run used in the metrics artifact — a smoke-subset number
must never be compared against a full-set baseline value.

## Pytest Integration

Evals run as pytest so CI, markers, and reporting come free. Harness
construction: `ai-engineer:ai-test-generator`.

```python
# evals/conftest.py
"""Eval-gate fixtures: one session-scoped eval run, metrics artifact, baseline.

PR tier:   uv run pytest evals -m smoke --baseline evals/baselines/main.json
Full tier: uv run pytest evals --baseline evals/baselines/main.json
"""
import json
from pathlib import Path

import pytest

from evals.harness import load_gates, run_suite

def pytest_addoption(parser: pytest.Parser) -> None:
    parser.addoption("--baseline", type=Path, default=None,
                     help="Metrics artifact of the last accepted main run")

@pytest.fixture(scope="session")
def baseline(request: pytest.FixtureRequest) -> dict | None:
    path = request.config.getoption("--baseline")
    return json.loads(path.read_text()) if path else None

@pytest.fixture(scope="session")
def run(request: pytest.FixtureRequest) -> dict:
    """Run the suite once (temp 0, pinned set) and persist the artifact."""
    subset = "smoke" if request.config.getoption("-m") == "smoke" else "full"
    artifact = run_suite(subset=subset)          # returns the metrics JSON dict
    out = Path("evals/out/metrics.json")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(artifact, indent=2))
    return artifact
```

```python
# evals/test_extraction_gate.py
"""Regression gate: per-example assertions + aggregate thresholds vs baseline."""
import pytest

from evals.harness import load_examples, load_gates

EXAMPLES = load_examples("evals/datasets/invoice-extraction", subset="smoke")

@pytest.mark.smoke
@pytest.mark.parametrize("ex", EXAMPLES, ids=lambda e: e.id)
def test_example_assertions(ex, run: dict) -> None:
    """Tier-1 checks stay per-example: failures name the transcript directly."""
    result = run["results"][ex.id]
    assert result["schema_valid"], f"schema: {result['errors']} ({result['transcript']})"

@pytest.mark.smoke
def test_aggregate_gate(run: dict, baseline: dict | None) -> None:
    """Absolute floors always; relative deltas when a baseline is supplied."""
    failures: list[str] = []
    for name, gate in load_gates("evals/gates.yaml").items():
        value = run["metrics"][name]
        if gate.breaches_absolute(value):
            failures.append(f"{name}={value:.3f} breaches {gate.absolute_bound}")
        if baseline and gate.regresses(value, baseline["metrics"][name]):
            failures.append(f"{name}: {baseline['metrics'][name]:.3f} → {value:.3f} "
                            f"exceeds allowed delta (see {run['transcripts']})")
    assert not failures, "\n".join(failures)
```

CI wiring sketch (PR rung; pin action versions per repo policy):

```yaml
# .github/workflows/eval-gate.yml — required check for merge
eval-smoke:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout
    - run: curl -LsSf https://astral.sh/uv/install.sh | sh
    - run: uv sync --frozen
    - run: uv run pytest evals -m smoke --baseline evals/baselines/main.json
    - if: always()
      uses: actions/upload-artifact          # metrics + transcripts for triage
      with: {name: eval-metrics, path: evals/out/}
```

Gate failures must point at transcripts (the artifact upload above), because the
fix workflow is `skills/evals/eval-design/references/eval-methodology.md § Failure Analysis` — nobody can act
on "field_f1 dropped 0.03" alone.

## Escape Hatch Protocol

Sometimes a red gate must be overridden — a hotfix outranks a warn-band metric,
or the gate itself is wrong. Overrides are legitimate **only when recorded**:

1. **Recorded rationale** — who overrode, why, which metrics were red, expiry.
2. **Follow-up issue** — filed before merge, linked in the override record;
   fixing the regression or the gate is now scheduled work.
3. **Annotation in the metrics artifact** — the run is marked `overridden`, so
   it can never silently become a baseline.
4. **Never a threshold edit in disguise.** Changing `gates.yaml` in the same PR
   that fails it is an unrecorded override; threshold changes ship separately
   with their own review.

```yaml
# evals/overrides/2026-07-22-hotfix-1382.yaml
gate: field_f1                # 0.87 vs floor 0.85, max_drop breached
by: korich.vi.p@gmail.com
reason: P0 hotfix for prod incident 1382 outranks a warn-band regression
follow_up: repo#1391          # re-run + fix scheduled
expires: 2026-07-29
```

In worktask context the same rule surfaces as the QA verdict: `no-go` carries
the eval failure into `metadata.gate_blockers[]`, and any override rationale
lives in the QA artifact and PR — never only in chat
(`skills/_shared/workflow-integration/references/stage-details.md § Gate-Feedback Contract`).
