# RN2 Docker Setup

Containerized deployment of Raspberry-NOAA-V2 for weather satellite image capture.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     RN2 Container                           │
│  ┌─────────┐  ┌─────────┐  ┌──────┐  ┌──────┐              │
│  │  nginx  │  │ php-fpm │  │ cron │  │  atd │              │
│  │  :8080  │  │         │  │      │  │      │              │
│  └────┬────┘  └────┬────┘  └──┬───┘  └──┬───┘              │
│       │            │          │         │                   │
│       └────────────┴──────────┴─────────┘                   │
│                         │                                   │
│              ┌──────────┴──────────┐                       │
│              │    supervisord      │                       │
│              └─────────────────────┘                       │
│                         │                                   │
│  ┌──────────────────────┴────────────────────────────┐     │
│  │              RN2 Application                       │     │
│  │  /opt/raspberry-noaa-v2 (scripts, config)         │     │
│  │  /var/www/wx-new (webpanel)                       │     │
│  └────────────────────────────────────────────────────┘     │
│                         │                                   │
│  ┌──────────┐  ┌────────┴────────┐  ┌──────────────┐       │
│  │ SatDump  │  │    RTL-SDR      │  │   wxtoimg    │       │
│  └──────────┘  │  (USB device)   │  └──────────────┘       │
│                └─────────────────┘                          │
└─────────────────────────────────────────────────────────────┘
           │                    │
           ▼                    ▼
    ┌──────────────┐    ┌──────────────┐
    │ /srv/images  │    │  RTL-SDR USB │
    │ /srv/videos  │    │   (host)     │
    │   (volumes)  │    └──────────────┘
    └──────────────┘
```

## Prerequisites

- Docker 20.10+
- RTL-SDR dongle connected via USB
- Existing Traefik network (`docker network create traefik`)
- Image/video directories on host (`/srv/images`, `/srv/videos`)

## Quick Start

1. **Copy configuration**:
   ```bash
   cp config/settings.yml.example config/settings.yml
   # Edit with your location, credentials, etc.
   ```

2. **Build and start**:
   ```bash
   docker-compose up -d --build
   ```

3. **View logs**:
   ```bash
   docker-compose logs -f
   ```

4. **Access webpanel**:
   - Via Traefik: https://wrx.liveencode.com
   - Direct: http://localhost:8080

## Configuration

### settings.yml

Key settings to configure:

```yaml
# Your location (decimal degrees)
latitude: 50.816368
longitude: -0.065110
altitude: 30.0

# Satellites to capture
meteor_m2_3_schedule: true
meteor_m2_4_schedule: true

# SDR settings
meteor_m2_3_enable_bias_tee: true
meteor_m2_3_gain: 8
```

### Traefik Integration

The container includes Traefik labels for automatic routing. Alternatively, use file-based routing in your Traefik dynamic config:

```yaml
# routers.yml
http:
  routers:
    wrx-router:
      rule: "Host(`wrx.liveencode.com`)"
      entryPoints:
        - websecure
      service: wrx-service
      tls:
        certResolver: letsencrypt

# services.yml
http:
  services:
    wrx-service:
      loadBalancer:
        servers:
          - url: "http://rn2:8080"
```

## RTL-SDR Access

The container runs in privileged mode to access USB devices. For a more secure setup:

1. Find your RTL-SDR device:
   ```bash
   lsusb | grep RTL
   # Bus 001 Device 004: ID 0bda:2838 Realtek RTL2838
   ```

2. Update docker-compose.yml:
   ```yaml
   privileged: false
   devices:
     - /dev/bus/usb/001/004:/dev/bus/usb/001/004
   ```

## Volume Mounts

| Volume | Purpose | Host Path |
|--------|---------|-----------|
| `rn2-images` | Captured satellite images | `/srv/images` |
| `rn2-videos` | Video recordings | `/srv/videos` |
| `rn2-db` | SQLite database | Named volume |
| `rn2-logs` | Application logs | Named volume |

## Migration from Native Install

1. **Backup existing data**:
   ```bash
   # On the host
   cp -r /home/pi/raspberry-noaa-v2/db ./backup/
   cp -r /srv/images ./backup/
   ```

2. **Stop native services**:
   ```bash
   sudo systemctl stop nginx php7.4-fpm
   sudo systemctl disable nginx php7.4-fpm
   # Remove RN2 crontabs
   crontab -r
   ```

3. **Start container**:
   ```bash
   docker-compose up -d
   ```

4. **Verify**:
   - Check https://wrx.liveencode.com
   - Verify passes are scheduled: `docker exec rn2 atq`
   - Check RTL-SDR: `docker exec rn2 rtl_test -t`

## Troubleshooting

### RTL-SDR not detected
```bash
# Check USB device on host
lsusb | grep RTL

# Check inside container
docker exec rn2 rtl_test -t
```

### No passes scheduled
```bash
# Check scheduler logs
docker exec rn2 cat /var/log/raspberry-noaa-v2/schedule.log

# Manually run scheduler
docker exec rn2 /opt/raspberry-noaa-v2/scripts/schedule.sh -t
```

### Check container health
```bash
docker exec rn2 supervisorctl status
```

## Maintenance

### Update container
```bash
docker-compose pull
docker-compose up -d --build
```

### View capture logs
```bash
docker exec rn2 tail -f /var/log/raspberry-noaa-v2/output.log
```

### Database backup
```bash
docker exec rn2 sqlite3 /opt/raspberry-noaa-v2/db/panel.db ".backup /srv/images/panel.db.bak"
```



