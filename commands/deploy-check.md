---
description: Serving readiness gate for vLLM/TGI/Ollama/Triton deploys — checklist audit of pins, quantization evals, KV-cache math, gateway controls, probes, rollback, monitoring, and lockfiles, returning GO / NO-GO / GO-WITH-RISKS with P0-P3 gaps.
argument-hint: [scope: serving config dir/file — default: auto-detect] [--stack vllm|tgi|ollama|triton] [--quick]
allowed-tools: Read, Agent, Glob, Grep, Bash
---

# Serving Readiness Gate (Deploy Check)

Audit a model-serving deployment before it takes traffic: locate the serving surface, walk the nine-item readiness checklist from `ai-engineer:model-serving`, add a config deep pass (`ai-engineer:mlops-engineer`) and a capacity pass (`ai-engineer:ai-performance-engineer`), and return one verdict — GO / NO-GO / GO-WITH-RISKS — with a per-item table and P0-P3 gaps. It gates; it never fixes.

## Rules

1. **Read-only.** This command and both subagent passes don't write or edit. Fixes route to `ai-engineer:ai-code-fixer` (mechanical config edits) or `ai-engineer:mlops-engineer` (design-level wiring).
2. **Every item gets a status:** PASS with `path:line` evidence, FAIL with the gap named, or N/A with a reason (e.g. "bf16 deploy, no quantized artifact"). An item that can't be evidenced from a file is FAIL — don't assume engine defaults, an upstream gateway, or monitoring in another repo.
3. **The verdict is mechanical** — exactly one of GO / NO-GO / GO-WITH-RISKS, derived from the Verdict Rules. Don't soften a NO-GO in prose.
4. **No absolute price/perf numbers.** Express capacity and cost as formulas instantiated with config-derived values; quote measured numbers only when the repo contains them (load-test baselines, eval reports).
5. **Hardware arithmetic uses real hardware:** probed `nvidia-smi`, else the target declared in config/IaC. CPU-class serving (Ollama/GGUF, llama.cpp) is expected on the CPU rung; a silent CPU fallback behind a GPU-sized capacity plan is a finding.
6. **Don't manufacture findings.** A clean deployment gets a clean GO.
7. Execute directly; don't enter plan mode.

## Usage

```bash
/ai-engineer:deploy-check                                   # auto-detect
/ai-engineer:deploy-check serving/
/ai-engineer:deploy-check deploy/vllm-config.yaml --stack vllm
/ai-engineer:deploy-check --quick                           # checklist only
```

## Options

| Option | Default | Effect |
|--------|---------|--------|
| `scope` | auto-detect | Directory or file holding the serving deployment. Default scans the repo per Surface Discovery. |
| `--stack vllm\|tgi\|ollama\|triton` | auto | Force the engine when detection is ambiguous (e.g. generic K8s manifests). |
| `--quick` | off | Skip both subagent passes. The report notes reduced depth; GO still requires file evidence on every item. |

## Serving Surface Discovery

Locate the deployment and print the inventory before auditing:

| Artifact | Where to look |
|----------|---------------|
| Engine configs | `serving/**`, `deploy/**` YAML; `vllm serve` / `text-generation-launcher` flags in compose files, K8s manifests, systemd units, launch scripts |
| Ollama / llama.cpp | `Modelfile`, GGUF references, server launch flags |
| Triton | model repository `config.pbtxt` trees |
| Images | `Dockerfile*`, compose/K8s image refs — base-image digest pinning |
| Endpoint & gateway | proxy/gateway config, endpoint code, auth middleware, provider-SDK call sites (retries/fallback) |
| Monitoring | trace/OTel config, `monitoring/**` probes, dashboards-as-code, spend alarms |
| Lockfiles & pipelines | `uv.lock` + `uv sync --frozen` in images, `dvc.yaml`, CI deploy jobs |

Probe hardware with `nvidia-smi --query-gpu=name,memory.total --format=csv,noheader`.

## The Readiness Checklist

Per `ai-engineer:model-serving` and its `references/serving-stack-matrix.md`:

| # | Item | PASS means |
|---|------|-----------|
| 1 | Model revision pinned | Immutable revision (HF commit sha / registry version / image digest) in the serving config — not `latest`/`main` |
| 2 | Quantization declared + evaled | Format named in config AND the exact quantized artifact passed the pinned eval set vs the fp16 baseline (eval report/registry evidence). N/A when unquantized |
| 3 | KV-cache / context budget arithmetic | `max_model_len` + max concurrency derived from the model's `config.json` shape vs available VRAM — recorded math, not trial-and-OOM |
| 4 | Gateway: authn + rate limits + quotas | Endpoint fronted by authn (keys/mTLS), rate limits, per-tenant quotas — not an open OpenAI-compatible port |
| 5 | Client resilience: retries + fallback | Timeouts on every call, bounded retries on retryable statuses only, a defined fallback chain (`ai-engineer:llm-api-patterns`) |
| 6 | Probes + warmup + drain | Startup/liveness/readiness split; ready gated on weights loaded AND warmup done; graceful drain ≥ longest allowed stream |
| 7 | Rollback path defined | Previous revision stays loadable; rollback = alias/revision flip (minutes), not an image rebuild; canary/revert condition stated |
| 8 | Monitoring wired | Traces (prompt_version, model_revision, tokens, latency, outcome), drift probes (input drift + scheduled judge evals), cost dashboards + spend alarms — ≥1 metric per plane (`ai-engineer:model-monitoring`) |
| 9 | Lockfile / image pinning | `uv sync --frozen` against a committed `uv.lock`; digest-pinned accelerator base image (`ai-engineer:ml-pipelines § Environment Discipline`) |

## Workflow

### Phase 1: Checklist Audit

Walk the nine items against the inventory. Check locally what you can: `latest`/`main` in model refs, `max_model_len`/`max_num_seqs`, probe blocks and `terminationGracePeriodSeconds`, `--frozen` and image digests. With `--quick`, go to Phase 3.

### Phase 2: Deep Passes (parallel)

Launch both with the Agent tool in one message and wait for both.

`subagent_type="ai-engineer:mlops-engineer"`: "Read-only deep pass over this serving deployment: {inventory}. Stack: {stack}. Verify engine flag validity against current docs (context7), pin integrity (model revision, adapter revisions, image digests), probe/warmup/drain wiring, rollback + canary story, registry/promotion path, and whether monitoring sinks actually emit. Don't write or edit. Return findings as `{file, line, checklist_item, severity (P0-P3), why, fix}`; say so when an area is clean."

`subagent_type="ai-engineer:ai-performance-engineer"`: "Read-only capacity arithmetic for this deployment: {inventory}. From the model's config.json (n_layers, n_kv_heads, head_dim, KV dtype) and the serving config (max_model_len, max concurrent sequences), compute per-token and per-sequence KV bytes and S_max against {probed VRAM | declared target hardware}. Flag headroom under 10-15%, `max_model_len` far above the product's real context need, guessed concurrency, and quantized-weight plans that assume fp16 KV. Formulas and config-derived numbers only, no leaderboard figures. Return findings as `{file, line, checklist_item, severity (P0-P3), why, fix}`."

### Phase 3: Synthesis + Verdict

1. **Merge** checklist statuses with subagent findings; dedupe at `{file, line}` keeping the higher severity; drop claims without concrete evidence.
2. **Rank** P0-P3 per `${CLAUDE_PLUGIN_ROOT}/skills/_shared/severity-matrix.md`: leaked key or open privileged endpoint → P0; unpinned revision in a production path → P1; missing retries, monitoring gaps, unbounded spend → P2-P1; style → P3.
3. **Verdict Rules:**
   - **NO-GO** — any P0; OR no serving config located; OR FAIL on item 1, 4, 6, or 7 (pin, gateway, probes, rollback — the incident-shaped four).
   - **GO-WITH-RISKS** — no NO-GO condition, but ≥1 FAIL or any P1/P2. List each accepted risk with owner and fix route.
   - **GO** — every item PASS or justified N/A, nothing above P3.

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
- Then re-run /ai-engineer:deploy-check — a NO-GO is cleared by new evidence, not argument.
```

## Error Handling

| Condition | Response |
|-----------|----------|
| No serving config found | `Verdict: NO-GO — no serving configuration located under {scope}.` List the patterns searched; suggest passing the config path, or having `ai-engineer:mlops-engineer` scaffold the serving config first. |
| `nvidia-smi` absent | Not fatal. CPU-class stacks are audited on the CPU rung; GPU stacks against declared target hardware. With neither probe nor declaration, item 3 fails and the report says what to declare. |
| Model `config.json` unreachable (weights remote-only) | Item 3 fails; give the exact command to run on a host with the weights and keep the symbolic formulas so only numbers need filling in. |
| Subagent pass fails | Continue with Phase 1 results and note the failed pass under Reduced-Depth Notes. Items the pass would have evidenced stay FAIL. |
| context7 unavailable | Engine-flag validity unverified — note it; don't fail items on suspected flag drift. |

## See Also

- `ai-engineer:model-serving` (+ `references/serving-stack-matrix.md`) — checklist source.
- `ai-engineer:quantized-export` — the pre/post smoke-test diff a fine-tuned artifact should arrive with.
- `ai-engineer:checkpoint-promotion` — the upstream PROMOTE report the artifact should name.
- `ai-engineer:model-monitoring`, `ai-engineer:ml-pipelines`, `ai-engineer:llm-api-patterns` — behind items 8, 9, 5.
- `${CLAUDE_PLUGIN_ROOT}/skills/_shared/severity-matrix.md` — P0-P3 definitions.
- `/ai-engineer:finetune-plan` — planning the artifact this gate later ships.
- `ai-engineer:ai-security-auditor` — gateway-exposure and abuse-path review beyond item 4.
