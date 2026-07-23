---
name: structured-outputs
description: >-
  Reliable machine-readable LLM output: extraction-mode selection (tool-call vs
  native structured modes vs prompted JSON), JSON schema design (flat over
  nested, enums, nullable-with-reason), the Pydantic validate → repair-once →
  fail-closed loop, streaming partial JSON, and failure modes (markdown fences,
  trailing prose, hallucinated enums). Use when an LLM must return JSON or feed
  downstream code, when parsing fails intermittently, when designing an
  extraction or classification schema, or when reviewing code that parses
  model output. Never eval() model output — safe parse only.
---

# Structured Outputs

**Model output that feeds code is untrusted input to a parser — schema-first, validate always, fail closed**

## Overview

The moment an LLM's answer is consumed by code instead of a human, it stops being "a response" and becomes a wire format produced by an unreliable serializer. This skill covers making that wire format dependable: choosing the extraction mode, designing schemas that models can actually fill, validating with Pydantic, repairing exactly once, failing closed, and handling streams. The security floor throughout: model output is **never** executed — no `eval()`, no `exec()`, no `ast.literal_eval` — safe parsing (`json.loads` / `model_validate_json`) plus schema validation only.

## When to Use

- A feature returns JSON or a typed object consumed by downstream code
- Building extraction, classification, form-filling, or routing on an LLM
- Parsing failures are intermittent and "usually it works" is the current strategy
- Designing or reviewing an extraction/classification schema
- Streaming structured output to a UI or into a pipeline
- Reviewing any code that parses model output

**When NOT to use:**

- Wording and structure of the instructions around the output → [prompt-design](../prompt-design/SKILL.md)
- Deciding what context the extraction call sees → [context-engineering](../context-engineering/SKILL.md)
- Measuring field-level extraction accuracy → `skills/evals/eval-design`
- Provider SDK mechanics — timeouts, retries, streaming transports → `skills/llm-apps/llm-api-patterns`
- Worked schema examples (evidence spans, abstain, batching, accumulator) → `references/schema-patterns.md`

## Extraction Mode Selection

Three ways to get structured output; pick deliberately, per feature:

| Mode | How it works | Choose when | Watch out |
|---|---|---|---|
| **Tool-call extraction** | Define a tool whose *input schema* is your output schema; force the model to call it | Provider supports forced tool choice; strongest schema adherence; no prose contamination | Tool def and validator drift apart — generate both from one Pydantic model |
| **Native structured/response-format mode** | Provider-side JSON or JSON-schema enforcement flag on the request | Provider/model supports it for your payload shape | Feature names, supported models, and schema subsets vary by provider — verify current docs (context7); still validate client-side |
| **Prompted JSON** | Output contract + example in the prompt; optionally prefill `{` | Any provider/model; maximum portability; last resort or fallback path | Most failure-prone: fences, prose, drift — the repair loop is mandatory |

Selection rules:

1. Prefer tool-call or native mode when available; keep prompted JSON as the portable fallback.
2. **Client-side validation is non-negotiable in every mode.** Provider-side enforcement reduces syntactic failures; it cannot catch a semantically wrong (but schema-valid) enum choice, an invented value, or a truncated batch.
3. Whatever the mode, one Pydantic model is the single source of truth — it generates the tool/response-format schema *and* validates the result.

## Schema Design for Extraction

Design for the model's failure modes, not for your domain model's elegance:

- **Flat > nested.** Every nesting level multiplies failure modes (missing branches, misplaced fields). Extract flat; assemble domain objects app-side after validation.
- **Enums for closed sets** — with an explicit escape value (`"other"`/`"unknown"`) so the model has a legal move when unsure, instead of inventing a label.
- **Nullable-with-reason.** Pair every optional value with a status field so "absent from source" is distinguishable from "model missed it".
- **Coarse confidence over floats.** `Literal["high","medium","low"]` routes review queues; a `0.87` is pseudo-calibration models cannot back.
- **Dates and numbers as format-declared strings** (ISO 8601, plain decimal) parsed app-side — locale-ambiguous formats (`03/04/25`, `1,249.50`) are a classic silent corruption.
- **Field descriptions are prompt surface.** In tool-call and native modes the schema descriptions are what the model reads — write them like instructions.
- **Forbid extras.** Unknown keys are a drift signal, not free data.

```python
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class InvoiceExtraction(BaseModel):
    """Wire schema for invoice extraction — flat, enum-closed, audit-ready."""

    model_config = ConfigDict(extra="forbid")

    vendor_name: str | None = None
    vendor_name_status: Literal["found", "not_present", "ambiguous"] = "not_present"
    total_amount: str | None = Field(
        default=None, description="Decimal string, e.g. '1249.50'. No currency symbol, no thousands separators."
    )
    currency: Literal["USD", "EUR", "GBP", "UAH", "OTHER"] = "OTHER"
    issue_date: str | None = Field(default=None, description="ISO 8601 date: YYYY-MM-DD")
    confidence: Literal["high", "medium", "low"]
```

Worked variants — evidence spans, abstain classification, batched items: `references/schema-patterns.md`.

## The Validate → Repair → Fail-Closed Loop

The contract: parse safely, validate against the schema, feed validation errors back **exactly once**, then fail closed. Never loop until it parses; never default-fill; never execute.

```python
from collections.abc import Callable

from pydantic import BaseModel, ValidationError


class ExtractionError(Exception):
    """Raised when model output fails schema validation after one repair round."""


def extract_json_candidate(text: str) -> str:
    """Isolate the outermost JSON value: strip code fences and surrounding prose."""
    cleaned = text.strip().removeprefix("```json").removeprefix("```").removesuffix("```")
    start = min((i for i in (cleaned.find("{"), cleaned.find("[")) if i != -1), default=0)
    end = max(cleaned.rfind("}"), cleaned.rfind("]")) + 1 or len(cleaned)
    return cleaned[start:end].strip()


def parse_or_repair[M: BaseModel](
    schema: type[M],
    raw: str,
    repair_call: Callable[[str], str],
) -> M:
    """Validate raw model output against schema; one repair round; then fail closed.

    Raises ExtractionError when the repaired output still fails validation.
    """
    try:
        return schema.model_validate_json(extract_json_candidate(raw))
    except ValidationError as first:
        repaired = repair_call(
            "Your previous output failed schema validation.\n"
            f"Validation errors:\n{first}\n"
            "Return ONLY the corrected JSON object. No commentary, no code fences."
        )
        try:
            return schema.model_validate_json(extract_json_candidate(repaired))
        except ValidationError as second:
            raise ExtractionError("schema validation failed after one repair") from second
```

Discipline around the loop:

- `repair_call` re-invokes the provider with the original context plus the error text, at **temperature 0** — a deterministic repair, not another roll of the dice.
- **Log and meter both failures.** Repair rate is a first-class metric: a rising rate means the prompt, schema, or model changed — wire it into the eval gate (`skills/evals/regression-gates`).
- **Fail closed means fail closed**: raise, route to a fallback path or human queue — never return a half-parsed object or a default-filled one.
- **Check the finish/stop reason before parsing** (field name varies by provider — verify current docs): output truncated at the token limit is a budget bug, and no repair prompt fixes it.
- Full implementation with metrics hooks: `references/schema-patterns.md` § Repair Loop.

## Streaming Partial JSON

Mid-stream JSON is invalid by construction — the stream ends inside a string or before a closing brace. Three strategies:

1. **Buffer-then-parse (default).** Stream for perceived latency (typing indicator, token ticker), but parse and validate only the complete response. Simplest, correct, right for most features.
2. **Progressive display only.** A tolerant partial parser may render a live preview, but **no action fires from a partial value** — a half-streamed `"cancel_or…"` must never trigger `cancel_order`. Partial values are pixels, not data.
3. **Item-boundary streaming for lists.** Emit one JSON object per line (NDJSON); validate each completed line against the *item* schema as it lands. This is the pattern for long batched extractions — accumulator implementation in `references/schema-patterns.md` § Streaming Accumulator.

Tool-call arguments also stream as partial-JSON deltas on current provider APIs (verify mechanics in current docs) — accumulate deltas, then validate the assembled arguments exactly like any other output.

## Common Failure Modes

| Failure | Looks like | Mitigation |
|---|---|---|
| Markdown fences | ```` ```json {…} ``` ```` | Fence-strip in `extract_json_candidate`; prefill `{`; tool-call mode |
| Trailing commentary | `{…} Hope this helps!` | Outermost-span extraction; "ONLY JSON" contract; prefill |
| Hallucinated enum values | `"currency": "credits"` | Closed `Literal` enums + escape value; validation catches, repair corrects |
| Ambiguous date/number formats | `03/04/25`, `1,249.50` | Format-declared string fields; parse app-side |
| Invented fields | Extra keys appear | `extra="forbid"` → ValidationError → repair |
| Truncated JSON | Ends mid-string | Check finish/stop reason first; raise output budget or shrink schema |
| Unescaped quotes/newlines | Parse error mid-field | Repair loop; NDJSON item boundaries for long text fields |
| Python-repr output | `{'key': 'value'}` single quotes | Do **not** paper over with `literal_eval` — repair with errors; it signals contract drift |

## Anti-Patterns

| Pattern | Problem | Fix |
|---|---|---|
| `eval()` / `exec()` / `ast.literal_eval` on model output | Code-execution surface (OWASP LLM insecure output handling); `literal_eval` accepts Python-not-JSON and masks drift | `json.loads` / `model_validate_json` + schema validation only |
| Regex field-plucking from responses | Breaks on reorder, nesting, escaping | Whole-document schema validation |
| Trusting provider JSON mode ⇒ skipping validation | Syntactically valid ≠ correct; mode support varies by model | Always validate client-side |
| Unlimited repair retries | Cost spiral; hides prompt/schema regressions | Exactly one repair, then fail closed |
| Float confidence `0.0-1.0` | Uncalibrated precision theater | Coarse `Literal` levels + review routing |
| Deeply nested wire schema | Multiplied failure modes | Flatten; assemble domain objects after validation |
| Acting on partially streamed values | Actions fire on truncated data | Act only on validated complete objects/items |
| Silent default-fill on validation failure | Corrupt data flows downstream unlabeled | Fail closed; route to fallback or human |

## Common Rationalizations

| Excuse | Reality |
|---|---|
| "The model almost always returns valid JSON" | At production volume, "almost always" is a daily incident. The repair loop costs ~20 lines once. |
| "`literal_eval` is safe, it doesn't execute code" | It accepts Python semantics JSON forbids, so contract drift parses "successfully" — you lose the failure signal that would have caught the regression. |
| "We'll just retry until it parses" | Unbounded retries burn spend and hide regressions behind eventual success. One repair with the errors, then fail. |
| "JSON mode means I can skip Pydantic" | Provider modes guarantee syntax at best. Wrong enum choice, invented values, and truncation all pass through. |
| "The schema should mirror our domain model" | The wire schema is optimized for model reliability (flat, enums, strings); the domain model for your app. Map between them after validation. |

## Red Flags

- `json.loads` calls scattered around the codebase with no schema validation behind them
- `try/except` around a parse that returns `{}` or a default object
- `.replace("```json", "")` hacks duplicated across files instead of one shared extractor
- A prompt that says "return JSON" with no schema, no example, no escape values
- No metric for parse-failure or repair rate
- UI or pipeline actions wired to partially streamed field values
- `eval`, `exec`, or `ast.literal_eval` anywhere near model output — P0 per `skills/_shared/severity-matrix.md`

## Verification

- [ ] Extraction mode chosen from the selection table; rationale recorded in the PR
- [ ] One Pydantic model generates the tool/response-format schema *and* validates the output
- [ ] `extra="forbid"`; closed enums with an escape value; nullable fields paired with status
- [ ] Dates/numbers are format-declared strings, parsed app-side
- [ ] Validate → repair-once → fail-closed implemented; repair at temperature 0; repairs logged and metered
- [ ] No `eval`/`exec`/`literal_eval` on model output anywhere in the diff
- [ ] Finish/stop reason checked before parsing
- [ ] Streaming: actions fire only from validated complete objects or items
- [ ] Field-level accuracy measured on a pinned eval set, deterministic settings (`skills/evals/eval-design`); parse/repair rate wired into the regression gate

## Deep-Dive References

- `references/schema-patterns.md` — worked schemas: extraction with evidence spans, classification with confidence + abstain, batched item extraction, full repair-loop implementation, streaming accumulator

## Related Skills

- [prompt-design](../prompt-design/SKILL.md) — output-contract wording, prefilling, few-shot format discipline
- [context-engineering](../context-engineering/SKILL.md) — what the extraction call sees; validating compaction notes
- `skills/evals/eval-design` — field-level extraction metrics and golden sets
- `skills/llm-apps/llm-api-patterns` — provider call discipline, streaming transports, token budgeting
- Agents: `ai-engineer:llm-engineer` (implementation owner), `ai-engineer:ai-prompt-engineer` (contract wording), `ai-engineer:ai-security-auditor` (output-handling review)
