# P2: API Key or Secret Leaked

**Severity:** P2 — High
**Response time:** 1 hour
**Incident commander:** On-call SRE

## Detection

- Secret scanning alert (gitleaks/trufflehog) in CI
- GitHub secret scanning notification
- External report of exposed credentials

## Immediate Actions (0-15 min)

### 1. Identify the Leaked Secret

Determine which secret was leaked:
- [ ] JWT signing key
- [ ] Database password
- [ ] S3 access key
- [ ] Redis password
- [ ] NATS credentials
- [ ] Supabase service role key
- [ ] Application encryption key (Fernet)
- [ ] SMTP credentials
- [ ] FCM/APNs push credentials

### 2. Rotate the Secret Immediately

See [general-secret-rotation.md](general-secret-rotation.md) for per-secret rotation procedures.

### 3. Scan for Unauthorized Usage

```bash
# Check audit logs for unusual activity
psql $DATABASE_URL -c "
  SELECT action, user_id, ip_address, created_at
  FROM audit_logs
  WHERE created_at > NOW() - INTERVAL '7 days'
    AND ip_address NOT IN (SELECT ip FROM known_service_ips)
  ORDER BY created_at DESC
  LIMIT 100;
"
```

### 4. Remove from Git History

```bash
# If committed to a branch (NOT main)
git filter-branch --force --index-filter \
  'git rm --cached --ignore-unmatch <file-with-secret>' \
  --prune-empty -- --all

# Force push (coordinate with team)
git push --force --all
```

## Investigation

### 5. Determine Exposure Window

- When was the secret committed?
- When was it discovered?
- Was the repository public during this window?

### 6. Run Full Secret Scan

```bash
gitleaks detect --source . --verbose --report-path gitleaks-report.json
```

## Post-Mortem

- [ ] Document how the secret was leaked
- [ ] Verify pre-commit hooks are installed for all contributors
- [ ] Review CI secret scanning configuration
- [ ] Add the leaked pattern to custom gitleaks rules
