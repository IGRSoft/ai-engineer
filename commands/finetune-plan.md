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

Turn "should we fine-tune?" into an evidence-backed plan or an honest "no". Gather the project's real context (data on hand, current prompt/RAG stack, eval assets, hardware), put the method decision to `ai-engineer:ai-architector`, and only on a fine-tune or hybrid verdict assemble the plan: data requirements, method and config, GPU memory math, hyperparameter starting points, eval gates, launch, promotion, and export. Most requests are better served by prompting or retrieval, which is why the verdict runs first and can end the command.

## CRITICAL BEHAVIORAL RULES

1. **Read-only; never start training.** No Write/Edit. Bash is for probes only (`nvidia-smi`, `wc -l` on found datasets, `uv tree`). Training commands (`uv run python -m training.*`, `accelerate launch`, TRL scripts) appear only as text in the plan for the executor, including the smoke run.
2. **Honor the verdict.** On "don't fine-tune", emit Output Format B and stop: no data plan, configs, or launch plan for a method that lost.
3. **No invented hardware.** Use probed (`nvidia-smi`) or declared (`--target-gpu`) specs, or ask for the training host's card/VRAM. Without real numbers the memory math stays symbolic.
4. **No absolute prices or durations.** Use duration classes (minutes / hours / days) and cost-driver formulas (GPU-hours × current rate, token volumes).
5. **Numbers are starting points.** Dataset sizes are ranges by task class; r/alpha/LR/beta are sweep origins. Label them so in the plan.
6. **Volatile facts are verified, not recalled.** Model IDs and revisions, and TRL/PEFT argument names (they churn across minor versions), are tagged "verify against current docs" (context7 / provider hub) for the executor.
7. **Plan goes to stdout.** Print the complete plan; don't write a plan file.
8. Execute directly; don't enter plan mode.

## Usage

```bash
/ai-engineer:finetune-plan "make the support bot answer in our house style"
/ai-engineer:finetune-plan "emit strict JSON audit summaries" --data data/audits/
/ai-engineer:finetune-plan "prefer concise, non-sycophantic answers" --base <org/model-id>
/ai-engineer:finetune-plan "domain assistant for internal CRM" --target-gpu "1x 24 GB"   # training host differs from this box
```

## Options

| Option | Default | Effect |
|--------|---------|--------|
| `task` | required | What the tuned model should do, in the user's words. Drives task-class sizing and the architector's framing. |
| `--data <path>` | auto-discover | Where existing candidate training data lives (JSONL, logs, exports). Without it, glob `data/**` and report what's found. |
| `--base <model-id>` | recommend one | Candidate base model; the plan pins a revision (Rule 6). |
| `--target-gpu "<spec>"` | probe `nvidia-smi` | Training-host hardware when it differs from this machine (e.g. `"1x 24 GB"`, `"2x 80 GB"`). Used only for the memory math. |

## Workflow

### Phase 0: Context Gathering

Print a "Context Detected" block before delegating:

1. **Task** — the target behavior in one sentence.
2. **Data inventory** — glob `data/**/*.jsonl`, `data/ledger/*.yaml`, `*.dvc`, the `--data` path; count records (`wc -l`); note format (messages schema vs raw logs) and whether a provenance ledger exists.
3. **Prompt/RAG stack** — `prompts/` and versioned prompt files; grep `pyproject.toml`/`uv.lock` for `anthropic|openai|litellm|langchain|llama-index|chromadb|qdrant|pgvector|faiss`.
4. **Eval assets** — `evals/` harnesses, golden-set manifests, judge configs. None is a planning input, not a blocker.
5. **Training stack** — `torch|transformers|peft|trl|accelerate|bitsandbytes` in `uv.lock`.
6. **Base model** — `--base`, else an existing id from training configs or `pyproject.toml`, with its parameter count; none → recommended in Phase 2.
7. **GPU** — `nvidia-smi --query-gpu=name,memory.total --format=csv,noheader`. No binary → "no CUDA on this box", plan the two-host workflow (Mac/MPS smoke loop, Linux/CUDA full run per `ai-engineer:training-optimization`), and use `--target-gpu` or ask (Rule 3).

### Phase 1: Method Verdict

Use the Agent tool with `subagent_type="ai-engineer:ai-architector"`. Prompt: "Feasibility consultation; don't implement anything. Task: {task}. Detected context: {data inventory, prompt/RAG stack, eval assets, hardware}. Apply your Prompt vs RAG vs Fine-tune vs Hybrid decision table and return the compressed form: decision, the 2-3 criteria that decided it with project inputs, each rejected option + the criterion that killed it, the eval gate that would validate the bet, and measurable revisit-when triggers. If the honest answer is 'don't fine-tune', say so with the cheaper alternative."

- **Don't fine-tune** → Output Format B, stop (Rule 2).
- **Fine-tune** or **hybrid** (e.g. RAG for facts + adapter for form) → Phase 2.

### Phase 2: Plan Assembly

1. **Data** — per `ai-engineer:dataset-curation`: messages-format JSONL (one system-turn policy, strict role alternation, completion-only masking); size range by task class (style/persona ~200–2k · format enforcer ~500–5k · domain assistant ~1k–20k · DPO pairs ~2k–20k); gap = range minus curated inventory; the eight curation gates (collect→normalize→dedupe→decontaminate→scrub→license→split→version, fail-closed on scrub/license). If rows come from already-graded traces, source them via `ai-engineer:trace-to-training-data`.
2. **Base model** — carry Phase 0's candidate forward; if none, recommend one marked "unpinned". Either way resolve a parameter count, because step 4 is computed from it.
3. **Method** — per `ai-engineer:peft-lora` and `ai-engineer:preference-tuning`: LoRA (behavior/format/domain from gold outputs), QLoRA (same job under step 4's VRAM budget), or SFT→DPO (directional better-vs-worse targets; needs a competent SFT baseline). Give the config starting point (r, alpha ≈ 2r, target_modules, dropout). When success is decided by a program (unit tests, schema validation, math ground truth, tool-call match), use `ai-engineer:grpo-rlvr-training` instead: DPO for taste, GRPO for reasoning. That branch needs the skill's two preconditions (a verifier exists; base success rate is nonzero); if either fails, plan SFT first.
4. **GPU memory** — formulas per `ai-engineer:training-optimization` `references/gpu-memory-math.md` (weights + gradients + optimizer states + activations + ≥10–15% headroom), instantiated from the parameter count against probed or declared hardware only. Verdict fits / tight / doesn't fit, plus which fit-ladder rungs to plan (accumulation, checkpointing, QLoRA). No hardware → symbolic, marked "instantiate on the training host".
5. **Hyperparameters** — LR (~2e-4 LoRA-class), cosine schedule + warmup, effective batch = micro × accumulation (retune LR when it changes), fixed seed; DPO beta ~0.1 swept against held-out win rate, never training loss.
6. **Eval plan** — per `ai-engineer:eval-design`: baseline on the pinned eval set before training (temperature 0, eval-set version recorded); target metrics with pass thresholds; a general-capability regression slice that must not regress (the catastrophic-forgetting detector); gate wiring per `ai-engineer:regression-gates`; subjective quality via `ai-engineer:llm-judge`.
7. **Launch** — two printed commands. **Smoke**: capped `max_steps`, ~256-record subsample, fixed seed; minutes; success = falling loss, no NaN, sane trainable-param %, peak memory vs estimate. **Full**: command + dataset version + CUDA host; duration class + cost drivers (GPU-hours ≈ steps × sec/step; spend scales with params, sequence length, epochs).
8. **Promotion gate** — per `ai-engineer:checkpoint-promotion`: the frozen baseline and version-pinned capability-drift suite, and the drift budget (≤1pt noise · 2–5pt seed-variation rerun · >5pt hard fail that no target-task gain buys back). Margins carry their half-width; a margin inside its interval is `REJECT (uncertain)`. State the first escalation rung on `REJECT`, because a plan with no reject path silently assumes success.
9. **Export** — per `ai-engineer:quantized-export`, as the `PROMOTE` branch: merged vs LoRA-only (LoRA-only pins base repo and revision), target runtime and format, and the pre/post smoke test over 3–5 goldens. Pre-export generations are captured before the export runs; they are the smoke test's only baseline.

### Phase 3: Emit

Print Output Format A. Close with the execution route: `ai-engineer:ml-engineer` runs it inside a worktask DV (smoke-scale rule applies); the eval harness is built by `ai-engineer:ai-test-generator`.

## Output Format

**A — fine-tune / hybrid verdict:**

```markdown
## Fine-Tuning Feasibility Plan — {task}

**Verdict:** FINE-TUNE ({LoRA | QLoRA | SFT→DPO}) | HYBRID ({RAG for facts + adapter for form}) — per ai-engineer:ai-architector
**Context detected:** data {inventory summary} · prompt/RAG {stack} · evals {present/absent} · hardware {probed | declared | none → two-host}
**Base model:** {org/model-id} ({param count}) · revision {pinned value | unpinned — verify against current provider/hub docs} · source {--base | repo config | recommended}

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
Regression slice: {general-capability slice — must not regress} · Gate: ai-engineer:regression-gates

### Launch Plan (commands for the executor — not run by this command)
Smoke: `{command}` — {success criteria}; duration class: minutes
Full:  `{command}` — host {host}, dataset {version}; duration class {hours|days}; cost drivers {formula}

### Risks & Open Questions
{data gaps, license unknowns, unverified hardware, contested criteria}
```

**B — don't-fine-tune verdict (then stop):**

```markdown
## Fine-Tuning Feasibility Plan — {task}

**Verdict: DON'T FINE-TUNE** — {prompting | RAG | hybrid-without-tuning} covers this cheaper.
**Why:** {2-3 deciding criteria from the decision table, with project inputs}
**Do instead:** {concrete path + owning skill/agent, e.g. ai-engineer:rag-systems via ai-engineer:llm-engineer}
**Revisit when:** {measurable trigger — e.g. pinned eval set vN proves the cheaper layer's ceiling}
```

## Error Handling

| Condition | Response |
|-----------|----------|
| No task description | `Note: finetune-plan needs a task description.` / `Usage: /ai-engineer:finetune-plan "what the tuned model should do" [--data <path>]` |
| No candidate data found | Not fatal: the plan includes a collection step sized by task class, with the ledger/consent requirements it must meet. If the range for the task class exceeds what can plausibly be curated, say so; that evidence goes to the architector and may flip the verdict. |
| No `nvidia-smi` and no `--target-gpu` | Not a failure: symbolic memory math, Mac/MPS smoke + CUDA full-run plan, and ask for the training host's specs before the full run can be instantiated. |
| `ai-engineer:ai-architector` dispatch fails | Apply the decision table inline from `agents/ai-architector.md § Decision Frameworks`, mark the verdict **PROVISIONAL (architector unavailable)**, and recommend re-running before anyone collects data. |
| context7 unavailable | Proceed, stamping every volatile fact (model IDs, TRL/PEFT arg names, quantization support) UNVERIFIED. |

## See Also

- `ai-engineer:finetuning` leaf skills — dataset-curation, trace-to-training-data, peft-lora, preference-tuning, grpo-rlvr-training, training-optimization, checkpoint-promotion (+ `references/gate-templates.md`), quantized-export (+ `references/export-commands.md`), as cited in Phase 2.
- `ai-engineer:eval-design`, `ai-engineer:regression-gates` — eval sets, thresholds, CI gating for the success criteria.
- `/ai-engineer:data-audit` — audit the candidate data before collection or training.
- `/ai-engineer:deploy-check` — readiness gate when the artifact heads to serving.
- `ai-engineer:ml-engineer` executes the plan; `ai-engineer:ai-test-generator` builds the eval harness.
