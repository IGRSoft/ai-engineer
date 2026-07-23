# Model Monitoring — Observability and Drift Deep Dive

Deep-dive companion to [../SKILL.md](../SKILL.md): LLM trace observability, drift detection, cost monitoring, feedback loops, and canary/rollback/alert design.

## LLM Trace Observability

Log the full request context — a metric tells you *that*, only a trace tells
you *why*:

```python
from typing import Any, TypedDict


class LLMTrace(TypedDict):
    """One request, replayable and judgeable. The metadata tier logs all fields;
    content (chunk text, messages) exists only in the sampled full-trace tier."""

    trace_id: str
    ts: str
    feature: str                    # which product surface spent these tokens
    prompt_version: str             # ties quality shifts to prompt releases
    model_revision: str             # what actually served — alias resolved
    retrieved_chunk_ids: list[str]  # ids + scores always; contents only when sampled
    tool_calls: list[dict[str, Any]]  # name, args digest, latency, outcome
    tokens: dict[str, int]          # prompt / completion / cached — per hop
    latency_ms: dict[str, float]    # retrieval, first_token, total — per hop
    outcome: str                    # ok | refusal | format_failure | tool_error | timeout
```

Retention is tiered — full traces of everything forever is a cost and privacy
liability; zero traces is flying blind:

| Tier | What | How much | Retention |
|------|------|----------|-----------|
| Metadata + counters | versions, tokens, latency, outcome | 100% | Long (cheap, no content) |
| Full traces | + prompt, chunks, output | Small sampled % | Short, PII-scrubbed |
| Failures + user-flagged | Full trace | 100% | Until triaged into an eval set |

Scrub PII before retention and treat trace stores as sensitive — route
data-handling and retention review to `ai-engineer:ai-security-auditor`.

## Drift: Inputs Shift, Outputs Decay

**Input drift** — the traffic changes, not the model: topic mix, prompt
length, language distribution, new intents. Track distributions over trace
metadata (length percentiles, language/intent shares) against a reference
window. Input drift is the leading indicator; quality follows it.

**Output drift** — quality on live traffic trends down even with the model
frozen (inputs moved into weaker territory, retrieval staleness, upstream
model/API changes). Offline evals cannot see it; measure it with scheduled
judge evals on sampled traffic:

```yaml
# monitoring/quality-probe.yaml — nightly judge pass over sampled prod traffic
sample:
  source: traces
  filter: { feature: support-chat, outcome: ok }
  n: 200                       # small and stratified — trend detection, not a census
  strategy: stratified_by_intent
judge:
  config: evals/judge/support-rubric-v5.yaml   # pinned rubric + judge settings
  temperature: 0                               # deterministic scoring
reference:
  eval_set: golden-v12         # pinned static set scored in the same pass,
                               # to separate judge drift from real output drift
report:
  - judge_score_mean by intent, 7d trend
  - refusal_rate, format_failure_rate
```

Score a pinned golden set with the same judge in the same pass: if golden-set
scores moved, your *judge* drifted, not your model. Rubric and calibration
design live in `skills/evals/llm-judge`.

## Cost Monitoring

Token spend is an engineering signal, not just a finance line:

- **Per-feature dashboards**: tokens (prompt / completion / cached) and cost
  per feature per day — attribution first, optimization second.
- **Anomaly alarms on spend**: a retry loop or a runaway agent looks like
  organic growth until the invoice. Alarm on rate-of-change and on hard caps.
- **Cache hit-rate**: prompt-cache hit rate trends with template stability; a
  hit-rate cliff usually means someone edited a cached prefix
  (`skills/llm-apps/llm-api-patterns`).
- Never hardcode prices into dashboards — meter tokens and resolve current
  rates at render time (verify against current provider docs).

## Feedback Loops: Pay for Each Failure Once

```
traces ──▶ failure triage ──▶ labeled examples ──▶ eval-set additions (skills/evals/eval-design)
   │                                │
   ├─ explicit: ratings, edits,     └────────────▶ fine-tuning data
   │   thumbs, corrections                         (skills/finetuning/dataset-curation)
   └─ implicit: retry, abandon, copy/accept, escalate-to-human
```

- Capture **explicit** feedback where the product allows it (thumbs, edit
  diffs of model output, correction text) — attached to the trace id.
- Mine **implicit** signals: immediate retry with a rephrase, abandonment,
  copy/accept events, escalation — higher-volume and less biased than thumbs.
- **Route on a schedule**: labeled failures become eval cases (regression
  protection) and, when volume permits, fine-tuning examples. Feedback that is
  collected but never routed is decoration.

## Canary, Rollback, and Alert Design

- **Canary vs control on identical monitors**: same planes, same metrics, same
  slices; predeclare the comparison criteria and window before rollout.
  Traffic-splitting mechanics live in `skills/mlops/model-serving`.
- **Rollback trigger**: any P0-grade symptom on the canary (error spike,
  refusal spike, format-failure spike) rolls back first and investigates
  second — the alias flip is cheap (`skills/mlops/experiment-tracking`).
- **Alert on symptoms, page on users:**

| Signal | Response | Rationale |
|--------|----------|-----------|
| Error/timeout burst, p99 collapse | Page | Users are affected right now |
| Refusal or format-failure rate spike | Page (user-facing surface) | Broken outputs, right now |
| Judge-score downward trend, input drift | Ticket | Erosion — investigate in days, not at 3am |
| Spend anomaly | Ticket; page only at a hard cap | Money, not availability |

Deep latency/throughput regressions on the system plane route to
`ai-engineer:ai-performance-engineer`.
