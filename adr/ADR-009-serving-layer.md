# ADR-009 — Serving-Schicht: Modularer Ansatz

**Status:** ✅ Entschieden (Ansatz) · 🔄 teilweise offen (Komponentenwahl)

## Kontext

Verschiedene Konsumenten benötigen verschiedene Zugriffsarten. Ein einzelner Serving-Dienst kann diese Anforderungen nicht optimal erfüllen.

## Entscheidung

**Modulare Serving-Schicht** mit spezialisierten Komponenten je Zugriffsart — keine monolithische Serving-Lösung.

| Zugriffsart          | Empfohlene Komponente                     | Status |
|----------------------|-------------------------------------------|:------:|
| Analytisches SQL     | DuckDB (lokal) / Athena-kompatible Engine | ✅    |
| OGC WMS / WFS        | GeoServer oder MapServer                  | 🔄    |
| Vektorkacheln        | Martin oder pg_tileserv                   | 🔄    |
| Raster / COG-Tiles   | TiTiler                                   | ✅    |
| STAC-API             | stac-fastapi                              | ✅    |
| Programmatische API  | REST-API über Objektspeicher-Direktzugriff | ⏳    |

## Offene Entscheidungen

- **OGC-Server:** GeoServer vs. MapServer — Entscheidung abhängig von den Anforderungen des FüInfoSys (Phase 2 Start)
- **Vektorkachel-Server:** Martin vs. pg_tileserv — Entscheidung offen
- **Programmatische API:** Design und Framework-Wahl ausstehend

## Konsequenzen

- Höhere Komplexität im Betrieb durch mehrere Komponenten
- Jede Komponente kann unabhängig skaliert und ausgetauscht werden
- Klare Zuordnung: jeder Zugriffstyp hat genau eine verantwortliche Komponente
