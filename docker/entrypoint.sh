#!/bin/bash
set -e

echo "=== RN2 Docker Container Starting ==="

# Ensure directories exist with correct permissions
mkdir -p /srv/images /srv/videos /srv/audio/noaa /srv/audio/meteor \
    /var/log/raspberry-noaa-v2 /run/php /tmp/ramfs \
    /opt/raspberry-noaa-v2/tmp /opt/raspberry-noaa-v2/db \
    /opt/raspberry-noaa-v2/tmp/meteor \
    /opt/raspberry-noaa-v2/tmp/annotation \
    /var/spool/cron/crontabs /var/spool/cron/atjobs \
    /usr/share/satdump

# Set permissions - images/videos readable by www-data, logs/db owned by pi
chown -R www-data:www-data /srv/images /srv/videos /var/www/wx-new
chown -R pi:pi /srv/audio /tmp/ramfs /var/log/raspberry-noaa-v2 \
    /opt/raspberry-noaa-v2/tmp /opt/raspberry-noaa-v2/db \
    /opt/raspberry-noaa-v2/tmp/meteor \
    /opt/raspberry-noaa-v2/tmp/annotation \
    /home/pi/.noaa-v2.conf /home/pi/.predict

# Fix permissions for annotation config files (needed by image processing)
chmod -R 755 /opt/raspberry-noaa-v2/config/annotation 2>/dev/null || true
chown -R pi:pi /opt/raspberry-noaa-v2/config/annotation 2>/dev/null || true

# Database must be readable by www-data (PHP-FPM)
chmod 755 /opt/raspberry-noaa-v2/db
chmod 644 /opt/raspberry-noaa-v2/db/panel.db 2>/dev/null || true

# Initialize database if it doesn't exist
if [ ! -f /opt/raspberry-noaa-v2/db/panel.db ]; then
    echo "Initializing database..."
    sqlite3 /opt/raspberry-noaa-v2/db/panel.db < /opt/raspberry-noaa-v2/db_migrations/00_seed_schema.sql
    # Run all migrations
    for migration in /opt/raspberry-noaa-v2/db_migrations/*.sql; do
        [ -f "$migration" ] && echo "Running migration: $(basename $migration)" && \
            sqlite3 /opt/raspberry-noaa-v2/db/panel.db < "$migration" 2>/dev/null || true
    done
    chown pi:pi /opt/raspberry-noaa-v2/db/panel.db
fi

# Check for satdump (required for Meteor captures)
if ! command -v satdump >/dev/null 2>&1; then
    echo "⚠ ERROR: satdump not found! Meteor captures will fail."
    echo "   The .deb package may be corrupted. You can copy satdump from the host:"
    echo "   docker cp /usr/bin/satdump rn2:/usr/bin/satdump"
    echo "   docker cp /usr/lib/libsatdump_core.so rn2:/usr/lib/"
    echo "   docker cp /usr/lib/arm-linux-gnueabihf/libjemalloc.so.2 rn2:/usr/lib/arm-linux-gnueabihf/"
    echo "   docker cp /usr/lib/arm-linux-gnueabihf/libvolk.so.2.4 rn2:/usr/lib/arm-linux-gnueabihf/"
    echo "   docker cp /usr/lib/arm-linux-gnueabihf/libnng.so.1.4.0 rn2:/usr/lib/arm-linux-gnueabihf/"
    echo "   docker exec rn2 ln -sf libnng.so.1.4.0 /usr/lib/arm-linux-gnueabihf/libnng.so.1"
else
    echo "✓ satdump found"
    # Check for satdump config file
    if [ ! -f /usr/share/satdump/satdump_cfg.json ]; then
        echo "⚠ WARNING: satdump config file not found at /usr/share/satdump/satdump_cfg.json"
        echo "   Meteor captures may fail. Copy from host:"
        echo "   docker cp /usr/share/satdump rn2:/usr/share/"
    else
        echo "✓ satdump config found"
    fi
fi

# Test RTL-SDR connectivity
echo "Testing RTL-SDR..."
if rtl_test -t 2>&1 | grep -q "Found"; then
    echo "✓ RTL-SDR detected"
else
    echo "⚠ Warning: RTL-SDR not detected. Captures will fail!"
fi

# Set up cron for daily scheduling
if [ -f /etc/cron.d/rn2 ]; then
    # Install crontab for pi user
    crontab -u pi /etc/cron.d/rn2 2>/dev/null || {
        # Alternative: append to existing crontab
        (crontab -u pi -l 2>/dev/null; cat /etc/cron.d/rn2) | crontab -u pi - 2>/dev/null || true
    }
    echo "✓ Crontab installed for pi user"
fi

# Schedule initial passes as pi user
echo "Scheduling satellite passes..."
su - pi -c "source /home/pi/.noaa-v2.conf && cd /opt/raspberry-noaa-v2 && ./scripts/schedule.sh -t" >> /var/log/raspberry-noaa-v2/schedule.log 2>&1 || true

echo "=== Starting supervisord ==="
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf

