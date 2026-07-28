# Serving Stack Matrix

Companion deep dive for `skills/mlops/model-serving`. Rows are the dimensions
worth checking; cells describe mechanisms as of authoring. Engine capabilities
move quickly — verify every load-bearing cell against the engine's current
docs (context7) before committing a deployment.

## Per-Stack Matrix

| Dimension | vLLM | TGI | Ollama | Triton | llama.cpp server |
|---|---|---|---|---|---|
| Batching model | Continuous batching, paged KV cache | Continuous batching | Request queue; limited configurable parallelism | Via backend (TensorRT-LLM / vLLM backend): in-flight batching | Slot-based parallelism, modest concurrency |
| Quantization formats | GPU weight formats (GPTQ/AWQ/FP8-class; per-release support) | GPU weight formats (GPTQ/AWQ/bitsandbytes-class; per-release) | GGUF quant levels | Backend toolchain (e.g. TensorRT-LLM quantization) | GGUF quant levels |
| Multi-LoRA | Runtime multi-adapter over one base | Adapter support narrower — verify | Model variants (Modelfile), not hot multi-LoRA | Backend-dependent | Typically pre-merged; limited runtime adapters |
| Streaming | SSE token streaming | SSE token streaming | Streaming API | Frontend/backend-dependent | SSE token streaming |
| OpenAI-compat surface | Chat/completions server; tool-call + logprob coverage varies — verify | Compat layer over the native API — verify coverage | Chat/completions subset | Not native; pair with a compat frontend | Chat/completions subset |
| GPU/CPU span | CUDA-first (other accelerators vary — verify) | CUDA-first | CPU / Apple Metal / CUDA | NVIDIA-centric | CPU / Metal / CUDA; smallest footprint |
| Ops profile | Python service per model; K8s-friendly; rich metrics | Launcher + container; HF ecosystem alignment | Single binary; dev-grade defaults; model-library UX | Model-repo daemon; fleet features (ensembles, metrics); heaviest to run | Single binary, minimal deps |
| Sweet spot | GPU throughput under real concurrency | HF-stack shops wanting supported serving | Local dev, demos, single-box internal tools | Many models/frameworks under one serving tier | CPU-only, edge, minimal installs |

## Per-Stack Operational Notes

**vLLM** — throughput by design: continuous batching admits new sequences
every scheduler step; paged KV allocates by actual tokens, not worst case.
Plan one engine process per base model; multi-LoRA lets that process serve
many fine-tunes. Watch KV-cache utilization, preemptions, and queue depth —
not GPU compute percentage.

**TGI** — the same goals inside the Hugging Face ecosystem, with a strong
container story. If your artifacts, tokenizers, and deploy flow are HF-native,
that integration is the argument. Verify current quantization and
compat-surface coverage per release.

**Ollama** — the dev-loop tool: pull, run, chat in minutes on CPU/Metal/CUDA.
A Modelfile pins a base plus params as a named variant. Defaults favor a
single user; parallelism and context are configurable, but it is not built to
be a high-QPS prod tier — promote the same weights to a throughput engine for
load.

**Triton** — for fleets: one serving tier hosting LLMs next to non-LLM models
(rankers, embedders, vision) across frameworks, with ensembles and uniform
metrics. LLM specifics arrive via backends (TensorRT-LLM, vLLM backend).
Highest operational surface — adopt for fleet reasons, never for one model.

**llama.cpp server** — the degraded-mode and edge workhorse: one binary, GGUF
weights, runs anywhere including CPU-only hosts. The right floor when CUDA is
absent; set tokens/s expectations accordingly and say "CPU" in the capacity
plan.

## KV-Cache Sizing: Worked Example

Symbols come from the model's `config.json` — read them, never assume:

```
L    = num_hidden_layers
H_kv = num_key_value_heads         # GQA: fewer than attention heads; MQA: 1
D    = head_dim                    # often hidden_size / num_attention_heads
B    = bytes per element           # 2 for fp16/bf16 KV; 1 for fp8/int8 KV
C    = served context length       # the max_model_len you configure, not the model max
S    = concurrent sequences

per_token_kv = 2 × L × H_kv × D × B          # ×2 for K and V
per_seq_kv   = per_token_kv × C
kv_budget    = VRAM − weights_bytes − runtime_overhead
S_max        ≈ kv_budget / per_seq_kv
```

Hypothetical shape (illustrative arithmetic only): L=32, H_kv=8, D=128,
fp16 KV (B=2):

```
per_token_kv = 2 × 32 × 8 × 128 × 2 = 131,072 B = 128 KiB per token
C = 8192  ⇒  per_seq_kv = 128 KiB × 8192 = 1 GiB per full-length sequence

7B-class weights at 2 B/param ≈ 14 GB; runtime overhead ≈ 2 GB
24 GB device: kv_budget ≈ 24 − 14 − 2 = 8 GB  ⇒  S_max ≈ 8 full-context sequences
int4-quantized weights ≈ 4–5 GB  ⇒  kv_budget ≈ 17 GB  ⇒  S_max ≈ 17
halve C to 4096  ⇒  per_seq_kv 0.5 GiB  ⇒  S_max doubles again
```

Reading the result:

- The ceiling is arithmetic, not vibes — derive `max_model_len` and max
  sequences from this math, then validate under load.
- Paged-KV engines allocate by *actual* tokens: if typical requests use a
  quarter of C, effective concurrency is roughly 4× the worst-case S_max.
- KV quantization (B: 2 → 1) doubles capacity at some quality cost — eval it
  like any other quantization change before promoting.
- GQA is why modern models serve cheaply: H_kv ≪ attention heads shrinks the
  cache linearly.

## Degraded Configurations

**Single small GPU** (dev/staging, budget prod):

- Quantize weights (AWQ/GPTQ int4-class) to reclaim VRAM for KV
- Cap `max_model_len` to the product's real need; cap `max_num_seqs` from the math
- Prefer a smaller model at higher precision over a larger model squeezed to
  its last gigabyte — leave headroom for spikes and fragmentation
- Enable chunked prefill / prefix caching where the engine offers them (verify docs)

**CPU-only** (no `nvidia-smi` anywhere):

- llama.cpp server or Ollama with GGUF at a mid quant level; threads ≈ physical cores
- Single-digit concurrency; tokens/s roughly two orders below GPU serving —
  publish the expectation, don't let users discover it
- Fine for internal tools, batch jobs, and functional tests of the serving
  path; never a silent stand-in for a GPU tier — the capacity plan must say "CPU"

**Apple Silicon dev box** (MPS/Metal):

- Ollama/llama.cpp use Metal automatically; good for correctness checks of
  prompts, merged adapters, and client integration against an OpenAI-compatible
  surface
- Laptop throughput predicts nothing about the CUDA tier — re-measure on the
  target hardware before making capacity claims

## Per-Deploy Verification Checklist

- [ ] Engine + version recorded; serving config versioned in git next to the code
- [ ] Model source + revision pinned (registry alias resolved and logged at deploy)
- [ ] `config.json`-derived KV math attached to the deploy PR (L, H_kv, D, B, C, S_max)
- [ ] Quantized artifact eval'd vs the fp16 baseline on the pinned eval set, temperature 0
- [ ] Warmup requests issued before readiness; first-token latency spot-checked
- [ ] Streaming verified end-to-end through the gateway (no buffering, sane backpressure)
- [ ] OpenAI-compat surface exercised by the actual client code (tools/logprobs if used)
- [ ] Rollback rehearsed: the previous revision flips back without an image rebuild
- [ ] Load test at expected concurrency + context mix; TTFT/TPOT recorded as the baseline
- [ ] Monitors live before ramp (`skills/mlops/model-monitoring`)
