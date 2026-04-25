#!/usr/bin/env bash
# Build docs/viewer/viewer.bundle.js — single-file ESM with deck.gl 8.9 +
# loaders.gl 3.4 inlined. No CDN runtime peer-dep risk.
#
# Run from repo root: bash docs/viewer/build.sh
set -euo pipefail

cd "$(dirname "$0")"

if [ ! -d node_modules ]; then
  echo "→ npm install (first run only)"
  npm install --no-audit --no-fund --silent
fi

echo "→ esbuild bundle"
npm run -s build

ls -lh viewer.bundle.js
echo "✓ docs/viewer/viewer.bundle.js ready"
