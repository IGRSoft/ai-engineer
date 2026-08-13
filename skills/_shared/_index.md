# Shared Skills Index

Quick navigation for cross-cutting references shared by all ai-engineer
agents, commands, and skills.

## Workflow Integration

| File | Description |
|------|-------------|
| `workflow-integration/SKILL.md` | Guide for integrating with the corpflow 11-stage pipeline (v4.0.13) — pipeline, invocation, gates, artifact filename contract, qualified agent names |
| `workflow-integration/references/stage-details.md` | Per-stage contracts: DV contract for AI work, AI Build Evidence, screenshot cli-fallback, per-agent error files, DR/QA/SR/RE criteria, handoff frontmatter schema, gate-feedback contract, token budgets, PL0 sizing |
| `workflow-integration/templates/dv-development.md` | Copy-paste `development-N.md` artifact template (fixed H2 anchors, AI Build Evidence, handoff frontmatter) |
| `workflow-integration/templates/dr-review.md` | Copy-paste `developer-review-N.md` template for when an ai-engineer agent takes over or contributes the DR review body |
| `workflow-integration/templates/qa-testing.md` | Copy-paste `testing-N.md` template for ai-test-generator / AI testing evidence in QA |

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

- **Integrate with a corpflow worktask** → `workflow-integration/SKILL.md`
- **Write a DV/DR/QA stage artifact** → `workflow-integration/templates/`
- **Handle the screenshot gate for CLI-only AI work** → `workflow-integration/references/stage-details.md § Screenshot Gate for CLI Work`
- **Route a task, file, or repo to the right ai-engineer agent** → `framework-detection.md`
- **Decide who owns a training-vs-serving (or app-vs-prompt) task** → `framework-detection.md § Mixed-Stack Tie-Breaking`
- **Know when ai-engineer beats system-developer/apple-developer** → `framework-detection.md § Precedence vs Sibling Plugins`
- **Pick model/effort for a delegation** → `model-selection.md`
- **Escalate a review agent to opus+xhigh** → `model-selection.md § Applying an Override`
- **Set severity/priority on a finding** → `severity-matrix.md`
