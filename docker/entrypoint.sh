#!/bin/bash
set -e

echo "=== RN2 Docker Container Starting ==="

# Ensure directories exist with correct permissions
mkdir -p /srv/images /srv/videos /var/log/raspberry-noaa-v2 /run/php
chown -R www-data:www-data /srv/images /srv/videos /var/www/wx-new
chown -R www-data:www-data /opt/raspberry-noaa-v2/db 2>/dev/null || true

# Initialize database if it doesn't exist
if [ ! -f /opt/raspberry-noaa-v2/db/panel.db ]; then
    echo "Initializing database..."
    sqlite3 /opt/raspberry-noaa-v2/db/panel.db < /opt/raspberry-noaa-v2/db_migrations/00_seed_schema.sql
    # Run all migrations
    for migration in /opt/raspberry-noaa-v2/db_migrations/*.sql; do
        echo "Running migration: $migration"
        sqlite3 /opt/raspberry-noaa-v2/db/panel.db < "$migration" 2>/dev/null || true
    done
    chown www-data:www-data /opt/raspberry-noaa-v2/db/panel.db
fi

# Test RTL-SDR connectivity
echo "Testing RTL-SDR..."
if rtl_test -t 2>&1 | grep -q "Found"; then
    echo "✓ RTL-SDR detected"
else
    echo "⚠ Warning: RTL-SDR not detected. Captures will fail!"
fi

# Schedule initial passes
echo "Scheduling satellite passes..."
/opt/raspberry-noaa-v2/scripts/schedule.sh -t >> /var/log/raspberry-noaa-v2/schedule.log 2>&1 || true

echo "=== Starting supervisord ==="
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf

