# Onboarded domains

Each row is a STAC collection + RustFS prefix + IAM scope. See [`domain-template.md`](domain-template.md) for the full onboarding sequence.

| id | title | owner | retention | access | formats | cadence | volume |
|----|-------|-------|-----------|--------|---------|---------|--------|
| `gelaende-umwelt` | Terrain & environment (PoC reference) | Marco Sciaini | indefinite | internal | vector + raster + pointcloud | one-shot (sample data) | <1 GB |

## Adding a new domain

1. Open a PR adding a row above.
2. Run `cd poc && make rbac-bootstrap` after merge.
3. Follow `domain-template.md` from Step 2.
