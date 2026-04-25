# Build a small image with py3dtiles + boto3, used by the dashi
# `copc → 3D Tiles tileset` Prefect flow.
#
# py3dtiles convert reads .las/.laz (incl. COPC) and emits a tileset.json
# + .pnts chunks suitable for streaming to deck.gl Tile3DLayer or CesiumJS.

FROM pdal/pdal:latest

ENV PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

# pdal/pdal image is conda-based and has pdal binary on PATH already.
# Just install py3dtiles via the bundled conda Python.

# Install py3dtiles + boto3 in a venv to dodge PEP 668.
# pdal/pdal image ships a base conda env at /opt/conda (python 3.13) plus a
# secondary `pdal` env. Install py3dtiles + boto3 explicitly into the base
# python so `python3 -m pip` and the PATH-resolved `python` both find them.
RUN /opt/conda/bin/python -m pip install --no-cache-dir \
      'py3dtiles>=9.0' \
      'laspy>=2.5' \
      'boto3>=1.35' \
 && /opt/conda/bin/python -c 'import boto3, py3dtiles, laspy'

COPY generate-3dtiles.sh /usr/local/bin/generate-3dtiles.sh
RUN chmod +x /usr/local/bin/generate-3dtiles.sh

ENTRYPOINT ["/usr/local/bin/generate-3dtiles.sh"]
