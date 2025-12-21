# Migration Guide: Move Storage to NAS

## Overview

This guide helps you migrate existing data from local SD card to NAS storage.

## Current Situation

- ✅ **Images**: Already on NAS at `/home/pi/nas/wrx-images`
- ❌ **Videos**: On local SD at `/srv/videos` (4KB - mostly empty)
- ❌ **Audio**: Inside container at `/srv/audio` (135MB - will be lost!)
- ❌ **Config**: On local SD at `./config/settings.yml`

## Migration Steps

### 1. Create NAS Directories

```bash
# On the Pi
mkdir -p /home/pi/nas/wrx-videos
mkdir -p /home/pi/nas/wrx-audio
mkdir -p /home/pi/nas/wrx-config
```

### 2. Copy Existing Data

```bash
# Copy videos (if any)
sudo cp -r /srv/videos/* /home/pi/nas/wrx-videos/ 2>/dev/null || true

# Copy audio from running container
sudo docker exec rn2 tar -czf - -C /srv/audio . | tar -xzf - -C /home/pi/nas/wrx-audio/

# Copy settings.yml
sudo cp /home/pi/rn2-docker/docker/config/settings.yml /home/pi/nas/wrx-config/settings.yml
```

### 3. Set Permissions

```bash
# Set ownership
sudo chown -R www-data:www-data /home/pi/nas/wrx-videos
sudo chown -R www-data:www-data /home/pi/nas/wrx-audio
sudo chown pi:pi /home/pi/nas/wrx-config/settings.yml

# Set permissions
sudo chmod 755 /home/pi/nas/wrx-videos
sudo chmod 755 /home/pi/nas/wrx-audio
sudo chmod 644 /home/pi/nas/wrx-config/settings.yml
```

### 4. Update Docker Compose

The `docker-compose.yml` has already been updated. Just restart:

```bash
cd /home/pi/rn2-docker/docker
sudo docker compose down
sudo docker compose up -d
```

### 5. Verify

```bash
# Check mounts
sudo docker inspect rn2 --format '{{json .Mounts}}' | python3 -m json.tool | grep -E 'Source|Destination'

# Check data is accessible
sudo docker exec rn2 ls -lh /srv/images | head -5
sudo docker exec rn2 ls -lh /srv/videos
sudo docker exec rn2 ls -lh /srv/audio | head -5
```

## Final Structure

```
/home/pi/nas/
├── wrx-images/          # Images (12MB) ✅
├── wrx-videos/          # Videos (4KB) ✅
├── wrx-audio/           # Audio (135MB) ✅
│   ├── noaa/            # NOAA audio files
│   ├── meteor/          # Meteor audio files
│   └── meteor/baseband/ # Baseband recordings
└── wrx-config/          # Configuration ✅
    └── settings.yml     # Main config file
```

## Benefits

- ✅ All data survives SD card replacement
- ✅ Easy to backup (just backup `/home/pi/nas/wrx-*`)
- ✅ Configuration editable on NAS
- ✅ Can be accessed from other machines on network

## Notes

- Database (`rn2-db`) remains on SD card as a Docker volume (small, can be recreated)
- Logs (`rn2-logs`) remain on SD card (can be recreated)
- These are small and can be recreated if needed

