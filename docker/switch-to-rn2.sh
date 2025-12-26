#!/bin/bash
# Switch from SDR to RN2 container
# This stops the SDR container and starts RN2

set -e

RN2_DIR="/home/pi/rn2-docker/docker"
SDR_CONTAINER="sdr"  # Adjust this to your SDR container name

echo "=== Switching from SDR to RN2 container ==="

# Check if SDR is running
if docker ps --format '{{.Names}}' | grep -q "^${SDR_CONTAINER}$"; then
    echo "Stopping SDR container..."
    docker stop "$SDR_CONTAINER"
    echo "✓ SDR stopped"
else
    echo "SDR is not running"
fi

# Start RN2 container
echo "Starting RN2 container..."
cd "$RN2_DIR"
docker compose up -d rn2

# Wait for container to be healthy
echo "Waiting for RN2 to be healthy..."
for i in {1..30}; do
    if docker inspect rn2 --format '{{.State.Health.Status}}' 2>/dev/null | grep -q "healthy"; then
        echo "✓ RN2 is healthy"
        break
    fi
    sleep 1
done

# Update Traefik routing to point to RN2
TRAEFIK_CONFIG="/home/d2/stats/traefik-config/dynamic/http/services.yml"
if [ -f "$TRAEFIK_CONFIG" ]; then
    echo "Updating Traefik routing to point to RN2..."
    cat > "$TRAEFIK_CONFIG" << 'EOF'
http:
  services:
    wrx-service:
      loadBalancer:
        servers:
          - url: "http://pi400:8080"
EOF
    echo "✓ Traefik routing updated to RN2"
    # Reload Traefik (file provider watches for changes, but we can verify)
    docker restart stats-traefik >/dev/null 2>&1 || true
else
    echo "⚠ Traefik config not found at $TRAEFIK_CONFIG"
fi

echo ""
echo "=== Switch complete ==="
echo "SDR: stopped"
echo "RN2: running"
echo "Routing: wrx.liveencode.com -> RN2 (pi400:8080)"
echo ""
echo "To switch back: ./switch-to-sdr.sh"



