#!/bin/bash
set -e

APP=notes-app
NGINX_CONTAINER=nginx
BLUE_WEIGHT=$1
GREEN_WEIGHT=$2

if [ -z "$BLUE_WEIGHT" ] || [ -z "$GREEN_WEIGHT" ]; then
  echo "Usage: traffic_shift.sh <blue_weight> <green_weight>"
  exit 1
fi

echo "🔀 Shifting traffic: BLUE=${BLUE_WEIGHT}% GREEN=${GREEN_WEIGHT}%"

docker exec ${NGINX_CONTAINER} sh -c "cat > /etc/nginx/conf.d/notes-app.conf" <<EOF
resolver 127.0.0.11 valid=10s;

upstream notes_backend {
    server ${APP}-blue:8000 weight=${BLUE_WEIGHT};
    server ${APP}-green:8000 weight=${GREEN_WEIGHT};
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

echo "✅ Traffic updated"
