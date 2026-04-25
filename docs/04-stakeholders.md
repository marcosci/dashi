# 4. Stakeholder & Rollen

## Grundprinzip

Im regulierten Umgebungen ist die Klärung von Verantwortlichkeiten keine Formalität — sie ist eine operative Notwendigkeit. Unklare Zuständigkeiten sind erfahrungsgemäß die häufigste Ursache für verzögerte Entscheidungen, blockierte Pipelines und gescheiterte Plattforminitiativen. Dieses Kapitel definiert verbindlich, wer welche Rolle in dieser Initiative übernimmt.

## Rollenmodell

> **Besetzungsstand (2026-04-23, Pre-Phase-1 / PoC):** Marco Sciaini und Johannes Schlund leiten die Initiative gemeinsam als Co-Owner, solange die Initiative als interne Entwicklung im independent project-Kontext betrieben wird. Rollenverteilung auf zusätzliche Personen erfolgt mit Phase-2-Übergabe in den Produktivbetrieb.

### Initiative Owner / Auftraggeber
Trägt die organisatorische Verantwortung für die Initiative. Trifft finale Entscheidungen bei Eskalationen, sichert Ressourcen und Budget, und gibt die Phasenübergänge frei. Zwei-Personen-Owner-Modell: beide gemeinsam verantwortlich, Entscheidungen einvernehmlich.

| Rolle            | Name / Einheit                    | Kontakt             |
|------------------|-----------------------------------|---------------------|
| Initiative Owner | Marco Sciaini / independent project       | marco@kaldera.dev   |
| Initiative Owner | Johannes Schlund / independent project   | [tbd]               |

### Platform Architect
Verantwortet die technische Gesamtarchitektur der Plattform. Trifft und dokumentiert Architekturentscheidungen, bewertet Technologieoptionen, definiert Zonenverträge und Schnittstellenstandards. Eskalationspunkt für technische Konflikte zwischen Teams.

| Rolle              | Name / Einheit                    | Kontakt             |
|--------------------|-----------------------------------|---------------------|
| Platform Architect | Marco Sciaini / independent project       | marco@kaldera.dev   |
| Platform Architect | Johannes Schlund / independent project   | [tbd]               |

### Platform Team
Verantwortlich für Aufbau, Betrieb und Weiterentwicklung der Plattforminfrastruktur. Stellt die Zonenarchitektur, Pipelines, den Katalog und die Serving-Schicht bereit.

| Rolle                   | Name                              | Kontakt             |
|-------------------------|-----------------------------------|---------------------|
| Platform Lead           | Marco Sciaini + Johannes Schlund | marco@kaldera.dev   |
| Infrastructure Engineer | Marco Sciaini + Johannes Schlund (PoC) | marco@kaldera.dev |
| Data Engineer           | Marco Sciaini + Johannes Schlund (PoC) | marco@kaldera.dev |
| Security Engineer       | [offen — nach Phase 2]            | [tbd]               |

### Domänen-Dateneigentümer (Data Owner)
Pro Domäne wird ein verantwortlicher Dateneigentümer benannt. Dieser ist zuständig für die inhaltliche Korrektheit der Daten seiner Domäne, die Einhaltung von Qualitätsstandards, die Freigabe von Schemaänderungen und die Benennung von Datenlieferanten.

| Domäne             | Data Owner | Einheit   | Kontakt   |
|--------------------|------------|-----------|-----------|
| Earth observation   | [Name]     | [Einheit] | [Kontakt] |
| operational planning | [Name]   | [Einheit] | [Kontakt] |
| logistics & supply chain | [Name]  | [Einheit] | [Kontakt] |
| terrain & environment   | [Name]     | [Einheit] | [Kontakt] |

### Datenlieferanten (Data Producer)
Teams oder Systeme, die Daten in die Plattform einspeisen. Verantwortlich für die Einhaltung der vereinbarten Lieferschnittstellen, Formate und Lieferzyklen.

| Quelle / System | Liefernde Einheit | Domäne   | Ansprechpartner |
|-----------------|-------------------|----------|-----------------|
| [Quellsystem]   | [Einheit]         | [Domäne] | [Kontakt]       |

### Datenkonsumenten (Data Consumer)
Teams, Systeme oder Personen, die Daten aus der Plattform beziehen. **Kein Schreibrecht in produktive Zonen.**

| Konsument      | Einheit   | Primäre Nutzung          | Ansprechpartner |
|----------------|-----------|--------------------------|-----------------|
| [Team / System] | [Einheit] | [Analyseart / Anwendungsfall] | [Kontakt]   |

### Sicherheits- & Compliance-Auditsverantwortliche

| Rolle                     | Name / Einheit | Kontakt   |
|---------------------------|----------------|-----------|
| IT-Sicherheitsbeauftragter | [Name]        | [Kontakt] |
| Geheimschutzbeauftragter  | [Name]         | [Kontakt] |

### Lenkungsausschuss / Steuerungskreis

| Mitglied | Funktion  | Einheit   |
|----------|-----------|-----------|
| [Name]   | [Funktion] | [Einheit] |

## RACI-Übersicht

Legende: **R** = Responsible · **A** = Accountable · **C** = Consulted · **I** = Informed

| Entscheidung            | Initiative Owner | Platform Architect | Data Owner | Security |
|-------------------------|------------------|--------------------|------------|----------|
| Architekturentscheidungen | I              | A/R                | C          | C        |
| Technologieauswahl      | C                | A/R                | I          | C        |
| Datenqualitätsstandards | I                | C                  | A/R        | I        |
| Sicherheitsfreigaben    | C                | C                  | I          | A/R      |
| Phasenübergänge         | **A/R**          | C                  | C          | C        |
| Schemaänderungen        | I                | C                  | **A/R**    | I        |
| Budgetentscheidungen    | **A/R**          | I                  | I          | I        |
