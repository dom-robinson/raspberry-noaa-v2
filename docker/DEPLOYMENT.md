# RN2 Docker Deployment Guide

## Overview

This Docker setup makes RN2 completely self-contained and portable. You can:
- Deploy to any machine with Docker and an RTL-SDR
- Switch between RN2 and other SDR applications (e.g., sdr.liveencode.com)
- Clean up native installations completely

## Prerequisites

- Docker and docker-compose installed
- RTL-SDR dongle connected via USB
- Traefik network exists: `docker network create traefik`
- Directories on host: `/srv/images`, `/srv/videos`

## Initial Deployment

1. **Copy files to target machine:**
   ```bash
   scp -r docker/ user@host:/home/user/rn2-docker/
   scp -r raspberry-noaa-v2/ user@host:/home/user/rn2-docker/
   scp -r wx-new-deployed/ user@host:/home/user/rn2-docker/
   ```

2. **Copy .deb packages:**
   ```bash
   scp raspberry-noaa-v2/software/*.deb user@host:/home/user/rn2-docker/raspberry-noaa-v2/software/
   ```

3. **Build and start:**
   ```bash
   cd /home/user/rn2-docker/docker
   docker compose build
   docker compose up -d
   ```

4. **Verify:**
   ```bash
   docker ps | grep rn2
   docker logs rn2
   curl https://wrx.liveencode.com/
   ```

## Configuration

### Location Settings

Edit `docker/config/noaa-v2.conf` before building:
- `LAT`, `LON`, `ALT` - Your coordinates
- `GROUND_STATION_LOCATION` - Your callsign/location

### Satellite Selection

Edit `docker/config/noaa-v2.conf`:
- `METEOR_M2_3_SCHEDULE=true/false`
- `METEOR_M2_4_SCHEDULE=true/false`
- `NOAA_15_SCHEDULE`, etc.

## Switching Between SDR Applications

### Stop RN2, Start SDR App

```bash
cd /home/pi/rn2-docker/docker
./switch-to-sdr.sh
```

This will:
1. Check for upcoming captures
2. Stop RN2 container
3. Start your SDR container

### Stop SDR App, Start RN2

```bash
cd /home/pi/rn2-docker/docker
./switch-to-rn2.sh
```

This will:
1. Stop SDR container
2. Start RN2 container
3. Wait for health check

## Cleanup Native Installation

**⚠️ Only run this AFTER Docker container is proven working!**

```bash
cd /home/pi/rn2-docker/docker
sudo ./cleanup-native.sh
```

This removes:
- `/home/pi/raspberry-noaa-v2`
- `/var/www/wx-new`
- Native nginx config
- RN2 crontab entries
- RN2 at jobs

**Keeps:**
- `/srv/images` (satellite images)
- `/srv/videos` (video files)
- Database (in Docker volume)

## Data Volumes

| Volume | Location | Purpose |
|--------|----------|---------|
| `rn2-db` | Docker volume | SQLite database |
| `rn2-logs` | Docker volume | Application logs |
| `rn2-at-spool` | Docker volume | Scheduled at jobs |
| `/srv/images` | Host bind mount | Captured images |
| `/srv/videos` | Host bind mount | Video files |

## Troubleshooting

### Container won't start
```bash
docker logs rn2
docker inspect rn2
```

### RTL-SDR not detected
```bash
docker exec rn2 rtl_test -t
# Check USB passthrough in docker-compose.yml
```

### Passes not scheduling
```bash
docker exec rn2 atq
docker exec rn2 crontab -l -u pi
docker exec rn2 cat /var/log/raspberry-noaa-v2/schedule.log
```

### Database issues
```bash
docker exec rn2 sqlite3 /opt/raspberry-noaa-v2/db/panel.db ".tables"
docker exec rn2 ls -la /opt/raspberry-noaa-v2/db/
```

## Maintenance

### Update container
```bash
cd /home/pi/rn2-docker/docker
docker compose pull
docker compose build
docker compose up -d
```

### View logs
```bash
docker logs -f rn2
docker exec rn2 tail -f /var/log/raspberry-noaa-v2/output.log
```

### Manual pass scheduling
```bash
docker exec -u pi rn2 bash -c 'source /home/pi/.noaa-v2.conf && cd /opt/raspberry-noaa-v2 && ./scripts/schedule.sh -t'
```

## Portability

To deploy to a new machine:

1. Copy the entire `rn2-docker` directory
2. Ensure RTL-SDR is connected
3. Create Traefik network: `docker network create traefik`
4. Update `docker/config/noaa-v2.conf` with new location
5. Build and start: `docker compose up -d --build`

All configuration is in the container - no host dependencies!

