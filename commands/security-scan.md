---
description: OWASP LLM Top 10 sweep of AI code, prompts, and dependencies via ai-engineer:ai-security-auditor — scanner-backed, mapped to LLM01-LLM10 + CWE with P0-P3. Use before release or after changes touching prompts, tools, or model artifacts.
argument-hint: [scope: file/dir/PR#/branch — default: working changes] [--deps-only] [--prompts-only]
allowed-tools: Read, Glob, Grep, Bash
estimated-cost:
  min-tokens: 4000
  max-tokens: 20000
  model-distribution:
    sonnet: 85%
    haiku: 15%
---

# AI Security Scan
<!-- Updated: July 2026 -->

Sweep the AI surfaces in scope against the OWASP Top 10 for LLM Applications — prompt injection, insecure output handling, model supply chain, secret/PII leakage, ungated agency — by delegating to the review-only `ai-engineer:ai-security-auditor`, armed with whatever scanners this machine actually has. Findings come back mapped to LLM01-LLM10 plus CWE, ranked P0-P3, deduplicated against any same-session code review, and routed to the right remediation agent.

[Extended thinking: AI security review is recall-first — secrets scanners, CVE scanners, and pattern scanners each see a different slice, and the auditor's manual pass covers what none of them can (an untrusted retrieval result flowing into a privileged prompt segment is invisible to every scanner). So this command probes scanner availability first and tells the auditor exactly which lenses it has: a missing scanner reduces depth and must be said out loud, never silently absorbed. Two hard lines shape the output. Findings describe risk and fix but never include working exploit payloads — the report should make the defender faster, not arm an attacker. And discovered secrets are reported as file:line pointers with a type label only; echoing a live credential into a report would itself be the leak the scan exists to prevent.]

## CRITICAL BEHAVIORAL RULES

You MUST follow these rules exactly. Violating any of them is a failure.

1. **Read-only.** Neither this command nor the auditor writes or edits (the auditor carries `disallowed-tools: Write, Edit`). Remediation is routed, never applied inline: code fixes → `ai-engineer:ai-code-fixer`, dependency/pin fixes → `ai-engineer:ai-dependency-manager`.
2. **Resolve the scope once** (explicit args > working diff > branch/PR diff), print the concrete file list, and pass it to the auditor. `--deps-only` / `--prompts-only` filter that list — they do not re-derive it.
3. **Probe scanners before delegating.** Check `pip-audit`, `osv-scanner`, `gitleaks`, `trufflehog`, `bandit`, `semgrep` with `command -v` and pass the availability report to the auditor. A missing scanner = a named reduced-depth note in the final report — never a hard failure, never a silent gap.
4. **No exploit code.** Findings describe the attack path, impact, and fix. NEVER generate working exploit payloads, jailbreak strings, or injection strings beyond the minimal fragment needed to locate the flaw.
5. **Secrets are pointers.** A discovered secret is reported as `file:line` + secret type + detecting scanner. NEVER echo the secret value (or a decodable fragment) into the report, the log, or a delegation prompt. Recommend immediate rotation regardless of any history cleanup.
6. **Dedupe against same-session review.** If `/ai-engineer:code-review` ran earlier this session, merge overlapping security findings at `{file, line}` — keep the higher severity, mark provenance "also flagged by code review" — so the user gets one list, not two.
7. **No manufactured findings.** A clean scan is a valid result: report posture and the controls verified, not invented P3s.
8. **Never enter plan mode.** This command IS the procedure — execute it.

## Usage

```bash
# Sweep your current working changes
/ai-engineer:security-scan

# Sweep a directory or the whole repo
/ai-engineer:security-scan src/agents/
/ai-engineer:security-scan .

# Sweep a PR or branch
/ai-engineer:security-scan 87
/ai-engineer:security-scan feature/tool-use

# Dependency / supply-chain surface only
/ai-engineer:security-scan --deps-only

# Prompt-injection / leakage surface only
/ai-engineer:security-scan --prompts-only
```

## Options

| Option | Default | Effect |
|--------|---------|--------|
| `scope` | working changes | File, directory, PR number, or branch. Same precedence as `/ai-engineer:code-review` Phase 0. |
| `--deps-only` | off | Restrict to the supply-chain surface: manifests + lockfiles (`pyproject.toml`, `uv.lock`, `requirements*.txt`), model-artifact loading (`from_pretrained` pins, pickle vs safetensors, `trust_remote_code`), CVE scans. Findings concentrate in LLM05; remediation routes to `ai-engineer:ai-dependency-manager`. |
| `--prompts-only` | off | Restrict to prompt assets plus prompt-assembly and output-handling code: injection paths (LLM01), insecure output handling (LLM02), secrets/PII in prompts, templates, and logs (LLM06). |

## Scope Resolution

Same precedence as `/ai-engineer:code-review`, applied **once**:

1. **Explicit args** — file/dir reviewed directly; PR number via `gh pr diff <N> --name-only` (`gh` missing → install hint, fall back to rule 3); branch via `git diff --name-only $(git merge-base HEAD <branch>)..<branch>`.
2. **Working changes** (default) — `git diff --name-only HEAD` plus `git diff --cached --name-only`.
3. **Fallback** — current branch vs the default branch's merge-base.

Then widen for security relevance: always include the manifests/lockfiles governing the scope, plus the prompt templates and tool registries the changed code touches; note changed binary/model artifacts (`*.safetensors`, `*.gguf`, checkpoints) for supply-chain assessment rather than line review. Apply `--deps-only` / `--prompts-only` last and print the final list. `--deps-only` on a no-diff scope uses the lockfile/manifest set as the scope.

## Scanner Probe

Probe with `command -v <tool>` and build the availability report the auditor receives:

| Scanner | Lens | Install hint (if missing) |
|---------|------|---------------------------|
| `pip-audit` | Python dependency CVEs from `uv.lock`/requirements | `uv tool install pip-audit` |
| `osv-scanner` | cross-ecosystem CVE lookup over lockfiles | `brew install osv-scanner` |
| `gitleaks` | secrets in working tree + git history | `brew install gitleaks` |
| `trufflehog` | secret detection with credential verification | `brew install trufflehog` |
| `bandit` | Python security anti-patterns (`eval`/`exec`, `shell=True`, pickle, `yaml.load`) | `uv tool install bandit` |
| `semgrep` | pattern rules — injection sinks, hardcoded creds, LLM rulesets | `uv tool install semgrep` |

A missing scanner degrades that lens to the auditor's manual grep patterns — a real reduction in recall the report must name (Rule 3).

## Workflow

### Phase 1: Scope + Probe (Bash)

1. Resolve the scope per Scope Resolution; apply filters; print the file list.
2. Probe the scanners; print the availability report (present / missing + hints).
3. Nothing AI-relevant in scope → Error Handling and stop.

### Phase 2: Delegated Audit

**Use Task tool with subagent_type="ai-engineer:ai-security-auditor"**
Prompt: "Read-only OWASP LLM Top 10 audit. Scope ({full | --deps-only | --prompts-only}): {file_list}. Changed binary/model artifacts: {artifact_list_or_none}. Scanner availability: available {list}; missing {list} — for missing lenses fall back to manual pattern review and record the reduced depth. Run the available scanners over the scope (pip-audit/osv-scanner on lockfiles, gitleaks/trufflehog for secrets, bandit/semgrep on Python), then your manual sweep: prompt-injection paths (direct + indirect via retrieval/tool results), insecure output handling into exec/subprocess/SQL/render/file sinks, artifact safety (pickle vs safetensors, trust_remote_code, unpinned HF revisions), secrets/PII in code, prompts, logs, or datasets, unbounded spend/DoS, ungated tool execution and excessive agency, and exposed model endpoints. Verify every scanner candidate in the surrounding code before reporting it. Map each finding to LLM01-LLM10 plus CWE where applicable; grade P0-P3 per skills/_shared/severity-matrix.md. HARD RULES: do not write or edit; no working exploit payloads or jailbreak strings; report secrets as file:line + type + scanner — never the value. Return findings as `{file, line, llm_id, cwe, severity, why, fix, confidence}` plus a control checklist. If there are no material issues, say so directly."

For deep threat modeling of a large agent/tool surface, override per `skills/_shared/model-selection.md`: pass `model: "opus"`, `effort: "xhigh"` on the Task call.

### Phase 3: Synthesis & Routing

1. **Collect** the auditor's findings; drop anything speculative or unverified (Rule 7).
2. **Dedupe** against same-session `/ai-engineer:code-review` security findings (Rule 6).
3. **Group** by LLM01-LLM10 and rank P0-P3 within each group.
4. **Route remediation**: mechanical code fixes → `ai-engineer:ai-code-fixer`; dependency/pin/lockfile fixes (CVE bumps, HF revision pins) → `ai-engineer:ai-dependency-manager`; design-level items (agent topology, trust-zone redesign) → the owning domain engineer with an `ai-engineer:ai-architector` consult. This command routes — it does not apply fixes (Rule 1); there is deliberately no `--fix` flag.
5. **Emit** the Output Format report.

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

#### LLM05 — Supply Chain
{same table shape — and so on for each category with findings}

### Secrets (pointers only — values withheld per Rule 5)
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

### Nothing AI-relevant in scope
```
Note: No AI-relevant sources in the resolved scope (no code, prompts, configs, or
manifests per skills/_shared/framework-detection.md).
Resolved scope: {scope}
Suggestion: Pass an explicit path, or use the security-scanning plugin for a
general (non-AI) sweep.
```

### No changes detected (default scope)
```
Note: No staged or unstaged changes to scan.
Suggestion: Name a path, branch, or PR number — or run --deps-only, which scans
the lockfile/manifest set even with a clean tree.
```

### `gh` unavailable for a PR scope
Print the install hint (`brew install gh`, then `gh auth login`) and fall back to a branch diff against the default branch.

### All scanners missing
Proceed with the auditor's manual pattern review only, state the degraded recall prominently at the top of the report, and print the aggregated install hints. Reduced depth — never a silent pass.

### Filter yields an empty set
```
Note: {--deps-only | --prompts-only} left no files in scope.
Suggestion: Drop the filter, or point the scan at the tree that holds that surface.
```

### Auditor echoes a secret value
Redact it before emitting the report and restate Rule 5 in any follow-up prompt — output-side defense in depth.

## See Also

- `skills/_shared/severity-matrix.md` — P0-P3 definitions used for ranking.
- `skills/_shared/framework-detection.md` — AI-surface markers used for scope relevance.
- `/ai-engineer:code-review` — includes an always-on security pass; this command is the deeper, scanner-backed sweep.
- `ai-engineer:ai-security-auditor` — the review-only agent this command delegates to (its LLM01-LLM10 domain table is the canonical hunt list).
- `ai-engineer:ai-code-fixer` / `ai-engineer:ai-dependency-manager` — the two remediation routes.
- `igrsoft:security-review-process` — the SR-stage checklist this scan feeds inside a worktask.

A clean report lists what was verified — and a found secret gets rotated, never re-printed.
