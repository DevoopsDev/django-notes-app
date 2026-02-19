#!/bin/bash
set -e

APP=notes-app
NETWORK=notes-net
NGINX_CONTAINER=nginx

echo "⏪ Rolling back to BLUE (previous stable version)"

# Ensure nginx is running
docker ps --format '{{.Names}}' | grep -q "^${NGINX_CONTAINER}$" || {
  echo "❌ nginx container not running"
  exit 1
}

# Stop & remove GREEN if exists
if docker ps --format '{{.Names}}' | grep -q "^${APP}-green$"; then
  echo "🛑 Removing GREEN container"
  docker rm -f ${APP}-green
fi

# Restore nginx config to BLUE only
docker exec ${NGINX_CONTAINER} sh -c "cat > /etc/nginx/conf.d/notes-app.conf" <<EOF
resolver 127.0.0.11 valid=10s;

upstream notes_backend {
    server ${APP}-blue:8000;
}

server {
    listen 80;
    location / {
        proxy_pass http://notes_backend;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

docker exec ${NGINX_CONTAINER} nginx -t
docker exec ${NGINX_CONTAINER} nginx -s reload

echo "✅ Rollback completed — BLUE is serving 100%"
