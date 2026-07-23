---
description: Serving readiness gate for vLLM/TGI/Ollama/Triton deploys — checklist audit of pins, quantization evals, KV-cache math, gateway controls, probes, rollback, monitoring, and lockfiles, returning GO / NO-GO / GO-WITH-RISKS with P0-P3 gaps.
argument-hint: [scope: serving config dir/file — default: auto-detect] [--stack vllm|tgi|ollama|triton] [--quick]
allowed-tools: Read, Glob, Grep, Bash
estimated-cost:
  min-tokens: 3000
  max-tokens: 12000
  model-distribution:
    sonnet: 90%
    haiku: 10%
---

# Serving Readiness Gate (Deploy Check)
<!-- Updated: July 2026 -->

Audit a model-serving deployment before it takes traffic. The command locates the serving surface (engine configs, Dockerfiles, endpoint and gateway code, monitoring wiring), walks the nine-item readiness checklist from `skills/mlops/model-serving`, fans out a deep config pass to `ai-engineer:mlops-engineer` and the capacity arithmetic to `ai-engineer:ai-performance-engineer`, then returns a single mechanical verdict — GO / NO-GO / GO-WITH-RISKS — with a per-item pass/fail table and P0-P3 gaps. Read-only: it gates, it never fixes.

[Extended thinking: LLM endpoints fail in ways uptime checks cannot see — an unpinned revision silently becomes a different model, a TCP-open port with cold weights serves 30-second first tokens, an unauthenticated OpenAI-compatible endpoint is free compute for whoever scans it, and a `max_model_len` set to the model maximum quietly collapses concurrency. Every one of these is visible in config before rollout, which is why this gate is a file audit, not a load test. The two hard disciplines: missing config is itself the finding (never assume an engine default fills the gap), and the verdict is derived mechanically from findings so a NO-GO cannot be argued down into prose. Capacity claims come from the KV arithmetic over the model's real config.json against hardware that was probed or declared — never from leaderboard numbers.]

## CRITICAL BEHAVIORAL RULES

You MUST follow these rules exactly. Violating any of them is a failure.

1. **Read-only audit.** This command and both subagent passes never write or edit. Fixes route out: `ai-engineer:ai-code-fixer` for mechanical config edits, `ai-engineer:mlops-engineer` for design-level wiring.
2. **Missing config = NO-GO finding, not a guess.** A checklist item that cannot be evidenced from a `path:line` fails closed. Never assume engine defaults, "probably behind the corporate gateway", or "monitoring is in another repo" without the file that proves it.
3. **The verdict is mechanical.** Exactly one of GO / NO-GO / GO-WITH-RISKS, derived from the Verdict Rules below. Never soften a NO-GO narratively, and never award GO with an UNKNOWN on the table.
4. **Every item gets a status** — PASS (with `path:line` evidence), FAIL (with the gap named), or N/A (with the stated reason, e.g. "no quantized artifact — bf16 deploy"). UNKNOWN is recorded as FAIL per Rule 2.
5. **No absolute price/perf numbers.** Capacity and cost are expressed as the arithmetic (KV formulas, $/token formula shapes) instantiated with config-derived values; quote measured numbers only when the repo contains them (load-test baselines, eval reports).
6. **Hardware arithmetic against real hardware only.** Probe `nvidia-smi`; absent, use the target hardware declared in config/IaC. CPU-class serving (Ollama/GGUF, llama.cpp) is audited on the CPU rung — expected, not a finding; a *silent* CPU fallback behind a GPU-sized capacity plan is.
7. **No manufactured findings.** A clean deployment gets a clean GO — do not invent P2/P3 nits to make the report look thorough.
8. **Never enter plan mode.** This command IS the procedure — execute it.

## Usage

```bash
# Audit the auto-detected serving surface of this repo
/ai-engineer:deploy-check

# Audit a specific directory or config file
/ai-engineer:deploy-check serving/
/ai-engineer:deploy-check deploy/vllm-config.yaml --stack vllm

# Fast checklist-only pass (skips the two subagent deep passes)
/ai-engineer:deploy-check --quick
```

## Options

| Option | Default | Effect |
|--------|---------|--------|
| `scope` | auto-detect | Directory or file holding the serving deployment to audit. Default scans the repo per Surface Discovery. |
| `--stack vllm\|tgi\|ollama\|triton` | auto | Force the engine when detection is ambiguous (e.g. generic K8s manifests). |
| `--quick` | off | Checklist-only single pass by this command; skips the `mlops-engineer` deep pass and the `ai-performance-engineer` capacity pass. Reduced depth is noted in the report; GO still requires file-level evidence on every item. |

## Serving Surface Discovery

Locate the deployment (Glob/Grep) and **print the inventory before auditing**:

| Artifact | Where to look |
|----------|---------------|
| Engine configs | `serving/**`, `deploy/**` YAML; `vllm serve` / `text-generation-launcher` flags in compose files, K8s manifests, systemd units, launch scripts |
| Ollama / llama.cpp | `Modelfile`, GGUF references, server launch flags |
| Triton | model repository `config.pbtxt` trees |
| Images | `Dockerfile*`, compose/K8s image refs — base-image digest pinning |
| Endpoint & gateway | proxy/gateway config, FastAPI/endpoint code, auth middleware, provider-SDK call sites (retries/fallback) |
| Monitoring | trace/OTel config, `monitoring/**` probes, dashboards-as-code, spend alarms |
| Lockfiles & pipelines | `uv.lock` + `uv sync --frozen` in images, `dvc.yaml`, CI deploy jobs |

Plus the hardware probe: `nvidia-smi --query-gpu=name,memory.total --format=csv,noheader` (absent → Rule 6). Nothing serving-shaped found → Error Handling (NO-GO shape).

## The Readiness Checklist

Nine items, per `skills/mlops/model-serving` (+ `references/serving-stack-matrix.md § Per-Deploy Verification Checklist`):

| # | Item | PASS means |
|---|------|-----------|
| 1 | Model revision pinned | Immutable revision (HF commit sha / registry version / image digest) in the serving config — never `latest`/`main` |
| 2 | Quantization declared + evaled | Format named in config AND the exact quantized artifact passed the pinned eval set vs the fp16 baseline (eval report/registry evidence). N/A when unquantized |
| 3 | KV-cache / context budget arithmetic | `max_model_len` + max concurrency derived from the model's `config.json` shape vs available VRAM — recorded math, not trial-and-OOM |
| 4 | Gateway: authn + rate limits + quotas | Endpoint fronted by authn (keys/mTLS), rate limits, per-tenant quotas — not an open OpenAI-compatible port |
| 5 | Client resilience: retries + fallback | Timeouts on every call, bounded retries on retryable statuses only, a defined fallback chain (`skills/llm-apps/llm-api-patterns`) |
| 6 | Probes + warmup + drain | Startup/liveness/readiness split; ready gated on weights loaded AND warmup done; graceful drain ≥ longest allowed stream |
| 7 | Rollback path defined | Previous revision stays loadable; rollback = alias/revision flip (minutes), not an image rebuild; canary/revert condition stated |
| 8 | Monitoring wired | Traces (prompt_version, model_revision, tokens, latency, outcome), drift probes (input drift + scheduled judge evals), cost dashboards + spend alarms — ≥1 metric per plane, per `skills/mlops/model-monitoring` |
| 9 | Lockfile / image pinning | `uv sync --frozen` against a committed `uv.lock`; digest-pinned accelerator base image (`skills/mlops/ml-pipelines § Environment Discipline`) |

## Workflow

### Phase 1: Checklist Audit (this command)

Walk the nine items against the discovered inventory. Each item → status + `path:line` evidence, or the missing-config gap named (Rule 4). Compute what is computable locally: grep for `latest`/`main` in model refs, read `max_model_len`/`max_num_seqs`, check probe blocks and `terminationGracePeriodSeconds`, confirm `--frozen` and image digests.

With `--quick`, skip Phase 2 and go straight to synthesis.

### Phase 2: Deep Passes (parallel; skipped by `--quick`)

**Use Task tool with subagent_type="ai-engineer:mlops-engineer"**
Prompt: "Read-only deep pass over this serving deployment: {inventory}. Stack: {stack}. Verify engine flag validity against current docs (context7 — serving options churn), pin integrity (model revision, adapter revisions, image digests), probe/warmup/drain wiring, rollback + canary story, registry/promotion path, and monitoring sink reality (does anything actually emit?). Do NOT write or edit. Return findings as `{file, line, checklist_item, severity (P0-P3), why, fix}`. If an area is clean, say so."

**Use Task tool with subagent_type="ai-engineer:ai-performance-engineer"**
Prompt: "Read-only capacity arithmetic for this deployment: {inventory}. From the model's config.json (n_layers, n_kv_heads, head_dim, KV dtype) and the serving config (max_model_len, max concurrent sequences), compute per-token and per-sequence KV bytes and S_max against {probed VRAM | declared target hardware}. Flag: headroom < 10-15%, `max_model_len` far above the product's real context need, concurrency set by guesswork, quantization memory plans that assume fp16 KV. Formulas + config-derived numbers only — no absolute perf claims, no leaderboard numbers. Do NOT write or edit. Return findings as `{file, line, checklist_item, severity (P0-P3), why, fix}`."

[SYNC POINT: wait for both passes before synthesis.]

### Phase 3: Synthesis + Verdict

1. **Merge** checklist statuses with subagent findings; deduplicate at `{file, line}` keeping the higher severity; drop speculative claims without concrete evidence.
2. **Rank** every finding P0-P3 per `skills/_shared/severity-matrix.md` (leaked key / open privileged endpoint → P0; unpinned revision in a production path → P1; missing retries/monitoring gaps / unbounded spend → P2-P1; style → P3).
3. **Verdict Rules** (mechanical, Rule 3):
   - **NO-GO** — any P0 finding; OR no serving config located; OR FAIL/UNKNOWN on item 1, 4, 6, or 7 (pin, gateway, probes, rollback — the incident-shaped four).
   - **GO-WITH-RISKS** — no NO-GO condition, but ≥1 remaining FAIL or any P1/P2 finding. Each accepted risk is listed with its owner and fix route.
   - **GO** — every item PASS or justified N/A, nothing above P3.
4. **Emit** the Output Format report.

## Output Format

```markdown
## Deploy Check — {scope}

**Verdict: {GO | NO-GO | GO-WITH-RISKS}**
**Stack:** {vllm | tgi | ollama | triton | mixed} · **Hardware:** {probed GPU + VRAM | CPU-class | declared target | unknown}
**Mode:** {full | --quick (reduced depth)}

### Checklist
| # | Item | Status | Evidence / gap | Severity |
|---|------|--------|----------------|----------|
| 1 | Model revision pinned | PASS/FAIL/N/A | {path:line | "missing: …"} | {— | P0-P3} |
| … | (all nine rows, always) | | | |

### P0 — Block deploy
| File:Line | Item | Why | Fix | Route |
|-----------|------|-----|-----|-------|

### P1 — Fix before traffic ramps
{same shape} — then P2 (Should fix), P3 (Nice to have)

### Capacity Arithmetic
{per_token_kv / per_seq_kv / S_max instantiation vs hardware, or "UNKNOWN — config.json shape unavailable (item 3 fails closed)"}

### Reduced-Depth Notes
{nvidia-smi absent · --quick · subagent pass skipped/failed · context7 unavailable — or "none"}

### Next Steps
- Fix now (P0/P1): {finding → ai-engineer:ai-code-fixer | ai-engineer:mlops-engineer}
- Then re-run /ai-engineer:deploy-check — a NO-GO is re-earned by evidence, not argued down.
```

## Error Handling

### No serving configuration found
```
Verdict: NO-GO — no serving configuration located under {scope}.
Searched: {patterns from Surface Discovery}.
A deployment with no config to audit is unready by definition (Rule 2).
Suggestion: pass the config path explicitly, or have ai-engineer:mlops-engineer scaffold the serving config first.
```

### `nvidia-smi` absent
Not fatal (Rule 6): CPU-class stacks (Ollama/GGUF) are audited on the CPU rung. GPU stacks (vLLM/TGI/Triton) are audited against target hardware declared in config/IaC; when neither probe nor declaration exists, item 3 is UNKNOWN → FAIL, and the report says exactly what to declare.

### Model `config.json` unreachable (weights remote-only)
Item 3 arithmetic cannot be verified here: record the item as FAIL with the exact command to run on a host with the weights, and keep the symbolic formulas in the report so the executor only fills in numbers.

### Subagent dispatch failure
Continue with the Phase 1 checklist results, list the failed pass under Reduced-Depth Notes, and keep Rule 3 intact — items the deep pass would have evidenced stay FAIL, not benefit-of-the-doubt PASS.

### context7 unavailable
Engine-flag validity goes unverified — note it in Reduced-Depth Notes; do not fail items on suspected-but-unverified flag drift.

## See Also

- `skills/mlops/model-serving` (+ `references/serving-stack-matrix.md`) — the checklist source: pins, quantization evals, KV math, probes, rollback
- `skills/mlops/model-monitoring` — the three monitoring planes item 8 checks
- `skills/mlops/ml-pipelines` — lockfile/image environment discipline behind item 9
- `skills/llm-apps/llm-api-patterns` — client-side retries/fallback behind item 5
- `skills/_shared/severity-matrix.md` — P0-P3 definitions the verdict derives from
- `/ai-engineer:finetune-plan` — planning the artifact this gate later ships
- `ai-engineer:ai-security-auditor` — escalation for gateway-exposure and abuse-path review beyond item 4's config check

If the deployment is clean, say so and stamp the GO — do not manufacture risks to hedge the verdict.
