#!/bin/bash
set -e

echo "🧹 Cleaning stale docker ports"

for PORT in 8001 8002; do
  if lsof -i :$PORT >/dev/null 2>&1; then
    echo "⚠️ Port $PORT busy — killing docker-proxy"
    sudo fuser -k ${PORT}/tcp || true
  else
    echo "✅ Port $PORT free"
  fi
done

# ❌ DO NOT restart docker in CI/CD
# sudo systemctl restart docker

