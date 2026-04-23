# Brief — Translate Chapter for External Review

## Goal

Produce an English translation of one chapter for external review (bündnispartner, NATO-STANAG context, contractor onboarding) **without** replacing the German source of truth.

## Inputs

- Target chapter path (e.g. `docs/07-logical-architecture.md`)
- Intended audience (shapes terminology level)

## Steps

1. Copy the source to `docs/en/<same-filename>` (create directory if it does not exist).
2. Translate prose into fluent English.
3. Preserve IDs verbatim: `F-NN`, `NF-NN`, `W-NN`, `R-NN`, `ADR-NNN`.
4. Preserve zone names (Landing, Processed, Curated, Enrichment, Serving) — already English-cognate.
5. Keep domain names in the original German form on first mention, then use the shorter English form in parentheses once:
   - Aufklärung & ISR (Reconnaissance & ISR)
   - Missionsplanung & C2 (Mission Planning & C2)
   - Logistik & Versorgung (Logistics & Supply)
   - Gelände & Umwelt (Terrain & Environment)
6. Add a banner at the top:
   > **Informational translation.** Source of truth is the German version at `docs/<filename>`. In case of discrepancy, the German text prevails.

## Guardrails

- Do not edit content or restructure — translation only.
- Do not translate technology names (GeoParquet, COG, STAC, H3, Iceberg, Spark, Sedona, DuckDB, etc.).
- Do not translate organizational acronyms (FüInfoSys, KRS, STANAG).
- If the German text is ambiguous, translate literally and add a `<!-- TRANSLATION NOTE: ... -->` HTML comment inline.

## Done when

- Parallel English file exists under `docs/en/`
- Banner is present
- All IDs match source
- No content was silently dropped or added
