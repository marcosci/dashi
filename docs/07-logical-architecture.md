# 7. Logische Architektur

## Grundprinzip

Die logische Architektur beschreibt die Struktur der Plattform auf konzeptioneller Ebene — unabhängig von konkreten Technologien oder Produktnamen. Sie definiert, welche Schichten existieren, was in jede Schicht gehört, welche Transformationen an den Übergängen stattfinden und wer auf welche Schicht Zugriff hat.

Die logische Architektur ist der **stabilste Teil dieses Dokuments**. Technologieentscheidungen können sich ändern — das Zonenmodell und die Prinzipien dahinter bleiben konstant.

## 7.1 Schichtenmodell

Die Plattform gliedert sich in fünf horizontale Schichten. Daten fließen grundsätzlich von unten nach oben — von der Rohquelle bis zum analysebereit aufbereiteten Produkt.

```
┌─────────────────────────────────────────────────────────────────┐
│                        KONSUMSCHICHT                            │
│        Analysten · Missionsplanung · ML-Pipelines · APIs        │
├─────────────────────────────────────────────────────────────────┤
│                        SERVING-SCHICHT                          │
│      SQL-Engine · OGC-Dienste · Kachelserver · Feature Store    │
├─────────────────────────────────────┬───────────────────────────┤
│            CURATED ZONE             │      ENRICHMENT ZONE      │
│          Domänenprodukte            │  Domänenübergreifende P.  │
├─────────────────────────────────────┴───────────────────────────┤
│                        PROCESSED ZONE                           │
│           Standardisiertes KRS · Validiert · Katalogisiert      │
├─────────────────────────────────────────────────────────────────┤
│                         LANDING ZONE                            │
│         Rohdaten · Unveränderlich · Vollständig protokolliert   │
└─────────────────────────────────────────────────────────────────┘
                    Objektspeicher-Fundament
```

## 7.2 Zonenbeschreibungen

### Landing Zone — Rohdaten

Die Landing Zone ist der unveränderliche Eingang der Plattform. Alle Daten werden exakt so gespeichert, wie sie angeliefert wurden — ohne Transformation, ohne Bereinigung, ohne Interpretation.

**Prinzipien:**

- **Immutabilität:** Einmal geschriebene Daten werden nicht verändert oder gelöscht — nur archiviert
- **Vollständige Protokollierung:** Jede Lieferung wird mit Zeitstempel, Quelle, Liefernder Einheit und Prüfsumme erfasst
- **Kein direkter Analysezugriff:** Die Landing Zone ist keine Arbeitszone für Analysten — ausschließlich das Platform Team hat Schreibzugriff

**Übergabevertrag Landing → Processed:**

- Formatprüfung (ist das Dateiformat lesbar?)
- Geometriegültigkeitsprüfung (sind alle Geometrien valide?)
- Vollständigkeitsprüfung (sind alle erwarteten Felder vorhanden?)
- Koordinatenreferenzsystem erkannt und dokumentiert?
- Bei Fehler: Ablehnung mit strukturiertem Fehlerprotokoll, keine Weiterleitung

---

### Processed Zone — Standardisiert

In der Processed Zone werden Rohdaten in einen organisationsweit einheitlichen Zustand überführt. Diese Zone ist die technische Grundlage für alle weiteren Verarbeitungsschritte.

**Transformationen an diesem Übergang:**

- KRS-Transformation in das organisationsweite Ziel-KRS
- Formatkonvertierung in die Zielformate der Plattform (GeoParquet, COG, COPC)
- Geometriereparatur wo möglich und fachlich vertretbar
- Räumliche Partitionierung nach definiertem Schema
- Metadatenvervollständigung und Katalogeintrag

**Prinzipien:**

- Daten in der Processed Zone sind **technisch korrekt, aber noch nicht fachlich interpretiert**
- Schreibzugriff ausschließlich durch automatisierte Pipelines
- Lesezugriff für Data Engineers und spezialisierte Analysten

---

### Curated Zone — Fachlich aufbereitet

Die Curated Zone enthält domänenspezifische Produkte, die für den direkten operativen Einsatz aufbereitet sind. Hier findet die fachliche Anreicherung, Klassifikation und Qualitätssicherung statt.

**Verantwortlichkeit:** Die Curated Zone wird von den **Domänen-Dateneigentümern** verantwortet — nicht vom Platform Team. Das Platform Team stellt die Infrastruktur bereit; der Inhalt liegt in der Verantwortung der Domäne.

**Typische Inhalte:**

- Validierte und klassifizierte Geländemodelle
- Aufbereitete ISR-Produkte mit Metadatenannotation
- Bereinigte Logistiklagen mit Aktualitätsstempel
- Missionsrelevante Kartengrundlagen in Standardauflösung

---

### Enrichment Zone — Domänenübergreifend

Die Enrichment Zone ist der Ort für Produkte, die aus der Verschneidung mehrerer Domänen entstehen. Sie ist konzeptionell von der Curated Zone getrennt, da sie **keine einzelne Dateneigentümerschaft hat** — sondern gemeinsam von mehreren Domänen verantwortet wird.

**Beispiele:**

- Geländeanalyse angereichert mit aktuellen ISR-Erkenntnissen
- Logistikrouten verschnitten mit Geländeklassifikation und Wetterinformation
- Missionsplanungsprodukte mit integrierten Aufklärungsergebnissen

**Governance:** Jedes Enrichment-Produkt erfordert eine **explizite Freigabe aller beteiligten Dateneigentümer**.

---

### Serving-Schicht — Zugriff & Bereitstellung

Die Serving-Schicht ist die Schnittstelle zwischen der Plattform und ihren Konsumenten. Sie stellt keine eigene Datenhaltung dar, sondern bildet eine Zugriffsschicht über der Curated und Enrichment Zone.

**Zugriffspattern und zugehörige Komponenten:**

| Zugriffsart         | Zielgruppe                 | Komponente        |
|---------------------|----------------------------|-------------------|
| Analytisches SQL    | Geoinformationsanalysten   | SQL-Query-Engine  |
| OGC-Dienste (WMS/WFS) | Externe Systeme, FüInfoSys | OGC-Server        |
| Vektorkacheln       | Kartendarstellungen        | Kachelserver      |
| STAC-API            | Bildauswertung, ML         | STAC-Endpunkt     |
| Programmatischer Zugriff | ML-Pipelines, Entwickler | Daten-API        |

## 7.3 Datenfluss

Der vollständige Datenfluss von der Quelle bis zum Konsumenten folgt diesem Muster:

```
Datenquelle
    │
    ▼
[Ingestion-Adapter]
    │   Format- und Vollständigkeitsprüfung
    ▼
LANDING ZONE
    │
    ▼
[Standardisierungs-Pipeline]
    │   KRS-Transformation · Formatkonvertierung
    │   Geometrievalidierung · Partitionierung
    ▼
PROCESSED ZONE
    │
    ▼
[Domänen-Pipeline]
    │   Fachliche Anreicherung · Klassifikation
    │   Qualitätssicherung · Katalogeintrag
    ▼
CURATED ZONE ──────────────────────────────┐
    │                                      │
    ▼                                      ▼
[Enrichment-Pipeline]             [Serving-Schicht]
    │   Domänenübergreifende                │
    │   Verschneidung                       ▼
    ▼                                   Konsumenten
ENRICHMENT ZONE
    │
    ▼
[Serving-Schicht]
    │
    ▼
Konsumenten
```

## 7.4 Governance der Zonenübergänge

Jeder Übergang zwischen Zonen ist ein **kontrollierter Akt** — kein automatischer Durchlauf. Die folgende Matrix definiert, wer Übergänge auslösen, genehmigen und überwachen darf.

| Übergang              | Auslöser               | Verantwortlich    | Freigabe erforderlich             |
|-----------------------|------------------------|-------------------|-----------------------------------|
| Quelle → Landing      | Datenlieferant / Scheduler | Platform Team     | Nein                              |
| Landing → Processed   | Automatisierte Pipeline    | Platform Team     | Nein                              |
| Processed → Curated   | Domänen-Pipeline       | Data Owner        | Ja — Data Owner                   |
| Processed → Enrichment | Enrichment-Pipeline   | Platform Architect | Ja — alle beteiligten Data Owner |
| Curated → Serving     | Konfiguration          | Platform Team     | Ja — Data Owner                   |

## 7.5 Räumliche Governance

Neben der zonenbasierten Governance gelten folgende raumspezifische Prinzipien, die in der logischen Architektur verankert sind:

### Einheitliches Koordinatenreferenzsystem (KRS)

Die gesamte Plattform verwendet ein einziges organisationsweites Ziel-KRS. Die Transformation findet ausschließlich am Übergang Landing → Processed statt. Innerhalb der Plattform gibt es keine weiteren KRS-Transformationen.

> **Empfehlung:** EPSG:4326 (WGS84) als globales Ziel-KRS für Langzeitspeicherung, mit optionaler Projektion für spezifische Analyseprodukte in der Curated Zone.

### Räumliche Partitionierung

Alle Vektordaten werden nach einem einheitlichen räumlichen Partitionierungsschema organisiert. Das Schema wird in Phase 1 festgelegt und gilt verbindlich für alle Domänen.

> **Empfehlung:** H3-Hierarchie (Resolution 5 für globale Datensätze, Resolution 7–8 für lokale/regionale Datensätze) als Partitionierungsgrundlage.

### Geometriegültigkeit

Ungültige Geometrien werden nicht in die Processed Zone übernommen. Geometriereparatur ist zulässig, muss aber protokolliert werden. Reparierte Geometrien erhalten einen entsprechenden Qualitätsindikator im Metadatensatz.

## 7.6 Abgrenzung zur physischen Architektur

Die logische Architektur trifft bewusst **keine Aussagen** zu:

- Konkreten Technologien, Produkten oder Cloud-Anbietern
- Netzwerktopologie und Infrastrukturkomponenten
- Deployment-Modellen (on-premise, cloud, hybrid)
- Spezifischen Sicherheitsarchitekturmaßnahmen

Diese Entscheidungen sind Gegenstand von **[Kapitel 8 — Technologieentscheidungen](08-technology-decisions.md)** und einer künftigen physischen Architekturspezifikation.
