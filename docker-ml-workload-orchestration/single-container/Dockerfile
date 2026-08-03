# syntax=docker/dockerfile:1

FROM python:3.12-slim AS dependency-builder

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /build

COPY requirements.txt .

RUN python -m pip install \
      --upgrade pip \
    && python -m pip wheel \
      --wheel-dir /wheels \
      --requirement requirements.txt


FROM python:3.12-slim AS runtime

ARG APP_USER=mlrunner
ARG APP_UID=10001

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    OUTPUT_DIR=/app/output \
    RANDOM_SEED=42 \
    MAX_ITERATIONS=500 \
    REGULARIZATION_C=1.0 \
    TEST_SIZE=0.2

RUN groupadd \
      --gid "${APP_UID}" \
      "${APP_USER}" \
    && useradd \
      --uid "${APP_UID}" \
      --gid "${APP_UID}" \
      --create-home \
      --shell /usr/sbin/nologin \
      "${APP_USER}"

WORKDIR /app

COPY --from=dependency-builder /wheels /wheels
COPY requirements.txt .
COPY fit_model.py .

RUN python -m pip install \
      --no-index \
      --find-links=/wheels \
      --requirement requirements.txt \
    && rm -rf /wheels \
    && mkdir -p /app/output \
    && chown -R "${APP_UID}:${APP_UID}" /app

USER ${APP_UID}:${APP_UID}

VOLUME ["/app/output"]

ENTRYPOINT ["python", "/app/fit_model.py"]
