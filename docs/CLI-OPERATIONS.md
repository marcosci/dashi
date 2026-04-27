# `dashictl` Operations Runbook

Day-2 operator workflows for the dashi spatial data lake, driven from
the `dashictl` CLI. Three-layer ops model:

- **`dashictl`** — operator CRUD, garbage collection, audit, backup,
  backfill. Source of truth for mutating the data lake.
- **Grafana** — read-only dashboards (throughput, errors, queue
  depth, sizes).
- **Web UI** — researcher front door (ingest, browse, runs, viewer).
  Never grows admin scope. If a workflow needs a button, add a
  `dashictl` subcommand instead.

All `dashictl` commands respect:

- `--context <name>` — switches between `[contexts.<name>]` blocks in
  `~/.config/dashi/config.toml`. Default: `default` or `$DASHI_CONTEXT`.
- `--json` — emits machine-readable output for `jq` / scripts.
- Audit trail — destructive commands print an `[audit]` line to stderr
  before performing the cascade so log shippers (Loki) capture the
  intent even if the process is killed mid-cascade.

---

## 1. Preflight check

Run on every fresh cluster bringup, every CI smoke, every
post-deploy verification.

```sh
dashictl doctor
```

Verifies STAC reachable, has at least one collection, Prefect
reachable, `dashi-ingest/main` deployment registered, Loki reachable,
S3 buckets present, ingest-api reachable. Exits non-zero on any hard
failure. Loki + ingest-api are warnings (optional components).

If `dashi-ingest/main` is missing:

```sh
make -C poc prefect-bootstrap
```

If S3 buckets are missing:

```sh
make -C poc storage-deploy
```

---

## 2. Domain (= STAC collection) management

```sh
dashictl domain list                         # tabular
dashictl domain show gelaende-umwelt         # full STAC JSON
dashictl --json domain list | jq '.[].id'    # machine-readable

dashictl domain create klima-historisch \
  --title "Klima – historisch" \
  --description "Historic climate reconstructions." \
  --max-classification pub \
  --retention indefinite
```

Idempotent — re-running `create` upserts. Pre-seeded demo domains:

```sh
bash poc/scripts/seed-sample-domains.sh
```

---

## 3. Ingest

Same `presign → PUT → scan → trigger` pipeline the web UI uses. CLI is
a thin orchestrator over `ingest-api`.

```sh
dashictl ingest /path/to/data.tif --domain gelaende-umwelt
dashictl ingest s3://landing/preexisting.geojson --domain gelaende-umwelt
dashictl ingest /path/to/big.laz --domain gelaende-umwelt --dry-run
```

Files ≥ 500 MiB auto-switch to multipart; cap is 50 GiB.

---

## 4. Item delete (cascade)

Dry-run by default. Always reads first, then prompts for the item id
to confirm, then cascades S3 → STAC → (manual) Iceberg.

```sh
# Preview
dashictl item delete gelaende-umwelt/abc123

# Apply with explicit confirmation
dashictl item delete gelaende-umwelt/abc123 --apply

# CI / scripted (skips the confirmation prompt)
DASHICTL_YES=1 dashictl item delete gelaende-umwelt/abc123 --apply
```

Order is deliberate: S3 assets first (orphans cost only storage, GC
sweepable), STAC record second (invisible from APIs after this), and
Iceberg partitions surfaced as a manual TODO until the
Postgres-backed catalogue lands (Phase 3).

---

## 5. Garbage collection

Identifies S3 objects that are not referenced by any STAC item and
older than `--min-age-hours` (default 1, override
`DASHICTL_GC_MIN_AGE_HOURS=N`). Default mode is read-only listing.

```sh
# Preview orphans (any bucket — landing / processed / curated)
dashictl gc --bucket landing
dashictl gc --bucket processed

# Apply with explicit bucket-name confirmation
dashictl gc --bucket landing --apply

# CI mode
DASHICTL_YES=1 dashictl gc --bucket landing --apply
```

The min-age cutoff prevents racing in-flight ingests whose STAC item
hasn't landed yet. Tighten only when you know there are no concurrent
writers.

---

## 6. Backup verify + restore-test

`backup verify` is a freshness check. `backup restore-test` proves
the newest dump can actually be restored end-to-end.

```sh
# Listing only
dashictl backup verify

# Full proof: spin ephemeral Postgres, restore newest pgstac dump,
# run sanity SELECTs, tear down. Requires kubectl + RBAC to create
# Jobs in dashi-backup.
dashictl backup restore-test

# Pin to a specific dump (post-mortem)
dashictl backup restore-test --key pgstac/20260427T020000Z.dump

# Leave the ephemeral Postgres + Job in-cluster for manual debugging
# when the restore fails
dashictl backup restore-test --leave-on-fail
```

Schedule a `backup restore-test` weekly via Prefect or GitHub Actions
to keep the proven-restorable property continuous.

---

## 7. Audit log tail

Wraps Loki LogQL queries.

```sh
dashictl audit tail --limit 50              # one-shot
dashictl audit tail --follow                # stream
dashictl audit tail --query '{namespace="dashi-web"}'
dashictl --json audit tail --follow | jq .  # structured
```

---

## 8. Prefect flow runs

```sh
dashictl runs --limit 20
dashictl runs --domain gelaende-umwelt
dashictl --json runs --limit 5 | jq '.[] | {id, name, state}'
```

---

## 9. Configuration

```sh
dashictl config           # human-readable resolved config
dashictl --json config    # JSON

# Per-context overrides
dashictl --context prod domain list
DASHI_CONTEXT=prod dashictl runs
```

Lookup precedence (lowest → highest): compiled defaults →
`~/.config/dashi/config.toml` → `[contexts.<name>]` block → `DASHI_*`
env vars → CLI flags. Secrets in the resolved view are masked (e.g.
`rust…`) by default; only the first 4 chars are shown.

---

## Stub / blocked commands

| Command | Status | Blocked on |
|---|---|---|
| `user grant` | stub | Authelia + Keycloak live (Phase 3) |
| `backfill` | stub | `as_of` parameter convention ADR (Phase 3) |
| `item delete` Iceberg cascade | manual | Postgres-backed Iceberg catalogue (Phase 3) |

Full status table in [`poc/dashictl/README.md`](../poc/dashictl/README.md#subcommands).
