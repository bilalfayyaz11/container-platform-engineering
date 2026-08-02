from __future__ import annotations

import json
import logging
import os
from pathlib import Path

from flask import Flask, jsonify, request

from bootstrap import DatabaseBootstrap
from cache import CacheLayer
from health import HealthChecker
from store import ItemStore

logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(asctime)s %(levelname)s %(message)s",
)

app = Flask(__name__)


def read_secret(path: str) -> str:
    return Path(path).read_text(encoding="utf-8").strip()


POSTGRES_HOST = os.getenv("POSTGRES_HOST", "db")
POSTGRES_PORT = int(os.getenv("POSTGRES_PORT", "5432"))
POSTGRES_DB = os.getenv("POSTGRES_DB", "network_app")
POSTGRES_USER = os.getenv("POSTGRES_USER", "network_app")
POSTGRES_PASSWORD = read_secret(
    os.getenv(
        "POSTGRES_PASSWORD_FILE",
        "/run/secrets/postgres_password",
    )
)

REDIS_HOST = os.getenv("REDIS_HOST", "cache")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))
REDIS_PASSWORD = read_secret(
    os.getenv(
        "REDIS_PASSWORD_FILE",
        "/run/secrets/redis_password",
    )
)

DATABASE_URL = (
    f"postgresql://{POSTGRES_USER}:{POSTGRES_PASSWORD}"
    f"@{POSTGRES_HOST}:{POSTGRES_PORT}/{POSTGRES_DB}"
)

bootstrap = DatabaseBootstrap(DATABASE_URL)

if not bootstrap.wait_for_ready(
    POSTGRES_HOST,
    POSTGRES_PORT,
    timeout_seconds=60,
):
    raise RuntimeError("database failed to become ready")

bootstrap.apply_schema()
seeded_rows = bootstrap.seed_initial_data()

logging.info("database bootstrap complete seeded_rows=%s", seeded_rows)

store = ItemStore(DATABASE_URL)

cache_layer = CacheLayer(
    REDIS_HOST,
    REDIS_PORT,
    REDIS_PASSWORD,
)

health_checker = HealthChecker(
    DATABASE_URL,
    cache_layer,
)

CACHE_KEY = "items:list"


@app.get("/health")
def health():
    report = health_checker.report()
    status_code = 200 if report["status"] == "ok" else 503
    return jsonify(report), status_code


@app.get("/items")
def list_items():
    try:
        cached = cache_layer.get(CACHE_KEY)

        if cached:
            return jsonify(json.loads(cached))

        items = store.list_items()

        cache_layer.set(
            CACHE_KEY,
            json.dumps(items),
            ttl_seconds=30,
        )

        return jsonify(items)

    except Exception as error:
        logging.exception("item listing failed")
        return jsonify(
            error="dependency_failure",
            detail=str(error),
        ), 503


@app.post("/items")
def create_item():
    payload = request.get_json(silent=True) or {}
    name = payload.get("name")

    if not isinstance(name, str) or not name.strip():
        return jsonify(
            error="validation_error",
            detail="name must be a non-empty string",
        ), 400

    if len(name.strip()) > 255:
        return jsonify(
            error="validation_error",
            detail="name must not exceed 255 characters",
        ), 400

    try:
        item = store.create_item(name.strip())
        cache_layer.invalidate(CACHE_KEY)
        return jsonify(item), 201

    except Exception as error:
        logging.exception("item creation failed")
        return jsonify(
            error="dependency_failure",
            detail=str(error),
        ), 503
