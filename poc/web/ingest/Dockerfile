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
# nginx serves /index.html for SPA fallback so client-side router works.
RUN printf '%s\n' \
  'server {' \
  '  listen 8080;' \
  '  root /usr/share/nginx/html;' \
  '  index index.html;' \
  '  location / { try_files $uri $uri/ /index.html; }' \
  '  # /api/* proxied to ingest-api by the cluster Service; nginx here just' \
  '  # serves static and returns 404 for unknown /api/* (which should never' \
  '  # reach this pod since the Ingress routes /api/* elsewhere).' \
  '  location /api/ { return 404; }' \
  '}' > /etc/nginx/conf.d/default.conf
EXPOSE 8080
