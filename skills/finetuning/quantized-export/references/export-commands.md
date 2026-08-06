# Export Commands and the Smoke-Test Skeleton

Command sequences per export format plus the gate script that
`skills/finetuning/quantized-export` requires before any artifact ships.
Quantization-library CLIs change flag names between minors — verify the current
invocation against each tool's docs (context7) and pin the versions in
`uv.lock`, because an export produced by an unpinned toolchain is not
reproducible.

## Contents

- [Capture the pre-export baseline first](#capture-the-pre-export-baseline-first)
- [Merging an adapter](#merging-an-adapter)
- [FP8 export](#fp8-export)
- [AWQ INT4 export](#awq-int4-export)
- [GGUF export with an imatrix](#gguf-export-with-an-imatrix)
- [Smoke-test script skeleton](#smoke-test-script-skeleton)
- [Artifact registration](#artifact-registration)

## Capture the pre-export baseline first

This step is not optional and it cannot be done afterwards. Once the checkpoint
is exported, the pre-export generations no longer exist to diff against, and
regenerating them later on a different library version compares two unknowns.

```bash
# Run BEFORE any export step. Same seed and decoding config are reused
# post-export — persisted here rather than re-typed, so the two runs are
# provably identical rather than nominally identical.
uv run python -m tools.generate \
    --model "$CHECKPOINT" \
    --prompts eval/goldens.jsonl \
    --temperature 0 --seed 3407 \
    --config-out artifacts/decode-config.json \
    --out artifacts/pre-export.jsonl
```

Keep `artifacts/decode-config.json` and `artifacts/pre-export.jsonl` next to
the artifact for its whole life: a re-export after a library bump diffs against
this same baseline, not against a fresh capture.

## Merging an adapter

Only when the merged topology was chosen. LoRA-only exports skip this entirely
and ship the adapter directory as-is.

```python
# uv add peft transformers
from peft import PeftModel
from transformers import AutoModelForCausalLM, AutoTokenizer

BASE, ADAPTER = "org/base-model", "artifacts/adapter"

# dtype is pinned explicitly: merging under a different dtype than training
# silently changes the merged weights, and the difference is small enough to
# pass a casual eyeball and fail a golden diff.
base = AutoModelForCausalLM.from_pretrained(BASE, torch_dtype="bfloat16", revision=BASE_REV)
merged = PeftModel.from_pretrained(base, ADAPTER).merge_and_unload()

merged.save_pretrained("artifacts/merged", safe_serialization=True)
AutoTokenizer.from_pretrained(BASE, revision=BASE_REV).save_pretrained("artifacts/merged")
```

Two things that go wrong here:

- **The tokenizer is forgotten.** Weights without a tokenizer produce
  correct-looking text with systematic spacing or unicode damage. Save it in
  the same step, as above, so the two cannot drift apart.
- **`safe_serialization=True` is dropped.** Pickle-format checkpoints are a P0
  supply-chain risk when they come from anywhere but your own pipeline; the
  plugin's standing rule is safetensors only. Route exceptions to
  `ai-engineer:ai-security-auditor`.

If the base model is gated or its default branch moves, pin `revision` to a
commit hash — `main` is not a version.

## FP8 export

The default wherever the target GPU has a native FP8 path and the serving
engine compiles for it.

```bash
# Calibration-free weight-only FP8 is the simplest path; activation-scaled
# variants need a calibration set drawn from the target task's own traffic,
# not a generic corpus, or the scales fit the wrong distribution.
uv run python -m tools.quantize \
    --model artifacts/merged \
    --scheme fp8-dynamic \
    --out artifacts/export-fp8
```

Verify the engine loads the scheme you produced *before* trusting the smoke
test's own load step to catch it — an engine that silently falls back to
dequantized bf16 will pass every golden and deliver none of the memory saving.
Check the reported weight footprint against the expected halving.

## AWQ INT4 export

For GPU generations without an FP8 path. Not for long-context, code, or math
workloads — see the Workload Overrides section of the parent skill.

```bash
# The calibration set is the quality lever: 128-512 samples drawn from the
# target task's real distribution. A generic web corpus calibrates the scales
# for text the model will never see, which is how "AWQ lost 4 points" happens.
uv run python -m tools.quantize \
    --model artifacts/merged \
    --scheme awq-int4 \
    --calibration data/calibration-task.jsonl \
    --calibration-samples 256 \
    --out artifacts/export-awq
```

Keep the output head and embeddings out of the INT4 cast when the tool allows
it. Quantizing the output head is the single most common cause of fluent,
semantically wrong generation after an otherwise clean INT4 export.

## GGUF export with an imatrix

For CPU, laptop, and edge targets served by llama.cpp-family runtimes.

```bash
# 1. Convert to a GGUF container at full precision.
python llama.cpp/convert_hf_to_gguf.py artifacts/merged \
    --outfile artifacts/model-f16.gguf --outtype f16

# 2. Build an importance matrix on task-representative text. Skipping this
#    step is the difference between a usable Q4 and a noticeably degraded one:
#    the imatrix tells the quantizer which weights carry the task's signal.
./llama.cpp/llama-imatrix -m artifacts/model-f16.gguf \
    -f data/calibration-task.txt -o artifacts/model.imatrix

# 3. Quantize using that matrix.
./llama.cpp/llama-quantize --imatrix artifacts/model.imatrix \
    artifacts/model-f16.gguf artifacts/model-Q4_K_M.gguf Q4_K_M
```

Quantization level is a quality/footprint dial, not a single right answer:
higher-bit K-quants degrade less and cost more disk. Pick the level with the
task evals, then keep the f16 GGUF as the re-quantization input.

## Smoke-test script skeleton

The gate itself. It must exit non-zero on mismatch, or it is documentation
rather than a gate.

```python
"""Compare pre-export and post-export generations over the golden set.

Lossless exports gate on byte-identical text; lossy (quantized) exports are
expected to differ token-for-token, so they gate on the task grader returning
the same verdict. Using byte equality for a quantized export produces a gate
that always fails and therefore always gets bypassed.
"""
import json, sys

def main(export_path: str, goldens: str, pre_export: str, *, lossy: bool) -> int:
    pre = {r["task_id"]: r for r in map(json.loads, open(pre_export))}
    decode = json.load(open("artifacts/decode-config.json"))
    model = load_in_target_runtime(export_path)   # the production engine, not a stand-in

    failures = []
    for row in map(json.loads, open(goldens)):
        post = model.generate(row["prompt"], **decode)
        before = pre[row["task_id"]]["completion"]
        ok = (
            grade(row, post) == grade(row, before) if lossy
            else post == before
        )
        if not ok:
            failures.append({"task_id": row["task_id"], "before": before, "after": post})

    json.dump(failures, open("artifacts/smoke-diff.json", "w"), indent=2)
    for f in failures:
        print(f"SMOKE FAIL {f['task_id']}", file=sys.stderr)
    return 1 if failures else 0

if __name__ == "__main__":
    raise SystemExit(main(*sys.argv[1:], lossy="--lossy" in sys.argv))
```

Wire it into the pipeline stage that produces the artifact, so an export that
fails its smoke test never reaches a registry
(`skills/mlops/ml-pipelines`). `artifacts/smoke-diff.json` is the handoff
evidence `skills/mlops/model-serving` expects with the artifact.

## Artifact registration

An export that is not registered cannot be rolled back to or reproduced.

```yaml
# Recorded with the artifact — see skills/mlops/experiment-tracking
artifact: support-summarizer-fp8
source_checkpoint: "runs/2f9c1a/checkpoint-1200"
promotion_report: "runs/2f9c1a/promotion-report.md"   # the PROMOTE that authorized this
topology: merged                 # or: lora-only
base_model:                      # required for lora-only; omit when merged
  repo: null
  revision: null
precision: fp8-dynamic
calibration_set: null            # required for AWQ; null for calibration-free schemes
tokenizer_bundled: true
chat_template_bundled: true
rollback_to: support-summarizer-bf16
smoke_test:
  goldens: "eval/goldens.jsonl@v4"
  mode: lossy                    # byte-match gate does not apply
  diff: "artifacts/smoke-diff.json"
  result: pass
library_versions:                # an unpinned toolchain makes this unreproducible
  quantizer: null
  runtime: null
```

The `rollback_to` field is the reason the bf16 artifact stays registered: a
rollback during an incident is an alias flip to an already-loadable artifact,
never a re-export.
