---
name: structured-outputs
description: >-
  Get reliable JSON or typed objects from an LLM: extraction-mode choice
  (tool-call, native structured mode, prompted JSON), flat enum-closed schemas,
  the Pydantic validate → repair-once → fail-closed loop, streaming partial
  JSON, and common parse failures. Use when model output feeds code, parsing
  fails intermittently, designing an extraction or classification schema, or
  reviewing code that parses model output. Safe parse only, never eval().
---

# Structured Outputs

Model output consumed by code is untrusted input to a parser: define the schema first, always validate, and fail closed. Model output is never executed — no `eval()`, `exec()`, or `ast.literal_eval`; use `json.loads` / `model_validate_json` plus schema validation only.

**Elsewhere:**

- Wording of the instructions around the output → [prompt-design](../prompt-design/SKILL.md)
- What context the extraction call sees → [context-engineering](../context-engineering/SKILL.md)
- Measuring field-level extraction accuracy → `skills/evals/eval-design`
- Provider SDK mechanics (timeouts, retries, streaming transports) → `skills/llm-apps/llm-api-patterns`
- Worked schemas (evidence spans, abstain, batching, accumulator) → `references/schema-patterns.md`

## Extraction Mode Selection

| Mode | How it works | Choose when | Watch out |
|---|---|---|---|
| **Tool-call extraction** | Define a tool whose *input schema* is your output schema; have the model call it | Strong schema adherence, no prose contamination | Some current models reject forced `tool_choice` — use auto choice plus a prompt instruction and the provider's strict-schema flag where available. Generate tool def and validator from one Pydantic model |
| **Native structured/response-format mode** | Provider-side JSON-schema enforcement on the request | Provider/model supports it for your payload shape | Parameter names, supported models, and schema subsets vary by provider — verify current docs (context7); still validate client-side |
| **Prompted JSON** | Output contract + example in the prompt | Any provider/model; portable fallback | Most failure-prone (fences, prose, drift) — the repair loop is required |

- Prefer tool-call or native mode; keep prompted JSON as the portable fallback.
- Validate client-side in every mode. Provider enforcement reduces syntax failures; it cannot catch a wrong-but-valid enum choice, an invented value, or a truncated batch.
- One Pydantic model is the single source of truth: it generates the tool/response-format schema and validates the result.

## Schema Design for Extraction

Design the wire schema for the model's failure modes; map to your domain model after validation.

- **Flat over nested.** Each nesting level multiplies failure modes. Extract flat; assemble domain objects app-side.
- **Enums for closed sets**, with an escape value (`"other"`/`"unknown"`) so the model has a legal move instead of inventing a label.
- **Nullable-with-reason.** Pair each optional value with a status field so "absent from source" differs from "model missed it".
- **Coarse confidence over floats.** `Literal["high","medium","low"]` routes review queues; `0.87` is uncalibrated.
- **Dates and numbers as format-declared strings** (ISO 8601, plain decimal), parsed app-side — `03/04/25` and `1,249.50` corrupt silently.
- **Field descriptions are prompt surface** in tool-call and native modes — write them as instructions.
- **Forbid extras.** Unknown keys are a drift signal.

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

## The Validate → Repair → Fail-Closed Loop

Parse safely, validate against the schema, feed validation errors back once, then fail closed. Don't loop until it parses, don't default-fill, don't execute.

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

- `repair_call` re-invokes the provider with the original context plus the error text, using deterministic settings (temperature 0 where the model accepts sampling parameters; some current models reject them).
- Log and meter both failures. A rising repair rate means the prompt, schema, or model changed — wire it into the eval gate (`skills/evals/regression-gates`).
- Failing closed means raise and route to a fallback path or human queue — never return a half-parsed or default-filled object.
- Check the finish/stop reason before parsing (field name varies by provider). Truncation at the token limit is a budget bug no repair prompt fixes; a refusal stop reason is not a parse failure either.
- Full implementation with metrics hooks: `references/schema-patterns.md` § Repair Loop.

## Streaming Partial JSON

Mid-stream JSON is invalid by construction. Three strategies:

1. **Buffer-then-parse (default).** Stream for perceived latency, but parse and validate only the complete response.
2. **Progressive display only.** A tolerant partial parser may render a live preview, but no action fires from a partial value — a half-streamed `"cancel_or…"` must not trigger `cancel_order`.
3. **Item-boundary streaming for lists.** Emit one JSON object per line (NDJSON) and validate each completed line against the *item* schema as it lands — accumulator in `references/schema-patterns.md` § Streaming Accumulator.

Tool-call arguments also stream as partial-JSON deltas — accumulate, then validate the assembled arguments like any other output.

## Common Failure Modes

| Failure | Looks like | Mitigation |
|---|---|---|
| Markdown fences | ```` ```json {…} ``` ```` | Shared `extract_json_candidate`; tool-call or native mode |
| Trailing commentary | `{…} Hope this helps!` | Outermost-span extraction; "only JSON" contract |
| Hallucinated enum values | `"currency": "credits"` | Closed `Literal` enums + escape value; validation catches, repair corrects |
| Ambiguous date/number formats | `03/04/25`, `1,249.50` | Format-declared string fields; parse app-side |
| Invented fields | Extra keys appear | `extra="forbid"` → ValidationError → repair |
| Truncated JSON | Ends mid-string | Check finish/stop reason first; raise output budget or shrink schema |
| Unescaped quotes/newlines | Parse error mid-field | Repair loop; NDJSON item boundaries for long text fields |
| Python-repr output | `{'key': 'value'}` | Repair with errors, not `literal_eval` — it signals contract drift |

Assistant-turn prefill (`{`) is another fence/prose mitigation, but several current models reject prefill outright — see `../prompt-design/references/claude-prompting.md`.

## Anti-Patterns

| Pattern | Problem | Fix |
|---|---|---|
| `eval()` / `exec()` / `ast.literal_eval` on model output | Code-execution surface (OWASP LLM insecure output handling, P0 per `skills/_shared/severity-matrix.md`); `literal_eval` accepts Python-not-JSON and hides drift | `json.loads` / `model_validate_json` + schema validation only |
| `json.loads` with no schema behind it; regex field-plucking | Breaks on reorder, nesting, escaping; wrong values pass | Whole-document schema validation |
| `.replace("```json", "")` hacks copied across files | Inconsistent cleanup | One shared extractor |
| "Return JSON" prompt with no schema, example, or escape values | Model guesses the contract | Schema-driven mode or explicit contract |
| Trusting provider JSON mode ⇒ skipping validation | Valid syntax ≠ correct; support varies by model | Always validate client-side |
| Unlimited repair retries | Cost spiral; hides regressions | One repair, then fail closed |
| Float confidence `0.0-1.0` | Uncalibrated precision | Coarse `Literal` levels + review routing |
| Deeply nested wire schema | Multiplied failure modes | Flatten; assemble after validation |
| Acting on partially streamed values | Actions fire on truncated data | Act only on validated complete objects/items |
| Default-fill (`{}` or default object) on validation failure | Corrupt data flows downstream unlabeled | Fail closed; route to fallback or human |

## Verification

- [ ] Extraction mode chosen from the selection table; rationale recorded in the PR
- [ ] One Pydantic model generates the tool/response-format schema and validates the output
- [ ] `extra="forbid"`; closed enums with an escape value; nullable fields paired with status
- [ ] Dates/numbers are format-declared strings, parsed app-side
- [ ] Validate → repair-once → fail-closed implemented; repair uses deterministic settings; repairs logged and metered
- [ ] No `eval`/`exec`/`literal_eval` on model output anywhere in the diff
- [ ] Finish/stop reason checked before parsing
- [ ] Streaming: actions fire only from validated complete objects or items
- [ ] Field-level accuracy measured on a pinned eval set with deterministic settings (`skills/evals/eval-design`); parse/repair rate wired into the regression gate

## Related Skills

- [prompt-design](../prompt-design/SKILL.md) — output-contract wording, few-shot format discipline
- [context-engineering](../context-engineering/SKILL.md) — what the extraction call sees; validating compaction notes
- `skills/evals/eval-design` — field-level extraction metrics and golden sets
- `skills/llm-apps/llm-api-patterns` — provider call discipline, streaming transports, token budgeting
- Agents: `ai-engineer:llm-engineer` (implementation owner), `ai-engineer:ai-prompt-engineer` (contract wording), `ai-engineer:ai-security-auditor` (output-handling review)
