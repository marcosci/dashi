FROM python:3.12-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      gdal-bin \
      libgdal-dev \
      pdal \
      libpdal-plugin-python \
      libexpat1 \
      build-essential \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install the package — copy in minimal files for layer caching
COPY pyproject.toml README.md* /app/
COPY src /app/src

RUN pip install --no-cache-dir \
      "prefect>=3.1,<4" \
      "prefect-kubernetes>=0.5" \
    && pip install --no-cache-dir -e .

ENV PYTHONUNBUFFERED=1 \
    PREFECT_LOGGING_LEVEL=INFO

ENTRYPOINT ["miso-ingest"]
