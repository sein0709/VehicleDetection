FROM nginx:1.27-alpine

RUN apk add --no-cache openssl gettext

RUN mkdir -p /etc/nginx/ssl /app/html

COPY services/api_gateway/nginx.conf      /app/nginx.conf
COPY services/api_gateway/nginx.dev.conf  /app/nginx.dev.conf
COPY services/api_gateway/proxy_params    /app/proxy_params
COPY services/api_gateway/mime.types      /app/mime.types
COPY services/api_gateway/html/           /app/html/
COPY services/api_gateway/docker-entrypoint.sh /app/docker-entrypoint.sh

RUN chmod +x /app/docker-entrypoint.sh

EXPOSE 80 443

HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost/healthz || exit 1

ENTRYPOINT ["/app/docker-entrypoint.sh"]
