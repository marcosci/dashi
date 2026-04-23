# ADR-001 — Objektspeicher als Fundament

**Status:** ✅ Entschieden
**Primärwahl:** RustFS (S3-kompatibel, Apache 2.0)
**Letzte Änderung:** 2026-04-23 — konkrete Implementierung von MinIO auf RustFS umgestellt (siehe unten)

## Kontext

Die Plattform muss große Mengen heterogener Geodaten (Raster, Vektor, Punktwolken) kosteneffizient, langlebig und skalierbar speichern. Die Wahl der Speichergrundlage beeinflusst alle anderen Architekturentscheidungen.

Die Kernentscheidung ist zweistufig:

1. **Speicherparadigma** — Objektspeicher vs. relationale DB vs. NAS
2. **Konkrete Implementierung** — welche S3-kompatible Lösung

## Bewertete Alternativen — Paradigma

| Alternative                 | Vorteile | Nachteile |
|-----------------------------|----------|-----------|
| **Objektspeicher (S3-API)** | Unbegrenzt skalierbar, kosteneffizient, cloud-nativ, breite Tool-Unterstützung | Kein nativer Transaktionssupport |
| Relationale Geodatenbank (PostGIS) | Starke Abfragesprache, ACID-Transaktionen | Skalierungsgrenzen bei großen Rasterdaten, hohe Betriebskosten |
| Netzwerklaufwerk / NAS      | Einfache Migration, vertraute Infrastruktur | Keine Skalierbarkeit, kein cloud-natives Ökosystem |

## Bewertete Alternativen — S3-Implementierung

| Alternative | Vorteile | Nachteile | PoC-Fit |
|-------------|----------|-----------|---------|
| **RustFS** | MinIO-API-kompatibel (`mc`, `boto3` unverändert), Apache 2.0, Rust (Memory Safety), Erasure Coding, Single-Binary | Junges Projekt (2024+), kleinere Community | ✅ |
| MinIO | Reife, breite Verbreitung, Tooling-Ökosystem | Community-Edition 2024/2025 ausgedünnt, AGPL + kommerzielle Add-ons, Governance-Turbulenzen, R-15-Risiko bei militärischer Zulassung | ⚠️ |
| Garage | Rust, kleinster Footprint, geo-Replikation nativ | Kein Erasure Coding, AGPL | Möglich |
| SeaweedFS | Skaliert bis PB, stabile Community | 2-Komponenten-Modell (Master + Volume + S3 Gateway), komplexere Ops | Überdimensioniert für PoC |
| Ceph via Rook | Industriestandard on-prem, voll Erasure-coded, RGW S3 | 10+ Pods, steile Lernkurve, >4 GB RAM Idle | Produktionsziel, nicht PoC |

## Entscheidung

**Objektspeicher (S3-API)** als alleiniges Speicherfundament für alle Zonen der Plattform.

**RustFS** als konkrete S3-Implementierung für PoC und Phase 1 — Begründung:

- **Apache 2.0** statt MinIO-AGPL — reduziert R-15 (militärische Zulassungsrisiken, siehe Kapitel 10)
- **Drop-in-MinIO-Kompatibilität** — alle S3-Tools (`mc`, `aws-cli`, `boto3`, STAC, TiTiler, DuckDB `httpfs`) funktionieren unverändert
- **Rust-Memory-Safety** — kleinere Angriffsfläche, relevant für spätere Akkreditierung (NF-11)
- **Erasure Coding** — produktionsreif von Anfang an, Migrationspfad nach Ceph/Rook ist sauber (S3 bleibt S3)
- **Single-Binary** — geringerer Ops-Overhead als SeaweedFS oder Ceph

Migrationspfad nach Ceph/Rook oder RGW bleibt offen, sobald Datenvolumen PB-Bereich erreicht — die S3-API-Abstraktion macht den Wechsel orthogonal zu allen anderen Komponenten.

## Konsequenzen

- Alle Datenformate müssen objektspeicher-kompatibel sein (kein direktes Schreiben in Datenbanken als primärer Speicher)
- Query-Engines müssen direkt auf Objektspeicher operieren können
- **RustFS im PoC als K8s-Deployment**, Manifests unter `poc/manifests/rustfs/`
- **Credentials via K8s Secret**, nicht im Image
- **Lock-Mechanismus auf Landing-Bucket** (F-07 Immutabilität) — via S3 Object Lock, Worm-Modus
- **Beobachtbare Metriken:** RustFS exponiert Prometheus-Format, Einbindung in spätere Monitoring-Stack-Entscheidung (NF-16)
- **Migration MinIO → RustFS:** keine Laufzeit-Migration nötig (Greenfield), aber Dokumentation sollte Ursprungsentscheidung nachvollziehbar machen

## Verworfene Alternativen — Begründung

- **MinIO:** Community-Edition-Erosion + License-Turbulenzen überwiegen Reife-Vorteil. RustFS nimmt API-Kompatibilität mit, schneidet Rechts-/Compliance-Risiken ab.
- **Garage:** Fehlendes Erasure Coding zwingt späte Umstellung — nicht akzeptabel wenn PoC zu Produktivbetrieb wächst.
- **SeaweedFS:** Skaliert besser, aber Ops-Komplexität nicht gerechtfertigt für PoC-Volumen (~1 GB).
- **Ceph via Rook:** Richtige Wahl für produktive On-Prem-Infrastruktur, aber für PoC Overhead nicht tragbar. Bleibt als Zielumgebung auf dem Radar.
