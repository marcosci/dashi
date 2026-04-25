# ADR-006 — Datenkatalog: STAC + Technischer Katalog

**Status räumlicher Katalog:** ✅ Entschieden (STAC)
**Status technischer Katalog:** 🔄 In Diskussion

## Kontext

Die Plattform benötigt zwei Katalogschichten: einen räumlich-zeitlichen Entdeckungskatalog für Analysten und einen technischen Metadatenkatalog für das Platform Team.

## Bewertete Alternativen — Räumlicher Katalog

| Alternative                          | Vorteile | Nachteile |
|--------------------------------------|----------|-----------|
| **STAC (SpatioTemporal Asset Catalog)** | Offener Standard, breite Tool-Unterstützung, räumliche und zeitliche Suche | Primär für Raster/Imagery konzipiert |
| OGC API Records                      | OGC-Standard, für Vektordaten geeignet | Geringere Tool-Reife als STAC |
| Proprietärer Katalog                 | Vollständige Kontrolle | Kein Standardanschluss, hoher Entwicklungsaufwand |

## Bewertete Alternativen — Technischer Katalog

| Alternative         | Vorteile | Nachteile |
|---------------------|----------|-----------|
| Apache Atlas        | Reife Lösung, Lineage-Support | Komplex im Betrieb |
| OpenMetadata        | Modern, aktive Community, gute UI | Jünger, weniger erprobt |
| DataHub (LinkedIn)  | Skalierbar, gute Lineage | Komplex im Betrieb |

## Entscheidung

**STAC** als räumlich-zeitlicher Entdeckungskatalog (Pflicht).
**Technischer Katalog:** Entscheidung bis Ende Phase 1 ausstehend.

## Konsequenzen

- Jeder Rasterdatensatz und jedes Bildprodukt erhält einen STAC-Item-Eintrag
- STAC-Extensions für domänenspezifische Metadaten müssen in Phase 1 definiert werden
- Der technische Katalog muss Lineage bis auf Pipeline-Ebene nachvollziehen können
