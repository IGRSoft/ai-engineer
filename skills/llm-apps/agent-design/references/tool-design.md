# Tool Design (deep dive)

Use this when:

- Writing or reviewing tool schemas for an agent loop
- The model picks the wrong tool, malformed arguments keep arriving, or one
  "do everything" tool has grown modes
- Adding idempotency, dry-run previews, or approval gates to write actions
- Setting up tests for tools, or versioning a tool set that agents depend on

Skip this file if:

- You are designing the loop around the tools — use [../SKILL.md](../SKILL.md)
- The output-schema problem is a one-shot extraction, not a tool — use
  `skills/prompt-engineering/structured-outputs`

The model never sees your implementation — only the name, description, and
schema. Those three strings *are* the API contract, and they are prompt text:
every improvement to them is a prompt improvement.

## Schema Quality Checklist

- [ ] **Name** is `verb_noun`, unambiguous, and unlike every other tool name
      (`search_orders`, not `data_tool`, not `orders2`)
- [ ] **Description** states what it does, when to use it, when **not** to use
      it (naming the alternative tool), side effects, and what an empty result
      means
- [ ] **Parameters** are typed, with `enum` for closed sets, `format`/ranges
      for values, defaults declared, and an example value in each description
- [ ] **Required list** is minimal — every required param the model must guess
      is a failure mode
- [ ] **Output shape** documented (in the description or a documented return
      schema): fields, units, ordering, empty-vs-error distinction
- [ ] **Error contract**: errors return structured payloads with a stable
      `error` code and a `retryable` flag — never raw stack traces

## Good vs Bad Schema

Bad — a mega-tool with stringly-typed everything:

```json
{
  "name": "data_tool",
  "description": "Works with customer data.",
  "input_schema": {
    "type": "object",
    "properties": {
      "action": {"type": "string", "description": "what to do"},
      "params": {"type": "string", "description": "JSON string of parameters"}
    },
    "required": ["action", "params"]
  }
}
```

Failures: `action` smuggles in N tools with zero schema support; `params` is
JSON-in-a-string the handler must re-parse (and the model must re-invent per
call); no enums, no examples, no error contract, and the description says
nothing about when to use it.

Good — one capability, closed sets, contract in the description:

```json
{
  "name": "search_orders",
  "description": "Search existing customer orders by status and date. Read-only. Use for questions about past or current orders; do NOT use to modify orders (use cancel_order). Returns up to `limit` orders, newest first. An empty list means no matches — it is not an error.",
  "input_schema": {
    "type": "object",
    "properties": {
      "status": {
        "type": "string",
        "enum": ["pending", "shipped", "delivered", "cancelled"]
      },
      "placed_after": {
        "type": "string",
        "format": "date",
        "description": "ISO date lower bound, e.g. \"2026-01-31\". Omit for no bound."
      },
      "limit": {"type": "integer", "minimum": 1, "maximum": 50, "default": 10}
    },
    "required": ["status"]
  }
}
```

## Granularity: One Capability per Tool

- A `mode`/`action` parameter that switches behavior is the mega-tool smell —
  split it. A description containing "and" usually names two tools.
- The opposite failure is real too: fifteen micro-tools force the model to
  orchestrate plumbing. If steps always run in the same order, compose them in
  code and expose the composite as one tool.
- Target a single-digit registry per agent. Past that, selection accuracy and
  context budget both degrade — prune or split the agent.
- Separate read tools from write tools. It makes allowlisting trivial
  (read-only agents get the read set) and review honest.

## Idempotency and Dry-Run

Agents retry, and models occasionally repeat an action — write tools must
survive both.

- **Idempotency key:** create-class tools accept a caller-supplied
  `idempotency_key`; the handler dedupes on it, so a repeated call is a no-op
  returning the original result.
- **Dry-run:** destructive tools accept `dry_run: true` and return a preview
  of what would happen — the natural input to a human approval gate.
- **Two-step confirm:** the dry-run response carries a short-lived
  `confirmation_token`; the executing call requires it. The model cannot skip
  the preview because the token only exists after one.

```json
{
  "name": "delete_records",
  "description": "Delete customer records matching a filter. IRREVERSIBLE. Always call with dry_run=true first; the real deletion requires the confirmation_token from that preview (expires in minutes-class time).",
  "input_schema": {
    "type": "object",
    "properties": {
      "filter_id": {"type": "string", "description": "Saved filter id from search_records"},
      "dry_run": {"type": "boolean", "default": true},
      "confirmation_token": {
        "type": "string",
        "description": "Required when dry_run=false. Returned by the dry-run preview."
      }
    },
    "required": ["filter_id"]
  }
}
```

## Dangerous-Action Gating

Treat the model as an untrusted caller — the tool boundary is a trust
boundary (excessive agency / insecure output handling, OWASP LLM Top 10;
review with `ai-engineer:ai-security-auditor`):

- **Capability tiers:** classify every tool `read` / `write` / `irreversible`;
  allowlist per agent; irreversible requires the two-step confirm plus a human
  approval in the loop ([../SKILL.md](../SKILL.md) Guardrails).
- **Server-side validation:** re-validate every argument in the handler —
  schema conformance is enforced by *you*, not assumed from the model.
- **No string assembly:** arguments never interpolate into shell commands or
  SQL — parameterize, use allowlisted subcommands, escape at the boundary.
- **Least privilege:** each tool runs with its own scoped credential, not the
  service's god-token.
- **Audit log:** every invocation logged with args (redacted), caller run id,
  and outcome — the agent's actions must be reconstructable.

## Testing Tools in Isolation

Tools are ordinary functions — test them without any model in the loop:

- **Unit tests** on the handler: happy path, empty results, each error code.
- **Contract tests:** the published schema matches the implementation — reject
  unknown fields, exercise every enum member, check defaults actually apply.
- **Adversarial fixtures** (model-shaped bad input): missing required params,
  wrong types, boundary values, absurd sizes, and injection payloads in every
  string field (`"; rm -rf /"`, `' OR 1=1 --`, "ignore previous instructions").
- **Record/replay integration:** pin real transcripts as fixtures so loop
  tests run deterministically without live tool backends.

```python
import pytest

from app.tools.orders import search_orders  # run: uv run pytest tests/tools -q


def test_unknown_status_rejected() -> None:
    with pytest.raises(ToolValidationError) as err:
        search_orders(status="exploded", limit=10)
    assert err.value.code == "invalid_enum"  # structured error, not a traceback


def test_injection_string_is_inert() -> None:
    result = search_orders(status="pending", placed_after="2026-01-01'; DROP TABLE--")
    assert result.error is not None and result.error.retryable is False
```

## Versioning Tool Sets

The tool set is part of the prompt surface: renaming a tool or rewording a
description changes model behavior exactly like editing the system prompt.

- Version the registry as a unit (`tools-v7`); record the version in every
  step trace so transcripts are interpretable later.
- Any change — even "just the description" — goes through the eval set and the
  regression gate (`skills/evals/regression-gates`) before rollout.
- Evolve additively: add the new tool, migrate, then remove the old one after
  its usage in traces drops to zero. In-place behavior swaps under an old name
  are silent breakage.
- Keep a per-version changelog next to the registry; agents pin a registry
  version the way code pins a lockfile.
