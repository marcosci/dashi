<p align="center">
  <img src="docs/assets/dashi-logo.svg" alt="dashi" width="180">
</p>

<h1 align="center">dashi</h1>

<p align="center"><strong>The essential base for spatial data.</strong></p>

<p align="center">
  <a href="https://github.com/marcosci/dashi/actions/workflows/ci.yml"><img alt="ci" src="https://github.com/marcosci/dashi/actions/workflows/ci.yml/badge.svg"></a>
  <a href="https://github.com/marcosci/dashi/actions/workflows/docs.yml"><img alt="docs" src="https://github.com/marcosci/dashi/actions/workflows/docs.yml/badge.svg"></a>
  <a href="https://marcosci.github.io/dashi/"><img alt="site" src="https://img.shields.io/badge/site-marcosci.github.io%2Fdashi-c8821f"></a>
  <a href="LICENSE"><img alt="license" src="https://img.shields.io/badge/license-Apache--2.0-blue"></a>
  <a href="CONTRIBUTING.md"><img alt="contributions welcome" src="https://img.shields.io/badge/contributions-welcome-3d5a3a"></a>
  <a href="https://github.com/marcosci/dashi/discussions"><img alt="discussions" src="https://img.shields.io/badge/discussions-open-3d5a3a"></a>
</p>

> A cloud-native spatial data lake — layered, infused, re-usable. Ingests any OGR/GDAL-readable geodata (vector, raster, point cloud), standardises onto a common zone model (Landing → Processed → Curated → Enrichment → Serving), catalogs everything via STAC, and serves it through SQL, COG raster tiles, and OGC API — Tiles vector tiles. Use cases: Earth observation, environmental analysis, urban planning, logistics, research — anywhere durable spatial storage with reproducible pipelines is needed.

## Status

- **Phase:** Phase 2 — production hardening in progress
- **Maintainers:** Marco Sciaini + Johannes Schlund
- **License:** Apache 2.0 — see [LICENSE](LICENSE)
- **Phase-0 PoC:** ✅ Gate-1 passed
- **PoC focus domain:** terrain & environment (sample data: GeoTIFF / Shapefile / GPKG / LAZ)

## About the name

_Dashi_ is the Japanese foundational broth that sits under every layered dish: kombu, bonito, water. Unseen but essential. The platform takes its name from that idea — it's the base that every downstream map, analysis, and decision is built on. Built in the open as an Apache-2.0 reference implementation.

## Quick start

### Browse the docs

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements-docs.txt
mkdocs serve                      # http://localhost:8000
```

### Run the PoC locally

Requires Docker + k3d + kubectl on your PATH.

```bash
cd poc
make k3s-up                       # local k3d cluster named "dashi"
make storage-deploy               # RustFS + landing/processed/curated buckets
make catalog-deploy               # pgstac + stac-fastapi
make rbac-bootstrap               # per-zone scoped IAM
make serving-deploy               # TiTiler (raster tiles) + DuckDB SQL endpoint
make prefect-up                   # Prefect 3 server + worker
make monitoring-up                # Prometheus + Grafana + kube-state-metrics
make network-policies-up          # default-deny + scoped allow NetworkPolicies
make ogc-deploy                   # Martin (vector tiles) + PostGIS + PMTiles regen
make smoke                        # end-to-end acceptance checks
```

Full target list: `make help`. See [poc/docs/k3s-setup.md](poc/docs/k3s-setup.md) for prerequisites and troubleshooting.

## Architecture

```
                       ┌─────────────────────────────────────────────┐
   GeoTIFF, Shapefile, │  Landing → Processed → Curated → Enrichment │
   GPKG, KML, LAZ, …   │           (zone model, RustFS)              │
            │          └────────────┬────────────────────────────────┘
            ▼                       │
        Prefect flow                ▼
       (dashi-ingest)         pgstac (STAC catalog)
            │                       │
            └─────────┬─────────────┘
                      ▼
        Serving:  TiTiler · DuckDB · Martin (OGC API – Tiles)
```

Standardised formats: **COG** (raster), **GeoParquet** (vector), **COPC** (point cloud), **PMTiles** (tile bundles). Spatial partitioning via **H3**. Single processing engine via **DuckDB + GDAL/PDAL**.

## Repository layout

```
dashi/
├── README.md                      # This file
├── CONTRIBUTING.md                # How to contribute
├── CODE_OF_CONDUCT.md             # Community standards
├── LICENSE                        # Apache 2.0
├── CLAUDE.md                      # Agent / AI working instructions
├── mkdocs.yml                     # MkDocs Material site config
├── docs/                          # Architecture spec + site root
│   ├── index.md                   # Public homepage
│   ├── 01-summary.md … 10-risks-open-questions.md
│   ├── FEATURE-IDEAS.md           # Backlog for new ideas
│   └── assets/                    # Logo, favicon, brand tokens
├── adr/                           # Architecture Decision Records
├── poc/                           # PoC — k3s manifests + ingest + flows
│   ├── ingest/                    # dashi-ingest (Python, format-agnostic)
│   ├── manifests/                 # K8s manifests per component
│   ├── flows/                     # Prefect flows
│   └── smoke/                     # End-to-end acceptance checks
├── agents/                        # Task briefs for AI agents
└── templates/                     # Doc templates (ADR, requirement, risk)
```

## Documentation map

| Chapter | Topic |
|---------|-------|
| [01](docs/01-summary.md) | Zusammenfassung — executive summary |
| [02](docs/02-context.md) | Kontext & Motivation |
| [03](docs/03-goals.md) | Ziele & Nicht-Ziele |
| [04](docs/04-stakeholders.md) | Stakeholder & Rollen (RACI) |
| [05](docs/05-requirements.md) | Funktionale + nicht-funktionale Anforderungen |
| [06](docs/06-baseline.md) | Ist-Zustand (Greenfield) |
| [07](docs/07-logical-architecture.md) | Zonenmodell |
| [08](docs/08-technology-decisions.md) | ADR-Übersicht |
| [09](docs/09-phases.md) | Phasenplan |
| [10](docs/10-risks-open-questions.md) | Offene Fragen & Risikoregister |
| [Phase-0-Roadmap](docs/PHASE-0-ROADMAP.md) · [Phase-2-Roadmap](docs/PHASE-2-ROADMAP.md) | Active work tracks |
| [FEATURE-IDEAS](docs/FEATURE-IDEAS.md) | Backlog of future ideas |
| [Glossary](docs/GLOSSARY.md) · [ID reference](docs/id-reference.md) | Lookups |

## Contributing

Contributions are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md) for the workflow, code style, and how to file issues. By participating you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).

Quick paths:
- **Bug?** Open a [bug report](https://github.com/marcosci/dashi/issues/new?template=bug_report.md).
- **Idea?** Append to [docs/FEATURE-IDEAS.md](docs/FEATURE-IDEAS.md) or open a [feature request](https://github.com/marcosci/dashi/issues/new?template=feature_request.md).
- **Question?** Use GitHub Discussions or open an issue with the `question` label.

## Working language

The architecture chapters preserve the original spec language (German). Public-facing surfaces — README, code, commit messages, agent instructions — are English. New docs may be written in either.

## License

Apache License 2.0 — see [LICENSE](LICENSE). Copyright © 2026 the dashi contributors.
