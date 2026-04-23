# ADR-007 — Verarbeitungs-Engine: Apache Spark mit Sedona (vs. Alternatives)

**Status:** 🔄 In Diskussion

**Fälligkeit:** Ende Phase 1

## Kontext

Die Plattform muss große Geodatensätze verarbeiten — sowohl Vektor als auch Raster. Die Verarbeitungs-Engine ist die zentrale Komponente der Pipeline-Architektur.

## Bewertete Alternativen

| Alternative             | Vorteile | Nachteile |
|-------------------------|----------|-----------|
| **Apache Spark + Sedona** | Skalierbar, räumliche Operationen nativ, breite Format-Unterstützung | Ressourcenintensiv, komplex im Betrieb |
| Dask + GeoPandas        | Python-nativ, einfacher Einstieg | Skalierungsgrenzen bei sehr großen Datensätzen |
| DuckDB + Spatial Extension | Extrem schnell für analytische Abfragen, einfach | Kein verteiltes Processing |
| GDAL-basierte Skripte   | Maximale Formatunterstützung | Nicht skalierbar, schwer orchestrierbar |

## Entscheidung

**Noch offen** — abhängig von verfügbarer Infrastruktur und Teamkompetenz.

**Empfehlung:** Hybridansatz
- **DuckDB** für analytische Workloads in der Curated Zone
- **Spark + Sedona** für große Batch-Transformationen in der Processed Zone

## Konsequenzen

- Hybridansatz erhöht die Komplexität, deckt aber beide Workload-Typen optimal ab
- Teamkompetenz in Spark muss ggf. aufgebaut werden
- Entscheidung bis Ende Phase 1 erforderlich
