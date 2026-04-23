#!/usr/bin/env bash
# Tear down the local MISO PoC cluster.

set -euo pipefail

CLUSTER_NAME="${1:-miso}"

case "$(uname -s)" in
  Darwin|MINGW*|MSYS*|CYGWIN*)
    if command -v k3d >/dev/null 2>&1 && k3d cluster list | awk 'NR>1 {print $1}' | grep -qx "${CLUSTER_NAME}"; then
      echo "→ Deleting k3d cluster '${CLUSTER_NAME}'"
      k3d cluster delete "${CLUSTER_NAME}"
    else
      echo "→ No k3d cluster '${CLUSTER_NAME}' to delete."
    fi
    ;;
  Linux)
    if command -v k3s-uninstall.sh >/dev/null 2>&1; then
      echo "→ Running k3s uninstall script"
      sudo /usr/local/bin/k3s-uninstall.sh
    else
      echo "→ No k3s install detected."
    fi
    ;;
esac

echo "✓ Teardown complete."
