# dashi web · ingest

Browser UI for non-shell users to drop a file → STAC item.

Stack: **Vite 5 + React 18 + TypeScript + Tailwind v4 + TanStack Query**.

```
poc/web/ingest/
├── src/
│   ├── main.tsx              # bootstrap + QueryClient + Router
│   ├── App.tsx               # shell (header / footer / outlet)
│   ├── routes/Ingest.tsx     # the upload flow state machine
│   ├── components/
│   │   ├── DomainPicker.tsx  # dropdown sourced from /api/domains
│   │   ├── FileDropzone.tsx  # react-dropzone wrapper
│   │   ├── ScanPreview.tsx   # detect.discover() result table
│   │   └── RunStatus.tsx     # link out to Prefect run page
│   ├── hooks/                # TanStack Query bindings
│   ├── api/client.ts         # /presign · /scan · /trigger · /domains · /me
│   └── styles/globals.css    # Tailwind base + dashi palette tokens
├── public/dashi-favicon.svg
├── tests/Ingest.test.tsx     # vitest + @testing-library/react
├── package.json              # 4 runtime deps, 12 dev deps
├── vite.config.ts            # /api proxy → ingest-api on :8088
├── tsconfig.json             # strict mode
└── Dockerfile                # multi-stage Vite build → nginx alpine
```

## Local dev

```bash
# Terminal 1 — FastAPI shim with mock auth (dev@dashi.local)
cd poc/services/ingest-api
pip install -e '.[dev]'
DASHI_API_MOCK_USER=dev@dashi.local DASHI_API_MOCK_GROUPS=dashi,admins \
  DASHI_API_S3_ACCESS_KEY=$(kubectl -n dashi-data get secret dashi-rustfs-pipeline -o jsonpath='{.data.access-key}' | base64 -d) \
  DASHI_API_S3_SECRET_KEY=$(kubectl -n dashi-data get secret dashi-rustfs-pipeline -o jsonpath='{.data.secret-key}' | base64 -d) \
  DASHI_API_S3_ENDPOINT=http://localhost:9000 \
  DASHI_API_STAC_URL=http://localhost:8080 \
  DASHI_API_PREFECT_API_URL=http://localhost:4200/api \
  uvicorn dashi_ingest_api.main:app --port 8088

# Terminal 2 — Vite dev server (proxies /api → :8088)
cd poc/web/ingest
npm install
npm run dev
```

Open http://localhost:5173.

## Deploy in cluster

```bash
cd poc && make web-ingest-deploy
make smoke-web-ingest    # or:  bash smoke/web-ingest.sh
```

PoC port-forward:

```bash
kubectl -n dashi-web port-forward svc/ingest-web 5174:8080 &
kubectl -n dashi-web port-forward svc/ingest-api 8088:8088 &
```

The cluster pods run with `DASHI_API_MOCK_USER=dev@dashi.local` for PoC. Production removes those two env vars and the ingress controller injects real `Remote-User` / `Remote-Groups` headers via Authelia forward-auth.

## Build budget

CI fails the build if the gzipped JS exceeds **200 KB**. Today: ~84 KB gz.

## What's intentionally NOT here

- run history (use Prefect UI)
- catalog browser (use STAC browser fork)
- admin domain self-service (PR-bot in Phase 3)
- multipart uploads >1 GB (use `dashi-ingest` CLI)
