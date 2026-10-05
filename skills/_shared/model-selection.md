---
name: model-selection
description: Model and effort selection for ai-engineer agents — cost tiers, per-agent assignments, and per-call model override paths. Reference when delegating to or overriding an ai-engineer specialist.
effort: low
---

# Model & Effort Selection (ai-engineer)

Companion to the orchestrator's model-selection reference. This file pins the
**ai-engineer** per-agent assignments and the override paths the domain
agents expose. Frontmatter in `agents/*.md` is the source of truth — keep this
table in sync with it.

## Cost Tiers

| Model | Relative Cost | Use For |
|-------|---------------|---------|
| **haiku** | 1x (baseline) | Batch remediation, dependency mechanics (lockfiles, pins, CVE scans) |
| **sonnet** | ~10x haiku | Implementation, review, test/eval generation, serving work, routing |
| **opus** | ~50x haiku | Architecture decisions (RAG-vs-finetune-vs-prompt, agent topology, serving design) |

## Effort Levels

`low` ○, `medium` ◐, `high` ●, `xhigh` ⬣.

- Effort is set in agent frontmatter (`effort:`); an Agent call can't change it.
- `xhigh` is honored **only on Opus 4.8 or Fable 5** — Sonnet/Haiku silently
  downgrade the thinking budget to `high`.
- Reserve `xhigh` for the hardest long-chain reasoning (architecture trade-offs,
  root-causing an eval regression that spans retrieval + prompt + model,
  threat modeling an agent's tool surface).

## Per-Agent Assignment

| Agent | Model | Effort | maxTurns | Override path |
|-------|-------|--------|----------|---------------|
| `ai-engineer` (router) | sonnet | medium | 40 | — routes work to specialists |
| `llm-engineer` | sonnet | high | 50 | → `opus` for novel agent-loop design / cross-system RAG work |
| `ml-engineer` | sonnet | high | 50 | → `opus` for novel training recipes / multi-stage tuning (SFT→DPO) |
| `mlops-engineer` | sonnet | high | 50 | — sonnet sufficient for serving/pipeline work |
| `ai-prompt-engineer` | sonnet | high | 50 | — sonnet sufficient for eval-driven prompt iteration |
| `ai-architector` | opus | xhigh | 60 | already top tier; self-limits scope at Low complexity |
| `ai-test-generator` | sonnet | high | 50 | — sonnet sufficient for harness/pattern work |
| `ai-security-auditor` | sonnet | high | 50 | → `opus` for deep threat modeling (review-only: no Write/Edit in `tools`) |
| `ai-performance-engineer` | sonnet | high | 50 | → `opus` for deep trace analysis (review-only: no Write/Edit in `tools`) |
| `ai-code-fixer` | haiku | medium | 30 | — deterministic minimal-diff remediation |
| `ai-dependency-manager` | haiku | low | 20 | — mechanical lockfile/pinning operations |

## House Rules

- **Pass `model` on every Agent call** using the short alias
  (`opus` / `sonnet` / `haiku` / `fable`) — do not rely on frontmatter
  inheritance.
- **Prefer aliases over pinned model IDs** — aliases track the current
  generation; pinned IDs go stale.
- **Prefer `opus` over `fable` for overrides**: `fable` is 1M-context by
  default and hard-fails dispatch on accounts without 1M usage credits.

## Applying an Override

Pass `model` on the Agent call (per-invocation, does not edit frontmatter);
effort stays at the agent's frontmatter value. Callers of
`ai-performance-engineer` and `ai-security-auditor` may override to `opus`
when the investigation spans multiple subsystems or requires long-chain
causal reasoning:

```
Agent({ subagent_type: "ai-engineer:ai-performance-engineer",
        model: "opus",
        prompt: "Root-cause the 40% throughput regression across the retriever, KV-cache config, and vLLM serving traces…" })
```

Only override when complexity warrants it — the sonnet/high default covers the
overwhelming majority of AI-engineering work. Both review-only agents keep their
Write/Edit-free `tools` list regardless of model: fixes route to
`ai-engineer:ai-code-fixer`.
