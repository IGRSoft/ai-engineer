# Shared Skills Index

Cross-cutting references shared by ai-engineer agents, commands, and skills.

| File | Description |
|------|-------------|
| `agent-base.md` | Rules shared across ai-engineer agents (Python quality, uv, secrets, deterministic evals, smoke-scale training, pinning, single-command Bash, comments, routing); agents copy what they need |
| `framework-detection.md` | AI-stack marker → domain → agent routing: detection priority order, dependency and file markers, mixed-stack tie-breaking, precedence vs sibling plugins, ambiguity rule |
| `model-selection.md` | Per-agent model/effort/maxTurns assignments, cost tiers, house rules for Agent calls, per-call `model` override paths |
| `severity-matrix.md` | Severity levels and P0-P3 review priorities with AI examples (prompt injection, leaked keys, eval regressions), effort/impact quadrant, code-smell thresholds, coverage requirements |

## Quick Links

- Training-vs-serving or app-vs-prompt ownership → `framework-detection.md § Mixed-Stack Tie-Breaking`
- ai-engineer vs system-developer/apple-developer → `framework-detection.md § Precedence vs Sibling Plugins`
- Escalate a review agent to opus → `model-selection.md § Applying an Override`
