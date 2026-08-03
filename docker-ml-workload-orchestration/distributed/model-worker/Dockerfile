FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    RANDOM_SEED=42 \
    MAX_ITERATIONS=500

WORKDIR /app

COPY requirements.txt /tmp/requirements.txt

RUN python -m pip install \
      --no-cache-dir \
      --requirement /tmp/requirements.txt \
    && useradd \
      --uid 10001 \
      --create-home \
      --shell /usr/sbin/nologin \
      pipeline

COPY model-worker/model_worker.py /app/model_worker.py

RUN mkdir -p /pipeline/data /pipeline/results \
    && chown -R 10001:10001 /app /pipeline

USER 10001:10001

ENTRYPOINT ["python", "/app/model_worker.py"]
