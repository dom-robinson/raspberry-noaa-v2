# RN2 Container Portability Analysis

## Current State

### ✅ Fully Self-Contained (Inside Container)
- All application code (`/home/pi/raspberry-noaa-v2`)
- All binaries (satdump, predict, etc.)
- Web server (nginx + PHP-FPM)
- Database (SQLite)
- All dependencies and libraries
- Scheduling system (`atd` daemon)
- Configuration files (`.noaa-v2.conf`, `predict.qth`)

### ⚠️ Externalized (Host Mounts)
These are mounted from the host to prevent data loss:

1. **Configuration** (`./config/settings.yml`)
   - User-editable settings
   - Mounted to: `/home/pi/raspberry-noaa-v2/config/settings.yml`

2. **Data Directories** (mounted from `./data/`)
   - Images: `./data/images` → `/srv/images`
   - Videos: `./data/videos` → `/srv/videos`
   - Audio: `./data/audio` → `/srv/audio`
   - Database: `./data/db` → `/home/pi/raspberry-noaa-v2/db`
   - Logs: `./data/logs` → `/var/log/raspberry-noaa-v2`
   - Temp: `./data/tmp` → `/home/pi/raspberry-noaa-v2/tmp`

### 🔴 External Dependencies
1. **RTL-TCP Server** (on WRX at 192.168.0.86:1234)
   - Network connection required
   - Not part of this container

## Portability Assessment

### Current Portability: **PARTIAL**

**What works:**
- Container can be moved to any Docker host
- All application logic is self-contained
- Can run on any architecture that supports the container image

**What needs attention:**
1. **Network dependency**: Requires RTL-TCP server to be accessible
   - Solution: Either bundle rtl_tcp in container OR document network requirement
   
2. **Volume mounts**: Data directories must exist on new host
   - Solution: Create initialization script that sets up directories

3. **Configuration**: `settings.yml` must be present on host
   - Solution: Provide default/template config

4. **atd daemon**: Must be running (currently not auto-started)
   - Solution: Add to container startup/entrypoint

## Recommendations for Full Portability

### Priority 1: Fix atd Auto-Start
- Add `atd` to container entrypoint/startup script
- Ensure it starts automatically when container starts

### Priority 2: Create Initialization Script
- Script that creates all required directories
- Sets proper permissions
- Validates configuration

### Priority 3: Network Configuration
- Document RTL-TCP requirement
- OR: Option to bundle rtl_tcp in same container (if USB passthrough available)
- OR: Make RTL-TCP connection optional/configurable

### Priority 4: Configuration Management
- Provide default `settings.yml` template
- Auto-generate if missing
- Validate on startup

## Implementation Plan (Post 10:32 Pass)

1. **Update Dockerfile/Entrypoint**
   - Start `atd` daemon automatically
   - Create required directories if missing
   - Validate configuration

2. **Create Setup Script**
   - `docker/setup.sh` - Initializes directories and permissions
   - Can be run on new host before starting container

3. **Update docker-compose.yml**
   - Add healthcheck for atd
   - Add restart policy (if not already present)
   - Document volume requirements

4. **Documentation**
   - Update DEPLOYMENT.md with portability notes
   - Add network requirements section
   - Add migration guide

## Current Container Dependencies

```
Container (RN2)
├── Application Code ✅ Self-contained
├── Binaries ✅ Self-contained  
├── Web Server ✅ Self-contained
├── Database ✅ Self-contained
├── atd Daemon ⚠️ Needs auto-start
├── Configuration ⚠️ External mount
├── Data Directories ⚠️ External mounts
└── RTL-TCP Connection 🔴 External network dependency
```

## Conclusion

The container is **mostly self-contained** but requires:
1. External volume mounts for data persistence (intentional)
2. Network access to RTL-TCP server (external dependency)
3. atd daemon auto-start (fixable)
4. Initial setup script (documentation/setup improvement)

These are mostly intentional design choices for data persistence and network-based SDR access. The container itself is portable; the deployment requires proper setup of volumes and network connectivity.




