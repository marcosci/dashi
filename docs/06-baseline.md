# 6. Ist-Zustand & Bestandsaufnahme

## Grundprinzip

Die Bestandsaufnahme des aktuellen Zustands bildet die sachliche Grundlage für alle nachfolgenden Architekturentscheidungen. In diesem Fall ist die Ausgangslage klar: Es existiert keine zentrale, dedizierte Plattform für die Verwaltung und Verarbeitung von Geodaten. Die Organisation befindet sich in einer **Greenfield-Situation** — das ist sowohl eine Herausforderung als auch eine Chance.

## 6.1 Aktuelle Situation

Es ist derzeit keine konsolidierte Geodateninfrastruktur vorhanden. Weder eine zentrale Datenhaltung, noch standardisierte Pipelines, noch ein gemeinsamer Datenkatalog existieren organisationsweit. Geodaten werden — soweit bekannt — lokal, dezentral und nach individuellem Bedarf der jeweiligen Einheiten verwaltet.

Die vollständige Bestandsaufnahme vorhandener Datenquellen, Werkzeuge und Prozesse ist selbst Bestandteil von **Phase 1 (Proof of Concept)** und wird im Rahmen der Stakeholder-Interviews und einer strukturierten Datenerhebung erarbeitet.

> Dieses Kapitel wird im Verlauf von Phase 1 schrittweise befüllt und ist zum Zeitpunkt der Erstellung dieses Dokuments bewusst offen gehalten.

## 6.2 Implikationen der Greenfield-Situation

Die Abwesenheit einer bestehenden Plattform hat direkte Auswirkungen auf die Initiative — positive wie negative.

### Vorteile

- **Keine Altlasten.** Es müssen keine bestehenden Systeme abgelöst, migriert oder rückwärtskompatibel unterstützt werden. Architekturentscheidungen können ohne Kompromisse getroffen werden.
- **Kein politischer Besitzstand.** Da keine Einheit eine bestehende Plattform verteidigt, ist die Bereitschaft zur Konsolidierung unter einer gemeinsamen Lösung potenziell höher.
- **Standards von Anfang an.** Koordinatenreferenzsysteme, Metadatenschemata, Qualitätsstandards und Zonenverträge können als verbindliche Grundlage eingeführt werden — ohne Rücksicht auf gewachsene Inkompatibilitäten.

### Risiken

- **Unbekannte Datenlage.** Da keine zentrale Übersicht existiert, ist unklar, welche Geodaten in welcher Qualität, welchem Format und an welchem Ort vorhanden sind. Die Bestandsaufnahme in Phase 1 ist daher ein kritischer Meilenstein. — Register: [R-07](10-risks-open-questions.md#technische-risiken) (Datenvolumina), offene Frage [F-06](10-risks-open-questions.md#101-offene-fragen) (undokumentierte Quellsysteme)
- **Unbekannte Quellsysteme.** Welche Systeme Geodaten erzeugen oder konsumieren, ist nicht vollständig bekannt. Fehlende oder schlecht dokumentierte Schnittstellen können die Ingestion-Architektur erheblich beeinflussen. — Register: [R-06](10-risks-open-questions.md#technische-risiken) (undokumentierte Formate), [R-11](10-risks-open-questions.md#technische-risiken) (Schema-Drift)
- **Keine Vergleichsbasis.** Ohne Ausgangszustand ist es schwerer, den Nutzen der Plattform quantitativ nachzuweisen. Erfolgskennzahlen müssen daher bereits in Phase 1 als Baseline erhoben werden — zum Beispiel: gemessener manueller Aufwand für Datenbeschaffung und -konvertierung heute. — Bezug zum Reduktionsziel in [§3 Operative Ziele](03-goals.md#operative-ziele) (`[X %]`-Placeholder).
- **Kultureller Wandel.** Dort wo heute keine Plattform existiert, existieren oft informelle Prozesse, persönliche Datensilos und gewachsene Abhängigkeiten. Die Einführung einer gemeinsamen Plattform erfordert aktives Change Management — nicht nur Technologie. — Register: [R-01](10-risks-open-questions.md#organisatorische-risiken) (Verweigerung Datenzugang), [R-04](10-risks-open-questions.md#organisatorische-risiken) (Silo-Widerstand)

## 6.3 Aufgaben der Bestandsaufnahme in Phase 1

Die folgenden Erhebungen sind als expliziter Bestandteil von Phase 1 eingeplant und liefern die Grundlage für die finale Anforderungs- und Architekturspezifikation.

| Aufgabe | Methode | Verantwortlich | Zieldatum |
|---------|---------|----------------|-----------|
| Identifikation aller geodatenerzeugenden Systeme | Stakeholder-Interviews | Platform Architect | [Datum] |
| Erhebung vorhandener Datenbestände je Domäne | Fragebogen an Data Owner | Data Owner je Domäne | [Datum] |
| Analyse vorhandener Exportformate und Schnittstellen | Technische Sichtung | Data Engineer | [Datum] |
| Erfassung manueller Datenprozesse und Aufwände | Workshops je Domäne | Platform Architect | [Datum] |
| Bewertung sicherheitsrelevanter Datenbestände | Interview mit Sicherheitsbeauftragtem | Security Engineer | [Datum] |
| Dokumentation des Ergebnisses in diesem Kapitel | Redaktion | Platform Architect | [Datum] |

## 6.4 Bekannte Ausgangspunkte

Trotz der offenen Datenlage sind folgende Punkte bereits zum jetzigen Zeitpunkt bekannt und fließen in die Architekturplanung ein:

- Es existiert **keine zentrale Geodatenplattform**
- Es existiert **kein gemeinsamer Datenkatalog**
- Es existieren **keine standardisierten Ingestion-Pipelines**
- Das **vollständige Dateninventar ist unbekannt** und wird in Phase 1 erhoben
- Die Initiative startet auf der **grünen Wiese** — Architektur, Standards und Governance werden neu definiert
