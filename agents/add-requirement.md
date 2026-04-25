# Brief — Add New Requirement

## Goal

Register a new functional (`F-NN`) or non-functional (`NF-NN`) requirement into `docs/05-requirements.md`.

## Inputs

- Stakeholder description of the requirement (natural language)
- Stakeholder's role/domain
- Requested priority (if stated) and phase (if stated)

## Steps

1. Read `docs/05-requirements.md` and identify the **highest existing** `F-NN` and `NF-NN` number. New IDs continue from there — never reuse.
2. Classify as functional or non-functional:
   - **Functional:** what the system does (ingestion, storage, catalog, processing, serving)
   - **Non-functional:** how well it does it (performance, availability, security, scalability, operations)
3. Insert the requirement into the correct subsection table. Keep table column count identical.
4. For non-functional: include a measurable `Zielwert`. Bracketed placeholders `[X]` are allowed if the target is not yet ratified.
5. If the requirement conflicts with or supersedes an existing one, **do not delete** the existing entry — add a note `Ersetzt durch F-NN` to it and leave it in place.
6. If the requirement reveals an open question (e.g., "what's the retention period?"), append a new `F-NN` in §10.1 with `🟡` status.

## Guardrails

- Never renumber existing IDs.
- Never silently change priorities of existing requirements.
- German wording — match the style of surrounding entries (short, imperative: "Das System muss ...").
- If priority is unclear, use `Mittel` and flag for Platform Architect review in the commit message.

## Done when

- New row exists with next free ID in correct table
- If applicable, matching open question logged in §10.1
- Commit message names the new ID and the requesting stakeholder
