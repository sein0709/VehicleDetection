# P2: DDoS Attack

**Severity:** P2 — High
**Response time:** 1 hour
**Incident commander:** On-call SRE

## Detection

- Monitoring alert: request rate spike, elevated 429 responses
- WAF metrics: rate limit rule triggered at high volume
- Service degradation: increased latency, 503 errors

## Immediate Actions (0-15 min)

### 1. Confirm Attack Pattern

```bash
# Check WAF metrics
aws wafv2 get-sampled-requests \
  --web-acl-arn $WAF_ACL_ARN \
  --rule-metric-name "greyeye-waf-rate-limit" \
  --scope REGIONAL \
  --time-window StartTime=$(date -u -d '15 minutes ago' +%s),EndTime=$(date -u +%s) \
  --max-items 100

# Check nginx rate limit logs
kubectl logs -n greyeye-api deploy/api-gateway --since=15m | \
  grep "limiting requests"
```

### 2. Escalate WAF Rate Limits

```bash
# Reduce WAF rate limit temporarily
aws wafv2 update-web-acl ... --rules '[
  {"Name": "rate-limit-global", "Priority": 60,
   "Statement": {"RateBasedStatement": {"Limit": 500, "AggregateKeyType": "IP"}},
   "Action": {"Block": {}}, ...}
]'
```

### 3. Scale API Gateway

```bash
kubectl scale -n greyeye-api deploy/api-gateway --replicas=5
```

### 4. Enable Cloud DDoS Protection

```bash
# AWS Shield Advanced (if available)
aws shield create-protection \
  --name greyeye-api-ddos \
  --resource-arn $ALB_ARN
```

## Investigation

### 5. Identify Attack Sources

```bash
# Top IPs by request count from WAF logs
aws logs filter-log-events \
  --log-group-name "aws-waf-logs-greyeye" \
  --filter-pattern "{ $.action = \"BLOCK\" }" \
  --start-time $(date -u -d '1 hour ago' +%s000) | \
  jq -r '.events[].message' | jq -r '.httpRequest.clientIp' | \
  sort | uniq -c | sort -rn | head -20
```

### 6. Block Specific IPs (if targeted)

```bash
# Add IP set to WAF
aws wafv2 create-ip-set \
  --name "greyeye-blocked-ips" \
  --scope REGIONAL \
  --ip-address-version IPV4 \
  --addresses "1.2.3.4/32" "5.6.7.8/32"
```

## Recovery

### 7. Monitor Service Health

```bash
# Watch error rates
kubectl top pods -n greyeye-api
kubectl get hpa -n greyeye-api
```

### 8. Restore Normal Limits

After attack subsides (30+ min of normal traffic):
- Restore WAF rate limits to default
- Scale down API gateway replicas
- Remove temporary IP blocks (keep persistent offenders)

## Post-Mortem

- [ ] Document attack pattern (volume, duration, source distribution)
- [ ] Review rate limit thresholds
- [ ] Consider geographic blocking if attack was region-specific
- [ ] Update WAF rules based on attack signatures
