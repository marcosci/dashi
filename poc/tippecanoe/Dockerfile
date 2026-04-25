# Multi-stage:
# - builder: tippecanoe arm64 from source on debian 12
# - runtime: GDAL 3.12 ubuntu-full image (has GeoParquet via Apache Arrow)

FROM debian:12-slim AS builder
ARG TIPPECANOE_VERSION=2.79.0
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential \
      ca-certificates \
      git \
      libsqlite3-dev \
      zlib1g-dev \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /src
RUN git clone --depth=1 --branch=${TIPPECANOE_VERSION} https://github.com/felt/tippecanoe.git \
 && cd tippecanoe && make -j"$(nproc)"

FROM ghcr.io/osgeo/gdal:ubuntu-full-3.12.0

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash \
      ca-certificates \
      curl \
      libsqlite3-0 \
      python3-pip \
      zlib1g \
 && rm -rf /var/lib/apt/lists/*

# go-pmtiles CLI
ARG PMTILES_VERSION=1.22.3
RUN set -eu; \
    arch="$(uname -m)"; \
    case "$arch" in \
      aarch64|arm64) pm_arch=arm64 ;; \
      x86_64|amd64) pm_arch=amd64 ;; \
      *) echo "unsupported arch $arch"; exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/protomaps/go-pmtiles/releases/download/v${PMTILES_VERSION}/go-pmtiles_${PMTILES_VERSION}_Linux_${pm_arch}.tar.gz" \
      | tar -xz -C /usr/local/bin pmtiles

COPY --from=builder /src/tippecanoe/tippecanoe /src/tippecanoe/tile-join /usr/local/bin/

# boto3 for S3 IO from the helper script
RUN pip install --break-system-packages --no-cache-dir boto3==1.35.96

COPY generate-pmtiles.sh /usr/local/bin/generate-pmtiles.sh
RUN chmod +x /usr/local/bin/generate-pmtiles.sh

WORKDIR /work
ENTRYPOINT ["/bin/bash"]
