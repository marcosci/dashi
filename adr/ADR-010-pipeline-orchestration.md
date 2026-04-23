# ADR-010 — Pipeline-Orchestrierung

**Status:** ⏳ Offen

**Fälligkeit:** Ende Phase 1

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

**Offen** — Entscheidung abhängig von verfügbarer Infrastruktur und Teamgröße.

**Empfehlung:**
- **Prefect** für kleinere Teams
- **Airflow** wenn bestehende Organisationsinfrastruktur vorhanden ist

**Entscheidung erforderlich bis:** [Datum — Ende Phase 1]

## Konsequenzen (je Entscheidung)

- **Prefect:** modernere DX, weniger Betriebsaufwand, kleineres Ökosystem
- **Airflow:** breiteres Ökosystem, höherer Betriebsaufwand, höhere organisatorische Verankerung
- **Dagster:** beste Observability, aber höchste Einstiegshürde
- **Cron:** nur für PoC tragbar, nicht produktiv
