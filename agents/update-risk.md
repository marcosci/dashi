# Brief — Add or Update Risk Register Entry

## Goal

Keep `docs/10-risks-open-questions.md` accurate: add newly surfaced risks, update probability/impact on existing ones, close risks that no longer apply.

## Inputs

- Description of the event / concern
- Date of observation
- Category: Organisatorisch · Technisch · Sicherheit & Compliance · Zeitplan & Ressourcen

## Steps — New Risk

1. Find highest existing `R-NN`. New ID = next integer.
2. Assign category, insert row into the matching subsection of §10.2.
3. Score Wahrscheinlichkeit × Schaden using the scheme in the bewertungstabelle; derive the Stufe (🔴/🟠/🟡/🟢).
4. Write a concrete Gegenmaßnahme — not "aufmerksam bleiben". Name the responsible role.
5. If Stufe is 🔴 (Kritisch), also append a paragraph to §10.3 explaining why immediate action is required.
6. Update the ASCII matrix in §10.4 — insert the new ID in the correct cell.

## Steps — Update Existing Risk

1. Find the row by `R-NN`.
2. Update Wahrscheinlichkeit, Schaden, or Stufe as needed. Recompute Stufe from the scheme — do not eyeball.
3. If Stufe changes, update §10.4 matrix.
4. Append a dated note under the Gegenmaßnahme column if context changed: `[YYYY-MM-DD: Wahrsch. reduziert, Grund ...]`.

## Steps — Close Risk

1. Do not delete. Change Stufe to 🟢 and append `[YYYY-MM-DD: geschlossen, Grund ...]` to Gegenmaßnahme.
2. Remove from §10.4 matrix.
3. If the risk was 🔴 and listed in §10.3, move its paragraph into an archival note at the end of §10.3.

## Guardrails

- Never reuse retired IDs.
- Never silently adjust scoring without a dated note.
- The ASCII matrix in §10.4 must stay consistent with the table — always update both.
- Critical-risk additions (§10.3) require Platform Architect sign-off — flag in commit message.

## Done when

- Risk row reflects current state
- §10.4 matrix is consistent
- If Kritisch: §10.3 updated
- Commit message lists affected `R-NN` IDs
