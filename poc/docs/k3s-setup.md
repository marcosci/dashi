# k3s Setup — Local MISO PoC Cluster

Step-by-step setup for a local Kubernetes cluster running k3s (or k3s-in-Docker). Tested on macOS 14+, Ubuntu 22.04+, Windows 11 (WSL2).

> **Why k3s?** Full Kubernetes API, production-like, lightweight. Manifests written for the PoC will transfer to any k3s/K8s target without rewrites. See [ADR-011](../../adr/ADR-011-infra-substrate.md).

---

## 0. Prerequisites

| Tool | Purpose | macOS | Linux | Windows |
|------|---------|-------|-------|---------|
| Docker | Container runtime (macOS/Windows only) | `brew install --cask docker` or [OrbStack](https://orbstack.dev) | — | Docker Desktop |
| k3d | k3s-in-Docker wrapper (macOS/Windows only) | `brew install k3d` | — | `choco install k3d` |
| kubectl | Kubernetes CLI | `brew install kubectl` | package manager | `choco install kubernetes-cli` |
| helm | Package manager (used for MinIO etc.) | `brew install helm` | [script](https://helm.sh/docs/intro/install/) | `choco install kubernetes-helm` |
| make | Task runner | preinstalled | preinstalled | WSL2 or Git-Bash |

Verify:

```bash
docker --version       # only macOS/Windows
k3d version            # only macOS/Windows
kubectl version --client
helm version
```

---

## 1. Start the cluster

From the repo root:

```bash
cd poc
make k3s-up
```

What this does:

- **macOS / Windows:** creates a k3d cluster named `miso` with 1 server + 2 agents. Ports `8080→80` and `8443→443` are published on the host. Built-in Traefik is disabled (we control ingress ourselves).
- **Linux:** installs k3s natively via the upstream installer, then copies kubeconfig to `~/.kube/config` with correct permissions.

Expected output tail:

```
NAME                       STATUS   ROLES                  AGE   VERSION
k3d-miso-server-0          Ready    control-plane,master   1m    v1.28.x+k3s1
k3d-miso-agent-0           Ready    <none>                 55s   v1.28.x+k3s1
k3d-miso-agent-1           Ready    <none>                 55s   v1.28.x+k3s1

✓ Cluster 'miso' ready.
```

---

## 2. Sanity-check

```bash
kubectl get nodes
kubectl get pods -A
kubectl config current-context    # should be k3d-miso or default
```

If `kubectl` cannot find the cluster, inspect `~/.kube/config`. On Linux, the k3s installer writes to `/etc/rancher/k3s/k3s.yaml` — the setup script copies it to `~/.kube/config`. On macOS/Windows, k3d writes directly.

---

## 3. Namespaces

```bash
kubectl create namespace miso-platform
kubectl create namespace miso-catalog
kubectl create namespace miso-serving
kubectl create namespace miso-data
```

Convention:

| Namespace | Contents |
|-----------|----------|
| `miso-platform` | MinIO, monitoring, shared platform services |
| `miso-catalog` | stac-fastapi + its PostgreSQL backend |
| `miso-serving` | TiTiler, DuckDB-query endpoint |
| `miso-data` | Prefect server + workers, pipeline-scoped secrets |

---

## 4. Next: deploy the platform

```bash
make minio-deploy       # Strang B2 in the roadmap
make catalog-deploy     # Strang D1
make serving-deploy     # Strang E1
make prefect-up         # Strang F1
```

Each target is currently a stub — see `poc/manifests/*/` as they get filled in during Phase 0.

---

## 5. Teardown

```bash
make k3s-down
```

On macOS/Windows this deletes the k3d cluster (data wiped). On Linux it runs the k3s-uninstall script.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `docker: command not found` | Docker not installed on macOS/Windows | Install Docker Desktop or OrbStack |
| k3d cluster stuck creating | Low Docker resource limits | Docker Desktop → Settings → Resources → 4+ CPU, 8+ GB RAM |
| `kubectl` connects to wrong cluster | Multiple contexts | `kubectl config use-context k3d-miso` |
| Pods stuck `ImagePullBackOff` | Corporate proxy / offline | Configure Docker daemon `registry-mirrors` or pre-import images with `k3d image import` |
| Ingress on `localhost:8080` 404 | Traefik disabled (by design) | Deploy an ingress controller (later step) or use `kubectl port-forward` |
| Linux k3s pods unable to pull | `systemd-resolved` DNS quirks | `sudo systemctl restart k3s` |
| Permissions error reading kubeconfig | File owned by root | `sudo chown $(id -u):$(id -g) ~/.kube/config && chmod 600 ~/.kube/config` |

## Resource budget

For a full PoC deployment (MinIO + stac-fastapi + Postgres + TiTiler + DuckDB endpoint + Prefect) expect:

- ~4 vCPU, ~6 GB RAM idle
- ~10 GB disk (mostly MinIO sample data + Postgres)

Adjust Docker Desktop / OrbStack limits accordingly.
