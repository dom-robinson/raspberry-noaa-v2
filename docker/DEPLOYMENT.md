# RN2 Docker Deployment Guide

This guide provides complete instructions for deploying the Raspberry NOAA V2 (RN2) system as a fully self-contained Docker container.

## Features

- **Fully Self-Contained**: All dependencies bundled in Docker image
- **Easy Removal**: Simply stop and remove container; all data externalized
- **External Configuration**: Edit `settings.yml` on host machine without entering container
- **Data Persistence**: All captured images, videos, and audio stored on host machine
- **Portable**: Can be deployed to any machine with Docker installed

## Prerequisites

### System Requirements
- Raspberry Pi with 64-bit OS (Raspberry Pi OS 64-bit recommended)
- Docker and Docker Compose installed
- RTL-SDR dongle (for satellite reception)
- Sufficient disk space for captures (recommended: 20GB+)

### Install Docker

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo apt-get update
sudo apt-get install -y docker-compose-plugin

# Log out and back in for group changes to take effect
```

## Quick Start

### 1. Clone Repository

```bash
cd ~
git clone https://github.com/dom-robinson/raspberry-noaa-v2.git
cd raspberry-noaa-v2/docker
```

### 2. Prepare External Directories

```bash
# Create directories for external data storage
mkdir -p config
mkdir -p data/{images,videos,audio,db,logs,tmp}

# Copy and configure settings file
cp ../raspberry-noaa-v2/config/settings.yml.sample config/settings.yml
nano config/settings.yml  # Edit with your location, frequencies, etc.
```

### 3. Configure Settings

Edit `config/settings.yml` with your specific configuration:

```yaml
# Location (update with your coordinates)
latitude: 50.816368
longitude: -0.065110
altitude: 30.0

# Receiver settings
receiver_type: rtlsdr
meteor_decoder: satdump
noaa_decoder: wxtoimg

# Enable satellites you want to receive
meteor_m2_3_schedule: true
meteor_m2_4_schedule: true
noaa_15_schedule: true
noaa_18_schedule: true
noaa_19_schedule: true
```

### 4. Build and Start Container

```bash
# Build the Docker image
docker compose build

# Start the container
docker compose up -d

# View logs
docker compose logs -f
```

### 5. Access Web Interface

Open your browser and navigate to:
- `http://<pi-ip-address>/` or `http://localhost/`

The web interface shows scheduled passes, captured images, and system status.

## Directory Structure

```
docker/
├── Dockerfile              # Container build definition
├── docker-compose.yml      # Container orchestration
├── config/
│   └── settings.yml        # RN2 configuration (editable on host)
└── data/
    ├── images/            # Captured satellite images
    ├── videos/            # Generated videos/animations
    ├── audio/             # Raw audio captures
    ├── db/                # SQLite database
    ├── logs/              # Application logs
    └── tmp/               # Temporary files
```

## Managing the Container

### Start Container
```bash
docker compose up -d
```

### Stop Container
```bash
docker compose up -d
```

### View Logs
```bash
# Follow logs in real-time
docker compose logs -f

# View last 100 lines
docker compose logs --tail=100
```

### Restart Container
```bash
docker compose restart
```

### Remove Container (Keeps Data)
```bash
# Stop and remove container, but keep volumes
docker compose down

# Data remains in docker/data/ directory
```

### Complete Removal
```bash
# Remove container and all data
docker compose down -v
rm -rf data/ config/
```

## Editing Configuration

### Settings File

The `settings.yml` file is mounted from the host, so you can edit it directly:

```bash
# Edit on host machine
nano docker/config/settings.yml

# Restart container to apply changes
docker compose restart
```

### Database Access

```bash
# Access database from host
docker exec -it rn2 sqlite3 /home/pi/raspberry-noaa-v2/db/raspberry-noaa-v2.db

# Or copy database to host for backup
docker cp rn2:/home/pi/raspberry-noaa-v2/db/raspberry-noaa-v2.db ./data/db/
```

## Updating the Container

### Update Code and Rebuild

```bash
# Pull latest code
cd ~/raspberry-noaa-v2
git pull

# Rebuild container
cd docker
docker compose build

# Restart with new image
docker compose down
docker compose up -d
```

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker compose logs

# Check if ports are in use
sudo netstat -tlnp | grep :80

# Verify USB device access
lsusb
```

### No Passes Scheduled

```bash
# Enter container and manually run scheduler
docker exec -it rn2 bash
cd /home/pi/raspberry-noaa-v2
./scripts/schedule.sh -t -x

# Check database
sqlite3 db/raspberry-noaa-v2.db "SELECT COUNT(*) FROM predict_passes;"
```

### Permission Issues

```bash
# Fix permissions on data directories
sudo chown -R $USER:$USER docker/data/
chmod -R 755 docker/data/
```

### RTL-SDR Not Detected

```bash
# Check USB device
lsusb | grep RTL

# Verify device permissions
ls -la /dev/bus/usb/

# Add udev rules if needed
sudo nano /etc/udev/rules.d/20-rtlsdr.rules
# Add: SUBSYSTEM=="usb", ATTRS{idVendor}=="0bda", ATTRS{idProduct}=="2838", GROUP="plugdev", MODE="0666"
```

## Backup and Restore

### Backup Data

```bash
# Backup all captures and data
tar -czf rn2-backup-$(date +%Y%m%d).tar.gz docker/data/ docker/config/

# Backup database only
docker exec rn2 sqlite3 /home/pi/raspberry-noaa-v2/db/raspberry-noaa-v2.db .dump > backup.sql
```

### Restore Data

```bash
# Extract backup
tar -xzf rn2-backup-YYYYMMDD.tar.gz

# Restore database
docker exec -i rn2 sqlite3 /home/pi/raspberry-noaa-v2/db/raspberry-noaa-v2.db < backup.sql
```

## Migration to New Machine

1. **Backup everything:**
   ```bash
   tar -czf rn2-migration.tar.gz docker/data/ docker/config/
   ```

2. **On new machine, clone repository:**
   ```bash
   git clone https://github.com/dom-robinson/raspberry-noaa-v2.git
   cd raspberry-noaa-v2/docker
   ```

3. **Extract backup:**
   ```bash
   tar -xzf rn2-migration.tar.gz -C .
   ```

4. **Build and start:**
   ```bash
   docker compose build
   docker compose up -d
   ```

## Architecture Notes

- **Base Image**: `debian:bookworm-slim` (64-bit)
- **Services**: Nginx (web server), PHP-FPM (web interface), SatDump (Meteor decoding)
- **Volume Mounts**: All persistent data externalized to host
- **Privileged Mode**: Required for USB device access (RTL-SDR)
- **Port 80**: Web interface exposed on host

## Support

For issues or questions:
- GitHub Issues: https://github.com/dom-robinson/raspberry-noaa-v2/issues
- Documentation: See `docs/` directory in repository
