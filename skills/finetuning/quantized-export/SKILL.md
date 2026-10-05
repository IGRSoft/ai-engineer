---
name: quantized-export
description: >-
  Export a promoted checkpoint for its target runtime: merged vs LoRA-only,
  format choice (FP8, AWQ INT4, GGUF), and the pre/post smoke test. Use when
  a checkpoint has a PROMOTE verdict and needs exporting, when picking a
  quantization format for a device, or when an exported model fails its
  smoke test. Not serving config (model-serving).
---

# Quantized Export

Turns a checkpoint that `skills/finetuning/checkpoint-promotion` marked
`PROMOTE` into a deployable artifact, and proves it still behaves after the
write. A `REJECT` checkpoint never reaches this skill.

**Input:** a promoted checkpoint (or LoRA adapter plus its exact base-model
revision) and the target deployment surface — GPU class or CPU/edge target,
serving engine, and whether long-context, code, or math workloads are in scope.

**Output:** an exported artifact in the chosen format, plus a smoke-test diff
comparing 3–5 golden outputs generated before and after the export under
identical deterministic sampling settings.

Two separate axes get decided here — what is folded into the artifact (merged
vs adapter) and the numeric precision. Export bugs rarely error; they produce a
loadable file that generates plausible garbage, so a successful load proves
nothing and the smoke test is a gate.

Owned by `ai-engineer:ml-engineer`; serving-side handoff to
`ai-engineer:mlops-engineer`.

**Not this skill:**

- Whether the checkpoint ships → `skills/finetuning/checkpoint-promotion`
- Engine choice and sizing, KV-cache, adapter hot-swap, rollout, and
  serve-time quantization of a model you did not train →
  `skills/mlops/model-serving`
- Adapter mechanics during training (r, alpha, target_modules) →
  `skills/finetuning/peft-lora`
- Building the goldens the smoke test draws from → `skills/evals/eval-design`

## Merged vs LoRA-Only

Artifact topology, independent of precision. Pick it first — it determines
what you are quantizing.

| | Merged | LoRA-only |
|---|---|---|
| Artifact size | Full weight copy per variant | Megabyte-scale adapter |
| Serve-time dependency | None — self-contained | Requires the exact base model revision |
| Multi-variant serving | One copy per variant | Many adapters over one base |
| Quantization | Quantize after merging, then re-evaluate | Quantized base + higher-precision adapter, engine-dependent |
| Picks when | Artifact portability and simplest ops matter most | Disk footprint or multi-tenant serving matters most |

A mismatched base model silently changes outputs — no load failure, just
different answers. For LoRA-only, the base repo *and* its pinned revision are
part of the artifact contract and go in the serving config
(`skills/mlops/model-serving`).

## Format Map

Verify support against the engine's current docs (context7), not a remembered
matrix — format support moves fast.

| Target | Workload | Format |
|---|---|---|
| GPU with native FP8 support | Generic chat/instruction | FP8 |
| GPU with native FP8 support | Long-context, code, or math | FP8 or W8A8 — not INT4 |
| Older GPU generation, no FP8 path | Generic | AWQ INT4 |
| CPU, laptop, or edge via llama.cpp | Local serving | GGUF (Q4_K_M class) built with an imatrix |
| Any target, quality-first | Baseline for comparison | bf16 unquantized |

- **FP8 is the default where the hardware supports it natively** — near-bf16
  quality at about half the memory. Native means the GPU has an FP8 path *and*
  the engine compiles for it; emulated FP8 is slower than what it replaces.
- **AWQ over GPTQ for new INT4 exports** — better accuracy retention at the
  same bit width, wider current tooling.
- **GGUF optimizes footprint, not datacenter throughput.** Build it with an
  imatrix computed on task-like data; without one it loses noticeably more
  quality at the same level.
- **Keep the bf16 artifact registered** as the rollback target and
  re-quantization input (`skills/mlops/experiment-tracking`).

## Workload Overrides

Long-context, code, and math break at INT4: quantization error compounds over
long sequences and precise token-level reasoning in ways short generic prompts
don't reveal. For these, stay on FP8 or W8A8 even when hardware and cost argue
for INT4.

- Validate with the actual task evals (`skills/evals/eval-design`) run
  through the exported artifact, not broad knowledge benchmarks — INT4
  degradation shows up as dropped context, broken syntax, and arithmetic
  errors before it moves a knowledge score.
- If a task eval regresses after an INT4 export, change format rather than
  re-tuning the recipe. AWQ and GPTQ at the same bit width share the failure
  mode; a new calibration set does not fix a precision floor.

## The Smoke Test

Required for every export, including formats that "should just work". Run it
as a gate that exits non-zero, not a manual look. Capture the pre-export
generations *before* exporting — afterwards there is no baseline to diff.

1. **Load the artifact in its real target runtime** — the production engine,
   not a framework that happens to read the file. Loader differences are what
   this catches.
2. **Run 3–5 golden prompts** from the pinned eval golden set
   (`skills/evals/eval-design`), not an ad-hoc set.
3. **Compare against the pre-export generation** under identical
   deterministic settings — greedy decoding, fixed seed, both persisted and
   reused rather than re-specified.

| Export | Gate |
|---|---|
| Lossless (bf16 merge, format conversion only) | Byte-identical output; any diff is a bug |
| Lossy (any quantization) | Grader returns the same verdict on every golden (byte match is expected to fail) |

### Failure signatures

- **Chat-template mismatch** → garbled, run-on, or role-confused output; the
  exported template differs from the one trained and evaluated against.
- **Output head quantized too aggressively** → fluent but semantically
  nonsensical text. Keep output head and embeddings at higher precision when
  the format allows.
- **Missing or mis-sized adapter merge** → the *base* model's behavior; the
  fine-tune has vanished.
- **Tokenizer not exported with the weights** → correct-looking output with
  systematic spacing or unicode damage.

Re-run the gate on any quantization-library or runtime version bump. Per-format
command sequences, the baseline capture, and a smoke-test script skeleton are
in `references/export-commands.md`.

## Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| Exporting a checkpoint that has not been promoted | Ships a model no gate approved | `skills/finetuning/checkpoint-promotion` first |
| Skipping the smoke test because the export "succeeded" | Export bugs produce loadable garbage, not errors | The gate above, exit-code enforced |
| Comparing pre/post outputs with different sampling settings | Every diff is unattributable | Persist seed and decoding config; reuse both runs |
| INT4 for a long-context, code, or math workload | Compounding error the generic benchmarks miss | FP8 or W8A8 per Workload Overrides |
| Choosing format from a benchmark blog post | Their workload, hardware, and tolerance | Task evals through the exported artifact |
| LoRA-only shipped without pinning the base revision | Silent output changes when the base moves | Base repo + revision in the serving config |
| Discarding the bf16 artifact after quantizing | No rollback, no re-quantization input | Register bf16 as its own version |
| Smoke test run in a different framework than production | Loader-specific bugs pass unseen | Load in the real target runtime |
| Adapter merged on the serving host | No registered, smoke-tested artifact | Merge here, register the result |

## Verification

- [ ] Upstream `PROMOTE` verdict recorded, with a link to the promotion report
- [ ] Merged vs LoRA-only chosen deliberately; if LoRA-only, base repo and revision pinned in the serving config
- [ ] Format chosen against verified current engine support, not a remembered matrix
- [ ] Long-context/code/math workloads kept off INT4, or the exception justified by task evals through the artifact
- [ ] Pre-export goldens generated and persisted with the exact decoding config and seed
- [ ] Smoke test run in the real target runtime; lossless exports byte-match, lossy exports match on grader verdict
- [ ] Tokenizer and chat template exported alongside the weights and verified present
- [ ] bf16 artifact retained and registered for rollback and re-quantization (`skills/mlops/experiment-tracking`)
- [ ] Artifact registered with its source checkpoint, quantization method, and library versions
- [ ] Smoke test re-run after any quantization-library or runtime upgrade
- [ ] Handoff to `skills/mlops/model-serving` includes the smoke-test diff

## Related Skills

- `references/export-commands.md` — per-format commands, baseline capture, imatrix build, smoke-test skeleton, artifact registration
- `skills/finetuning/checkpoint-promotion` — the only valid upstream
- `skills/mlops/model-serving` — runs the artifact this skill produces
- `skills/finetuning/peft-lora` — adapter mechanics and merge semantics during training
- `skills/evals/eval-design` — the goldens and the task evals the INT4 override requires
- `skills/mlops/experiment-tracking` — registering the artifact, its precision, and its rollback predecessor
- `skills/mlops/ml-pipelines` — automating export as a pipeline stage behind the promotion gate
