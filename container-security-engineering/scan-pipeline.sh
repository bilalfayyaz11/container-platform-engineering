#!/usr/bin/env bash

set -uo pipefail

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 IMAGE"
    exit 2
fi

IMAGE="$1"
SAFE_IMAGE=$(printf '%s' "$IMAGE" | tr '/:@' '____')
REPORT_DIR="reports"

CVE_REPORT="${REPORT_DIR}/${SAFE_IMAGE}_cve.json"
SECRET_REPORT="${REPORT_DIR}/${SAFE_IMAGE}_secrets.json"
MISCONFIG_REPORT="${REPORT_DIR}/${SAFE_IMAGE}_misconfig.json"
DOCKLE_REPORT="${REPORT_DIR}/${SAFE_IMAGE}_dockle.json"

mkdir -p "$REPORT_DIR"

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "ERROR: Local image not found: $IMAGE"
    exit 2
fi

echo "Scanning: $IMAGE"

echo "1/4 Trivy vulnerability scan"

trivy image \
  --scanners vuln \
  --severity HIGH,CRITICAL \
  --ignore-unfixed \
  --format json \
  --output "$CVE_REPORT" \
  "$IMAGE"

TRIVY_CVE_EXIT=$?

echo "2/4 Trivy secret scan"

trivy image \
  --scanners secret \
  --format json \
  --output "$SECRET_REPORT" \
  "$IMAGE"

TRIVY_SECRET_EXIT=$?

echo "3/4 Trivy misconfiguration scan"

trivy image \
  --scanners misconfig \
  --format json \
  --output "$MISCONFIG_REPORT" \
  "$IMAGE"

TRIVY_MISCONFIG_EXIT=$?

echo "4/4 Dockle image benchmark"

dockle \
  --format json \
  --exit-code 0 \
  --output "$DOCKLE_REPORT" \
  "$IMAGE"

DOCKLE_EXIT=$?

for report in \
    "$CVE_REPORT" \
    "$SECRET_REPORT" \
    "$MISCONFIG_REPORT" \
    "$DOCKLE_REPORT"; do

    if [ ! -s "$report" ]; then
        echo "ERROR: Report is missing or empty: $report"
        exit 2
    fi
done

if [ "$TRIVY_CVE_EXIT" -ne 0 ] ||
   [ "$TRIVY_SECRET_EXIT" -ne 0 ] ||
   [ "$TRIVY_MISCONFIG_EXIT" -ne 0 ] ||
   [ "$DOCKLE_EXIT" -ne 0 ]; then

    echo "ERROR: One or more scanners failed operationally"
    echo "Trivy CVE exit: $TRIVY_CVE_EXIT"
    echo "Trivy secret exit: $TRIVY_SECRET_EXIT"
    echo "Trivy misconfiguration exit: $TRIVY_MISCONFIG_EXIT"
    echo "Dockle exit: $DOCKLE_EXIT"
    exit 2
fi

CVE_COUNT=$(jq '
  [
    .Results[]?.Vulnerabilities[]?
    | select(
        .Severity == "HIGH" or
        .Severity == "CRITICAL"
      )
  ]
  | length
' "$CVE_REPORT")

SECRET_COUNT=$(jq '
  [
    .Results[]?.Secrets[]?
  ]
  | length
' "$SECRET_REPORT")

MISCONFIG_COUNT=$(jq '
  [
    .Results[]?.Misconfigurations[]?
  ]
  | length
' "$MISCONFIG_REPORT")

DOCKLE_FATAL=$(jq '
  [
    .details[]?
    | select(.level == "FATAL")
  ]
  | length
' "$DOCKLE_REPORT" 2>/dev/null || echo 0)

DOCKLE_WARN=$(jq '
  [
    .details[]?
    | select(.level == "WARN")
  ]
  | length
' "$DOCKLE_REPORT" 2>/dev/null || echo 0)

DOCKLE_INFO=$(jq '
  [
    .details[]?
    | select(.level == "INFO")
  ]
  | length
' "$DOCKLE_REPORT" 2>/dev/null || echo 0)

DOCKLE_COUNT=$((DOCKLE_FATAL + DOCKLE_WARN + DOCKLE_INFO))

echo
echo "===== SECURITY SCAN SUMMARY ====="
echo "Image: $IMAGE"
echo "HIGH/CRITICAL CVEs: $CVE_COUNT"
echo "Secrets: $SECRET_COUNT"
echo "Misconfigurations: $MISCONFIG_COUNT"
echo "Dockle findings: $DOCKLE_COUNT"
echo "Reports:"
echo "  $CVE_REPORT"
echo "  $SECRET_REPORT"
echo "  $MISCONFIG_REPORT"
echo "  $DOCKLE_REPORT"

if [ "$CVE_COUNT" -gt 0 ]; then
    echo "RESULT: FAILED CVE GATE"
    exit 1
fi

echo "RESULT: PASSED CVE GATE"
exit 0
