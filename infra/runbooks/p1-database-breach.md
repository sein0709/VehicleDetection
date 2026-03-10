# P1: Database Breach Suspected

**Severity:** P1 — Critical
**Response time:** 15 minutes
**Incident commander:** On-call SRE + Database Admin

## Detection

- SIEM alert: anomalous query patterns
- RLS violation events in security logs
- Unexpected data export activity
- External vulnerability disclosure

## Immediate Actions (0-15 min)

### 1. Enable Enhanced Logging

```bash
psql $DATABASE_URL -c "
  ALTER SYSTEM SET log_statement = 'all';
  ALTER SYSTEM SET log_min_duration_statement = 0;
  SELECT pg_reload_conf();
"
```

### 2. Snapshot Current State

```bash
# Create immediate backup
kubectl exec -n greyeye-data deploy/pgbackrest -- \
  pgbackrest backup --stanza=greyeye --type=full --annotation="incident-snapshot"
```

### 3. Check RLS Policy Effectiveness

```bash
psql $DATABASE_URL -c "
  SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
  FROM pg_policies
  WHERE tablename IN ('users', 'organizations', 'sites', 'cameras',
                       'vehicle_crossings', 'audit_logs')
  ORDER BY tablename, policyname;
"
```

### 4. Review Recent Connections

```bash
psql $DATABASE_URL -c "
  SELECT usename, client_addr, backend_start, state, query
  FROM pg_stat_activity
  WHERE datname = 'greyeye'
  ORDER BY backend_start DESC;
"
```

## Investigation (15-60 min)

### 5. Analyze Query Logs

```bash
# Check for suspicious queries (cross-tenant, bulk export, schema inspection)
grep -E "(information_schema|pg_catalog|COPY|pg_dump)" /var/log/postgresql/*.log
```

### 6. Check for Data Exfiltration

```bash
psql $DATABASE_URL -c "
  SELECT * FROM audit_logs
  WHERE action IN ('data.exported', 'report.exported')
    AND created_at > NOW() - INTERVAL '24 hours'
  ORDER BY created_at DESC;
"
```

### 7. Verify Data Integrity

```bash
# Check row counts against known baselines
psql $DATABASE_URL -c "
  SELECT 'organizations' as tbl, count(*) FROM organizations
  UNION ALL SELECT 'users', count(*) FROM users
  UNION ALL SELECT 'sites', count(*) FROM sites
  UNION ALL SELECT 'cameras', count(*) FROM cameras;
"
```

## Remediation

### 8. Rotate Database Credentials

```bash
# Generate new password
NEW_PASS=$(openssl rand -base64 32)

# Update in database
psql $DATABASE_URL -c "ALTER USER greyeye_app PASSWORD '$NEW_PASS';"

# Update Kubernetes secret
kubectl create secret generic greyeye-db-credentials \
  --from-literal=password="$NEW_PASS" \
  --from-literal=connection-string="postgresql://greyeye_app:$NEW_PASS@..." \
  --dry-run=client -o yaml | kubectl apply -f -

# Rolling restart all services
kubectl rollout restart -n greyeye-api deploy
kubectl rollout restart -n greyeye-processing deploy
```

### 9. Patch Vulnerability

If an application vulnerability was exploited:
- Deploy hotfix
- Add WAF rule to block the attack vector
- Update RLS policies if bypass was found

## Post-Mortem

- [ ] Document timeline and attack vector
- [ ] Verify no data was exfiltrated
- [ ] Review and strengthen RLS policies
- [ ] File compliance notification (72h for PII breach)
- [ ] Schedule penetration test
