---
description: Read-only fine-tuning feasibility plan — ai-architector renders the prompt-vs-RAG-vs-finetune verdict, then data requirements, LoRA/QLoRA/DPO method choice, GPU memory math, eval gates, and a smoke-then-full launch plan. Never starts training.
argument-hint: [task: what the tuned model should do] [--data <path>] [--base <model-id>] [--target-gpu "<name / VRAM>"]
allowed-tools: Read, Glob, Grep, Bash
estimated-cost:
  min-tokens: 4000
  max-tokens: 18000
  model-distribution:
    opus: 40%
    sonnet: 60%
---

# Fine-Tuning Feasibility Plan
<!-- Updated: July 2026 -->

Turn "should we fine-tune?" into an evidence-backed plan — or an honest "no". The command gathers the project's real context (data on hand, current prompt/RAG stack, hardware), puts the method decision to `ai-engineer:ai-architector`, and only on a fine-tune verdict assembles the full plan: data requirements and curation gates, LoRA/QLoRA/DPO selection, GPU memory arithmetic, hyperparameter starting points, eval gates, and a smoke-then-full launch plan. Everything is planned; nothing is executed.

[Extended thinking: Most fine-tuning requests should not be fine-tuning requests — prompting or retrieval covers them at a fraction of the cost and rollback risk, which is why the architector's decision table runs first and a "don't fine-tune" verdict short-circuits the whole command. When the verdict is fine-tune, the plan's value is in being concrete about the unglamorous parts: how many curated examples the task class actually needs, whether the job fits the GPU that actually exists (probed, never assumed), which eval proves the adapter helped and which slice proves it didn't break everything else. The command is strictly read-only — it prints a plan the user saves; the ml-engineer executes it later inside a worktask, where the smoke-scale rule applies.]

## CRITICAL BEHAVIORAL RULES

You MUST follow these rules exactly. Violating any of them is a failure.

1. **Read-only — never start training.** No Write/Edit. Bash is for probes only (`nvidia-smi`, `wc -l` on found datasets, `uv tree`). Training invocations (`uv run python -m training.*`, `accelerate launch`, anything TRL) appear **inside the plan text** as commands for the executor — this command never runs them, not even "just the smoke run".
2. **Honor the verdict.** If `ai-engineer:ai-architector` returns "don't fine-tune", emit the short-form verdict output (cheaper alternative + measurable revisit trigger) and **STOP**. No data plan, no configs, no launch plan for a method that lost the decision.
3. **No invented GPU specs.** Probe `nvidia-smi`; when absent, use `--target-gpu` or ask the user for the training host's card/VRAM. Until real numbers exist, the memory math stays symbolic — never assume a card, never fabricate VRAM.
4. **No absolute prices or durations.** Duration classes (minutes / hours / days) and cost-driver formulas (GPU-hours × current rate, token volumes) only; rates get looked up at execution time, never recalled here.
5. **Numbers are starting points, not promises.** Dataset sizes are ranges by task class; r/alpha/LR/beta are sweep origins — label them as such in the plan.
6. **Volatile APIs are verified, not recalled.** TRL/PEFT argument names churn across minor versions — the plan instructs the executor to verify against current docs (context7) before running anything.
7. **Plan goes to stdout.** Print the complete plan in the response; the user saves it where they want it. Never write a plan file.
8. **Never enter plan mode.** This command IS the procedure — execute it.

## Usage

```bash
# Feasibility plan for a behavior target
/ai-engineer:finetune-plan "make the support bot answer in our house style"

# Point at the data you already have
/ai-engineer:finetune-plan "emit strict JSON audit summaries" --data data/audits/

# Name a candidate base model (revision gets pinned in the plan)
/ai-engineer:finetune-plan "prefer concise, non-sycophantic answers" --base <org/model-id>

# Declare the training host when this box has no GPU
/ai-engineer:finetune-plan "domain assistant for internal CRM" --target-gpu "1x 24 GB"
```

## Options

| Option | Default | Effect |
|--------|---------|--------|
| `task` | — (required) | What the tuned model should do, in the user's words. Drives the task-class sizing and the architector's decision framing. |
| `--data <path>` | auto-discover | Where existing candidate training data lives (JSONL, logs, exports). Without it, the command globs `data/**` and reports what it finds. |
| `--base <model-id>` | recommend one | Candidate base model. The plan pins a revision and notes "verify ID against current provider/hub docs — never from memory". |
| `--target-gpu "<spec>"` | probe `nvidia-smi` | Training-host hardware when it differs from this machine (e.g. `"1x 24 GB"`, `"2x 80 GB"`). Used only for the memory-math instantiation. |

## Workflow

### Phase 0: Context Gathering (read-only probes)

Collect and **print a "Context Detected" block** before any delegation:

1. **Task framing** — restate the target behavior in one sentence from the args (missing → Error Handling).
2. **Data inventory** — Glob `data/**/*.jsonl`, `data/ledger/*.yaml`, `*.dvc`, `--data` path; count records on hits (`wc -l`); note format (messages-schema vs raw logs) and whether a provenance ledger exists.
3. **Current prompt/RAG setup** — `prompts/` dir and versioned prompt files; Grep `pyproject.toml`/`uv.lock` for `anthropic|openai|litellm|langchain|llama-index|chromadb|qdrant|pgvector|faiss`; note what the cheaper layers already do.
4. **Eval assets** — `evals/` harnesses, golden-set manifests, judge configs; no eval set is a planning input, not a blocker.
5. **Training stack** — `torch|transformers|peft|trl|accelerate|bitsandbytes` in `uv.lock`.
6. **GPU probe** — `nvidia-smi --query-gpu=name,memory.total --format=csv,noheader`. Absent binary → record "no CUDA on this box", note the two-host workflow (Mac/MPS smoke loop, Linux/CUDA full run per `skills/finetuning/training-optimization`), and use `--target-gpu` or ask (Rule 3). Never a failure.

### Phase 1: Method Verdict

**Use Task tool with subagent_type="ai-engineer:ai-architector"** (model: opus, effort: xhigh)
Prompt: "Feasibility consultation — do NOT implement anything. Task: {task}. Detected context: {data inventory, prompt/RAG stack, eval assets, hardware}. Apply your Prompt vs RAG vs Fine-tune vs Hybrid decision table and return the compressed form: decision, the 2-3 criteria that decided it with project inputs, each rejected option + the single criterion that killed it, the eval gate that would validate the bet, and measurable revisit-when triggers. If the honest answer is 'don't fine-tune', say so plainly with the cheaper alternative."

- Verdict **don't fine-tune** → emit the short-form output (Output Format B) and STOP (Rule 2).
- Verdict **fine-tune** or **hybrid** (e.g. RAG for facts + adapter for form) → Phase 2.

### Phase 2: Plan Assembly (fine-tune / hybrid verdicts only)

1. **Data requirements** — per `skills/finetuning/dataset-curation`: messages-format JSONL (one system-turn policy, strict role alternation, completion-only masking); size range by task class (style/persona ~200–2k · format enforcer ~500–5k · domain assistant ~1k–20k · DPO pairs ~2k–20k); gap = range minus curated inventory; the eight curation gates the data must pass (collect→normalize→dedupe→decontaminate→scrub→license→split→version, fail-closed on scrub/license).
2. **Method selection** — per `skills/finetuning/peft-lora` and `skills/finetuning/preference-tuning`: LoRA (behavior/format/domain from gold outputs) vs QLoRA (same job under the VRAM budget from step 3) vs SFT→DPO (directional "better vs worse" targets — needs a competent SFT baseline first). Include the config starting point for the scenario (r, alpha ≈ 2r, target_modules, dropout).
3. **GPU memory budget** — symbolic formulas per `skills/finetuning/training-optimization` `references/gpu-memory-math.md` (weights + gradients + optimizer states + activations + ≥10–15% headroom), instantiated **only** against probed or declared hardware; verdict fits / tight / doesn't-fit plus which fit-ladder rungs to plan (accumulation, checkpointing, QLoRA). No hardware known → keep it symbolic and mark "instantiate on the training host".
4. **Hyperparameter starting points** — LR (~2e-4 LoRA-class, sweep), cosine schedule + warmup, effective batch = micro × accumulation (retune LR when it changes), fixed seed; DPO: beta ~0.1 swept against held-out win rate, never training loss. All labeled sweep origins; TRL/PEFT arg names to be verified via context7 (Rule 6).
5. **Eval plan + success criteria** — per `skills/evals/eval-design`: baseline run on the pinned eval set **before** training (temperature 0, eval-set version recorded); target metrics by task type with explicit pass thresholds; a **general-capability regression slice** that must not regress (the catastrophic-forgetting detector); gate wiring per `skills/evals/regression-gates`; subjective quality via `skills/evals/llm-judge`.
6. **Launch plan** — two runs, both as printed commands: **smoke** (capped `max_steps`, ~256-record subsample, fixed seed; duration class: minutes; success = falling loss, no NaN, sane trainable-param %, peak memory recorded vs estimate) then **full** (command + dataset version + CUDA host; duration class + cost drivers: GPU-hours ≈ steps × sec/step, spend scales with params, sequence length, epochs — no absolute prices, Rule 4).

### Phase 3: Emit

Print the plan (Output Format A) to stdout. Close with the execution route: `ai-engineer:ml-engineer` runs it inside a worktask DV (smoke-scale rule applies); harness build → `ai-engineer:ai-test-generator`.

## Output Format

**A — fine-tune / hybrid verdict:**

```markdown
## Fine-Tuning Feasibility Plan — {task}

**Verdict:** FINE-TUNE ({LoRA | QLoRA | SFT→DPO}) | HYBRID ({RAG for facts + adapter for form}) — per ai-engineer:ai-architector
**Context detected:** data {inventory summary} · prompt/RAG {stack} · evals {present/absent} · hardware {probed | declared | none → two-host}

### Method Decision
{decision, deciding criteria with project inputs, rejected options + killing criterion}

### Data Plan
| Aspect | Requirement |
|--------|-------------|
| Format | messages JSONL, {system-turn policy}, completion-only masking |
| Size (task class: {class}) | {range} — starting range, not a target |
| On hand / gap | {counts} / {gap + collection source} |
| Curation gates | collect→normalize→dedupe→decontaminate→scrub→license→split→version (fail-closed) |

### Training Method & Config
{LoRA/QLoRA/DPO rationale + starting config: r, alpha, target_modules, dropout — sweep origins}

### GPU Memory Budget
{component table instantiated vs {hardware}, or symbolic + "instantiate on training host"}
Fit verdict: {fits with headroom | tight — ladder rungs {N} | doesn't fit — QLoRA/sharding}

### Hyperparameter Starting Points
{LR, schedule, effective batch, seed, (beta) — labeled starting points; verify TRL/PEFT args via context7}

### Eval Plan & Success Criteria
Baseline: {eval set + version, temperature 0} · Targets: {metric ≥ threshold, …}
Regression slice: {general-capability slice — must not regress} · Gate: skills/evals/regression-gates

### Launch Plan (commands for the executor — NOT run by this command)
Smoke: `{command}` — {success criteria}; duration class: minutes
Full:  `{command}` — host {host}, dataset {version}; duration class {hours|days}; cost drivers {formula}

### Risks & Open Questions
{data gaps, license unknowns, unverified hardware, contested criteria}
```

**B — don't-fine-tune verdict (then STOP):**

```markdown
## Fine-Tuning Feasibility Plan — {task}

**Verdict: DON'T FINE-TUNE** — {prompting | RAG | hybrid-without-tuning} covers this cheaper.
**Why:** {2-3 deciding criteria from the decision table, with project inputs}
**Do instead:** {concrete path + owning skill/agent, e.g. skills/llm-apps/rag-systems via ai-engineer:llm-engineer}
**Revisit when:** {measurable trigger — e.g. pinned eval set vN proves the cheaper layer's ceiling}
```

## Error Handling

### No task description
```
Note: finetune-plan needs a task description.
Usage: /ai-engineer:finetune-plan "what the tuned model should do" [--data <path>]
```

### No candidate data found
Not fatal — the plan includes a collection step sized by task class, and the ledger/consent requirements it must meet. If the honest range for the task class exceeds what can plausibly be curated, say so — that evidence feeds the architector and may flip the verdict to "don't fine-tune".

### `nvidia-smi` absent and no `--target-gpu`
Not a failure (Rule 3): note "no CUDA detected", keep the memory math symbolic, plan the Mac/MPS smoke loop + CUDA full run, and ask the user for the training host's specs before the full-run section can be instantiated.

### `ai-engineer:ai-architector` dispatch fails
Apply the decision table inline from `agents/ai-architector.md § Decision Frameworks`, mark the verdict **PROVISIONAL (architector unavailable)**, and recommend re-running for the reviewed verdict before anyone collects data.

### context7 unavailable
Proceed, but stamp every volatile fact (model IDs, TRL/PEFT arg names, quantization support) as UNVERIFIED in the plan.

## See Also

- `skills/finetuning/dataset-curation` — formats, size ranges by task class, the eight curation gates
- `skills/finetuning/peft-lora` — LoRA/QLoRA configs, adapter lifecycle, before/after eval discipline
- `skills/finetuning/preference-tuning` — SFT-only vs DPO/ORPO/KTO ladder, pair building, beta mechanics
- `skills/finetuning/training-optimization` (+ `references/gpu-memory-math.md`) — memory model, fit ladder, smoke-scale rule
- `skills/evals/eval-design` / `skills/evals/regression-gates` — eval sets, thresholds, CI gating for the success criteria
- `/ai-engineer:deploy-check` — readiness gate when the resulting artifact heads to serving
- `ai-engineer:ml-engineer` — executes this plan (worktask DV, smoke-scale); `ai-engineer:ai-test-generator` — builds the eval harness

If the verdict is "don't fine-tune", that IS the deliverable — say it plainly instead of padding a plan nobody should execute.
