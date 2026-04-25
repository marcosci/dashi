# ADR-005 — Tabellenformat für Zeitreihen & Transaktionen: Apache Iceberg (vs. Delta Lake)

**Status:** 🔄 In Diskussion

**Fälligkeit:** Ende Phase 1

## Kontext

Für Vektordatensätze mit häufigen Aktualisierungen (z. B. Logistikdaten, EO-Datenströme) wird ein Format benötigt, das ACID-Transaktionen, Schema-Evolution und Zeitreisen (Time Travel) unterstützt.

## Bewertete Alternativen

| Alternative          | Vorteile | Nachteile |
|----------------------|----------|-----------|
| **Apache Iceberg**   | ACID, Time Travel, Schema-Evolution, breite Engine-Unterstützung | Operationell komplex |
| Delta Lake           | Ähnliche Fähigkeiten, starke Databricks-Integration | Vendor-Nähe zu Databricks |
| Apache Hudi          | Streaming-optimiert, Upserts | Komplexer Betrieb, geringere Community |
| Reines GeoParquet    | Einfach, stabil | Kein Transaktionssupport, keine Zeitreisen |

## Entscheidung

**Noch offen** — Entscheidung zwischen Iceberg und Delta Lake abhängig von der Wahl der Query-Engine ([ADR-007](ADR-007-processing-engine.md)). Entscheidung bis Ende Phase 1 erforderlich.

## Konsequenzen je Entscheidung

- **Iceberg:** maximale Engine-Unabhängigkeit, höherer Betriebsaufwand
- **Delta Lake:** einfachere Integration wenn Spark / Databricks ohnehin im Stack
- **Kein Tabellenformat:** einfachere Architektur, aber kein Transaktionssupport für veränderliche Datensätze
