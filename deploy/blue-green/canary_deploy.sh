#!/bin/bash
set -e

IMAGE=$1
APP=notes-app
NETWORK=notes-net

echo "🟡 Starting CANARY deployment (10%)"

# Ensure network exists
docker network inspect ${NETWORK} >/dev/null 2>&1 || docker network create ${NETWORK}

# ---- FIX STARTS HERE ----

# Remove stopped BLUE container if exists
if docker ps -a --format '{{.Names}}' | grep -q "^${APP}-blue$"; then
  if ! docker ps --format '{{.Names}}' | grep -q "^${APP}-blue$"; then
    echo "🧹 Removing stopped BLUE container"
    docker rm ${APP}-blue
  fi
fi

# Start BLUE if not running
if ! docker ps --format '{{.Names}}' | grep -q "^${APP}-blue$"; then
  echo "🔵 Starting BLUE container"
  docker run -d \
    --name ${APP}-blue \
    --network ${NETWORK} \
    ${IMAGE}
fi

# ---- FIX ENDS HERE ----

# Remove old GREEN if exists
docker rm -f ${APP}-green >/dev/null 2>&1 || true

# Start GREEN (canary)
echo "🟢 Starting GREEN container"
docker run -d \
  --name ${APP}-green \
  --network ${NETWORK} \
  ${IMAGE}

# Health check
echo "❤️ Health check on GREEN"
sleep 10
docker exec ${APP}-green curl -f http://localhost:8000/health/ || {
  echo "❌ Canary health check failed"
  docker rm -f ${APP}-green
  exit 1
}

echo "✅ Canary container healthy"

# Nginx 90/10 traffic split
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

