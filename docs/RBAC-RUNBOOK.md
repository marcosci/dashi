# RBAC & Secret Rotation Runbook

**Scope:** Phase-2 Strang H — per-zone RustFS identities, Prefect credential injection, NetworkPolicies, and the procedure to rotate any of these without downtime.

## Identity inventory

| RustFS user | Policy | Lives in K8s Secret | Consumer(s) |
|-------------|--------|---------------------|-------------|
| `dashi-ingest` | `landing/*` read+write | `miso-data/dashi-rustfs-ingest` | Future external producers uploading into the landing zone |
| `dashi-pipeline` | `landing/*` RO + `processed/*` + `curated/*` RW | `miso-data/dashi-rustfs-pipeline` | Prefect `miso-ingest` flow-run Jobs (via work-pool base job template `valueFrom`) |
| `dashi-serving-reader` | `processed/*` + `curated/*` RO | `miso-serving/dashi-rustfs-serving` | TiTiler, DuckDB endpoint |
| `rustfs-root` | `consoleAdmin` (everything) | `miso-platform/rustfs-root` | Cluster operator, `rbac-bootstrap.sh`, console login. **Must not be mounted into application pods.** |

Each per-zone Secret contains three keys:

```yaml
data:
  access-key: <user name>
  secret-key: <40-char random>
  endpoint:   http://rustfs.miso-platform.svc.cluster.local:9000
```

## Bootstrap (new cluster / factory reset)

```bash
cd poc
make k3s-up
make storage-deploy        # RustFS + rustfs-root secret
make rbac-bootstrap        # creates 3 per-zone RustFS users + K8s Secrets
make catalog-deploy
make serving-deploy        # deploys TiTiler + DuckDB wired to dashi-rustfs-serving
make prefect-up
make prefect-patch-pool    # work-pool base job template now envFrom dashi-rustfs-pipeline
make monitoring-up
make network-policies-up
```

`rbac-bootstrap` is idempotent — rerunning rotates every per-zone key and re-creates the K8s Secrets in place.

## Rotation — per-zone credential

Applies to `dashi-ingest`, `dashi-pipeline`, `dashi-serving-reader`.

```bash
cd poc
make rbac-bootstrap                             # rotates all three at once; or edit the script for selective rotation

# Restart consumers so they pick up the new Secret
kubectl -n miso-serving rollout restart deployment/titiler deployment/duckdb-endpoint
# Prefect flow runs pick the new Secret automatically on the next pod (valueFrom is resolved at pod admission)
```

Downtime: **zero** for TiTiler / DuckDB (rolling restart). Flow runs in flight at the moment of rotation finish with their old credential.

## Rotation — RustFS root credential

High blast radius — this key can mutate every bucket and every IAM user.

```bash
# 1. Generate new root key and apply it
cd poc
ROOT_NEW=$(openssl rand -base64 40)
kubectl -n miso-platform patch secret rustfs-root \
  --type='json' -p='[{"op":"replace","path":"/data/secret-key","value":"'"$(echo -n "$ROOT_NEW" | base64)"'"}]'

# 2. Re-bootstrap so per-zone users are re-created with the new root key in control
make rbac-bootstrap

# 3. Restart RustFS to pick up the new root (this is a full-downtime step)
kubectl -n miso-platform rollout restart statefulset/rustfs

# 4. Validate
make smoke
```

Downtime: **~30 s** during step 3 (single-replica RustFS). For production, scale to 3+ replicas + erasure coding before rotating root.

## Prefect work-pool template

The base job template is stored in the Prefect DB (not in git). If the DB is lost:

```bash
make prefect-up          # re-creates the DB
make prefect-patch-pool  # re-installs the envFrom.secretKeyRef injection
bash scripts/prefect-register.sh   # re-registers the miso-ingest deployment
```

Inspect the live template:

```bash
export PREFECT_API_URL=http://localhost:4200/api
kubectl -n miso-data port-forward svc/prefect-server 4200:4200 &
ingest/.venv/bin/prefect work-pool inspect miso-default | yq '.base_job_template'
```

## NetworkPolicies

- Applied by `make network-policies-up`, managed via `poc/manifests/network-policies/`
- **Requires a CNI that enforces NetworkPolicies**. k3d / k3s ship Flannel which _does not_ enforce them by default. The manifests are applied for documentation + production-cluster portability but are **not policing traffic in the local PoC cluster**.
- To actually enforce in k3d: recreate cluster with `--k3s-arg "--flannel-backend=none"` and install Calico or Cilium before re-applying everything. Out of PoC scope.

## Audit: who reads what

```bash
# List all RustFS users + their policy
mc admin user list miso-root

# Inspect a single user's policy JSON
mc admin policy info miso-root dashi-pipeline

# Who is bound to a K8s Secret? (workloads that mount it)
for ns in miso-data miso-serving miso-platform; do
  echo "=== $ns ==="
  kubectl -n "$ns" get deploy,statefulset -o json \
    | jq -r '.items[] | {name:.metadata.name, secrets:[.spec.template.spec.containers[].env[]? | select(.valueFrom.secretKeyRef) | .valueFrom.secretKeyRef.name]}' \
    2>/dev/null
done
```

## Open work (Phase 3)

- **Automated rotation** via `external-secrets-operator` or `reloader` so Secret updates auto-restart consumers
- **Workload-identity replacement for static creds** (SPIFFE / IRSA-equivalent) so no long-lived secret lives in K8s
- **CNI-enforced NetworkPolicies** (Cilium L7 rules for path-level control, Hubble flow visibility)
- **Cilium egress gateway** to tag all outbound traffic for firewall pinning in production
