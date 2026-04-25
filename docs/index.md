---
hide:
  - navigation
---

<div style="text-align: center; margin: 2.5rem 0 1rem 0;">
  <img src="assets/dashi-logo.svg" alt="dashi logo" width="220" style="display:inline-block">
</div>

# dashi

## The *essential base* for spatial data

> A cloud-native spatial data lake — layered, infused, re-usable. Ingests any OGR/GDAL-readable geodata (vector, raster, point cloud), standardises onto a common zone model (Landing → Processed → Curated → Enrichment → Serving), catalogs everything via STAC, and serves it through SQL, COG raster tiles, and OGC API – Tiles vector tiles.
>
> Visible brand: **dashi** — the Japanese broth that forms the base of every layered dish.

!!! info "Status"
    **Maintainers:** Marco Sciaini + Johannes Schlund · **License:** Apache 2.0 · **Substrate:** local k3s + GitHub Actions + Pages

    Use cases: Earth observation, environmental analysis, urban planning, logistics, research — anywhere durable spatial storage with reproducible pipelines is needed.

---

## Reading paths

=== "I'm new — where do I start?"

    1. [Executive summary](01-summary.md) — what and why in one page
    2. [Context & motivation](02-context.md) — the problem this solves
    3. [Logical architecture](07-logical-architecture.md) — the zone model diagram
    4. [Phase-0 roadmap](PHASE-0-ROADMAP.md) — concrete next steps

=== "I'm a Platform Architect"

    - [Technology decisions](08-technology-decisions.md) — ADR overview
    - [ADR catalogue](adrs.md) — one file per decision
    - [Open questions & risks](10-risks-open-questions.md) — what's unresolved
    - [Requirements](05-requirements.md) — F-NN, NF-NN, workload catalog

=== "I'm a Data Owner"

    - [Stakeholders & roles](04-stakeholders.md) — responsibilities
    - [Zone governance](07-logical-architecture.md) — approvals required
    - [Requirements](05-requirements.md) — quality + metadata expectations

=== "I'm onboarding the PoC"

    - [PoC overview](poc/README.md)
    - [k3s setup](poc/docs/k3s-setup.md) — step-by-step local cluster
    - [Phase-0 roadmap](PHASE-0-ROADMAP.md) — the work tracks

=== "I want to contribute"

    - [Contributing guide](https://github.com/marcosci/dashi/blob/main/CONTRIBUTING.md)
    - [Feature ideas backlog](FEATURE-IDEAS.md)
    - [Code of Conduct](https://github.com/marcosci/dashi/blob/main/CODE_OF_CONDUCT.md)

---

## Status dashboard

<div class="grid cards" markdown>

-   **Decided ADRs (7)**

    ---

    ADR-001 Objektspeicher · ADR-002 GeoParquet · ADR-003 COG · ADR-004 COPC · ADR-008 H3 · ADR-010 Prefect · ADR-011 k3s

-   **In discussion (4)**

    ---

    ADR-005 Iceberg vs Delta · ADR-006 technischer Katalog · ADR-007 Verarbeitungs-Engine · ADR-009 Serving-Komponenten

-   **Open backlog**

    ---

    See [FEATURE-IDEAS](FEATURE-IDEAS.md) — CI tooling, LLM metadata extraction, TiPG, MapLibre viewer, OIDC, and more.

-   **License**

    ---

    Apache 2.0 — open source, contributions welcome.

</div>

---

## References

- [ID reference](id-reference.md) — jump to any `F-NN`, `NF-NN`, `W-NN`, `ADR-NNN`, `R-NN`
- [Glossary](GLOSSARY.md) — acronyms and domain terms
- [GitHub repo](https://github.com/marcosci/dashi)

---

<sub>dashi is under active development. Specification chapters are in German (matches the original spec); navigation, code, and contributor docs are in English.</sub>
