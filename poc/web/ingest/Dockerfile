# Multi-stage: Vite build → tiny nginx static.
# Build context: poc/web/ingest/

FROM node:26-alpine AS builder
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci --no-audit --no-fund || npm install --no-audit --no-fund
COPY tsconfig.json vite.config.ts index.html ./
COPY public ./public
COPY src ./src
RUN npm run build

FROM nginx:1.27-alpine
COPY --from=builder /app/dist /usr/share/nginx/html
# Re-serve the standalone point cloud viewer at /viewer/* — same origin
# as the SPA so the iframe works without CORS. Build context is
# poc/web/ingest/, so we cannot reach docs/viewer/ here directly; the
# viewer assets are mounted at runtime via a ConfigMap in production
# (manifests/ingest-web/). For the dev image we just serve a small
# placeholder so the iframe doesn't 404.
RUN mkdir -p /usr/share/nginx/html/viewer \
 && printf '%s\n' '<!doctype html><meta charset=utf-8>' \
    '<style>body{font-family:Inter,system-ui;background:#fff;color:#14110d;padding:2rem;font-size:14px}a{color:#8a5410}</style>' \
    '<h1>Point cloud viewer</h1>' \
    '<p>The standalone viewer lives under <code>docs/viewer/pointcloud.html</code> in the repo. Mount it into this nginx via a ConfigMap (or open it directly via the docs site).</p>' \
    '<p><a href="https://github.com/marcosci/dashi/tree/main/docs/viewer">repo: docs/viewer</a></p>' \
    > /usr/share/nginx/html/viewer/pointcloud.html
# nginx:
#  - serves /index.html for SPA fallback (client-side router)
#  - reverse-proxies /api/* to the ingest-api Service (same namespace),
#    so the static bundle works behind a single port-forward / ingress.
# INGEST_API_UPSTREAM is templated by the official nginx entrypoint
# (envsubst over /etc/nginx/templates/*.template) at container start.
ENV INGEST_API_UPSTREAM="http://ingest-api.dashi-web.svc.cluster.local:8088"
ENV RUSTFS_UPSTREAM="http://rustfs.dashi-platform.svc.cluster.local:9000"
ENV MARTIN_UPSTREAM="http://martin.dashi-serving.svc.cluster.local:3000"
RUN mkdir -p /etc/nginx/templates && printf '%s\n' \
  'server {' \
  '  listen 8080;' \
  '  root /usr/share/nginx/html;' \
  '  index index.html;' \
  '  # Single-PUT path tops out at 500 MiB (multipart threshold); each' \
  '  # multipart chunk is 16-64 MiB. 600m gives both paths headroom.' \
  '  client_max_body_size 600m;' \
  '  location /api/ {' \
  '    rewrite ^/api/(.*)$ /$1 break;' \
  '    proxy_pass ${INGEST_API_UPSTREAM};' \
  '    proxy_set_header Host              $http_host;' \
  '    proxy_set_header X-Real-IP         $remote_addr;' \
  '    proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;' \
  '    proxy_set_header X-Forwarded-Proto $scheme;' \
  '    proxy_set_header Remote-User       $http_remote_user;' \
  '    proxy_set_header Remote-Groups     $http_remote_groups;' \
  '    proxy_read_timeout                 300s;' \
  '  }' \
  '  # /martin/* → Martin tile server. Path rewrite + Host preserved.' \
  '  location /martin/ {' \
  '    rewrite ^/martin/(.*)$ /$1 break;' \
  '    proxy_pass ${MARTIN_UPSTREAM};' \
  '    proxy_set_header Host              $http_host;' \
  '    proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;' \
  '    proxy_set_header X-Forwarded-Proto $scheme;' \
  '  }' \
  '  # Bucket paths reverse-proxy to RustFS, preserving Host. No path' \
  '  # rewrite — boto3 SigV4 includes the path in the signature, so we' \
  '  # cannot prefix-mount RustFS without breaking the signature. Same' \
  '  # origin as the SPA → no CORS for browser PUT.' \
  '  location ~ ^/(landing|processed|curated|backups)(/|$) {' \
  '    proxy_pass ${RUSTFS_UPSTREAM};' \
  '    proxy_set_header Host              $http_host;' \
  '    proxy_set_header X-Real-IP         $remote_addr;' \
  '    proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;' \
  '    proxy_set_header X-Forwarded-Proto $scheme;' \
  '    proxy_request_buffering            off;' \
  '    proxy_read_timeout                 600s;' \
  '    proxy_send_timeout                 600s;' \
  '  }' \
  '  location / { try_files $uri $uri/ /index.html; }' \
  '}' > /etc/nginx/templates/default.conf.template \
 && rm -f /etc/nginx/conf.d/default.conf
EXPOSE 8080
