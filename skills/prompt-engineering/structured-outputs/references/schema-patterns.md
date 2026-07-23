# Schema Patterns — Worked Examples

Use this when:

- You are implementing an extraction/classification feature and want a proven schema shape to start from
- You need the full repair-loop or streaming-accumulator implementation referenced from [../SKILL.md](../SKILL.md)
- A review found hallucinated extractions, dropped batch items, or actions firing on partial streams

Skip this file if:

- You need mode selection or schema-design principles → [../SKILL.md](../SKILL.md)
- You need the prompt wording around the schema → `../../prompt-design/SKILL.md`

All examples: Pydantic v2, type-hinted, `uv add pydantic`; test each schema against a golden set with `uv run pytest` (`skills/evals/eval-design`). Shared imports assumed: `from typing import Literal, Protocol, Self` and `from pydantic import BaseModel, ConfigDict, Field, ValidationError, model_validator`.

## 1. Extraction with Evidence Spans

Every extracted value carries a verbatim quote. Post-parse verification checks the quote actually occurs in the source — hallucinated extractions fail mechanically, without a judge model.

```python
class ExtractedFact(BaseModel):
    model_config = ConfigDict(extra="forbid")

    field: Literal["vendor_name", "total_amount", "issue_date"]
    value: str
    evidence_quote: str = Field(
        description="Verbatim quote from the source document that contains the value"
    )


def _normalize(text: str) -> str:
    return " ".join(text.split())


def verify_evidence(
    facts: list[ExtractedFact], source: str
) -> tuple[list[ExtractedFact], list[ExtractedFact]]:
    """Split facts into (grounded, rejected) by literal quote presence in source."""
    src = _normalize(source)
    grounded = [f for f in facts if _normalize(f.evidence_quote) in src]
    rejected = [f for f in facts if _normalize(f.evidence_quote) not in src]
    return grounded, rejected
```

Rejected facts are a first-class metric — a rising rejection rate is your hallucination alarm. Whitespace-normalize both sides; models re-wrap lines. Rejected ≠ silently dropped: route to the fail-closed path or a review queue.

## 2. Classification with Confidence + Abstain

`abstain` is a legal label, so the model has an alternative to guessing; the validator makes abstention and reason travel together.

```python
class TicketClassification(BaseModel):
    model_config = ConfigDict(extra="forbid")

    label: Literal["billing", "bug", "how_to", "account", "abstain"]
    confidence: Literal["high", "medium", "low"]
    abstain_reason: str | None = None

    @model_validator(mode="after")
    def _abstain_contract(self) -> Self:
        if self.label == "abstain" and not self.abstain_reason:
            raise ValueError("label=abstain requires abstain_reason")
        if self.label != "abstain" and self.abstain_reason:
            raise ValueError("abstain_reason is only valid with label=abstain")
        return self
```

Routing convention:

| Result | Action |
|---|---|
| `high` | Auto-apply |
| `medium` | Auto-apply + sampled human audit |
| `low` or `abstain` | Human queue |

Track the abstain rate on the pinned eval set — a jump in either direction after a prompt/model change is a regression signal even when accuracy "looks fine".

## 3. Batched Item Extraction

Batch outputs fail by *dropping* or *duplicating* items. The envelope forces per-input accounting: every input id must land in exactly one of `items` / `skipped`.

```python
class LineItem(BaseModel):
    model_config = ConfigDict(extra="forbid")

    source_id: str = Field(description="Echo the id of the input row this item came from")
    name: str
    qty: int
    unit_price: str | None = Field(default=None, description="Decimal string, e.g. '4.00'")


class SkippedItem(BaseModel):
    model_config = ConfigDict(extra="forbid")

    source_id: str
    reason: Literal["not_a_line_item", "unreadable", "duplicate"]


class BatchExtraction(BaseModel):
    model_config = ConfigDict(extra="forbid")

    items: list[LineItem]
    skipped: list[SkippedItem]


def check_coverage(batch: BatchExtraction, input_ids: list[str]) -> None:
    """Every input id appears exactly once across items + skipped."""
    seen = sorted(
        [i.source_id for i in batch.items] + [s.source_id for s in batch.skipped]
    )
    if seen != sorted(input_ids):
        raise ExtractionError(f"coverage mismatch: got {seen}, want {sorted(input_ids)}")
```

Cap batch size (~10-20 items per call) and chunk the input — large batches drive truncation and mid-list format drift. Coverage failure goes through the repair loop like any validation error (stringify it into the error feedback).

## 4. Repair Loop — Full Implementation

The complete version of [../SKILL.md](../SKILL.md) § Validate → Repair → Fail-Closed: fence/prose stripping, truncation guard, metrics.

```python
import re
from collections.abc import Callable
from dataclasses import dataclass


class ExtractionError(Exception):
    """Raised when output fails validation after one repair, or was truncated."""


class ModelResponse(Protocol):
    text: str
    stopped_naturally: bool  # finish/stop reason == natural end; field name varies by provider — map it in your adapter


@dataclass
class ExtractionMetrics:
    calls: int = 0
    first_pass_failures: int = 0
    repairs_succeeded: int = 0
    failed_closed: int = 0


def extract_json_candidate(text: str) -> str:
    """Strip code fences and prose; return the outermost {...} or [...] span."""
    text = re.sub(r"^```(?:json)?\s*|```\s*$", "", text.strip(), flags=re.MULTILINE)
    starts = [i for i in (text.find("{"), text.find("[")) if i != -1]
    if not starts:
        return text.strip()  # nothing JSON-like: let the validator raise the real error
    start, end = min(starts), max(text.rfind("}"), text.rfind("]"))
    return text[start : end + 1] if end > start else text[start:]


def parse_or_repair[M: BaseModel](
    schema: type[M],
    response: ModelResponse,
    repair_call: Callable[[str], ModelResponse],
    metrics: ExtractionMetrics,
) -> M:
    """Validate; one deterministic repair round with the errors; then fail closed."""
    metrics.calls += 1
    if not response.stopped_naturally:
        metrics.failed_closed += 1
        raise ExtractionError("output truncated at token limit — fix the budget, not the parse")
    try:
        return schema.model_validate_json(extract_json_candidate(response.text))
    except ValidationError as first:
        metrics.first_pass_failures += 1
        repaired = repair_call(
            "Your previous output failed schema validation.\n"
            f"Validation errors:\n{first}\n"
            "Return ONLY the corrected JSON. No commentary, no code fences."
        )
        try:
            result = schema.model_validate_json(extract_json_candidate(repaired.text))
        except ValidationError as second:
            metrics.failed_closed += 1
            raise ExtractionError("validation failed after one repair") from second
        metrics.repairs_succeeded += 1
        return result
```

`repair_call` re-invokes the provider with the original messages plus the error feedback, at temperature 0. Export `ExtractionMetrics` to your tracker (`skills/mlops/model-monitoring`); gate releases on the repair rate (`skills/evals/regression-gates`). Never call `eval`/`exec`/`ast.literal_eval` anywhere in this path.

## 5. Streaming Accumulator (NDJSON Item Boundaries)

For long batched extractions: the model emits one JSON object per line; each completed line validates against the *item* schema immediately, so consumers act on validated items while the stream continues.

```python
from collections.abc import Iterator


class NdjsonAccumulator[M: BaseModel]:
    """Accumulate streamed text deltas; yield schema-validated items per line."""

    def __init__(self, item_schema: type[M]) -> None:
        self._schema = item_schema
        self._buf = ""
        self.errors: list[tuple[str, ValidationError]] = []

    def feed(self, delta: str) -> Iterator[M]:
        self._buf += delta
        while "\n" in self._buf:
            line, self._buf = self._buf.split("\n", 1)
            if (item := self._validate(line)) is not None:
                yield item

    def finish(self) -> Iterator[M]:
        """Flush the trailing buffer; call exactly once after the stream ends."""
        if (item := self._validate(self._buf)) is not None:
            yield item
        self._buf = ""

    def _validate(self, line: str) -> M | None:
        if not (line := line.strip()):
            return None
        try:
            return self._schema.model_validate_json(line)
        except ValidationError as e:
            self.errors.append((line, e))
            return None
```

Policy at stream end: if `errors` is non-empty, fail closed or route the failed lines to the repair loop — never silently drop them. Only *validated* items may trigger actions; a line still in `_buf` is display-only ([../SKILL.md](../SKILL.md) § Streaming Partial JSON). The same accumulator shape works for streamed tool-call argument deltas: buffer, then validate the assembled arguments.

## Pattern Selection

| Need | Pattern |
|---|---|
| Auditable single-record extraction | 1 (evidence spans) + 4 |
| Routing/triage with a safe "don't know" | 2 (confidence + abstain) |
| Many records from one document | 3 (batched envelope) + 4; stream via 5 when long |
| Any prompted-JSON mode in production | 4 is mandatory, not optional |
| Live UI over a long extraction | 5, actions on validated items only |
