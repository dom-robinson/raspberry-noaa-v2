# Yesterday's Incident Review - December 26, 2025

## Executive Summary

On December 26, 2025, multiple services crashed on both pi400 (RN2 and stats containers) and wrx systems. The root cause appears to be CPU overload from simultaneous rtl_tcp stream processing and rsync operations, combined with configuration issues that prevented proper container restart.

## Timeline of Events

### Initial Problem (Evening of Dec 26)
- **Time**: ~6pm - 11pm
- **Impact**: Stats containers failed on pi400
- **User Action**: Manual restart at ~11pm

### RN2 Container Failure
- **Time**: 23:12:14 UTC (Dec 26)
- **Exit Code**: 127 (Command not found)
- **Status**: Container stopped and did not restart automatically
- **System Restart**: 09:57:54 UTC (Dec 27)

## Root Causes

### 1. High-Level Root Cause (CPU Overload)

**Issue**: CPU overload from concurrent operations:
- rtl_tcp stream processing from WRX
- rsync operations (data transfer/sync)
- Multiple containerized services running

**Impact**: 
- Services became unresponsive
- Stats containers crashed
- RN2 container failed to restart properly

**Status**: Being addressed in separate WRX workflow

### 2. RN2 Container Specific Root Cause

#### Primary Issue: PHP-FPM Version Mismatch

**Problem**:
- `docker/supervisord.conf` configured to run `/usr/sbin/php-fpm7.4`
- `docker/Dockerfile` installs `php8.2-fpm` (Debian Bookworm)
- Result: Container starts but supervisord fails to start php-fpm, causing nginx to not function properly

**Error Messages**:
```
INFO spawnerr: can't find command '/usr/sbin/php-fpm7.4'
INFO gave up: php-fpm entered FATAL state, too many start retries too quickly
```

**Root Cause**:
- Dockerfile was updated to use Debian Bookworm (php8.2-fpm)
- supervisord.conf was not updated to match
- Legacy configuration from Bullseye (php7.4) remained

#### Secondary Issues Fixed During Yesterday's Work

1. **SatDump rtl_tcp Plugin Architecture Mismatch**
   - **Issue**: Plugin was 32-bit ARM, container was 64-bit aarch64
   - **Fix**: Rebuilt SatDump from source with RTLTCP_SUPPORT=ON during container build
   - **Status**: ✅ Fixed - plugin now built natively for container architecture

2. **Package Name Issues**
   - **Issue**: Debian Bookworm package names differ from Bullseye
   - **Fixes Applied**:
     - `libtiff5` → `libtiff6`
     - `libvolk2.4` → `libvolk2.5`
     - `libwebp6` → `libwebp7`
     - `libfftw3-3` → `libfftw3-double3`
   - **Status**: ✅ Fixed in Dockerfile

3. **Python pip Externally-Managed Environment**
   - **Issue**: Debian Bookworm blocks system-wide pip installs
   - **Fix**: Added `--break-system-packages` flag to pip commands
   - **Status**: ✅ Fixed in Dockerfile

4. **Missing wx-new-deployed Directory**
   - **Issue**: Build context missing webpanel files
   - **Fix**: Ensured directory included in build context
   - **Status**: ✅ Fixed

5. **Port Conflict**
   - **Issue**: Container tried to bind to port 80 (already in use by Traefik)
   - **Fix**: Changed to port 8080 in docker-compose.yml
   - **Status**: ✅ Fixed

## Fixes Applied

### Yesterday's Work (Dec 26)

1. **SatDump Build from Source**
   - Rebuilt SatDump 1.2.2 with rtl_tcp plugin support
   - All dependencies properly configured
   - Build completed successfully at ~13:42 UTC

2. **Container Image Created**
   - Image: `docker-rn2:latest`
   - Size: 1.52GB
   - SHA256: 262e5ad19004
   - Status: ✅ Successfully built

3. **SatDump rtl_tcp Plugin Verification**
   - Plugin built and installed correctly
   - SatDump connects to rtl_tcp successfully
   - Test runs complete without crashes (timeout handled gracefully)

### Fix Required Today (Dec 27)

**Issue**: PHP-FPM version mismatch in supervisord.conf

**Fix**: Update `docker/supervisord.conf` line 16:
```diff
- command=/usr/sbin/php-fpm7.4 -F
+ command=/usr/sbin/php-fpm8.2 -F
```

**Status**: 🔧 Ready to apply

## Current System Status

### pi400 Status
- **System**: Up (restarted at 09:57:54 UTC Dec 27)
- **Stats Containers**: ✅ Running (restarted ~40 minutes ago)
- **RN2 Container**: ❌ Stopped (exited code 127 at 23:12:14 UTC Dec 26)

### RN2 Container Status
- **State**: Exited (127)
- **Last Run**: 21 hours ago
- **Issue**: PHP-FPM configuration mismatch prevents proper startup
- **Fix**: Update supervisord.conf, then restart container

## RN2 Progress Summary

### What Was Accomplished

1. ✅ **Complete Container Rebuild**
   - Migrated from Debian Bullseye to Bookworm
   - Updated all package names for Bookworm compatibility
   - Fixed Python pip externally-managed environment issues

2. ✅ **SatDump Integration**
   - Compiled SatDump 1.2.2 from source
   - Built rtl_tcp plugin natively for container architecture
   - Verified plugin loads and connects correctly
   - Confirmed graceful timeout handling (no crashes)

3. ✅ **Build Process Improvements**
   - Created automated build monitor script
   - Fixed all package dependency issues
   - Container image successfully created

4. ✅ **Configuration Updates**
   - Port changed to 8080 (avoiding Traefik conflict)
   - All dependencies properly configured
   - Database migrations working

### What Still Needs Fixing

1. ❌ **PHP-FPM Configuration** (Current blocker)
   - supervisord.conf needs update to php8.2
   - Prevents container from starting properly

2. ⚠️ **Container Auto-Restart**
   - Container exited but didn't restart
   - `restart: unless-stopped` policy should handle this
   - May need investigation if system was rebooted

## Cleanup Required

1. **Remove Temporary Files**
   - `/tmp/rn2-rebuild.log` (build log - can archive)
   - `/tmp/rn2-build-monitor.log` (monitor log - can archive)
   - `/tmp/docker/` (temporary build context - can remove)

2. **Stop Build Monitor**
   - Build monitor script may still be running
   - Should be stopped now that build is complete

3. **Verify Container Health**
   - After fixing php-fpm, restart and verify all services
   - Check nginx, php-fpm, cron, atd are all running

## Next Steps

1. **Immediate**: Fix supervisord.conf (change php-fpm7.4 → php-fpm8.2)
2. **Immediate**: Restart RN2 container
3. **Verify**: Check all services start correctly
4. **Cleanup**: Remove temporary build files
5. **Monitor**: Watch first scheduled pass to confirm everything works

## Lessons Learned

1. **Configuration Consistency**: When updating base images/versions, must update ALL related configurations
2. **CPU Management**: Need better resource management when multiple CPU-intensive operations run simultaneously
3. **Monitoring**: Automated monitoring helped catch build issues but needs to also monitor runtime failures
4. **Architecture Migration**: Moving from 32-bit to 64-bit requires careful attention to all binary paths and configurations

