---
name: agent-design
description: >-
  Design LLM agent loops that stay bounded, safe, and observable: the
  escalation ladder (single call → workflow → single agent with tools →
  multi-agent), loop anatomy, stop conditions and budgets, tool contracts,
  memory patterns, guardrails with human confirmation for irreversible
  actions, failure handling, and step-level tracing. Use when deciding whether
  a task needs an agent at all, designing or reviewing a tool-using loop, an
  agent overruns iterations or spend, the model keeps picking the wrong tool,
  or you are adding approval gates before dangerous actions.
---

# Agent Design

## Overview

An agent is a model deciding its own control flow: it picks tools, reads
results, and chooses the next step. That autonomy is the product feature *and*
the liability — every increment buys capability and pays for it in
predictability, latency, spend, and audit surface. Good agent design is mostly
subtraction: the fewest tools, the lowest autonomy level, and the tightest
stop conditions that still pass the eval set.

Owning agent: `ai-engineer:llm-engineer`. Tool-surface and excessive-agency
review routes to `ai-engineer:ai-security-auditor`.

## When to Use

- Deciding between a single call, a scripted chain, an agent, or multi-agent
- Designing or reviewing a tool-using loop and its stop conditions
- An agent overruns iterations, tokens, or budget — or never terminates
- The model picks wrong tools, oscillates, or ignores tool errors
- Adding guardrails: allowlists, validation, human-in-the-loop confirmation

**When NOT to use:**

- The real problem is finding the right knowledge — that is retrieval, not
  agency; see `skills/llm-apps/rag-systems` (often just one tool in the loop)
- Provider-call mechanics (timeouts, retries, streaming, fallbacks) — see
  `skills/llm-apps/llm-api-patterns`
- One-shot extraction/classification against a fixed schema — see
  `skills/prompt-engineering/structured-outputs`; no loop required
- Wording and iterating the prompts inside the loop — see
  `skills/prompt-engineering/prompt-design` + `skills/evals/eval-design`

## The Escalation Ladder

```
L3  multi-agent            orchestrator + specialists      highest cost & variance
L2  single agent + tools   model-directed loop             bounded autonomy
L1  workflow / chain       code-directed steps w/ LLM calls predictable, testable
L0  single call            one prompt, one response        cheapest, most testable
        ▲  climb ONE rung, only on eval evidence the current rung fails
```

| Level | Control flow decided by | Fits | Climb when |
|-------|------------------------|------|-----------|
| L0 single call | You (one prompt) | Classify, extract, draft, summarize | Output needs multiple dependent steps |
| L1 workflow/chain | Your code (fixed DAG) | Enumerable steps: retrieve→draft→check | The step sequence genuinely varies per input |
| L2 single agent | The model (tool loop) | Open-ended tasks over a known tool set | One context window/persona can't hold the task |
| L3 multi-agent | Models + orchestrator | Parallel specialist subtasks, isolation needs | — (top rung; expect coordination tax) |

**Stay as low as possible.** The decision rule: if you can enumerate the steps
ahead of time, it is a workflow, not an agent — hardcode the sequence and keep
the LLM calls simple. Each rung multiplies token spend, latency, failure
modes, and debugging difficulty; climb one rung at a time and only when the
eval set shows the current rung failing. Architecture-level topology decisions
(L3 shapes, delegation trees) belong to `ai-engineer:ai-architector`.

## Loop Anatomy

```
goal
 └─▶ plan (model chooses next action)
      └─▶ act — execute ONE tool call
           └─▶ observe — append result (or structured error) to transcript
                └─▶ reflect — progress made? plan still valid?
                     └─▶ stop-check ──yes──▶ final answer / escalate to human
                            │ no
                            └────────▶ plan (next iteration, budgets decremented)
```

Every arrow is observable state; every cycle passes a stop-check. The loop
skeleton, with budgets and gates in place:

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
            approve_or_abort(step)  # HITL gate BEFORE the action, never after
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

### Stop conditions (all four classes, always)

| Condition | Trigger | On trip |
|-----------|---------|---------|
| Iteration cap | Fixed max loop count | Abort with transcript; surface partial work |
| Budget | Token/cost ceiling per run | Abort; alert if hit rate climbs |
| Goal check | Model declares done **and** a validator agrees (schema, tests, checklist) | Return the answer |
| HITL gate | Irreversible action requested, or confidence below threshold | Pause for human approval |

Add a no-progress detector (identical tool+args twice, or A↔B oscillation) —
it catches the loops that budgets only make expensive. **An unbounded agent
loop is a P1 finding** per `skills/_shared/severity-matrix.md` (ungated tool
execution class): flag it in review, never ship it.

## Tool Design (contract-first)

The model reads only the tool's name, description, and schema — that text *is*
the interface. Principles:

- **Few.** Selection accuracy degrades as the registry grows; keep it
  single-digit per agent and compose plumbing in code, not in the model.
- **Orthogonal.** No overlapping capabilities — two tools that both "kind of"
  fetch data guarantee misrouting.
- **Typed.** JSON schema with enums, ranges, formats, and examples — not
  freeform strings the handler re-parses.
- **Described by contract.** When to use, when NOT to use, side effects, error
  meanings, output shape.

Read `references/tool-design.md` for the schema-quality checklist, granularity
calls, idempotency/dry-run patterns, dangerous-action gating, isolated
testing, and tool-set versioning.

## Memory Patterns

| Pattern | Mechanism | Use when | Overkill when |
|---------|-----------|----------|---------------|
| Scratchpad | The transcript itself — plan and observations in context | Default; task fits one session | Never — this is the baseline |
| Episodic summary | Compact older turns into a running summary | Long sessions approaching the context budget | Short tasks — compaction discards detail for nothing |
| External store | Vector/DB recall across sessions | Cross-session facts, personalization | Any single-session task — it imports RAG's whole failure surface (`skills/llm-apps/rag-systems`) |

Default to no memory machinery: start with the scratchpad, add summarization
when transcripts measurably outgrow the window (compaction techniques:
`skills/prompt-engineering/context-engineering`), and add an external store
only when evals show cross-session recall failing.

## Guardrails

Excessive agency is an OWASP LLM Top 10 risk class — the agent that *can* do
more than the task needs eventually *will*. Design-time controls:

- **Input validation:** schema-check user input and tool arguments before
  execution; treat model output as untrusted caller input at every boundary.
- **Output validation:** model output never reaches shell, DB, file, or HTTP
  APIs unvalidated — parameterize, allowlist, escape.
- **Action allowlist:** each agent gets an explicit tool list, least-privilege
  credentials per tool, and capability tiers (read / write / irreversible).
- **Irreversible-action HITL:** send, delete, pay, deploy, and anything
  crossing an org boundary requires a human confirmation gate *before*
  execution — a dry-run preview plus approval token is the standard shape
  (`references/tool-design.md`).

Review the full tool surface with `ai-engineer:ai-security-auditor` before
launch and after every tool addition.

## Failure Handling

- **Tool errors are observations, not exceptions.** Feed a structured error
  (`{"error": "...", "retryable": true}`) back into the transcript and let the
  model adapt — bounded by `max_tool_errors`.
- **Retry semantics:** transient tool failures may auto-retry once with
  backoff; non-idempotent tools never auto-retry without an idempotency key
  (`references/tool-design.md`). Provider-call retries are the client's job —
  `skills/llm-apps/llm-api-patterns`.
- **Degraded modes:** on budget exhaustion return partial results with an
  explicit disclosure, or fall back one ladder rung (agent → scripted
  workflow → canned response). Define the degraded path at design time; it is
  not an incident-time improvisation.
- **Escalation:** hand humans the transcript and the stop reason, not a stack
  trace.

## Observability

Trace every step or debug nothing: agents fail across iterations, and the
transcript is the only ground truth.

```python
from typing import TypedDict


class StepEvent(TypedDict):
    run_id: str
    iteration: int
    prompt_version: str  # versioned prompt file, not inline text
    model: str  # resolved from config — never hardcoded IDs
    tool_name: str | None
    tool_args_redacted: dict[str, object]  # secrets/PII scrubbed before write
    tokens_in: int
    tokens_out: int
    latency_ms: int
    stop_reason: str | None  # populated on the final event of a run
```

Emit one JSONL event per loop step (append-only, one file or stream per run).
This yields per-run cost, per-step latency, tool-choice distributions — and
replayable transcripts that become eval cases (`skills/evals/eval-design`).
Production drift and cost dashboards: `skills/mlops/model-monitoring`.

## Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| Multi-agent on day one | Coordination tax, context loss at every hop, nothing testable | Start at L0; climb one rung on eval evidence |
| `while True` around a model call | Unbounded spend and hangs — P1 | Iteration cap + token budget + no-progress detector |
| 30-tool registry | Wrong-tool selection, bloated context | Few orthogonal tools; compose plumbing in code |
| Retrying semantic tool errors | Same failure, more spend | Retry transient only; fix the schema/prompt instead |
| Auto-confirming irreversible actions | Excessive agency — one bad plan is a production incident | HITL gate before the action, with dry-run preview |
| Freeform string args into shell/DB | Injection via model output | Typed schemas, parameterization, allowlists; security review |
| Memory store bolted on at design time | RAG's failure surface with no proven need | Scratchpad first; add memory when evals demand it |
| No step traces | Failures unreproducible, spend unattributable | JSONL step events from the first prototype |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "The model will know when to stop" | It frequently doesn't — loops oscillate politely forever. Explicit stop conditions or it's a P1. |
| "More tools make it more capable" | Selection accuracy drops as the registry grows; capability comes from a few well-contracted tools. |
| "Multi-agent mirrors our team structure" | That's an org chart, not an architecture. Every handoff loses context and adds cost. |
| "We'll add the approval gate after launch" | The first irreversible mistake *is* the launch review — gates go in before the first real credential. |
| "Tracing every step is too much storage" | One untraceable bad run costs more engineer-hours than a year of JSONL. |
| "It worked on the demo task" | A demo is one sample, not an eval. Loop behavior ships behind an eval set and a regression gate. |

## Red Flags

- A loop with no iteration cap, token budget, or no-progress check
- Tool descriptions of the form "does stuff with files"
- The agent holds production write credentials "temporarily"
- Results carry no `stop_reason` — nobody can say why runs end
- The same subtask ping-pongs between two tools across iterations
- The demo ran at L3 but evals only ever covered L0 prompts
- Tool arguments interpolated into shell or SQL strings

## Verification

- [ ] Task sits on the lowest ladder rung that passes evals; any climb is justified by eval evidence, not vibes
- [ ] Every loop exit is explicit: iteration cap, token/cost budget, validated goal check, HITL gate
- [ ] No-progress detection trips on repeated or oscillating actions
- [ ] Tools are few, orthogonal, typed, contract-described (`references/tool-design.md` checklist passed)
- [ ] Irreversible actions gated by human confirmation with dry-run preview
- [ ] Tool errors return as structured observations with bounded retries
- [ ] Degraded mode defined and tested (partial answer or lower-rung fallback)
- [ ] Every step traced: prompt version, model, tool calls, tokens, latency, stop reason — redacted before write
- [ ] Tool surface reviewed by `ai-engineer:ai-security-auditor`
- [ ] Loop behavior covered by a pinned eval set (`skills/evals/eval-design`) and gated in CI (`skills/evals/regression-gates`)
