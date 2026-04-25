# ADR-003 — Rasterdatenformat: Cloud Optimized GeoTIFF (COG)

**Status:** ✅ Entschieden

## Kontext

Rasterdaten (Geländemodelle, Satellitenbilder, Klassifikationsraster) müssen effizient über Objektspeicher abfragbar sein, ohne vollständig heruntergeladen werden zu müssen.

## Bewertete Alternativen

| Alternative                  | Vorteile | Nachteile |
|------------------------------|----------|-----------|
| **Cloud Optimized GeoTIFF (COG)** | HTTP-Range-Requests, Overviews integriert, breite Unterstützung | Einzeldatei-Format, kein nativer Zeitreihensupport |
| Zarr                         | Multidimensional, Zeitreihen, cloud-nativ | Geringere GIS-Tool-Unterstützung |
| NetCDF                       | Standard für meteorologische Daten | Nicht cloud-nativ ohne Konvertierung |
| GeoTIFF (klassisch)          | Universell bekannt | Nicht für cloud-nativen Zugriff optimiert |

## Entscheidung

**COG** als primäres Rasterformat. **Zarr** als ergänzendes Format für multidimensionale und zeitreihenbasierte Rasterdaten (z. B. meteorologische Felder, Zeitserien von Satellitenbildern).

## Konsequenzen

- Alle eingehenden Rasterdaten werden beim Übergang Landing → Processed nach COG konvertiert
- Overviews (Pyramiden) werden automatisch beim Konvertierungsprozess erstellt
- STAC-Einträge referenzieren COG-Dateien direkt
