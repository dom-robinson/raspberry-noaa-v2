# Raspberry NOAA V2 - Docker Edition

Fully containerized deployment of the Raspberry NOAA V2 satellite image capture system.

## Quick Start

```bash
cd docker
cp ../raspberry-noaa-v2/config/settings.yml.sample config/settings.yml
nano config/settings.yml  # Edit with your settings
docker compose build
docker compose up -d
```

Access the web interface at `http://localhost/`

## Features

- ✅ Fully self-contained Docker container
- ✅ Easy removal - all data externalized to host
- ✅ Edit settings.yml on host machine
- ✅ Persistent data storage (images, videos, audio on host)
- ✅ 64-bit optimized for performance
- ✅ Automatic pass scheduling
- ✅ Supports NOAA 15/18/19 and Meteor-M2 3/4 satellites

## Documentation

- **[DEPLOYMENT.md](docker/DEPLOYMENT.md)** - Complete deployment guide
- **[32BIT_MIGRATION.md](docker/32BIT_MIGRATION.md)** - Migration strategy for 32-bit systems

## Architecture

- **Base**: Debian Bookworm (64-bit)
- **Services**: Nginx + PHP-FPM (web), SatDump (Meteor), wxtoimg (NOAA)
- **Storage**: All data externalized via Docker volumes
- **Hardware**: RTL-SDR via USB passthrough

## Requirements

- Raspberry Pi with 64-bit OS
- Docker and Docker Compose
- RTL-SDR dongle
- 20GB+ free disk space

## Repository Structure

```
.
├── docker/
│   ├── Dockerfile              # Container definition
│   ├── docker-compose.yml      # Orchestration
│   ├── DEPLOYMENT.md          # Deployment guide
│   └── 32BIT_MIGRATION.md     # Migration guide
├── raspberry-noaa-v2/         # Upstream RN2 source
└── README.md                  # This file
```

## License

GPL-3.0 (inherited from upstream jekhokie/raspberry-noaa-v2)

## Credits

Based on the excellent work by:
- [jekhokie/raspberry-noaa-v2](https://github.com/jekhokie/raspberry-noaa-v2) - Main RN2 project
- [dom-robinson/raspberry-noaa-v2](https://github.com/dom-robinson/raspberry-noaa-v2) - Fork with enhancements
