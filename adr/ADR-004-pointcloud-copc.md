# ADR-004 — Punktwolkenformat: COPC

**Status:** ✅ Entschieden · PoC-Implementierung live (PDAL `writers.copc`)

## Kontext

Punktwolkendaten (LiDAR, UAV-Scans) müssen cloud-nativ speicher- und abfragbar sein.

## Bewertete Alternativen

| Alternative                  | Vorteile | Nachteile |
|------------------------------|----------|-----------|
| **COPC (Cloud Optimized Point Cloud)** | LAZ-basiert, räumlich indiziert, cloud-nativ | Noch nicht überall unterstützt |
| LAZ / LAS                    | Weit verbreitet, komprimiert | Nicht cloud-nativ |
| EPT (Entwine Point Tiles)    | Cloud-nativ, Potree-kompatibel | Proprietärer Charakter, geringere Verbreitung |

## Entscheidung

**COPC** als primäres Punktwolkenformat.

## Konsequenzen

- LAS/LAZ-Eingangsdaten werden beim Übergang Landing → Processed nach COPC konvertiert
- Räumliche Indizierung ist im Format inhärent enthalten
- **PoC-Implementierung:** `miso-ingest` ruft PDAL (`writers.copc`) als Subprozess auf. Reprojektion (Quell-CRS → EPSG:4326) erfolgt im gleichen PDAL-Pipeline-Stage via `filters.reprojection`. PDAL-Binary muss auf PATH verfügbar sein (`brew install pdal` / `apt install pdal`) — fehlt PDAL, wird Pointcloud-Ingestion sauber übersprungen und in `IngestOutcome.reason` begründet.
- **Live-Validierung (2026-04-23):** 118 MB NZ-LiDAR-LAZ (NZGD2000 NZTM2000 + NZVD2016 height) erfolgreich nach 97 MB COPC in EPSG:4326 konvertiert, STAC-Item mit korrektem BBox [168.096, -46.9034, 168.1214, -46.8915] im Katalog.

## Offene Punkte (Phase 2)

- **Reader-Kompatibilität mit TiTiler-ähnlichen Diensten:** COPC-Serving (deck.gl, Potree) braucht ggf. zusätzliche CORS-Konfiguration und chunked-range-requests — zu klären, sobald Pointcloud-Konsumenten definiert sind.
- **Klassifizierungs-Filter:** LAS/LAZ Classification-Bytes (ground, building, vegetation) bleiben unverändert erhalten. Semantische Enrichment-Pipeline (z. B. `ndvi`-basierte Klassifikation) ist nicht Teil von Phase 1.
- **PDAL-Containerisierung:** aktuell PDAL auf der Entwickler-Maschine. Produktive Ingestion-Worker sollten PDAL in das Container-Image bundlen (Phase 2, zusammen mit der Prefect-Integration).
