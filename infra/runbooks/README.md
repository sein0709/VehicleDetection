# GreyEye Incident Response Runbooks

Operational runbooks for security incidents and common operational scenarios.
Severity levels follow the P1-P4 classification from the security design doc.

| Level | Response Time | Examples |
|-------|:------------:|---------|
| P1 — Critical | 15 minutes | Data breach, complete outage, active exploitation |
| P2 — High | 1 hour | Sustained attack, WAF bypass, single-service compromise |
| P3 — Medium | 4 hours | Security anomaly, failed penetration, config drift |
| P4 — Low | 24 hours | Outdated dependency CVE, log anomaly |

## Runbooks

- [P1: Compromised Credentials](p1-compromised-credentials.md)
- [P1: Database Breach](p1-database-breach.md)
- [P2: DDoS Attack](p2-ddos-attack.md)
- [P2: API Key Leak](p2-api-key-leak.md)
- [P3: WAF Alert Triage](p3-waf-alert-triage.md)
- [General: Secret Rotation](general-secret-rotation.md)

## Communication Protocol

| Audience | Channel | Timing |
|----------|---------|--------|
| Incident response team | PagerDuty + Slack #greyeye-incidents | Immediate |
| Engineering leadership | Email + Slack | Within 1 hour (P1/P2) |
| Affected org admins | In-app notification + email | Within 24 hours (if data affected) |
| Regulatory bodies | Formal notification | Within 72 hours (if PII breach, per GDPR/PIPA) |
