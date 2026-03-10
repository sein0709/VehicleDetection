# P1: Compromised User or Service Credentials

**Severity:** P1 — Critical
**Response time:** 15 minutes
**Incident commander:** On-call SRE

## Detection

- SIEM alert: multiple failed logins followed by successful login from unusual IP
- Security event: `auth.refresh_token_reuse` (token theft detected)
- External report: user reports unauthorized access
- Audit log: unexpected admin actions

## Immediate Actions (0-15 min)

### 1. Assess Scope

```bash
# Identify the affected user
kubectl exec -n greyeye-api deploy/auth-service -- \
  python -c "from auth_service.supabase_client import *; ..."

# Check recent audit logs for the user
psql $DATABASE_URL -c "
  SELECT action, entity_type, ip_address, created_at
  FROM audit_logs
  WHERE user_id = '<USER_ID>'
  ORDER BY created_at DESC
  LIMIT 50;
"
```

### 2. Revoke All Tokens

```bash
# Revoke all refresh tokens for the user
kubectl exec -n greyeye-api deploy/auth-service -- \
  python -m auth_service.cli revoke-all-tokens --user-id <USER_ID>

# Add all active JTIs to the deny list
kubectl exec -n greyeye-api deploy/auth-service -- \
  python -m auth_service.cli deny-all-jtis --user-id <USER_ID>
```

### 3. Lock the Account

```bash
psql $DATABASE_URL -c "
  UPDATE users SET is_active = false WHERE id = '<USER_ID>';
"
```

### 4. Force Password Reset

```bash
kubectl exec -n greyeye-api deploy/auth-service -- \
  python -m auth_service.cli force-password-reset --user-id <USER_ID>
```

## Investigation (15-60 min)

### 5. Review Audit Trail

```bash
# All actions by the compromised user in the last 24h
psql $DATABASE_URL -c "
  SELECT action, entity_type, entity_id, ip_address, user_agent, created_at
  FROM audit_logs
  WHERE user_id = '<USER_ID>'
    AND created_at > NOW() - INTERVAL '24 hours'
  ORDER BY created_at;
"
```

### 6. Check for Data Exfiltration

```bash
# Report exports by the user
psql $DATABASE_URL -c "
  SELECT * FROM audit_logs
  WHERE user_id = '<USER_ID>'
    AND action IN ('report.exported', 'data.exported', 'shared_link.created')
  ORDER BY created_at DESC;
"
```

### 7. Check for Privilege Escalation

```bash
psql $DATABASE_URL -c "
  SELECT * FROM audit_logs
  WHERE user_id = '<USER_ID>'
    AND action IN ('user.role_changed', 'user.invited')
  ORDER BY created_at DESC;
"
```

## Remediation

### 8. Revert Unauthorized Changes

Based on audit log findings, revert any unauthorized:
- Role changes
- Site/camera configuration changes
- Alert rule modifications
- Shared report links

### 9. Notify Affected Organization

```
Subject: Security Incident — Unauthorized Access Detected
Body: We detected unauthorized access to your GreyEye account...
```

### 10. Rotate Affected Secrets

If the compromised user had admin access:
- Rotate JWT signing key (see general-secret-rotation.md)
- Rotate any API keys the user had access to

## Post-Mortem

- [ ] Document timeline of events
- [ ] Identify root cause (phishing, credential reuse, etc.)
- [ ] Update brute-force detection thresholds if needed
- [ ] Review and update this runbook
- [ ] File compliance notification if PII was accessed (72h deadline)
