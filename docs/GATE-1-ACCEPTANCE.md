# Gate-1 Acceptance — PoC Scope

Status snapshot of the Phase-1 Gate-1-equivalent acceptance criteria applied to the PoC scope (see [PHASE-0-ROADMAP §Gate-1-Äquivalent](PHASE-0-ROADMAP.md#gate-1-äquivalent--abnahmekriterien)).

**Measurement date:** 2026-04-23 · **Cluster:** local k3d `miso` · **Data ingested:** Dresden OSM shapefiles (29 files), QGIS Military Grids GPKG (4 layers), GeoTIFF (sample.tif, EPSG:32631), LAZ (118 MB NZ LiDAR)

| # | Kriterium | Messung | Zielwert | Stand | Belegt durch |
|:-:|-----------|---------|----------|:-----:|--------------|
| 1 | End-to-End-Pipeline funktionsfähig | Sample-Datei rein → STAC-Item raus → Tile- + SQL-Query-Ausgabe | Bestanden | ✅ | `poc/smoke/ingest.sh` + `poc/smoke/catalog.sh` + `poc/smoke/serving.sh` alle grün |
| 2 | KRS-Transformation korrekt | Stichprobenprüfung von 3 Datensätzen | 100 % korrekt | ✅ | sample.tif EPSG:32631 → EPSG:4326 COG · points.laz NZGD2000 NZTM2000 → EPSG:4326 COPC · Dresden shapefiles EPSG:4326 → EPSG:4326 (no-op), BBox-Sichtprüfung stimmt |
| 3 | STAC-Suche funktionsfähig | BBox-Abfrage liefert korrekte Items | Bestanden | ✅ | `/search?bbox=13.5,50.8,14.0,51.2` → 30+ Items im Dresden-Raum |
| 4 | SQL-Abfrage auf Curated-/Processed-Zone | Einfache Abfrage in < 10 Sek. | Bestanden | ✅ | `ST_Intersects` über 367 219 Features, 10 490 Treffer, < 2 s |
| 5 | COG-Serving funktionsfähig | TiTiler liefert PNG für Raster-Item | Bestanden | ✅ | `/cog/tiles/10/519/340.png` → 256×256 RGBA PNG |
| 6 | Pipeline idempotent | Zwei aufeinanderfolgende Läufe, keine Duplikate | Bestanden | ✅ | dataset_id = `sha256(filename + content + layer)`, wiederholte Läufe liefern denselben STAC-Item-ID → `stac.post_item` 409 → PUT-Upsert |
| 7 | Betriebsdoku vorhanden | Setup + Teardown + Troubleshooting | Vollständig | ✅ | [docs/OPERATIONS.md](OPERATIONS.md), [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md), [poc/docs/k3s-setup.md](poc/docs/k3s-setup.md) |

## Unterstützende Metriken

### Ingestion

| Kenngröße | Wert |
|-----------|------|
| Quell-Formate verarbeitet | Shapefile, GeoPackage (multi-layer), GeoTIFF, LAZ |
| Gesamte Eingangsdaten | ~350 MB |
| Ingestierte STAC-Items | 35 |
| Ingestierte Vektor-Features | 367 219 |
| H3-7 Vektorpartitionen | 3 709 |
| Reparierte Geometrien | 0 (OSM-Quelle ist sauber) |
| Ablehnungen | 1 (leere `coastline` Shapefile — Dresden ist Binnenland) |
| Wall-Clock-Zeit (ohne LAZ) | ~55 s |
| Wall-Clock LAZ → COPC (118 MB → 97 MB) | ~5 min inkl. Upload über Port-Forward |

### Katalog

| Kenngröße | Wert |
|-----------|------|
| Collections | 1 (`gelaende-umwelt`) |
| Items | 35 (33 vector, 1 raster, 1 pointcloud) |
| BBox-Query-Latenz (stac-fastapi, 30 Items) | < 100 ms |

### Serving

| Kenngröße | Wert |
|-----------|------|
| TiTiler `/cog/info` Latenz | 200 – 400 ms (S3 range-request auf COG-Overviews) |
| TiTiler Tile 256×256 | 100 – 300 ms |
| DuckDB `SELECT COUNT(*)` über 367 k Features | < 500 ms |
| DuckDB `ST_Intersects` BBox über 367 k Features | ~1.5 s |
| DuckDB DDL-Abweisung | HTTP 400 mit `"write/DDL keywords forbidden"` |

## Ausgeschlossen aus PoC-Gate-1

Per [PHASE-0-ROADMAP.md](PHASE-0-ROADMAP.md#bewusst-außerhalb-gate-1-scope):

- NF-01 – NF-04 Performance-Benchmarks (Phase 1 Ende)
- F-21 OGC-Dienste WMS/WFS (Phase 2)
- F-22 Vektorkacheln (Phase 2)
- F-23 Rollenbasierte Zugriffskontrolle (Phase 2)
- NF-10 Audit-Logging (Phase 2)
- Bestandsaufnahme aller 4 Domänen (Phase 2 mit realen Stakeholdern)
- R-12 Akkreditierung + NF-11 (pausiert, Produktivmigration)

## Verbleibende Arbeit bis produktives Phase-1-Gate

| Punkt | Status |
|-------|:------:|
| Prefect Orchestrierung + produktive Pipeline-Scheduling | ⏳ Strang F |
| Ingestion-Container-Image (damit Flows nicht lokal laufen müssen) | ⏳ Strang F |
| ADR-007 final: DuckDB für alles vs. Spark-Ergänzung | ⏳ offen |
| ADR-005 final: Iceberg / Delta / kein Tabellenformat | ⏳ offen |
| Technischer Katalog (Lineage-Backend) | ⏳ offen |
| KMZ unzip-Step | ⏳ geringe Priorität |

## Erklärung zur Akzeptanz

**PoC-Scope-Gate-1: Bestanden** — alle 7 Kriterien erfüllt, sämtliche Smoke-Tests grün. Dokumentation vollständig. Die Plattform kann beliebige OGR/GDAL-lesbare Geodaten aufnehmen, in eine gemeinsame Zonenarchitektur standardisieren, räumlich-zeitlich katalogisieren und über SQL + Tile-API zur Verfügung stellen — auf lokalem k3s + RustFS + GitHub-CI.

Die in `Verbleibende Arbeit` aufgelisteten Punkte sind für den produktiven Phase-1-Abschluss (§9 des Spezifikationsdokuments) relevant, nicht für das PoC-Gate.

**Freigabe-Empfehlung:** Übergang in Strang F (Prefect-Orchestrierung) + laufende Anbindung realer Datenlieferanten über das bestehende CLI. Re-Evaluation der produktiven Phase-1-Kriterien, sobald ein realer Datenlieferant über Prefect-Scheduling angebunden ist.

**Freigabe durch:** Marco Sciaini + Johannes Schlund — Co-Owners
