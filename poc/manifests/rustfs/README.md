# RustFS Deployment

S3-compatible object storage for the dashi PoC. Primary backend for all zones (`landing`, `processed`, `curated`). See [ADR-001](../../../adr/ADR-001-object-storage.md) for the decision and its rationale.

## Components

| File | Purpose |
|------|---------|
| `namespace.yaml` | `dashi-platform` namespace |
| `secret.yaml` | Root credentials (template — replace before apply) |
| `statefulset.yaml` | RustFS server, single replica for PoC, persistent volume |
| `service.yaml` | ClusterIP `rustfs` port 9000 (S3 API) + 9001 (console) |
| `job-buckets.yaml` | One-shot Job that creates `landing` / `processed` / `curated` buckets via `mc` once RustFS is Ready |
| `kustomization.yaml` | Apply with `kubectl apply -k .` |

## Apply

```bash
cd poc/manifests/rustfs
# Generate a strong root secret and replace the template
export RUSTFS_ROOT_PASSWORD=$(openssl rand -base64 32)
sed -i.bak "s|CHANGE_ME_ROOT_PASSWORD|${RUSTFS_ROOT_PASSWORD}|" secret.yaml
kubectl apply -k .
```

Verify:

```bash
kubectl -n dashi-platform get pods -w
kubectl -n dashi-platform logs job/rustfs-create-buckets
```

Port-forward for local access:

```bash
kubectl -n dashi-platform port-forward svc/rustfs 9000:9000 9001:9001
# mc alias set dashi-local http://localhost:9000 rustfs-admin "${RUSTFS_ROOT_PASSWORD}"
# mc ls dashi-local
```

## Production hardening deferred

- Multi-replica erasure-coded StatefulSet (R-10 backup resilience)
- Object Lock on `landing` bucket (F-07 immutability — flagged for Phase 1 end)
- TLS / cert-manager integration
- Separate read-only IAM policies per namespace (F-23)
- Prometheus ServiceMonitor (NF-16)
