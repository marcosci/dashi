# NetworkPolicies — Strang H2

Namespace-level traffic isolation. Every `dashi-*` namespace starts with a **default-deny** on ingress + egress, then explicit allows open only the edges we actually need.

Policy matrix:

| From ↘ To →           | dashi-platform (RustFS) | dashi-catalog (pgstac + stac-fastapi) | dashi-data (Prefect + flows) | dashi-serving (TiTiler + DuckDB) | dashi-monitoring |
|-----------------------|:----------------------:|:-------------------------------------:|:----------------------------:|:-------------------------------:|:---------------:|
| dashi-platform         | ✓ (self)              |                                       |                              |                                 |                |
| dashi-catalog          |                        | ✓                                     |                              |                                 |                |
| dashi-data             | ✓ (pipeline S3)       | ✓ (STAC POST)                         | ✓                            |                                 |                |
| dashi-serving          | ✓ (read processed/)   |                                       |                              | ✓                               |                |
| dashi-monitoring       | ✓ (scrape /metrics)   | ✓ (scrape)                            | ✓ (scrape)                   | ✓ (scrape)                      | ✓               |
| kube-system (DNS)     | ✓                      | ✓                                     | ✓                            | ✓                               | ✓               |
| Host (port-forward)   | ✓ (allowed in PoC)    | ✓                                     | ✓                            | ✓                               | ✓               |

k3d / k3s runs Flannel without the NetworkPolicy CNI by default. Policies apply iff the cluster has a compatible CNI. For k3d this is opt-in via `--k3s-arg "--flannel-backend=none"` plus a real CNI (Calico/Cilium). Until then, the manifests serve as **documented intent** and a clean target for production clusters.

## Files

| File | Purpose |
|------|---------|
| `default-deny.yaml` | Deny-all ingress + egress per namespace |
| `allow-dns.yaml` | Allow egress to kube-system DNS (TCP/UDP 53) — otherwise every pod breaks |
| `allow-platform.yaml` | Storage clients (`dashi-data` + `dashi-serving`) reach RustFS:9000 |
| `allow-catalog.yaml` | `dashi-data` flows reach stac-fastapi:8080 |
| `allow-data-internal.yaml` | Prefect server ↔ worker ↔ job pods within `dashi-data` |
| `allow-monitoring.yaml` | Prometheus scraper reaches each workload namespace |
| `allow-ingress-port-forward.yaml` | Allow kubectl port-forward (labelled from `kube-system` + host-network) — relaxed for PoC |

## Apply

```bash
cd poc
make network-policies-up
```

Validate after applying:

```bash
make smoke  # should still pass — policies are scoped to allow our known traffic
```

## Production hardening deferred

- **Default-deny on egress** currently skipped for `dashi-data` (Prefect worker needs egress to the Kubernetes API — see `allow-kube-api.yaml`) — tighten with explicit allow to the API endpoint only
- Cilium L7 policies for path-level control (e.g., duckdb-endpoint only allows POST /query, no /admin)
- Pod-to-pod mTLS via service mesh (Linkerd/Istio)
- Log policy denials via Cilium Hubble or Calico flow logs
