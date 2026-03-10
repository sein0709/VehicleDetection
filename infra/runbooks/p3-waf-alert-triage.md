# P3: WAF Alert Triage

**Severity:** P3 — Medium
**Response time:** 4 hours
**Owner:** Security team

## Detection

- CloudWatch alarm: WAF block count exceeds threshold
- SIEM correlation: WAF events from same source as other suspicious activity

## Triage Steps

### 1. Review Blocked Requests

```bash
aws logs filter-log-events \
  --log-group-name "aws-waf-logs-greyeye" \
  --filter-pattern "{ $.action = \"BLOCK\" }" \
  --start-time $(date -u -d '4 hours ago' +%s000) | \
  jq '.events[].message | fromjson | {
    timestamp: .timestamp,
    action: .action,
    clientIp: .httpRequest.clientIp,
    uri: .httpRequest.uri,
    ruleId: .terminatingRuleId,
    country: .httpRequest.country
  }'
```

### 2. Classify the Traffic

| Pattern | Classification | Action |
|---------|---------------|--------|
| Automated scanning (sequential paths) | Reconnaissance | Monitor, consider IP block |
| SQL injection attempts | Attack | Block IP, review WAF rules |
| Single blocked request, legitimate user | False positive | Add exception rule |
| High volume from single IP | Brute force / DDoS | Escalate to P2 if sustained |

### 3. Check for False Positives

```bash
# Review COUNT (not BLOCK) rules for legitimate traffic being flagged
aws wafv2 get-sampled-requests \
  --web-acl-arn $WAF_ACL_ARN \
  --rule-metric-name "greyeye-waf-common" \
  --scope REGIONAL \
  --time-window StartTime=$(date -u -d '1 hour ago' +%s),EndTime=$(date -u +%s) \
  --max-items 50
```

### 4. Adjust Rules if Needed

For false positives, add rule exclusions:
```hcl
# In Terraform WAF module
rule_action_override {
  name = "GenericRFI_BODY"
  action_to_use { count {} }
}
```

## Escalation

Escalate to P2 if:
- Sustained attack (>30 min of high-volume blocks)
- Evidence of WAF bypass (blocked + successful requests from same source)
- Correlation with other security events (auth failures, RLS violations)
