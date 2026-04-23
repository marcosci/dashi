# ADR-008 — Räumliche Partitionierung: H3

**Status:** ✅ Entschieden

## Kontext

Alle Vektordaten werden räumlich partitioniert gespeichert. Das Partitionierungsschema beeinflusst direkt die Abfrageleistung und muss organisationsweit einheitlich sein.

## Bewertete Alternativen

| Alternative          | Vorteile | Nachteile |
|----------------------|----------|-----------|
| **H3 (Uber)**        | Hierarchisch, gleichflächig, weit verbreitet, Python/SQL-Support | Hexagonale Zellen ungewohnt |
| S2 (Google)          | Hierarchisch, globale Abdeckung | Geringere Open-Source-Tool-Reife |
| GeoHash              | Einfach, weit bekannt | Ungleiche Zellflächen an Polnähe |
| Administrative Grenzen | Operativ vertraut | Statisch, keine globale Hierarchie |

## Entscheidung

**H3** als primäres räumliches Partitionierungsschema.

| Resolution | Zellgröße   | Verwendung |
|-----------|-------------|------------|
| 5         | ~250 km²    | Globale und regionale Datensätze |
| 7         | ~5 km²      | Lokale und operative Datensätze |
| 9         | ~0,1 km²    | Hochauflösende urbane Datensätze |

## Konsequenzen

- Alle Pipelines müssen H3-Indizierung unterstützen
- Abfragen ohne räumlichen Filter scannen alle Partitionen — Analysten müssen auf Filternutzung hingewiesen werden
- H3-Bibliotheken müssen in alle Processing-Umgebungen integriert werden
