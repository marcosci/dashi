#!/usr/bin/env bash
# Bring up a local k3s-equivalent cluster for dashi PoC.
# macOS + Windows: uses k3d (k3s in Docker).
# Linux: uses native k3s.

set -euo pipefail

CLUSTER_NAME="${1:-dashi}"

case "$(uname -s)" in
  Darwin|MINGW*|MSYS*|CYGWIN*)
    echo "→ Detected non-Linux host. Using k3d (k3s in Docker)."
    if ! command -v k3d >/dev/null 2>&1; then
      echo "ERROR: k3d not installed."
      echo "  macOS: brew install k3d"
      echo "  Windows: scoop install k3d   OR   choco install k3d"
      exit 1
    fi
    if ! command -v docker >/dev/null 2>&1; then
      echo "ERROR: docker not installed. Install Docker Desktop or OrbStack."
      exit 1
    fi
    if k3d cluster list | awk 'NR>1 {print $1}' | grep -qx "${CLUSTER_NAME}"; then
      echo "→ Cluster '${CLUSTER_NAME}' already exists."
    else
      echo "→ Creating cluster '${CLUSTER_NAME}' (1 server, 2 agents, port 8080→80, 8443→443)"
      k3d cluster create "${CLUSTER_NAME}" \
        --servers 1 \
        --agents 2 \
        --port "8080:80@loadbalancer" \
        --port "8443:443@loadbalancer" \
        --k3s-arg "--disable=traefik@server:0"
    fi
    ;;
  Linux)
    echo "→ Detected Linux. Using native k3s."
    if ! command -v k3s >/dev/null 2>&1; then
      echo "→ Installing k3s ..."
      curl -sfL https://get.k3s.io | sh -
    fi
    echo "→ Exporting kubeconfig to ~/.kube/config (if not already)"
    mkdir -p "${HOME}/.kube"
    sudo cat /etc/rancher/k3s/k3s.yaml > "${HOME}/.kube/config"
    sudo chown "$(id -u):$(id -g)" "${HOME}/.kube/config"
    chmod 600 "${HOME}/.kube/config"
    ;;
  *)
    echo "ERROR: unsupported OS: $(uname -s)"
    exit 1
    ;;
esac

echo ""
echo "→ Verifying cluster"
kubectl cluster-info
kubectl get nodes

echo ""
echo "✓ Cluster '${CLUSTER_NAME}' ready."
echo "  Next: make storage-deploy"
