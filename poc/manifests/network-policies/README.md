# NetworkPolicies — Strang H2

Namespace-level traffic isolation. Every `miso-*` namespace starts with a **default-deny** on ingress + egress, then explicit allows open only the edges we actually need.

Policy matrix:

| From ↘ To →           | miso-platform (RustFS) | miso-catalog (pgstac + stac-fastapi) | miso-data (Prefect + flows) | miso-serving (TiTiler + DuckDB) | miso-monitoring |
|-----------------------|:----------------------:|:-------------------------------------:|:----------------------------:|:-------------------------------:|:---------------:|
| miso-platform         | ✓ (self)              |                                       |                              |                                 |                |
| miso-catalog          |                        | ✓                                     |                              |                                 |                |
| miso-data             | ✓ (pipeline S3)       | ✓ (STAC POST)                         | ✓                            |                                 |                |
| miso-serving          | ✓ (read processed/)   |                                       |                              | ✓                               |                |
| miso-monitoring       | ✓ (scrape /metrics)   | ✓ (scrape)                            | ✓ (scrape)                   | ✓ (scrape)                      | ✓               |
| kube-system (DNS)     | ✓                      | ✓                                     | ✓                            | ✓                               | ✓               |
| Host (port-forward)   | ✓ (allowed in PoC)    | ✓                                     | ✓                            | ✓                               | ✓               |

k3d / k3s runs Flannel without the NetworkPolicy CNI by default. Policies apply iff the cluster has a compatible CNI. For k3d this is opt-in via `--k3s-arg "--flannel-backend=none"` plus a real CNI (Calico/Cilium). Until then, the manifests serve as **documented intent** and a clean target for production clusters.

## Files

| File | Purpose |
|------|---------|
| `default-deny.yaml` | Deny-all ingress + egress per namespace |
| `allow-dns.yaml` | Allow egress to kube-system DNS (TCP/UDP 53) — otherwise every pod breaks |
| `allow-platform.yaml` | Storage clients (`miso-data` + `miso-serving`) reach RustFS:9000 |
| `allow-catalog.yaml` | `miso-data` flows reach stac-fastapi:8080 |
| `allow-data-internal.yaml` | Prefect server ↔ worker ↔ job pods within `miso-data` |
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

- **Default-deny on egress** currently skipped for `miso-data` (Prefect worker needs egress to the Kubernetes API — see `allow-kube-api.yaml`) — tighten with explicit allow to the API endpoint only
- Cilium L7 policies for path-level control (e.g., duckdb-endpoint only allows POST /query, no /admin)
- Pod-to-pod mTLS via service mesh (Linkerd/Istio)
- Log policy denials via Cilium Hubble or Calico flow logs
