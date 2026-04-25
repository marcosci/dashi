# Data classification & access scope

Closes open question **F-01** (Datenklassifizierung + Zonentrennung). Defines the classification scheme dashi enforces on every STAC item, the runtime checks, and how access is scoped to it.

## The four levels

| Level | Code | Meaning | Examples |
|-------|------|---------|----------|
| **Public** | `pub` | Open data — no access restriction. Internet-publishable. | OSM, Sentinel-2, public DTM |
| **Internal** | `int` | Operational data; access limited to the operating organisation. | In-house terrain models, internal route plans |
| **Restricted** | `rst` | Sensitive — access on a need-to-know basis, audit-logged. | Asset locations, infrastructure surveys |
| **Confidential** | `cnf` | Highly sensitive — explicit per-user grant + 2FA + watermarking. | Personal data, contractual data with NDA |

The four levels mirror the German **TLP (Traffic Light Protocol)** scheme (white / green / amber / red) without using TLP literally — TLP is an information-sharing protocol, not a data-classification one. Codes are 3-char ASCII so they fit STAC properties + path segments without escaping.

## Where the level lives

Every STAC item carries:

```json
{
  "properties": {
    "dashi:classification": "int",
    "dashi:access_groups": ["dashi", "team-terrain"],
    "dashi:retention": "1y",
    "dashi:source_kind": "vector",
    ...
  }
}
```

`dashi:classification` is mandatory. `dashi:access_groups` lists the OIDC groups (Authelia / IdP) that may read the asset; ignored when classification is `pub`.

## Where it is enforced

| Layer | Enforcement |
|-------|-------------|
| **Ingest** | `dashi-ingest --classification <pub\|int\|rst\|cnf>` flag (CLI + flow parameter). Default per domain set in `docs/onboarding/domains.md`. Item rejected if higher than the domain ceiling. |
| **STAC catalog** | Validator runs on every PUT/POST: missing `dashi:classification` → 400. |
| **Object storage** | Per-zone IAM is the **floor**. Each classification adds a path-prefix policy: `rst` and `cnf` items go under `s3://processed/<domain>/<rst\|cnf>/...` with separate read users. |
| **Serving** | TiTiler / Martin / TiPG / DuckDB endpoints sit behind oauth2-proxy (see `poc/manifests/auth/`); the proxy injects `X-Forwarded-User` + `X-Forwarded-Groups` headers, the upstream filters STAC results by group membership. |
| **Backups** | `cnf` dumps additionally pass through age-encryption with a per-cluster public key before being mirrored off-cluster. |
| **Audit** | `dashi:classification ∈ {rst, cnf}` STAC reads emit a Loki line via the serving sidecars; query `{namespace="dashi-serving",classification=~"rst|cnf"}` for the audit trail. |

## Domain-default ceiling

`docs/onboarding/domains.md` gains a `max_classification` column. Items exceeding the domain's ceiling are rejected at ingest. Example:

```markdown
| id | title | owner | retention | access | max_classification | …
| gelaende-umwelt | Terrain & environment | Marco | indefinite | internal | int | …
| weather-radar   | DWD radolan           | …     | 90d         | public   | pub | …
| asset-locations | Internal asset survey | …     | 1y          | restricted | rst | …
```

## Classification scheme is documented; runtime enforcement TBD

This document defines **what** the four levels mean and **where** they should be enforced. The actual code paths are scaffolded:

- [x] STAC item supports `dashi:classification` (free-form properties bag)
- [ ] `dashi-ingest` `--classification` flag (open in FEATURE-IDEAS)
- [ ] STAC validator hook (open: needs pgstac transaction-time validator)
- [ ] Per-classification IAM policy + bucket prefixes (open)
- [ ] oauth2-proxy header → group filter on serving endpoints (open)
- [ ] `cnf` age-encrypted backup mirror (open)

Tracking: every checkbox above is a Phase-2-K follow-up. Until those land, dashi treats every item as `int` by default — the classification is _declared_ via `dashi:classification`, not _enforced_.

## Disposal

When an item's retention expires (per `domain-template.md` step 7) and its classification is `rst` or `cnf`:

1. Object overwrite + DELETE on RustFS (versioning: tombstone versions also pruned)
2. STAC item DELETE
3. Loki audit line: `dashi.dispose item=<id> classification=<lvl> reason=retention`
4. Off-cluster backup mirror: corresponding object pruned
