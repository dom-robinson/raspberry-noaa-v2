#!/bin/bash
# Migration script: Native RN2 → Docker RN2
# Run this on the wrx machine

set -e

echo "=== RN2 Native to Docker Migration ==="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (sudo)"
    exit 1
fi

# Backup current installation
BACKUP_DIR="/home/pi/rn2-backup-$(date +%Y%m%d)"
echo "1. Creating backup at $BACKUP_DIR..."
mkdir -p "$BACKUP_DIR"
cp -r /home/pi/raspberry-noaa-v2/db "$BACKUP_DIR/"
cp -r /home/pi/raspberry-noaa-v2/config "$BACKUP_DIR/"
cp -r /etc/nginx/sites-available "$BACKUP_DIR/"
crontab -l > "$BACKUP_DIR/crontab.bak" 2>/dev/null || true
echo "   ✓ Backup complete"

# Stop native services
echo ""
echo "2. Stopping native services..."
systemctl stop nginx || true
systemctl stop php7.4-fpm || true
echo "   ✓ Services stopped"

# Remove scheduled at jobs
echo ""
echo "3. Clearing scheduled captures..."
for job in $(atq | awk '{print $1}'); do
    atrm "$job" 2>/dev/null || true
done
echo "   ✓ At jobs cleared"

# Remove RN2 crontab entries
echo ""
echo "4. Removing RN2 cron entries..."
# Create temp crontab without RN2 entries
crontab -l 2>/dev/null | grep -v "raspberry-noaa-v2" | grep -v "RN2" > /tmp/crontab.new || true
crontab /tmp/crontab.new
rm /tmp/crontab.new
echo "   ✓ Cron entries removed"

# Check if docker is ready
echo ""
echo "5. Checking Docker..."
if ! docker info >/dev/null 2>&1; then
    echo "   ✗ Docker not running or not accessible"
    exit 1
fi
echo "   ✓ Docker is ready"

# Check if traefik network exists
if ! docker network ls | grep -q traefik; then
    echo "   Creating traefik network..."
    docker network create traefik
fi
echo "   ✓ Traefik network exists"

# Create directory for docker setup
DOCKER_DIR="/home/pi/rn2-docker"
echo ""
echo "6. Setting up Docker directory at $DOCKER_DIR..."
mkdir -p "$DOCKER_DIR"
cd "$DOCKER_DIR"

# Copy database to Docker volume location
echo ""
echo "7. Migrating database..."
docker volume create rn2-db || true
# The database will be copied when the container starts

echo ""
echo "=== Migration Preparation Complete ==="
echo ""
echo "Next steps:"
echo "1. Copy the Docker files to $DOCKER_DIR"
echo "2. Edit docker/config/settings.yml if needed"
echo "3. Run: cd $DOCKER_DIR && docker-compose up -d --build"
echo "4. Verify at https://wrx.liveencode.com"
echo ""
echo "To rollback:"
echo "  docker-compose down"
echo "  systemctl start nginx php7.4-fpm"
echo "  crontab $BACKUP_DIR/crontab.bak"



