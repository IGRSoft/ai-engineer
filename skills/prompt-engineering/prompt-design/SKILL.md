---
name: prompt-design
description: >-
  Design production LLM-app prompts: five-segment anatomy, instruction
  hierarchy with delimited untrusted input, few-shot design, positive framing,
  and prompts as versioned files. Use when writing or restructuring a
  feature's system/user prompt, when untrusted input flows into a prompt, when
  few-shot examples underperform, or when deciding whether to escalate to RAG
  or fine-tuning. Product prompts only, not Claude Code agents or skills.
---

# Prompt Design

Application prompts degrade instead of crashing, regress silently when
edited, and are the main prompt-injection surface. Structure them, version
them, keep untrusted input out of instructions, and measure every change.

Owned by `ai-engineer:ai-prompt-engineer`.

**Elsewhere:**

- What goes into the window (budgets, history, retrieval packing) → [context-engineering](../context-engineering/SKILL.md)
- Machine-parseable JSON output → [structured-outputs](../structured-outputs/SKILL.md)
- Measuring whether a prompt change helped → `skills/evals/eval-design`
- Retrieval quality (chunking, embeddings, reranking) → `skills/llm-apps/rag-systems`

## Prompt Anatomy

Every production prompt has five segments in this order:

```
┌─ 1. ROLE ────────────────────────────────────────────────┐
│ Who the model is, its scope, what it never does          │
├─ 2. CONTEXT ─────────────────────────────────────────────┤
│ Stable facts the task needs (product, domain, audience)  │
├─ 3. INSTRUCTIONS ────────────────────────────────────────┤
│ The task: rules, steps, edge-case handling, tie-breaks   │
├─ 4. EXAMPLES ────────────────────────────────────────────┤
│ 2-5 input→output pairs, incl. one edge case              │
├─ 5. OUTPUT CONTRACT ─────────────────────────────────────┤
│ Exact format, length, language, escape hatch             │
└──────────────────────────────────────────────────────────┘
```

Order matters because attention is not uniform:

- **Role first** — everything after it is interpreted through the role; a role stated late cannot re-frame instructions already read.
- **Output contract last** — the format spec sits closest to generation (recency), which is where format compliance is decided.
- **Examples after instructions** — examples disambiguate rules; when they conflict, models tend to imitate examples over prose, so the pair must agree.
- **Load-bearing rules at the edges** — models under-attend to the middle of long prompts (see [window-management](../context-engineering/references/window-management.md) § Placement: Lost in the Middle); bury nothing critical mid-prompt.

| Segment | Question it answers | Typical failure when missing |
|---|---|---|
| Role | Who am I? What is out of scope? | Off-scope answers, persona drift |
| Context | What is true here? | Hallucinated product facts |
| Instructions | What exactly do I do? | Plausible-but-wrong behavior on edge cases |
| Examples | What does done look like? | Format drift, wrong granularity |
| Output contract | What shape is the answer? | Unparseable output, wrong language/length |

## Instruction Hierarchy and Injection-Resistant Layering

Prompts have privilege levels. Instructions flow down; data flows up — content from a lower layer does not rewrite a higher one. Injection also arrives by accident: pasted emails, retrieved docs, and tool output carry instruction-like text daily.

```
privilege
   ▲  ┌──────────────────────────────────────────────────────┐
 high │ SYSTEM      app owner's rules: role, safety, contract │ fixed at deploy
      ├──────────────────────────────────────────────────────┤
      │ DEVELOPER   feature framing, examples, tool guidance  │ fixed per feature
      ├──────────────────────────────────────────────────────┤
      │ USER        the end-user's request                    │ per request
      ├──────────────────────────────────────────────────────┤
 low  │ RETRIEVED / TOOL OUTPUT — untrusted                   │ per request
      │   delimited + labeled, treated as data, not rules     │
      └──────────────────────────────────────────────────────┘
   ▼
 trust in instruction-like content found at this layer
```

Rules:

1. **Untrusted input stays out of system/developer segments** — no f-strings or template slots for user text in privileged files.
2. **Untrusted content is delimited and labeled as data** — wrapped in tags with a source label, placed in the user turn.
3. **The system prompt states the data rule**: content inside data delimiters is information to analyze, not instructions to follow.
4. **Escape delimiter collisions** — strip or escape the closing delimiter inside untrusted content, or an attacker closes your tag and writes "instructions" outside it.
5. **Validate model output at trust boundaries** (shell, DB, file APIs) — see [structured-outputs](../structured-outputs/SKILL.md); injection review is `ai-engineer:ai-security-auditor` territory.

```python
# BAD — user text lands inside the privileged segment
system = f"You are Acme's support agent. The user said: {user_msg}. Help them."

# GOOD — privileged segment is a fixed versioned file; untrusted text is
# delimited data in the user turn
system = load_prompt("support-triage/system", version="4")
user = render_user(
    "support-triage/user",
    version="4",
    ticket=escape_delimiters(user_msg, tag="ticket"),
)
```

Full pattern with before/after: `references/prompt-patterns.md` § Delimited Untrusted Input.

## Few-Shot Design

Treat examples like test fixtures: selected from the real distribution, covering edges, format-exact.

- **Selection**: draw from real (sanitized) production inputs. Invented examples encode your assumptions, not the input distribution.
- **Coverage**: for k examples — majority typical cases, at least one edge case, and one escape-hatch demonstration when the contract has one (e.g. an empty result).
- **Ordering**: keep it stable and versioned. Models over-imitate the last example (recency); if outputs skew toward one example, reorder deliberately and re-measure.
- **Format consistency**: examples must byte-match the output contract. On conflict, the model copies the examples and ignores the prose.
- **Count**: start at 2-5. More is not better — each example must earn its tokens on the eval set.

```text
<examples>
<example>
<ticket>The app charged me twice for the June invoice.</ticket>
<output>{"category": "billing", "urgency": "high"}</output>
</example>
<example>
<ticket>How do I export my data to CSV?</ticket>
<output>{"category": "how_to", "urgency": "low"}</output>
</example>
<example>
<ticket>Can't log in since yesterday — also please update my billing address.</ticket>
<output>{"category": "account", "urgency": "high"}</output>
</example>
</examples>
```

The third example is the edge case: mixed intent, teaching the tie-break rule (access issues outrank billing edits) that prose alone states weakly. Wrap example inputs in the same delimiters used at runtime so the mapping is unambiguous.

## Negative Instructions vs Positive Framing

A positive instruction specifies one target; a negative one excludes a single point in an infinite space — and naming the forbidden thing raises its salience.

```text
# Before — negative pile-up (every "don't" leaves the "do" undefined)
Don't be verbose. Don't use markdown. Don't speculate about causes.
Don't mention internal tools. Don't say you are an AI.

# After — positive contract (desired behavior fully specified)
Reply in 1-3 plain-text sentences. State only causes explicitly present in
<ticket>; if none is stated, write exactly: CAUSE UNKNOWN.
Refer to tooling generically ("our system"), never by internal name.
```

Keep "never" for absolutes (security, safety, compliance) — and pair each retained negative with its positive alternative so the model knows what to do instead.

## Prompts as Versioned Files

Prompts are behavior; unversioned behavior can't be diffed, rolled back, or blamed.

```
prompts/
├── CHANGELOG.md              # one line per bump: version, change, eval delta
├── OWNERS.md                 # who reviews prompt changes (or a CODEOWNERS rule)
└── support-triage/
    ├── system@4.md           # privileged: role, rules, output contract
    ├── user@4.md             # request template: delimited slots for untrusted data
    └── examples@4.md         # few-shot block, versioned with the prompt
```

Rules:

- **Code loads and renders, never inlines.** No prompt literals in application code; the only interpolation surface is the user template's delimited data slots. Log the loaded version per call so the live version is always known.
- **Every semantic change bumps the version** and adds a CHANGELOG line with the eval delta (deterministic run: temperature 0, pinned eval-set version — `skills/evals/eval-design`). A 20-case golden set catches most regressions pre-ship.
- **Rollback = repointing the version**, not reverting a code deploy.
- **Owners review prompt diffs** like API changes — a one-word edit is a behavior change.

```python
from pathlib import Path
from string import Template

PROMPTS = Path(__file__).parent / "prompts"


def load_prompt(name: str, *, version: str) -> str:
    """Return the raw prompt template ``prompts/<name>@<version>.md``."""
    return (PROMPTS / f"{name}@{version}.md").read_text(encoding="utf-8")


def render_user(name: str, *, version: str, **data: str) -> str:
    """Render untrusted values into the user template's delimited data slots.

    Raises KeyError on a missing placeholder — fail loud rather than ship a
    half-rendered prompt. Never call this on system/developer templates.
    """
    return Template(load_prompt(name, version=version)).substitute(data)
```

## Model-Agnostic Core vs Provider Adaptations

- Keep the **core** — role, rules, examples, output contract — in provider-neutral markdown. It is the reviewed, versioned asset.
- Isolate provider specifics in a **thin adapter**: message-role mapping, structuring idioms (XML tags for Claude), feature use (prefill, native structured-output modes, thinking budgets).
- Fork the adapter, not the core — forked cores drift apart within weeks.
- Model IDs, parameter names, and limits are volatile: keep model choice in config, and verify current names/limits against provider docs (context7) rather than memory.

Claude-specific techniques (XML structuring, prefilling, extended thinking, long-context placement): `references/claude-prompting.md`.

## When to Stop Prompt-Engineering

Prompting has a ceiling. After 2-3 *measured* iterations (each with an eval delta — unmeasured iteration is thrash), diagnose and escalate:

| Symptom after measured iterations | Diagnosis | Escalate to |
|---|---|---|
| Model lacks the facts (private/post-cutoff data), invents them | Knowledge gap | RAG — `skills/llm-apps/rag-systems` |
| Facts right, but tone/format/style drifts despite examples | Behavior gap | Fine-tuning — `skills/finetuning/peft-lora` |
| Task needs many steps, tools, or state | Capability/topology gap | Agent design — `skills/llm-apps/agent-design` |
| Quality fine, cost/latency from an ever-growing prompt | Efficiency gap | [context-engineering](../context-engineering/SKILL.md); caching — `skills/llm-apps/llm-api-patterns` |

The prompt-vs-RAG-vs-fine-tune decision framework is owned by `ai-engineer:ai-architector` — consult it before committing to a fine-tune.

## Anti-Patterns

| Pattern | Problem | Fix |
|---|---|---|
| Prompt literals scattered through application code | Unversioned, unreviewable, untestable behavior | `prompts/` dir + loader; code loads-renders-never-inlines |
| User input f-stringed into the system prompt | Prompt injection into the privileged segment | Delimited data slots in the user turn only |
| Negative pile-up ("don't X, never Y, avoid Z") | Behavior underspecified; model picks a different wrong thing | Positive contract; reserve "never" for absolutes |
| Examples that contradict the output contract | Model imitates examples, ignores prose | Byte-match examples to the contract; version them together |
| One mega-prompt serving every intent (>2k tokens, no sections or version — `skills/_shared/severity-matrix.md`) | Rules conflict; every edit regresses another path | One prompt per feature; shared core via composition |
| Appending another rule after each incident | Instruction count dilutes compliance | Restructure, add an example, or escalate |
| Editing prompts without an eval run | Regressions ship silently | Eval gate per change — `skills/evals/regression-gates` |
| Provider syntax baked into the core prompt | Lock-in; per-provider forks drift | Agnostic core + thin provider adapter |

## Verification

- [ ] All five anatomy segments present, in order; load-bearing rules at the edges
- [ ] Untrusted input reaches only delimited data slots in the user turn; delimiter collisions escaped
- [ ] System prompt states that delimited content is data, never instructions
- [ ] Few-shot examples byte-match the contract; ≥1 edge case; escape hatch demonstrated
- [ ] Prompt is a versioned file with owner + CHANGELOG entry (eval delta, pinned eval-set version, temperature 0)
- [ ] Code loads and renders prompts — zero inline prompt literals; loaded version logged
- [ ] Provider specifics isolated in an adapter; core is provider-neutral
- [ ] Escalation table reviewed before adding iteration #4 (`ai-engineer:ai-architector` for the call)

## References and Related

- `references/prompt-patterns.md` — 10 reusable patterns (role anchoring, delimited input, CoT, refusal hatch, self-check…) with before/after and failure modes
- `references/claude-prompting.md` — Claude-specific: XML tags, prefilling, extended thinking, tool-use prompting, long-context placement
- `skills/llm-apps/llm-api-patterns` — provider-call discipline (timeouts, retries, caching)
- Agents: `ai-engineer:ai-security-auditor` (injection review), `ai-engineer:ai-architector` (escalation decisions)
