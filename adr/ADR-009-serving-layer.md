# ADR-009 — Serving-Schicht: Modularer Ansatz

**Status:** ✅ Entschieden (Ansatz) · 🔄 teilweise offen (Komponentenwahl)

## Kontext

Verschiedene Konsumenten benötigen verschiedene Zugriffsarten. Ein einzelner Serving-Dienst kann diese Anforderungen nicht optimal erfüllen.

## Entscheidung

**Modulare Serving-Schicht** mit spezialisierten Komponenten je Zugriffsart — keine monolithische Serving-Lösung.

| Zugriffsart          | Empfohlene Komponente                     | Status |
|----------------------|-------------------------------------------|:------:|
| Analytisches SQL     | DuckDB (lokal) / Athena-kompatible Engine | ✅    |
| OGC API — Tiles      | Martin (PMTiles)                          | ✅    |
| OGC API — Features   | TiPG / pygeoapi                           | ⏳    |
| Legacy WMS / WFS     | (ggf. Shim für FüInfoSys, sonst entfällt) | ⏳    |
| Vektorkacheln (MVT)  | Martin                                    | ✅    |
| Raster / COG-Tiles   | TiTiler                                   | ✅    |
| STAC-API             | stac-fastapi                              | ✅    |
| Programmatische API  | REST-API über Objektspeicher-Direktzugriff | ⏳    |

## Update — 2026-04-25 — Modernisierung der OGC-Strategie

GeoServer und MapServer sind beide aus den frühen 2000ern. Wir wechseln auf den modernen OGC-API-Stack:

- **WMS → OGC API – Tiles** (Martin liefert beides aus einer Quelle)
- **WFS → OGC API – Features** (TiPG / pygeoapi, geplant für die nächste Iteration)
- **WMTS → OGC API – Tiles**

**Entscheidungen getroffen:**

- **Vektorkacheln + OGC API – Tiles: Martin** (Rust, MapLibre-Org, multi-arch, performant). Liest PMTiles direkt; ein Prefect-getriggertes Tippecanoe-Pipeline produziert PMTiles aus GeoParquet in `s3://curated/tiles/`.
- **Tile-Format: PMTiles** (Protomaps) — single-file, HTTP-Range-Request-fähig, zukunftssicherer als MBTiles. Martin lädt PMTiles aus RustFS via initContainer-Mirror in `/tiles` (Workaround für Martin v1.6, da der `endpoint`-Knopf für RustFS-style S3 nicht öffentlich konfigurierbar ist; sobald Martin den Patch akzeptiert oder ein S3-Sidecar-Pattern eingeführt wird, fällt das Mirror-Stage weg).
- **OGC API – Features: TiPG empfohlen** (DevelopmentSeed, FastAPI, gleiche Familie wie unser stac-fastapi + TiTiler). Deployment in der nächsten Iteration zusammen mit dem PostGIS-Promotion-Flow aus `processed/` GeoParquet.
- **GeoServer und MapServer: verworfen.** Beide bleiben als Optionen für eine Phase-3 Legacy-Shim, falls FüInfoSys oder ein anderer Konsument zwingend WMS 1.3.0 in XML braucht. Default-Pfad ist OGC API.

## Offene Entscheidungen

- **OGC API – Features Backend:** TiPG vs. pygeoapi — Entscheidung mit Phase-2 K-Strang (Domain-Onboarding) wenn der erste Nicht-Tile-Konsument die Anforderung präzisiert.
- **Programmatische API:** Design und Framework-Wahl ausstehend.
- **Legacy-WMS-Shim:** nur falls ein FüInfoSys-Equivalent Phase-3 zwingt; aktuell offen.

## Konsequenzen

- Höhere Komplexität im Betrieb durch mehrere Komponenten
- Jede Komponente kann unabhängig skaliert und ausgetauscht werden
- Klare Zuordnung: jeder Zugriffstyp hat genau eine verantwortliche Komponente
