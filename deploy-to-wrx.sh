#!/bin/bash
# Deploy RN2 Docker setup to WRX machine
# Run this from your Mac

set -e

WRX_HOST="wrx"
REMOTE_DIR="/home/pi/rn2-docker"
LOCAL_DIR="$(dirname "$0")"

echo "=== Deploying RN2 Docker to $WRX_HOST ==="
echo ""

# Create remote directory
echo "1. Creating remote directory..."
ssh $WRX_HOST "mkdir -p $REMOTE_DIR"

# Sync files
echo ""
echo "2. Syncing Docker files..."
rsync -avz --progress \
    --exclude '.git' \
    --exclude '*.wav' \
    --exclude '*.cadu' \
    --exclude 'tmp/*' \
    --exclude '__pycache__' \
    --exclude '*.pyc' \
    "$LOCAL_DIR/docker/" \
    "$LOCAL_DIR/raspberry-noaa-v2/" \
    "$LOCAL_DIR/wx-new-deployed/" \
    "$WRX_HOST:$REMOTE_DIR/"

# Reorganize on remote
echo ""
echo "3. Organizing files on remote..."
ssh $WRX_HOST "cd $REMOTE_DIR && \
    mkdir -p raspberry-noaa-v2 wx-new-deployed && \
    [ -d App ] && mv App Config Lib composer.* public vendor wx-new-deployed/ 2>/dev/null || true && \
    [ -d ansible ] && mv ansible assets config db db_backups db_migrations docs scripts software templates webpanel *.sh *.md LICENSE raspberry-noaa-v2/ 2>/dev/null || true"

echo ""
echo "4. Copying current database..."
ssh $WRX_HOST "cp /home/pi/raspberry-noaa-v2/db/panel.db $REMOTE_DIR/raspberry-noaa-v2/db/ 2>/dev/null || true"

echo ""
echo "=== Deployment complete ==="
echo ""
echo "Next steps on the WRX machine:"
echo "  1. ssh $WRX_HOST"
echo "  2. cd $REMOTE_DIR/docker"
echo "  3. Review config/settings.yml"
echo "  4. Run: sudo ./migrate-to-docker.sh"
echo "  5. Run: sudo docker-compose up -d --build"
echo ""
echo "To test without stopping native services:"
echo "  sudo docker-compose up --build"
echo "  # Access at http://wrx:8180 (local only)"



