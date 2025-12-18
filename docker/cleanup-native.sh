#!/bin/bash
# Clean up native RN2 installation from wrx machine
# Run this AFTER Docker container is proven working

set -e

echo "=== RN2 Native Installation Cleanup ==="
echo ""
echo "This will remove:"
echo "  - /home/pi/raspberry-noaa-v2 (source code)"
echo "  - /var/www/wx-new (webpanel)"
echo "  - Native nginx config for RN2"
echo "  - RN2 crontab entries"
echo "  - RN2 scheduled at jobs"
echo ""
echo "It will KEEP:"
echo "  - /srv/images (satellite images)"
echo "  - /srv/videos (video files)"
echo "  - Database (now in Docker volume)"
echo ""

read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted"
    exit 1
fi

# Check if Docker container is running
if ! docker ps --format '{{.Names}}' | grep -q "^rn2$"; then
    echo "⚠ ERROR: RN2 Docker container is not running!"
    echo "Please start it first: cd /home/pi/rn2-docker/docker && docker compose up -d"
    exit 1
fi

echo ""
echo "1. Removing native RN2 source code..."
if [ -d /home/pi/raspberry-noaa-v2 ]; then
    # Backup database first (should already be in Docker volume)
    if [ -f /home/pi/raspberry-noaa-v2/db/panel.db ]; then
        echo "   Backing up database..."
        cp /home/pi/raspberry-noaa-v2/db/panel.db /tmp/panel.db.backup-$(date +%Y%m%d)
    fi
    rm -rf /home/pi/raspberry-noaa-v2
    echo "   ✓ Removed /home/pi/raspberry-noaa-v2"
else
    echo "   Already removed"
fi

echo ""
echo "2. Removing native webpanel..."
if [ -d /var/www/wx-new ]; then
    rm -rf /var/www/wx-new
    echo "   ✓ Removed /var/www/wx-new"
else
    echo "   Already removed"
fi

echo ""
echo "3. Removing native nginx config..."
if [ -f /etc/nginx/sites-available/wrx-internal ]; then
    rm -f /etc/nginx/sites-available/wrx-internal
    rm -f /etc/nginx/sites-enabled/wrx-internal
    echo "   ✓ Removed nginx config"
else
    echo "   Already removed"
fi

echo ""
echo "4. Removing RN2 crontab entries..."
# Create temp crontab without RN2 entries
crontab -l 2>/dev/null | grep -v "raspberry-noaa-v2" | grep -v "RN2" > /tmp/crontab.new || true
if [ -s /tmp/crontab.new ]; then
    crontab /tmp/crontab.new
    echo "   ✓ Removed RN2 cron entries"
else
    crontab -r 2>/dev/null || true
    echo "   ✓ Cleared crontab (was empty or only RN2 entries)"
fi
rm -f /tmp/crontab.new

echo ""
echo "5. Clearing RN2 at jobs..."
for job in $(atq 2>/dev/null | awk '{print $1}'); do
    atrm "$job" 2>/dev/null || true
done
echo "   ✓ Cleared at jobs"

echo ""
echo "6. Removing .noaa-v2.conf from home..."
if [ -f /home/pi/.noaa-v2.conf ]; then
    mv /home/pi/.noaa-v2.conf /home/pi/.noaa-v2.conf.backup-$(date +%Y%m%d)
    echo "   ✓ Backed up to .noaa-v2.conf.backup-$(date +%Y%m%d)"
fi

echo ""
echo "=== Cleanup Complete ==="
echo ""
echo "Native RN2 installation has been removed."
echo "All functionality is now in the Docker container."
echo ""
echo "To verify:"
echo "  docker ps | grep rn2"
echo "  curl https://wrx.liveencode.com/"
echo ""
echo "Database backup saved to: /tmp/panel.db.backup-$(date +%Y%m%d)"



