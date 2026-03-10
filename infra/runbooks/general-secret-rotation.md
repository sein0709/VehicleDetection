# General: Secret Rotation Procedures

Reference for rotating each type of secret in the GreyEye platform.

## JWT Signing Key (6-month rotation)

```bash
# 1. Generate new key pair
openssl genrsa -out jwt-key-new.pem 2048
openssl rsa -in jwt-key-new.pem -pubout -out jwt-key-new.pub

# 2. Update Kubernetes secret with both old and new keys
kubectl create secret generic greyeye-jwt-secret \
  --from-file=jwt-secret=jwt-key-new.pem \
  --from-file=jwt-secret-old=jwt-key-old.pem \
  --dry-run=client -o yaml | kubectl apply -f -

# 3. Rolling restart auth service (serves both keys via JWKS)
kubectl rollout restart -n greyeye-api deploy/auth-service

# 4. Wait for all existing access tokens to expire (15 min)
sleep 900

# 5. Remove old key
kubectl create secret generic greyeye-jwt-secret \
  --from-file=jwt-secret=jwt-key-new.pem \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl rollout restart -n greyeye-api deploy/auth-service
```

## Database Password (90-day rotation)

```bash
NEW_PASS=$(openssl rand -base64 32)

# 1. Create new user or update password
psql $DATABASE_URL -c "ALTER USER greyeye_app PASSWORD '$NEW_PASS';"

# 2. Update Kubernetes secret
kubectl create secret generic greyeye-db-credentials \
  --from-literal=username=greyeye_app \
  --from-literal=password="$NEW_PASS" \
  --from-literal=connection-string="postgresql://greyeye_app:$NEW_PASS@$DB_HOST:5432/greyeye?sslmode=verify-full" \
  --dry-run=client -o yaml | kubectl apply -f -

# 3. Rolling restart all services
kubectl rollout restart -n greyeye-api deploy
kubectl rollout restart -n greyeye-processing deploy
```

## Application Encryption Key / Fernet (90-day rotation)

```bash
# 1. Generate new key
NEW_KEY=$(python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())")

# 2. Prepend to existing keys (comma-separated)
OLD_KEYS=$(kubectl get secret greyeye-encryption-keys -o jsonpath='{.data.keys}' | base64 -d)
kubectl create secret generic greyeye-encryption-keys \
  --from-literal=keys="$NEW_KEY,$OLD_KEYS" \
  --dry-run=client -o yaml | kubectl apply -f -

# 3. Rolling restart services that use encryption
kubectl rollout restart -n greyeye-api deploy/config-service

# 4. Run re-encryption migration for existing data
kubectl exec -n greyeye-api deploy/config-service -- \
  python -m config_service.cli re-encrypt-fields

# 5. After migration, remove old keys (keep only new)
kubectl create secret generic greyeye-encryption-keys \
  --from-literal=keys="$NEW_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -
```

## S3 Access Keys (90-day rotation)

```bash
# 1. Create new access key
aws iam create-access-key --user-name greyeye-s3-user

# 2. Update Kubernetes secret
kubectl create secret generic greyeye-s3-credentials \
  --from-literal=access-key="$NEW_ACCESS_KEY" \
  --from-literal=secret-key="$NEW_SECRET_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -

# 3. Rolling restart affected services
kubectl rollout restart -n greyeye-processing deploy/inference-worker
kubectl rollout restart -n greyeye-api deploy/reporting-api

# 4. Delete old access key after confirming new one works
aws iam delete-access-key --user-name greyeye-s3-user --access-key-id $OLD_KEY_ID
```

## Redis Password (90-day rotation)

```bash
# For ElastiCache, modify the replication group
aws elasticache modify-replication-group \
  --replication-group-id greyeye-redis \
  --auth-token "$NEW_REDIS_PASS" \
  --auth-token-update-strategy ROTATE

# Update Kubernetes secret and restart services
kubectl create secret generic greyeye-redis-credentials \
  --from-literal=password="$NEW_REDIS_PASS" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl rollout restart -n greyeye-api deploy
kubectl rollout restart -n greyeye-processing deploy
```

## TLS Certificates (auto-renewed by cert-manager)

cert-manager handles automatic renewal. Manual rotation:

```bash
# Force renewal
kubectl cert-manager renew greyeye-tls -n greyeye-api

# Verify new certificate
kubectl get certificate greyeye-tls -n greyeye-api -o jsonpath='{.status.notAfter}'
```
