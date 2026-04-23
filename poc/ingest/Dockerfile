FROM condaforge/miniforge3:latest

# Base deps via conda-forge — PDAL is not in Debian main.
RUN mamba install -y -c conda-forge \
      python=3.12 \
      gdal=3.9 \
      pdal=2.7 \
      python-pdal \
 && mamba clean -afy

WORKDIR /app

# Install the package — copy in minimal files for layer caching
COPY pyproject.toml README.md* /app/
COPY src /app/src

RUN pip install --no-cache-dir \
      "prefect>=3.1,<4" \
      "prefect-kubernetes>=0.5" \
    && pip install --no-cache-dir -e .

# Demo fixture — small GeoJSON so Phase-2 scheduled runs have data even
# when no landing-zone upload happened. Overridable: set the flow's
# source_path parameter to any path inside the ingest pod (mount a PVC
# or ConfigMap in production).
COPY fixtures /work/sample-data

ENV PYTHONUNBUFFERED=1 \
    PREFECT_LOGGING_LEVEL=INFO

# No ENTRYPOINT — Prefect flow-run Jobs override with
# `prefect flow-run execute`. For direct CLI use run:
#   docker run --rm miso/miso-ingest:dev miso-ingest --help
