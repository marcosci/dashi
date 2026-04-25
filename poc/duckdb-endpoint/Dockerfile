FROM python:3.12-slim

RUN pip install --no-cache-dir \
      "fastapi==0.115.6" \
      "uvicorn[standard]==0.32.1" \
      "duckdb==1.1.3" \
      "pydantic==2.10.3"

WORKDIR /app
COPY app.py /app/app.py

ENV LOG_LEVEL=INFO
EXPOSE 8080
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8080"]
