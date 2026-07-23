---
name: model-monitoring
description: >-
  Watching models in production across three planes: system (latency, errors,
  saturation), model quality (drift, refusal/format-failure rates,
  judge-scored samples), business (completion, escalation, cost). LLM trace
  observability, drift detection via scheduled judge evals on sampled traffic,
  per-feature cost dashboards and spend alarms, feedback loops into eval sets
  and fine-tuning data, canary vs control. Use when wiring observability for
  an LLM app, investigating quality regressions or spend spikes, scheduling
  judge evals on traffic, designing alerts, or feeding failures into eval
  sets.
---

# Model Monitoring

## Overview

Models fail differently from services: the process stays up, the latency stays
green, and the answers quietly get worse. Uptime monitoring cannot see that.
Model monitoring watches three planes at once — is the service healthy, is the
model still good, is the product still working — and wires what it finds back
into evals and training data so each failure is only paid for once.

The unit of observability is the trace: one request with everything needed to
replay it and judge it.

## When to Use

- Wiring observability for a newly deployed model or LLM feature
- Investigating "it got worse" reports, quality regressions, or spend spikes
- Setting up scheduled judge evals on sampled production traffic
- Designing alerts, canary comparisons, or rollback triggers
- Deciding what to log per request and how long to keep it

**When NOT to use:**

- Building the judge/rubric itself → `skills/evals/llm-judge`
- Offline, pre-release evaluation and CI gates → `skills/evals/eval-design`, `skills/evals/regression-gates`
- Serving infrastructure (probes, drain, canary routing mechanics) → `skills/mlops/model-serving`
- Curating the fine-tuning data that feedback produces → `skills/finetuning/dataset-curation`

## The Three Monitoring Planes

```
┌─ SYSTEM ────── latency (TTFT/TPOT/total, p50–p99) · error/timeout rates
│                saturation: queue depth, KV/VRAM utilization on GPU hosts
│                (CPU serving tracks CPU/RAM instead) — owned by normal SRE practice
├─ MODEL ─────── output-quality trend (judge-scored samples) · refusal rate
│                format/schema-failure rate · retrieval hit quality · input drift
├─ BUSINESS ──── task completion · escalation/handoff-to-human rate
│                user feedback rates · cost per task / per feature
└─ every alert, canary, and dashboard states which plane it watches
```

A healthy deployment has at least one metric per plane, sliced by feature (and
by intent/language where those differ). System-plane green with the model
plane unmonitored is the classic silent failure: nothing pages while quality
rots.

| Plane | Example metrics | Typical failure it catches |
|-------|-----------------|----------------------------|
| System | p99 TTFT, 5xx rate, queue depth | Overload, cold starts, provider outages |
| Model | judge-score trend, refusal %, JSON-parse failure % | Prompt/model regressions, drift, jailbreak waves |
| Business | completion %, escalation %, cost per task | "Technically working, practically useless" |

## Deep Dives

Read `references/observability-and-drift.md` for LLM trace observability, drift detection via scheduled judge evals, cost monitoring, feedback loops, and canary/rollback/alert design.

## Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| System-plane dashboards only | Quality rots while everything is green | At least one metric per plane, per feature |
| Aggregate-only quality scores | Cannot see which segment regressed | Slice by feature / intent / language |
| Full traces, everything, forever | Cost + PII liability | Tiered sampling, scrubbing, TTLs |
| Judge config drifts silently | Fake quality trends | Pin judge + rubric versions; co-score a golden set |
| Alerting on every metric | Pager fatigue → alerts ignored | Page symptoms; ticket trends |
| Feedback captured, never routed | Labels rot unused | Scheduled routing into eval sets / datasets |
| Canary judged by anecdote | "Looks fine" ships regressions | Predeclared metrics, canary vs control |
| Cost checked on the invoice | Weeks-late detection | Per-feature dashboards + anomaly alarms |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Users will tell us when it breaks" | Users rarely report wrong-but-plausible answers; they quietly stop trusting the feature. |
| "We eval before every release — that covers quality" | Offline evals cannot see traffic shift, retrieval staleness, or upstream changes. Production is a different distribution. |
| "Judge evals on prod traffic are too expensive" | A few hundred sampled scores a night is a rounding error; an unnoticed bad month is not. |
| "Cost dashboards are finance's problem" | A retry loop looks like growth to finance and like a bug to you. Engineering owns the token meter. |
| "We can't log prompts — privacy" | Log versions/ids/counters at 100% and scrubbed content at a small sample. Zero observability is not a privacy strategy. |
| "We'll add monitoring after launch" | Launch week is the highest-drift, highest-attention window you will ever get. |

## Red Flags

- Nobody can state today's refusal or format-failure rate
- A prompt changed last week and no chart shows a break anywhere
- Spend doubled and the invoice was the detection mechanism
- Feedback buttons exist, but nobody can point to where the labels go
- A canary was promoted after "an hour of watching it"
- The judge model or rubric was upgraded mid-quarter and trends were kept as-is
- The trace store contains raw PII with no TTL

## Verification

- [ ] Each plane (system / model / business) has ≥1 metric, sliced per feature
- [ ] Traces carry prompt version, model revision, token counts, per-hop latency, and outcome
- [ ] Failure and user-flagged traces retained at 100% and triaged on a schedule
- [ ] Scheduled judge eval runs on sampled traffic: pinned judge config + rubric, temperature 0, golden set co-scored
- [ ] Input-drift distributions (length / topic / language) tracked against a reference window
- [ ] Per-feature cost dashboard live; spend anomaly alarm armed; cache hit-rate visible
- [ ] Canary comparison predeclared and automated against control on the same monitors
- [ ] Paging alerts limited to user-facing symptoms; drift and cost trends are tickets

## Related Skills

- `skills/mlops/model-serving` — canary routing, probes, and rollback mechanics
- `skills/mlops/experiment-tracking` — run baselines that prod trends compare against; alias-flip rollback
- `skills/mlops/ml-pipelines` — the retraining/refresh pipelines that drift findings trigger
- `skills/evals/llm-judge` — building and calibrating the judge this skill schedules
- `skills/evals/eval-design` — turning triaged failures into durable eval cases
- `skills/finetuning/dataset-curation` — hygiene for feedback-derived training data

Owning agent: `ai-engineer:mlops-engineer`.
