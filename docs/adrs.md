# Architecture Decision Records

Jede Entscheidung ist als eigenständige ADR-Datei versioniert. Übersicht mit Status und Zielbereich unten. Die tabellarische Stack-Zusammenfassung liegt in [Kapitel 8](08-technology-decisions.md).

## Status-Legende

- ✅ **Entschieden** — in Umsetzung
- 🔄 **In Diskussion** — Alternativen bewertet, Entscheidung offen
- ⏳ **Offen** — Diskussion ausstehend

## Entscheidungen

| ID | Bereich | Entscheidung | Status |
|----|---------|--------------|:------:|
| [ADR-001](adr/ADR-001-object-storage.md) | Speicherfundament | RustFS (S3-kompatibel, Apache 2.0) | ✅ |
| [ADR-002](adr/ADR-002-vector-format-geoparquet.md) | Vektorformat | GeoParquet | ✅ |
| [ADR-003](adr/ADR-003-raster-format-cog.md) | Rasterformat | Cloud Optimized GeoTIFF (+ Zarr) | ✅ |
| [ADR-004](adr/ADR-004-pointcloud-copc.md) | Punktwolkenformat | COPC | ✅ |
| [ADR-005](adr/ADR-005-table-format.md) | Tabellenformat | Iceberg vs. Delta Lake | 🔄 |
| [ADR-006](adr/ADR-006-data-catalog.md) | Datenkatalog | STAC + techn. Katalog offen | 🔄 |
| [ADR-007](adr/ADR-007-processing-engine.md) | Verarbeitungs-Engine | DuckDB (analytisch) + Spark/Sedona (offen) | 🔄 |
| [ADR-008](adr/ADR-008-spatial-partitioning-h3.md) | Räumliche Partitionierung | H3 | ✅ |
| [ADR-009](adr/ADR-009-serving-layer.md) | Serving-Schicht | Modularer Ansatz, Komponenten teilweise offen | 🔄 |
| [ADR-010](adr/ADR-010-pipeline-orchestration.md) | Pipeline-Orchestrierung | Prefect | ✅ |
| [ADR-011](adr/ADR-011-infra-substrate.md) | Infrastruktur-Substrat | k3s lokal + GitHub (PoC) | ✅ |

## ADR-Lebenszyklus

1. **⏳ Offen** — Kontext und Alternativen werden gesammelt. Template unter [`templates/adr.md`](https://github.com/marcosci/dashi/blob/main/templates/adr.md).
2. **🔄 In Diskussion** — Alternativen bewertet. `Empfehlung (Stand ...)`-Abschnitt ergänzt via [`agents/resolve-open-adr.md`](https://github.com/marcosci/dashi/blob/main/agents/resolve-open-adr.md).
3. **✅ Entschieden** — Entscheidung getroffen, Konsequenzen aufgezählt, in Kapitel 8 Übersicht gepflegt, in der [ID-Referenz](id-reference.md) aktualisiert.

ADRs werden **nicht gelöscht**. Eine revidierte Entscheidung ersetzt die alte ADR durch eine neue mit höherer Nummer, die Vorgängerin bekommt den Status `Superseded` mit Verweis.
