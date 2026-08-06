---
name: model-serving
description: >-
  Serving open-weights and fine-tuned models: managed-API vs self-hosted
  ladder (Ollama, vLLM, TGI, Triton, llama.cpp), deployment anatomy from
  pinned artifact to OpenAI-compatible endpoint behind a gateway, quantization
  (GPTQ/AWQ/GGUF), KV-cache capacity math and concurrency budgets, LoRA
  hot-swap vs merged weights, operational hardening (readiness, warmup, drain,
  canary, rollback). Use when deploying an LLM or adapter, choosing or sizing
  a serving stack, exposing a model endpoint, quantizing at serve time,
  planning GPU capacity, or reviewing a serving config before rollout.
---

# Model Serving

## Overview

Serving is where a model stops being an artifact and becomes a dependency with
an SLO. LLM serving is not a stateless web service: it is dominated by GPU
memory accounting (weights + KV cache), long-lived streaming responses, and
multi-gigabyte load times. Every deploy decision reduces to four questions —
what artifact (pinned revision), what runtime (engine + config), what surface
(OpenAI-compatible endpoint), and what guardrails (gateway, probes, rollback).

Get the memory math and the rollback path right first; throughput tuning comes
after correctness — route deep latency/throughput investigations to
`ai-engineer:ai-performance-engineer`.

## When to Use

- Deploying an open-weights or fine-tuned model (or a LoRA adapter) as an endpoint
- Choosing between a managed API and self-hosting — or between serving engines
- Sizing GPU memory, concurrency, and context-length budgets
- Quantizing a model for inference and deciding which format
- Reviewing a serving config, canary plan, or rollback story before rollout

**When NOT to use:**

- Calling provider APIs from application code (timeouts, retries, streaming, fallback routing) → `skills/llm-apps/llm-api-patterns`
- Producing the fine-tuned artifact itself → `skills/finetuning/peft-lora`
- *Exporting* a freshly promoted checkpoint — merged vs LoRA-only, export format, the pre/post smoke test → `skills/finetuning/quantized-export` (it produces the artifact; this skill runs it)
- Watching the deployed model in production → `skills/mlops/model-monitoring`
- Registering/promoting the artifact you are about to serve → `skills/mlops/experiment-tracking`

## The Serving Decision Ladder

```
Need an LLM behind an endpoint?
│
├── No dedicated-infra mandate, spiky/low volume, frontier-quality needs
│      └──▶ managed API — stop here (see skills/llm-apps/llm-api-patterns)
│
└── Self-host: weights control, data residency, fine-tunes, steady-load economics
    │
    ├── laptop / dev box / single machine, fast iteration ──▶ Ollama (llama.cpp family)
    ├── GPU throughput under real concurrency              ──▶ vLLM
    ├── HF-ecosystem deployment, similar goals             ──▶ TGI
    ├── heterogeneous multi-model / multi-framework fleet  ──▶ Triton (+ LLM backend)
    └── CPU-only / edge / minimal footprint                ──▶ llama.cpp server + GGUF
```

Select on dimensions, not fashion. Capabilities shift fast — verify against
each engine's current docs (context7); the filled-in per-stack matrix lives in
`references/serving-stack-matrix.md`.

| Dimension | Question to ask | Why it decides |
|-----------|-----------------|----------------|
| Batching model | Continuous batching or request-at-a-time? | Dominates throughput under concurrent load |
| Quantization formats | Which of GPTQ/AWQ/GGUF/FP8-class load natively? | Sets the memory floor and hardware fit |
| Multi-LoRA | Many adapters over one base at runtime? | One GPU can serve N fine-tunes |
| OpenAI-compat surface | `/v1/chat/completions` incl. streaming + tool calls? | Client portability, gateway reuse |
| Hardware span | CUDA-only, or CPU/Metal/ROCm too? | Dev/prod parity; laptop reproduction |
| Ops profile | Single binary vs K8s-native vs model-repo daemon? | Must match the team's capacity to operate it |

No `nvidia-smi` on the box? You are on the CPU/MPS rung: GGUF via
Ollama/llama.cpp, order-of-magnitude lower throughput — plan capacity for it
explicitly. A *silent* CPU fallback in prod is an incident, not a config.

## Deployment Anatomy

```
model artifact (registry alias / HF repo @ pinned revision)   ← immutable input
        │
runtime config (context cap, max seqs, dtype/quant, adapters) ← versioned file in git
        │
serving engine ──▶ OpenAI-compatible endpoint (streaming on)
        │
gateway: authn (keys/mTLS) · rate limits · per-tenant quotas · request logging
```

```yaml
# serving/config.yaml — versioned next to code; exact flag names vary by
# engine release (verify current docs via context7)
model:
  source: "models:/support-summarizer@prod"   # registry alias, or hf://org/name
  revision: "<commit-hash>"                    # resolved + recorded at deploy — never "main"
runtime:
  max_model_len: 8192       # context budget: what the product needs, not the model max
  max_num_seqs: 64          # concurrency ceiling from the KV-cache math below
  dtype: auto
  quantization: awq         # only after the quantized artifact passed the eval suite
adapters:
  - name: support-v3
    source: "hf://org/support-lora"
    revision: "<commit-hash>"
```

The gateway is not optional hardening — it is part of the deployment: without
authn, rate limits, and per-tenant quotas, an OpenAI-compatible endpoint is a
free compute API for whoever finds it. Route endpoint-exposure and abuse-path
review to `ai-engineer:ai-security-auditor`.

## Quantization for Serving

Quantization trades memory (and often latency) against quality. What it never
is: free. **A quantized artifact is a different model — eval it as one.**

| Format | Targets | Mechanism notes |
|--------|---------|-----------------|
| GPTQ | GPU weight-only, int4-class | Post-training, calibration-set based; broad engine support |
| AWQ | GPU weight-only, int4-class | Activation-aware: protects salient channels; similar footprint to GPTQ |
| GGUF | llama.cpp/Ollama family; CPU/Metal-first | Container format with graded quant levels (higher-bit = safer) |
| FP8 / quantized KV | Newer GPUs; engine-dependent | Halves weight or KV bytes; hardware + engine support varies — verify |

Rules:

- Promote only after the exact quantized artifact passes the eval suite
  (pinned eval-set version, temperature 0) against the fp16 baseline —
  generic "negligible loss" benchmark claims do not transfer to your task.
- Register the quantized artifact as its own version; keep the fp16 version
  registered for rollback and re-quantization.
- Expect non-uniform degradation: instruction-following, code, and math
  degrade before fluency does. Slice the evals accordingly.

## Capacity Planning: the KV Cache Is the Ceiling

GPU memory, not compute, is usually the real limit. Weights are a fixed cost;
the KV cache grows with every concurrent sequence and every token of context:

```
kv_bytes_per_token = 2 × n_layers × n_kv_heads × head_dim × bytes_per_element
                     ↑ K and V        ↑ GQA: num_key_value_heads, not attention heads
kv_per_sequence    = kv_bytes_per_token × context_len
concurrency_max    ≈ (vram − weights − runtime_overhead) / kv_per_sequence
```

Read `n_layers` / `n_kv_heads` / `head_dim` from the model's `config.json` —
never assume the shape. Levers, in order of cheapness: cap `max_model_len` to
the product's real context need; cap max concurrent sequences; quantize
weights; quantize the KV cache (engine-dependent). Continuous-batching engines
with paged KV allocate by actual tokens used, so real concurrency beats the
worst-case math when typical requests are short.

Worked example with symbolic numbers, degraded single-GPU/CPU configs, and the
per-deploy checklist: read `references/serving-stack-matrix.md` when sizing a
box or comparing stacks.

## Operational Hardening

- **Liveness ≠ readiness.** Ready only after weights are loaded *and* warmup
  completed. A TCP-open port with cold weights serves 30-second first tokens.
- **Warmup**: run representative requests (typical + max context) before
  joining the pool — triggers lazy compilation/graph capture and page-in.
- **Graceful drain**: on shutdown, stop accepting, let in-flight streams
  finish (bounded), then exit. Rolling restarts without drain kill mid-stream.
- **Rollback = revision flip.** The previous artifact version stays loadable;
  rolling back is repointing the alias/config, never rebuilding an image.
- **Canary by traffic fraction**: route a small percentage to the new
  revision; compare canary vs control on the same monitors
  (`skills/mlops/model-monitoring`) against predeclared criteria before
  ramping.

```yaml
# k8s-flavored probes — the shape matters, not the platform
startupProbe:            # weight load can take minutes: give it time, don't kill-loop
  httpGet: { path: /health, port: 8000 }
  failureThreshold: 60
  periodSeconds: 10
readinessProbe:          # gate traffic on "loaded + warmed", not "process up"
  httpGet: { path: /health/ready, port: 8000 }
terminationGracePeriodSeconds: 120   # ≥ longest allowed stream, for drain
```

## Adapters in Serving: Hot-Swap vs Merge

| Aspect | Multi-LoRA over one base | Merged weights |
|--------|--------------------------|----------------|
| Memory | One base + megabyte-scale adapters | Full weight copy per variant |
| Rolling out a new variant | Load/swap an adapter in seconds | Full artifact deploy |
| Per-token overhead | Small but nonzero | None |
| Quantization | Quantized base + fp16 adapters (engine support varies — verify) | Quantize after merge, then re-eval |
| Fits when | Many tenants/tasks, fast iteration, shared base | Single model, tightest latency, simplest ops |

Merged artifacts follow the normal promotion path (register → eval → alias).
Hot-swapped adapters need the same rigor: pin adapter revisions in the serving
config and eval each adapter against its task set before it becomes routable.

## Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| Serving `main` / "latest" | The deploy changes when upstream pushes | Pin the revision at deploy; record it |
| Promoting a quantized model on fp16 evals | Quantization is a model change | Eval the exact quantized artifact |
| `max_model_len` = model maximum by reflex | KV per sequence balloons; concurrency collapses or OOMs | Budget context to the product need |
| Readiness = process up | Cold-weight requests, compile-time first tokens | Ready only after load + warmup |
| scp-ing a checkpoint onto the box | Untraceable prod artifact, no rollback | Deploy from registry alias + pinned revision |
| Open endpoint "because it's internal" | Free tokens for whoever scans it; key sprawl | Gateway with authn, limits, quotas |
| Rolling restart without drain | In-flight streams killed | Graceful drain ≥ longest stream |
| Tuning to leaderboard tokens/s | Optimizes someone else's workload | Measure TTFT/TPOT on your prompt/output mix |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "It's OpenAI-compatible, we can switch engines any time" | Compat surfaces differ at the edges (tool calls, logprobs, streaming details). Verify against your client code; don't assume. |
| "GPU utilization is only 40%, we have headroom" | Utilization measures compute; the ceiling is KV memory. Check memory and queue depth before adding load. |
| "The quantization page says under 1% quality loss" | On their benchmark. Your task's eval suite is the only claim that counts. |
| "We'll add the gateway after launch" | An unauthenticated endpoint *is* the launch. Abuse and cost surprises start on day one. |
| "Self-hosting is obviously cheaper than the API" | Only at steady utilization, counting engineering time. Model the economics per workload — `ai-engineer:ai-architector` owns the build-vs-buy call. |
| "Rollback is redeploying the old image" | A 20-minute image rebuild is not a rollback path during an incident. An alias/revision flip is. |

## Red Flags

- Nobody can name the exact revision the endpoint is serving
- No fp16 baseline registered behind a quantized prod artifact
- First request after a deploy takes 30+ seconds (no warmup; readiness lies)
- Concurrency limits chosen by trial-and-OOM instead of KV math
- Adapter files edited or merged directly on the serving host
- CPU fallback discovered from latency graphs, not from the deploy review
- Canary "looked fine" after an hour, with no predeclared comparison metrics

## Verification

- [ ] Artifact source + revision pinned and recorded; resolvable from the registry (`skills/mlops/experiment-tracking`)
- [ ] KV-cache budget computed from the model's real `config.json`; `max_model_len` and max concurrency documented with the arithmetic
- [ ] Quantized artifact (if any) passed the eval suite vs the fp16 baseline — pinned eval set, temperature 0
- [ ] Readiness gated on load + warmup; liveness separate; drain covers the longest allowed stream
- [ ] Rollback rehearsed: the previous revision flips back in minutes without a rebuild
- [ ] Canary plan states traffic fraction, predeclared metrics, and uses the same monitors as control
- [ ] Gateway enforces authn, rate limits, per-tenant quotas; exposure reviewed by `ai-engineer:ai-security-auditor`
- [ ] Latency/throughput targets stated as TTFT/TPOT on the real workload; tuning routed to `ai-engineer:ai-performance-engineer`

## Related Skills

- `references/serving-stack-matrix.md` — per-stack matrix, KV-cache worked example, degraded configs, per-deploy checklist
- `skills/mlops/experiment-tracking` — registry aliases and promotion gates that feed serving
- `skills/mlops/model-monitoring` — the monitors canaries and prod run on
- `skills/mlops/ml-pipelines` — CI/CD wiring that ends in the alias flip
- `skills/llm-apps/llm-api-patterns` — client-side call discipline against this endpoint
- `skills/finetuning/peft-lora` — producing and merging the adapters served here

Owning agent: `ai-engineer:mlops-engineer`.
