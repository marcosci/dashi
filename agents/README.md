# Agent Briefs

Task-specific briefs for agents contributing to the dashi specification.

Each brief is a self-contained prompt that can be handed to a Claude Code agent without requiring the full conversation context. Briefs describe scope, inputs, expected outputs, and stopping conditions.

## Available Briefs

| Brief | Purpose | Trigger |
|-------|---------|---------|
| [resolve-open-adr.md](resolve-open-adr.md) | Drive an open ADR toward a decision | Phase 1 execution, any 🔄 or ⏳ ADR |
| [fill-baseline.md](fill-baseline.md) | Populate `docs/06-baseline.md` from stakeholder interview notes | Phase 1 baseline capture |
| [add-requirement.md](add-requirement.md) | Add a new F-NN / NF-NN requirement | When stakeholder raises a new requirement |
| [update-risk.md](update-risk.md) | Add or update an entry in the risk register | Steering committee review, new incident |
| [translate-chapter.md](translate-chapter.md) | Produce an English reviewer-facing translation of one chapter | External review / partner handover |

## Adding a new brief

1. Copy an existing brief as a starting point.
2. Name it `<verb>-<object>.md` (imperative, kebab-case).
3. List it in the table above.
4. Keep it self-contained — an agent spawned cold should be able to complete the task.
