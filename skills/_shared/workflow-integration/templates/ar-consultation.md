# AR Consultation Template (AI architecture)

`corpflow:software-architector` owns `.context/analyzing-N.md`. `ai-architector` writes the consultation document below to `.context/ai-architecture.md` and returns a ≤500-token summary — see `workflow-integration/references/stage-details.md § AR Consultation Model`.

```markdown
---
handoff:
  stage: AR
  verdict: ok           # ok | blocked | escalate
  summary: "<chosen architecture + the one criterion that decided it — ≤200 chars>"
  key_decisions:        # REQUIRED for AR
    - id: a1
      summary: "Hybrid RAG + LoRA style adapter; prompt-only rejected on knowledge freshness"
      anchor: ai-architecture.md#decision
  next_stage_focus: "<what DV must build first — ≤240 chars>"
  open_questions:
    - "<unresolved constraint blocking a decision, or omit>"
  refs:
    plan: planning-0.md#requirements
---

# AI Architecture — <worktask_id>

## context

<one-sentence problem statement + the hard constraints that bind the decision:
latency budget, cost ceiling, data actually available, update cadence,
privacy/residency, ops capacity, and the success metric with its threshold>

## options

| Option | Fit | Cost / latency | Rejected because |
|--------|-----|----------------|------------------|
| Prompt only | <fit> | <numbers> | <criterion it failed> |
| RAG | <fit> | <numbers> | <criterion, or "chosen"> |
| Fine-tune | <fit> | <numbers> | <criterion it failed> |

## decision

<chosen architecture, traceable to the named criteria above>

## consequences

<build cost, run-rate formula, operational load, new failure modes, rollback path>

## revisit-when

- <measurable trigger, e.g. "eval-set grounding score < 0.85 at p50 corpus growth 3x">

## eval-plan

<the eval that would falsify the capability claim: suite, metric, threshold>
```

## Notes

- **Consultation is the default.** Return the ≤500-token recommendation; `software-architector` merges it into `analyzing-N.md` and authors the `PL→AR` handoff. Write `analyzing-N.md` yourself **only** when `task.metadata.agent` names `ai-engineer:ai-architector`.
- Verify volatile claims (model capabilities, context windows, API features, pricing mechanics) via Context7 before recording them — an ADR built on remembered pricing is wrong within a quarter.
- Cheapest reversible layer first: prompt → RAG → fine-tune. Escalate only where a pinned eval set proves the cheaper layer's ceiling, and say which eval proved it.
- `key_decisions[].anchor` must resolve to a real `## <kebab-case>` heading in `ai-architecture.md` (anchor-lint enforces this).
- Frontmatter budget: ≤200 tokens, ≤30 lines.
