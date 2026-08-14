# Shared Skills Index

Quick navigation for cross-cutting references shared by all ai-engineer
agents, commands, and skills.

## Workflow Integration

| File | Description |
|------|-------------|

## Routing & Models

| File | Description |
|------|-------------|
| `framework-detection.md` | AI-stack marker → domain → agent routing: detection priority order, dependency and file markers, mixed-stack tie-breaking, precedence vs sibling plugins, ambiguity rule |
| `model-selection.md` | Per-agent model/effort/maxTurns assignments, cost tiers, house rules for `Task()` calls, opus+xhigh override paths |

## Quality

| File | Description |
|------|-------------|
| `severity-matrix.md` | Severity levels and P0-P3 review priorities with AI examples (prompt injection, leaked keys, eval regressions), effort/impact quadrant, code-smell thresholds, coverage requirements |

## Quick Links by Problem

### "I need to..."

- **Route a task, file, or repo to the right ai-engineer agent** → `framework-detection.md`
- **Decide who owns a training-vs-serving (or app-vs-prompt) task** → `framework-detection.md § Mixed-Stack Tie-Breaking`
- **Know when ai-engineer beats system-developer/apple-developer** → `framework-detection.md § Precedence vs Sibling Plugins`
- **Pick model/effort for a delegation** → `model-selection.md`
- **Escalate a review agent to opus+xhigh** → `model-selection.md § Applying an Override`
- **Set severity/priority on a finding** → `severity-matrix.md`
