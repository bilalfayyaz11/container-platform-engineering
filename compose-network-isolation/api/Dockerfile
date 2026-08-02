# syntax=docker/dockerfile:1.12

FROM python:3.13-slim AS dependencies

ENV PIP_DISABLE_PIP_VERSION_CHECK=1
ENV PIP_NO_CACHE_DIR=1

WORKDIR /app

COPY requirements.txt ./

RUN --mount=type=cache,target=/root/.cache/pip \
    pip install \
      --prefix=/install \
      --requirement requirements.txt

FROM python:3.13-slim AS runtime

ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

WORKDIR /app

COPY --from=dependencies /install /usr/local
COPY app.py bootstrap.py store.py cache.py health.py ./

RUN groupadd \
      --gid 10001 \
      appgroup && \
    useradd \
      --uid 10001 \
      --gid appgroup \
      --no-create-home \
      --shell /usr/sbin/nologin \
      appuser && \
    chown -R appuser:appgroup /app

USER 10001:10001

EXPOSE 5000

HEALTHCHECK \
  --interval=10s \
  --timeout=5s \
  --start-period=20s \
  --retries=5 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:5000/health', timeout=3)"

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--threads", "2", "--timeout", "30", "--access-logfile", "-", "--error-logfile", "-", "app:app"]
