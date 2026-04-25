#!/usr/bin/env bash
# Apply a kustomize manifest directory after rotating a placeholder secret.
#
# Usage: apply-with-secret.sh <manifest-dir> <secret-filename> <placeholder>
#
# Generates a strong random password, writes it into the given secret file only
# for the duration of the apply, then restores the placeholder so the template
# never ends up in git with a real value.

set -euo pipefail

MANIFEST_DIR="${1:?manifest dir required}"
SECRET_FILE="${2:?secret filename required}"
PLACEHOLDER="${3:?placeholder string required}"

SECRET_PATH="${MANIFEST_DIR}/${SECRET_FILE}"

if [[ ! -f "$SECRET_PATH" ]]; then
  echo "ERROR: ${SECRET_PATH} not found"
  exit 1
fi

if ! grep -q "$PLACEHOLDER" "$SECRET_PATH"; then
  echo "→ ${SECRET_PATH} already rotated. Applying existing manifest."
  exec kubectl apply -k "$MANIFEST_DIR"
fi

PW=$(openssl rand -base64 32)
BACKUP="${SECRET_PATH}.bak"
cp "$SECRET_PATH" "$BACKUP"

# Restore template on any exit
trap 'mv -f "$BACKUP" "$SECRET_PATH" 2>/dev/null || true' EXIT

# shellcheck disable=SC2016
sed "s|${PLACEHOLDER}|${PW}|" "$BACKUP" > "$SECRET_PATH"

echo "→ Generated new secret (stored only in the cluster Secret object)"
kubectl apply -k "$MANIFEST_DIR"
