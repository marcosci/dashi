# Build a small image with py3dtiles + boto3, used by the dashi
# `copc → 3D Tiles tileset` Prefect flow.
#
# py3dtiles convert reads .las/.laz (incl. COPC) and emits a tileset.json
# + .pnts chunks suitable for streaming to deck.gl Tile3DLayer or CesiumJS.

FROM debian:12-slim

ENV PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash \
      ca-certificates \
      curl \
      libgdal32 \
      python3 \
      python3-pip \
      python3-venv \
 && rm -rf /var/lib/apt/lists/*

# Install py3dtiles + boto3 in a venv to dodge PEP 668.
RUN python3 -m venv /opt/p3dt \
 && /opt/p3dt/bin/pip install --upgrade pip \
 && /opt/p3dt/bin/pip install \
      'py3dtiles>=9.0' \
      'laspy[lazrs]>=2.5' \
      'boto3>=1.35'

ENV PATH=/opt/p3dt/bin:$PATH

COPY generate-3dtiles.sh /usr/local/bin/generate-3dtiles.sh
RUN chmod +x /usr/local/bin/generate-3dtiles.sh

ENTRYPOINT ["/usr/local/bin/generate-3dtiles.sh"]
