# Registering ai-engineer as an igrsoft platform (company-workflow companion edits)

This document specifies the exact edits that register **ai-engineer** as a
routable platform (`ai`) in the **igrsoft company-workflow plugin**
(v3.36.0, separate repo: `/Volumes/internal/Projects/igrsoft/ai-agents/company-workflow`).
Apply them via a company-workflow PR — **nothing in this file changes the
ai-engineer repo**, and nothing here is applied automatically.

## What works today vs what needs registration

**Works today, standalone (no company-workflow change needed):**

- Slash commands: `/ai-engineer:review-code`, `/ai-engineer:eval-run`,
  `/ai-engineer:prompt-optimize`, `/ai-engineer:rag-audit`,
  `/ai-engineer:finetune-plan`, `/ai-engineer:data-audit`,
  `/ai-engineer:deploy-check`, `/ai-engineer:analyze-security`.
- Direct delegation: `Task(ai-engineer:ai-engineer)` and every other
  `Task(ai-engineer:<agent>)` target, including from an igrsoft worktask when
  PL0 stamps `metadata.agent: "ai-engineer:ai-engineer"` explicitly.
- All 24 skills and the workflow-integration contract
  (`skills/_shared/workflow-integration/SKILL.md`) — ai-engineer agents already
  speak the v3.36.0 handoff protocol.

**Needs the edits below:**

- `igrsoft:developer` **DV auto-routing** — the developer agent's `tools:`
  frontmatter must list the ai-engineer Task targets, and the platform
  detection tables must know the `ai` markers, or DV can never dispatch an
  ai-engineer specialist on its own.
- **`--platform ai`** on `/worktask`, `/dev-code-review`, and `/pm-milestone`
  (today the enums stop at `apple|android|web|all`).
- PL0 (`product-manager`) knowing that `ai` is a non-UI platform
  (`requires_screenshots: false`) and how to stamp the DV0 route.
- Cross-plugin handoff registry (`plugin-protocols.md`) and the
  senior-developer estimation matrix.

Surfaces 1–8 are required; surface 9 is optional consultation wiring;
surface 10 is a verification-only no-op check.

---

## 1. `agents/developer.md` — DV router: tools + common rows + evidence default

### 1a. Frontmatter `tools:` — add the ai-engineer Task targets

The `tools:` line lists, per platform, the router + implementers + fixer/test
pair. Append the ai-engineer family after the backend-developer entries
(before the first `mcp__XcodeBuildMCP__*` entry), mirroring that shape.

**BEFORE** (fragment of the single `tools:` line, line 10):

```
…, Task(backend-developer:be-code-fixer), Task(backend-developer:be-test-generator), mcp__XcodeBuildMCP__session_show_defaults, …
```

**AFTER**:

```
…, Task(backend-developer:be-code-fixer), Task(backend-developer:be-test-generator), Task(ai-engineer:ai-engineer), Task(ai-engineer:llm-engineer), Task(ai-engineer:ml-engineer), Task(ai-engineer:mlops-engineer), Task(ai-engineer:ai-prompt-engineer), Task(ai-engineer:ai-code-fixer), Task(ai-engineer:ai-test-generator), mcp__XcodeBuildMCP__session_show_defaults, …
```

(Router `ai-engineer:ai-engineer`, three domain implementers +
`ai-prompt-engineer`, then the fixer/test-generator pair. The review-only
specialists — `ai-security-auditor`, `ai-performance-engineer` — are reached
through the stage flow, not as direct DV `Task(...)` targets, matching the
android/web convention.)

### 1b. `### Platform Specialization (common rows)` — add the `ai` row

**BEFORE** (lines 70–75):

```markdown
| Platform | Default specialist | Common alternate |
|----------|--------------------|------------------|
| apple | `apple-developer:apple-developer` (Swift, concurrency; routes internally) | `apple-developer:ios-developer` (iOS/UIKit) |
| android | `android-developer:android-developer` (router) | `android-developer:android-phone-developer` (Compose UI) |
| web | `frontend-developer:frontend-developer` (router, plain HTML/CSS/TS) | `frontend-developer:react-developer` (React/Next.js) |
| systems | `system-developer:system-developer` (router, FFI/mixed) | `system-developer:python-developer` / `system-developer:cpp-developer` |
```

**AFTER** (one row appended):

```markdown
| Platform | Default specialist | Common alternate |
|----------|--------------------|------------------|
| apple | `apple-developer:apple-developer` (Swift, concurrency; routes internally) | `apple-developer:ios-developer` (iOS/UIKit) |
| android | `android-developer:android-developer` (router) | `android-developer:android-phone-developer` (Compose UI) |
| web | `frontend-developer:frontend-developer` (router, plain HTML/CSS/TS) | `frontend-developer:react-developer` (React/Next.js) |
| systems | `system-developer:system-developer` (router, FFI/mixed) | `system-developer:python-developer` / `system-developer:cpp-developer` |
| ai | `ai-engineer:ai-engineer` (router, mixed AI stacks) | `ai-engineer:llm-engineer` (LLM apps/RAG) / `ai-engineer:ml-engineer` (fine-tuning) |
```

### 1c. `#### UI vs non-UI defaults` — add `ai` to the non-UI set

**BEFORE** (line 81):

```markdown
UI vs non-UI defaults: apple/android/web work is UI by default (set `metadata.requires_screenshots: true`, capture via the platform adapter); systems/backend work is non-UI by default (`requires_screenshots: false`, build/test transcripts under `.context/logs/` are the Build Evidence). Per-platform adapter detail and review-only specialists are in `skills/shared/platform-detection.md`.
```

**AFTER**:

```markdown
UI vs non-UI defaults: apple/android/web work is UI by default (set `metadata.requires_screenshots: true`, capture via the platform adapter); systems/backend/ai work is non-UI by default (`requires_screenshots: false`; build/test transcripts under `.context/logs/` are the Build Evidence — for ai, the cli-fallback evidence is eval reports, loss-curve textual summaries, and test transcripts). Per-platform adapter detail and review-only specialists are in `skills/shared/platform-detection.md`.
```

---

## 2. `skills/shared/platform-detection.md` — AI specialization, markers, precedence

### 2a. New `## AI Platform Specialization` section

Insert after the `### Web DV evidence and review specialists` paragraph and
before `## Detection Rules (markers → platform)`.

**BEFORE** (lines 77–81, insertion point):

```markdown
### Web DV evidence and review specialists

Web work is UI by default: set/forward `metadata.requires_screenshots: true` on DV tasks (captured via the `web_adapter` → Playwright `npx playwright screenshot` / Chrome MCP); the screenshot manifest at `.context/images/<worktask_id>/screenshots.md` plus Lighthouse/axe reports are the Build Evidence. Review-only specialists (`frontend-developer:fe-performance-engineer`, `frontend-developer:fe-accessibility-auditor`, `frontend-developer:fe-security-auditor`) are reached through the stage flow (DR/SR/QA), not as direct DV `Task(...)` targets.

## Detection Rules (markers → platform)
```

**AFTER** (new section inserted between them):

```markdown
## AI Platform Specialization

When platform is `ai`, further route based on context:

| Context | Agent | Use Case |
|---------|-------|----------|
| LLM application — RAG, agent loops/tool use, structured outputs, provider SDK calls | `ai-engineer:llm-engineer` | LLM features, retrieval pipelines, streaming/caching/fallback |
| Training / fine-tuning — LoRA/QLoRA, DPO, dataset prep, trainer scripts | `ai-engineer:ml-engineer` | PyTorch, Transformers/TRL/PEFT, smoke-scale verification |
| Serving / pipelines / tracking — deploy, experiment tracking, monitoring | `ai-engineer:mlops-engineer` | vLLM/TGI/Ollama/Triton, MLflow/W&B, DVC, drift |
| Prompt assets — the prompts shipped inside the product | `ai-engineer:ai-prompt-engineer` | System-prompt design and eval-driven optimization |
| Ambiguous / cross-domain AI work (app+serving, training+eval) | `ai-engineer:ai-engineer` | Index/router; sequences specialists, owns the seams |

The full marker → agent tables (dependency dist names, file markers, mixed-stack
tie-breaks) are canonical in ai-engineer `skills/_shared/framework-detection.md`
— do not fork them here.

### AI DV evidence

AI work is non-UI by default: set/forward `metadata.requires_screenshots: false` on DV tasks (or rely on the `cli_fallback_adapter`); the cli-fallback evidence is eval reports, loss-curve textual summaries, and test transcripts under `.context/logs/` (AI Build Evidence: `python -VV`, framework versions from `uv.lock`, ruff/type status, eval metrics vs baseline when prompts/models/retrieval change). Review-only specialists (`ai-engineer:ai-security-auditor`, `ai-engineer:ai-performance-engineer`) are reached through the stage flow (DR/SR/QA), not as direct DV `Task(...)` targets.
```

### 2b. `## Detection Rules (markers → platform)` — AI marker rows

Insert a new `#### AI platform` table after
`#### Backend platforms — contracts, data & polyglot` and before
`#### Mixed-repo precedence`.

**BEFORE** (lines 115–123, insertion point):

```markdown
#### Backend platforms — contracts, data & polyglot

| Markers | Platform | Route To |
|---------|----------|----------|
| REST/GraphQL/gRPC contract work (OpenAPI/SDL/`.proto`) | backend | `backend-developer:api-designer` |
| schema / migration / index / query / ORM work | backend | `backend-developer:database-engineer` |
| Mixed / polyglot / cross-service back-end | backend | `backend-developer:backend-developer` (router) |

#### Mixed-repo precedence
```

**AFTER** (new subsection inserted between them):

```markdown
#### AI platform

| Markers | Platform | Route To |
|---------|----------|----------|
| Deps (`pyproject.toml`/`requirements*.txt`/`uv.lock`): `anthropic`, `openai`, `langchain`, `llama-index`, `litellm` | ai | `ai-engineer:llm-engineer` |
| Deps in a training context: `torch`, `transformers`, `peft`, `trl`, `accelerate`, `bitsandbytes` | ai | `ai-engineer:ml-engineer` |
| Deps: `vllm`, `mlflow`, `wandb`, `dvc` | ai | `ai-engineer:mlops-engineer` |
| Files: `dvc.yaml`, `.dvc/` (data/pipeline versioning) | ai | `ai-engineer:mlops-engineer` |
| Files: CUDA `Dockerfile` (`FROM nvidia/cuda:…`, GPU torch/vLLM base images) | ai | `ai-engineer:mlops-engineer` |
| Files: `chat_template.jinja` (tokenizer chat template — dataset formatting / SFT alignment) | ai | `ai-engineer:ml-engineer` |
| Files: `*.ipynb` (experimentation — classify by the notebook's imports against the deps rows above) | ai | owning domain agent; mixed → `ai-engineer:ai-engineer` |
| Files: `*.safetensors`, `*.gguf` (model weights / quantized artifacts) | ai | producing them (training, merge, quantize) → `ai-engineer:ml-engineer`; serving/loading them → `ai-engineer:mlops-engineer` |
| Dirs: `prompts/` (prompt assets), `evals/` (eval harnesses) | ai | `ai-engineer:ai-prompt-engineer` / `ai-engineer:ai-test-generator` |
| Mixed / ambiguous AI stack | ai | `ai-engineer:ai-engineer` (router) |
```

### 2c. Precedence note — AI markers vs the generic Python rule

**BEFORE** (lines 127–129, the existing note the new one mirrors):

```markdown
Three precedence notes resolve the only non-trivial collisions:

- **Python language vs Python web.** Pure Python *language* depth (typing, asyncio internals, free-threading, packaging) → `system-developer:python-developer`. The Python *web* layer (FastAPI/Django/Flask + persistence) → `backend-developer:python-backend-developer`. The backend agent itself delegates language depth back to system-developer, so this is a routing entry point, not a fork.
```

**AFTER** (count updated, new bullet appended after the Python one):

```markdown
Four precedence notes resolve the only non-trivial collisions:

- **Python language vs Python web.** Pure Python *language* depth (typing, asyncio internals, free-threading, packaging) → `system-developer:python-developer`. The Python *web* layer (FastAPI/Django/Flask + persistence) → `backend-developer:python-backend-developer`. The backend agent itself delegates language depth back to system-developer, so this is a routing entry point, not a fork.
- **AI markers vs generic Python.** AI markers beat the generic `.py`/`pyproject.toml` → systems rule **when the task targets model/prompt/eval/serving work**: a Python repo with AI deps (`anthropic`, `torch`, `vllm`, …) routes to `ai-engineer:*` for tasks touching that surface. Pure Python language depth in the same repo (typing refactor, packaging fix, asyncio internals) stays `system-developer:python-developer` — the precedence is task-scoped, not repo-scoped; an `anthropic` dep does not annex the repository.
```

---

## 3. `skills/cross-plugin-handoff/references/plugin-protocols.md` — ai-engineer block

Insert an `## ai-engineer Plugin` block after the android-developer block and
before `## security-scanning Plugin`, mirroring the per-plugin table shape.

**BEFORE** (lines 49–55, insertion point — end of the android block):

```markdown
| SR (Security) | security-auditor | development context + Android security checklist (EncryptedSharedPreferences/Keystore, no-cleartext, exported-component validation, no hardcoded secrets) |
| QA (Quality) | test-generator | development context + test requirements; JUnit4/5, MockK, Turbine, Roborazzi screenshot tests |
| DV-support (dependencies) | dependency-manager | version catalog (`libs.versions.toml`) + Gradle dependency CVE audit scope |

## security-scanning Plugin
```

**AFTER** (new block inserted between them):

```markdown
| SR (Security) | security-auditor | development context + Android security checklist (EncryptedSharedPreferences/Keystore, no-cleartext, exported-component validation, no hardcoded secrets) |
| QA (Quality) | test-generator | development context + test requirements; JUnit4/5, MockK, Turbine, Roborazzi screenshot tests |
| DV-support (dependencies) | dependency-manager | version catalog (`libs.versions.toml`) + Gradle dependency CVE audit scope |

## ai-engineer Plugin

### ai-engineer — core stage handoffs

| igrsoft Stage | ai-engineer Agent | Handoff Data |
|---------------|-------------------|--------------|
| AR (Architecture) | ai-architector | planning context + AI system constraints (prompt-vs-RAG-vs-finetune, agent topology, serving stack — consultation model, like apple-architector) |
| DV (Development) | ai-engineer (router), llm-engineer, ml-engineer, mlops-engineer, ai-prompt-engineer | planning + architecture context; `requires_screenshots: false` for AI work (Build Evidence = eval reports, loss-curve summaries, test transcripts; smoke-scale training only — capped `max_steps`, full-run launch plan documented) |
| DR (Developer Review) | ai-code-fixer | gate blockers (`metadata.gate_blockers[]`) + minimal-diff remediation |

### ai-engineer — review, support & release handoffs

| igrsoft Stage | ai-engineer Agent | Handoff Data |
|---------------|-------------------|--------------|
| SR (Security) | ai-security-auditor | development context + OWASP LLM Top 10 checklist (prompt injection, insecure output handling, model supply chain — safetensors over pickle, pinned HF revisions — secret/PII leakage, ungated agency) |
| QA (Quality) | ai-test-generator | development context + test requirements; QA gate includes the eval regression gate where a harness exists (pinned eval-set version, deterministic settings) |
| DV-support (performance) | ai-performance-engineer | inference perf/cost review scope (TTFT, throughput/batching, KV-cache, quantization, GPU utilization) |
| DV-support (dependencies) | ai-dependency-manager | manifest paths (`pyproject.toml` + `uv.lock`) + CVE audit scope (pip-audit/osv-scanner) + HF model revision pins |
| RE (Release) | ai-dependency-manager | lockfile + model-revision + eval-set-version pin freeze for release readiness |

Error files are per-agent (basename = last `:`-segment of the qualified name):
`.context/errors/ai-engineer.md`, `llm-engineer.md`, `ml-engineer.md`,
`mlops-engineer.md`, `ai-prompt-engineer.md`, `ai-code-fixer.md`. Evidence
norm: non-UI — no screenshot adapter; the cli-fallback manifest rows point at
transcripts produced this run.

## security-scanning Plugin
```

---

## 4. `commands/dev-code-review.md` — `--platform` enum

**BEFORE** (line 78, in `## Options`):

```markdown
- `--platform <apple|android|web|all>` - Platform context (default: auto-detect)
```

**AFTER**:

```markdown
- `--platform <apple|android|web|ai|all>` - Platform context (default: auto-detect)
```

No routing table exists in this command file — platform routing is owned by
`agents/developer.md` + `skills/shared/platform-detection.md` (surfaces 1–2),
so the enum is the only edit here.

---

## 5. `commands/worktask.md` — `--platform` enum

**BEFORE** (line 65, in `### Scope and pipeline flags`):

```markdown
| `--platform <apple\|android\|web\|all>` | Target platform |
```

**AFTER**:

```markdown
| `--platform <apple\|android\|web\|ai\|all>` | Target platform |
```

---

## 6. `commands/pm-milestone.md` — enum + agent-assignment row

### 6a. Frontmatter `argument-hint`

**BEFORE** (line 4):

```yaml
argument-hint: '<feature description or --from-prd path> [--milestone N] [--platform apple|android|web] [--dry-run] [--secure]'
```

**AFTER**:

```yaml
argument-hint: '<feature description or --from-prd path> [--milestone N] [--platform apple|android|web|ai] [--dry-run] [--secure]'
```

### 6b. `## Options` table

**BEFORE** (line 35):

```markdown
| `--platform <apple\|android\|web\|all>` | Route implementation agent (default: infer from codebase) |
```

**AFTER**:

```markdown
| `--platform <apple\|android\|web\|ai\|all>` | Route implementation agent (default: infer from codebase) |
```

### 6c. `#### Implementation Agent` table

**BEFORE** (lines 73–78):

```markdown
| Platform / Content | Agent | Plugin |
|--------------------|-------|--------|
| `--platform apple` | `ios-developer` | apple-developer |
| `--platform android` | `developer` | igrsoft |
| `--platform web` | `developer` | igrsoft |
| `all` / omitted | `developer` | igrsoft |
```

**AFTER** (one row added before the `all` row):

```markdown
| Platform / Content | Agent | Plugin |
|--------------------|-------|--------|
| `--platform apple` | `ios-developer` | apple-developer |
| `--platform android` | `developer` | igrsoft |
| `--platform web` | `developer` | igrsoft |
| `--platform ai` | `ai-engineer` | ai-engineer |
| `all` / omitted | `developer` | igrsoft |
```

---

## 7. `skills/senior-developer-review/SKILL.md` — AI/ML estimation adjustments

Insert a `### AI/ML` subsection in `## Platform-Specific Adjustments`, after
`### Web/React` and before `## Review Process`, mirroring the iOS/Android/Web
table format.

**BEFORE** (lines 54–62, insertion point):

```markdown
### Web/React
| Feature | Min Adjustment | Max Adjustment |
|---------|---------------|---------------|
| WebGL rendering | +3 SP | +5 SP |
| WebRTC integration | +3 SP | +5 SP |
| Service workers | +2 SP | +3 SP |
| IndexedDB sync | +2 SP | +3 SP |

## Review Process
```

**AFTER** (new subsection inserted between them):

```markdown
### Web/React
| Feature | Min Adjustment | Max Adjustment |
|---------|---------------|---------------|
| WebGL rendering | +3 SP | +5 SP |
| WebRTC integration | +3 SP | +5 SP |
| Service workers | +2 SP | +3 SP |
| IndexedDB sync | +2 SP | +3 SP |

### AI/ML
| Feature | Min Adjustment | Max Adjustment |
|---------|---------------|---------------|
| GPU fine-tuning run (LoRA/QLoRA/DPO, memory fitting, smoke-then-full) | +3 SP | +5 SP |
| Data pipeline / dataset curation (dedup, decontamination, PII scrub) | +2 SP | +3 SP |
| Model-eval harness (golden sets, LLM-judge calibration, regression gates) | +2 SP | +3 SP |
| LLM provider integration (streaming, retries, fallback, cost bounds) | +1 SP | +2 SP |
| RAG pipeline (chunk/embed/retrieve/rerank + retrieval evals) | +2 SP | +3 SP |

## Review Process
```

---

## 8. `agents/product-manager.md` — S4 non-UI signal + DV0 routing override

### 8a. S4 detector note — `ai` stays non-UI

**BEFORE** (lines 119–125, `##### Detector run (step 1)`):

````markdown
1. Run the detector against the draft plan:
   ```bash
   skills/worktask/scripts/detect-ui-change.sh <draft-plan> --platform <platform>
   ```
   It emits `{requires_screenshots, signals, rationale}`. Signals (ANY true ⇒ true): **S1** `ui_visual_check: true`; **S2** `.context/designs/` has `figma-registry.md`/`*.png`; **S3** `## scope`/`## requirements` matches the UI keyword set; **S4** platform ∈ {apple, web, android} AND scope names UI path classes (`Views/`, `Screens/`, `*.storyboard`, `*.tsx`, …). Exits 0 always; any error ⇒ `true` (`fail_safe_default`).
````

**AFTER** (one sentence appended to the same list item):

````markdown
1. Run the detector against the draft plan:
   ```bash
   skills/worktask/scripts/detect-ui-change.sh <draft-plan> --platform <platform>
   ```
   It emits `{requires_screenshots, signals, rationale}`. Signals (ANY true ⇒ true): **S1** `ui_visual_check: true`; **S2** `.context/designs/` has `figma-registry.md`/`*.png`; **S3** `## scope`/`## requirements` matches the UI keyword set; **S4** platform ∈ {apple, web, android} AND scope names UI path classes (`Views/`, `Screens/`, `*.storyboard`, `*.tsx`, …). Exits 0 always; any error ⇒ `true` (`fail_safe_default`). Platform `ai` is deliberately **not** in the S4 set: AI/LLM work is non-UI by default (`requires_screenshots: false`; cli-fallback evidence = eval reports, loss-curve summaries, test transcripts) — S1–S3 can still force `true` when an AI task genuinely touches UI.
````

### 8b. DV0 routing override — `platform: ai`

**BEFORE** (lines 368–374, `##### DV0 routing override` section):

```markdown
##### DV0 routing override — plugin worktask-infrastructure

Single source of truth — do NOT duplicate elsewhere. The DV0 default `igrsoft:developer` routes *platform app-code*. Route DV to `metadata.agent: "igrsoft:workflow-engineer"` (model `opus`, error_file `.context/errors/workflow-engineer.md`) when the change touches worktask infrastructure — `skills/worktask/scripts/*.sh`, the state-machine / Task-System glue under `skills/worktask/**`, or `hooks/**`. Platform/app code (Swift, server, web, product source) stays `igrsoft:developer` (or the `apple-developer:*` variant); a mixed worktask splits DV sub-tasks by scope and routes each independently. `stage-codes.md` keeps the unconditional DV default and points here.

###### Worked example

Example: a `publish-pl-issue.sh` change → DV0 `workflow-engineer`, DR0 `technical-lead`, QA0 `qa-engineer`.
```

**AFTER** (new `###### AI platform override` appended after the worked example):

```markdown
##### DV0 routing override — plugin worktask-infrastructure

Single source of truth — do NOT duplicate elsewhere. The DV0 default `igrsoft:developer` routes *platform app-code*. Route DV to `metadata.agent: "igrsoft:workflow-engineer"` (model `opus`, error_file `.context/errors/workflow-engineer.md`) when the change touches worktask infrastructure — `skills/worktask/scripts/*.sh`, the state-machine / Task-System glue under `skills/worktask/**`, or `hooks/**`. Platform/app code (Swift, server, web, product source) stays `igrsoft:developer` (or the `apple-developer:*` variant); a mixed worktask splits DV sub-tasks by scope and routes each independently. `stage-codes.md` keeps the unconditional DV default and points here.

###### Worked example

Example: a `publish-pl-issue.sh` change → DV0 `workflow-engineer`, DR0 `technical-lead`, QA0 `qa-engineer`.

###### AI platform override

When `platform: ai` (explicit `--platform ai`, or the AI markers in `skills/shared/platform-detection.md § AI Platform Specialization` match), route DV0 to `metadata.agent: "ai-engineer:ai-engineer"` (model `sonnet`, error_file `.context/errors/ai-engineer.md`) and stamp `metadata.requires_screenshots: false` (AI work is non-UI; Build Evidence = eval reports and test transcripts under `.context/logs/`). The ai-engineer router further dispatches `ai-engineer:llm-engineer` / `:ml-engineer` / `:mlops-engineer` / `:ai-prompt-engineer` per its `skills/_shared/framework-detection.md`. Alternatively DV0 may stay `igrsoft:developer`, which reaches the same specialists via its own Task targets (surface: `agents/developer.md`); the direct stamp skips one delegation hop.
```

---

## 9. OPTIONAL — consultation wirings (three one-line `tools:` additions)

These let the AR/SR/QA stage owners consult ai-engineer specialists directly.
Skippable: without them, AI context still reaches those stages through the DV
artifacts and the developer agent.

### 9a. `agents/software-architector.md` — `ai-architector` consult

**BEFORE** (line 9):

```yaml
tools: Read, Glob, Grep, Write, Edit, TaskCreate, TaskUpdate, TaskGet, TaskList, Task(apple-developer:apple-architector)
```

**AFTER**:

```yaml
tools: Read, Glob, Grep, Write, Edit, TaskCreate, TaskUpdate, TaskGet, TaskList, Task(apple-developer:apple-architector), Task(ai-engineer:ai-architector)
```

### 9b. `agents/security-reviewer.md` — `ai-security-auditor` consult

**BEFORE** (line 9):

```yaml
tools: Read, Glob, Grep, Bash, Write, TaskCreate, TaskUpdate, TaskGet, TaskList, Task(apple-developer:security-auditor)
```

**AFTER**:

```yaml
tools: Read, Glob, Grep, Bash, Write, TaskCreate, TaskUpdate, TaskGet, TaskList, Task(apple-developer:security-auditor), Task(ai-engineer:ai-security-auditor)
```

### 9c. `agents/qa-engineer.md` — `ai-test-generator` consult

**BEFORE** (line 9, fragment — the line continues with XcodeBuildMCP/context7/Ref MCP tools):

```yaml
tools: Read, Glob, Grep, Write, Edit, Bash, TaskCreate, TaskUpdate, TaskGet, TaskList, Task(apple-developer:test-generator), mcp__XcodeBuildMCP__session_show_defaults, …
```

**AFTER**:

```yaml
tools: Read, Glob, Grep, Write, Edit, Bash, TaskCreate, TaskUpdate, TaskGet, TaskList, Task(apple-developer:test-generator), Task(ai-engineer:ai-test-generator), mcp__XcodeBuildMCP__session_show_defaults, …
```

---

## 10. `skills/worktask/scripts/detect-ui-change.sh` — verification only (expected no-op)

Do **not** edit this script. Verify that `ai` is absent from the S4
UI-platform case:

**CURRENT** (lines 116–122):

```bash
  # S4 — platform ∈ {apple,web,android} AND scope names UI path classes.
  case "$platform" in
    apple|web|android)
      if printf '%s\n' "$sections" | grep -qE "$UI_PATH_CLASSES" 2>/dev/null; then
        signals+=("S4"); req="true"
      fi ;;
  esac
```

**Why the no-op is correct:** `ai` must never be added to
`apple|web|android` — S4 exists to catch UI path classes on UI-default
platforms, and AI work is non-UI by default. With `--platform ai` the case
falls through, S4 cannot fire, and an AI plan with no S1–S3 signal yields
`requires_screenshots=false` with rationale
`No UI signal in plan scope/requirements (platform=ai)`. S1 (explicit
`ui_visual_check: true`), S2 (design artifacts present), and S3 (UI keywords
in scope) still force `true` — correct for the rare AI task with a real UI
surface. Verify with:

```bash
printf '# t\n## scope\nAdd eval harness for the retriever\n' > /tmp/ai-plan.md
skills/worktask/scripts/detect-ui-change.sh /tmp/ai-plan.md --platform ai
# expect: {"requires_screenshots":false,"signals":[],...}
```

---

## Application checklist (run inside the company-workflow repo)

1. **Apply in this order**: 2 (platform-detection tables) → 1 (developer.md)
   → 8 (product-manager) → 3 (plugin-protocols) → 4/5/6 (command enums) → 7
   (senior-developer-review) → 9 (optional consults). Routing docs land before
   the agents that point at them; command enums last so `--platform ai` never
   resolves to an unregistered route.
2. **Verify surface 10** (detect-ui-change no-op) with the snippet above.
3. **Grep gate** — every new agent reference is fully qualified and real:
   `grep -rn "ai-engineer:" agents/ commands/ skills/ | grep -v "ai-engineer:ai-\|ai-engineer:llm-\|ai-engineer:ml-\|ai-engineer:mlops-"`
   should return no unqualified or misspelled targets (valid names:
   `ai-engineer`, `llm-engineer`, `ml-engineer`, `mlops-engineer`,
   `ai-prompt-engineer`, `ai-architector`, `ai-test-generator`,
   `ai-security-auditor`, `ai-performance-engineer`, `ai-code-fixer`,
   `ai-dependency-manager`).
4. **Run the deterministic suite**: `make test` (or `./run-tests.sh`) — the
   docs edits must not break the bats/state-machine tests; detect-ui-change's
   `--self-test` fixtures are unchanged by design.
5. **Smoke-test routing** with ai-engineer installed:
   `/worktask --platform ai "add a regression gate for the summarizer prompt"`
   → PL0 stamps DV0 `metadata.agent: "ai-engineer:ai-engineer"` and
   `requires_screenshots: false`; the DV artifact carries AI Build Evidence.
6. **Version bump**: this is an additive platform registration — bump
   company-workflow `3.36.0 → 3.37.0` (minor), with the version co-move
   across `plugin.json`, `marketplace.json`, `README.md`, and `MEMORY.md` plus
   a CHANGELOG entry, per the igrsoft `/cc-update` convention. ai-engineer's
   own `igrsoft compatibility` headline then updates to v3.37.0 in its next
   release.
