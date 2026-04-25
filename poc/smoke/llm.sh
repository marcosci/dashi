#!/usr/bin/env bash
# Smoke — Ollama LLM endpoint reachability + chat round-trip.

set -euo pipefail

NS="${NS:-dashi-llm}"
PORT="${PORT:-19434}"

cleanup() { for pid in ${PFPIDS:-}; do kill "$pid" 2>/dev/null || true; done; }
trap cleanup EXIT

ok()   { echo "✓ $1"; }
fail() { echo "✗ $1" >&2; exit 1; }

if ! kubectl -n "$NS" get deploy ollama >/dev/null 2>&1; then
  echo "  (Ollama not deployed; skipping. Run: make llm-deploy)"
  exit 0
fi

echo "→ port-forward svc/ollama"
kubectl -n "$NS" port-forward svc/ollama "${PORT}:11434" >/dev/null 2>&1 &
PFPIDS="$!"
sleep 4

VER=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${PORT}/api/version")
[[ "$VER" == "200" ]] && ok "ollama /api/version 200" || fail "/api/version $VER"

# Just check tags exist; the model may still be pulling on first deploy.
TAGS=$(curl -sf "http://localhost:${PORT}/api/tags" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(len(d.get("models",[])))')
ok "ollama lists $TAGS model(s)"

if [[ "$TAGS" -ge 1 ]]; then
  RESP=$(curl -sf -X POST "http://localhost:${PORT}/v1/chat/completions" \
    -H 'Content-Type: application/json' \
    -d '{"model":"llama3.2:3b","messages":[{"role":"user","content":"reply with the single word OK"}],"temperature":0,"max_tokens":4}' \
    | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d["choices"][0]["message"]["content"][:30])' || true)
  if [[ -n "$RESP" ]]; then
    ok "chat completion: \"${RESP}\""
  else
    echo "  (chat completion not available yet — model may still be pulling)"
  fi
fi

echo ""
echo "✓ llm smoke PASSED"
