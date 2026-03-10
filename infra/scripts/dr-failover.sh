#!/usr/bin/env bash
###############################################################################
# GreyEye — DR Failover Script
#
# Promotes the DR cross-region replica to a standalone primary and redirects
# traffic to the DR region. Per docs/07-backup-and-recovery.md Section 8.
#
# Prerequisites:
#   - AWS CLI configured with appropriate IAM permissions
#   - kubectl configured for both primary and DR clusters
#   - Route 53 hosted zone for the domain
#
# Usage:
#   ./dr-failover.sh [--dry-run]
#
# Target: ≤ 49 minutes total failover time
###############################################################################

set -euo pipefail

PRIMARY_REGION="${PRIMARY_REGION:-ap-northeast-2}"
DR_REGION="${DR_REGION:-ap-northeast-1}"
NAME_PREFIX="${NAME_PREFIX:-greyeye-production}"
DR_REPLICA_ID="${DR_REPLICA_ID:-${NAME_PREFIX}-postgres-dr}"
DOMAIN="${DOMAIN:-greyeye.io}"
API_SUBDOMAIN="${API_SUBDOMAIN:-api}"
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
log "GreyEye DR Failover"
log "Primary: ${PRIMARY_REGION} → DR: ${DR_REGION}"
log "=========================================="

# Step 1: Verify DR replica status
log "Step 1/9: Checking DR replica status..."
REPLICA_STATUS=$(aws rds describe-db-instances \
  --region "$DR_REGION" \
  --db-instance-identifier "$DR_REPLICA_ID" \
  --query 'DBInstances[0].DBInstanceStatus' \
  --output text)

if [[ "$REPLICA_STATUS" != "available" ]]; then
  fail "DR replica status is '${REPLICA_STATUS}', expected 'available'"
fi

REPLICA_LAG=$(aws cloudwatch get-metric-statistics \
  --region "$DR_REGION" \
  --namespace AWS/RDS \
  --metric-name ReplicaLag \
  --dimensions "Name=DBInstanceIdentifier,Value=${DR_REPLICA_ID}" \
  --start-time "$(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-10M +%Y-%m-%dT%H:%M:%SZ)" \
  --end-time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --period 300 \
  --statistics Maximum \
  --query 'Datapoints[0].Maximum' \
  --output text 2>/dev/null || echo "unknown")

log "  DR replica: ${REPLICA_STATUS}, lag: ${REPLICA_LAG}s"

# Step 2: Stop writes to primary (if reachable)
log "Step 2/9: Attempting to stop writes on primary..."
if [[ "$DRY_RUN" != "--dry-run" ]]; then
  kubectl --context "${PRIMARY_K8S_CONTEXT:-}" scale deployment --all --replicas=0 \
    -n greyeye-api -n greyeye-processing 2>/dev/null || \
    log "  WARNING: Could not reach primary cluster (may already be down)"
fi

# Step 3: Promote DR replica
log "Step 3/9: Promoting DR replica to standalone primary..."
confirm "aws rds promote-read-replica --region ${DR_REGION} --db-instance-identifier ${DR_REPLICA_ID}"
if [[ "$DRY_RUN" != "--dry-run" ]]; then
  aws rds promote-read-replica \
    --region "$DR_REGION" \
    --db-instance-identifier "$DR_REPLICA_ID"
fi

# Step 4: Wait for promotion
log "Step 4/9: Waiting for DR replica promotion to complete..."
if [[ "$DRY_RUN" != "--dry-run" ]]; then
  aws rds wait db-instance-available \
    --region "$DR_REGION" \
    --db-instance-identifier "$DR_REPLICA_ID"
fi
log "  DR database promoted successfully"

# Step 5: Update DR K8s ConfigMaps with new DB endpoint
DR_ENDPOINT=$(aws rds describe-db-instances \
  --region "$DR_REGION" \
  --db-instance-identifier "$DR_REPLICA_ID" \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text)

log "Step 5/9: Updating DR K8s configuration (DB endpoint: ${DR_ENDPOINT})..."
if [[ "$DRY_RUN" != "--dry-run" ]]; then
  kubectl --context "$DR_K8S_CONTEXT" create configmap greyeye-dr-db-override \
    --from-literal=host="$DR_ENDPOINT" \
    --from-literal=port="5432" \
    -n greyeye-data --dry-run=client -o yaml | \
    kubectl --context "$DR_K8S_CONTEXT" apply -f -
fi

# Step 6: Scale up DR K8s workloads
log "Step 6/9: Scaling up DR region workloads..."
if [[ "$DRY_RUN" != "--dry-run" ]]; then
  kubectl --context "$DR_K8S_CONTEXT" scale deployment --all --replicas=2 -n greyeye-api
  kubectl --context "$DR_K8S_CONTEXT" scale deployment --all --replicas=2 -n greyeye-processing
fi

# Step 7: Update S3 endpoints in DR workloads
log "Step 7/9: Updating S3 endpoints to DR region buckets..."
if [[ "$DRY_RUN" != "--dry-run" ]]; then
  kubectl --context "$DR_K8S_CONTEXT" create configmap greyeye-dr-s3-override \
    --from-literal=endpoint="https://s3.${DR_REGION}.amazonaws.com" \
    --from-literal=bucket-frames="${NAME_PREFIX}-frames-dr" \
    --from-literal=bucket-backups="${NAME_PREFIX}-backups-dr" \
    -n greyeye-data --dry-run=client -o yaml | \
    kubectl --context "$DR_K8S_CONTEXT" apply -f -
fi

# Step 8: Update DNS to point to DR region
log "Step 8/9: Updating DNS to DR region..."
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
  --dns-name "$DOMAIN" \
  --query 'HostedZones[0].Id' \
  --output text | sed 's|/hostedzone/||')

if [[ "$DRY_RUN" != "--dry-run" ]]; then
  DR_LB_HOSTNAME=$(kubectl --context "$DR_K8S_CONTEXT" get svc -n greyeye-api \
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
          \"ResourceRecords\": [{\"Value\": \"${DR_LB_HOSTNAME}\"}]
        }
      }]
    }"
fi

# Step 9: Smoke test
log "Step 9/9: Running smoke tests..."
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
log "DR FAILOVER COMPLETE"
log "  New primary DB: ${DR_ENDPOINT:-<dry-run>}"
log "  DNS updated:    ${API_SUBDOMAIN}.${DOMAIN} → DR region"
log "=========================================="
log ""
log "POST-FAILOVER CHECKLIST:"
log "  [ ] Verify all API endpoints respond correctly"
log "  [ ] Check Grafana dashboards for error rates"
log "  [ ] Notify stakeholders of failover"
log "  [ ] Begin root cause analysis on primary region"
log "  [ ] Plan failback once primary is restored"
