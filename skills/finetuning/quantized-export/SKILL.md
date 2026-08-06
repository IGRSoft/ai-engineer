---
name: quantized-export
description: >-
  Exports a promoted checkpoint for a target runtime: merged vs LoRA-only,
  format choice (FP8, AWQ INT4, GGUF), and the pre/post smoke test.
  Use when a promoted checkpoint needs exporting, when picking a quantization
  format for a device, or when an exported model fails its smoke test.
  Not serving config (model-serving).
---

# Quantized Export

You are here because `skills/finetuning/checkpoint-promotion` returned a
`PROMOTE` verdict and the weights now have to become a deployable artifact. A
checkpoint that cleared the promotion gate is still not deployed: it has to be
written out in the format its target runtime loads, and proven to still behave
after the write. A `REJECT` verdict never reaches this skill — export starts
only from a promoted checkpoint.

**Input:** a promoted checkpoint (or LoRA adapter plus its exact base-model
revision) and the target deployment surface — GPU class or CPU/edge target,
serving engine, and whether long-context, code, or math workloads are in scope.

**Output format:** an exported artifact in the chosen format, plus a smoke-test
diff comparing 3–5 golden outputs generated before and after the export under
identical deterministic sampling settings.

## Overview

Export is where two independent decisions get made and routinely conflated:
**what gets folded into the artifact** (merged weights vs. a standalone
adapter) and **at what numeric precision** (bf16, FP8, INT4-class, GGUF
levels). They are separate axes — you can ship a merged INT4 artifact or a
LoRA-only bf16 adapter — and treating them as one choice is how teams end up
with an artifact their serving stack cannot load.

The third thing this skill owns is the part everyone skips: an export bug does
not produce an error. It produces a loadable file that generates plausible
garbage. File-existence checks and a successful load prove nothing, which is
why the smoke test below is a gate rather than a suggestion.

Owned by `ai-engineer:ml-engineer`, with the serving-side handoff to
`ai-engineer:mlops-engineer`. This skill *produces* the artifact; running it
under an engine is `skills/mlops/model-serving`.

## When to Use

- A checkpoint passed promotion and needs to become a deployable artifact
- Choosing between a merged export and a LoRA-only adapter
- Picking a quantization format for a known target device or serving engine
- An exported model loads but produces garbled, truncated, or nonsensical output
- Re-exporting after a quantization-library or runtime version bump

**When NOT to use:**

- Deciding whether the checkpoint ships at all →
  `skills/finetuning/checkpoint-promotion` (this skill assumes `PROMOTE`)
- Choosing and sizing the serving engine, KV-cache budgets, adapter hot-swap,
  rollout and rollback → `skills/mlops/model-serving`
- Quantizing a model you did not train, purely to fit an existing deployment →
  `skills/mlops/model-serving` owns serving-time quantization
- Adapter mechanics during training (r, alpha, target_modules, merge semantics)
  → `skills/finetuning/peft-lora`
- Building the goldens the smoke test draws from → `skills/evals/eval-design`

## Merged vs LoRA-Only

This axis is about artifact topology, not precision. Pick it first — it
determines what you are even quantizing.

| | Merged | LoRA-only |
|---|---|---|
| Artifact size | Full weight copy per variant | Megabyte-scale adapter |
| Serve-time dependency | None — self-contained | Requires the exact base model revision |
| Multi-variant serving | One copy per variant | Many adapters over one base |
| Quantization | Quantize after merging, then re-evaluate | Quantized base + higher-precision adapter, engine-dependent |
| Picks when | Artifact portability and simplest ops matter most | Disk footprint or multi-tenant serving matters most |

The LoRA-only failure mode is worth stating plainly: **a mismatched base model
silently changes outputs.** Not an error, not a load failure — different
answers. If you ship LoRA-only, the base repo *and* its pinned revision are
part of the artifact contract and belong in the serving config
(`skills/mlops/model-serving`), recorded at deploy time.

## Format Map

Choose by what the target hardware and runtime actually support, verified
against the engine's current docs (context7) rather than a remembered support
matrix — format support moves faster than anything else in this stack.

| Target | Workload | Format |
|---|---|---|
| GPU with native FP8 support | Generic chat/instruction | FP8 |
| GPU with native FP8 support | Long-context, code, or math | FP8 or W8A8 — never INT4 |
| Older GPU generation, no FP8 path | Generic | AWQ INT4 |
| CPU, laptop, or edge via llama.cpp | Local serving | GGUF (Q4_K_M class) built with an imatrix |
| Any target, quality-first | Baseline for comparison | bf16 unquantized |

- **FP8 is the default wherever the hardware supports it natively.** It holds
  near-bf16 quality at roughly half the memory. "Supports it" means the GPU has
  a native FP8 path *and* the serving engine compiles for it — emulated FP8 is
  slower than the format you were trying to beat.
- **AWQ is the INT4 pick over GPTQ for new exports.** Activation-aware
  quantization protects salient channels, giving better accuracy retention at
  the same bit width with wider current tooling support.
- **GGUF optimizes footprint, not datacenter throughput.** Build it with an
  importance matrix (imatrix) computed on data resembling the target task; a
  GGUF quantized without one loses noticeably more quality at the same level.
- **Keep the bf16 artifact registered.** It is the rollback target and the
  input for re-quantization when the format landscape moves
  (`skills/mlops/experiment-tracking`).

## Workload Overrides

The Format Map is a default that does not survive every workload.
**Long-context, code, and math break at INT4.** Quantization error compounds
across long sequences and across the precise token-level reasoning those tasks
depend on, in a way short generic prompts never reveal. For any of those three
classes, stay on FP8 or W8A8 even when the hardware and the cost model both
argue for INT4.

- **Do not validate this with broad knowledge benchmarks.** They do not stress
  the failure mode. Measure with the actual task evals
  (`skills/evals/eval-design`) run *through the exported artifact*, because
  INT4 degradation shows up as dropped context, broken syntax, and arithmetic
  errors well before it moves a knowledge score.
- **If a task eval regresses after an INT4 export, change format — do not
  re-tune the recipe.** AWQ and GPTQ variants at the same bit width share the
  compounding-error failure mode; a different calibration set does not fix a
  precision floor.

## The Smoke Test

Mandatory for every export, with no exemption for a format that "should just
work". Run it as a gate that exits non-zero, not as a manual look.

1. **Load the artifact in its real target runtime.** The engine that will serve
   it in production — not a convenient framework that happens to read the file.
   Loader differences are exactly what this test exists to catch.
2. **Run 3–5 golden prompts through it**, pulled from the pinned eval golden
   set (`skills/evals/eval-design`), not a fresh ad-hoc set written today.
3. **Compare against the pre-export generation** for the same prompts under
   identical deterministic settings — greedy decoding, fixed seed, both
   persisted and reused rather than nominally re-specified.

The comparison rule depends on whether the export is lossy:

| Export | Gate |
|---|---|
| Lossless (bf16 merge, format conversion only) | **Byte-identical output. Any diff is a bug.** |
| Lossy (any quantization) | Byte match is expected to fail — gate on the task grader returning the same verdict on every golden |

### Failure signatures

Export bugs have recognizable shapes. Knowing them turns "the output looks
weird" into a diagnosis:

- **Chat-template mismatch** presents as garbled, run-on, or role-confused
  output. The template baked into the export differs from the one the
  checkpoint was trained and evaluated against, so turn boundaries and special
  tokens land in the wrong places.
- **Wrong quantization applied to the output head** presents as fluent but
  semantically nonsensical text. The rest of the network quantized cleanly; the
  head lost precision it needed. Keep the output head and embeddings at higher
  precision when the format allows it.
- **Missing or mis-sized adapter merge** presents as the *base* model's
  behavior — the fine-tune appears to have vanished, because effectively it
  did.
- **Tokenizer not exported alongside the weights** presents as correct-looking
  output with systematic spacing or unicode damage.

Re-run this gate on any quantization-library or runtime version bump, not just
after the first export. Runnable command sequences per format and a smoke-test
script skeleton are in `references/export-commands.md`.

## Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| Exporting a checkpoint that has not been promoted | Ships a model no gate approved | `skills/finetuning/checkpoint-promotion` first |
| Skipping the smoke test because the export "succeeded" | Export bugs produce loadable garbage, not errors | The gate above, exit-code enforced |
| Comparing pre/post outputs with different sampling settings | Every diff is unattributable | Persist seed and decoding config; reuse both runs |
| INT4 for a long-context, code, or math workload | Compounding error the generic benchmarks miss | FP8 or W8A8 per Workload Overrides |
| Choosing format from a benchmark blog post | Their workload, their hardware, their tolerance | Task evals through the exported artifact |
| LoRA-only shipped without pinning the base revision | Silent output changes when the base moves | Base repo + revision in the serving config |
| Discarding the bf16 artifact after quantizing | No rollback, no re-quantization input | Register bf16 as its own version |
| Smoke test run in a different framework than production | Loader-specific bugs pass unseen | Load in the real target runtime |

## Red Flags

- Nobody can name the promotion verdict that authorized this export
- Pre-export golden outputs were never captured, so there is nothing to diff against
- The exported artifact was quantized and evaluated only on the unquantized evals
- Chat template not pinned or not exported with the weights
- Adapter merged on the serving host rather than produced as a registered artifact
- "It loaded fine" used as the acceptance criterion
- Re-export after a library upgrade shipped without re-running the smoke test

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
- [ ] Handoff to `skills/mlops/model-serving` includes the smoke-test diff

## Related Skills

- `references/export-commands.md` — per-format command sequences, the smoke-test script skeleton, and the imatrix build
- `skills/finetuning/checkpoint-promotion` — the only valid upstream; a checkpoint without `PROMOTE` does not reach export
- `skills/mlops/model-serving` — runs the artifact this skill produces: engine choice, KV-cache math, hot-swap, rollout
- `skills/finetuning/peft-lora` — adapter mechanics and merge semantics during training
- `skills/evals/eval-design` — owns the goldens the smoke test draws from and the task evals the INT4 override requires
- `skills/mlops/experiment-tracking` — registering the artifact, its precision, and its rollback predecessor
- `skills/mlops/ml-pipelines` — automating export as a pipeline stage behind the promotion gate
