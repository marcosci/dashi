# 5. Anforderungen

## Grundprinzip

Anforderungen sind der Vertrag zwischen der Initiative und ihren Stakeholdern. Sie werden hier in zwei Kategorien unterteilt: **funktionale Anforderungen** beschreiben, was das System tun muss. **Nicht-funktionale Anforderungen** beschreiben, wie gut es das tun muss. Beide sind gleichwertig verbindlich.

Zusätzlich wird pro Domäne ein **Workload-Katalog** geführt, der die konkreten Nutzungsszenarien mit ihren technischen Charakteristika beschreibt. Dieser Katalog ist die Grundlage für alle Architektur- und Technologieentscheidungen in den nachfolgenden Kapiteln.

---

## 5.1 Funktionale Anforderungen

### Ingestion & Datenaufnahme

| ID   | Anforderung | Priorität |
|------|-------------|-----------|
| F-01 | Das System muss Geodaten aus heterogenen Quellformaten (GeoTIFF, Shapefile, GeoPackage, GeoJSON, LAZ, CSV mit Koordinaten) aufnehmen können | Hoch |
| F-02 | Das System muss sowohl batch-basierte als auch kontinuierliche Datenlieferungen unterstützen | Hoch |
| F-03 | Jede Datenlieferung muss automatisch auf Vollständigkeit, Formatkonformität und Geometriegültigkeit geprüft werden | Hoch |
| F-04 | Abgelehnte Lieferungen müssen mit strukturiertem Fehlerprotokoll an den Datenlieferanten zurückgemeldet werden | Mittel |
| F-05 | Das System muss eine Transformation in das organisationsweite Ziel-KRS beim Übergang Landing → Processed automatisch durchführen | Hoch |

### Speicherung & Zonenverwaltung

| ID   | Anforderung | Priorität |
|------|-------------|-----------|
| F-06 | Das System muss ein dreistufiges Zonenmodell (Landing, Processed, Curated) mit definierten Zugriffsrechten pro Zone umsetzen | Hoch |
| F-07 | Daten in der Landing Zone müssen unveränderlich (immutable) gespeichert werden | Hoch |
| F-08 | Das System muss Versionierung von Datensätzen unterstützen, sodass frühere Zustände reproduzierbar abrufbar sind | Hoch |
| F-09 | Das System muss eine räumliche Partitionierung der Daten unterstützen (z. B. H3, S2 oder administrativ) | Hoch |
| F-10 | Rasterdata muss als Cloud Optimized GeoTIFF (COG) gespeichert werden | Hoch |
| F-11 | Vektordaten müssen als GeoParquet gespeichert werden | Hoch |

### Katalog & Metadaten

| ID   | Anforderung | Priorität |
|------|-------------|-----------|
| F-12 | Jeder Datensatz muss mit einem standardisierten Metadatensatz (räumliche Ausdehnung, zeitliche Ausdehnung, KRS, Auflösung, Herkunft, Klassifizierung) versehen werden | Hoch |
| F-13 | Der Katalog muss eine räumliche Suche (Bounding Box, Verschneidung) und eine zeitliche Suche (Zeitraum, Aktualität) unterstützen | Hoch |
| F-14 | Rasterdaten und Bilddaten müssen über einen STAC-konformen Katalog auffindbar sein | Hoch |
| F-15 | Die Datenherkunft (Lineage) muss für jeden Datensatz lückenlos dokumentiert und maschinell abfragbar sein | Hoch |

### Verarbeitung & Pipelines

| ID   | Anforderung | Priorität |
|------|-------------|-----------|
| F-16 | Datenpipelines müssen idempotent sein — eine wiederholte Ausführung darf keine unerwünschten Seiteneffekte erzeugen | Hoch |
| F-17 | Das System muss die Verarbeitung großer Rasterdatensätze (> 10 GB) ohne manuelle Eingriffe unterstützen | Hoch |
| F-18 | Fehlgeschlagene Pipeline-Läufe müssen automatisch protokolliert und über einen definierten Benachrichtigungskanal gemeldet werden | Hoch |
| F-19 | Das System muss die Erstellung domänenübergreifender Analyseprodukte durch Verschneidung von Datensätzen aus verschiedenen Domänen unterstützen | Mittel |

### Serving & Zugriff

| ID   | Anforderung | Priorität |
|------|-------------|-----------|
| F-20 | Das System muss analytischen SQL-Zugriff auf Vektordaten in der Curated Zone bereitstellen | Hoch |
| F-21 | Das System muss OGC-konforme Dienste (WMS, WFS) für externe Konsumenten bereitstellen können | Mittel |
| F-22 | Das System muss Vektorkacheln (Vector Tiles) für kartenbasierte Konsumenten bereitstellen können | Mittel |
| F-23 | Zugriff auf Daten muss rollenbasiert steuerbar sein — auf Ebene der Zone, der Domäne und des einzelnen Datensatzes | Hoch |
| F-24 | Das System muss eine definierte API für programmatischen Datenzugriff durch Analyseteams und ML-Pipelines bereitstellen | Mittel |

---

## 5.2 Nicht-funktionale Anforderungen

### Performance

| ID    | Anforderung | Zielwert |
|-------|-------------|----------|
| NF-01 | Antwortzeit für einfache Bounding-Box-Abfragen auf Vektordaten (Curated Zone) | < 5 Sekunden |
| NF-02 | Durchsatz für Batch-Ingestion großer Datensätze | > [X] GB/h |
| NF-03 | Maximale Verarbeitungszeit für Standard-Pipelines (Landing → Curated) | < [X] Stunden |
| NF-04 | Gleichzeitig unterstützte Analysenutzer ohne Leistungsdegradation | > [X] Nutzer |

### Verfügbarkeit & Resilienz

| ID    | Anforderung | Zielwert |
|-------|-------------|----------|
| NF-05 | Verfügbarkeit der Serving-Schicht im Produktivbetrieb | > 99,5 % |
| NF-06 | Recovery Time Objective (RTO) bei Systemausfall | < [X] Stunden |
| NF-07 | Recovery Point Objective (RPO) — maximaler Datenverlust | < [X] Stunden |
| NF-08 | Pipelines müssen bei Teilausfall eines Quellsystems weiter betrieben werden können | Pflicht |

### Sicherheit

| ID    | Anforderung | Zielwert |
|-------|-------------|----------|
| NF-09 | Alle Daten müssen at rest und in transit verschlüsselt sein | Pflicht |
| NF-10 | Zugriffe auf die Plattform müssen vollständig auditiert und protokolliert werden | Pflicht |
| NF-11 | Die Plattform muss für den Betrieb bis Klassifizierungsstufe [X] akkreditiert werden | Pflicht |
| NF-12 | Geometrie-basierte Zugriffsbeschränkungen (z. B. Zugriff nur auf Daten innerhalb eines definierten Zuständigkeitsbereichs) müssen technisch durchsetzbar sein | Hoch |

### Skalierbarkeit

| ID    | Anforderung | Zielwert |
|-------|-------------|----------|
| NF-13 | Die Plattform muss ein Datenwachstum von [X] TB/Jahr ohne Architekturänderungen bewältigen | Pflicht |
| NF-14 | Neue Domänen müssen ohne Eingriff in bestehende Pipelines onboardierbar sein | Hoch |
| NF-15 | Neue Datenformate müssen durch Konfiguration, nicht durch Neuentwicklung, integrierbar sein | Mittel |

### Betrieb & Beobachtbarkeit

| ID    | Anforderung | Zielwert |
|-------|-------------|----------|
| NF-16 | Alle Pipelines müssen über ein zentrales Monitoring-Dashboard überwachbar sein | Hoch |
| NF-17 | Datenqualitätsmetriken (Geometriegültigkeit, KRS-Konformität, Vollständigkeit) müssen automatisch erhoben und visualisiert werden | Hoch |
| NF-18 | Das System muss ohne spezialisiertes GIS-Fachwissen administrierbar sein | Mittel |

---

## 5.3 Workload-Katalog

Der Workload-Katalog beschreibt die primären Nutzungsszenarien der Plattform mit ihren technischen Charakteristika. Er ist die direkte Grundlage für Entscheidungen zur Serving-Architektur und Partitionierungsstrategie.

| ID   | Workload | Domäne | Zugriffsart | Volumen | Latenz | Häufigkeit |
|------|----------|--------|-------------|---------|--------|------------|
| W-01 | Historische Geländeanalyse (Sichtbarkeit, Geländeklassifikation) | Gelände & Umwelt | Batch SQL / Rasterverarbeitung | Hoch | Niedrig (Stunden) | Täglich |
| W-02 | Aktuelle Routenplanung und Zugänglichkeitsanalyse | Logistik & C2 | Interaktive SQL-Abfrage | Mittel | Mittel (Minuten) | Mehrmals täglich |
| W-03 | Fusionierung von ISR-Produkten mit Geländedaten | ISR / Gelände | Batch-Verschneidung | Hoch | Niedrig (Stunden) | Bedarfsgesteuert |
| W-04 | Bereitstellung von Hintergrundkarten für Missionsplanungssysteme | Missionsplanung | Vektorkacheln / WMS | Mittel | Hoch (Sekunden) | Kontinuierlich |
| W-05 | Extraktion von ML-Trainingsdaten (Bildkacheln, Annotationen) | ISR / KI | Batch-Export | Sehr hoch | Niedrig (Stunden) | Wöchentlich |
| W-06 | Qualitätsprüfung neu eingehender Datensätze | Plattform intern | Pipeline-Trigger | Niedrig | Mittel (Minuten) | Bei Eingang |
| W-07 | Ad-hoc-Analyse durch Geoinformationsanalysten | Alle Domänen | Notebook / SQL | Mittel | Mittel (Minuten) | Täglich |

---

## 5.4 Offene Anforderungsfragen

Die folgenden Punkte sind noch nicht ausreichend geklärt und erfordern eine Abstimmung mit den Stakeholdern vor Abschluss der Anforderungsphase:

- Welche Klassifizierungsstufen müssen auf der Plattform verarbeitet werden können — und in getrennten oder gemeinsamen Zonen?
- Gibt es Echtzeit-Anforderungen aus dem C2-Bereich, die eine gesonderte Architekturkomponente erfordern?
- Welche externen Systeme (Bündnispartner, nationale Behörden) müssen über standardisierte Schnittstellen angebunden werden?
- Wie lange müssen Rohdaten in der Landing Zone aufbewahrt werden (Archivierungsfristen)?
- Welche bestehenden Quellsysteme haben keine standardisierten Exportschnittstellen und erfordern individuelle Konnektoren?

> Diese Fragen werden im [Risiko- und Fragenregister](10-risks-open-questions.md) nachverfolgt.
