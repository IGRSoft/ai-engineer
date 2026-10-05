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
| commands/eval-run.md | command | done | commands/eval-run.md | 1938 → 1548 | Cut update comment, extended-thinking block (kept its two "because"s inline), shouted rules, phase steps restating rules, closing restatement; usage condensed; error cases to a table; `${PIPESTATUS[0]}` → "suite's exit status, not tee's" (as build-test); Task tool → Agent tool; See Also dropped framework-detection + ai-test-generator dups |
| commands/finetune-plan.md | command | done | commands/finetune-plan.md | 2480 → 1845 | Cut update comment, extended-thinking block (kept its "because" in the intro), shouted rules, Rule 3/6 restatements across Options/Phase 0/Phase 2, duplicated base-model text, closing restatement; error cases to a table; See Also condensed; Task tool → Agent tool; dropped invalid per-call `effort` override |
| commands/prompt-optimize.md | command | done | commands/prompt-optimize.md | 2024 → 1524 | Cut update comment, extended-thinking block (kept its "because" in the intro), shouted rules, phase text restating Rules 1/3/5/7, closing restatements; usage condensed; error cases to a table; Task tool → Agent tool; dropped corpflow logging-conventions ref (seam rule); See Also trimmed to non-dups |
| commands/rag-audit.md | command | done | commands/rag-audit.md | 1922 → 1616 | Cut update comment, extended-thinking block (kept its two "because"s in intro/rules), shouted rules, SYNC POINT, phase text restating Rules 2/3/4; usage condensed; error cases to a table; See Also merged tuning-ref dup and dropped agent/severity dups; Task tool → Agent tool; dropped corpflow logging-conventions ref (seam rule). Map, options, agent prompts, output format unchanged |
| commands/review-code.md | command | done | commands/review-code.md | 2883 → 1869 | Cut update comment, extended-thinking block (kept its "because" in the intro), shouted rules, SYNC POINT and closing restatement; four Focus+Prompt pairs → one prompt template + focus table; Phase 3 no longer restates Rules 5/6/8; error cases to a table; Task tool → Agent tool; `/system-developer:code-review` → `review-code` (the real command) |
| skills/_shared/agent-base.md (was agents/_base/ai-agent.md) | agent | done | agents/_base/ai-agent.md | 935 → 712 | G1: moved to a maintainer reference doc (no agent inherits it), skill paths → `ai-engineer:<skill>` names. De-shouted; Tool Priority folded into Constraints (uv-first, single-command, verify-via-Context7 each stated once; "read before edit" dropped); comment-policy table → bullets; Context7 routing row dropped (in Constraints). Delegation table and response format unchanged |
| agents/ai-architector.md | agent | done | commands/finetune-plan.md | 2282 → 2036 | Persona + dead base-inheritance note to one line; dropped finetune-plan caller note, worked example, Guardrails/Constraints overlap; de-shouted; Decision Frameworks tables, Compressed Return, ADR format unchanged |
| agents/ai-code-fixer.md | agent | done | commands/review-code.md | 842 → 561 | Persona + base-inheritance note to one line; Capabilities folded into Response Approach; 4 workflow subsections → numbered list; verification step merged into the checklist; Constraints de-duplicated against playbooks/checklist; escalation rule moved below the table |
| agents/ai-dependency-manager.md | agent | done | agents/ai-dependency-manager.md | 838 → 722 | Dropped stale base-inheritance list (inlined the single-command Bash rule with its reason); Constraints de-duplicated against Capabilities/workflow and de-shouted; pip-audit now runs on `uv export` output (can't read uv.lock); Capabilities split into two sections to fit section-lint cap; output format, Compressed Return unchanged |
| agents/ai-engineer.md | agent | done | commands/build-test.md | 1307 → 785 | Dropped agent/model table (dup of frontmatter + decision tree) and closing route restatement; `metadata.model` → Agent `model` param; Return Verification condensed, corpflow script name removed; base-inheritance note dropped |
| agents/ai-performance-engineer.md | agent | done | commands/deploy-check.md | 1251 → 1054 | Persona + base-inheritance note to one line; dropped caller-facing Model Notes; 6-step loop to 5 (verify folded into output format); de-shouted GPU/price rules; `disallowed-tools` → `disallowedTools`. Domains, cost levers, output format kept |
| agents/ai-prompt-engineer.md | agent | done | commands/prompt-optimize.md | 1255 → 954 | Persona + dead base-inheritance note to one line; routing callout → one Scope line; ASCII loop → numbered list with its bullets folded in; Skills References folded into Capabilities/loop; Response Approach 8 → 6 (dups of loop cut); single-command Bash rule inlined. Review checklist (used by review-code) unchanged |
| agents/ai-security-auditor.md | agent | done | commands/analyze-security.md | 945 → 816 | Persona + base-inheritance note to one line; dropped caller-facing Model Notes; merged Map/Recommend into output format; `disallowed-tools` → `disallowedTools`; pip-audit runs on exported requirements, not uv.lock |
| agents/ai-test-generator.md | agent | done | commands/eval-run.md | 1307 → 1104 | Persona + base-inheritance note to one line; de-shouted rules; Skills References list folded into Test Categories (one line); execution loop 6 → 4 steps; single-command Bash rule inlined from unreachable base with its reason; dropped "never re-Read" and "read before writing" |
| agents/llm-engineer.md | agent | done | commands/build-test.md | 961 → 656 | Persona + dead base-inheritance note to one line; dropped Skills References list (dup of inline Apply lines); tightened rules/DR Focus; single-command Bash rule inlined from unreachable base |
| agents/ml-engineer.md | agent | done | commands/build-test.md | 1369 → 961 | Persona + base note to one line; dropped Skills References list (folded the two non-inline skills into steps); removed dead "(base …)" pointers, inlining the GPU-absence rule they referred to |
| agents/mlops-engineer.md | agent | done | commands/build-test.md | 922 → 600 | Persona + base note to one line; dropped Skills References list (folded into inline refs); tightened rules, capabilities, DR Focus |
| skills/SKILL.md | skill | done | skills/SKILL.md | 773 → 517 | Shorter description; Overview cut to a pointer at references/conventions.md; Quick Navigation + five one-line domain sections + Shared/Conventions/Related merged into one Domains table; wrong "28 SKILL.md" total dropped; stale "workflow integration" shared row fixed. "I need help with..." table unchanged (README cites it). skills/_index.md 984 → 854: count fixed to 27, stale corpflow/_shared "1 + refs" fixed, Child Indexes table (dup of Domains) dropped. references/conventions.md unchanged (already clean) |
| skills/evals/SKILL.md | skill | done | skills/evals/SKILL.md | 575 → 352 | Shorter description; tagline dropped; Selection Guide + Decision Tree + File Overview + Related Skills (four overlapping route lists) merged into Where to Go + Adjacent Skills tables; broken `${CLAUDE_SKILL_DIR}/llm-apps/...` cross-tree paths (resolve under evals/) → `../` links; `python-skills (python-testing)` → `system-developer:python-testing`. Determinism Snapshot unchanged. _index.md 256 → 242: same path fix, CORPFLOW.md row dropped (seam rule) |
| skills/evals/eval-design/SKILL.md | skill | done | commands/prompt-optimize.md | 1067 → 699 | Shorter description; Overview/When-to-Use → intro + Elsewhere list; dropped Common Rationalizations and Red Flags (unique points → Anti-Patterns/Verification); unconfirmed CORPFLOW.md QA citation removed. references/eval-methodology.md 1452 → 1429: de-shouted; cited §§ Statistical Honesty, Failure Analysis Workflow unchanged |
| skills/evals/llm-judge/SKILL.md | skill | done | commands/prompt-optimize.md | 2175 → 1765 | Shorter description; Overview/When-to-Use → intro + Elsewhere list; dropped Common Rationalizations and Red Flags (unique points → Calibration/Determinism); judge-versioning rule (prompt-optimize Rule 6) made explicit. references/judge-prompt-templates.md 1360 → 1371: prose de-shouted, judge templates verbatim, fixed eval-design safety-row pointer |
| skills/evals/regression-gates/SKILL.md | skill | done | commands/eval-run.md | 1187 → 819 | Shorter description; Overview + When to Use folded into one paragraph; dropped Common Rationalizations and Red Flags (dups of anti-patterns/verification; provisional-floor and stale-baseline points folded in); unconfirmed CORPFLOW.md citations removed. references/gate-implementation.md 1233 → 1214: de-shouted, fixed `§ Failure Analysis Workflow` anchor |
| skills/finetuning/SKILL.md | skill | done | skills/finetuning/SKILL.md | 824 → 424 | Shorter description; tagline cut; Selection Guide + Decision Tree + File Overview + Related Skills (overlapping route lists, duplicate trace-to-training-data row) merged into Where to Go + Adjacent Skills tables; broken `${CLAUDE_SKILL_DIR}/mlops|evals|_shared/...` paths → `../` links. Stack Snapshot unchanged. _index.md 478 → 388: leaf summaries synced to the trimmed descriptions, same path fix, CORPFLOW.md row dropped (seam rule) |
| skills/finetuning/checkpoint-promotion/SKILL.md | skill | done | commands/finetune-plan.md | 2045 → 1356 | Shorter description; dropped Overview/When-to-Use; When-NOT + Related merged; Red Flags cut (two unique items → Anti-Patterns); gate, drift budget, REJECT (uncertain), verdict block unchanged; reference trimmed closing restatement |
| skills/finetuning/dataset-curation/SKILL.md | skill | done | commands/data-audit.md | 2236 → 1852 | Shorter description; persona/overview to two lines; dropped ASCII pipeline diagram (dup of gate table) and Common Rationalizations; Red Flags trimmed to items not in Verification; size table, gates, ledger schema kept (used by data-audit, finetune-plan). references/data-formats.md unchanged |
| skills/finetuning/grpo-rlvr-training/SKILL.md | skill | done | commands/finetune-plan.md | 1945 → 1344 | Shorter description; dropped routing preamble, Overview/When-to-Use, Anti-Patterns table (rows restated body; one fix moved to inspection list); preconditions, config, inspection gate, variant table kept; reference de-shouted |
| skills/finetuning/peft-lora/SKILL.md | skill | done | commands/finetune-plan.md | 2118 → 1732 | Shorter description; Overview/When-to-Use folded into intro; dropped Common Rationalizations and Red Flags dup'd by Verification; configs, scenario table, smoke loop, lifecycle unchanged; reference unchanged |
| skills/finetuning/preference-tuning/SKILL.md | skill | done | commands/finetune-plan.md | 1380 → 927 | Shorter description; When/When-NOT merged into one routing list; dropped Common Rationalizations; Red Flags folded into Verification; selection table, beta rule kept; fixed relative data-formats path; reference de-shouted only |
| skills/finetuning/quantized-export/SKILL.md | skill | done | commands/finetune-plan.md | 1921 → 1426 | Shorter description; Overview to 2-line intro; Red Flags cut (two unique → Anti-Patterns/Verification); made capture-pre-export-generations explicit (finetune-plan relies on it); reference: defined missing BASE_REV; G6: `tools.generate`/`tools.quantize`/`BASE_REV` labeled project placeholders |
| skills/finetuning/trace-to-training-data/SKILL.md | skill | done | commands/finetune-plan.md | 1805 → 1103 | Shorter description; intro/Overview/When merged with an Elsewhere list; Red Flags dup'd by Verification cut; fixed nonexistent 'format checker' and 'embedding-similarity sweep' refs; reference light pass; G6: recipes fixed (task_id in every provenance, leak check fails closed on untraceable rows, `_user_turn`/`_assistant_turn` defined, `build_pairs` skips tasks with no failing traces) |
| skills/finetuning/training-optimization/SKILL.md | skill | done | commands/finetune-plan.md | 2093 → 1792 | Shorter description; dropped Overview/When-to-Use, Common Rationalizations, Red Flags (unique items folded in); ASCII fit ladder → table; memory model, smoke-scale rule, two-host workflow kept; references de-shouted; G6: restored "distributed training" to description |
| skills/llm-apps/SKILL.md | skill | done | skills/llm-apps/SKILL.md | 594 → 402 | Shorter description; tagline cut; Selection Guide + Decision Tree + File Overview + Related Skills (four overlapping route lists) merged into Where to Go + Adjacent Skills tables; broken `${CLAUDE_SKILL_DIR}/prompt-engineering|mlops|evals/...` paths → `../` links. Stack Snapshot and owner/escalation line unchanged. _index.md 254 → 246: rag-systems/llm-api-patterns summaries synced to their trimmed descriptions, same path fix, CORPFLOW.md row dropped (seam rule) |
| skills/llm-apps/agent-design/SKILL.md | skill | done | skills/llm-apps/agent-design/SKILL.md | 2022 → 1519 | Shorter description; Overview/When-to-Use → intro + Elsewhere list; ASCII ladder and loop diagrams dropped (dup of table and code); Common Rationalizations and Red Flags dropped (unique points → Guardrails, Verification); de-shouted. Ladder, stop-condition table, code samples, Verification kept. references/tool-design.md 1142 → 1077: use-when/skip header condensed; example tool descriptions (product text) unchanged |
| skills/llm-apps/llm-api-patterns/SKILL.md | skill | done | agents/_base/ai-agent.md | 2267 → 1869 | Shorter description; Overview/When-to-Use → intro + Elsewhere list; dropped Common Rationalizations and Red Flags (unique points → timeout, 429, caching-layout, fallback-drill, `.env` text); de-shouted. Code samples, Anti-Patterns, Verification kept; provider-matrix intro condensed |
| skills/llm-apps/rag-systems/SKILL.md | skill | done | commands/rag-audit.md | 2298 → 1967 | Shorter description; Overview/When-to-Use → intro + Elsewhere list; dropped Common Rationalizations and Red Flags (unique points → rerank/freshness text, one Anti-Patterns row, Verification); unreachable `agents/_base/ai-agent.md` determinism cite inlined; de-shouted. Section names (Debug Retrieval First, Verification) and grounded template kept. references/ unchanged (already clean) |
| skills/mlops/SKILL.md | skill | done | skills/mlops/SKILL.md | 635 → 425 | Shorter description; tagline cut; Selection Guide + Decision Tree + File Overview + Related Skills (four overlapping route lists) merged into Where to Go + Adjacent Skills tables; broken `${CLAUDE_SKILL_DIR}/evals|finetuning|llm-apps/...` paths → `../` links. Stack Snapshot and owner/escalation line unchanged. _index.md 296 → 270: experiment-tracking/model-serving summaries synced to their trimmed descriptions, same path fix, CORPFLOW.md row dropped (seam rule) |
| skills/mlops/experiment-tracking/SKILL.md | skill | done | agents/_base/ai-agent.md | 1156 → 664 | Shorter description; Overview/When-to-Use/Related Skills → intro + Elsewhere list; duplicate Deep Dives pointer merged; dropped Common Rationalizations and Red Flags (covered by Anti-Patterns/Verification). Contract table unchanged; references/ unchanged (already clean) |
| skills/mlops/ml-pipelines/SKILL.md | skill | done | skills/mlops/ml-pipelines/SKILL.md | 1198 → 814 | Shorter description; Overview/When-to-Use/Related Skills → intro + Elsewhere list; Deep Dives pointer folded into DAG section; dropped Common Rationalizations and Red Flags (unique points → `dvc.lock` anti-pattern row, metrics-file and any-machine Verification items); de-shouted. `§ Environment Discipline` heading kept (cited by deploy-check). references/versioning-and-cicd.md unchanged (already clean) |
| skills/mlops/model-monitoring/SKILL.md | skill | done | skills/mlops/model-monitoring/SKILL.md | 1065 → 721 | Shorter description; Overview/When-to-Use/When-NOT/Related Skills → intro + Elsewhere list; planes ASCII diagram merged into the table; dropped Common Rationalizations and Red Flags (unique points → privacy and judge-upgrade anti-patterns, refusal-rate/prompt-marker and PII-TTL Verification items, launch-week line). references/observability-and-drift.md unchanged (already clean) |
| skills/mlops/model-serving/SKILL.md | skill | done | commands/deploy-check.md | 2024 → 1516 | Shorter description; Overview + When to Use (dup of description) folded into one paragraph; dropped Common Rationalizations and Red Flags (dups of anti-patterns/verification), unique points folded in; Related Skills trimmed to non-duplicates. G6: Verification list merged into serving-stack-matrix.md § Per-Deploy Verification Checklist (deploy-check cites it); skill links there |
| skills/prompt-engineering/SKILL.md | skill | done | skills/prompt-engineering/SKILL.md | 590 → 371 | Shorter description; tagline cut; Selection Guide + Decision Tree + File Overview + Related Skills (four overlapping route lists) merged into Where to Go + Adjacent Skills tables; broken `${CLAUDE_SKILL_DIR}/evals|llm-apps|finetuning/...` paths → `../` links; CORPFLOW.md link dropped (seam rule). Stack Snapshot (minus "temperature 0", per structured-outputs caveat) and owner/escalation line unchanged. _index.md 225 → 196: leaf summaries synced to the trimmed descriptions, same path fix, CORPFLOW.md row dropped; G6: restored "(temperature 0 where supported)" in Iteration loop row |
| skills/prompt-engineering/context-engineering/SKILL.md | skill | done | commands/prompt-optimize.md | 1002 → 632 | Shorter description; tagline/Overview/When-to-Use → intro + Elsewhere list; dropped Common Rationalizations and Red Flags (two unique → Verification); de-shouted. references/window-management.md 1250 → 1240: de-shouted, fixed vague § link, removed orphan 'base constraints' ref |
| skills/prompt-engineering/prompt-design/SKILL.md | skill | done | commands/prompt-optimize.md | 2265 → 1885 | Shorter description; Overview/When-to-Use → intro + Elsewhere list; dropped Common Rationalizations and Red Flags (unique points → Anti-Patterns/Verification); Deep-Dive + Related merged; de-shouted. Anatomy, hierarchy, versioned-file layout, 'When to Stop Prompt-Engineering' unchanged. references: prompt-patterns 1313 → 1311, claude-prompting 1350 → 1289 (de-shouted, prefill dup bullets merged) |
| skills/prompt-engineering/structured-outputs/SKILL.md | skill | done | commands/prompt-optimize.md | 2015 → 1534 | Shorter description; Overview/When-to-Use → one-line rule + Elsewhere list; Rationalizations/Red Flags → Anti-Patterns rows; de-shouted; provider-neutral caveats that some current models reject forced tool_choice, prefill, and temperature; no-eval() rule kept. references/schema-patterns.md 1179 → 1183: de-shouted, same temperature caveat |
| skills/_shared/framework-detection.md | skill | done | commands/build-test.md | 805 → 772 | Light pass: dropped corpflow mentions and CORPFLOW.md ref (seam rule), softened emphasis; tables unchanged (shared by review-code, eval-run, analyze-security) |
| skills/_shared/_index.md | skill | todo | | 191 → | |
| skills/_shared/model-selection.md | skill | todo | | 573 → | |
| skills/_shared/severity-matrix.md | skill | todo | | 569 → | |

## Decisions

Answered 2026-10-05. Each group runs as one Opus task in this order, one commit per group. Prompt: `Apply decision group {G#} from optimization/ledger.md following optimization/brief.md`. The decisions below override the brief's "Keep → file layout" rule where they say so. When done, mark the group done and note the commit.

| group | status | commit |
|---|---|---|
| G1 Agent infrastructure | done | `chore(optimization): Apply G1 agent infrastructure decisions` |
| G2 Tool names & frontmatter | done | `chore(optimization): Apply G2 tool name and frontmatter decisions` |
| G3 Lint & shared docs | done | `chore(optimization): Apply G3 lint and shared doc decisions` |
| G4 Corpflow seam | done | `chore(optimization): Apply G4 corpflow seam decisions` |
| G5 Security IDs & exit codes | done | `chore(optimization): Apply G5 security ID and exit code decisions` |
| G6 Content fixes | done | `chore(optimization): Apply G6 content fix decisions` |
| G7 `_shared` rows (process the three todo rows above per the brief) | todo | |

### G1 Agent infrastructure
- Move `agents/_base/ai-agent.md` to `skills/_shared/agent-base.md` (a reference doc, not an agent). Drop `inherits:` from every agent and copy into each agent only the base rules it needs (some are already copied). Update references to the old path.
- Agents reach skills through the `Skill` tool: add `Skill` to each agent's `tools` and cite skills by name (`ai-engineer:<skill>`), not by `skills/...` path.
- Prefix the remaining `skills/_shared/...` paths in agent and command bodies with `${CLAUDE_PLUGIN_ROOT}/`.

### G2 Tool names & frontmatter
- `disallowed-tools`: drop it where `tools` already excludes Write/Edit; rename it to `disallowedTools` elsewhere, including README, MEMORY and model-selection.md.
- Rename "Task tool" to "Agent tool" in prose, and `Task(...)` to `Agent(...)` in `tools` lists.
- Add `Agent` to `allowed-tools` in every command that launches subagents.
- model-selection.md: the per-call override passes `model` only; reasoning effort is set in agent frontmatter (`effort:`).
- Drop the `estimated-cost` field from command frontmatter and from the README.

### G3 Lint & shared docs
- Rename `## CRITICAL BEHAVIORAL RULES` to `## Rules` in `scripts/section-lint.sh` and in all commands.
- Remove the `## Workflow Integration` requirement from section-lint.
- Remove the empty Workflow Integration section from `skills/_shared/_index.md`.
- ai-performance-engineer: rank unbounded spend P2, matching severity-matrix.md.

### G4 Corpflow seam
- Move the Return Verification details out of `agents/ai-engineer.md` into `CORPFLOW.md`; leave a one-line pointer in the agent.
- Add one line to the agents that build or test: inside a worktask, build and test only through `/ai-engineer:build-test`.
- Add to CORPFLOW.md: AI QA passes only when the tests pass and the eval gate holds (rule from regression-gates).
- Remove the "orchestrator's meta-prompt engineer" routing line wherever it appears.

### G5 Security IDs & exit codes
- Move the OWASP LLM Top 10 IDs to the 2025 numbering in ai-security-auditor, analyze-security, review-code and rag-audit, all in this one commit.
- build-test and eval-run: replace `| tee log` with `> log 2>&1`, then `tail` the log, so the tool's real exit code survives. Check that the `allowed-tools` patterns still match.

### G6 Content fixes
- Merge the model-serving Verification list into the Per-Deploy Checklist in `references/serving-stack-matrix.md`; the skill links to it.
- Sync the skill summaries in README.md and skills/_index.md to the trimmed descriptions.
- prompt-engineering index: restore "(temperature 0 where supported)" in the iteration-loop row.
- training-optimization: restore "distributed training" to its description.
- trace-to-training-data `references/conversion-recipes.md`:
  - make `assert_no_golden_leak` catch plain SFT, correction and masked rows;
  - define `_user_turn` and `_assistant_turn`;
  - make `build_pairs` skip tasks that have no failing traces instead of crashing.
- quantized-export `references/export-commands.md`: label `tools.generate`, `tools.quantize` and `BASE_REV` as project placeholders.
- README.md:66: change `/system-developer:code-review` to `/system-developer:review-code`. Leave CHANGELOG.md history alone.

### Decided: keep as is
- `.context/...` corpflow paths in peft-lora and training-optimization.
- rag-audit's own grading rubric alongside rag-systems' Verification list.
- The one-line "every change ships with an eval run" pointers in each skill.
- Emphasis inside judge templates and repair prompts, since that text goes to the product model.
- Provider-neutral caveats in structured-outputs.

## Needs decision

- CORPFLOW.md is 285 lines after G4 (was 275) and its footer lists two size budgets, ≤260 and ≤280 (a third duplicate ≤280 row was dropped). Which budget holds, and should the file be trimmed to it?
- regression-gates/SKILL.md still states the AI QA rule (QA passes only when tests pass and the eval gate holds), now also in CORPFLOW.md. Keep it in the skill or cut it there?
- ai-performance-engineer runs `uv run pytest` benchmarks but did not get the build-test line, since it is review-only and benchmarks aren't a build or test gate. Add it there too?
- G5 applied `>> log 2>&1` (append), not `> log`, because each build-test phase and each eval-run suite appends to one shared log. `tail` is a built-in read-only command; build-test lists `Bash(tail:*)` anyway and dropped `Bash(tee:*)`. Redirect targets are checked against Edit rules and working dirs, so `.context/logs/` inside the repo still passes. mlops-engineer, ai-test-generator and rag-audit still say "tee transcripts to `.context/logs/`" (generic, outside G5's two commands). Switch them to redirects too?
- G5: structured-outputs/SKILL.md and agent-design/references/tool-design.md still name the old category "insecure output handling" (no ID). Rename to "improper output handling" (LLM05:2025)?
