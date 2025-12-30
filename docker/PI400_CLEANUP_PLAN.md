# Pi400 Cleanup and Optimization Plan

## Current Status

**Running Services (Keep):**
- RN2 (docker-rn2)
- Stats project (traefik, collector, admin, timescaledb)
- OpenWebRX (slechev/openwebrxplus-nightly)
- Desktop/Raspbian (for Chromium to view applications)

**Disk Usage:**
- SD Card: 100% full (27GB/29GB used)
- USB Stick: 1% used (3.7MB/15GB used)

## Cleanup Actions

### 1. Move Docker Data to USB Stick

**Docker Build Cache:**
- Current: ~888MB on SD card
- Move to: `/mnt/usb-docker/docker-cache/`
- Configure Docker to use USB for build cache

**Docker Images:**
- Keep essential images on SD card
- Move old/unused images to USB or remove

### 2. Move Application Data to USB

**RN2 Data:**
- ✅ Already moved: images, videos, audio → `/mnt/usb-docker/rn2-data/`
- Keep on USB: All capture outputs

**Stats Data:**
- Move snapshots and data to: `/mnt/usb-docker/stats-data/`
- Update stats container volumes

**OpenWebRX:**
- Check if it stores data, move if needed

### 3. Remove Unnecessary Software

**Snaps:**
- Review and remove unused snaps
- Keep only essential ones

**Packages:**
- Remove development tools not needed for runtime
- Remove unused applications

**Docker:**
- Remove unused images
- Clean up old containers

### 4. Configure Docker to Use USB for Cache

Update Docker daemon config to use USB stick for build cache:
```json
{
  "data-root": "/mnt/usb-docker/docker-data",
  "storage-driver": "overlay2"
}
```

## Progress Monitoring Setup

### Using Screen/Tmux for Long Tasks

**For Builds:**
```bash
screen -S satdump-build -dm bash -c 'cd ~/RN2-build/docker && docker compose build rn2 2>&1 | tee /tmp/satdump-build.log'
```

**Check Progress:**
```bash
screen -r satdump-build  # Attach to see live output
# Or check log:
tail -f /tmp/satdump-build.log
```

**For Cleanup:**
```bash
screen -S cleanup -dm bash -c './cleanup-script.sh 2>&1 | tee /tmp/cleanup.log'
```

## Implementation Steps

1. ✅ Install screen/tmux
2. ✅ Create USB directories for data
3. Move Docker cache to USB
4. Move stats data to USB
5. Clean up unnecessary packages/snaps
6. Configure Docker to use USB for cache
7. Test all services still work
8. Verify disk space freed

## Expected Results

- SD Card: ~20GB free (from 0MB)
- USB Stick: ~10GB used (for data and cache)
- All services: Still running correctly
- Builds: Can complete without disk space issues

