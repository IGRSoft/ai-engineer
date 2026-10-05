# Model & Effort Selection (ai-engineer)

Per-agent model assignments and override paths. Frontmatter in `agents/*.md` is the source of truth; keep this table in sync with it.

## Cost Tiers

| Model | Relative Cost | Use For |
|-------|---------------|---------|
| **haiku** | 1x (baseline) | Batch remediation, dependency mechanics (lockfiles, pins, CVE scans) |
| **sonnet** | ~10x haiku | Implementation, review, test/eval generation, serving work, routing |
| **opus** | ~50x haiku | Architecture decisions (RAG-vs-finetune-vs-prompt, agent topology, serving design) |

## Effort Levels

`low`, `medium`, `high`, `xhigh`, `max`; available levels depend on the model.

- Effort is set in agent frontmatter (`effort:`); an Agent call can't change it.
- Reserve `xhigh` for the hardest long-chain reasoning: architecture trade-offs, root-causing an eval regression that spans retrieval + prompt + model, threat modeling an agent's tool surface.

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
| `ai-security-auditor` | sonnet | high | 50 | → `opus` for deep threat modeling |
| `ai-performance-engineer` | sonnet | high | 50 | → `opus` for deep trace analysis |
| `ai-code-fixer` | haiku | medium | 30 | — deterministic minimal-diff remediation |
| `ai-dependency-manager` | haiku | low | 20 | — mechanical lockfile/pinning operations |

## House Rules

- Pass `model` on every Agent call as a short alias (`opus` / `sonnet` / `haiku` / `fable`) rather than relying on frontmatter inheritance.
- Prefer aliases over pinned model IDs; pinned IDs go stale.
- Prefer `opus` over `fable` for overrides: `fable` is 1M-context by default and fails dispatch on accounts without 1M usage credits.

## Applying an Override

Pass `model` on the Agent call; it applies to that invocation only. Override `ai-performance-engineer` or `ai-security-auditor` to `opus` only when the investigation spans several subsystems or needs long-chain causal reasoning; the sonnet/high default covers most work.

```
Agent({ subagent_type: "ai-engineer:ai-performance-engineer",
        model: "opus",
        prompt: "Root-cause the 40% throughput regression across the retriever, KV-cache config, and vLLM serving traces…" })
```

Both stay review-only at any model (no Write/Edit in `tools`); fixes route to `ai-engineer:ai-code-fixer`.
