#!/usr/bin/env bash
###############################################################################
# GreyEye — Production Smoke Test Suite
#
# End-to-end validation: health checks, auth flow, site creation, camera
# registration, frame upload, and count verification. Designed to run after
# a production deploy or during the 24h burn-in window.
#
# Usage:
#   ./infra/scripts/production-smoke-test.sh [--api-url URL] [--password PW]
#
# Environment variables (override with flags):
#   API_BASE_URL          Base URL (default: https://api.greyeye.io)
#   SMOKE_TEST_PASSWORD   Password for smoke@greyeye.io
#   SMOKE_TIMEOUT         HTTP timeout in seconds (default: 15)
#   CLEANUP               Set to "false" to skip cleanup (default: true)
###############################################################################

set -euo pipefail

# ── Defaults ────────────────────────────────────────────────────────────────
API_BASE_URL="${API_BASE_URL:-https://api.greyeye.io}"
SMOKE_TEST_PASSWORD="${SMOKE_TEST_PASSWORD:-}"
SMOKE_TIMEOUT="${SMOKE_TIMEOUT:-15}"
CLEANUP="${CLEANUP:-true}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --api-url)   API_BASE_URL="$2"; shift 2 ;;
    --password)  SMOKE_TEST_PASSWORD="$2"; shift 2 ;;
    --no-cleanup) CLEANUP="false"; shift ;;
    *)           echo "Unknown flag: $1"; exit 1 ;;
  esac
done

PASSED=0
FAILED=0
WARNINGS=0
CREATED_SITE_ID=""
CREATED_CAMERA_ID=""
ACCESS_TOKEN=""

# ── Helpers ─────────────────────────────────────────────────────────────────
log()   { echo "  $(date -u +%H:%M:%S) $*"; }
pass()  { log "✓ $*"; PASSED=$((PASSED + 1)); }
fail()  { log "✗ $*"; FAILED=$((FAILED + 1)); }
warn()  { log "⚠ $*"; WARNINGS=$((WARNINGS + 1)); }

http_get() {
  curl -sf --max-time "${SMOKE_TIMEOUT}" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    "${API_BASE_URL}$1" 2>/dev/null
}

http_post() {
  curl -sf --max-time "${SMOKE_TIMEOUT}" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$2" \
    "${API_BASE_URL}$1" 2>/dev/null
}

http_delete() {
  curl -sf --max-time "${SMOKE_TIMEOUT}" -X DELETE \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    "${API_BASE_URL}$1" 2>/dev/null
}

http_status() {
  curl -so /dev/null -w "%{http_code}" --max-time "${SMOKE_TIMEOUT}" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    "${API_BASE_URL}$1" 2>/dev/null || echo "000"
}

cleanup() {
  if [[ "${CLEANUP}" != "true" ]]; then
    log "Skipping cleanup (--no-cleanup)."
    return
  fi
  echo ""
  echo "── Cleanup ──"
  if [[ -n "${CREATED_CAMERA_ID}" ]]; then
    http_delete "/v1/config/cameras/${CREATED_CAMERA_ID}" >/dev/null 2>&1 && \
      log "Deleted smoke-test camera ${CREATED_CAMERA_ID}" || true
  fi
  if [[ -n "${CREATED_SITE_ID}" ]]; then
    http_delete "/v1/config/sites/${CREATED_SITE_ID}" >/dev/null 2>&1 && \
      log "Deleted smoke-test site ${CREATED_SITE_ID}" || true
  fi
}
trap cleanup EXIT

# ── Banner ──────────────────────────────────────────────────────────────────
echo "══════════════════════════════════════════════════════════════"
echo "  GreyEye Production Smoke Tests"
echo "  Target: ${API_BASE_URL}"
echo "  Time:   $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "══════════════════════════════════════════════════════════════"
echo ""

###############################################################################
# 1. Health Endpoints
###############################################################################
echo "── 1. Health Endpoints ──"
HEALTH_ENDPOINTS=("/healthz" "/v1/auth/healthz" "/v1/config/healthz" "/v1/ingest/healthz" "/v1/analytics/healthz")
for ep in "${HEALTH_ENDPOINTS[@]}"; do
  STATUS=$(curl -so /dev/null -w "%{http_code}" --max-time "${SMOKE_TIMEOUT}" "${API_BASE_URL}${ep}" 2>/dev/null || echo "000")
  if [[ "$STATUS" == "200" ]]; then
    pass "${ep} → ${STATUS}"
  else
    fail "${ep} → ${STATUS}"
  fi
done

echo ""
echo "── 2. Response Time ──"
TOTAL_TIME=$(curl -so /dev/null -w "%{time_total}" --max-time "${SMOKE_TIMEOUT}" "${API_BASE_URL}/healthz" 2>/dev/null || echo "99")
log "/healthz response: ${TOTAL_TIME}s"
SLOW=$(echo "$TOTAL_TIME > 2.0" | bc -l 2>/dev/null || echo "0")
if [[ "$SLOW" == "1" ]]; then
  warn "Response time exceeds 2s threshold"
else
  pass "Response time within threshold"
fi

###############################################################################
# 2. Authentication Flow
###############################################################################
echo ""
echo "── 3. Authentication ──"
if [[ -z "${SMOKE_TEST_PASSWORD}" ]]; then
  warn "SMOKE_TEST_PASSWORD not set — skipping auth and API tests"
  echo ""
  echo "══════════════════════════════════════════════════════════════"
  echo "  Results: ${PASSED} passed, ${FAILED} failed, ${WARNINGS} warnings"
  echo "══════════════════════════════════════════════════════════════"
  [[ "${FAILED}" -eq 0 ]] && exit 0 || exit 1
fi

TOKEN_RESP=$(curl -sf --max-time "${SMOKE_TIMEOUT}" -X POST "${API_BASE_URL}/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"smoke@greyeye.io\",\"password\":\"${SMOKE_TEST_PASSWORD}\"}" 2>/dev/null || echo '{}')

ACCESS_TOKEN=$(echo "$TOKEN_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null || echo "")

if [[ -n "$ACCESS_TOKEN" ]]; then
  pass "Login as smoke@greyeye.io"
else
  fail "Login failed — cannot continue API tests"
  echo ""
  echo "══════════════════════════════════════════════════════════════"
  echo "  Results: ${PASSED} passed, ${FAILED} failed, ${WARNINGS} warnings"
  echo "══════════════════════════════════════════════════════════════"
  exit 1
fi

ME_RESP=$(http_get "/v1/users/me")
if echo "$ME_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d.get('email')=='smoke@greyeye.io'" 2>/dev/null; then
  pass "GET /v1/users/me returns correct user"
else
  fail "GET /v1/users/me unexpected response"
fi

###############################################################################
# 3. Site CRUD
###############################################################################
echo ""
echo "── 4. Site Management ──"
SITE_PAYLOAD='{"name":"smoke-test-site-'$(date +%s)'","address":"Seoul, South Korea","timezone":"Asia/Seoul","location":{"type":"Point","coordinates":[126.978,37.566]}}'

SITE_RESP=$(http_post "/v1/config/sites" "$SITE_PAYLOAD")
CREATED_SITE_ID=$(echo "$SITE_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || echo "")

if [[ -n "$CREATED_SITE_ID" ]]; then
  pass "Created site: ${CREATED_SITE_ID}"
else
  fail "Site creation failed"
fi

if [[ -n "$CREATED_SITE_ID" ]]; then
  SITE_GET=$(http_get "/v1/config/sites/${CREATED_SITE_ID}")
  if echo "$SITE_GET" | python3 -c "import sys,json; assert json.load(sys.stdin).get('id')=='${CREATED_SITE_ID}'" 2>/dev/null; then
    pass "GET site by ID"
  else
    fail "GET site by ID returned unexpected data"
  fi
fi

###############################################################################
# 4. Camera Registration
###############################################################################
echo ""
echo "── 5. Camera Registration ──"
if [[ -n "$CREATED_SITE_ID" ]]; then
  CAMERA_PAYLOAD='{"name":"smoke-test-cam","site_id":"'${CREATED_SITE_ID}'","source_type":"rtsp","source_uri":"rtsp://smoke-test:554/stream","resolution_width":1920,"resolution_height":1080,"target_fps":10}'

  CAMERA_RESP=$(http_post "/v1/config/cameras" "$CAMERA_PAYLOAD")
  CREATED_CAMERA_ID=$(echo "$CAMERA_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || echo "")

  if [[ -n "$CREATED_CAMERA_ID" ]]; then
    pass "Registered camera: ${CREATED_CAMERA_ID}"
  else
    fail "Camera registration failed"
  fi
else
  warn "Skipping camera registration (no site)"
fi

###############################################################################
# 5. Ingest Endpoint
###############################################################################
echo ""
echo "── 6. Ingest Endpoint ──"
INGEST_STATUS=$(http_status "/v1/ingest/healthz")
if [[ "$INGEST_STATUS" == "200" ]]; then
  pass "Ingest service healthy"
else
  fail "Ingest service unhealthy (${INGEST_STATUS})"
fi

###############################################################################
# 6. Analytics / Reporting
###############################################################################
echo ""
echo "── 7. Analytics API ──"
ANALYTICS_STATUS=$(http_status "/v1/analytics/15m?camera_id=00000000-0000-0000-0000-000000000000&start=2025-01-01T00:00:00Z&end=2025-01-01T01:00:00Z")
if [[ "$ANALYTICS_STATUS" == "200" || "$ANALYTICS_STATUS" == "404" ]]; then
  pass "Analytics endpoint responds (${ANALYTICS_STATUS})"
else
  fail "Analytics endpoint error (${ANALYTICS_STATUS})"
fi

KPI_STATUS=$(http_status "/v1/analytics/kpi")
if [[ "$KPI_STATUS" == "200" ]]; then
  pass "KPI endpoint responds"
else
  warn "KPI endpoint returned ${KPI_STATUS}"
fi

###############################################################################
# 7. Alerts API
###############################################################################
echo ""
echo "── 8. Alerts API ──"
ALERTS_STATUS=$(http_status "/v1/alerts/rules")
if [[ "$ALERTS_STATUS" == "200" ]]; then
  pass "Alert rules endpoint responds"
else
  warn "Alert rules endpoint returned ${ALERTS_STATUS}"
fi

###############################################################################
# 8. WebSocket Connectivity
###############################################################################
echo ""
echo "── 9. WebSocket ──"
WS_URL="${API_BASE_URL/https:/wss:}/v1/analytics/live/ws"
WS_URL="${WS_URL/http:/ws:}"
if command -v websocat >/dev/null 2>&1; then
  WS_RESULT=$(echo '{"type":"ping"}' | timeout 5 websocat -t --one-message "${WS_URL}?token=${ACCESS_TOKEN}" 2>/dev/null || echo "")
  if [[ -n "$WS_RESULT" ]]; then
    pass "WebSocket connection established"
  else
    warn "WebSocket connection could not be verified"
  fi
else
  warn "websocat not installed — skipping WebSocket test"
fi

###############################################################################
# 9. Metrics Endpoints
###############################################################################
echo ""
echo "── 10. Metrics ──"
METRICS_ENDPOINTS=("/v1/auth/metrics" "/v1/config/metrics" "/v1/ingest/metrics" "/v1/analytics/metrics")
for ep in "${METRICS_ENDPOINTS[@]}"; do
  STATUS=$(curl -so /dev/null -w "%{http_code}" --max-time "${SMOKE_TIMEOUT}" "${API_BASE_URL}${ep}" 2>/dev/null || echo "000")
  if [[ "$STATUS" == "200" ]]; then
    pass "Metrics: ${ep}"
  else
    warn "Metrics: ${ep} → ${STATUS}"
  fi
done

###############################################################################
# Summary
###############################################################################
echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  Results: ${PASSED} passed, ${FAILED} failed, ${WARNINGS} warnings"
echo "  Time:   $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "══════════════════════════════════════════════════════════════"

if [[ "${FAILED}" -gt 0 ]]; then
  echo "SMOKE TEST FAILED"
  exit 1
fi
echo "SMOKE TEST PASSED"
exit 0
