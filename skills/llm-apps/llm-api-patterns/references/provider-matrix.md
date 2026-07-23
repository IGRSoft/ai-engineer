# Provider Capability Matrix (dimensions, not snapshots)

Use this when:

- Choosing between managed APIs and self-hosted open-weights serving
- Declaring per-hop capability requirements for a fallback chain
- Planning or reviewing a migration between providers
- Checking which capability *mechanisms* differ before assuming parity

Skip this file if:

- You need client discipline (timeouts, retries, streaming, caching) — use
  [../SKILL.md](../SKILL.md)
- You are operating the self-hosted servers themselves — use
  `skills/mlops/model-serving`

**Hard rule for this file:** cells name the capability *mechanism* and where
to verify it — never model IDs, token limits, prices, or feature snapshots.
All of those churn monthly. Resolve current specifics from provider docs via
context7 (`resolve-library-id` → `query-docs` for the provider SDK/API docs)
at decision time, and pin what you verified in your own config.

## Provider Categories

- **Managed APIs** — Anthropic, OpenAI, Google: hosted models behind a
  versioned HTTP API; capabilities are per-model-family and change with
  releases.
- **Open-weights self-hosted** — vLLM (server for production serving, exposes
  an OpenAI-compatible endpoint), Ollama (local/edge runner with its own API
  plus an OpenAI-compatible endpoint): capabilities are the *product of*
  server version × model weights × chat template — verify per deployed
  combination, not per project.

## Capability Matrix

| Dimension | Anthropic (managed) | OpenAI (managed) | Google (managed) | vLLM (self-hosted) | Ollama (local/self-hosted) |
|---|---|---|---|---|---|
| Structured output | Tool-schema-driven extraction; structured-output support per model family — verify | JSON-schema response-format mode; strictness options — verify | Response-schema config on the generation request — verify | Server-side guided decoding: JSON-schema / grammar / regex backends — verify per server version | Schema-constrained `format` option; fidelity varies by model — verify |
| Tool use | Native tool blocks; parallel-call and forcing options — verify | Native function calling; parallel-call and forcing options — verify | Native function calling with its own declaration format — verify | Passthrough of the model's tool-call template; depends on model + parser flag — verify per combination | Template-dependent tool support; model-dependent — verify per model |
| Streaming | SSE event stream; typed event kinds; usage on terminal event — verify shapes | SSE deltas; usage reporting options on stream — verify shapes | SSE/chunked streaming; aggregate-at-end helpers — verify shapes | OpenAI-compatible SSE from the server | Native streaming API + OpenAI-compatible endpoint |
| Prompt caching | Explicit cache-control breakpoints; minimum-length + TTL-class rules — verify | Automatic prefix caching; hit reporting in usage — verify | Context-caching objects and/or implicit caching — verify | KV/prefix-cache reuse as a server feature (flag-dependent) — no billing dimension | Keep-alive model residency + KV reuse; a locality mechanism, not a billing one |
| Batch API | Async batch endpoint; submit list, poll, fetch results — verify | Async batch endpoint (file-based); poll and download — verify | Batch prediction jobs via the platform — verify | None — you are the batch system; throughput comes from continuous batching | None — script your own offline loop |
| Multimodal | Image input class; other modalities per model family — verify | Image/audio classes per model family — verify | Image/audio/video classes per model family — verify | Depends on model weights + server support for the modality — verify | Depends on model weights + runner support — verify |
| Context length class | Per model family — verify current docs | Per model family — verify current docs | Per model family — verify current docs | Set by model weights × server config (max length settings, memory) | Set by model weights × host RAM/VRAM and runner config |

Reading the matrix: a row tells you *what kind of mechanism* to look for and
that the mechanisms are **not interchangeable** — a fallback hop or migration
that assumes they are will corrupt outputs quietly. The verify pointer is the
cell's real content.

## Dimension Notes (what differs mechanically)

- **Structured output.** Three distinct mechanisms exist: prompt-level
  coaxing (weakest), tool-schema extraction, and constrained/guided decoding
  (strongest, grammar-enforced). Providers differ in which they offer and in
  JSON-Schema feature coverage (unions, optionality, recursion). Always
  re-validate output against your own schema regardless of mode — see
  `skills/prompt-engineering/structured-outputs`.
- **Tool use.** Declaration format, parallel-call semantics, streaming of
  partial tool arguments, and "force this tool" options all differ. A
  cross-provider agent needs an adapter layer that normalizes tool calls
  in both directions (`skills/llm-apps/agent-design`).
- **Streaming.** Everyone streams; *event shapes* differ (typed event kinds
  vs raw deltas, where usage appears, how tool calls interleave). Isolate
  parsing in one adapter module per provider.
- **Prompt caching.** The split that matters: explicit opt-in breakpoints vs
  automatic prefix caching vs self-hosted KV reuse. All reward the same
  prompt layout (stable prefix first — [../SKILL.md](../SKILL.md)), but
  hit-rate measurement and cost effects differ; re-model costs on migration.
- **Batch.** Managed batch APIs are a *price/throughput* mechanism with
  async job semantics. Self-hosted has no equivalent object — you schedule
  offline load yourself and size the server for it
  (`skills/mlops/model-serving`).
- **Multimodal.** Treat as per-model-family, not per-provider. Never assume a
  modality survives a fallback hop; declare it as a capability requirement.
- **Context length class.** Think in classes (short / standard / long /
  very-long) when designing, and verify the concrete number for the exact
  model at build time. Self-hosted context is also a *memory budget you pay
  for* — KV-cache growth caps real usable length below the model's nominal
  maximum.

## Migration Checklist (provider → provider)

Mechanical parity is table stakes; behavioral parity is an eval result. Both
are required.

- [ ] Inventory every request parameter in use; map each to the target's
      equivalent or consciously drop it — names and semantics differ (verify
      via context7, not memory)
- [ ] Map the structured-output mechanism; re-validate all schemas against the
      target's JSON-Schema feature coverage; keep your own output validation on
- [ ] Map tool-call declaration + response formats, including parallel calls
      and streamed tool arguments; update the adapter and its tests
- [ ] Re-check system-prompt placement (dedicated field vs message role) and
      any provider-specific prompt conventions
- [ ] Tokenizers differ: re-measure prompt token counts, truncation points,
      and budget alarms — identical text, different bill
- [ ] Re-structure prompt caching (breakpoints vs automatic) and re-model the
      cost effect via your rates config — mechanism changes, so the ledger math does
- [ ] Update the client error taxonomy: retryable status/error codes and
      rate-limit header names differ
- [ ] Re-run the full eval set (pinned version, temperature 0) against the
      target; compare to baseline before any traffic shifts
      (`skills/evals/regression-gates`)
- [ ] Canary behind a flag with per-provider response tagging; keep the old
      path warm for rollback
- [ ] Issue new scoped credentials via the secret manager; rotate, never
      copy; confirm no keys land in code or config commits
- [ ] For self-hosted targets: pin server version + model weights revision +
      chat template together, and re-verify tool/structured-output claims for
      that exact combination

## Where to Verify

| Surface | Verify via |
|---------|-----------|
| Managed API capabilities, parameters, limits | Provider API docs through context7 (`resolve-library-id` for the provider SDK, then `query-docs`) |
| Self-hosted server features | vLLM / Ollama docs for the *deployed server version* (context7), plus the model card for the weights |
| Model-family specifics (modalities, context, structured-output support) | The provider's current model documentation — never memory, never this file |
| Prices / rate limits | Provider pricing and limits pages at decision time; store outcomes in your own rates/limits config with effective dates |
