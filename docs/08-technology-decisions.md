# 8. Technologieentscheidungen

## Grundprinzip

Technologieentscheidungen sind keine isolierten Produktwahlen — sie sind Architekturentscheidungen mit langfristigen Konsequenzen. Jede Entscheidung wird hier als **Architecture Decision Record (ADR)** dokumentiert: mit Kontext, bewerteten Alternativen, getroffener Entscheidung und ihren Konsequenzen.

Dieses Format macht Entscheidungen nachvollziehbar, revidierbar und kommunizierbar — auch für Stakeholder, die nicht an der ursprünglichen Diskussion beteiligt waren.

## Status-Kennzeichnung

- ✅ **Entschieden**
- 🔄 **In Diskussion**
- ⏳ **Offen — Entscheidung ausstehend**

## ADR-Übersicht

Jede ADR wird als eigenständige Datei im [`adr/`](adr/) Verzeichnis geführt. Die folgende Tabelle verlinkt auf die Detaildokumente.

| ID      | Bereich                    | Entscheidung           | Technologie            | Status | Detail |
|---------|----------------------------|------------------------|------------------------|:------:|--------|
| ADR-001 | Speicherfundament          | Objektspeicher         | S3-kompatibel (RustFS) | ✅    | [→](adr/ADR-001-object-storage.md) |
| ADR-002 | Vektorformat               | Primärformat           | GeoParquet             | ✅    | [→](adr/ADR-002-vector-format-geoparquet.md) |
| ADR-003 | Rasterformat               | Primärformat           | COG                    | ✅    | [→](adr/ADR-003-raster-format-cog.md) |
| ADR-004 | Punktwolkenformat          | Primärformat           | COPC                   | ✅    | [→](adr/ADR-004-pointcloud-copc.md) |
| ADR-005 | Tabellenformat             | Transaktional          | Iceberg / Delta Lake   | 🔄    | [→](adr/ADR-005-table-format.md) |
| ADR-006 | Räumlicher Katalog         | Entdeckung             | STAC                   | ✅    | [→](adr/ADR-006-data-catalog.md) |
| ADR-006 | Technischer Katalog        | Lineage & Metadaten    | Offen                  | 🔄    | [→](adr/ADR-006-data-catalog.md) |
| ADR-007 | Verarbeitungs-Engine       | Batch / Groß           | Spark + Sedona         | 🔄    | [→](adr/ADR-007-processing-engine.md) |
| ADR-007 | Verarbeitungs-Engine       | Analytisch             | DuckDB + Spatial       | ✅    | [→](adr/ADR-007-processing-engine.md) |
| ADR-008 | Partitionierung            | Räumlich               | H3                     | ✅    | [→](adr/ADR-008-spatial-partitioning-h3.md) |
| ADR-009 | Serving — SQL              | Analytisch             | DuckDB / SQL-Engine    | ✅    | [→](adr/ADR-009-serving-layer.md) |
| ADR-009 | Serving — OGC              | WMS/WFS                | GeoServer / MapServer  | 🔄    | [→](adr/ADR-009-serving-layer.md) |
| ADR-009 | Serving — Kacheln          | Vektor                 | Martin / pg_tileserv   | 🔄    | [→](adr/ADR-009-serving-layer.md) |
| ADR-009 | Serving — Raster           | COG-Tiles              | TiTiler                | ✅    | [→](adr/ADR-009-serving-layer.md) |
| ADR-009 | Serving — STAC             | API                    | stac-fastapi           | ✅    | [→](adr/ADR-009-serving-layer.md) |
| ADR-010 | Orchestrierung             | Pipeline-Management    | Prefect                | ✅    | [→](adr/ADR-010-pipeline-orchestration.md) |
| ADR-011 | Infrastruktur-Substrat     | PoC / MVP              | k3s lokal + GitLab     | ✅    | [→](adr/ADR-011-infra-substrate.md) |

## 8.1 Technologie-Stack-Übersicht (konsolidiert)

| Bereich               | Entscheidung        | Technologie             | Status |
|-----------------------|---------------------|-------------------------|:------:|
| Speicherfundament     | Objektspeicher      | S3-kompatibel (RustFS)  | ✅    |
| Vektorformat          | Primärformat        | GeoParquet              | ✅    |
| Rasterformat          | Primärformat        | COG                     | ✅    |
| Punktwolkenformat     | Primärformat        | COPC                    | ✅    |
| Tabellenformat        | Transaktional       | Iceberg / Delta Lake    | 🔄    |
| Räumlicher Katalog    | Entdeckung          | STAC                    | ✅    |
| Technischer Katalog   | Lineage & Metadaten | Offen                   | 🔄    |
| Verarbeitungs-Engine  | Batch / Groß        | Spark + Sedona          | 🔄    |
| Verarbeitungs-Engine  | Analytisch          | DuckDB + Spatial        | ✅    |
| Partitionierung       | Räumlich            | H3                      | ✅    |
| Serving — SQL         | Analytisch          | DuckDB / SQL-Engine     | ✅    |
| Serving — OGC         | WMS/WFS             | GeoServer / MapServer   | 🔄    |
| Serving — Kacheln     | Vektor              | Martin / pg_tileserv    | 🔄    |
| Serving — Raster      | COG-Tiles           | TiTiler                 | ✅    |
| Serving — STAC        | API                 | stac-fastapi            | ✅    |
| Orchestrierung        | Pipeline-Management | Prefect                 | ✅    |
| Infrastruktur-Substrat | PoC / MVP          | k3s lokal + GitLab      | ✅    |

## 8.2 Offene Technologieentscheidungen

Die folgenden Entscheidungen sind noch ausstehend und müssen spätestens zum Ende von Phase 1 getroffen werden.

| ID      | Entscheidung                       | Abhängigkeit            | Fälligkeit    |
|---------|------------------------------------|-------------------------|---------------|
| ADR-005 | Iceberg vs. Delta Lake             | Wahl der Query-Engine   | Ende Phase 1  |
| ADR-007 | Spark vs. Dask als primäre Engine  | Infrastrukturentscheidung | Ende Phase 1 |
| ADR-009 | OGC-Server: GeoServer vs. MapServer | Anforderungen FüInfoSys | Phase 2 Start |
| —       | Technischer Metadatenkatalog       | Evaluierung in Phase 1  | Ende Phase 1  |
