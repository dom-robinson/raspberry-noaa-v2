# Storage and Configuration Locations

## Current Status

### ✅ Storage on NAS (Survives Rebuild)
- **Images**: `/srv/images` → `/home/pi/nas/wrx-images` (12MB)
  - ✅ On NAS, survives SD card replacement

### ❌ Storage on Local SD Card (Lost on Rebuild)
- **Videos**: `/srv/videos` → `/srv/videos` (4KB)
  - ❌ On local SD card, will be lost
- **Audio**: `/srv/audio` → Inside container (135MB!)
  - ❌ Not mounted, stored in container, will be lost

### Configuration Files

#### ✅ In Git (Survives Rebuild)
- `docker/config/noaa-v2.conf` - Environment variables
- `docker/config/crontab` - Scheduled tasks
- `wx-new-deployed/` - Web GUI (54 files, baked into image)

#### ❌ On Local SD Card (Lost on Rebuild)
- `docker/config/settings.yml` - Main configuration file
  - Currently at: `/home/pi/rn2-docker/docker/config/settings.yml`
  - Mounted as read-only into container
  - ❌ Not in git, will be lost on SD card replacement

### Web GUI Customizations

- **Location**: `wx-new-deployed/` directory
- **Status**: Baked into Docker image during build
- **Editable**: ❌ Not easily editable after build (requires rebuild)
- **In Git**: ✅ Yes (54 files tracked)

## Recommendations

### 1. Move All Storage to NAS
- Move `/srv/videos` to `/home/pi/nas/wrx-videos`
- Move `/srv/audio` to `/home/pi/nas/wrx-audio`
- This ensures all data survives SD card replacement

### 2. Move Configuration to NAS
- Move `settings.yml` to `/home/pi/nas/wrx-config/settings.yml`
- Keep it editable on the host
- Optionally commit a template to git

### 3. Web GUI Customizations
- **Option A**: Keep in git, rebuild image when changes needed
- **Option B**: Mount web GUI directory from NAS for live editing
  - More flexible but requires careful permission management

## Proposed Structure

```
/home/pi/nas/
├── wrx-images/          # Images (already on NAS ✅)
├── wrx-videos/          # Videos (move from /srv/videos)
├── wrx-audio/           # Audio (move from container)
└── wrx-config/          # Configuration files
    └── settings.yml      # Main config (editable)
```

