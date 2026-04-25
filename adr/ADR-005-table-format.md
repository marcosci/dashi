# ADR-005 — Tabellenformat für Zeitreihen & Transaktionen: Apache Iceberg

**Status:** ✅ Entschieden — 2026-04-25 · 🚀 deployed (REST catalog + promote flow)

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

**Apache Iceberg** als Standard-Tabellenformat für veränderliche Datensätze + Zeitreihen.

Iceberg wird **on-demand** verwendet — nicht jede curated Tabelle braucht Iceberg. Nutzungspfad:

| Datensatz-Charakter | Format |
|---------------------|--------|
| Append-only Snapshot pro Lieferung (Standardfall im PoC) | GeoParquet, Hive-partitioniert |
| Slowly-Changing Dimensions, Backfills, Korrekturen | Iceberg V2 (`merge-on-read`) |
| Streaming-Updates (z. B. Sensor-/IoT-Telemetrie) | Iceberg V2 |
| Read-only Curated-Layer-Aggregate | GeoParquet |

## Begründung

- **DuckDB Iceberg-Extension** (`INSTALL iceberg; LOAD iceberg`) kann Iceberg-Tabellen bereits direkt aus S3 lesen — wir behalten ADR-007's _DuckDB-only_-Stack ohne Spark/JVM.
- Engine-Unabhängigkeit: PyIceberg, Trino, Athena, Snowflake können dieselben Tabellen lesen, falls externe Konsumenten dazustoßen.
- Delta Lake verworfen: starke Databricks/Spark-Bindung, schwächere DuckDB-Story; wir wollen keinen Spark-Cluster betreiben.
- Hudi verworfen: kleinere Community, höhere Betriebslast, keine spürbaren Vorteile gegenüber Iceberg in unserem Use-Case.

## Implementierungspfad

1. **Phase-2 Iceberg-Spike:** PyIceberg + S3 REST Catalog (Iceberg REST 1.x oder Polaris) im Cluster — Phase-2 Strang für mind. eine Iceberg-Tabelle (z. B. `gelaende-umwelt.terrain_corrections`).
2. **DuckDB-Endpoint** lädt `iceberg` Extension, lest Iceberg-Tabellen via `iceberg_scan('s3://curated/iceberg/<table>/')`.
3. **STAC-Integration:** Iceberg-Tabellen erscheinen als STAC-Items mit `assets.iceberg_table` (Typ `application/x.iceberg-metadata+json`, href auf den `metadata.json`-Pfad).
4. **Promotion-Flow:** Prefect-Task `promote_to_iceberg(parquet_prefix, table_name)` — schreibt Iceberg-Snapshot, registriert im REST-Catalog.

## Konsequenzen

- **+** Time Travel (`AS OF` queries) für Korrektur-Audits und Reproduzierbarkeit
- **+** Schema-Evolution ohne Re-Write
- **+** ACID-Garantien für nebenläufige Schreibvorgänge
- **−** Iceberg REST-Katalog ist eine zusätzliche Komponente (Phase-2-Strang)
- **−** DuckDB Iceberg-Extension kann (Stand 2026-04) noch nicht schreiben — Schreibpfad bleibt PyIceberg/Spark; Lesen reicht für unsere DuckDB-zentrische Serving-Schicht

## Tracking

- Phase-2-Strang offen: `iceberg-rest-catalog-deploy` (FEATURE-IDEAS)
- Erste reale Iceberg-Tabelle als Onboarding-Use-Case dokumentiert in `docs/onboarding/domain-template.md` (Schritt 5)
