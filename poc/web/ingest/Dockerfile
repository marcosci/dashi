# Multi-stage: Vite build → tiny nginx static.
# Build context: poc/web/ingest/

FROM node:22-alpine AS builder
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci --no-audit --no-fund || npm install --no-audit --no-fund
COPY tsconfig.json vite.config.ts index.html ./
COPY public ./public
COPY src ./src
RUN npm run build

FROM nginx:1.27-alpine
COPY --from=builder /app/dist /usr/share/nginx/html
# nginx:
#  - serves /index.html for SPA fallback (client-side router)
#  - reverse-proxies /api/* to the ingest-api Service (same namespace),
#    so the static bundle works behind a single port-forward / ingress.
# INGEST_API_UPSTREAM is templated by the official nginx entrypoint
# (envsubst over /etc/nginx/templates/*.template) at container start.
ENV INGEST_API_UPSTREAM="http://ingest-api.dashi-web.svc.cluster.local:8088"
RUN mkdir -p /etc/nginx/templates && printf '%s\n' \
  'server {' \
  '  listen 8080;' \
  '  root /usr/share/nginx/html;' \
  '  index index.html;' \
  '  client_max_body_size 1100m;' \
  '  location /api/ {' \
  '    rewrite ^/api/(.*)$ /$1 break;' \
  '    proxy_pass ${INGEST_API_UPSTREAM};' \
  '    proxy_set_header Host              $host;' \
  '    proxy_set_header X-Real-IP         $remote_addr;' \
  '    proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;' \
  '    proxy_set_header X-Forwarded-Proto $scheme;' \
  '    proxy_set_header Remote-User       $http_remote_user;' \
  '    proxy_set_header Remote-Groups     $http_remote_groups;' \
  '    proxy_read_timeout                 300s;' \
  '  }' \
  '  location / { try_files $uri $uri/ /index.html; }' \
  '}' > /etc/nginx/templates/default.conf.template \
 && rm -f /etc/nginx/conf.d/default.conf
EXPOSE 8080
