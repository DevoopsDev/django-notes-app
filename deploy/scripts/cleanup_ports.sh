#!/bin/bash
set -e

PORTS=(8001 8002)

echo "🧹 Cleaning stale docker ports"

for PORT in "${PORTS[@]}"; do
  if sudo ss -lntp | grep -q ":${PORT} "; then
    echo "⚠️ Port ${PORT} busy — killing docker-proxy"
    sudo pkill -f "docker-proxy.*:${PORT}" || true
  else
    echo "✅ Port ${PORT} free"
  fi
done

echo "🔁 Restarting Docker"
sudo systemctl restart docker
sleep 5
