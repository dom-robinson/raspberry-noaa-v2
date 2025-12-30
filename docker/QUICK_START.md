# RN2 Quick Start Guide

## One-Command Setup (After Initial System Prep)

```bash
# 1. Clone repository
git clone https://github.com/dom-robinson/raspberry-noaa-v2.git RN2
cd RN2/docker

# 2. Configure (edit these files):
# - config/noaa-v2.conf: Add Space-Track.org credentials
# - config/settings.yml: Set ground station coordinates

# 3. Mount USB stick (if not already done):
sudo mkdir -p /mnt/usb-docker
sudo mount /dev/sda1 /mnt/usb-docker
sudo mkdir -p /mnt/usb-docker/rn2-data/{images,videos,audio}
sudo chown -R $USER:$USER /mnt/usb-docker/rn2-data

# 4. Build and start
docker compose build --no-cache rn2
docker compose up -d

# 5. Fix paths and schedule passes
docker exec rn2 bash -c 'sed -i "s|NOAA_HOME=/opt/raspberry-noaa-v2|NOAA_HOME=/home/pi/raspberry-noaa-v2|g" /home/pi/.noaa-v2.conf'
docker exec rn2 bash -c 'mkdir -p /home/pi/raspberry-noaa-v2/scripts && cp /home/pi/raspberry-noaa-v2/common.sh /home/pi/raspberry-noaa-v2/scripts/ && cp /home/pi/raspberry-noaa-v2/schedule*.sh /home/pi/raspberry-noaa-v2/scripts/'
docker exec -u pi rn2 bash -c 'cd /home/pi/raspberry-noaa-v2 && bash schedule.sh -t -x'

# 6. Verify
docker exec rn2 atq
docker exec rn2 supervisorctl status
```

## Key Files

- **Restoration Guide:** `docker/RESTORATION_GUIDE.md` (comprehensive)
- **Docker Compose:** `docker/docker-compose.yml`
- **Dockerfile:** `docker/Dockerfile`
- **Config:** `docker/config/noaa-v2.conf`
- **Settings:** `docker/config/settings.yml`

## Essential Configuration

### Space-Track.org Credentials
```bash
# In docker/config/noaa-v2.conf
SPACETRACK_USER=your_username
SPACETRACK_PASS=your_password
```

### Ground Station
```bash
# In docker/config/settings.yml
LATITUDE=50.816368
LONGITUDE=-0.06511
ALTITUDE=30.0
```

### SDR Device
```bash
# For remote rtl_tcp (in docker/config/noaa-v2.conf)
METEOR_M2_3_SDR_DEVICE_ID=rtl_tcp=192.168.0.86:1234
```

## Common Commands

```bash
# Check scheduled passes
docker exec rn2 atq

# View logs
docker logs rn2

# Restart services
docker exec rn2 supervisorctl restart all

# Update TLE and reschedule
docker exec -u pi rn2 bash -c 'cd /home/pi/raspberry-noaa-v2 && bash schedule.sh -t -x'

# Rebuild container
docker compose down
docker compose build --no-cache rn2
docker compose up -d
```

## System Requirements

- Raspberry Pi 4 or Pi 400 (64-bit)
- 4GB+ RAM recommended
- USB stick for data storage (recommended)
- Docker & Docker Compose installed
- Space-Track.org account (free)

## Troubleshooting

See `docker/RESTORATION_GUIDE.md` for detailed troubleshooting.

