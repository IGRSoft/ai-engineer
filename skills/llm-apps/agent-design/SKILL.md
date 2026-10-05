---
name: agent-design
description: >-
  Design bounded, safe, observable LLM agent loops: the escalation ladder
  (single call → workflow → agent with tools → multi-agent), stop conditions
  and budgets, tool contracts, memory, human approval for irreversible actions,
  failure handling, and step tracing. Use when deciding whether a task needs an
  agent, designing or reviewing a tool loop, an agent overruns iterations or
  spend, the model picks the wrong tool, or adding approval gates.
---

# Agent Design

An agent is a model choosing its own control flow, and every increment of autonomy costs predictability, latency, spend, and audit surface. Good agent design is mostly subtraction: the fewest tools, the lowest autonomy level, and the tightest stop conditions that still pass the eval set. Owning agent: `ai-engineer:llm-engineer`; tool-surface and excessive-agency review goes to `ai-engineer:ai-security-auditor`.

**Elsewhere:**

- Finding the right knowledge is retrieval, not agency → `skills/llm-apps/rag-systems` (often one tool in the loop)
- Provider-call mechanics (timeouts, retries, streaming, fallbacks) → `skills/llm-apps/llm-api-patterns`
- One-shot extraction or classification against a fixed schema → `skills/prompt-engineering/structured-outputs`
- Wording and iterating the prompts inside the loop → `skills/prompt-engineering/prompt-design` + `skills/evals/eval-design`

## The Escalation Ladder

| Level | Control flow decided by | Fits | Climb when |
|-------|------------------------|------|-----------|
| L0 single call | You (one prompt) | Classify, extract, draft, summarize | Output needs multiple dependent steps |
| L1 workflow/chain | Your code (fixed DAG) | Enumerable steps: retrieve→draft→check | The step sequence genuinely varies per input |
| L2 single agent | The model (tool loop) | Open-ended tasks over a known tool set | One context window/persona can't hold the task |
| L3 multi-agent | Models + orchestrator | Parallel specialist subtasks, isolation needs | — (top rung; expect coordination tax) |

Stay as low as possible. If you can enumerate the steps ahead of time, it is a workflow, not an agent: hardcode the sequence and keep the LLM calls simple. Each rung multiplies spend, latency, failure modes, and debugging difficulty, so climb one rung at a time and only when the eval set shows the current rung failing. Topology decisions (L3 shapes, delegation trees) belong to `ai-engineer:ai-architector`.

## Loop Anatomy

Plan → act (one tool call) → observe (append result or structured error) → stop-check → repeat. Every exit path is an explicit stop condition:

```python
from dataclasses import dataclass

IRREVERSIBLE: frozenset[str] = frozenset({"send_email", "delete_records", "deploy"})


@dataclass(frozen=True)
class LoopBudget:
    max_iterations: int = 10
    max_tokens: int = 150_000  # app-level spend cap, not a provider limit
    max_tool_errors: int = 3


def run_agent(goal: str, tools: ToolRegistry, budget: LoopBudget) -> AgentResult:
    """Bounded agent loop: every exit path is an explicit stop condition."""
    transcript = Transcript(goal=goal)
    for _iteration in range(budget.max_iterations):
        step = model_step(transcript)  # plan + chosen action (or final answer)
        if step.is_final:
            return AgentResult.done(step.answer, transcript)
        if step.tool_name in IRREVERSIBLE:
            approve_or_abort(step)  # HITL gate before the action, not after
        observation = tools.execute(step)  # tool errors return as observations
        transcript.append(step, observation)
        if transcript.tokens_used > budget.max_tokens:
            return AgentResult.aborted("token budget exceeded", transcript)
        if transcript.tool_error_count > budget.max_tool_errors:
            return AgentResult.aborted("repeated tool failures", transcript)
        if transcript.repeats_last_action():
            return AgentResult.aborted("no progress (repeated action)", transcript)
    return AgentResult.aborted("iteration cap", transcript)
```

### Stop conditions (all four classes)

| Condition | Trigger | On trip |
|-----------|---------|---------|
| Iteration cap | Fixed max loop count | Abort with transcript; surface partial work |
| Budget | Token/cost ceiling per run | Abort; alert if hit rate climbs |
| Goal check | Model declares done and a validator agrees (schema, tests, checklist) | Return the answer |
| HITL gate | Irreversible action requested, or confidence below threshold | Pause for human approval |

Add a no-progress detector (identical tool+args twice, or A↔B oscillation); it catches the loops that budgets only make expensive. An unbounded agent loop is a P1 finding per `skills/_shared/severity-matrix.md` (ungated tool execution).

## Tool Design (contract-first)

The model sees only the tool's name, description, and schema, so that text is the interface:

- **Few.** Selection accuracy degrades as the registry grows; keep it single-digit per agent and compose plumbing in code.
- **Orthogonal.** Two tools that both "kind of" fetch data guarantee misrouting.
- **Typed.** JSON schema with enums, ranges, formats, and examples, not freeform strings the handler re-parses.
- **Described by contract.** When to use, when not to, side effects, error meanings, output shape.

`references/tool-design.md` has the schema checklist, granularity calls, idempotency/dry-run patterns, dangerous-action gating, isolated testing, and tool-set versioning.

## Memory Patterns

| Pattern | Mechanism | Use when | Overkill when |
|---------|-----------|----------|---------------|
| Scratchpad | The transcript itself | Default; task fits one session | Never — this is the baseline |
| Episodic summary | Compact older turns into a running summary | Long sessions approaching the context budget | Short tasks — compaction discards detail for nothing |
| External store | Vector/DB recall across sessions | Cross-session facts, personalization | Any single-session task — it imports RAG's whole failure surface |

Start with the scratchpad, add summarization when transcripts measurably outgrow the window (`skills/prompt-engineering/context-engineering`), and add an external store only when evals show cross-session recall failing.

## Guardrails

Excessive agency is an OWASP LLM Top 10 risk: an agent that can do more than the task needs will.

- **Input validation:** schema-check user input and tool arguments before execution; treat model output as untrusted caller input at every boundary.
- **Output validation:** model output reaches shell, DB, file, or HTTP APIs only after parameterizing, allowlisting, or escaping.
- **Action allowlist:** each agent gets an explicit tool list, least-privilege credentials per tool, and capability tiers (read / write / irreversible). No production write credentials "temporarily".
- **Irreversible-action HITL:** send, delete, pay, deploy, and anything crossing an org boundary needs human confirmation before execution, typically a dry-run preview plus approval token (`references/tool-design.md`). Gates go in before the first real credential, not after launch.

Review the full tool surface with `ai-engineer:ai-security-auditor` before launch and after every tool addition.

## Failure Handling

- **Tool errors are observations, not exceptions.** Feed a structured error (`{"error": "...", "retryable": true}`) back into the transcript and let the model adapt, bounded by `max_tool_errors`.
- **Retries:** transient tool failures may auto-retry once with backoff; non-idempotent tools don't auto-retry without an idempotency key (`references/tool-design.md`). Provider-call retries belong to the client (`skills/llm-apps/llm-api-patterns`).
- **Degraded modes:** on budget exhaustion return partial results with explicit disclosure, or fall back one rung (agent → scripted workflow → canned response). Define this at design time.
- **Escalation:** hand humans the transcript and the stop reason, not a stack trace.

## Observability

Agents fail across iterations, and the transcript is the only ground truth, so trace every step:

```python
from typing import TypedDict


class StepEvent(TypedDict):
    run_id: str
    iteration: int
    prompt_version: str  # versioned prompt file, not inline text
    model: str  # resolved from config, not a hardcoded ID
    tool_name: str | None
    tool_args_redacted: dict[str, object]  # secrets/PII scrubbed before write
    tokens_in: int
    tokens_out: int
    latency_ms: int
    stop_reason: str | None  # populated on the final event of a run
```

Emit one JSONL event per loop step (append-only, one file or stream per run). This yields per-run cost, per-step latency, tool-choice distributions, and replayable transcripts that become eval cases (`skills/evals/eval-design`). Production drift and cost dashboards: `skills/mlops/model-monitoring`.

## Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| Multi-agent on day one | Coordination tax, context loss per hop, untestable | Start at L0; climb one rung on eval evidence |
| `while True` around a model call | Unbounded spend and hangs — P1 | Iteration cap + token budget + no-progress detector |
| 30-tool registry | Wrong-tool selection, bloated context | Few orthogonal tools; compose plumbing in code |
| Retrying semantic tool errors | Same failure, more spend | Retry transient only; fix the schema/prompt instead |
| Auto-confirming irreversible actions | One bad plan = production incident | HITL gate before the action, with dry-run preview |
| Freeform string args into shell/DB | Injection via model output | Typed schemas, parameterization, allowlists |
| Memory store bolted on at design time | RAG failure surface, no proven need | Scratchpad first; add memory when evals demand it |
| No step traces | Failures unreproducible, spend unattributable | JSONL step events from the first prototype |

## Verification

- [ ] Task sits on the lowest ladder rung that passes evals; any climb is justified by eval evidence
- [ ] Every loop exit is explicit: iteration cap, token/cost budget, validated goal check, HITL gate
- [ ] No-progress detection trips on repeated or oscillating actions
- [ ] Tools are few, orthogonal, typed, contract-described (`references/tool-design.md` checklist passed)
- [ ] Irreversible actions gated by human confirmation with dry-run preview
- [ ] Tool errors return as structured observations with bounded retries
- [ ] Degraded mode defined and tested (partial answer or lower-rung fallback)
- [ ] Every step traced: prompt version, model, tool calls, tokens, latency, stop reason — redacted before write
- [ ] Tool surface reviewed by `ai-engineer:ai-security-auditor`
- [ ] Loop behavior covered by a pinned eval set (`skills/evals/eval-design`) at the rung that ships, and gated in CI (`skills/evals/regression-gates`)
