# Index — All IDs at a Glance

Single lookup for every identified requirement, workload, ADR, open question, and risk. Use this file to jump directly to any `F-NN`, `NF-NN`, `W-NN`, `ADR-NNN`, `R-NN`, or question ID.

## Functional Requirements (F-01 – F-24)

| ID | Kurz | Priorität | Kapitel |
|----|------|-----------|---------|
| F-01 | Heterogene Quellformate aufnehmen | Hoch | [§5.1](05-requirements.md#ingestion--datenaufnahme) |
| F-02 | Batch + kontinuierliche Lieferungen | Hoch | [§5.1](05-requirements.md#ingestion--datenaufnahme) |
| F-03 | Automatische Validierungsprüfung | Hoch | [§5.1](05-requirements.md#ingestion--datenaufnahme) |
| F-04 | Strukturiertes Fehlerprotokoll | Mittel | [§5.1](05-requirements.md#ingestion--datenaufnahme) |
| F-05 | Automatische KRS-Transformation | Hoch | [§5.1](05-requirements.md#ingestion--datenaufnahme) |
| F-06 | Dreistufiges Zonenmodell | Hoch | [§5.1](05-requirements.md#speicherung--zonenverwaltung) |
| F-07 | Immutable Landing Zone | Hoch | [§5.1](05-requirements.md#speicherung--zonenverwaltung) |
| F-08 | Versionierung | Hoch | [§5.1](05-requirements.md#speicherung--zonenverwaltung) |
| F-09 | Räumliche Partitionierung | Hoch | [§5.1](05-requirements.md#speicherung--zonenverwaltung) |
| F-10 | Raster als COG | Hoch | [§5.1](05-requirements.md#speicherung--zonenverwaltung) |
| F-11 | Vektor als GeoParquet | Hoch | [§5.1](05-requirements.md#speicherung--zonenverwaltung) |
| F-12 | Standardisierter Metadatensatz | Hoch | [§5.1](05-requirements.md#katalog--metadaten) |
| F-13 | Räumlich-zeitliche Suche | Hoch | [§5.1](05-requirements.md#katalog--metadaten) |
| F-14 | STAC-konformer Katalog | Hoch | [§5.1](05-requirements.md#katalog--metadaten) |
| F-15 | Lückenlose Lineage | Hoch | [§5.1](05-requirements.md#katalog--metadaten) |
| F-16 | Idempotente Pipelines | Hoch | [§5.1](05-requirements.md#verarbeitung--pipelines) |
| F-17 | Große Raster (>10 GB) | Hoch | [§5.1](05-requirements.md#verarbeitung--pipelines) |
| F-18 | Automatische Fehlerprotokollierung | Hoch | [§5.1](05-requirements.md#verarbeitung--pipelines) |
| F-19 | Domänenübergreifende Verschneidung | Mittel | [§5.1](05-requirements.md#verarbeitung--pipelines) |
| F-20 | Analytisches SQL | Hoch | [§5.1](05-requirements.md#serving--zugriff) |
| F-21 | OGC-Dienste (WMS/WFS) | Mittel | [§5.1](05-requirements.md#serving--zugriff) |
| F-22 | Vektorkacheln | Mittel | [§5.1](05-requirements.md#serving--zugriff) |
| F-23 | Rollenbasierte Zugriffskontrolle | Hoch | [§5.1](05-requirements.md#serving--zugriff) |
| F-24 | Programmatische API | Mittel | [§5.1](05-requirements.md#serving--zugriff) |

## Non-Functional Requirements (NF-01 – NF-18)

| ID | Kurz | Zielwert | Kapitel |
|----|------|----------|---------|
| NF-01 | BBox-Abfrage Vektor | < 5 Sek. | [§5.2](05-requirements.md#performance) |
| NF-02 | Batch-Ingestion-Durchsatz | > [X] GB/h | [§5.2](05-requirements.md#performance) |
| NF-03 | Standard-Pipeline-Zeit | < [X] Std. | [§5.2](05-requirements.md#performance) |
| NF-04 | Parallele Analysenutzer | > [X] | [§5.2](05-requirements.md#performance) |
| NF-05 | Serving-Verfügbarkeit | > 99,5 % | [§5.2](05-requirements.md#verfügbarkeit--resilienz) |
| NF-06 | RTO | < [X] Std. | [§5.2](05-requirements.md#verfügbarkeit--resilienz) |
| NF-07 | RPO | < [X] Std. | [§5.2](05-requirements.md#verfügbarkeit--resilienz) |
| NF-08 | Pipeline-Betrieb bei Teilausfall | Pflicht | [§5.2](05-requirements.md#verfügbarkeit--resilienz) |
| NF-09 | Verschlüsselung at rest + in transit | Pflicht | [§5.2](05-requirements.md#sicherheit) |
| NF-10 | Audit-Logging aller Zugriffe | Pflicht | [§5.2](05-requirements.md#sicherheit) |
| NF-11 | Akkreditierung Stufe [X] | Pflicht | [§5.2](05-requirements.md#sicherheit) |
| NF-12 | Geometrie-basierte Zugriffsbeschränkungen | Hoch | [§5.2](05-requirements.md#sicherheit) |
| NF-13 | Datenwachstum [X] TB/Jahr | Pflicht | [§5.2](05-requirements.md#skalierbarkeit) |
| NF-14 | Domänen ohne Pipeline-Eingriff | Hoch | [§5.2](05-requirements.md#skalierbarkeit) |
| NF-15 | Neue Formate per Konfiguration | Mittel | [§5.2](05-requirements.md#skalierbarkeit) |
| NF-16 | Zentrales Monitoring | Hoch | [§5.2](05-requirements.md#betrieb--beobachtbarkeit) |
| NF-17 | Datenqualitätsmetriken | Hoch | [§5.2](05-requirements.md#betrieb--beobachtbarkeit) |
| NF-18 | Ohne GIS-Fachwissen administrierbar | Mittel | [§5.2](05-requirements.md#betrieb--beobachtbarkeit) |

## Workloads (W-01 – W-07)

| ID | Workload | Domäne | Volumen | Latenz | Häufigkeit |
|----|----------|--------|---------|--------|------------|
| W-01 | Historische Geländeanalyse | Gelände & Umwelt | Hoch | Std. | Täglich |
| W-02 | Routenplanung + Zugänglichkeit | Logistik & C2 | Mittel | Min. | Mehrmals täglich |
| W-03 | ISR/Gelände-Fusion | ISR / Gelände | Hoch | Std. | Bedarfsgesteuert |
| W-04 | Missionsplanungs-Hintergrundkarten | Missionsplanung | Mittel | Sek. | Kontinuierlich |
| W-05 | ML-Trainingsdaten-Extraktion | ISR / KI | Sehr hoch | Std. | Wöchentlich |
| W-06 | Qualitätsprüfung Neueingang | Plattform intern | Niedrig | Min. | Bei Eingang |
| W-07 | Ad-hoc-Analyse | Alle Domänen | Mittel | Min. | Täglich |

Details: [§5.3](05-requirements.md#53-workload-katalog)

## Architecture Decision Records (ADR-001 – ADR-011)

| ID | Bereich | Entscheidung | Status | Datei |
|----|---------|--------------|:------:|-------|
| ADR-001 | Speicherfundament | RustFS (S3-kompatibel) | ✅ | [→](adr/ADR-001-object-storage.md) |
| ADR-002 | Vektorformat | GeoParquet | ✅ | [→](adr/ADR-002-vector-format-geoparquet.md) |
| ADR-003 | Rasterformat | COG + Zarr | ✅ | [→](adr/ADR-003-raster-format-cog.md) |
| ADR-004 | Punktwolkenformat | COPC | ✅ | [→](adr/ADR-004-pointcloud-copc.md) |
| ADR-005 | Tabellenformat | Iceberg vs. Delta Lake | 🔄 | [→](adr/ADR-005-table-format.md) |
| ADR-006 | Datenkatalog | STAC + techn. Katalog offen | 🔄 | [→](adr/ADR-006-data-catalog.md) |
| ADR-007 | Verarbeitungs-Engine | Spark+Sedona / DuckDB | 🔄 | [→](adr/ADR-007-processing-engine.md) |
| ADR-008 | Partitionierung | H3 | ✅ | [→](adr/ADR-008-spatial-partitioning-h3.md) |
| ADR-009 | Serving | Modularer Ansatz | 🔄 | [→](adr/ADR-009-serving-layer.md) |
| ADR-010 | Orchestrierung | Prefect | ✅ | [→](adr/ADR-010-pipeline-orchestration.md) |
| ADR-011 | Infra-Substrat | k3s lokal + GitHub | ✅ | [→](adr/ADR-011-infra-substrate.md) |

## Open Questions (F-01 – F-10, question register)

| ID | Kurz | Bereich | Status | Benötigt bis |
|----|------|---------|:------:|--------------|
| F-01 | Klassifizierungsstufen + Zonentrennung | Sicherheit | 🔴 | Ende Phase 1 |
| F-02 | Infrastruktur (Cloud/on-prem/hybrid) — geklärt via ADR-011 | Infrastruktur | 🟢 | Monat 1 |
| F-03 | Echtzeit-Anforderungen C2 | C2 | 🟡 | Ende Phase 1 |
| F-04 | Externe Systeme / Bündnispartner | Interoperabilität | 🟡 | Phase 2 Start |
| F-05 | Rohdaten-Archivierungsfristen | Governance / Recht | 🟡 | Ende Phase 1 |
| F-06 | Quellsysteme ohne Export-Standard | Ingestion | 🟡 | Ende Phase 1 |
| F-07 | STANAG-Konformitätspflicht | Interoperabilität | 🟡 | Phase 2 |
| F-08 | Organisationsweites Ziel-KRS | Architektur | 🟡 | Ende Phase 1 |
| F-09 | Betriebsverantwortung nach Phase 3 | Betrieb | 🟡 | Phase 2 |
| F-10 | Offline-Betrieb / taktische Randlagen | Architektur | 🟡 | Ende Phase 1 |

> **Hinweis:** Die Question-IDs `F-NN` kollidieren namentlich mit den Funktional-Anforderungs-IDs. Kontext entscheidet — Kapitel 5 vs. Kapitel 10.

## Risks (R-01 – R-18)

| ID | Risiko | Kategorie | Stufe |
|----|--------|-----------|:-----:|
| R-01 | Dateneigentümer verweigern Zugang | Organisatorisch | 🔴 |
| R-02 | Wechselnde Führungsunterstützung | Organisatorisch | 🟠 |
| R-03 | Unzureichende Teamkapazität | Organisatorisch | 🔴 |
| R-04 | Widerstand gegen Kulturwandel | Organisatorisch | 🟠 |
| R-05 | Zuständigkeitskonflikte Enrichment | Organisatorisch | 🟡 |
| R-06 | Undokumentierte Quellformate | Technisch | 🟠 |
| R-07 | Unbekannte Datenvolumina | Technisch | 🟡 |
| R-08 | Technologien nicht betreibbar | Technisch | 🟠 |
| R-09 | Performance domänenübergr. Abfragen | Technisch | 🟡 |
| R-10 | Datenverlust durch fehlende Backups | Technisch | 🟡 |
| R-11 | Schema-Drift der Quellsysteme | Technisch | 🟠 |
| R-12 | Akkreditierungsprozess dauert | Sicherheit | 🔴 |
| R-13 | Speicherung klassifizierter Daten | Sicherheit | 🟠 |
| R-14 | Fehlkonfigurierte Zugriffsrechte | Sicherheit | 🟠 |
| R-15 | Technologien ohne militär. Zulassung | Sicherheit | 🟠 |
| R-16 | Verzögerte Infrastrukturbeschaffung | Zeitplan | 🔴 |
| R-17 | Scope Creep | Zeitplan | 🟠 |
| R-18 | Schlüsselpersonen verlassen Projekt | Ressourcen | 🟠 |

Details: [§10.2](10-risks-open-questions.md#102-risikoregister)

## Chapter Quick Links

- [01 — Zusammenfassung](01-summary.md)
- [02 — Kontext & Motivation](02-context.md)
- [03 — Ziele & Nicht-Ziele](03-goals.md)
- [04 — Stakeholder & Rollen](04-stakeholders.md)
- [05 — Anforderungen](05-requirements.md)
- [06 — Ist-Zustand](06-baseline.md)
- [07 — Logische Architektur](07-logical-architecture.md)
- [08 — Technologieentscheidungen](08-technology-decisions.md)
- [09 — Phasenplan](09-phases.md)
- [10 — Offene Fragen & Risiken](10-risks-open-questions.md)
- [Glossar](GLOSSARY.md)
