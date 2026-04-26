#!/usr/bin/env bash
# Hold every dashi service on a stable localhost port. Re-spawns kubectl
# port-forward processes that die (k3d / pod restarts kill them).
#
# Run interactively in a terminal — `Ctrl-C` cleans every child up. Or
# detach with `nohup bash port-forward-all.sh &`.
#
# Stable ports (override via env DASHI_PORT_<svc> or edit the table below):
#
#   ingest-web    5174 → dashi-web/ingest-web:8080
#                        (also proxies /api → ingest-api, /martin → martin,
#                         /landing|processed|curated|backups → rustfs)
#   prefect       4200 → dashi-data/prefect-server:4200
#   grafana       3000 → dashi-monitoring/grafana:3000
#   prometheus    9090 → dashi-monitoring/prometheus:9090
#   stac-fastapi  8080 → dashi-catalog/stac-fastapi:8080
#   martin        3030 → dashi-serving/martin:3000
#   tipg          8081 → dashi-serving/tipg:8081
#   titiler       8090 → dashi-serving/titiler:8080
#   duckdb        8091 → dashi-serving/duckdb-endpoint:8080
#   rustfs-s3     9000 → dashi-platform/rustfs:9000
#   rustfs-ui     9001 → dashi-platform/rustfs:9001
#   iceberg-rest  8181 → dashi-iceberg/iceberg-rest:8181
#   loki          3100 → dashi-monitoring/loki:3100
#   ollama       11434 → dashi-llm/ollama:11434       (optional)
#   ingest-api    8088 → dashi-web/ingest-api:8088    (direct, bypasses nginx)

set -uo pipefail

# Tab-separated: name | local-port | namespace | svc:port
TABLE=$(cat <<'EOF'
ingest-web   5174  dashi-web         ingest-web:8080
prefect      4200  dashi-data        prefect-server:4200
grafana      3000  dashi-monitoring  grafana:3000
prometheus   9090  dashi-monitoring  prometheus:9090
stac-fastapi 8080  dashi-catalog     stac-fastapi:8080
martin       3030  dashi-serving     martin:3000
tipg         8081  dashi-serving     tipg:8081
titiler      8090  dashi-serving     titiler:8080
duckdb       8091  dashi-serving     duckdb-endpoint:8080
rustfs-s3    9000  dashi-platform    rustfs:9000
rustfs-ui    9001  dashi-platform    rustfs:9001
iceberg-rest 8181  dashi-iceberg     iceberg-rest:8181
loki         3100  dashi-monitoring  loki:3100
ollama       11434 dashi-llm         ollama:11434
ingest-api   8088  dashi-web         ingest-api:8088
EOF
)

declare -A PIDS
LOG_DIR="/tmp/dashi-pf"
mkdir -p "$LOG_DIR"

cleanup() {
  echo ""
  echo "→ stopping port-forwards"
  for name in "${!PIDS[@]}"; do
    kill "${PIDS[$name]}" 2>/dev/null || true
  done
  exit 0
}
trap cleanup INT TERM

start_one() {
  local name="$1" port="$2" ns="$3" target="$4"
  # Precheck retried up to 5x with 1s gap. Lima SSH-forwarding flaps on
  # macOS+colima — a single API hit can fail mid-bringup even when the
  # cluster is healthy. Retry tolerates the flap; if all 5 attempts fail
  # the service is genuinely missing.
  local i ok=
  for i in 1 2 3 4 5; do
    if kubectl -n "$ns" get svc "${target%%:*}" >/dev/null 2>&1; then
      ok=1
      break
    fi
    sleep 1
  done
  if [ -z "$ok" ]; then
    printf "  · %-13s skip (svc/%s not in %s)\n" "$name" "${target%%:*}" "$ns"
    return
  fi
  # Free the port if a stale forwarder is sitting on it.
  if lsof -ti tcp:"$port" >/dev/null 2>&1; then
    lsof -ti tcp:"$port" | xargs -r kill -9 2>/dev/null || true
    sleep 1
  fi
  kubectl -n "$ns" port-forward --address=127.0.0.1 \
    "svc/${target%%:*}" "${port}:${target##*:}" \
    >>"$LOG_DIR/${name}.log" 2>&1 &
  PIDS[$name]=$!
  printf "  · %-13s :%-5s → %s/%s\n" "$name" "$port" "$ns" "$target"
}

start_all() {
  while IFS= read -r row; do
    [ -z "$row" ] && continue
    set -- $row
    start_one "$1" "$2" "$3" "$4"
  done <<<"$TABLE"
}

echo "→ kubectl context: $(kubectl config current-context 2>/dev/null || echo unknown)"
echo "→ starting port-forwards on 127.0.0.1"
start_all
echo ""
echo "  Open these in your browser (whatever's deployed):"
echo "    http://localhost:5174        ingest UI (also proxies /api, /martin, /landing/...)"
echo "    http://localhost:4200        Prefect UI"
echo "    http://localhost:3000        Grafana"
echo "    http://localhost:9090        Prometheus"
echo "    http://localhost:9001        RustFS console"
echo "    http://localhost:8080/api/   STAC catalog (stac-fastapi)"
echo "    http://localhost:3030/catalog Martin tile catalog"
echo "    http://localhost:8081/       TiPG (OGC API – Features)"
echo "    http://localhost:8181/v1/config Iceberg REST"
echo ""
echo "  Logs: $LOG_DIR/<name>.log    Ctrl-C to stop everything."

# Supervisor: every 5 s, re-spawn anyone who died.
while sleep 5; do
  for row in $(awk 'NF{print $1}' <<<"$TABLE"); do
    pid="${PIDS[$row]:-}"
    if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
      # Find original config row + restart it.
      while IFS= read -r r; do
        [ -z "$r" ] && continue
        set -- $r
        if [ "$1" = "$row" ]; then
          echo "  ⟲ $row died — restarting"
          start_one "$1" "$2" "$3" "$4"
          break
        fi
      done <<<"$TABLE"
    fi
  done
done
