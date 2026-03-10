#!/usr/bin/env bash
###############################################################################
# GreyEye — 24-Hour Burn-In Monitor
#
# Periodically checks production health during the post-deploy burn-in window.
# Runs smoke tests, queries Prometheus for SLO compliance, and reports status.
# Exits non-zero if any critical threshold is breached.
#
# Usage:
#   ./infra/scripts/burn-in-monitor.sh [--duration HOURS] [--interval MINUTES]
#
# Environment variables:
#   API_BASE_URL          (default: https://api.greyeye.io)
#   PROMETHEUS_URL        (default: https://prometheus.greyeye.io)
#   SMOKE_TEST_PASSWORD   Password for smoke@greyeye.io
#   SLACK_WEBHOOK_URL     Webhook for status updates (optional)
#   K8S_NAMESPACE         (default: greyeye-production)
###############################################################################

set -euo pipefail

API_BASE_URL="${API_BASE_URL:-https://api.greyeye.io}"
PROMETHEUS_URL="${PROMETHEUS_URL:-https://prometheus.greyeye.io}"
SMOKE_TEST_PASSWORD="${SMOKE_TEST_PASSWORD:-}"
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
K8S_NAMESPACE="${K8S_NAMESPACE:-greyeye-production}"
DURATION_HOURS=24
INTERVAL_MINUTES=15

while [[ $# -gt 0 ]]; do
  case "$1" in
    --duration)   DURATION_HOURS="$2"; shift 2 ;;
    --interval)   INTERVAL_MINUTES="$2"; shift 2 ;;
    --api-url)    API_BASE_URL="$2"; shift 2 ;;
    --prom-url)   PROMETHEUS_URL="$2"; shift 2 ;;
    *)            echo "Unknown flag: $1"; exit 1 ;;
  esac
done

TOTAL_CHECKS=$(( (DURATION_HOURS * 60) / INTERVAL_MINUTES ))
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="/tmp/greyeye-burn-in-$(date +%Y%m%d-%H%M%S).log"
CRITICAL_FAILURES=0
TOTAL_ITERATIONS=0
START_TIME=$(date +%s)
END_TIME=$(( START_TIME + DURATION_HOURS * 3600 ))

# ── Helpers ─────────────────────────────────────────────────────────────────
log() {
  local msg="[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] $*"
  echo "$msg"
  echo "$msg" >> "$LOG_FILE"
}

prom_query() {
  local query="$1"
  curl -sf --max-time 10 "${PROMETHEUS_URL}/api/v1/query" \
    --data-urlencode "query=${query}" 2>/dev/null \
    | python3 -c "
import sys, json
data = json.load(sys.stdin)
results = data.get('data', {}).get('result', [])
if results:
    print(results[0].get('value', [None, '0'])[1])
else:
    print('N/A')
" 2>/dev/null || echo "N/A"
}

prom_query_count() {
  local query="$1"
  curl -sf --max-time 10 "${PROMETHEUS_URL}/api/v1/query" \
    --data-urlencode "query=${query}" 2>/dev/null \
    | python3 -c "
import sys, json
data = json.load(sys.stdin)
results = data.get('data', {}).get('result', [])
print(len(results))
" 2>/dev/null || echo "0"
}

send_slack() {
  local text="$1"
  if [[ -n "${SLACK_WEBHOOK_URL}" ]]; then
    curl -sf --max-time 10 -X POST "${SLACK_WEBHOOK_URL}" \
      -H "Content-Type: application/json" \
      -d "{\"text\":\"${text}\"}" >/dev/null 2>&1 || true
  fi
}

check_k8s_health() {
  local unhealthy=0

  local services=(api-gateway auth-service config-service ingest-service inference-worker aggregator reporting-api notification-service)
  for svc in "${services[@]}"; do
    local ready desired
    desired=$(kubectl get deployment "greyeye-${svc}" -n "${K8S_NAMESPACE}" \
      -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
    ready=$(kubectl get deployment "greyeye-${svc}" -n "${K8S_NAMESPACE}" \
      -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")

    if [[ "$ready" != "$desired" ]]; then
      log "  WARN: ${svc} ${ready}/${desired} ready"
      unhealthy=$((unhealthy + 1))
    fi
  done

  local restarts
  restarts=$(kubectl get pods -n "${K8S_NAMESPACE}" \
    -o jsonpath='{range .items[*]}{.status.containerStatuses[0].restartCount}{"\n"}{end}' 2>/dev/null \
    | awk '{s+=$1} END {print s+0}')
  log "  Pod restarts total: ${restarts}"

  if [[ "$restarts" -gt 10 ]]; then
    log "  CRITICAL: Excessive pod restarts (${restarts})"
    unhealthy=$((unhealthy + 1))
  fi

  return $unhealthy
}

check_slo_metrics() {
  local violations=0

  # NFR-2: Inference latency p95 <= 1.5s
  local inference_p95
  inference_p95=$(prom_query 'histogram_quantile(0.95, rate(greyeye_inference_duration_seconds_bucket{stage="total"}[15m]))')
  log "  Inference p95 latency: ${inference_p95}s (SLO: <=1.5s)"
  if [[ "$inference_p95" != "N/A" ]] && (( $(echo "$inference_p95 > 1.5" | bc -l 2>/dev/null || echo 0) )); then
    log "  VIOLATION: Inference latency exceeds SLO"
    violations=$((violations + 1))
  fi

  # NFR-1: Live KPI refresh <= 2s
  local kpi_p95
  kpi_p95=$(prom_query 'histogram_quantile(0.95, rate(greyeye_live_kpi_push_duration_seconds_bucket[15m]))')
  log "  Live KPI p95 latency: ${kpi_p95}s (SLO: <=2s)"
  if [[ "$kpi_p95" != "N/A" ]] && (( $(echo "$kpi_p95 > 2.0" | bc -l 2>/dev/null || echo 0) )); then
    log "  VIOLATION: KPI refresh exceeds SLO"
    violations=$((violations + 1))
  fi

  # 5xx error rate < 1%
  local error_rate
  error_rate=$(prom_query 'sum(rate(http_requests_total{status=~"5..", job=~"greyeye-.*"}[15m])) / sum(rate(http_requests_total{job=~"greyeye-.*"}[15m]))')
  log "  5xx error rate: ${error_rate} (SLO: <1%)"
  if [[ "$error_rate" != "N/A" ]] && (( $(echo "$error_rate > 0.01" | bc -l 2>/dev/null || echo 0) )); then
    log "  VIOLATION: Error rate exceeds SLO"
    violations=$((violations + 1))
  fi

  # NATS consumer lag
  local max_pending
  max_pending=$(prom_query 'max(nats_consumer_num_pending)')
  log "  Max NATS consumer pending: ${max_pending}"

  # Aggregation bucket lag
  local bucket_lag
  bucket_lag=$(prom_query 'max(greyeye_aggregation_bucket_lag_seconds)')
  log "  Aggregation bucket lag: ${bucket_lag}s"

  # Active alerts
  local firing_alerts
  firing_alerts=$(prom_query_count 'ALERTS{alertstate="firing", severity="critical"}')
  log "  Firing critical alerts: ${firing_alerts}"
  if [[ "$firing_alerts" -gt 0 ]]; then
    log "  VIOLATION: Critical alerts are firing"
    violations=$((violations + 1))
  fi

  return $violations
}

# ── Banner ──────────────────────────────────────────────────────────────────
echo "══════════════════════════════════════════════════════════════"
echo "  GreyEye 24h Burn-In Monitor"
echo "  API:        ${API_BASE_URL}"
echo "  Prometheus: ${PROMETHEUS_URL}"
echo "  Duration:   ${DURATION_HOURS}h (${TOTAL_CHECKS} checks @ ${INTERVAL_MINUTES}m)"
echo "  Log:        ${LOG_FILE}"
echo "  Started:    $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "══════════════════════════════════════════════════════════════"
echo ""

send_slack ":rocket: GreyEye burn-in monitor started — ${DURATION_HOURS}h window, checking every ${INTERVAL_MINUTES}m"

# ── Main Loop ───────────────────────────────────────────────────────────────
while [[ $(date +%s) -lt $END_TIME ]]; do
  TOTAL_ITERATIONS=$((TOTAL_ITERATIONS + 1))
  ELAPSED_HOURS=$(( ( $(date +%s) - START_TIME ) / 3600 ))
  REMAINING_HOURS=$(( (END_TIME - $(date +%s)) / 3600 ))

  log ""
  log "━━━ Check ${TOTAL_ITERATIONS}/${TOTAL_CHECKS} (${ELAPSED_HOURS}h elapsed, ${REMAINING_HOURS}h remaining) ━━━"

  # 1. Smoke test
  log "Running smoke tests..."
  if API_BASE_URL="${API_BASE_URL}" \
     SMOKE_TEST_PASSWORD="${SMOKE_TEST_PASSWORD}" \
     CLEANUP="true" \
     bash "${SCRIPT_DIR}/production-smoke-test.sh" >> "$LOG_FILE" 2>&1; then
    log "  Smoke tests: PASSED"
  else
    log "  Smoke tests: FAILED"
    CRITICAL_FAILURES=$((CRITICAL_FAILURES + 1))
    send_slack ":red_circle: Burn-in check ${TOTAL_ITERATIONS}: Smoke tests FAILED (${ELAPSED_HOURS}h in)"
  fi

  # 2. Kubernetes health
  log "Checking Kubernetes health..."
  if check_k8s_health; then
    log "  K8s health: OK"
  else
    log "  K8s health: DEGRADED"
    send_slack ":warning: Burn-in check ${TOTAL_ITERATIONS}: K8s health degraded"
  fi

  # 3. SLO metrics
  log "Checking SLO metrics..."
  if check_slo_metrics; then
    log "  SLO compliance: OK"
  else
    log "  SLO compliance: VIOLATIONS DETECTED"
    CRITICAL_FAILURES=$((CRITICAL_FAILURES + 1))
    send_slack ":red_circle: Burn-in check ${TOTAL_ITERATIONS}: SLO violations detected"
  fi

  # Abort if too many critical failures
  if [[ "$CRITICAL_FAILURES" -ge 5 ]]; then
    log ""
    log "ABORTING: ${CRITICAL_FAILURES} critical failures exceeded threshold (5)."
    send_slack ":rotating_light: Burn-in ABORTED after ${CRITICAL_FAILURES} critical failures at ${ELAPSED_HOURS}h. Investigate immediately."
    exit 1
  fi

  # Periodic status update every 4 checks (~1h)
  if (( TOTAL_ITERATIONS % 4 == 0 )); then
    send_slack ":white_check_mark: Burn-in status: ${ELAPSED_HOURS}h elapsed, ${CRITICAL_FAILURES} failures so far (check ${TOTAL_ITERATIONS}/${TOTAL_CHECKS})"
  fi

  log "Sleeping ${INTERVAL_MINUTES}m until next check..."
  sleep $(( INTERVAL_MINUTES * 60 ))
done

# ── Final Summary ───────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  Burn-In Complete"
echo "  Duration:          ${DURATION_HOURS}h"
echo "  Total checks:      ${TOTAL_ITERATIONS}"
echo "  Critical failures: ${CRITICAL_FAILURES}"
echo "  Log:               ${LOG_FILE}"
echo "  Finished:          $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "══════════════════════════════════════════════════════════════"

if [[ "$CRITICAL_FAILURES" -gt 0 ]]; then
  send_slack ":warning: Burn-in completed with ${CRITICAL_FAILURES} critical failures over ${DURATION_HOURS}h. Review required before GA."
  exit 1
fi

send_slack ":tada: Burn-in completed successfully — ${DURATION_HOURS}h, ${TOTAL_ITERATIONS} checks, zero critical failures. Production is GO."
exit 0
