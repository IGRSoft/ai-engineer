---
name: model-serving
description: >-
  Deploy and size self-hosted LLM endpoints: engine choice (Ollama, vLLM,
  TGI, Triton, llama.cpp) vs managed API, pinned artifact to
  OpenAI-compatible endpoint behind a gateway, serve-time quantization,
  KV-cache capacity math, LoRA hot-swap vs merge, and probes, warmup, drain,
  canary, and rollback. Use when deploying a model or adapter, planning GPU
  capacity, or reviewing a serving config before rollout.
---

# Model Serving

Serving turns a model artifact into a dependency with an SLO. LLM serving is
dominated by GPU memory (weights + KV cache), long-lived streams, and
multi-gigabyte load times. Every deploy answers four questions: which
artifact (pinned revision), which runtime (engine + config), which surface
(OpenAI-compatible endpoint), which guardrails (gateway, probes, rollback).
Get the memory math and rollback path right first; route deep
latency/throughput work to `ai-engineer:ai-performance-engineer`.

**Not this skill:**

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

Capabilities shift fast — verify against each engine's current docs
(context7); the filled-in per-stack matrix is in
`references/serving-stack-matrix.md`. Self-hosting only beats an API at
steady utilization counting engineering time; `ai-engineer:ai-architector`
owns that build-vs-buy call.

| Dimension | Question to ask | Why it decides |
|-----------|-----------------|----------------|
| Batching model | Continuous batching or request-at-a-time? | Dominates throughput under concurrent load |
| Quantization formats | Which of GPTQ/AWQ/GGUF/FP8-class load natively? | Sets the memory floor and hardware fit |
| Multi-LoRA | Many adapters over one base at runtime? | One GPU can serve N fine-tunes |
| OpenAI-compat surface | `/v1/chat/completions` incl. streaming + tool calls? | Client portability, gateway reuse |
| Hardware span | CUDA-only, or CPU/Metal/ROCm too? | Dev/prod parity; laptop reproduction |
| Ops profile | Single binary vs K8s-native vs model-repo daemon? | Must match the team's capacity to operate it |

No `nvidia-smi`? You are on the CPU/MPS rung: GGUF via Ollama/llama.cpp at
an order of magnitude lower throughput — plan capacity for it explicitly. A
silent CPU fallback in prod is an incident.

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

The gateway is part of the deployment, not later hardening: without authn,
rate limits, and per-tenant quotas, an OpenAI-compatible endpoint is free
compute for whoever finds it. Route exposure review to
`ai-engineer:ai-security-auditor`.

## Quantization for Serving

Quantization trades memory (and often latency) for quality. A quantized
artifact is a different model — eval it as one.

| Format | Targets | Mechanism notes |
|--------|---------|-----------------|
| GPTQ | GPU weight-only, int4-class | Post-training, calibration-set based; broad engine support |
| AWQ | GPU weight-only, int4-class | Activation-aware: protects salient channels; similar footprint to GPTQ |
| GGUF | llama.cpp/Ollama family; CPU/Metal-first | Container format with graded quant levels (higher-bit = safer) |
| FP8 / quantized KV | Newer GPUs; engine-dependent | Halves weight or KV bytes; hardware + engine support varies — verify |

Rules:

- Promote only after the exact quantized artifact passes the eval suite
  (pinned eval-set version, temperature 0) against the fp16 baseline;
  published "negligible loss" claims don't transfer to your task.
- Register the quantized artifact as its own version; keep the fp16 version
  registered for rollback and re-quantization.
- Expect non-uniform degradation: instruction-following, code, and math
  degrade before fluency does. Slice the evals accordingly.

## Capacity Planning: the KV Cache Is the Ceiling

GPU memory, not compute, is usually the limit (40% GPU utilization is not
headroom). Weights are fixed; the KV cache grows with every concurrent
sequence and every token of context:

```
kv_bytes_per_token = 2 × n_layers × n_kv_heads × head_dim × bytes_per_element
                     ↑ K and V        ↑ GQA: num_key_value_heads, not attention heads
kv_per_sequence    = kv_bytes_per_token × context_len
concurrency_max    ≈ (vram − weights − runtime_overhead) / kv_per_sequence
```

Read `n_layers` / `n_kv_heads` / `head_dim` from the model's `config.json`
rather than assuming the shape. Levers, in order of cheapness: cap `max_model_len` to
the product's real context need; cap max concurrent sequences; quantize
weights; quantize the KV cache (engine-dependent). Continuous-batching engines
with paged KV allocate by actual tokens used, so real concurrency beats the
worst-case math when typical requests are short.

Worked example and degraded single-GPU/CPU configs:
`references/serving-stack-matrix.md`.

## Operational Hardening

- **Liveness ≠ readiness.** Ready only after weights load and warmup
  completes; a TCP-open port with cold weights serves 30-second first tokens.
- **Warmup**: run representative requests (typical + max context) before
  joining the pool — triggers lazy compilation/graph capture and page-in.
- **Graceful drain**: on shutdown, stop accepting, let in-flight streams
  finish (bounded), then exit. Rolling restarts without drain kill mid-stream.
- **Rollback = revision flip.** The previous artifact stays loadable;
  rolling back repoints the alias/config in minutes instead of rebuilding an
  image.
- **Canary by traffic fraction**: route a small percentage to the new
  revision; compare canary vs control on the same monitors
  (`skills/mlops/model-monitoring`) against predeclared metrics before
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
| Assuming OpenAI-compat means drop-in | Tool calls, logprobs, streaming differ at the edges | Exercise the real client code against the engine |

## Verification

Run the per-deploy checklist in
[`references/serving-stack-matrix.md`](references/serving-stack-matrix.md#per-deploy-verification-checklist).

## Related Skills

- `skills/mlops/experiment-tracking` — registry aliases and promotion gates that feed serving
- `skills/mlops/ml-pipelines` — CI/CD that ends in the alias flip
- `skills/finetuning/peft-lora` — producing and merging the adapters served here

Owning agent: `ai-engineer:mlops-engineer`.
