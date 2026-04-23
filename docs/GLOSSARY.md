# Glossary

Abkürzungen und Fachbegriffe, die in dieser Spezifikation verwendet werden.

## Organisatorisch / Militärisch

| Begriff | Bedeutung |
|---------|-----------|
| **C2** | Command and Control — Führung und Kontrolle |
| **ISR** | Intelligence, Surveillance, Reconnaissance — Aufklärung und Überwachung |
| **FüInfoSys** | Führungsinformationssystem — bestehende operative Befehls- und Lagesysteme |
| **NATO STANAG** | NATO Standardization Agreement — Interoperabilitätsstandards für Bündnispartner |
| **RACI** | Responsible, Accountable, Consulted, Informed — Verantwortungsmatrix |
| **RTO** | Recovery Time Objective — maximale tolerierbare Ausfallzeit |
| **RPO** | Recovery Point Objective — maximal tolerierbarer Datenverlust |
| **SLA** | Service Level Agreement — Dienstgütevereinbarung |

## Daten & Geoinformatik

| Begriff | Bedeutung |
|---------|-----------|
| **KRS** | Koordinatenreferenzsystem — z. B. EPSG:4326 (WGS84) |
| **Geodaten** | Raumbezogene Daten: Vektor (Features), Raster (Bilder), Punktwolken |
| **Vektordaten** | Geometrisch diskrete Features (Punkte, Linien, Polygone) mit Attributen |
| **Rasterdaten** | Gitterbasierte Daten (Satellitenbilder, Höhenmodelle, Klassifikationsraster) |
| **Punktwolke** | Menge georeferenzierter Einzelpunkte (LiDAR, photogrammetrische Scans) |
| **Lineage** | Datenherkunft — Quellen und Transformationsschritte eines Datensatzes |
| **Predicate Pushdown** | Abfrageoptimierung: Filter direkt auf Speicherebene, nicht erst nach Laden |

## Formate

| Format | Bedeutung | Typ |
|--------|-----------|-----|
| **COG** | Cloud Optimized GeoTIFF — HTTP-Range-Request-fähiges Rasterformat | Raster |
| **COPC** | Cloud Optimized Point Cloud — LAZ-basiertes, räumlich indiziertes Punktwolkenformat | Punktwolke |
| **GeoParquet** | Spaltenorientiertes, cloud-natives Vektorformat auf Basis Apache Parquet | Vektor |
| **GeoPackage (GPKG)** | OGC-Standard, SQLite-basiertes Vektorformat | Vektor |
| **GeoJSON** | JSON-basiertes Vektoraustauschformat | Vektor |
| **Shapefile** | Älteres ESRI-Vektorformat, weit verbreitet aber limitiert | Vektor |
| **LAZ / LAS** | Klassisches (komprimiertes) Punktwolkenformat | Punktwolke |
| **GeoTIFF** | Klassisches Raster-Dateiformat mit Georeferenz | Raster |
| **NetCDF** | Multidimensionales Datenformat, Standard in Meteorologie | Raster / Multi-D |
| **Zarr** | Chunk-basiertes multidimensionales Format, cloud-nativ | Raster / Multi-D |
| **FlatGeobuf** | Streaming-fähiges Vektorformat | Vektor |

## Plattform & Architektur

| Begriff | Bedeutung |
|---------|-----------|
| **Data Lake** | Zentraler Speicher für Rohdaten und verarbeitete Daten in nativen Formaten |
| **Landing Zone** | Erste Zone — Rohdaten unverändert, nur lesbar |
| **Processed Zone** | Zweite Zone — technisch standardisiert (KRS, Format, Geometrie) |
| **Curated Zone** | Dritte Zone — fachlich aufbereitet, domänenverantwortet |
| **Enrichment Zone** | Vierte Zone — domänenübergreifende Fusionsprodukte |
| **Serving-Schicht** | Zugriffsschicht für Konsumenten (SQL, OGC, API, Tiles) |
| **Zonenvertrag** | Definierte Eintrittskriterien beim Übergang zwischen Zonen |
| **Idempotenz** | Wiederholte Ausführung führt zum selben Ergebnis ohne Seiteneffekte |
| **ADR** | Architecture Decision Record — strukturiert dokumentierte Entscheidung |
| **PoC** | Proof of Concept — Phase 1 dieser Initiative |
| **MVP** | Minimum Viable Platform — Phase 2 dieser Initiative |

## Standards & Protokolle

| Begriff | Bedeutung |
|---------|-----------|
| **OGC** | Open Geospatial Consortium — Standards-Organisation für Geodaten |
| **WMS** | Web Map Service — OGC-Standard für gerenderte Kartenbilder |
| **WFS** | Web Feature Service — OGC-Standard für Vektor-Feature-Abfragen |
| **STAC** | SpatioTemporal Asset Catalog — offener Katalogstandard für raumzeitliche Daten |
| **STAC-Extension** | Domänenspezifische Erweiterung des STAC-Grundschemas |
| **Vector Tiles** | Vektorbasierte Kachelformate (Mapbox Vector Tiles, MVT) |
| **EPSG** | European Petroleum Survey Group — Registry für KRS-Codes |

## Räumliche Indizierung

| Begriff | Bedeutung |
|---------|-----------|
| **H3** | Uber-entwickeltes hierarchisches hexagonales Rastersystem |
| **S2** | Google-entwickeltes hierarchisches Kugeloberflächen-Rastersystem |
| **GeoHash** | Geohash-Indexierung — rechteckige hierarchische Zellen |
| **Bounding Box** | Achsparallele Rechtecksbegrenzung einer Geometrie |

## Verarbeitung

| Begriff | Bedeutung |
|---------|-----------|
| **Apache Spark** | Verteilte Datenverarbeitungs-Engine |
| **Apache Sedona** | Räumliche Erweiterung für Spark |
| **DuckDB** | In-Prozess analytische SQL-Engine mit Spatial-Extension |
| **Dask** | Python-native verteilte Rechenbibliothek |
| **GDAL** | Geospatial Data Abstraction Library — Lingua franca der GIS-Formate |
| **Apache Iceberg** | Tabellenformat mit ACID, Zeitreisen und Schema-Evolution |
| **Delta Lake** | Alternatives Tabellenformat mit ähnlichen Fähigkeiten |
| **Apache Airflow** | Workflow-Orchestrierung auf Basis von DAGs |
| **Prefect** | Moderne Python-native Orchestrierungslösung |
| **Dagster** | Asset-orientierte Orchestrierungs- und Observability-Plattform |

## Serving-Komponenten

| Komponente | Zweck |
|------------|-------|
| **GeoServer** | Java-basierter OGC-Server (WMS/WFS/WCS) |
| **MapServer** | C-basierter OGC-Server |
| **Martin** | Rust-basierter Vector-Tile-Server |
| **pg_tileserv** | PostGIS-basierter Vector-Tile-Server |
| **TiTiler** | FastAPI-basierter COG-Tile-Dienst |
| **stac-fastapi** | FastAPI-Implementierung des STAC-API-Standards |
| **RustFS** | Rust-basierter, MinIO-API-kompatibler S3-Objektspeicher (Apache 2.0); primäre Speicherwahl im PoC, siehe [ADR-001](adr/ADR-001-object-storage.md) |
| **MinIO** | S3-kompatibler on-premise Objektspeicher (Go-basiert, AGPL, 2025 Community-Edition ausgedünnt — in dashi durch RustFS ersetzt) |

## KI / ML

| Begriff | Bedeutung |
|---------|-----------|
| **KI** | Künstliche Intelligenz |
| **ML** | Machine Learning — maschinelles Lernen |
| **Feature Store** | Speicher für vorberechnete ML-Features |
| **Trainingsdaten** | Annotierter Datensatz zum Training eines ML-Modells |
