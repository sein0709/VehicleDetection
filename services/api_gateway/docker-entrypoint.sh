#!/bin/sh
# GreyEye API Gateway — Docker entrypoint
#
# Handles:
#   - Environment variable substitution in nginx config
#   - TLS certificate generation (self-signed) for dev when no certs are mounted
#   - Dev vs production config selection
#   - Config validation and startup

set -e

# Default service hostnames (for local dev / Docker Compose)
export AUTH_SERVICE_HOST="${AUTH_SERVICE_HOST:-localhost}"
export CONFIG_SERVICE_HOST="${CONFIG_SERVICE_HOST:-localhost}"
export INGEST_SERVICE_HOST="${INGEST_SERVICE_HOST:-localhost}"
export REPORTING_API_HOST="${REPORTING_API_HOST:-localhost}"
export AGGREGATOR_HOST="${AGGREGATOR_HOST:-localhost}"
export NOTIFICATION_SERVICE_HOST="${NOTIFICATION_SERVICE_HOST:-localhost}"

# TLS mode: "true" for production (HTTPS), "false" for dev (HTTP only)
TLS_ENABLED="${TLS_ENABLED:-false}"

CONFIG_DIR="${NGINX_CONFIG_DIR:-/etc/nginx}"
CONFIG_FILE="${CONFIG_DIR}/nginx.conf"
SSL_DIR="${CONFIG_DIR}/ssl"
HTML_DIR="/usr/share/nginx/html"

ENV_VARS='${AUTH_SERVICE_HOST} ${CONFIG_SERVICE_HOST} ${INGEST_SERVICE_HOST} ${REPORTING_API_HOST} ${AGGREGATOR_HOST} ${NOTIFICATION_SERVICE_HOST}'

# Select config based on TLS mode
if [ "$TLS_ENABLED" = "true" ]; then
    echo "TLS mode: enabled (HTTPS)"
    SOURCE_CONF="/app/nginx.conf"

    # Generate self-signed certificate if none is mounted
    if [ ! -f "${SSL_DIR}/server.crt" ] || [ ! -f "${SSL_DIR}/server.key" ]; then
        echo "No TLS certificates found — generating self-signed certificate..."
        mkdir -p "${SSL_DIR}"
        openssl req -x509 -nodes -days 365 \
            -newkey rsa:2048 \
            -keyout "${SSL_DIR}/server.key" \
            -out "${SSL_DIR}/server.crt" \
            -subj "/CN=greyeye-gateway/O=GreyEye/C=KR" \
            2>/dev/null
        echo "Self-signed certificate generated at ${SSL_DIR}/"
    else
        echo "Using mounted TLS certificates from ${SSL_DIR}/"
    fi
else
    echo "TLS mode: disabled (HTTP only, dev mode)"
    SOURCE_CONF="/app/nginx.dev.conf"
fi

# Substitute env vars in the selected config
if [ -f "${SOURCE_CONF}.template" ]; then
    echo "Substituting environment variables from ${SOURCE_CONF}.template..."
    envsubst "$ENV_VARS" < "${SOURCE_CONF}.template" > "${CONFIG_FILE}"
elif [ -f "${SOURCE_CONF}" ]; then
    echo "Substituting environment variables in $(basename "${SOURCE_CONF}")..."
    envsubst "$ENV_VARS" < "${SOURCE_CONF}" > "${CONFIG_FILE}"
else
    echo "ERROR: Config file not found: ${SOURCE_CONF}"
    exit 1
fi

# Copy proxy_params
if [ -f /app/proxy_params ] && [ ! -f "${CONFIG_DIR}/proxy_params" ]; then
    cp /app/proxy_params "${CONFIG_DIR}/proxy_params"
fi

# Copy mime.types if the default is missing
if [ -f /app/mime.types ] && [ ! -f "${CONFIG_DIR}/mime.types" ]; then
    cp /app/mime.types "${CONFIG_DIR}/mime.types"
fi

# Copy custom error pages
if [ -d /app/html ]; then
    mkdir -p "${HTML_DIR}"
    cp -r /app/html/* "${HTML_DIR}/" 2>/dev/null || true
fi

# Validate configuration
echo "Testing nginx configuration..."
if ! nginx -t 2>&1; then
    echo "ERROR: nginx configuration test failed"
    exit 1
fi

echo "Starting nginx (PID 1)..."
exec nginx -g "daemon off;"
