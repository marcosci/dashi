# Brief — Populate Baseline Chapter

## Goal

Transform stakeholder interview notes and data inventory spreadsheets into structured content for `docs/06-baseline.md`.

## Inputs

- Raw interview notes (path supplied at invocation)
- Data inventory sheet per domain (path supplied at invocation)
- The four domain names (exact): `Aufklärung & ISR`, `Missionsplanung & C2`, `Logistik & Versorgung`, `Gelände & Umwelt`

## Steps

1. Confirm the "Aufgaben der Bestandsaufnahme in Phase 1" table in `docs/06-baseline.md` §6.3 is still the active task list. Check off completed rows.
2. Extract per-domain findings into a new section `## 6.5 Bestandsaufnahme-Ergebnisse` with one subsection per domain. Required fields per domain:
   - Identifizierte Quellsysteme (Name, Einheit, Format, Schnittstelle, Datenvolumen)
   - Vorhandene Datenbestände (Typ, Auflösung, KRS, Aktualität, Volumen)
   - Bekannte manuelle Aufbereitungsschritte
   - Engpässe und Schmerzpunkte
3. Aggregate across domains into `## 6.6 Konsolidierte Erkenntnisse`:
   - Häufigste Formate (Grundlage für Ingestion-Prioritäten)
   - Gesamtdatenvolumen (Baseline für NF-13)
   - Gemeinsame Quellsysteme über Domänen hinweg
   - Kritische Schnittstellenlücken

## Guardrails

- Do not invent data. If interview notes are missing a field, write `[nicht erhoben]` and flag it.
- Do not rewrite §6.1–§6.4 — they describe the Greenfield situation and are stable.
- If volumes exceed assumed NF-13 thresholds, raise a new risk via `templates/risk.md`.
- Preserve anonymity if interview notes contain individual names not authorized for the spec.

## Done when

- All interview notes are represented in §6.5
- `## 6.6 Konsolidierte Erkenntnisse` is complete
- The checkboxes in §6.4 that match the completed inventory are ticked
- Any new risks are in the register
