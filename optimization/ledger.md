# Optimization ledger

## How to run

Process one task at a time, in ledger order. Run each task in a fresh Opus context (e.g. a subagent with `model: opus`) with the prompt:

```
Process {path} ({type}) following optimization/brief.md
```

Don't run tasks in parallel: they share this ledger and can edit the same agents and skills.

This ledger is also the completed list. When a command task cleans up an agent or skill it uses, that row is marked done and its own task is skipped.

## Files

| path | type | status | done by | words before → after | note |
|---|---|---|---|---|---|
| commands/analyze-security.md | command | done | commands/analyze-security.md | 1960 → 1402 | Cut extended-thinking block, shouted rules, duplicated usage/workflow steps and rule restatements; error cases to a table; dropped invalid per-call `effort` override; fixed pip-audit/uv.lock note |
| commands/build-test.md | command | done | commands/build-test.md | 2459 → 1728 | Cut extended-thinking block, shouted rules, restated rules and duplicated tool-availability text; error cases to a table; `skill: framework-detection` (not a real skill) → file path, marker lists deferred to it; log path made literal since shell vars don't persist across Bash calls; dropped CORPFLOW.md/corpflow refs (seam rule) |
| commands/data-audit.md | command | done | commands/data-audit.md | 2034 → 1479 | Cut extended-thinking block, update comment, shouted rules and phase text restating them (PII echo, no-eval-set, read-only); error cases to a table; See Also trimmed; Task tool → Agent tool; data-formats path made explicit |
| commands/deploy-check.md | command | done | commands/deploy-check.md | 2017 → 1514 | Cut update comment, extended-thinking block, shouted rules (merged missing-config/status rules), SYNC POINT marker and closing restatement; error cases to a table; See Also condensed; Task tool → Agent tool. Checklist, verdict rules, output format unchanged |
| commands/eval-run.md | command | todo | | 1938 → | |
| commands/finetune-plan.md | command | todo | | 2480 → | |
| commands/prompt-optimize.md | command | todo | | 2024 → | |
| commands/rag-audit.md | command | todo | | 1922 → | |
| commands/review-code.md | command | todo | | 2883 → | |
| agents/_base/ai-agent.md | agent | todo | | 935 → | |
| agents/ai-architector.md | agent | todo | | 2282 → | |
| agents/ai-code-fixer.md | agent | todo | | 842 → | |
| agents/ai-dependency-manager.md | agent | todo | | 838 → | |
| agents/ai-engineer.md | agent | done | commands/build-test.md | 1307 → 785 | Dropped agent/model table (dup of frontmatter + decision tree) and closing route restatement; `metadata.model` → Agent `model` param; Return Verification condensed, corpflow script name removed; base-inheritance note dropped |
| agents/ai-performance-engineer.md | agent | done | commands/deploy-check.md | 1251 → 1054 | Persona + base-inheritance note to one line; dropped caller-facing Model Notes; 6-step loop to 5 (verify folded into output format); de-shouted GPU/price rules; `disallowed-tools` → `disallowedTools`. Domains, cost levers, output format kept |
| agents/ai-prompt-engineer.md | agent | todo | | 1255 → | |
| agents/ai-security-auditor.md | agent | done | commands/analyze-security.md | 945 → 816 | Persona + base-inheritance note to one line; dropped caller-facing Model Notes; merged Map/Recommend into output format; `disallowed-tools` → `disallowedTools`; pip-audit runs on exported requirements, not uv.lock |
| agents/ai-test-generator.md | agent | todo | | 1307 → | |
| agents/llm-engineer.md | agent | done | commands/build-test.md | 961 → 656 | Persona + dead base-inheritance note to one line; dropped Skills References list (dup of inline Apply lines); tightened rules/DR Focus; single-command Bash rule inlined from unreachable base |
| agents/ml-engineer.md | agent | done | commands/build-test.md | 1369 → 961 | Persona + base note to one line; dropped Skills References list (folded the two non-inline skills into steps); removed dead "(base …)" pointers, inlining the GPU-absence rule they referred to |
| agents/mlops-engineer.md | agent | done | commands/build-test.md | 922 → 600 | Persona + base note to one line; dropped Skills References list (folded into inline refs); tightened rules, capabilities, DR Focus |
| skills/SKILL.md | skill | todo | | 773 → | |
| skills/evals/SKILL.md | skill | todo | | 575 → | |
| skills/evals/eval-design/SKILL.md | skill | todo | | 1067 → | |
| skills/evals/llm-judge/SKILL.md | skill | todo | | 2175 → | |
| skills/evals/regression-gates/SKILL.md | skill | todo | | 1187 → | |
| skills/finetuning/SKILL.md | skill | todo | | 824 → | |
| skills/finetuning/checkpoint-promotion/SKILL.md | skill | todo | | 2045 → | |
| skills/finetuning/dataset-curation/SKILL.md | skill | done | commands/data-audit.md | 2236 → 1852 | Shorter description; persona/overview to two lines; dropped ASCII pipeline diagram (dup of gate table) and Common Rationalizations; Red Flags trimmed to items not in Verification; size table, gates, ledger schema kept (used by data-audit, finetune-plan). references/data-formats.md unchanged |
| skills/finetuning/grpo-rlvr-training/SKILL.md | skill | todo | | 1945 → | |
| skills/finetuning/peft-lora/SKILL.md | skill | todo | | 2118 → | |
| skills/finetuning/preference-tuning/SKILL.md | skill | todo | | 1380 → | |
| skills/finetuning/quantized-export/SKILL.md | skill | todo | | 1921 → | |
| skills/finetuning/trace-to-training-data/SKILL.md | skill | todo | | 1805 → | |
| skills/finetuning/training-optimization/SKILL.md | skill | todo | | 2093 → | |
| skills/llm-apps/SKILL.md | skill | todo | | 594 → | |
| skills/llm-apps/agent-design/SKILL.md | skill | todo | | 2022 → | |
| skills/llm-apps/llm-api-patterns/SKILL.md | skill | todo | | 2267 → | |
| skills/llm-apps/rag-systems/SKILL.md | skill | todo | | 2298 → | |
| skills/mlops/SKILL.md | skill | todo | | 635 → | |
| skills/mlops/experiment-tracking/SKILL.md | skill | todo | | 1156 → | |
| skills/mlops/ml-pipelines/SKILL.md | skill | todo | | 1198 → | |
| skills/mlops/model-monitoring/SKILL.md | skill | todo | | 1065 → | |
| skills/mlops/model-serving/SKILL.md | skill | done | commands/deploy-check.md | 2024 → 1647 | Shorter description; Overview + When to Use (dup of description) folded into one paragraph; dropped Common Rationalizations and Red Flags (dups of anti-patterns/verification), unique points folded in; Related Skills trimmed to non-duplicates. references/serving-stack-matrix.md unchanged (command cites its checklist) |
| skills/prompt-engineering/SKILL.md | skill | todo | | 590 → | |
| skills/prompt-engineering/context-engineering/SKILL.md | skill | todo | | 1002 → | |
| skills/prompt-engineering/prompt-design/SKILL.md | skill | todo | | 2265 → | |
| skills/prompt-engineering/structured-outputs/SKILL.md | skill | todo | | 2015 → | |
| skills/_shared/framework-detection.md | skill | done | commands/build-test.md | 805 → 772 | Light pass: dropped corpflow mentions and CORPFLOW.md ref (seam rule), softened emphasis; tables unchanged (shared by review-code, eval-run, analyze-security) |

## Needs decision

- **`inherits:` frontmatter (all agents)** — not a Claude Code field; subagents never load `agents/_base/ai-agent.md`, so its constraints/routing don't reach them. Inline what each agent needs, or drop the field? (found via commands/analyze-security.md)
- **`disallowed-tools` → `disallowedTools`** — agent frontmatter only recognizes camelCase. Fixed in ai-security-auditor; ai-performance-engineer, README.md, MEMORY.md, skills/_shared/model-selection.md still say `disallowed-tools`. (Redundant anyway where `tools` already omits Write/Edit.)
- **Per-call `effort` override** — skills/_shared/model-selection.md says to pass `model`/`effort` on the Task() call; the Agent tool takes `model` only. Rewrite the override path.
- **`estimated-cost` command frontmatter** — not a Claude Code field (ignored); README advertises it. Keep as plugin metadata or drop?
- **OWASP LLM IDs** — the auditor's LLM01-LLM10 table follows the 2023 v1.1 numbering (LLM05 Supply Chain, LLM06 Sensitive Info…); the 2025 list renumbers (LLM02 Sensitive Info, LLM03 Supply Chain, LLM05 Improper Output Handling, new LLM07/08). Report IDs are an output interface used by analyze-security, review-code, rag-audit — update together?
- **Relative `skills/_shared/...` paths** in agent/command bodies resolve against the user's project cwd, not the plugin root. Use `${CLAUDE_PLUGIN_ROOT}` or inline the needed bits?
- **`## CRITICAL BEHAVIORAL RULES` heading** — all-caps heading kept because scripts/section-lint.sh requires it on every command; rename in the lint and all commands together?
- **Agents can't reach their skills** — llm/ml/mlops-engineer cite `skills/...` paths (unresolvable from the user's cwd) and have neither the `Skill` tool nor a `skills:` frontmatter preload, so skill content likely never reaches them. Add `skills:` preloads, grant `Skill`, or accept? (found via commands/build-test.md)
- **Domain skills cited by build-test's agents left todo** — llm-apps/*, finetuning/*, mlops/*, evals/*, prompt-engineering/*, skills/SKILL.md are in scope via llm/ml/mlops/ai-engineer but were left to their own rows (≈30k words, shared by other commands). (found via commands/build-test.md)
- **`Return Verification` in agents/ai-engineer.md** — restates CORPFLOW.md contract details (handoff frontmatter, state.json patch, screenshot gate) inside an agent, against CORPFLOW's "keep the seam single" rule; condensed but kept since the router may own DV. Move to CORPFLOW.md? (found via commands/build-test.md)
- **Direct toolchain calls vs CORPFLOW "build/test only through /ai-engineer:build-test"** — llm/ml/mlops-engineer and the router still run `uv run pytest`/`ruff` directly; fine outside a worktask, conflicts inside one. (found via commands/build-test.md)
- **build-test exit status through `tee`** — the command pipes every phase through `tee`, so the Bash result is tee's exit code; `${PIPESTATUS[0]}` (bash) / `$pipestatus[1]` (zsh) must be read in the same command line, which the scoped `allowed-tools` patterns may not match. Text now says "judge by the tool's exit status, not tee's"; pick a concrete mechanism? (found via commands/build-test.md)
- **"Task tool" wording in commands** — the subagent tool is now `Agent` (`Task` is a legacy alias). data-audit says "Agent tool"; analyze-security and build-test still say "Task tool", and agent `tools:` lists use `Task(...)`. Align across the repo? (found via commands/data-audit.md)
- **`skills/_shared/severity-matrix.md` has no ledger row** — used by every command for P0-P3; its trailing "Usage" section is meta-instruction for authors. Add a row? (found via commands/data-audit.md)
- **ai-performance-engineer P1+ for unbounded spend** — its Output Format ranks "unbounded spend/loops and OOM-risk configs" P1+, while skills/_shared/severity-matrix.md puts unbounded token spend at P2. Intentional override or drift? (found via commands/deploy-check.md)
- **Peripheral skills cited by deploy-check left todo** — model-monitoring, ml-pipelines, llm-api-patterns (items 8, 9, 5), quantized-export, checkpoint-promotion (See Also) are shared with other commands; left to their own rows. (found via commands/deploy-check.md)
- **model-serving Verification vs serving-stack-matrix Per-Deploy Checklist** — two overlapping checklists (skill's adds canary + gateway; reference's adds engine version, streaming, load test). Merge into one? (found via commands/deploy-check.md)
