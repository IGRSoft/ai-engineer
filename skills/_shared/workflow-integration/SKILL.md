---
name: workflow-integration
description: Guide for integrating with igrsoft 11-stage workflow system (v3.36.0). Use when participating in structured workflow stages.
---

# Workflow Integration Guide

When invoked from the igrsoft workflow system, follow these guidelines for seamless collaboration.

## 11-Stage Pipeline (Default)

```
PL → AR → TL → DV → DR → SR → QA → DC → RE → FN → ST
          ↑    ↓    ↑    ↑    ↑              ↑
   ai-engineer agents contribute to AR, DV, DR, SR, QA, and RE
```

| Code | Stage | igrsoft Agent | ai-engineer Contribution |
|------|-------|---------------|--------------------------|
| PL | Planning | product-manager | — |
| AR | Architecture | software-architector | ai-architector (consultation: RAG-vs-finetune-vs-prompt, agent topology, serving architecture) |
| TL | Team Lead | team-lead | — |
| DV | Development | developer → **ai-engineer** | **Primary**: ai-engineer router, llm-engineer, ml-engineer, mlops-engineer, ai-prompt-engineer |
| **DR** | **Developer Review** | **technical-lead** | **Support**: ai-code-fixer (fix application), ai-architector (pattern consult) |
| SR | Security Review | security-reviewer | Context: ai-security-auditor (OWASP LLM Top 10, prompt injection, data leakage, artifact safety) |
| QA | QA Testing | qa-engineer | Support: ai-test-generator (tests + eval harness) |
| DC | Documentation | technical-writer | — |
| RE | Release Engineering | release-engineer | Packaging: ai-dependency-manager (lockfile + model-revision pin freeze), version/artifact preparation |
| FN | Finalization | project-manager | — |
| ST | Stakeholder | stakeholder | — |

## Worktask Invocation (v3.36.0)

Launch is **only** via the `/worktask` slash command (or `Skill igrsoft:worktask`) plus flags. Message-prefix triggers (`micro:`/`quick:`/`worktask:`/`fworktask:`/`emergency:`) are **removed**. PL0 dynamic sizing selects which of the 9 stages run.

| Flag | Effect |
|------|--------|
| `--secure` / `--full` | 11-stage pipeline (adds SR + RE) |
| `--emergency` | Incident pipeline IR→DV→DR→QA→RE→FN (DR enforces minimal-diff) |
| `--auto-plan` | Bypass the PL plan gate |
| `--auto-finalization` | Bypass the FN gate |
| `--ethics-review` | Add ET after PL |
| `--sequential` | DC waits for QA |

Multi-issue batches: `/megatask <milestone#>` or `/megatask --issues 12,15,18` — dependency-DAG ordered, isolated per-issue worktrees.

## Human Checkpoints — PL & FN Gates

Two independent human checkpoints, both carried on PL0 metadata:

| Gate | Carrier | Default | Bypassed by |
|------|---------|---------|-------------|
| PL gate | `PL0.metadata.plan_gate` | `checkpoint` (post-PL0 plan approval) | `--auto-plan` or `--emergency` |
| FN gate | `PL0.metadata.fn_gate` | `checkpoint` (pre-finalization commit/push/PR) | `--auto-finalization` or `--emergency` |

ai-engineer agents are **invoked specialists that run between the gates** — they do not own gate logic. On a gate loop-back, DV/DR/QA may re-run (`retry_count++`, `run_index` bump).

## Per-Stage Contracts (Deep Dive)

Read [references/stage-details.md](references/stage-details.md) before writing any stage artifact — DV contract + AI Build Evidence, screenshot-gate cli-fallback, per-agent error files, DR criteria, QA gate, SR/RE contributions, handoff frontmatter schema, gate-feedback rework contract, token budgets, PL0 dynamic sizing.

## Artifact Filename Contract (v3.36.0)

**Numbered `<stage>-N.md` names are canonical** per igrsoft's authoritative `handoff-protocol.md#stage-artifact-map`. N is allocated by PL0 (same value as `planning-N.md`), shared across all stages within a run, and propagated via `task.metadata.run_index`; it bumps on gate loop-back re-dispatch. Readers fall back to newest-glob (`<basename>-*.md`).

| Stage | Artifact | Owner |
|-------|----------|-------|
| PL | `planning-N.md` | product-manager |
| AR | `analyzing-N.md` | software-architector |
| TL | `coordination-N.md` | team-lead |
| DV | `development-N.md` | developer / ai-engineer agents |
| DR | `developer-review-N.md` | technical-lead |
| SR | `security-review-N.md` | security-reviewer |
| QA | `testing-N.md` | qa-engineer |
| DC | `documentation-N.md` | technical-writer |
| RE | `release-N.md` | release-engineer |
| FN | `complete-summary-N.md` | project-manager |
| ST | `retrospective-N.md` | stakeholder |
| IR | `incident-N.md` | incident-responder |
| ET | `ethics-review-N.md` | ethics-reviewer |

**Emit `handoff:` frontmatter unconditionally — it is the merge input regardless of filename.** state.json reconciliation is three-layered: Layer 1 (agent runs `state-patch.sh --stage <CODE> --prev <PREV>` when its path is supplied, else skips — never a hand-rolled `jq`/manual merge), Layer 2 (orchestrator re-reads artifact frontmatter after `Task()` returns), Layer 3 (`SubagentStop` hook auto-merge). Attempt Layer 1; if the script or its path is absent, proceed — Layers 2 and 3 repair from frontmatter. An artifact without `handoff:` YAML breaks the safety net (degrades to F3 fallback: orchestrator derives a minimal handoff and logs WARN).

## Qualified Agent Names

All Task delegations MUST use the fully-qualified `plugin:agent` form:

| Form | Status |
|------|--------|
| `ai-engineer:llm-engineer` | Required |
| `igrsoft:technical-lead` | Required |
| `llm-engineer` (bare) | Deprecated — back-compat shim prepends `igrsoft:` and logs a warning (would resolve to the wrong plugin) |

Task metadata carries qualified names:

```json
{
  "metadata": {
    "agent": "ai-engineer:llm-engineer",
    "model": "sonnet",
    "error_file": ".context/errors/llm-engineer.md",
    "requires_screenshots": false,
    "plan_file": "planning-0.md",
    "run_index": 0
  }
}
```

## Detecting Workflow Context

1. **Context folder**: `.context/` in project root, or `.worktrees/milestone-{N}/{issue#}/.context/` in worktree mode (resolve via `task.metadata.workspace_path` + `metadata.isolation`).
2. **Plan file**: (1) `task.metadata.plan_file`; (2) newest `.context/planning-*.md`.
3. **State ledger**: read `.context/state.json` for upstream `facts`/`handoffs`/`stages` (≤500-token canonical compressed view). Legacy fallback: `metadata.context_files`.
4. **Architecture document**: newest `.context/analyzing-*.md` — or the anchors named in upstream `next_stage_focus`.
5. **Task System**: TaskList/TaskGet; inspect `task.metadata.{plan_file, agent, model, run_index, error_file, gate_from_stage, gate_blockers, requires_screenshots, workspace_path}`.

## MCP Dynamic Inheritance

Subagents inherit the parent session's MCP tools (Context7, Ref, etc.). Do not redeclare MCP tools in agent frontmatter when the parent session already provides them — redeclaration creates duplicates and bloats permission prompts.

## When Not in Workflow

If no workflow context is detected (no `.context/`, no task metadata), proceed with standard implementation: follow the domain skills, run the same lint/test/eval discipline, and report results directly — no artifacts or frontmatter required.

## Related Skills (igrsoft plugin)

| Skill | Purpose |
|-------|---------|
| `igrsoft:worktask` | Complete worktask system documentation |
| `igrsoft:cross-plugin-handoff` | Handoff protocol between plugins |
| `igrsoft:agent-coordination` | Multi-agent coordination patterns |
| `igrsoft:context-compression` | Token budgets and compression techniques |
| `igrsoft:security-review-process` | SR stage OWASP checklists |
| `igrsoft:release-engineering` | RE stage versioning patterns |

## Related Skills (ai-engineer plugin)

| Skill | Purpose |
|-------|---------|
| `_shared/model-selection.md` | Per-agent model/effort assignments and override paths |
| `_shared/severity-matrix.md` | P0-P3 finding priorities for DR/SR outputs |
| `_shared/framework-detection.md` | Marker → AI stack → agent routing for DV dispatch |
| `skills` (root navigation) | Domain skill index: prompt-engineering, llm-apps, finetuning, mlops, evals |
| `evals` | Eval design, LLM-judge, and regression-gate patterns for QA readiness |
