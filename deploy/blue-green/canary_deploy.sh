#!/bin/bash
set -e

IMAGE=$1
APP=notes-app
NETWORK=notes-net
NGINX_CONTAINER=nginx

echo "🟡 Starting CANARY deployment (10%)"

# -------------------------------
# Ensure Docker network exists
# -------------------------------
docker network inspect ${NETWORK} >/dev/null 2>&1 || docker network create ${NETWORK}

# -------------------------------
# Ensure nginx container is running
# (Docker restart kills it, so we must recreate)
# -------------------------------
if ! docker ps --format '{{.Names}}' | grep -q "^${NGINX_CONTAINER}$"; then
  echo "🚀 Starting nginx container"
  docker rm -f ${NGINX_CONTAINER} 2>/dev/null || true
  docker run -d \
    --name ${NGINX_CONTAINER} \
    --network ${NETWORK} \
    -p 80:80 \
    -v /etc/nginx/conf.d:/etc/nginx/conf.d \
    nginx:latest
fi

# -------------------------------
# Remove stopped BLUE container
# -------------------------------
if docker ps -a --format '{{.Names}}' | grep -q "^${APP}-blue$"; then
  if ! docker ps --format '{{.Names}}' | grep -q "^${APP}-blue$"; then
    docker rm ${APP}-blue
  fi
fi

# -------------------------------
# Start BLUE container
# -------------------------------
if ! docker ps --format '{{.Names}}' | grep -q "^${APP}-blue$"; then
  echo "🔵 Starting BLUE container"
  docker run -d \
    --name ${APP}-blue \
    --network ${NETWORK} \
    ${IMAGE}
fi

# -------------------------------
# Remove old GREEN container
# -------------------------------
docker rm -f ${APP}-green >/dev/null 2>&1 || true

# -------------------------------
# Start GREEN (canary) container
# -------------------------------
echo "🟢 Starting GREEN container"
docker run -d \
  --name ${APP}-green \
  --network ${NETWORK} \
  ${IMAGE}

# -------------------------------
# Health check
# -------------------------------
echo "❤️ Health check on GREEN"
sleep 10
docker exec ${APP}-green curl -f http://localhost:8000/health/ || {
  echo "❌ Canary health check failed"
  docker rm -f ${APP}-green
  exit 1
}

echo "✅ Canary container healthy"

# -------------------------------
# Write nginx config INSIDE nginx container
# -------------------------------
docker exec ${NGINX_CONTAINER} sh -c "cat > /etc/nginx/conf.d/notes-app.conf" <<EOF
resolver 127.0.0.11 valid=10s;

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

# -------------------------------
# Wait for Docker DNS
# -------------------------------
echo "⏳ Waiting for Docker DNS..."
for i in {1..15}; do
  if docker exec ${NGINX_CONTAINER} getent hosts ${APP}-blue >/dev/null 2>&1 && \
     docker exec ${NGINX_CONTAINER} getent hosts ${APP}-green >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

# -------------------------------
# Reload nginx safely
# -------------------------------
docker exec ${NGINX_CONTAINER} nginx -t
docker exec ${NGINX_CONTAINER} nginx -s reload

echo "🟡 Canary live with 10% traffic"

