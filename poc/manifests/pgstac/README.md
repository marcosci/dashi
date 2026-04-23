# Catalog — pgstac + stac-fastapi

Spatial-temporal catalog (Strang D in [PHASE-0-ROADMAP](../../../docs/PHASE-0-ROADMAP.md)). Backs F-12, F-13, F-14, F-15. See [ADR-006](../../../adr/ADR-006-data-catalog.md) for the decision.

## Components

| File | Purpose |
|------|---------|
| `namespace.yaml` | `miso-catalog` namespace |
| `secret.yaml` | Postgres credentials (template — replace before apply) |
| `statefulset-postgres.yaml` | Postgres + PostGIS + pgstac (image `ghcr.io/stac-utils/pgstac:v0.9.5`), 5Gi PVC |
| `service-postgres.yaml` | ClusterIP `pgstac:5432` + headless |
| `job-migrate.yaml` | One-shot `pypgstac migrate` — installs pgstac schema once pg is up |
| `deployment-stac-api.yaml` | `ghcr.io/stac-utils/stac-fastapi-pgstac:5.0.2`, reads/writes pgstac via env |
| `service-stac-api.yaml` | ClusterIP `stac-fastapi:8080` |
| `kustomization.yaml` | Apply with `kubectl apply -k .` |

## Apply

Preferred: `make catalog-deploy` from `poc/` — rotates the placeholder password automatically.

Manual:

```bash
cd poc/manifests/pgstac
export PGSTAC_PW=$(openssl rand -base64 32)
sed -i.bak "s|CHANGE_ME_PG_PASSWORD|${PGSTAC_PW}|" secret.yaml
kubectl apply -k .
# restore template after apply:
mv secret.yaml.bak secret.yaml
```

Wait for readiness:

```bash
kubectl -n miso-catalog rollout status statefulset/pgstac --timeout=180s
kubectl -n miso-catalog wait --for=condition=complete job/pgstac-migrate --timeout=120s
kubectl -n miso-catalog rollout status deployment/stac-fastapi --timeout=120s
```

## Smoke test

```bash
kubectl -n miso-catalog port-forward svc/stac-fastapi 8080:8080 &
curl -s http://localhost:8080/_mgmt/ping
curl -s http://localhost:8080/ | jq '.title, .type'
curl -s 'http://localhost:8080/collections' | jq '.collections | length'
```

Expect: `{"message":"PONG"}`, title `"stac-fastapi-pgstac"`, empty collections list initially.

## Production hardening deferred

- Read-only Postgres replica (`POSTGRES_HOST_READER`) for scale-out (Phase 2)
- TLS at Ingress (Phase 2)
- Connection pooling via PgBouncer (Phase 2)
- Backup + PITR (Phase 2 per R-10)
- `USE_API_HYDRATE=true` with a hydration role (perf tuning, Phase 1 end)
