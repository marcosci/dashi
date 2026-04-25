# Brief — Drive Open ADR to Decision

## Goal

Move one open or in-discussion ADR (`⏳` or `🔄`) toward a decidable state by gathering missing inputs, clarifying the decision criteria, and drafting a recommendation.

You do **not** make the final call — that authority sits with the Platform Architect per the RACI in `docs/04-stakeholders.md`. You prepare the decision.

## Inputs

- The ADR file in `adr/ADR-NNN-*.md`
- Related chapter(s) in `docs/` (architecture context)
- Open questions list in `docs/10-risks-open-questions.md`
- The Workload-Katalog in `docs/05-requirements.md` §5.3

## Steps

1. Read the target ADR fully.
2. Identify what is blocking the decision — listed under "Fälligkeit" and "Konsequenzen je Entscheidung".
3. Check if any of the 🟡/🔴 open questions in chapter 10 gate this ADR. If yes, note the dependency explicitly.
4. For each listed alternative, verify whether the Vor/Nachteile still match current understanding. Update if outdated.
5. Cross-reference the Workload-Katalog: does any W-NN entry constrain the choice?
6. Draft a **recommendation paragraph** at the bottom of the ADR in a new section `## Empfehlung (Stand [Datum])` — not `## Entscheidung`. Include:
   - Preferred option
   - Justification tied to specific requirements or workloads (F-NN, NF-NN, W-NN IDs)
   - Outstanding information still needed before status can flip to ✅

## Guardrails

- Do **not** change the status badge.
- Do **not** touch `docs/08-technology-decisions.md` overview until the Platform Architect confirms.
- Keep recommendations in German (matches the ADR).
- If you discover a new risk while analyzing, append to `docs/10-risks-open-questions.md` with a new `R-NN`.

## Done when

- `## Empfehlung (Stand [Datum])` section exists with a concrete recommendation
- All dependencies on open questions are linked by ID
- Any newly discovered risks are logged
