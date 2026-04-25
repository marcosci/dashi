# ADR-002 — Vektordatenformat: GeoParquet

**Status:** ✅ Entschieden

## Kontext

Vektordaten (Features, Geometrien, Attributtabellen) müssen in einem Format gespeichert werden, das analytisch effizient, cloud-nativ und interoperabel ist.

## Bewertete Alternativen

| Alternative      | Vorteile | Nachteile |
|------------------|----------|-----------|
| **GeoParquet**   | Spaltenorientiert, Predicate Pushdown, cloud-nativ, offener Standard | Relativ neu, Tooling noch wachsend |
| GeoPackage (GPKG) | OGC-Standard, weit verbreitet, GIS-Tools | Zeilenorientiert, keine cloud-native Lesbarkeit |
| Shapefile        | Maximale Kompatibilität | Veraltet, 2GB-Limit, keine nativen Geometrietypen |
| FlatGeobuf       | Schnell, streamingfähig | Kein spaltenorientierter Zugriff |
| GeoJSON          | Lesbar, universell | Kein effizientes Encoding für große Datensätze |

## Entscheidung

**GeoParquet** als primäres Vektordatenformat in der Processed und Curated Zone. **GeoJSON** und **GeoPackage** bleiben als Austauschformate an der Ingestion- und Serving-Schicht zulässig.

## Konsequenzen

- Alle eingehenden Vektorformate werden beim Übergang Landing → Processed nach GeoParquet konvertiert
- Query-Engines müssen Parquet nativ unterstützen
- Partitionierung erfolgt als Hive-partitioniertes GeoParquet-Verzeichnis auf Objektspeicher
