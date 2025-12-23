# RN2 Docker Quick Reference

## Essential Commands

```bash
# Navigate to docker directory
cd docker

# Start container
docker compose up -d

# Stop container
docker compose down

# View logs
docker compose logs -f

# Restart container
docker compose restart

# Rebuild after code changes
docker compose build
docker compose up -d

# Access container shell
docker exec -it rn2 bash

# Edit settings
nano config/settings.yml
docker compose restart

# Check scheduled passes
docker exec rn2 sqlite3 /home/pi/raspberry-noaa-v2/db/raspberry-noaa-v2.db "SELECT COUNT(*) FROM predict_passes;"

# Manually schedule passes
docker exec -u pi rn2 bash -c 'cd /home/pi/raspberry-noaa-v2 && ./scripts/schedule.sh -t -x'
```

## Directory Locations

### On Host Machine:
- `config/settings.yml` - RN2 configuration (edit here)
- `data/images/` - Captured satellite images
- `data/videos/` - Generated videos/animations
- `data/audio/` - Raw audio captures
- `data/db/` - SQLite database

### Inside Container:
- `/home/pi/raspberry-noaa-v2/` - RN2 application root
- `/srv/images` - Images (mounted from host)
- `/srv/videos` - Videos (mounted from host)
- `/srv/audio` - Audio (mounted from host)

## Troubleshooting Quick Fixes

### Container won't start
```bash
docker compose logs
docker compose down
docker compose up -d
```

### No passes scheduled
```bash
docker exec -u pi rn2 bash -c 'cd /home/pi/raspberry-noaa-v2 && ./scripts/schedule.sh -t -x'
```

### RTL-SDR not detected
```bash
# Check USB device
lsusb | grep RTL

# Check device permissions
ls -la /dev/bus/usb/

# Restart container with privileged mode (already enabled)
docker compose restart
```

### Permission errors
```bash
# Fix data directory permissions
sudo chown -R $USER:$USER data/
chmod -R 755 data/
```

## Backup & Restore

```bash
# Backup all data
tar -czf backup-$(date +%Y%m%d).tar.gz config/ data/

# Restore backup
tar -xzf backup-YYYYMMDD.tar.gz
```

