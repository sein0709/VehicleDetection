# GreyEye Traffic Analysis AI — Security and Compliance

## 1 Introduction

This document specifies the security architecture, access-control model, encryption strategy, privacy controls, and audit-logging design for GreyEye. It covers authentication, role-based authorization, transport and storage encryption, mobile device security, row-level security enforcement, privacy-by-design controls, immutable audit logging, and incident response. Together these controls protect multi-tenant data integrity, ensure regulatory compliance, and maintain user trust.

**Traceability:** FR-1.1, FR-1.2, FR-1.3, FR-1.4, NFR-13, NFR-14, SEC-1 through SEC-20, DM-4

---

## 2 Security Architecture Overview

GreyEye implements a **defense-in-depth** strategy with security controls at every layer of the stack: client device, network transport, API gateway, application services, and database.

```mermaid
graph TB
    subgraph client ["Client Tier — Mobile Device"]
        SecureStore["Keychain / Keystore<br/>(token storage)"]
        CertPin["Certificate Pinning<br/>(optional)"]
        RootDetect["Root / Jailbreak<br/>Detection"]
        AppSandbox["App Sandbox<br/>(no PII in logs)"]
    end

    subgraph network ["Network Tier"]
        TLS["TLS 1.2+ Everywhere"]
        WAF["WAF / IDS / IPS"]
        RateLimit["Rate Limiting<br/>(per IP, per user)"]
    end

    subgraph api ["API Tier"]
        JWT["JWT Validation"]
        RBAC["RBAC Enforcement"]
        StepUp["Step-Up Auth<br/>(admin actions)"]
        InputVal["Input Validation<br/>(Pydantic schemas)"]
    end

    subgraph data ["Data Tier"]
        RLS["Row-Level Security<br/>(org-scoped)"]
        EncAtRest["Encryption at Rest<br/>(KMS-managed)"]
        AuditLog["Immutable Audit Log"]
        Retention["Retention Policies<br/>(auto-purge)"]
    end

    client --> network
    network --> api
    api --> data
```

### 2.1 Security Layers

| Layer | Controls | Traceability |
|-------|----------|:------------:|
| **Device** | Keychain/Keystore token storage, root/jailbreak detection, certificate pinning, no secrets in logs | SEC-6, SEC-7, SEC-8, SEC-9, SEC-10 |
| **Network** | TLS 1.2+, WAF/IDS/IPS, rate limiting and abuse detection | SEC-4, SEC-11, SEC-13 |
| **Application** | OAuth2/OIDC, JWT validation, RBAC, step-up auth, input validation | SEC-1, SEC-2, SEC-3 |
| **Database** | RLS, encryption at rest, immutable audit logs, retention enforcement | SEC-5, SEC-12, SEC-17, SEC-18 |
| **Privacy** | Audio disabled, raw video off, optional redaction, minimal PII | SEC-14, SEC-15, SEC-16 |

---

## 3 Authentication (SEC-1)

### 3.1 Protocol

GreyEye uses **OAuth2 / OpenID Connect (OIDC)** for authentication. The Auth Service (see 02-software-design.md, Section 2.2) issues short-lived access tokens and long-lived refresh tokens upon successful authentication.

| Aspect | Detail |
|--------|--------|
| **Protocol** | OAuth2 Authorization Code + PKCE (mobile), Client Credentials (service-to-service) |
| **Identity Provider** | Supabase Auth (Option A) or custom OIDC provider (Option B) |
| **SSO Providers** | Google, Microsoft (via OIDC federation) |
| **Registration** | Email/password or admin-initiated invite (FR-1.1) |

### 3.2 Token Architecture

| Token | Type | Lifetime | Storage | Rotation |
|-------|------|----------|---------|----------|
| **Access token** | JWT (RS256-signed) | 15 minutes | In-memory only (mobile) | Issued on login and refresh |
| **Refresh token** | Opaque (stored server-side) | 7 days | Keychain (iOS) / Keystore (Android) | Rotated on every use; reuse detection triggers revocation |
| **Service token** | JWT (RS256-signed) | 1 hour | K8s Secret / Vault | Auto-renewed by service |

**Access token claims (JWT payload):**

```json
{
  "sub": "usr_abc123",
  "iss": "https://auth.greyeye.io",
  "aud": "greyeye-api",
  "iat": 1741500000,
  "exp": 1741500900,
  "org_id": "org_xyz789",
  "role": "operator",
  "email": "operator@example.com",
  "name": "Kim Operator",
  "step_up_at": null
}
```

### 3.3 Token Lifecycle

```mermaid
sequenceDiagram
    actor User
    participant App as Mobile App
    participant Auth as Auth Service
    participant KS as Keychain / Keystore

    User->>App: Enter credentials
    App->>Auth: POST /v1/auth/login { email, password }
    Auth->>Auth: Validate credentials
    Auth-->>App: { access_token (JWT), refresh_token }
    App->>KS: Store refresh_token securely

    Note over App: Access token used for API calls (15 min)

    App->>Auth: POST /v1/auth/refresh { refresh_token }
    Auth->>Auth: Validate + rotate refresh token
    Auth-->>App: { new_access_token, new_refresh_token }
    App->>KS: Replace refresh_token

    Note over Auth: If old refresh_token is reused → revoke all tokens for user (theft detection)
```

### 3.4 Refresh Token Reuse Detection

When a refresh token is used, the server issues a new refresh token and invalidates the old one. If the old token is presented again (indicating it was intercepted), the server revokes **all** tokens for that user and forces re-authentication. This protects against token theft via replay attacks.

### 3.5 Session Revocation (SEC-19)

| Action | Mechanism |
|--------|-----------|
| User logout | Revoke refresh token; access token expires naturally (15 min) |
| Admin force-logout | Revoke all refresh tokens for the user; add `jti` to a short-lived deny list in Redis (TTL = access token remaining lifetime) |
| Password change | Revoke all refresh tokens for the user |
| Role change | Revoke all refresh tokens; user must re-authenticate to receive updated claims |

---

## 4 Authorization — Role-Based Access Control (SEC-2, FR-1.3)

### 4.1 Role Hierarchy

GreyEye defines four roles in a strict hierarchy. Higher roles inherit all permissions of lower roles.

```mermaid
graph TD
    Admin["Admin<br/>(full control)"]
    Operator["Operator<br/>(site + camera management)"]
    Analyst["Analyst<br/>(analytics + alerts)"]
    Viewer["Viewer<br/>(read-only)"]

    Admin --> Operator
    Operator --> Analyst
    Analyst --> Viewer
```

### 4.2 Permission Matrix

| Resource / Action | Admin | Operator | Analyst | Viewer | Traceability |
|-------------------|:-----:|:--------:|:-------:|:------:|:------------:|
| Manage organization settings | ✅ | — | — | — | FR-1.2 |
| Invite / remove users | ✅ | — | — | — | FR-1.1 |
| Assign / change roles | ✅ | — | — | — | FR-1.3 |
| Create / edit / delete site | ✅ | ✅ | — | — | FR-2.1 |
| Create / edit / delete camera | ✅ | ✅ | — | — | FR-3.1 |
| Edit ROI / counting lines | ✅ | ✅ | — | — | FR-4.4 |
| Start / stop monitoring | ✅ | ✅ | — | — | FR-3.1 |
| View live monitor | ✅ | ✅ | ✅ | ✅ | FR-8.1 |
| View analytics / KPIs | ✅ | ✅ | ✅ | ✅ | FR-6.1 |
| Export reports (CSV/JSON/PDF) | ✅ | ✅ | ✅ | — | FR-8.3 |
| Create / edit alert rules | ✅ | ✅ | — | — | FR-7.1 |
| Acknowledge / close alerts | ✅ | ✅ | ✅ | — | FR-7.3 |
| View alert history | ✅ | ✅ | ✅ | ✅ | FR-7.4 |
| Model rollback | ✅ | — | — | — | FR-9.2 |
| View audit logs | ✅ | — | — | — | FR-1.4 |
| Configure retention / privacy | ✅ | — | — | — | NFR-13 |
| Data export / deletion | ✅ | — | — | — | NFR-14 |
| Create shareable report links | ✅ | ✅ | ✅ | — | FR-8.4 |

### 4.3 Enforcement Points

RBAC is enforced at two levels to provide defense in depth:

| Level | Mechanism | Granularity |
|-------|-----------|-------------|
| **API Gateway** | JWT claim inspection (`role` field); rejects requests to admin-only endpoints for non-admin users | Coarse (endpoint-level) |
| **Service layer** | FastAPI dependency injection checks role against the specific operation and resource | Fine-grained (operation + resource) |
| **Database** | RLS policies restrict read/write by role (see Section 7) | Row-level |

**FastAPI RBAC dependency example:**

```python
from fastapi import Depends, HTTPException, status

class RequireRole:
    HIERARCHY = {"admin": 4, "operator": 3, "analyst": 2, "viewer": 1}

    def __init__(self, minimum_role: str):
        self.min_level = self.HIERARCHY[minimum_role]

    def __call__(self, current_user: User = Depends(get_current_user)):
        user_level = self.HIERARCHY.get(current_user.role, 0)
        if user_level < self.min_level:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Requires {self._role_name()} role or higher",
            )
        return current_user

require_admin = RequireRole("admin")
require_operator = RequireRole("operator")
require_analyst = RequireRole("analyst")
```

### 4.4 Step-Up Authentication (SEC-3)

Destructive or sensitive admin actions require the user to have re-authenticated within the last 5 minutes. The `step_up_at` claim in the JWT records the timestamp of the most recent step-up authentication.

| Action Requiring Step-Up | Reason |
|--------------------------|--------|
| Delete site | Irreversible data loss |
| Change user roles | Privilege escalation risk |
| Export organization data | Data exfiltration risk |
| Delete organization data | Irreversible data loss |
| Model rollback | Affects production inference |
| Modify retention policies | Affects data lifecycle |

**Step-up flow:**

```mermaid
sequenceDiagram
    actor Admin
    participant App as Mobile App
    participant GW as API Gateway
    participant Auth as Auth Service

    Admin->>App: Tap "Delete Site"
    App->>GW: DELETE /v1/sites/{id}
    GW->>GW: Check step_up_at claim
    GW-->>App: 403 { error: "step_up_required", message: "Re-authenticate to proceed" }
    App->>App: Show biometric / password prompt
    Admin->>App: Confirm identity
    App->>Auth: POST /v1/auth/step-up { password or biometric_token }
    Auth-->>App: { access_token (with updated step_up_at) }
    App->>GW: DELETE /v1/sites/{id} (with new token)
    GW->>GW: Verify step_up_at < 5 min ago
    GW-->>App: 200 OK
```

---

## 5 Transport Security (SEC-4)

### 5.1 TLS Configuration

All network communication uses **TLS 1.2 or higher**. TLS 1.0 and 1.1 are explicitly disabled.

| Connection | Protocol | Certificate | Notes |
|------------|----------|-------------|-------|
| Mobile App → API Gateway | TLS 1.3 (preferred), TLS 1.2 (fallback) | Let's Encrypt or managed CA | HSTS enabled |
| API Gateway → Backend Services | mTLS (mutual TLS) | Internal CA (cert-manager) | Service mesh or manual cert rotation |
| Backend Services → PostgreSQL | TLS 1.2+ | Server certificate verified by client | `sslmode=verify-full` |
| Backend Services → Redis | TLS 1.2+ | Server certificate | `--tls-cert-file`, `--tls-key-file` |
| Backend Services → NATS | TLS 1.2+ | Server + client certificates | NATS nkey authentication |
| Backend Services → S3 | TLS 1.3 | AWS/provider managed | HTTPS-only bucket policy |

### 5.2 Cipher Suites

Allowed cipher suites (in preference order):

```
TLS_AES_256_GCM_SHA384
TLS_CHACHA20_POLY1305_SHA256
TLS_AES_128_GCM_SHA256
ECDHE-RSA-AES256-GCM-SHA384
ECDHE-RSA-AES128-GCM-SHA256
```

Disabled: All CBC-mode ciphers, RC4, 3DES, export-grade ciphers.

### 5.3 Certificate Pinning (SEC-8)

Certificate pinning is **optional** and configurable per deployment. When enabled, the mobile app pins the SHA-256 hash of the API gateway's leaf certificate (or its public key) and rejects connections to servers presenting different certificates.

| Aspect | Detail |
|--------|--------|
| **Pin type** | Subject Public Key Info (SPKI) hash |
| **Backup pins** | Two pins: current certificate + next rotation certificate |
| **Failure mode** | Connection refused; user shown "certificate error" with support contact |
| **Rotation** | Pins updated via app release or remote config (with a 30-day overlap window) |

**Implementation (Flutter):**

```dart
final client = HttpClient()
  ..badCertificateCallback = (cert, host, port) {
    final pinHash = sha256.convert(cert.der).toString();
    return trustedPins.contains(pinHash);
  };
```

> **Trade-off:** Certificate pinning increases security against MITM attacks but complicates certificate rotation. It is recommended for high-security deployments and disabled by default for ease of development.

---

## 6 Encryption at Rest (SEC-5)

### 6.1 Database Encryption

| Component | Encryption Method | Key Management |
|-----------|-------------------|----------------|
| **PostgreSQL (Supabase)** | Transparent Data Encryption (TDE) via Supabase platform | Supabase-managed keys (AWS KMS) |
| **PostgreSQL (self-hosted)** | Full-disk encryption (LUKS/dm-crypt) on data volumes | Customer-managed KMS (AWS KMS, GCP KMS, or HashiCorp Vault) |
| **Redis** | Encrypted volumes; no at-rest encryption in Redis itself | Volume-level encryption via cloud provider |
| **NATS JetStream** | Encrypted volumes for stream storage | Volume-level encryption |

### 6.2 Object Storage Encryption

All objects in S3-compatible storage (frames, clips, exports, hard examples) are encrypted using **server-side encryption with customer-managed keys (SSE-KMS)**.

| Bucket | Encryption | Key Rotation |
|--------|------------|:------------:|
| `greyeye-frames` | AES-256 (SSE-KMS) | Annual (automatic) |
| `greyeye-exports` | AES-256 (SSE-KMS) | Annual (automatic) |
| `greyeye-hard-examples` | AES-256 (SSE-KMS) | Annual (automatic) |
| `greyeye-backups` | AES-256 (SSE-KMS) | Annual (automatic) |

### 6.3 Application-Level Encryption

Sensitive fields that require additional protection beyond volume encryption:

| Field | Encryption | Storage |
|-------|------------|---------|
| RTSP URLs (with credentials) | AES-256-GCM, application-level | `cameras.rtsp_url` (encrypted column) |
| Webhook secrets | AES-256-GCM, application-level | `alert_rules.condition_params` |
| API keys for external services | AES-256-GCM, application-level | K8s Secrets or Vault |

```python
from cryptography.fernet import Fernet

class FieldEncryptor:
    def __init__(self, key: bytes):
        self._fernet = Fernet(key)

    def encrypt(self, plaintext: str) -> str:
        return self._fernet.encrypt(plaintext.encode()).decode()

    def decrypt(self, ciphertext: str) -> str:
        return self._fernet.decrypt(ciphertext.encode()).decode()
```

### 6.4 Key Rotation (SEC-19)

| Key Type | Rotation Frequency | Mechanism |
|----------|:------------------:|-----------|
| KMS master keys | Annual | Automatic via KMS provider |
| Application encryption keys | 90 days | Re-encrypt affected fields during rotation window |
| JWT signing keys (RS256) | 6 months | JWKS endpoint serves both old and new keys during overlap |
| TLS certificates | 90 days (Let's Encrypt) or annual | cert-manager auto-renewal |
| Service-to-service mTLS | Annual | cert-manager auto-renewal |

---

## 7 Row-Level Security (SEC-2, FR-1.2)

Row-Level Security (RLS) is the primary mechanism for multi-tenant data isolation. Every query is automatically scoped to the authenticated user's organization, preventing cross-tenant data access even if application-level checks are bypassed.

The full RLS implementation is documented in 04-database-design.md, Section 7. This section summarizes the security-relevant aspects.

### 7.1 RLS Invariants

The following invariants are enforced by RLS policies on **every** tenant-scoped table:

| Invariant | Enforcement |
|-----------|-------------|
| A user can only read data belonging to their own organization | `WHERE org_id = current_org_id()` on all SELECT policies |
| A user can only create data within their own organization | `WITH CHECK (org_id = current_org_id())` on all INSERT policies |
| A user can only modify data belonging to their own organization | `USING (org_id = current_org_id())` on all UPDATE/DELETE policies |
| Write operations respect RBAC role restrictions | Role-check conditions in INSERT/UPDATE/DELETE policies |
| Audit logs are readable only by admins | Additional `role = 'admin'` check on SELECT policy |
| Audit logs are immutable | Database trigger prevents UPDATE and DELETE (see 04-database-design.md, Section 4.12) |

### 7.2 Tables Under RLS

All tenant-scoped tables have RLS enabled:

| Table | SELECT | INSERT | UPDATE | DELETE |
|-------|:------:|:------:|:------:|:------:|
| `organizations` | Own org only | — | Admin only | — |
| `users` | Own org only | Admin (invite) | Admin (role change) | Admin |
| `sites` | Own org, all roles | Admin, Operator | Admin, Operator | Admin (step-up) |
| `cameras` | Own org, all roles | Admin, Operator | Admin, Operator | Admin, Operator |
| `roi_presets` | Own org, all roles | Admin, Operator | Admin, Operator | Admin, Operator |
| `counting_lines` | Own org, all roles | Admin, Operator | Admin, Operator | Admin, Operator |
| `vehicle_crossings` | Own org, all roles | Service role only | — | Retention job only |
| `agg_vehicle_counts_15m` | Own org, all roles | Service role only | Service role only | Retention job only |
| `alert_rules` | Own org, all roles | Admin, Operator | Admin, Operator | Admin, Operator |
| `alert_events` | Own org, all roles | Service role only | Admin, Operator, Analyst | — |
| `config_versions` | Own org, all roles | Service role only | — | — |
| `audit_logs` | Admin only | Service role only | — (immutable) | — (immutable) |
| `data_retention_policies` | Admin only | Admin | Admin | Admin |
| `shared_report_links` | Own org, all roles | Admin, Operator, Analyst | — | Creator or Admin |

### 7.3 Service Role Bypass

Backend services that write system-generated data (crossing events, aggregates, audit entries) authenticate to the database using a **service role** that bypasses RLS. This role is restricted to specific tables and operations:

```sql
CREATE ROLE greyeye_service NOLOGIN;
GRANT INSERT ON vehicle_crossings TO greyeye_service;
GRANT INSERT, UPDATE ON agg_vehicle_counts_15m TO greyeye_service;
GRANT INSERT ON audit_logs TO greyeye_service;
GRANT INSERT ON alert_events TO greyeye_service;

ALTER TABLE vehicle_crossings FORCE ROW LEVEL SECURITY;
CREATE POLICY service_insert ON vehicle_crossings
    FOR INSERT TO greyeye_service
    WITH CHECK (true);
```

The service role connection is authenticated via client certificates (mTLS) or a dedicated database user with a strong, rotated password stored in Vault.

---

## 8 Secrets Management (SEC-6)

### 8.1 Principles

1. **No hardcoded secrets** — No credentials, API keys, or tokens in source code, container images, or configuration files checked into version control.
2. **Least privilege** — Each service receives only the secrets it needs.
3. **Rotation without downtime** — Secrets are rotatable without service restart where possible.
4. **Audit trail** — All secret access is logged.

### 8.2 Secret Storage

| Environment | Secret Store | Access Method |
|-------------|-------------|---------------|
| **Local dev** | `.env` files (gitignored) + Docker Compose env vars | Environment variables |
| **CI/CD** | GitHub Actions Secrets / GitLab CI Variables | Injected as env vars during build |
| **Staging / Production** | HashiCorp Vault or K8s Secrets (with encryption at rest via KMS) | Sidecar injector or init container |

### 8.3 Secret Categories

| Secret | Owner Service | Rotation |
|--------|--------------|:--------:|
| Database connection string | All backend services | 90 days |
| Redis password | All backend services | 90 days |
| NATS credentials (nkey) | Ingest, Inference, Aggregation, Notification | 90 days |
| JWT signing key (RSA private key) | Auth Service | 6 months |
| S3 access key / secret key | Inference Worker, Reporting API | 90 days |
| SMTP credentials | Notification Service | 90 days |
| FCM/APNs push credentials | Notification Service | Annual |
| Webhook signing secrets | Notification Service | Per webhook |
| Application encryption key (Fernet) | Config Service | 90 days |

### 8.4 Secret Scanning

The CI/CD pipeline includes a **secret scanning** step (using tools like `trufflehog` or `gitleaks`) that blocks commits containing patterns matching known secret formats (API keys, private keys, connection strings).

---

## 9 Mobile Device Security

### 9.1 Secure Token Storage (SEC-7)

Authentication tokens are stored exclusively in the platform's secure enclave:

| Platform | Storage | Protection |
|----------|---------|------------|
| **iOS** | Keychain Services (kSecAttrAccessibleWhenUnlockedThisDeviceOnly) | Hardware-backed Secure Enclave; not included in backups |
| **Android** | Android Keystore (AES-256 key wrapping) | Hardware-backed TEE/StrongBox where available |

Tokens are **never** stored in:
- SharedPreferences / UserDefaults
- Local files or SQLite databases
- Application logs or crash reports

### 9.2 Root / Jailbreak Detection (SEC-9)

The mobile app performs runtime integrity checks on launch and periodically during use:

| Check | iOS | Android |
|-------|-----|---------|
| Known jailbreak/root files | `/Applications/Cydia.app`, `/private/var/stash` | `/system/app/Superuser.apk`, `su` binary |
| Writable system paths | Write test to `/private/` | Write test to `/system/` |
| Suspicious processes | Check for `substrate`, `frida-server` | Check for `magisk`, `frida-server` |
| Package manager | Cydia URL scheme check | `com.topjohnwu.magisk` package check |

**Response policy:**

| Severity | Condition | Action |
|----------|-----------|--------|
| Warning | Root/jailbreak indicators detected | Show warning banner; allow continued use with user acknowledgment |
| Block | Frida or instrumentation framework detected | Refuse to start; display security error |

> **Note:** Root/jailbreak detection is a best-effort measure. Determined attackers can bypass these checks. The primary defense is server-side validation and RLS, not client-side trust.

### 9.3 Debug Log Sanitization (SEC-10)

The mobile app and all backend services enforce strict log sanitization:

| Data Type | Log Policy |
|-----------|-----------|
| RTSP URLs | Redact credentials: `rtsp://****:****@192.168.1.100/stream` |
| JWT tokens | Log only the `jti` claim (token ID), never the full token |
| Refresh tokens | Never logged |
| User passwords | Never logged (not even hashed) |
| API keys | Log only the last 4 characters |
| Email addresses | Redact to `o***@example.com` in non-audit logs |
| IP addresses | Full IP in audit logs only; redacted in application logs |

**Implementation:**

```python
import re

REDACTION_PATTERNS = [
    (re.compile(r'(rtsp://)[^@]+@'), r'\1****:****@'),
    (re.compile(r'(Bearer\s+)\S+'), r'\1[REDACTED]'),
    (re.compile(r'(password["\s:=]+)\S+', re.IGNORECASE), r'\1[REDACTED]'),
    (re.compile(r'(api[_-]?key["\s:=]+)\S+', re.IGNORECASE), r'\1[REDACTED]'),
]

def sanitize_log(message: str) -> str:
    for pattern, replacement in REDACTION_PATTERNS:
        message = pattern.sub(replacement, message)
    return message
```

---

## 10 Rate Limiting and Abuse Detection (SEC-11)

### 10.1 Rate Limit Tiers

Rate limiting is enforced at the API Gateway using a token-bucket algorithm. Limits are defined per scope:

| Scope | Limit | Window | Burst | Response |
|-------|:-----:|:------:|:-----:|----------|
| Per IP (unauthenticated) | 60 | 1 minute | 10 | `429` + `Retry-After` header |
| Per user (authenticated) | 300 | 1 minute | 50 | `429` + `Retry-After` header |
| Frame upload (per camera) | 15 | 1 second | 5 | `429` + `Retry-After` header |
| Auth endpoints (per IP) | 10 | 1 minute | 3 | `429` + `Retry-After` header |
| Report export (per user) | 5 | 5 minutes | 2 | `429` + `Retry-After` header |

### 10.2 Brute-Force Protection

| Mechanism | Threshold | Action |
|-----------|-----------|--------|
| Failed login attempts | 5 failures in 15 minutes (per email) | Lock account for 30 minutes; notify admin |
| Failed login attempts | 20 failures in 15 minutes (per IP) | Block IP for 1 hour |
| Invalid refresh tokens | 3 invalid tokens in 5 minutes (per user) | Revoke all sessions; require re-authentication |
| Step-up auth failures | 3 failures in 10 minutes | Lock step-up for 30 minutes |

### 10.3 Abuse Detection

The API Gateway logs request patterns and flags anomalies:

| Pattern | Detection | Response |
|---------|-----------|----------|
| Credential stuffing | High rate of unique email/password combinations from single IP | Temporary IP block + CAPTCHA challenge |
| API scraping | Systematic enumeration of resource IDs | Rate limit reduction + alert to admin |
| Excessive data export | Multiple large export requests in short window | Throttle + admin notification |

---

## 11 Network Security (SEC-13)

### 11.1 Web Application Firewall (WAF)

A WAF is deployed in front of the API Gateway to filter malicious traffic:

| Rule Category | Examples | Action |
|---------------|----------|--------|
| SQL injection | `' OR 1=1 --`, UNION-based attacks | Block + log |
| Cross-site scripting (XSS) | `<script>`, event handler injection | Block + log |
| Path traversal | `../../etc/passwd` | Block + log |
| Request size limits | Body > 10 MB (except frame upload), URL > 8 KB | Block |
| Geo-blocking (optional) | Restrict to allowed countries | Configurable per deployment |

### 11.2 Intrusion Detection / Prevention (IDS/IPS)

| Component | Tool | Scope |
|-----------|------|-------|
| Network IDS | Suricata or cloud-native (AWS GuardDuty, GCP Security Command Center) | Cluster network traffic |
| Host IDS | Falco (Kubernetes runtime security) | Container behavior anomalies |
| Log-based detection | SIEM integration (Splunk, Elastic Security) | Correlated security events |

### 11.3 Network Segmentation

```mermaid
graph TB
    subgraph public ["Public Zone"]
        LB["Load Balancer<br/>(TLS termination)"]
    end

    subgraph dmz ["DMZ"]
        GW["API Gateway<br/>(WAF + rate limit)"]
    end

    subgraph app ["Application Zone"]
        Services["Backend Services<br/>(Auth, Config, Reporting, etc.)"]
    end

    subgraph proc ["Processing Zone"]
        Workers["Inference Workers<br/>(GPU nodes)"]
    end

    subgraph data ["Data Zone"]
        DB[("PostgreSQL")]
        Cache[("Redis")]
        MQ["NATS JetStream"]
        S3[("Object Storage")]
    end

    LB --> GW
    GW --> Services
    Services --> DB
    Services --> Cache
    Services --> MQ
    Workers --> MQ
    Workers --> S3
    Workers --> Cache
```

| Zone | Ingress | Egress |
|------|---------|--------|
| **Public** | Internet → Load Balancer (ports 443 only) | Load Balancer → DMZ |
| **DMZ** | Load Balancer → API Gateway | API Gateway → Application Zone |
| **Application** | DMZ → Backend Services | Backend Services → Data Zone |
| **Processing** | Data Zone (NATS) → Inference Workers | Workers → Data Zone (S3, Redis, NATS) |
| **Data** | Application + Processing zones only | No outbound internet access |

---

## 12 Privacy by Design (NFR-13, SEC-14, SEC-15, SEC-16)

### 12.1 Data Minimization Principles

GreyEye follows a **privacy-by-design** approach: collect the minimum data necessary for traffic analysis, store aggregates by default, and provide controls for any additional data collection.

| Principle | Implementation |
|-----------|---------------|
| **Minimize collection** | No audio, no license plate recognition, no facial recognition by default |
| **Aggregate by default** | 15-minute bucket aggregates are the primary data product; raw events have configurable retention |
| **Purpose limitation** | Data is collected solely for traffic analysis; no secondary use without explicit consent |
| **Storage limitation** | Configurable retention periods with automatic purging |
| **User control** | Organization admins control what is collected and how long it is retained |

### 12.2 Privacy Controls

| Control | Default | Configurable | Admin Setting | Traceability |
|---------|:-------:|:------------:|---------------|:------------:|
| Audio capture | **OFF** (disabled at SDK level) | No | — | SEC-14 |
| Raw video frame storage | **OFF** | Yes | `settings.media.store_frames` | SEC-15 |
| Raw video clip storage | **OFF** | Yes | `settings.media.store_clips` | SEC-15 |
| Bounding box storage in events | ON (no PII) | Yes | `settings.privacy.store_bbox` | — |
| Speed estimate storage | ON (no PII) | Yes | `settings.privacy.store_speed` | — |
| Face redaction (if frames stored) | **OFF** (opt-in) | Yes | `settings.privacy.redact_faces` | SEC-16 |
| License plate redaction (if frames stored) | **OFF** (opt-in) | Yes | `settings.privacy.redact_plates` | SEC-16 |
| Aggregate-only mode | Available | Yes | `settings.privacy.aggregate_only` | NFR-13 |

### 12.3 Audio Disabling (SEC-14)

Audio capture is disabled at the camera SDK level. The mobile app requests camera permission **without** microphone access. On both iOS and Android, the video capture session is initialized with audio disabled:

```dart
// Flutter camera initialization — audio explicitly disabled
final controller = CameraController(
  camera,
  ResolutionPreset.high,
  enableAudio: false,  // SEC-14: audio disabled by default
);
```

No configuration option exists to enable audio capture. This is a hard-coded privacy control.

### 12.4 Optional Redaction Pipeline (SEC-16)

When raw frame storage is enabled and redaction is configured, frames pass through a redaction pipeline before storage:

```mermaid
graph LR
    Frame["Raw Frame"] --> FaceDetect["Face Detector<br/>(lightweight CNN)"]
    Frame --> PlateDetect["Plate Detector<br/>(YOLO-based)"]
    FaceDetect --> Blur1["Gaussian Blur<br/>(face regions)"]
    PlateDetect --> Blur2["Gaussian Blur<br/>(plate regions)"]
    Blur1 --> Merge["Merge Redactions"]
    Blur2 --> Merge
    Merge --> Store["Store Redacted Frame"]
```

| Aspect | Detail |
|--------|--------|
| **Face detector** | Lightweight CNN (e.g., BlazeFace) running on CPU |
| **Plate detector** | Small YOLO model trained on Korean license plates |
| **Redaction method** | Gaussian blur (σ=20) applied to detected regions |
| **Performance** | < 50 ms per frame on CPU; runs asynchronously (does not block inference pipeline) |
| **Fallback** | If redaction fails, the frame is **not stored** (fail-safe) |

### 12.5 Media Encryption (DM-4)

When raw frame or clip storage is enabled, media files are encrypted before upload to object storage:

| Aspect | Detail |
|--------|--------|
| **Algorithm** | AES-256-GCM |
| **Key management** | Per-organization data encryption key (DEK) wrapped by KMS master key |
| **Key rotation** | DEK rotated every 90 days; old DEKs retained for decryption of existing media |
| **Access** | Decryption requires both the DEK and a valid access token with appropriate role |

### 12.6 Data Export and Deletion (NFR-14)

Organizations can request a full data export or deletion at the org or site level. These operations are admin-only and require step-up authentication.

| Operation | Scope | Process | Traceability |
|-----------|-------|---------|:------------:|
| **Data export** | Org or site | Generate JSONL dump of all data → encrypt → upload to S3 → provide download link (7-day TTL) | NFR-14 |
| **Data deletion** | Org or site | Delete time-series data → delete config data → anonymize audit logs → delete media from S3 | NFR-14 |
| **Audit log retention** | Org | Audit logs are anonymized (PII removed) but retained per compliance requirements even after org deletion | SEC-17 |

The data deletion process is documented in 04-database-design.md, Section 8.3.

---

## 13 Audit Logging (SEC-12, SEC-17, SEC-18, FR-1.4)

### 13.1 Audit Log Scope

Every state-changing operation in GreyEye is recorded in the `audit_logs` table. The audit log is **append-only** — a database trigger prevents UPDATE and DELETE operations (see 04-database-design.md, Section 4.12).

### 13.2 Audited Events

| Category | Events | Severity |
|----------|--------|:--------:|
| **Authentication** | Login success, login failure, logout, token refresh, step-up auth | Info / Warning |
| **User management** | User invite, user removal, role change, account lock/unlock | Warning |
| **Organization** | Settings change, retention policy change, data export request, data deletion request | Critical |
| **Site management** | Site create, update, archive, delete | Info |
| **Camera management** | Camera create, update, delete, status change | Info |
| **ROI configuration** | Preset create, update, delete, activate | Info |
| **Alert management** | Rule create, update, delete; alert acknowledge, assign, resolve | Info |
| **Model management** | Model version deploy, canary start/stop, rollback | Critical |
| **Data access** | Report export, shared link creation, audit log query | Info |
| **Security events** | Rate limit triggered, brute-force lockout, invalid token, RLS violation attempt | Warning / Critical |

### 13.3 Audit Log Schema

Each audit entry captures the full context of the operation:

```json
{
  "id": "aud_f47ac10b",
  "org_id": "org_xyz789",
  "user_id": "usr_abc123",
  "action": "site.delete",
  "entity_type": "site",
  "entity_id": "site_a1b2c3",
  "old_value": {
    "name": "강남역 교차로",
    "status": "active"
  },
  "new_value": {
    "status": "archived"
  },
  "ip_address": "203.0.113.42",
  "user_agent": "GreyEye/1.2.0 (iOS 18.0; iPhone 16)",
  "created_at": "2026-03-09T14:07:32.451Z"
}
```

### 13.4 Audit Log Immutability (SEC-17)

Immutability is enforced at multiple levels:

| Level | Mechanism |
|-------|-----------|
| **Database trigger** | `BEFORE UPDATE OR DELETE` trigger raises an exception on the `audit_logs` table |
| **RLS policy** | No UPDATE or DELETE policies exist for any role |
| **Service role** | The `greyeye_service` database role has INSERT-only permission on `audit_logs` |
| **Application** | No API endpoint exists for modifying or deleting audit logs |

### 13.5 Audit Log Retention

Audit logs have a **minimum retention period of 3 years**, which is not configurable below this floor. Organizations may extend retention beyond 3 years. When an organization is deleted, audit logs are **anonymized** (PII fields set to NULL) but the entries themselves are retained.

### 13.6 Audit Log Export (SEC-18)

Admins can export audit logs for compliance review via the `POST /v1/audit-logs/export` endpoint:

| Aspect | Detail |
|--------|--------|
| **Format** | JSONL (one JSON object per line) or CSV |
| **Scope** | Filterable by date range, action category, user, entity type |
| **Delivery** | Encrypted file uploaded to S3; download link with 7-day TTL |
| **Access** | Admin role only; step-up authentication required |
| **Audit** | The export operation itself is recorded in the audit log |

---

## 14 Security Event Logging (SEC-12)

Beyond the business audit log, GreyEye maintains a separate **security event log** for real-time threat detection and incident response.

### 14.1 Security Events

| Event | Source | Severity | Alert |
|-------|--------|:--------:|:-----:|
| Failed login (single) | Auth Service | Info | No |
| Failed login (threshold exceeded) | Auth Service | Warning | Yes |
| Account locked (brute force) | Auth Service | Critical | Yes |
| Invalid JWT presented | API Gateway | Warning | No (high volume) |
| Expired token used after revocation | API Gateway | Warning | Yes |
| Rate limit exceeded | API Gateway | Info | No |
| Rate limit exceeded (sustained) | API Gateway | Warning | Yes |
| RLS policy violation (query returned 0 rows unexpectedly) | Database | Warning | Yes |
| WAF rule triggered | WAF | Warning | Yes (critical rules) |
| Root/jailbreak detected | Mobile App | Warning | Yes |
| Certificate pinning failure | Mobile App | Critical | Yes |
| Service-to-service auth failure | mTLS | Critical | Yes |
| Secret access (Vault audit) | Vault | Info | No |
| Anomalous API pattern | SIEM | Warning | Yes |

### 14.2 Security Log Pipeline

```mermaid
graph LR
    Sources["Security Event Sources<br/>(Gateway, Auth, WAF, App)"]
    Sources --> Collector["Log Collector<br/>(Fluentd / Vector)"]
    Collector --> SIEM["SIEM<br/>(Elastic Security / Splunk)"]
    Collector --> Loki["Loki<br/>(operational logs)"]
    SIEM --> Alerts["Alert Rules"]
    Alerts --> PagerDuty["PagerDuty / Opsgenie"]
    Alerts --> Slack["Slack Channel"]
```

### 14.3 Log Correlation

All security events include the following correlation fields for cross-referencing:

| Field | Description |
|-------|-------------|
| `request_id` | UUID assigned at the API Gateway (X-Request-ID header) |
| `user_id` | Authenticated user ID (if available) |
| `org_id` | Organization ID (if available) |
| `ip_address` | Client IP address |
| `timestamp_utc` | Event timestamp in UTC |
| `service` | Originating service name |
| `severity` | `info`, `warning`, `critical` |

---

## 15 Incident Response (SEC-20)

### 15.1 Incident Severity Levels

| Level | Definition | Response Time | Examples |
|-------|-----------|:-------------:|---------|
| **P1 — Critical** | Active data breach, complete service outage, or active exploitation | 15 minutes | Unauthorized data access, database compromise, credential leak |
| **P2 — High** | Partial service degradation with security implications | 1 hour | Sustained brute-force attack, WAF bypass detected, single-service compromise |
| **P3 — Medium** | Security anomaly without confirmed impact | 4 hours | Unusual API patterns, failed penetration attempt, configuration drift |
| **P4 — Low** | Minor security finding, no immediate risk | 24 hours | Outdated dependency with known CVE (no exploit), log anomaly |

### 15.2 Incident Response Runbook

```mermaid
graph TD
    Detect["1. Detect<br/>SIEM alert, user report,<br/>or monitoring anomaly"]
    Detect --> Triage["2. Triage<br/>Assess severity (P1–P4)<br/>Assign incident commander"]
    Triage --> Contain["3. Contain<br/>Isolate affected systems<br/>Revoke compromised credentials"]
    Contain --> Investigate["4. Investigate<br/>Analyze logs, audit trail<br/>Determine scope and root cause"]
    Investigate --> Remediate["5. Remediate<br/>Patch vulnerability<br/>Rotate affected secrets"]
    Remediate --> Recover["6. Recover<br/>Restore service<br/>Verify integrity"]
    Recover --> PostMortem["7. Post-Mortem<br/>Document timeline<br/>Update runbooks<br/>Implement preventive measures"]
```

### 15.3 Key Response Actions

| Scenario | Immediate Actions |
|----------|-------------------|
| **Compromised user credentials** | Revoke all tokens for the user → Force password reset → Review audit log for unauthorized actions → Notify affected organization |
| **Compromised service credentials** | Rotate affected secret in Vault → Restart affected service → Review database audit log for anomalous queries |
| **Database breach suspected** | Enable enhanced logging → Snapshot current state → Analyze RLS policy effectiveness → Check for data exfiltration via export logs |
| **API key leak (public repo)** | Immediately rotate the key → Scan for unauthorized usage → Review git history for other secrets → Run `trufflehog` scan |
| **DDoS attack** | Enable WAF rate-limit escalation → Scale API Gateway replicas → Engage cloud provider DDoS protection → Monitor service health |

### 15.4 Communication Protocol

| Audience | Channel | Timing |
|----------|---------|--------|
| Incident response team | PagerDuty + dedicated Slack channel | Immediate |
| Engineering leadership | Email + Slack | Within 1 hour (P1/P2) |
| Affected organization admins | In-app notification + email | Within 24 hours (if data affected) |
| Regulatory bodies | Formal notification | Within 72 hours (if PII breach, per GDPR/PIPA) |

---

## 16 Dependency and Supply Chain Security

### 16.1 Dependency Management

| Practice | Implementation |
|----------|---------------|
| **Lock files** | `uv.lock` (Python), `pubspec.lock` (Flutter) committed to version control |
| **Vulnerability scanning** | Automated scanning in CI/CD (Dependabot, Snyk, or `pip-audit`) |
| **Update cadence** | Security patches within 48 hours; minor/major updates monthly |
| **Minimal dependencies** | Prefer standard library where possible; audit new dependencies before adoption |

### 16.2 Container Security

| Practice | Implementation |
|----------|---------------|
| **Base images** | Distroless or Alpine-based images; no shell in production containers |
| **Image scanning** | Trivy or Grype scan in CI/CD; block deployment on critical CVEs |
| **Image signing** | Cosign signatures on all production images |
| **Non-root execution** | All containers run as non-root user |
| **Read-only filesystem** | Container filesystems mounted read-only where possible |

### 16.3 CI/CD Pipeline Security

| Control | Description |
|---------|-------------|
| **Branch protection** | `main` branch requires PR review + passing CI |
| **Secret scanning** | Pre-commit hooks + CI step block secrets in code |
| **SAST** | Static analysis (Bandit for Python, dart_code_metrics for Flutter) |
| **DAST** | Periodic dynamic scanning against staging environment |
| **Signed commits** | GPG-signed commits encouraged (required for releases) |

---

## 17 Compliance Considerations

### 17.1 Regulatory Landscape

GreyEye processes traffic video data in South Korea and potentially other jurisdictions. The following regulations are relevant:

| Regulation | Scope | Key Requirements |
|------------|-------|------------------|
| **PIPA (개인정보보호법)** | South Korean Personal Information Protection Act | Consent for PII collection, data minimization, breach notification within 72 hours, data subject rights |
| **GDPR** | EU General Data Protection Regulation (if deployed in EU) | Lawful basis for processing, data minimization, right to erasure, DPO appointment, breach notification |
| **KICT/MOLIT Standards** | Korean traffic survey standards | 12-class vehicle taxonomy compliance, survey data format requirements |

### 17.2 GreyEye Compliance Controls

| Requirement | GreyEye Control | Section |
|-------------|----------------|:-------:|
| Data minimization | No audio, no PII by default, aggregate-only mode available | 12 |
| Consent management | Organization admin controls data collection settings | 12.2 |
| Right to erasure | Data deletion at org/site level with step-up auth | 12.6 |
| Data portability | Data export in JSONL/CSV format | 12.6 |
| Breach notification | Incident response runbook with communication protocol | 15.4 |
| Audit trail | Immutable audit logs with 3-year minimum retention | 13 |
| Encryption in transit | TLS 1.2+ everywhere | 5 |
| Encryption at rest | KMS-managed encryption on all storage | 6 |
| Access control | RBAC + RLS + step-up auth | 4, 7 |
| Data retention | Configurable per-org retention with auto-purge | 12.6, 04-database-design.md §8 |

---

## 18 Security Testing

### 18.1 Testing Strategy

| Test Type | Frequency | Scope | Tool |
|-----------|-----------|-------|------|
| **Unit tests** | Every commit | RBAC logic, token validation, input sanitization | pytest |
| **Integration tests** | Every PR | RLS policy enforcement, auth flow end-to-end | pytest + test database |
| **SAST** | Every commit | Python (Bandit), Dart (dart_code_metrics) | CI/CD pipeline |
| **Dependency scan** | Daily | All dependencies | Dependabot / Snyk |
| **Container scan** | Every build | Docker images | Trivy |
| **Penetration test** | Quarterly | Full application stack | External security firm |
| **Red team exercise** | Annual | Social engineering + technical attack | External team |

### 18.2 RLS Policy Testing

RLS policies are tested in CI with dedicated test cases that verify:

```python
def test_rls_cross_tenant_isolation(db_session):
    """Verify that Org A cannot read Org B's data."""
    set_session_org(db_session, org_a.id)
    sites = db_session.query(Site).all()
    assert all(s.org_id == org_a.id for s in sites)
    assert org_b_site.id not in [s.id for s in sites]

def test_rls_role_restriction(db_session):
    """Verify that a Viewer cannot delete a site."""
    set_session_user(db_session, viewer_user)
    with pytest.raises(InsufficientPrivilege):
        db_session.delete(site)
        db_session.commit()

def test_audit_log_immutability(db_session):
    """Verify that audit logs cannot be modified."""
    log_entry = create_audit_log(db_session, action="test")
    with pytest.raises(DatabaseError, match="append-only"):
        log_entry.action = "tampered"
        db_session.commit()
```

---

## 19 Traceability Matrix

| Req ID | Requirement Summary | Section(s) |
|--------|--------------------:|:----------:|
| **FR-1.1** | User registration / invite via email or SSO | 3.1 |
| **FR-1.2** | Multi-tenant organizations with isolated data | 7 |
| **FR-1.3** | RBAC roles: Admin, Operator, Analyst, Viewer | 4 |
| **FR-1.4** | Audit log for permission changes | 13 |
| **NFR-13** | Configurable retention; minimize collection by default | 12 |
| **NFR-14** | Data export and deletion at org/site level | 12.6 |
| **SEC-1** | OAuth2/OIDC with short-lived tokens | 3 |
| **SEC-2** | RBAC enforcement for all resources | 4, 7 |
| **SEC-3** | Step-up auth for admin actions | 4.4 |
| **SEC-4** | TLS 1.2+ for all network traffic | 5 |
| **SEC-5** | Encryption at rest (KMS-managed) | 6 |
| **SEC-6** | No hardcoded secrets; OS secure storage | 8 |
| **SEC-7** | Auth tokens in Keychain/Keystore only | 9.1 |
| **SEC-8** | Certificate pinning (optional) | 5.3 |
| **SEC-9** | Rooted/jailbroken device detection | 9.2 |
| **SEC-10** | No RTSP credentials or tokens in debug logs | 9.3 |
| **SEC-11** | Rate limiting and abuse detection | 10 |
| **SEC-12** | Security event logging | 14 |
| **SEC-13** | WAF and IDS/IPS support | 11 |
| **SEC-14** | Audio disabled by default | 12.3 |
| **SEC-15** | Raw video storage off by default | 12.2 |
| **SEC-16** | Optional face/plate redaction | 12.4 |
| **SEC-17** | Immutable audit logs | 13.4 |
| **SEC-18** | Audit log export for compliance | 13.6 |
| **SEC-19** | Key rotation and session revocation | 3.5, 6.4 |
| **SEC-20** | Incident response runbooks | 15 |
| **DM-4** | Media off by default; encrypted if enabled | 12.2, 12.5 |

---

## 20 Summary

GreyEye's security design follows five principles:

1. **Defense in depth** — Security controls at every layer (device, network, application, database) ensure that no single point of failure compromises the system.
2. **Least privilege** — RBAC with four hierarchical roles, RLS at the database level, and service-specific secrets ensure each actor has only the access it needs.
3. **Privacy by design** — No audio, no raw video by default, aggregate-only mode, configurable retention, and optional redaction minimize privacy risk from the ground up.
4. **Immutable audit trail** — Every state-changing operation is logged in an append-only table with database-enforced immutability, providing a complete forensic record.
5. **Continuous verification** — Automated security testing (SAST, dependency scanning, container scanning, RLS tests) in CI/CD, combined with periodic penetration testing, ensures security controls remain effective as the system evolves.
