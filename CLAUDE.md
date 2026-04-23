# Agent Instructions — CldGIS Geodatalake

Working instructions for Claude Code agents contributing to this planning/architecture repo.

## Mission

This repo is the **living architecture specification** for a military-grade cloud-native spatial data lake. It is primarily a documentation project at this stage — no application code yet. Phase 1 (Proof of Concept) will add a PoC implementation.

## Language Conventions

- **Specification content** (chapters, ADRs, requirements, risks) — keep in **German**. The original spec is in German and this is the source of truth. Translating degrades fidelity with stakeholders.
- **Meta / navigation / agent instructions / commit messages / code** — **English**.
- **Technical terms** — use them exactly as written in original (e.g. `Zonenmodell`, `KRS`, `Curated Zone`). Do not anglicize.

## Document Hierarchy

```
README.md                    → repo map, quick nav
CLAUDE.md (this file)        → agent rules
docs/NN-*.md                 → one chapter per file, mirrors original PDF structure
docs/INDEX.md                → ID lookup (F-NN / NF-NN / W-NN / ADR-NNN / R-NN)
docs/GLOSSARY.md             → acronyms + domain terms
adr/ADR-NNN-*.md             → one Architecture Decision Record per file
source/                      → archived original PDF (read-only, historical)
templates/                   → copy these when adding new ADRs / requirements / risks
agents/                      → per-task briefs for specific agents
```

When asked to edit "chapter 7" or "ADR-03", go straight to the numbered file.

## Editing Rules

1. **Preserve IDs.** `F-01`, `NF-01`, `W-01`, `ADR-01`, `R-01`, `F-01` (question) — never renumber. Append new IDs to the end of the list.
2. **ADR status must match.** Each ADR has a status badge: ✅ Entschieden · 🔄 In Diskussion · ⏳ Offen. Update the status field, the ADR file, and `docs/08-technology-decisions.md` overview table in the same change.
3. **Phase gates are binding.** Do not move a requirement, ADR, or risk into an earlier phase without adding a note explaining the re-scoping rationale.
4. **Placeholders.** Bracketed placeholders like `[Name]`, `[Datum]`, `[X %]`, `[X] TB/Jahr` must stay until a stakeholder fills them. Do not invent values.
5. **Open questions are first-class.** When closing a question in `docs/10-risks-open-questions.md`, change its status dot to 🟢 and add the resolution date + resolver. Do not delete.

## When Adding Content

- **New requirement** → copy `templates/requirement.md`, assign next free `F-NN` or `NF-NN`, update chapter 5 table.
- **New ADR** → copy `templates/adr.md`, assign next free `ADR-NNN`, add row to ADR overview in `docs/08-technology-decisions.md`.
- **New risk** → copy `templates/risk.md`, assign next free `R-NN`, add to risk register in `docs/10-risks-open-questions.md`.

## Review Checklist Before Committing

- [ ] All IDs unique and sequential
- [ ] ADR status badge consistent across all four surfaces (ADR file, chapter 8 overview, README, `docs/INDEX.md`)
- [ ] New requirements/ADRs/risks are also listed in `docs/INDEX.md`
- [ ] Open questions have a `Verantwortlich` and `Benötigt bis`
- [ ] No placeholders silently resolved
- [ ] Table column count matches header everywhere
- [ ] Cross-references use relative markdown links
- [ ] New acronyms used in prose are defined in `docs/GLOSSARY.md`
- [ ] Diagram updates keep the Mermaid block AND the ASCII fallback in sync

## Domains (use these exact names)

- Aufklärung & ISR
- Missionsplanung & C2
- Logistik & Versorgung
- Gelände & Umwelt

## Zones (use these exact names)

Landing → Processed → Curated → Enrichment → Serving

## Out of Scope (hard limits — do not design into these)

- Real-time/tactical fire-control latencies (ms range)
- Replacement of existing FüInfoSys
- Map visualization / GIS clients / dashboards
- Quality of raw source data (producers own that)
- Migration of historical archives in Phase 1 and 2
- Classification levels above the accredited tier (scope: separate initiative)

## What NOT to do

- Don't invent technology choices for open ADRs (ADR-05, ADR-07, ADR-09 [partial], ADR-10). Mark them ⏳ and describe the decision criteria, don't pick.
- Don't add code, Dockerfiles, or infra-as-code yet. PoC implementation starts at Phase 1 Gate 1 approval.
- Don't translate chapter content to English.
- Don't combine files "for cleanliness". The one-chapter-per-file / one-ADR-per-file layout is load-bearing for diff readability.
