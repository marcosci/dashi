FROM python:3.12-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      libexpat1 \
 && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir \
      "fastapi==0.115.6" \
      "uvicorn[standard]==0.32.1" \
      "rio-tiler==7.4.0" \
      "pillow==11.0.0"

WORKDIR /app
COPY app.py /app/app.py

ENV LOG_LEVEL=INFO \
    GDAL_DISABLE_READDIR_ON_OPEN=EMPTY_DIR \
    CPL_VSIL_CURL_ALLOWED_EXTENSIONS=".tif,.TIF,.tiff"
EXPOSE 8080
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8080"]
