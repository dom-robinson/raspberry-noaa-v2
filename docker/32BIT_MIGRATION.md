# 32-bit to 64-bit Migration Strategy

## Current Situation Analysis

### WRX Machine Status
- **Current OS**: 32-bit Raspberry Pi OS (likely based on Debian 11/Bullseye)
- **Hardware**: Raspberry Pi with RTL-SDR attached
- **Current RN2**: Running on 32-bit system
- **Required**: 64-bit OS for latest RN2 container deployment

### Compatibility Assessment

#### What WILL work on 32-bit:
- **RTL-SDR drivers**: Available for both 32-bit and 64-bit
- **Basic hardware access**: USB devices work identically
- **Network configuration**: Same across architectures
- **Most system tools**: Compatible

#### What WON'T work on 32-bit:
- **Current Docker image**: Built for 64-bit (ARM64/aarch64)
- **Some dependencies**: May require 64-bit specific builds
- **Performance**: 64-bit generally better for processing-intensive tasks

#### Risk Assessment for WRX Services

**LOW RISK** (Easy to migrate):
- Static files and data
- Configuration files
- Network services
- Scripts and automation

**MEDIUM RISK** (May need updates):
- Python packages (mostly compatible, may need reinstalls)
- System services (systemd units mostly compatible)
- Database files (SQLite files are architecture-independent)

**HIGH RISK** (Requires attention):
- Compiled binaries (may need recompilation)
- Docker containers (architecture-specific)
- Binary dependencies (must match architecture)

## Migration Strategy Options

### Option 1: Dual-Boot / Test on New SD Card (RECOMMENDED)

**Safest approach** - Test 64-bit on new SD card while keeping 32-bit running.

**Steps:**

1. **Prepare new 64-bit SD card:**
   ```bash
   # Download latest Raspberry Pi OS 64-bit
   # Flash to new SD card
   # Boot new system with different hostname (e.g., wrx-new)
   ```

2. **Migrate services incrementally:**
   - Start with RN2 container (test thoroughly)
   - Migrate one service at a time
   - Keep 32-bit system running until all services verified

3. **Switch when ready:**
   - Shut down 32-bit system
   - Swap SD cards
   - Update network configuration if needed

**Advantages:**
- Zero downtime during migration
- Easy rollback (just swap SD cards)
- Can test everything before committing

**Disadvantages:**
- Requires second SD card
- Slightly more complex process

### Option 2: In-Place Upgrade (NOT RECOMMENDED)

**Risky** - Attempting to upgrade 32-bit to 64-bit in place.

**Why NOT recommended:**
- Not officially supported by Raspberry Pi OS
- High risk of breaking existing services
- Complex recovery if something goes wrong
- May require complete reinstallation anyway

### Option 3: Container-Only Migration (POSSIBLE)

**If WRX only runs RN2 container**, you could:

1. Install 64-bit OS on new SD card
2. Install Docker
3. Deploy RN2 container (uses external volumes)
4. Mount existing data directories

**However**, this assumes:
- No other services on WRX that need migration
- All data already externalized (or easy to copy)
- Network configuration can be easily updated

## Recommended Migration Plan

### Phase 1: Preparation (On 32-bit WRX)

1. **Document all services:**
   ```bash
   # List all running containers
   docker ps -a
   
   # List systemd services
   systemctl list-units --type=service --state=running
   
   # Document network configuration
   cat /etc/network/interfaces
   ip addr show
   
   # Document installed packages
   dpkg -l > packages-list.txt
   ```

2. **Backup everything:**
   ```bash
   # Backup Docker volumes
   docker run --rm -v rn2_data:/data -v $(pwd):/backup alpine tar czf /backup/rn2-volume-backup.tar.gz /data
   
   # Backup configuration files
   tar -czf wrx-config-backup.tar.gz /etc /home/pi/.ssh
   
   # Backup database
   docker exec rn2 sqlite3 /path/to/db .dump > db-backup.sql
   ```

3. **Export container configurations:**
   ```bash
   # Save all docker-compose files
   find . -name "docker-compose.yml" -exec cp {} ./backups/ \;
   ```

### Phase 2: New 64-bit System Setup

1. **Install 64-bit Raspberry Pi OS:**
   - Download from: https://www.raspberrypi.com/software/operating-systems/
   - Flash to SD card
   - Boot and complete initial setup

2. **Install base dependencies:**
   ```bash
   sudo apt-get update
   sudo apt-get upgrade -y
   
   # Install Docker
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh
   sudo usermod -aG docker $USER
   
   # Install Docker Compose
   sudo apt-get install -y docker-compose-plugin
   ```

3. **Restore network configuration:**
   ```bash
   # Copy network config from backup
   sudo cp wrx-config-backup/network-config /etc/network/
   
   # Or configure manually
   sudo raspi-config  # Network options
   ```

### Phase 3: RN2 Container Deployment

1. **Clone repository:**
   ```bash
   cd ~
   git clone https://github.com/dom-robinson/raspberry-noaa-v2.git
   cd raspberry-noaa-v2/docker
   ```

2. **Restore data:**
   ```bash
   # Create data directories
   mkdir -p config data/{images,videos,audio,db,logs,tmp}
   
   # Restore from backup
   tar -xzf rn2-backup.tar.gz -C data/
   cp wrx-config-backup/settings.yml config/
   ```

3. **Build and start:**
   ```bash
   docker compose build
   docker compose up -d
   
   # Verify
   docker compose logs -f
   curl http://localhost
   ```

### Phase 4: Verify and Test

1. **Verify RTL-SDR access:**
   ```bash
   docker exec -it rn2 rtl_test -t
   ```

2. **Check scheduled passes:**
   ```bash
   docker exec -it rn2 bash
   sqlite3 /home/pi/raspberry-noaa-v2/db/raspberry-noaa-v2.db "SELECT COUNT(*) FROM predict_passes;"
   ```

3. **Monitor first capture:**
   ```bash
   docker compose logs -f
   # Wait for next pass and verify capture works
   ```

### Phase 5: Migrate Other Services (If Any)

For each additional service on WRX:

1. **Document service:**
   - Container definition or systemd service
   - Configuration files
   - Data directories
   - Dependencies

2. **Test on 64-bit:**
   - Install dependencies
   - Deploy service
   - Verify functionality

3. **Repeat for all services**

## Service-Specific Migration Notes

### RN2 Container
- ✅ **Fully portable**: All data externalized
- ✅ **Architecture independent**: SQLite database works on both
- ✅ **Configuration**: YAML files are text-based
- ⚠️ **Binaries**: Container includes all compiled binaries (already 64-bit)

### Other Docker Containers
- **Check architecture**: Run `docker inspect <container> | grep Architecture`
- **Rebuild if needed**: Some containers may need rebuilds
- **Test thoroughly**: Verify all functionality

### System Services
- **Most compatible**: systemd services usually work
- **Check dependencies**: May need package reinstalls
- **Verify paths**: Ensure file paths are correct

### Python Scripts
- **Generally compatible**: Python code works on both
- **Reinstall packages**: May need `pip install -r requirements.txt`
- **Check versions**: Ensure Python 3.x versions match

## Rollback Plan

If migration fails:

1. **Immediate rollback:**
   - Power off new system
   - Insert original 32-bit SD card
   - Boot original system
   - Services should work immediately

2. **Data preservation:**
   - All data was backed up before migration
   - External volumes can be mounted to original system
   - No data loss if backups were created

## Testing Checklist

Before final switchover:

- [ ] RN2 container builds successfully
- [ ] Container starts without errors
- [ ] Web interface accessible
- [ ] RTL-SDR device detected
- [ ] Passes scheduled correctly
- [ ] Test capture completes successfully
- [ ] Images appear in web interface
- [ ] Database queries work
- [ ] Logs are being written
- [ ] All external volumes mounted correctly
- [ ] Settings file editable from host
- [ ] Container can be stopped/started cleanly

## Timeline Estimate

- **Phase 1 (Preparation)**: 1-2 hours
- **Phase 2 (New System Setup)**: 1 hour
- **Phase 3 (RN2 Deployment)**: 30 minutes
- **Phase 4 (Verification)**: 2-3 hours (wait for test pass)
- **Phase 5 (Other Services)**: Varies by service count

**Total estimated time**: 5-7 hours (excluding wait times for satellite passes)

## Decision Matrix

### Should you migrate WRX to 64-bit?

**YES, if:**
- ✅ WRX primarily runs RN2 (low service count)
- ✅ You have a spare SD card for testing
- ✅ You can afford 1-2 days of testing
- ✅ You want latest RN2 features and performance

**MAYBE, if:**
- ⚠️ WRX runs multiple critical services
- ⚠️ You can test thoroughly before switching
- ⚠️ All services are well-documented

**NO, if:**
- ❌ WRX runs critical production services
- ❌ No way to test before switching
- ❌ Migration window is too small
- ❌ Services are poorly documented

## Alternative: Keep 32-bit, Use Alternative Deployment

If migration risk is too high:

1. **Deploy RN2 container on pi400** (already 64-bit)
2. **Keep WRX for other services**
3. **Network-attach RTL-SDR** (if possible) or use separate RTL-SDR on pi400
4. **Migrate WRX services separately** when convenient

## Support Resources

- Raspberry Pi OS 64-bit: https://www.raspberrypi.com/software/operating-systems/
- Docker on Raspberry Pi: https://docs.docker.com/engine/install/debian/
- RN2 Repository: https://github.com/dom-robinson/raspberry-noaa-v2

