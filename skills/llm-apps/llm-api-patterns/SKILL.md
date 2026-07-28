---
name: llm-api-patterns
description: >-
  Production LLM provider-API integration: timeout and retry/backoff
  discipline, rate-limit handling, streaming with TTFT and mid-stream error
  recovery, prompt caching via stable-prefix structure, batch APIs for
  offline work, provider/model fallback chains with circuit breakers, cost
  accounting hooks, request-level observability, and secrets hygiene. Use
  when writing or reviewing any code that calls an LLM API, when requests
  hang or fail without retries, when hitting 429s or rate limits, when spend
  is untracked or spiking, or when adding streaming, caching, batching, or
  multi-provider fallback.
---

# LLM API Patterns

## Overview

A provider API is a remote dependency that bills per token and fails in every
way distributed systems fail — plus a few of its own (mid-stream truncation,
content refusals, silent model deprecations). Production integration is client
discipline: bounded calls, honest retries, streamed UX, cache-shaped prompts,
routed fallbacks, and a cost ledger.

One rule governs this whole skill: **parameter names, error codes, limits,
model IDs, and prices are volatile — never code them from memory; verify
against current provider docs (context7)**. This skill teaches the mechanisms
that stay stable across those churns.

Owning agent: `ai-engineer:llm-engineer`. Key handling, leakage, and
output-trust findings route to `ai-engineer:ai-security-auditor`.

## When to Use

- Writing or reviewing any code path that calls an LLM provider API
- Requests hang, fail without retry, or retry-storm into rate limits
- Adding streaming, prompt caching, batch processing, or fallback routing
- Spend is untracked, spiking, or unattributable to features
- Standing up observability for LLM calls (latency, tokens, request IDs)

**When NOT to use:**

- Designing the retrieval pipeline the calls serve — see
  `skills/llm-apps/rag-systems`
- Designing the loop and tool orchestration around the calls — see
  `skills/llm-apps/agent-design`
- Prompt content and iteration — see `skills/prompt-engineering/prompt-design`;
  output schemas — see `skills/prompt-engineering/structured-outputs`
- Operating self-hosted inference (vLLM/TGI/Ollama servers, GPUs,
  quantization) — see `skills/mlops/model-serving`; this skill covers the
  *client* side either way
- Comparing provider capabilities or planning a migration — read
  `references/provider-matrix.md`

## Call Discipline (non-negotiables)

Classify before you handle — the failure taxonomy drives every client
decision:

| Class | Typical signals | Action |
|-------|-----------------|--------|
| Transient | Timeouts, connection resets, 429, 5xx, provider "overloaded" codes | Retry with exponential backoff + jitter; honor server retry hints |
| Semantic | 400/422 invalid request, schema violations, context overflow | Never retry — the same request fails the same way; fix and alert |
| Auth/permission | 401/403, expired or mis-scoped key | Never retry; rotate/fix credentials, alert |
| Content | Refusals, safety stops, empty completions | Not an HTTP error — handle in application logic, count separately |

The exact status codes and error type names vary per provider and SDK
version — verify the current retryable set via provider docs (context7).

Rules:

1. **Timeout ALWAYS.** Explicit connect + read timeouts on every call; a
   missing timeout is a hung worker under incident load. Streaming needs an
   *idle* (per-chunk) timeout too — a stream that stops emitting is a failure
   even though the socket is open.
2. **Retry only transient classes.** Cap attempts, use exponential backoff
   with full jitter, and let a server-provided retry-after hint override your
   own delay.
3. **Respect rate-limit headers.** Providers expose retry-after and
   remaining-quota style headers (names vary — verify); feed them into your
   scheduler instead of discovering limits by 429.
4. **Bound concurrency client-side.** A semaphore or queue in front of the
   client turns provider limits into a plan instead of an error storm.

```python
import random
import time

from app.llm.client import CompletionRequest, CompletionResponse, TransientAPIError, client

MAX_ATTEMPTS = 5
BACKOFF_CAP_S = 30.0


def call_with_backoff(request: CompletionRequest) -> CompletionResponse:
    """Bounded call: explicit timeouts, retries on transient failures only."""
    for attempt in range(1, MAX_ATTEMPTS + 1):
        try:
            # timeout/retry parameter names differ per SDK — verify via
            # provider docs (context7); many SDKs ship built-in retry knobs:
            # prefer those over hand-rolling once verified.
            return client.complete(request, connect_timeout_s=5, read_timeout_s=60)
        except TransientAPIError as err:
            if attempt == MAX_ATTEMPTS:
                raise
            delay = min(float(2**attempt), BACKOFF_CAP_S) * random.random()  # full jitter
            time.sleep(max(delay, err.retry_after_s or 0.0))  # server hint wins
    raise AssertionError("unreachable")
```

Semantic errors deliberately propagate: retrying a malformed request only
spends money reproducing the bug.

## Streaming

Time-to-first-token (TTFT) is the user-perceived latency; total duration is
almost irrelevant next to it. Stream every user-facing generation longer than
a heartbeat.

- **Accumulate partials.** Render deltas incrementally, but build the
  canonical final text from the SDK's terminal/accumulated event where one is
  provided, rather than trusting your own concatenation — event shapes vary
  per provider (verify via docs).
- **Mid-stream errors.** The connection can die after real content has
  rendered. Decide the salvage policy per surface: chat UIs keep the partial
  and offer retry; pipelines discard and re-issue the whole call, because a
  half-streamed JSON payload is poison downstream.
- **Client disconnects.** Propagate cancellation upstream when the user
  leaves — an abandoned stream that runs to completion is pure token spend.
- **Usage arrives at the end.** Token counts ride the terminal stream event;
  capture them there or your cost ledger goes blind on streamed traffic.

```python
async def stream_answer(request: CompletionRequest, ui: StreamSink) -> str:
    """Stream deltas to the UI; salvage partial text on mid-stream failure."""
    rendered: list[str] = []
    try:
        async with client.stream(request, idle_timeout_s=20) as events:
            async for event in events:
                if event.delta:
                    rendered.append(event.delta)
                    await ui.append(event.delta)
                if event.is_terminal:
                    record_usage(request, event.usage)  # only source of streamed usage
                    return event.final_text  # SDK-accumulated canonical text
    except TransientAPIError:
        await ui.mark_interrupted()  # keep partial visible; offer retry affordance
    return "".join(rendered)
```

## Prompt Caching and Batching

**Caching mechanism:** providers cache a prompt *prefix* and charge/serve
cache hits differently from fresh input tokens. A hit requires the prefix to
be byte-identical up to the cache boundary — so cache design is prompt
layout, not an infra flag:

```
┌───────────────────────────────┐
│ system rules      (stable)    │ ┐
│ tool definitions  (stable)    │ ├─ cacheable prefix — identical every call
│ corpus / examples (stable)    │ ┘
├───────────────────────────────┤
│ session context   (semi)      │ ── changes per session
│ user turn         (volatile)  │ ── changes per call — always last
└───────────────────────────────┘
```

- Order prompt parts by change frequency: stable first, volatile last. One
  timestamp interpolated into the system block zeroes the hit rate.
- Some providers cache automatically; others need explicit cache-control
  breakpoints, with minimum-length and TTL-class behavior that differs —
  verify the mechanism and current parameter names via provider docs
  (context7).
- Measure: usage responses report cache-read vs fresh input tokens; monitor
  the hit rate and alarm on collapse (a prompt refactor that reorders
  segments is the usual cause).

**Batching mechanism:** provider batch APIs accept a file/list of requests
and return results asynchronously (minutes-to-hours class) at a lower cost
class — for offline work only: evals, backfills, enrichment, migrations.

- Key every item with your own `custom_id`; results return unordered.
- Handle per-item failures — a batch is not transactional; resubmit only the
  failed subset (idempotent by your ids).
- Never put interactive traffic on a batch path, and never let batch jobs
  bypass the same cost ledger as online traffic.

## Fallback Routing and Circuit Breakers

Single-provider is a single point of failure; naive multi-provider is silent
capability loss. Route deliberately:

```yaml
# fallback chain — config, not code
route: answer_generation
hops:
  - provider: primary            # resolve concrete model aliases from config;
    model_alias: main-large      # never hardcode model IDs in code
    requires: [tool_use, structured_output]
  - provider: primary
    model_alias: main-small     # same provider, cheaper tier: keeps parity
    requires: [tool_use, structured_output]
  - provider: secondary
    model_alias: alt-large
    requires: [structured_output]   # tool formats differ → this hop degrades
    degraded: no_tools
breaker:
  window_s: 60
  open_after_error_rate: 0.5
  half_open_probe_s: 30
```

- **Capability parity caveat:** structured-output modes, tool-call formats,
  multimodality, and context classes differ across providers
  (`references/provider-matrix.md`). Declare per-hop capability requirements
  and skip hops that cannot satisfy them — a fallback that silently drops
  tool use is an outage with extra steps.
- **Degrade knowingly:** tag every response with the hop that served it, so
  quality dips correlate with routing, and degraded modes surface in logs.
- **Circuit breakers:** per provider+model key; open on error-rate threshold,
  probe half-open, close on success. Breakers turn a provider incident into a
  routing event instead of a retry storm.
- **Parity is an eval question:** any hop added to the chain runs the eval set
  (pinned version, temperature 0) before it may serve traffic —
  `skills/evals/regression-gates`.

## Cost Accounting and Observability

Cost is a first-class output of every call — capture it at the source:

```python
from typing import TypedDict


class LLMCallRecord(TypedDict):
    request_id: str  # yours + the provider's echo, for support tickets
    route: str  # feature/route name — spend must be attributable
    provider: str
    model: str  # resolved alias from config, recorded as sent
    prompt_version: str
    tokens_in: int
    tokens_out: int
    tokens_cached: int  # cache-read tokens, from usage fields
    ttft_ms: int | None  # streamed calls
    total_ms: int
    outcome: str  # ok | transient_fail | semantic_fail | refusal | fallback_hop_n


def record_usage(request: CompletionRequest, usage: Usage) -> None:
    """One structured log line per call — the raw ledger for cost and latency."""
    ...
```

- **Token counting hooks:** read usage from every response — including the
  terminal stream event and each batch result. For pre-flight budget checks,
  use the provider's tokenizer/counting endpoint where offered (verify via
  docs) rather than a lookalike tokenizer.
- **Cost logging as a mechanism:** compute cost as `tokens × rate`, with
  rates loaded from a config you maintain with effective dates. Never
  hardcode prices in code or docs — they change; the *join* of usage ledger ×
  rates table is the mechanism that survives every price change.
- **Budget alarms:** per-route daily token budgets with warning and hard-stop
  thresholds; runaway agents are the classic trigger (budget design:
  `skills/llm-apps/agent-design`).
- **Histograms, not averages:** TTFT, total latency, and tokens-per-request
  are long-tailed; p50/p95/p99 or the dashboard lies.
- **Secrets:** API keys come from env vars or a secret manager, injected at
  runtime — never in code, notebooks, prompts, logs, or committed configs.
  Scan the repo (`gitleaks`-class tooling) and route findings to
  `ai-engineer:ai-security-auditor`.

## Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| Calls with no timeout | Hung workers, pool exhaustion during provider incidents | Explicit connect + read (+ stream idle) timeouts everywhere |
| Retrying 400-class errors | Same failure repeated at token prices | Taxonomy first: retry transient only |
| Fixed `sleep(1)` retry loops | Synchronized thundering herd on recovery | Exponential backoff + full jitter + retry-after hints |
| Prompt assembled volatile-first | Cache hit rate ~0; full price every call | Stable prefix / volatile suffix layout |
| Interactive traffic on batch APIs | Users wait minutes-to-hours | Batch is for offline jobs only |
| Fallback hop without parity check | Tool use / schema support silently vanishes | Per-hop capability requirements (`references/provider-matrix.md`) |
| Prices hardcoded in code | Ledger silently wrong after every pricing change | Rates config with effective dates; join at read time |
| Model IDs scattered as string literals | Deprecations become a 14-file hunt | Single config of aliases → concrete IDs, verified via docs |
| API keys in code or notebooks | Leakage into VCS and logs | Env/secret manager only; repo scanning in CI |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "The SDK surely has sane default timeouts" | Verify — several default to none or minutes-class. Own your timeouts explicitly. |
| "More retries will fix the 429s" | 429 means *slow down*: honor retry-after and bound concurrency. More retries extend the outage. |
| "We'll add caching later as an optimization" | Caching is a prompt-*structure* decision. Retrofitting reorders the prompt, which invalidates prompt evals — design cache-first now. |
| "We'll catch cost spikes on the invoice" | That is up to 30 days late. Per-request usage logging plus a budget alarm is a day of work. |
| "Both providers support JSON output, switching is trivial" | The mechanisms differ (`references/provider-matrix.md`); behavior differs more. Every provider/model change re-runs the eval set. |
| "The model ID is stable, hardcoding is fine" | Providers deprecate on their schedule, not yours. Aliases in config, verified via current docs (context7). |

## Red Flags

- `client.complete(...)` with no timeout argument anywhere in the codebase
- A bare `except Exception: retry()` around provider calls
- Zero usage/latency log lines per call — spend unattributable to features
- Grep finds the same model ID string in a dozen files
- Cache hit rate unmonitored, or prompt segments ordered user-turn-first
- Fallback chain exists but has never been exercised (no chaos/drill test)
- Streaming handler without an idle timeout or a cancellation path
- A `.env` file with real keys tracked in git

## Verification

- [ ] Every provider call: explicit timeouts, bounded retries on transient classes only, jittered backoff, retry-after honored
- [ ] Concurrency bounded client-side; rate-limit headers feed the scheduler
- [ ] User-facing generations stream; TTFT measured; mid-stream salvage policy defined per surface; cancellation propagates
- [ ] Prompts laid out stable-prefix-first; cache hit rate monitored with an alarm
- [ ] Offline bulk work uses batch APIs with custom ids and per-item failure handling
- [ ] Fallback chain declares per-hop capability requirements; circuit breaker per provider+model; fallback-served responses tagged
- [ ] Per-request usage ledger (tokens in/out/cached, TTFT, outcome, route); rates in config, never in code; budget alarms armed
- [ ] Secrets from env/secret manager only; repo scanned; findings to `ai-engineer:ai-security-auditor`
- [ ] All parameter names, limits, and retryable codes verified against current provider docs (context7), not memory
- [ ] Any provider/model change gated by the pinned eval set (`skills/evals/regression-gates`)
