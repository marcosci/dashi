# ADR-001 — Objektspeicher als Fundament

**Status:** ✅ Entschieden

## Kontext

Die Plattform muss große Mengen heterogener Geodaten (Raster, Vektor, Punktwolken) kosteneffizient, langlebig und skalierbar speichern. Die Wahl der Speichergrundlage beeinflusst alle anderen Architekturentscheidungen.

## Bewertete Alternativen

| Alternative                 | Vorteile | Nachteile |
|-----------------------------|----------|-----------|
| **Objektspeicher (S3-kompatibel)** | Unbegrenzt skalierbar, kosteneffizient, cloud-nativ, breite Tool-Unterstützung | Kein nativer Transaktionssupport |
| Relationale Geodatenbank (PostGIS) | Starke Abfragesprache, ACID-Transaktionen | Skalierungsgrenzen bei großen Rasterdaten, hohe Betriebskosten |
| Netzwerklaufwerk / NAS      | Einfache Migration, vertraute Infrastruktur | Keine Skalierbarkeit, kein cloud-natives Ökosystem |

## Entscheidung

**Objektspeicher (S3-kompatibel)** als alleiniges Speicherfundament für alle Zonen der Plattform.

## Konsequenzen

- Alle Datenformate müssen objektspeicher-kompatibel sein (kein direktes Schreiben in Datenbanken als primärer Speicher)
- Query-Engines müssen direkt auf Objektspeicher operieren können
- Für den militärischen Kontext: on-premise S3-kompatible Lösung erforderlich (z. B. MinIO) falls kein Cloud-Zugang verfügbar
