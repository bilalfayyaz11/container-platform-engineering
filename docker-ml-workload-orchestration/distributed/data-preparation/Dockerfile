FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

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

COPY data-preparation/prepare_data.py /app/prepare_data.py

RUN mkdir -p /pipeline/data \
    && chown -R 10001:10001 /app /pipeline

USER 10001:10001

ENTRYPOINT ["python", "/app/prepare_data.py"]
