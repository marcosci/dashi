# Build context: poc/ (so we can reach ingest/ alongside services/ingest-api/).
# docker build -f poc/services/ingest-api/Dockerfile poc -t dashi/ingest-api:dev
FROM python:3.14-slim

ENV PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      gdal-bin \
      libgdal-dev \
      build-essential \
 && rm -rf /var/lib/apt/lists/*

# Install dashi_ingest (detect + storage + flow) — siblings under poc/ingest
COPY ingest/pyproject.toml /tmp/ingest/pyproject.toml
COPY ingest/src/           /tmp/ingest/src/
RUN pip install /tmp/ingest

# The shim itself
COPY services/ingest-api/pyproject.toml ./
COPY services/ingest-api/src ./src
RUN pip install --no-cache-dir -e .

EXPOSE 8088
CMD ["uvicorn", "dashi_ingest_api.main:app", "--host", "0.0.0.0", "--port", "8088"]
