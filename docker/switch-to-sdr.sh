#!/bin/bash
# Switch from RN2 to SDR container
# This stops RN2 and starts the SDR container (sdr.liveencode.com)

set -e

RN2_DIR="/home/pi/rn2-docker/docker"
SDR_CONTAINER="sdr"  # Adjust this to your SDR container name

echo "=== Switching from RN2 to SDR container ==="

# Check if RN2 is running
if docker ps --format '{{.Names}}' | grep -q "^rn2$"; then
    echo "Stopping RN2 container..."
    cd "$RN2_DIR"
    docker compose stop rn2
    echo "✓ RN2 stopped"
else
    echo "RN2 is not running"
fi

# Check if there are any scheduled captures in the next hour
echo "Checking for upcoming captures..."
UPCOMING=$(docker exec rn2 atq 2>/dev/null | wc -l || echo "0")
if [ "$UPCOMING" -gt 0 ]; then
    echo "⚠ Warning: RN2 has $UPCOMING scheduled capture(s)"
    echo "Consider waiting until after captures complete"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted"
        exit 1
    fi
fi

# Start SDR container
echo "Starting SDR container..."
if docker ps -a --format '{{.Names}}' | grep -q "^${SDR_CONTAINER}$"; then
    docker start "$SDR_CONTAINER"
    echo "✓ SDR container started"
else
    echo "⚠ SDR container '$SDR_CONTAINER' not found"
    echo "Please start it manually: docker start $SDR_CONTAINER"
fi

# Update Traefik routing (disable RN2 routing or point to SDR if applicable)
TRAEFIK_CONFIG="/home/d2/stats/traefik-config/dynamic/http/services.yml"
if [ -f "$TRAEFIK_CONFIG" ]; then
    echo "Updating Traefik routing..."
    # Option 1: Disable routing by pointing to a non-existent service (will cause 503)
    # Option 2: Point to SDR service if it exists
    # For now, we'll comment it out or point to a placeholder
    # The user can configure SDR routing separately if needed
    echo "⚠ Traefik routing still points to RN2. Update $TRAEFIK_CONFIG manually if needed."
    echo "   Current config will cause 503 errors until RN2 is back or routing is updated."
fi

echo ""
echo "=== Switch complete ==="
echo "RN2: stopped"
echo "SDR: running"
echo "Routing: wrx.liveencode.com -> (needs manual update if SDR should be routed)"
echo ""
echo "To switch back: ./switch-to-rn2.sh"



