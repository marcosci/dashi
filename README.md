# CldGIS Geodatalake

Architecture, planning, and delivery workspace for the **CldGIS Spatial Data Lake** — a cloud-native geospatial data platform consolidating reconnaissance (ISR), mission planning (C2), logistics, and terrain/environment data under a common zone-based architecture.

> Living document. Source of truth for architectural decisions, phase scope, open questions, and risks. Updated continuously as requirements are refined.

## Status

- **Phase:** Pre-Phase 1 (documentation and stakeholder alignment)
- **Target:** Operational readiness within 18 months (3 phases)
- **Domains:** Aufklärung & ISR · Missionsplanung & C2 · Logistik & Versorgung · Gelände & Umwelt

## Repository Layout

```
cldgis-geodatalake/
├── README.md                      # This file
├── CLAUDE.md                      # Agent working instructions
├── docs/                          # Chapter-by-chapter architecture doc
│   ├── INDEX.md                   # Every F-NN / NF-NN / W-NN / ADR / R-NN lookup
│   ├── GLOSSARY.md                # Acronyms + domain terms
│   ├── 01-summary.md
│   ├── 02-context.md
│   ├── 03-goals.md
│   ├── 04-stakeholders.md
│   ├── 05-requirements.md
│   ├── 06-baseline.md
│   ├── 07-logical-architecture.md
│   ├── 08-technology-decisions.md
│   ├── 09-phases.md
│   └── 10-risks-open-questions.md
├── source/                        # Archived original PDF for traceability
├── adr/                           # Architecture Decision Records (per-decision)
│   ├── ADR-001-object-storage.md
│   ├── ADR-002-vector-format-geoparquet.md
│   ├── ADR-003-raster-format-cog.md
│   ├── ADR-004-pointcloud-copc.md
│   ├── ADR-005-table-format.md
│   ├── ADR-006-data-catalog.md
│   ├── ADR-007-processing-engine.md
│   ├── ADR-008-spatial-partitioning-h3.md
│   ├── ADR-009-serving-layer.md
│   └── ADR-010-pipeline-orchestration.md
├── agents/                        # Agent-specific task briefs
└── templates/                     # Doc templates (ADR, requirement, risk)
```

## Quick Navigation

| Chapter | Topic |
|---------|-------|
| [01](docs/01-summary.md) | Zusammenfassung — executive summary |
| [02](docs/02-context.md) | Kontext & Motivation |
| [03](docs/03-goals.md) | Ziele & Nicht-Ziele |
| [04](docs/04-stakeholders.md) | Stakeholder & Rollen (RACI) |
| [05](docs/05-requirements.md) | Funktionale + nicht-funktionale Anforderungen |
| [06](docs/06-baseline.md) | Ist-Zustand (Greenfield) |
| [07](docs/07-logical-architecture.md) | Zonenmodell (Landing → Processed → Curated → Enrichment → Serving) |
| [08](docs/08-technology-decisions.md) | ADR-Übersicht |
| [09](docs/09-phases.md) | PoC → MVP → Vollbetrieb (18 Monate) |
| [10](docs/10-risks-open-questions.md) | Offene Fragen & Risikoregister |
| [INDEX](docs/INDEX.md) | Lookup aller IDs (F/NF/W/ADR/R) |
| [GLOSSARY](docs/GLOSSARY.md) | Abkürzungen + Fachbegriffe |

## Working Language

- Architecture content: **German** (source of truth preserved from original spec)
- Agent instructions, commit messages, code: **English**
