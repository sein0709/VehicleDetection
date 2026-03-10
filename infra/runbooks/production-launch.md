# GreyEye — Production Launch Runbook

Checklist and procedures for deploying GreyEye to production. Each section must be completed in order. Sign-off is required before proceeding to the next phase.

---

## Pre-Launch Checklist (T-24h)

### Infrastructure Verification

- [ ] Terraform apply completed for production environment (`make tf-plan TF_ENV=production && make tf-apply`)
- [ ] EKS cluster healthy: all nodes `Ready`, GPU node pool autoscaling verified
- [ ] RDS instance running, DR replica connected with lag < 60s
- [ ] ElastiCache (Redis) cluster healthy, failover tested
- [ ] NATS JetStream cluster: 3 nodes, R=3 replication verified
- [ ] S3 buckets created with cross-region replication enabled
- [ ] DNS records configured: `api.greyeye.io`, `grafana.greyeye.io`, `prometheus.greyeye.io`
- [ ] TLS certificates provisioned and valid (check expiry > 30 days)
- [ ] WAF rules active and tested
- [ ] VPN/bastion access verified for on-call team

### Secrets & Configuration

- [ ] All secrets populated in AWS Secrets Manager (or K8s Secrets):
  - [ ] Database credentials
  - [ ] JWT signing key
  - [ ] Supabase service key
  - [ ] S3 access credentials
  - [ ] SMTP credentials
  - [ ] FCM/APNs push notification keys
  - [ ] PagerDuty service keys (platform + ML teams)
  - [ ] Slack webhook URLs
- [ ] ExternalSecrets operator syncing correctly
- [ ] Smoke test user (`smoke@greyeye.io`) created with appropriate role

### Database

- [ ] All migrations applied (`make migrate`)
- [ ] Seed data loaded (demo org, admin user)
- [ ] RLS policies verified with integration tests
- [ ] Connection pooling configured (PgBouncer or Supabase pooler)
- [ ] Backup schedule active: daily full (02:00 UTC), 6-hourly differential
- [ ] First full backup completed and verified

### Observability

- [ ] Prometheus scraping all service endpoints
- [ ] Alertmanager configured with PagerDuty + Slack receivers
- [ ] Alert rules loaded: `service-alerts.yml` + `backup-alerts.yml`
- [ ] Grafana dashboards provisioned (6 dashboards)
- [ ] Loki receiving structured logs from all services
- [ ] Tempo receiving traces (verify with a test request)
- [ ] On-call rotation configured in PagerDuty

### ML Models

- [ ] Detector model (ONNX) uploaded to `s3://greyeye-models-prod/detector/v1.0.0/model.onnx`
- [ ] Classifier model (ONNX) uploaded to `s3://greyeye-models-prod/classifier/v1.0.0/model.onnx`
- [ ] Models validated: `onnxruntime` inference test passed
- [ ] Evaluation metrics documented (mAP, per-class F1)

---

## Phase 1: Rolling Deploy (T-0)

### 1.1 Deploy Services

```bash
# Trigger production deploy workflow
gh workflow run deploy-production.yml \
  -f image_tag=<SHA> \
  -f dry_run=false
```

**Verification:**
- [ ] Approval gate passed (authorized deployer)
- [ ] Helm lint and template validation passed
- [ ] All 8 service images verified in registry
- [ ] `helm upgrade --atomic` completed without rollback
- [ ] All deployments show `Ready` replicas matching `Desired`

### 1.2 Verify Rollout

```bash
# Check all deployments
kubectl get deployments -n greyeye-production

# Check pod status
kubectl get pods -n greyeye-production -o wide

# Verify no crash loops
kubectl get events -n greyeye-production --sort-by=.lastTimestamp | tail -20
```

- [ ] All pods in `Running` state
- [ ] Zero `CrashLoopBackOff` events
- [ ] Readiness probes passing on all pods
- [ ] HPA active for all autoscaled services

### 1.3 Post-Deploy Smoke Tests

```bash
# Automated (runs in CI)
# Or manually:
bash infra/scripts/production-smoke-test.sh \
  --api-url https://api.greyeye.io \
  --password "${SMOKE_TEST_PASSWORD}"
```

- [ ] All health endpoints return 200
- [ ] Response time < 2s
- [ ] Auth flow succeeds (login, token refresh)
- [ ] Site creation and retrieval works
- [ ] Camera registration works
- [ ] Analytics endpoint responds
- [ ] Metrics endpoints accessible

---

## Phase 2: Canary ML Model Deploy (T+30m)

### 2.1 Deploy Detector Model

```bash
gh workflow run canary-model-deploy.yml \
  -f model_version=detector-v1.0.0 \
  -f model_type=detector \
  -f model_s3_path=s3://greyeye-models-prod/detector/v1.0.0/model.onnx \
  -f target_environment=production
```

- [ ] Model artifact validated (ONNX load + dummy inference)
- [ ] 10% canary: 5-min monitoring passed, no excessive restarts
- [ ] 50% canary: 5-min monitoring passed
- [ ] 100% rollout: all inference workers running new model
- [ ] Final health check: all workers ready

### 2.2 Deploy Classifier Model

```bash
gh workflow run canary-model-deploy.yml \
  -f model_version=classifier-v1.0.0 \
  -f model_type=classifier \
  -f model_s3_path=s3://greyeye-models-prod/classifier/v1.0.0/model.onnx \
  -f target_environment=production
```

- [ ] Same canary progression as detector (10% → 50% → 100%)
- [ ] Classification accuracy spot-check on live traffic

### 2.3 Verify Inference Pipeline

```bash
# Check inference metrics in Grafana
# Dashboard: GreyEye — Inference Pipeline
```

- [ ] Inference latency p95 < 1.5s
- [ ] Detection confidence mean > 0.5
- [ ] Classification class-flip rate < 15%
- [ ] No DLQ messages in NATS

---

## Phase 3: Enable Alerting (T+1h)

### 3.1 Verify Alert Rules

```bash
# Check Prometheus alert rules are loaded
curl -s https://prometheus.greyeye.io/api/v1/rules | python3 -m json.tool | head -50

# Check Alertmanager is receiving alerts
curl -s https://prometheus.greyeye.io/api/v1/alerts | python3 -m json.tool
```

- [ ] All rule groups loaded: `greyeye-inference`, `greyeye-api`, `greyeye-gateway`, `greyeye-nats`, `greyeye-aggregation`, `greyeye-database`, `greyeye-redis`, `greyeye-cameras`, `greyeye-notifications`, `greyeye-pods`, `greyeye-backup`
- [ ] Alertmanager healthy and connected to Prometheus
- [ ] Test alert delivered to Slack `#greyeye-alerts`
- [ ] Test alert delivered to PagerDuty (resolve immediately)

### 3.2 Verify Notification Channels

- [ ] Slack integration: messages appearing in `#greyeye-incidents`, `#greyeye-alerts`, `#greyeye-operations`
- [ ] PagerDuty integration: incidents created and auto-resolved
- [ ] Email delivery: test email received (if configured)

---

## Phase 4: 24-Hour Burn-In (T+1h to T+25h)

### 4.1 Start Burn-In Monitor

```bash
# Via GitHub Actions
gh workflow run burn-in.yml \
  -f duration_hours=24 \
  -f interval_minutes=15

# Or manually
bash infra/scripts/burn-in-monitor.sh \
  --duration 24 --interval 15
```

### 4.2 Monitoring During Burn-In

Check Grafana dashboards periodically:

| Dashboard | Key Metrics | Threshold |
|-----------|------------|-----------|
| System Overview | Service availability, pod restarts | 100% up, 0 restarts |
| Inference Pipeline | p95 latency, error rate, GPU util | <1.5s, <1%, <90% |
| Traffic Analytics | Crossing events/min, class distribution | Non-zero, reasonable |
| Database | Connection pool, query latency, replication lag | <85%, <100ms, <60s |
| Alerts & Notifications | Delivery success rate, rule eval time | >99%, <5s |
| Backup & DR | Backup freshness, DR lag | <26h, <300s |

### 4.3 Burn-In Exit Criteria

All of the following must be true for 24 consecutive hours:

- [ ] Zero critical Prometheus alerts firing
- [ ] Inference p95 latency consistently < 1.5s
- [ ] Live KPI refresh p95 < 2s
- [ ] 5xx error rate < 0.1%
- [ ] No pod crash loops (total restarts < 5)
- [ ] NATS consumer lag < 1000 messages
- [ ] Aggregation bucket lag < 120s
- [ ] Database connection pool < 85%
- [ ] All smoke test checks passing every 15 minutes

---

## Phase 5: Go / No-Go Decision (T+25h)

### Sign-Off Required From

- [ ] **Platform Lead**: Infrastructure stable, observability complete
- [ ] **ML Lead**: Models performing within spec, no drift detected
- [ ] **Product Lead**: End-to-end user flows verified
- [ ] **Security Lead**: WAF active, audit logs flowing, no anomalies

### Go Decision

If all burn-in criteria met and sign-offs obtained:

1. [ ] Update DNS TTL back to normal (from reduced TTL during launch)
2. [ ] Enable production mobile app endpoint in app config
3. [ ] Notify stakeholders: production is live
4. [ ] Archive burn-in logs

### No-Go Decision

If burn-in criteria not met:

1. [ ] Document failures and root causes
2. [ ] Rollback if necessary: `helm rollback greyeye -n greyeye-production`
3. [ ] Schedule post-mortem
4. [ ] Plan remediation and re-launch date

---

## Rollback Procedures

### Service Rollback

```bash
# Rollback to previous Helm revision
helm rollback greyeye -n greyeye-production --wait --timeout 10m

# Verify rollback
kubectl get deployments -n greyeye-production
```

### Model Rollback

```bash
# Remove canary environment variables
kubectl set env deployment/greyeye-inference-worker \
  -n greyeye-production \
  CANARY_WEIGHT- CANARY_MODEL_VERSION- CANARY_MODEL_S3_PATH- CANARY_MODEL_TYPE-

# Restart workers to reload previous model
kubectl rollout restart deployment/greyeye-inference-worker -n greyeye-production
```

### Database Rollback

```bash
# Only if schema migration caused issues
cd libs/db_models && uv run alembic downgrade -1
```

---

## Emergency Contacts

| Role | Contact | Escalation |
|------|---------|-----------|
| Platform On-Call | PagerDuty rotation | Slack #greyeye-incidents |
| ML On-Call | PagerDuty rotation | Slack #greyeye-incidents |
| Database Admin | (team-specific) | Direct page |
| Security | (team-specific) | Direct page for P1 |
