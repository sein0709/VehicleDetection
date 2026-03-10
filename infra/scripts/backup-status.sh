#!/usr/bin/env bash
###############################################################################
# GreyEye — Backup Status Report
#
# Queries pgBackRest and AWS to produce a human-readable backup status report.
#
# Usage:
#   ./backup-status.sh [--json]
###############################################################################

set -euo pipefail

NAME_PREFIX="${NAME_PREFIX:-greyeye-production}"
PRIMARY_REGION="${PRIMARY_REGION:-ap-northeast-2}"
DR_REGION="${DR_REGION:-ap-northeast-1}"
DR_REPLICA_ID="${DR_REPLICA_ID:-${NAME_PREFIX}-postgres-dr}"
OUTPUT_FORMAT="${1:-text}"
K8S_NAMESPACE="${K8S_NAMESPACE:-greyeye-data}"

log() { echo "$*"; }
header() { echo ""; echo "=== $* ==="; }

# ── pgBackRest Info ──────────────────────────────────────────────────────────

get_pgbackrest_info() {
  local pod
  pod=$(kubectl get pods -n "$K8S_NAMESPACE" \
    -l app.kubernetes.io/name=pgbackrest \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

  if [[ -z "$pod" ]]; then
    echo "  pgBackRest pod not found. Checking CronJob history..."
    kubectl get jobs -n "$K8S_NAMESPACE" \
      -l app.kubernetes.io/name=pgbackrest \
      --sort-by=.metadata.creationTimestamp \
      -o custom-columns='NAME:.metadata.name,STATUS:.status.conditions[0].type,COMPLETED:.status.completionTime' \
      2>/dev/null | tail -10 || echo "  No backup jobs found"
    return
  fi

  kubectl exec -n "$K8S_NAMESPACE" "$pod" -- \
    pgbackrest --stanza=greyeye info 2>/dev/null || echo "  Could not retrieve pgBackRest info"
}

# ── RDS Backup Status ────────────────────────────────────────────────────────

get_rds_backup_info() {
  aws rds describe-db-instances \
    --region "$PRIMARY_REGION" \
    --db-instance-identifier "${NAME_PREFIX}-postgres" \
    --query 'DBInstances[0].{
      Status: DBInstanceStatus,
      MultiAZ: MultiAZ,
      BackupRetention: BackupRetentionPeriod,
      LatestRestoreTime: LatestRestorableTime,
      BackupWindow: PreferredBackupWindow
    }' \
    --output table 2>/dev/null || echo "  Could not query RDS"
}

# ── DR Replica Status ────────────────────────────────────────────────────────

get_dr_status() {
  aws rds describe-db-instances \
    --region "$DR_REGION" \
    --db-instance-identifier "$DR_REPLICA_ID" \
    --query 'DBInstances[0].{
      Status: DBInstanceStatus,
      ReplicaSourceDB: ReadReplicaSourceDBInstanceIdentifier,
      Endpoint: Endpoint.Address
    }' \
    --output table 2>/dev/null || echo "  DR replica not found (may not be enabled)"

  local lag
  lag=$(aws cloudwatch get-metric-statistics \
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
  echo "  Current replication lag: ${lag}s"
}

# ── S3 Replication Status ────────────────────────────────────────────────────

get_s3_replication_status() {
  for bucket in "${NAME_PREFIX}-frames" "${NAME_PREFIX}-backups" "${NAME_PREFIX}-models" "${NAME_PREFIX}-hard-examples"; do
    local status
    status=$(aws s3api get-bucket-replication \
      --region "$PRIMARY_REGION" \
      --bucket "$bucket" \
      --query 'ReplicationConfiguration.Rules[0].Status' \
      --output text 2>/dev/null || echo "Not configured")
    echo "  ${bucket}: ${status}"
  done
}

# ── Report ───────────────────────────────────────────────────────────────────

if [[ "$OUTPUT_FORMAT" == "--json" ]]; then
  echo '{"error": "JSON output not yet implemented. Use text format."}'
  exit 0
fi

echo "============================================"
echo "  GreyEye Backup & DR Status Report"
echo "  Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "============================================"

header "pgBackRest Backup Status"
get_pgbackrest_info

header "RDS Automated Backup Status"
get_rds_backup_info

header "DR Cross-Region Replica"
get_dr_status

header "S3 Cross-Region Replication"
get_s3_replication_status

header "Recent Backup Jobs (K8s)"
kubectl get jobs -n "$K8S_NAMESPACE" \
  -l "greyeye.io/backup-type" \
  --sort-by=.metadata.creationTimestamp \
  -o custom-columns='NAME:.metadata.name,TYPE:.metadata.labels.greyeye\.io/backup-type,STATUS:.status.conditions[0].type,START:.status.startTime,COMPLETED:.status.completionTime' \
  2>/dev/null | tail -15 || echo "  No backup jobs found"

echo ""
echo "============================================"
echo "  Report complete"
echo "============================================"
