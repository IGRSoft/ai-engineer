---
name: model-monitoring
description: >-
  Watching models in production across three planes: system (latency, errors,
  saturation), model quality (drift, refusal/format-failure rates,
  judge-scored samples), business (completion, escalation, cost). Covers LLM
  traces, scheduled judge evals on sampled traffic, spend alarms, feedback
  loops into eval sets, canary vs control. Use when wiring observability for
  an LLM app, investigating quality regressions or spend spikes, designing
  alerts, or feeding failures into eval sets.
---

# Model Monitoring

Models fail differently from services: the process stays up, latency stays green, and the answers quietly get worse. Model monitoring watches three planes — is the service healthy, is the model still good, is the product still working — and routes what it finds back into evals and training data so each failure is paid for once. The unit of observability is the trace: one request with everything needed to replay and judge it. Owning agent: `ai-engineer:mlops-engineer`.

**Elsewhere:**

- Building the judge/rubric → `skills/evals/llm-judge`; turning triaged failures into eval cases → `skills/evals/eval-design`
- Offline pre-release evals and CI gates → `skills/evals/regression-gates`
- Probes, drain, canary routing mechanics → `skills/mlops/model-serving`; alias-flip rollback and run baselines → `skills/mlops/experiment-tracking`
- Retraining pipelines that drift findings trigger → `skills/mlops/ml-pipelines`
- Curating feedback-derived training data → `skills/finetuning/dataset-curation`

## The Three Monitoring Planes

| Plane | Example metrics | Typical failure it catches |
|-------|-----------------|----------------------------|
| System | TTFT/TPOT/total latency p50–p99, error/timeout rate, queue depth, KV/VRAM utilization (CPU/RAM on CPU serving) | Overload, cold starts, provider outages |
| Model | judge-score trend, refusal %, format/schema-failure %, retrieval hit quality, input drift | Prompt/model regressions, drift, jailbreak waves |
| Business | task completion %, escalation-to-human %, feedback rates, cost per task / feature | "Technically working, practically useless" |

A healthy deployment has at least one metric per plane, sliced by feature (and by intent/language where those differ), and every alert, canary, and dashboard states which plane it watches. System-plane green with the model plane unmonitored is the classic silent failure: nothing pages while quality rots. Offline evals don't replace this — they can't see traffic shift, retrieval staleness, or upstream changes — and launch week is the highest-drift window, so monitors go live before launch.

Read `references/observability-and-drift.md` for the trace schema and retention tiers, drift detection via scheduled judge evals, cost monitoring, feedback loops, and canary/rollback/alert design.

## Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| System-plane dashboards only | Quality rots while everything is green | At least one metric per plane, per feature |
| Aggregate-only quality scores | Cannot see which segment regressed | Slice by feature / intent / language |
| Full traces, everything, forever | Cost + PII liability | Tiered sampling, scrubbing, TTLs |
| No content logged "for privacy" | Zero observability | Versions/ids/counters at 100%, scrubbed content at a small sample |
| Judge config drifts silently | Fake quality trends | Pin judge + rubric versions; co-score a golden set; restart trends on upgrade |
| Alerting on every metric | Pager fatigue → alerts ignored | Page symptoms; ticket trends |
| Feedback captured, never routed | Labels rot unused | Scheduled routing into eval sets / datasets |
| Canary judged by anecdote | "Looks fine" ships regressions | Predeclared metrics, canary vs control |
| Cost checked on the invoice | Weeks-late detection; a retry loop looks like growth | Per-feature dashboards + anomaly alarms |

## Verification

- [ ] Each plane (system / model / business) has ≥1 metric, sliced per feature
- [ ] Today's refusal and format-failure rates are on a chart, and prompt releases show as markers on it
- [ ] Traces carry prompt version, model revision, token counts, per-hop latency, and outcome
- [ ] Failure and user-flagged traces retained at 100% and triaged on a schedule; trace store PII-scrubbed with a TTL
- [ ] Scheduled judge eval runs on sampled traffic: pinned judge config + rubric, temperature 0, golden set co-scored
- [ ] Input-drift distributions (length / topic / language) tracked against a reference window
- [ ] Per-feature cost dashboard live; spend anomaly alarm armed; cache hit-rate visible
- [ ] Canary comparison predeclared and automated against control on the same monitors
- [ ] Paging alerts limited to user-facing symptoms; drift and cost trends are tickets
