---
name: prompt-design
description: >-
  Design production application prompts: anatomy (role → context → instructions
  → examples → output contract), instruction hierarchy with injection-resistant
  layering, few-shot design, positive framing, and prompts as versioned files.
  Use when writing or restructuring a system/user prompt for an LLM feature,
  when untrusted input flows into a prompt, when a prompt grows monolithic,
  when few-shot examples underperform, or when deciding whether to keep
  prompting or escalate to RAG/fine-tuning. Product prompts only — Claude Code
  meta-prompts → igrsoft:prompt-engineer.
---

# Prompt Design

**A production prompt is an interface contract with a probabilistic dependency — structure it, version it, injection-proof it, measure it**

## Overview

Application prompts fail differently from code: they degrade instead of crashing, they regress silently when edited, and they are the primary attack surface for prompt injection. This skill covers the structural discipline that keeps prompts reliable: a fixed anatomy with deliberate ordering, an explicit privilege hierarchy that keeps untrusted input out of instruction segments, few-shot examples engineered like test fixtures, and prompt files that are versioned, owned, and changelogged like any other interface.

Owning agent: `ai-engineer:ai-prompt-engineer` (product/application prompts). Claude Code meta-prompts — agents, commands, skills — belong to `igrsoft:prompt-engineer`, not here.

## When to Use

- Writing the system/user prompt for a new LLM feature
- Untrusted input (user text, retrieved documents, tool output) flows into a prompt
- A prompt has grown into an unstructured monolith and edits cause regressions
- Few-shot examples underperform, contradict instructions, or leak into outputs
- Reviewing a PR that adds or changes prompt text
- Choosing where prompt files live and how they are versioned

**When NOT to use:**

- Deciding *what content* goes into the window (budgets, history, retrieval packing) → [context-engineering](../context-engineering/SKILL.md)
- Output must be machine-parseable JSON → [structured-outputs](../structured-outputs/SKILL.md)
- Measuring whether a prompt change helped → `skills/evals/eval-design`
- Retrieval quality (chunking, embeddings, reranking) → `skills/llm-apps/rag-systems`
- Claude Code agent/command/skill prompts → `igrsoft:prompt-engineer`

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

Ordering matters because attention is not uniform:

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

Prompts have privilege levels. Instructions flow down; data flows up — content from a lower layer must never rewrite a higher one:

```
privilege
   ▲  ┌──────────────────────────────────────────────────────┐
 high │ SYSTEM      app owner's rules: role, safety, contract │ fixed at deploy
      ├──────────────────────────────────────────────────────┤
      │ DEVELOPER   feature framing, examples, tool guidance  │ fixed per feature
      ├──────────────────────────────────────────────────────┤
      │ USER        the end-user's request                    │ per request
      ├──────────────────────────────────────────────────────┤
 low  │ RETRIEVED / TOOL OUTPUT — UNTRUSTED                   │ per request
      │   delimited + labeled, treated as DATA, never rules   │
      └──────────────────────────────────────────────────────┘
   ▼
 trust in instruction-like content found at this layer
```

Non-negotiable rules:

1. **Untrusted input is NEVER interpolated into system/developer segments.** No f-strings, no template slots for user text in privileged files.
2. **Untrusted content is always delimited and labeled as data** — wrapped in tags with a source label, placed in the user turn.
3. **The system prompt states the data rule explicitly**: content inside data delimiters is information to analyze, never instructions to follow.
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

Keep hard "never" statements for absolutes (security, safety, compliance) — and pair each retained negative with its positive alternative so the model knows what to do instead.

## Prompts as Versioned Files

Prompts are behavior. Behavior that isn't versioned can't be diffed, rolled back, or blamed.

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

- **Code loads and renders — never inlines.** No prompt literals in application code; the only interpolation surface is the user template's delimited data slots.
- **Every semantic change bumps the version** and adds a CHANGELOG line with the eval delta (deterministic run: temperature 0, pinned eval-set version — `skills/evals/eval-design`).
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
- Fork the adapter, never the core — forked cores drift apart within weeks.
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
| One mega-prompt serving every intent | Rules conflict; every edit regresses another path | One prompt per feature; shared core via composition |
| Editing prompts without an eval run | Regressions ship silently | Eval gate per change — `skills/evals/regression-gates` |
| Provider syntax baked into the core prompt | Lock-in; per-provider forks drift | Agnostic core + thin provider adapter |

## Common Rationalizations

| Excuse | Reality |
|---|---|
| "It's just a string, versioning is overkill" | The prompt *is* the behavior. Unversioned means no diff, no rollback, no blame for a production behavior change. |
| "Our users would never inject" | Injection arrives by accident too — pasted emails, retrieved docs, and tool output carry instruction-like text daily. |
| "One more rule will fix it" | Instruction count dilutes compliance. Restructure, add an example, or escalate — don't stack rule #47. |
| "The model should just know this" | It knows distributions, not your product. Say it (instructions) or show it (examples). |
| "We'll write examples once it works" | Examples are how it starts working. They're cheaper than ten instruction rewrites. |
| "We'll eval it after launch" | Post-launch you eval user complaints instead. A 20-case golden set catches most regressions pre-ship. |

## Red Flags

- A prompt exists only as a string inside a `.py` file
- `f"...{user_input}..."` anywhere in a system/developer segment
- Behavior changed but `prompts/CHANGELOG.md` has no new entry
- Examples in a different format than the output contract
- A prompt >2k tokens with no sections or version (monolith smell — `skills/_shared/severity-matrix.md`)
- Nobody can state which prompt version is live in production
- The same "fix" sentence appended after every incident

## Verification

- [ ] All five anatomy segments present, in order; load-bearing rules at the edges
- [ ] Untrusted input reaches only delimited data slots in the user turn; delimiter collisions escaped
- [ ] System prompt states that delimited content is data, never instructions
- [ ] Few-shot examples byte-match the contract; ≥1 edge case; escape hatch demonstrated
- [ ] Prompt is a versioned file with owner + CHANGELOG entry (eval delta, pinned eval-set version, temperature 0)
- [ ] Code loads and renders prompts — zero inline prompt literals
- [ ] Provider specifics isolated in an adapter; core is provider-neutral
- [ ] Escalation table reviewed before adding iteration #4 (`ai-engineer:ai-architector` for the call)

## Deep-Dive References

- `references/prompt-patterns.md` — ~10 reusable patterns (role anchoring, delimited input, CoT, refusal hatch, self-check…) with before/after examples and failure modes
- `references/claude-prompting.md` — Claude-specific: XML tags, prefilling, extended thinking, tool-use prompting, long-context placement

## Related Skills

- [context-engineering](../context-engineering/SKILL.md) — what goes into the window (budgets, packing, compaction)
- [structured-outputs](../structured-outputs/SKILL.md) — machine-readable output contracts and validation
- `skills/evals/eval-design` — golden sets and metrics for measuring prompt changes
- `skills/llm-apps/llm-api-patterns` — provider-call discipline (timeouts, retries, caching)
- Agents: `ai-engineer:ai-prompt-engineer` (owner), `ai-engineer:ai-security-auditor` (injection review), `ai-engineer:ai-architector` (escalation decisions)
