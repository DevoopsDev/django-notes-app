#!/bin/bash
set -e

IMAGE=$1
APP=notes-app
NETWORK=notes-net
NGINX_CONTAINER=nginx

echo "🚀 Promoting CANARY → 100%"

# Ensure nginx is running
if ! docker ps --format '{{.Names}}' | grep -q "^${NGINX_CONTAINER}$"; then
  echo "❌ nginx container not running"
  exit 1
fi

# Stop and remove OLD blue
if docker ps --format '{{.Names}}' | grep -q "^${APP}-blue$"; then
  echo "🛑 Removing OLD BLUE container"
  docker rm -f ${APP}-blue
fi

# Promote GREEN → BLUE
echo "🔁 Promoting GREEN → BLUE"
docker rename ${APP}-green ${APP}-blue

# Update nginx config to 100% traffic
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

# Reload nginx
docker exec ${NGINX_CONTAINER} nginx -t
docker exec ${NGINX_CONTAINER} nginx -s reload

echo "✅ Canary promoted to 100% traffic"
