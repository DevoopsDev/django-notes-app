#!/bin/bash
set -e

IMAGE=$1
APP=notes-app
NETWORK=notes-net

echo "🟡 Starting CANARY deployment (10%)"

# Ensure network exists
docker network inspect ${NETWORK} >/dev/null 2>&1 || docker network create ${NETWORK}

# Start BLUE if not running
if ! docker ps --format '{{.Names}}' | grep -q "${APP}-blue"; then
  echo "🔵 Starting BLUE container"
  docker run -d \
    --name ${APP}-blue \
    --network ${NETWORK} \
    ${IMAGE}
fi

# Remove old green if exists
docker rm -f ${APP}-green >/dev/null 2>&1 || true

# Start GREEN (NO PORT BINDING ❗)
echo "🟢 Starting GREEN container"
docker run -d \
  --name ${APP}-green \
  --network ${NETWORK} \
  ${IMAGE}

# Health check inside container
echo "❤️ Health check on GREEN"
sleep 10
docker exec ${APP}-green curl -f http://localhost:8000/health/ || {
  echo "❌ Canary health check failed"
  docker rm -f ${APP}-green
  exit 1
}

echo "✅ Canary container healthy"

# Enable 10% traffic via Nginx
sudo tee /etc/nginx/conf.d/notes-app.conf >/dev/null <<EOF
upstream notes_backend {
    server ${APP}-blue:8000 weight=9;
    server ${APP}-green:8000 weight=1;
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

sudo nginx -t
sudo systemctl reload nginx

echo "🟡 Canary live with 10% traffic"
