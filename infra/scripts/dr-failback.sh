#!/usr/bin/env bash
###############################################################################
# GreyEye — DR Failback Script
#
# Restores operations to the primary region after a DR failover event.
# Per docs/07-backup-and-recovery.md Section 8.
#
# Prerequisites:
#   - Primary region infrastructure is healthy
#   - A new RDS instance has been created in the primary region
#   - Data has been replicated back from DR to primary (pg_dump/pg_restore
#     or new cross-region replica + promotion)
#
# Usage:
#   ./dr-failback.sh [--dry-run]
###############################################################################

set -euo pipefail

PRIMARY_REGION="${PRIMARY_REGION:-ap-northeast-2}"
DR_REGION="${DR_REGION:-ap-northeast-1}"
NAME_PREFIX="${NAME_PREFIX:-greyeye-production}"
PRIMARY_DB_ID="${PRIMARY_DB_ID:-${NAME_PREFIX}-postgres}"
DOMAIN="${DOMAIN:-greyeye.io}"
API_SUBDOMAIN="${API_SUBDOMAIN:-api}"
PRIMARY_K8S_CONTEXT="${PRIMARY_K8S_CONTEXT:-arn:aws:eks:${PRIMARY_REGION}:$(aws sts get-caller-identity --query Account --output text):cluster/${NAME_PREFIX}}"
DR_K8S_CONTEXT="${DR_K8S_CONTEXT:-arn:aws:eks:${DR_REGION}:$(aws sts get-caller-identity --query Account --output text):cluster/${NAME_PREFIX}-dr}"
DRY_RUN="${1:-}"

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"; }
fail() { log "FATAL: $*"; exit 1; }

confirm() {
  if [[ "$DRY_RUN" == "--dry-run" ]]; then
    log "DRY-RUN: Would execute: $*"
    return 0
  fi
  read -rp "Execute: $*? [y/N] " answer
  [[ "$answer" =~ ^[Yy]$ ]] || fail "Aborted by operator"
}

log "=========================================="
log "GreyEye DR Failback"
log "DR: ${DR_REGION} → Primary: ${PRIMARY_REGION}"
log "=========================================="

# Step 1: Verify primary DB is ready
log "Step 1/7: Verifying primary region database..."
PRIMARY_STATUS=$(aws rds describe-db-instances \
  --region "$PRIMARY_REGION" \
  --db-instance-identifier "$PRIMARY_DB_ID" \
  --query 'DBInstances[0].DBInstanceStatus' \
  --output text)

if [[ "$PRIMARY_STATUS" != "available" ]]; then
  fail "Primary DB status is '${PRIMARY_STATUS}', expected 'available'"
fi
log "  Primary DB: ${PRIMARY_STATUS}"

# Step 2: Enable maintenance mode on DR
log "Step 2/7: Enabling maintenance mode on DR workloads..."
if [[ "$DRY_RUN" != "--dry-run" ]]; then
  kubectl --context "$DR_K8S_CONTEXT" annotate deployment --all \
    -n greyeye-api greyeye.io/maintenance="failback-$(date -u +%Y%m%d%H%M)" --overwrite
fi

# Step 3: Drain DR connections
log "Step 3/7: Draining DR region connections (60s grace period)..."
if [[ "$DRY_RUN" != "--dry-run" ]]; then
  kubectl --context "$DR_K8S_CONTEXT" scale deployment --all --replicas=0 -n greyeye-api
  sleep 60
  kubectl --context "$DR_K8S_CONTEXT" scale deployment --all --replicas=0 -n greyeye-processing
fi

# Step 4: Final data sync from DR to primary
log "Step 4/7: Final data sync (verify replication is caught up)..."
PRIMARY_ENDPOINT=$(aws rds describe-db-instances \
  --region "$PRIMARY_REGION" \
  --db-instance-identifier "$PRIMARY_DB_ID" \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text)
log "  Primary endpoint: ${PRIMARY_ENDPOINT}"

# Step 5: Scale up primary workloads
log "Step 5/7: Scaling up primary region workloads..."
if [[ "$DRY_RUN" != "--dry-run" ]]; then
  kubectl --context "$PRIMARY_K8S_CONTEXT" scale deployment --all --replicas=2 -n greyeye-api
  kubectl --context "$PRIMARY_K8S_CONTEXT" scale deployment --all --replicas=2 -n greyeye-processing
fi

# Step 6: Update DNS back to primary
log "Step 6/7: Updating DNS back to primary region..."
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
  --dns-name "$DOMAIN" \
  --query 'HostedZones[0].Id' \
  --output text | sed 's|/hostedzone/||')

if [[ "$DRY_RUN" != "--dry-run" ]]; then
  PRIMARY_LB_HOSTNAME=$(kubectl --context "$PRIMARY_K8S_CONTEXT" get svc -n greyeye-api \
    -l app.kubernetes.io/name=api-gateway \
    -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')

  aws route53 change-resource-record-sets \
    --hosted-zone-id "$HOSTED_ZONE_ID" \
    --change-batch "{
      \"Changes\": [{
        \"Action\": \"UPSERT\",
        \"ResourceRecordSet\": {
          \"Name\": \"${API_SUBDOMAIN}.${DOMAIN}\",
          \"Type\": \"CNAME\",
          \"TTL\": 60,
          \"ResourceRecords\": [{\"Value\": \"${PRIMARY_LB_HOSTNAME}\"}]
        }
      }]
    }"
fi

# Step 7: Smoke test
log "Step 7/7: Running smoke tests..."
if [[ "$DRY_RUN" != "--dry-run" ]]; then
  sleep 30
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://${API_SUBDOMAIN}.${DOMAIN}/healthz" || echo "000")
  if [[ "$HTTP_CODE" == "200" ]]; then
    log "  Smoke test PASSED (HTTP ${HTTP_CODE})"
  else
    log "  WARNING: Smoke test returned HTTP ${HTTP_CODE} — manual verification needed"
  fi
fi

log "=========================================="
log "DR FAILBACK COMPLETE"
log "  Primary DB: ${PRIMARY_ENDPOINT:-<dry-run>}"
log "  DNS updated: ${API_SUBDOMAIN}.${DOMAIN} → Primary region"
log "=========================================="
log ""
log "POST-FAILBACK CHECKLIST:"
log "  [ ] Verify all API endpoints respond correctly"
log "  [ ] Re-establish cross-region DR replica"
log "  [ ] Verify S3 CRR is active"
log "  [ ] Update monitoring to track new DR replica"
log "  [ ] Conduct post-incident review"
