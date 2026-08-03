#!/bin/sh

set -eu

test -r /app/index.html

HTTPD_BIN="$(command -v httpd)"

if [ -z "$HTTPD_BIN" ]; then
    echo "ERROR: httpd executable is unavailable" >&2
    exit 1
fi

exec "$HTTPD_BIN" \
  -f \
  -p 8080 \
  -h /app
