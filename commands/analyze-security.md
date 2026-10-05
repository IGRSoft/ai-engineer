---
description: OWASP LLM Top 10 sweep of AI code, prompts, and dependencies via ai-engineer:ai-security-auditor — scanner-backed, mapped to LLM01-LLM10 + CWE with P0-P3. Use before release or after changes touching prompts, tools, or model artifacts.
argument-hint: [scope: file/dir/PR#/branch — default: working changes] [--deps-only] [--prompts-only]
allowed-tools: Read, Agent, Glob, Grep, Bash
---

# AI Security Scan

Sweep the AI surfaces in scope against the OWASP Top 10 for LLM Applications by delegating to the review-only `ai-engineer:ai-security-auditor`, armed with whichever scanners this machine has. Findings come back mapped to LLM01-LLM10 plus CWE, ranked P0-P3, deduplicated against any same-session code review, and routed to a remediation agent.

## Rules

1. **Read-only.** Neither this command nor the auditor edits files. Remediation is routed, not applied: code fixes → `ai-engineer:ai-code-fixer`, dependency/pin fixes → `ai-engineer:ai-dependency-manager`. There is deliberately no `--fix` flag.
2. **Resolve the scope once**, print the file list, and pass it to the auditor. `--deps-only` / `--prompts-only` filter that list rather than re-deriving it.
3. **Probe scanners before delegating.** A missing scanner is a named reduced-depth note in the report, not a failure and not a silent gap — each scanner sees a slice the others miss.
4. **No exploit code.** Findings describe attack path, impact, and fix; include no working exploit payloads, jailbreak strings, or injection strings beyond the minimal fragment needed to locate the flaw.
5. **Secrets are pointers.** Report a secret as `file:line` + type + detecting scanner, never its value or a decodable fragment — in the report, log, or delegation prompt. Recommend rotation regardless of history cleanup.
6. **Dedupe against same-session review.** If `/ai-engineer:review-code` ran earlier this session, merge overlapping findings at `{file, line}`: keep the higher severity, mark "also flagged by code review".
7. **No manufactured findings.** A clean scan is a valid result: report posture and the controls verified.
8. Execute directly; don't enter plan mode.

## Usage

```bash
/ai-engineer:analyze-security                  # working changes
/ai-engineer:analyze-security src/agents/      # file, dir, or . for whole repo
/ai-engineer:analyze-security 87               # PR number or branch name
/ai-engineer:analyze-security --deps-only
/ai-engineer:analyze-security --prompts-only
```

## Options

| Option | Default | Effect |
|--------|---------|--------|
| `scope` | working changes | File, directory, PR number, or branch. |
| `--deps-only` | off | Supply-chain surface only: manifests + lockfiles (`pyproject.toml`, `uv.lock`, `requirements*.txt`), model-artifact loading (`from_pretrained` pins, pickle vs safetensors, `trust_remote_code`), CVE scans. Findings concentrate in LLM05; remediation routes to `ai-engineer:ai-dependency-manager`. |
| `--prompts-only` | off | Prompt assets plus prompt-assembly and output-handling code: injection (LLM01), insecure output handling (LLM02), secrets/PII in prompts, templates, and logs (LLM06). |

## Scope Resolution

Same precedence as `/ai-engineer:review-code`:

1. **Explicit args** — file/dir directly; PR via `gh pr diff <N> --name-only`; branch via `git diff --name-only $(git merge-base origin/HEAD <branch>)..<branch>` (merge-base with the default branch, not `HEAD`, or the range is empty).
2. **Working changes** (default) — `git diff --name-only HEAD` plus `git diff --cached --name-only`.
3. **Fallback** — current branch vs the default branch's merge-base.

Then widen: add the manifests/lockfiles governing the scope and the prompt templates and tool registries the changed code touches; list changed binary/model artifacts (`*.safetensors`, `*.gguf`, checkpoints) separately for supply-chain assessment rather than line review. Apply `--deps-only` / `--prompts-only` last and print the final list. `--deps-only` on a no-diff scope uses the lockfile/manifest set.

## Scanner Probe

Probe each with `command -v` and print present / missing + hint:

| Scanner | Lens | Install hint |
|---------|------|--------------|
| `pip-audit` | Python dependency CVEs (needs a requirements-format file, not `uv.lock`) | `uv tool install pip-audit` |
| `osv-scanner` | cross-ecosystem CVEs over lockfiles, incl. `uv.lock` | `brew install osv-scanner` |
| `gitleaks` | secrets in working tree + history | `brew install gitleaks` |
| `trufflehog` | secrets with credential verification | `brew install trufflehog` |
| `bandit` | Python anti-patterns (`eval`/`exec`, `shell=True`, pickle, `yaml.load`) | `uv tool install bandit` |
| `semgrep` | pattern rules — injection sinks, hardcoded creds, LLM rulesets | `uv tool install semgrep` |

## Workflow

### Phase 1: Scope + Probe

Resolve and print the scope, then probe scanners. Nothing AI-relevant in scope → Error Handling, stop.

### Phase 2: Delegated Audit

Use the Agent tool with `subagent_type="ai-engineer:ai-security-auditor"`. Prompt:

"Read-only OWASP LLM Top 10 audit. Scope ({full | --deps-only | --prompts-only}): {file_list}. Changed binary/model artifacts: {artifact_list_or_none}. Scanners available: {list}; missing: {list} — for missing lenses fall back to manual pattern review and record the reduced depth. Run the available scanners over the scope, then your manual sweep, and verify every candidate in the surrounding code. Also check exposed model endpoints. Do not write or edit; include no working exploit payloads or jailbreak strings; report secrets as file:line + type + scanner, never the value. Return findings as `{file, line, llm_id, cwe, severity, why, fix, confidence}` plus the control checklist. If there are no material issues, say so."

For deep threat modeling of a large agent/tool surface, pass `model: "opus"` (see `${CLAUDE_PLUGIN_ROOT}/skills/_shared/model-selection.md`).

### Phase 3: Synthesis & Routing

1. Drop speculative or unverified findings; dedupe per Rule 6.
2. Group by LLM01-LLM10, rank P0-P3 within each group.
3. Route: mechanical code fixes → `ai-engineer:ai-code-fixer`; CVE bumps, HF revision pins, lockfile → `ai-engineer:ai-dependency-manager`; design-level items (agent topology, trust zones) → the owning domain engineer with an `ai-engineer:ai-architector` consult.
4. If the auditor echoed a secret value, redact it before emitting the report.
5. Emit the report.

## Output Format

```markdown
## AI Security Scan Report

**Scope:** {resolved scope} ({full | --deps-only | --prompts-only})
**Files scanned:** {N} (+ {manifests/lockfiles widened in})
**Scanners:** {present list} | missing: {list or "none"}
**Dedup:** {n} findings merged with same-session code review | n/a

### Summary
{One or two sentences. If clean: "No material AI security issues found in scope — controls verified below." Otherwise counts by priority.}

| Priority | Count |
|----------|-------|
| P0 | {n} |
| P1 | {n} |
| P2 | {n} |
| P3 | {n} |

### Findings by OWASP LLM Top 10
<!-- Only categories with findings; keep the LLMxx header on each -->

#### LLM01 — Prompt Injection
| Priority | File:Line | CWE | Why | Fix | Confidence |
|----------|-----------|-----|-----|-----|------------|
| P0 | src/rag/answer.py:88 | CWE-77 | retrieved doc text enters the system segment unmarked | delimit + privilege-separate retrieved content | high |

### Secrets (pointers only — values withheld)
| File:Line | Type | Scanner | Action |
|-----------|------|---------|--------|
| {file}:{line} | {e.g. provider API key} | gitleaks | rotate now; purge from history; load from env |

### Remediation Routing
| Route | Findings |
|-------|----------|
| `ai-engineer:ai-code-fixer` (minimal-diff code fixes) | {finding refs} |
| `ai-engineer:ai-dependency-manager` (CVE bumps, revision pins, lockfile) | {finding refs} |
| Manual / design ({owning engineer} + `ai-engineer:ai-architector`) | {finding refs} |

### Controls Verified
- [ ] no untrusted input in privileged prompt segments
- [ ] model output validated at every trust boundary
- [ ] artifacts safetensors + pinned revisions; no trust_remote_code
- [ ] secrets/PII absent from code, prompts, logs, datasets
- [ ] dependencies CVE-clear at scan time
- [ ] tool execution gated; human-in-the-loop on irreversible actions

<!-- When a scanner was unavailable: -->
### Reduced-Depth Notes
- {lens}: {scanner} missing — manual pattern review only. Install: {hint}.
```

## Error Handling

| Condition | Response |
|-----------|----------|
| Nothing AI-relevant in scope (no code, prompts, configs, or manifests per `${CLAUDE_PLUGIN_ROOT}/skills/_shared/framework-detection.md`) | Print the resolved scope; suggest an explicit path, or the security-scanning plugin for a general (non-AI) sweep. |
| No changes (default scope) | Suggest a path, branch, or PR — or `--deps-only`, which scans the lockfile/manifest set on a clean tree. |
| `gh` missing for a PR scope | Print `brew install gh` then `gh auth login`; fall back to a branch diff against the default branch. |
| All scanners missing | Proceed with manual review only; state the degraded recall at the top of the report with aggregated install hints. |
| Filter leaves no files | Suggest dropping the filter or pointing at the tree that holds that surface. |

## See Also

- `${CLAUDE_PLUGIN_ROOT}/skills/_shared/severity-matrix.md` — P0-P3 definitions.
- `/ai-engineer:review-code` — includes an always-on security pass; this command is the deeper, scanner-backed sweep.
- `ai-engineer:ai-security-auditor` — the delegated agent; its LLM01-LLM10 table is the canonical hunt list.
- `corpflow:security-review-process` — the SR-stage checklist this scan feeds inside a worktask.
