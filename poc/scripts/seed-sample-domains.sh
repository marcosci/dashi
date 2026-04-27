#!/usr/bin/env bash
# Seed the dashi cluster with two demo domains so the multi-tenant
# story is visible end-to-end:
#
#   gelaende-umwelt   — generic spatial / Earth-observation; ceiling=int
#   klima-historisch  — historic climate reconstructions; ceiling=pub
#
# Each domain is an independent STAC collection with its own
# `dashi:max_classification` ceiling and `dashi:retention` policy. The
# pair exists to prove that a domain is a tenant boundary (different
# ceilings, different retention, different audiences) rather than just
# a folder name.
#
# Idempotent — `dashictl domain create` is an upsert.
#
# Prereqs: dashictl on PATH (cargo install --path poc/dashictl) +
#          STAC reachable on http://localhost:8080 (port-forward-all.sh
#          running, or set DASHI_STAC_URL).

set -euo pipefail

if ! command -v dashictl >/dev/null 2>&1; then
  echo "ERROR: dashictl not on PATH"
  echo "       cd poc/dashictl && cargo install --path . --locked"
  exit 1
fi

echo "→ seed gelaende-umwelt (ceiling=int, retention=indefinite)"
dashictl domain create gelaende-umwelt \
  --title "Gelände & Umwelt" \
  --description "Generic spatial / Earth-observation domain — vector basemaps, raster mosaics, point-cloud surveys. Ceiling: int (operational data, not internet-publishable by default)." \
  --max-classification int \
  --retention indefinite

echo "→ seed klima-historisch (ceiling=pub, retention=indefinite)"
dashictl domain create klima-historisch \
  --title "Klima – historisch" \
  --description "Historic climate reconstructions and re-analyses. Ceiling: pub (public, internet-publishable). Boundary differs from gelaende-umwelt to prove the multi-tenant model: different ceiling, different audience, different retention semantics." \
  --max-classification pub \
  --retention indefinite

echo ""
echo "✓ Seeded 2 domains. Verify:"
echo "  dashictl domain list"
echo ""
echo "  Each domain enforces its own classification ceiling at trigger time:"
echo "  attempting to ingest a 'cnf' object into klima-historisch (pub ceiling)"
echo "  is rejected by the ingest-api with 403 + a docs link."
