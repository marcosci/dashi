# ADR-010 — Pipeline-Orchestrierung: Prefect

**Status:** ✅ Entschieden (PoC / Phase 1)

**Beschlossen:** 2026-04-23

## Kontext

Datenpipelines müssen zuverlässig geplant, überwacht, bei Fehlern neu gestartet und in ihren Abhängigkeiten verwaltet werden.

## Bewertete Alternativen

| Alternative      | Vorteile | Nachteile |
|------------------|----------|-----------|
| Apache Airflow   | Mächtig, weit verbreitet, DAG-basiert | Komplex im Betrieb |
| **Prefect**      | Modern, Python-nativ, einfacher Einstieg | Jünger als Airflow |
| Dagster          | Asset-orientiert, starke Observability | Steile Lernkurve |
| Cron + Skripte   | Einfach, keine Abhängigkeiten | Kein Monitoring, keine Abhängigkeitsverwaltung |

## Entscheidung

**Prefect** für PoC und Phase 1. Python-nativ, niedriger Einstieg, kein JVM-Stack nötig. Passt zum 1-Personen-PoC-Team unter [ADR-011](ADR-011-infra-substrate.md).

Re-Evaluierung mit Phase-2-Übergang an ein produktives Betriebsteam — falls bestehende Airflow-Infrastruktur in der Zielorganisation verfügbar wird, ist ein Wechsel dann vertretbar (Flows sind relativ portierbar).

## Konsequenzen

- Flows werden als Python-Module unter `poc/flows/` versioniert
- Prefect-Server läuft als k3s-Deployment im Namespace `miso-data` (siehe [k3s setup](../poc/docs/k3s-setup.md))
- Worker nutzen denselben Cluster — keine Remote-Runner im PoC
- Blob-Storage-Zugriff über `boto3` gegen MinIO, Credentials via K8s Secret
- Alerts initial nur via Prefect-UI; Monitoring-Dashboard-Anbindung (NF-16) in Phase 2

## Verworfene Alternativen

- **Airflow:** höherer Betriebsaufwand, Python-Code-Struktur zwang-DAG-förmig — ohne Legacy-Investment im Team nicht zu rechtfertigen
- **Dagster:** beste Observability und Asset-Modell, aber steile Lernkurve für PoC-Scope zu teuer
- **Cron + Skripte:** keine Abhängigkeitsverwaltung, kein Retry — reicht nicht einmal für Gate-1
