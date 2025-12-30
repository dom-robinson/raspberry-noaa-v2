# RN2 Container Restoration Guide

This guide explains how to restore the RN2 Docker container from scratch on a fresh Raspberry Pi system.

## Prerequisites

- Raspberry Pi 4 or Pi 400 (64-bit ARM/aarch64)
- Raspbian OS (64-bit) installed
- Docker and Docker Compose installed
- USB memory stick formatted and mounted (for data storage)
- RTL-SDR device or access to rtl_tcp server

## Quick Start

1. **Clone the repository:**
   ```bash
   git clone <repository-url> RN2
   cd RN2/docker
   ```

2. **Configure settings:**
   - Edit `config/noaa-v2.conf` with your Space-Track.org credentials
   - Edit `config/settings.yml` with your ground station coordinates
   - Ensure USB stick is mounted at `/mnt/usb-docker/`

3. **Build and start:**
   ```bash
   docker compose build --no-cache rn2
   docker compose up -d
   ```

4. **Schedule passes:**
   ```bash
   docker exec -u pi rn2 bash -c 'cd /home/pi/raspberry-noaa-v2 && bash schedule.sh -t -x'
   ```

## Detailed Setup

### 1. System Preparation

#### Install Docker
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
```

#### Install Docker Compose
```bash
sudo apt-get update
sudo apt-get install docker-compose-plugin
```

#### Mount USB Stick
```bash
# Find USB device
lsblk

# Format (if needed - WARNING: destroys data)
sudo mkfs.ext4 /dev/sda1

# Create mount point
sudo mkdir -p /mnt/usb-docker

# Mount (add to /etc/fstab for persistence)
sudo mount /dev/sda1 /mnt/usb-docker
echo "/dev/sda1 /mnt/usb-docker ext4 defaults 0 2" | sudo tee -a /etc/fstab

# Create data directories
sudo mkdir -p /mnt/usb-docker/rn2-data/{images,videos,audio}
sudo chown -R $USER:$USER /mnt/usb-docker/rn2-data
```

### 2. Configuration Files

#### Space-Track.org Credentials
Edit `docker/config/noaa-v2.conf`:
```bash
SPACETRACK_USER=your_username
SPACETRACK_PASS=your_password
```

#### Ground Station Coordinates
Edit `docker/config/settings.yml`:
- Set `LATITUDE` and `LONGITUDE`
- Set `ALTITUDE` (meters above sea level)
- Configure satellite elevation filters (`SAT_MIN_ELEV`, `SCHEDULE_SUN_MIN_ELEV`)

#### SDR Configuration
If using remote rtl_tcp:
```bash
METEOR_M2_3_SDR_DEVICE_ID=rtl_tcp=192.168.0.86:1234
```

### 3. Build the Container

The Dockerfile builds SatDump 1.2.0 from source (stable version, no JSON parsing bugs).

**Build time:** ~30-60 minutes on Raspberry Pi 4

```bash
cd ~/RN2/docker
docker compose build --no-cache rn2
```

**Note:** The build process:
- Compiles SatDump 1.2.0 from source
- Installs all dependencies
- Configures supervisord for service management
- Sets up entrypoint scripts

### 4. Start Services

```bash
docker compose up -d
```

Verify services are running:
```bash
docker exec rn2 supervisorctl status
```

Expected output:
```
atd                              RUNNING
cron                             RUNNING
nginx                            RUNNING
php-fpm                          RUNNING
```

### 5. Initial Setup

#### Fix NOAA_HOME path (if needed)
```bash
docker exec rn2 bash -c 'sed -i "s|NOAA_HOME=/opt/raspberry-noaa-v2|NOAA_HOME=/home/pi/raspberry-noaa-v2|g" /home/pi/.noaa-v2.conf'
```

#### Create scripts directory structure
```bash
docker exec rn2 bash -c 'mkdir -p /home/pi/raspberry-noaa-v2/scripts && cp /home/pi/raspberry-noaa-v2/common.sh /home/pi/raspberry-noaa-v2/scripts/ && cp /home/pi/raspberry-noaa-v2/schedule*.sh /home/pi/raspberry-noaa-v2/scripts/'
```

#### Download TLE files and schedule passes
```bash
docker exec -u pi rn2 bash -c 'cd /home/pi/raspberry-noaa-v2 && bash schedule.sh -t -x'
```

### 6. Verify System

#### Check scheduled passes
```bash
docker exec rn2 atq
```

#### Test SatDump
```bash
docker exec rn2 satdump
# Should show: "Please specify either live/record or pipeline name!"
# (This confirms SatDump 1.2.0 is installed and working)
```

#### Check web interface
Open browser to: `http://<pi-ip>:8080`

## Key Components

### SatDump 1.2.0
- **Version:** 1.2.0 (stable, no JSON parsing bugs)
- **Build:** Compiled from source in Dockerfile
- **Location:** `/usr/bin/satdump`
- **Config:** `/usr/share/satdump/satdump_cfg.json` (auto-created by entrypoint)

### predict
- **Version:** Built from source (64-bit ARM)
- **Location:** `/usr/bin/predict`
- **Config:** `/home/pi/.predict/predict.qth`

### Scheduling
- **TLE Source:** Space-Track.org API (requires authentication)
- **Fallback:** Celestrak (may be blocked)
- **Schedule Script:** `/home/pi/raspberry-noaa-v2/schedule.sh`
- **Jobs:** Managed via `at` daemon

## Troubleshooting

### No passes scheduled
1. Check TLE files exist: `docker exec rn2 ls -lh /home/pi/raspberry-noaa-v2/tmp/orbit.tle`
2. Verify Space-Track credentials in `config/noaa-v2.conf`
3. Re-run scheduling: `docker exec -u pi rn2 bash -c 'cd /home/pi/raspberry-noaa-v2 && bash schedule.sh -t -x'`

### SatDump JSON errors
- **Symptom:** `type must be array, but is null`
- **Solution:** Ensure SatDump 1.2.0 is installed (not 1.2.2). The entrypoint script patches config files automatically.

### Container won't start
- Check logs: `docker logs rn2`
- Verify USB mount: `ls -la /mnt/usb-docker/rn2-data/`
- Check disk space: `df -h`

### Services not running
```bash
docker exec rn2 supervisorctl restart all
docker exec rn2 supervisorctl status
```

## Data Persistence

### On SD Card (fast, limited space)
- Database: `docker/data/db/`
- Logs: `docker/data/logs/`
- Temporary files: `docker/data/tmp/`

### On USB Stick (large, slower)
- Images: `/mnt/usb-docker/rn2-data/images/`
- Videos: `/mnt/usb-docker/rn2-data/videos/`
- Audio/Baseband: `/mnt/usb-docker/rn2-data/audio/`

## Maintenance

### Update TLE files
```bash
docker exec -u pi rn2 bash -c 'cd /home/pi/raspberry-noaa-v2 && bash schedule.sh -t'
```

### Rebuild container (after code changes)
```bash
cd ~/RN2/docker
docker compose down
docker compose build --no-cache rn2
docker compose up -d
```

### Clean up old images
```bash
docker system prune -a
```

## Version Information

- **SatDump:** 1.2.0 (stable)
- **Base Image:** Debian Bookworm (64-bit)
- **Architecture:** ARM64/aarch64
- **Last Updated:** December 30, 2025

## Notes

- The container requires `privileged: true` for USB device access
- All services run as `pi` user (not root) where possible
- SatDump config files are auto-patched on container startup
- TLE files are downloaded from Space-Track.org (requires free account)

