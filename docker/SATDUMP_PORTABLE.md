# Portable SatDump Installation

## Problem

The original SatDump `.deb` package in the repository was corrupted, causing Docker builds to fail. Additionally, copying SatDump from the host at runtime is not portable - it won't work on fresh deployments or after SD card recovery.

## Solution

SatDump files are now **extracted from a working installation** and **baked directly into the Docker image**. This makes the image:

- ✅ **Self-contained** - No dependency on host system
- ✅ **Portable** - Works on any machine, fresh installs, or after recovery
- ✅ **Reliable** - No runtime copying or installation needed
- ✅ **Version-controlled** - SatDump files are committed to git

## How It Works

1. **Extraction Script** (`docker/scripts/extract-satdump.sh`):
   - Extracts working SatDump binary, libraries, config, and plugins from host
   - Creates `docker/satdump-files/` directory structure
   - Can be run on any machine with a working SatDump installation

2. **Dockerfile**:
   - Copies extracted files directly into the image during build
   - No `.deb` installation needed
   - Verifies SatDump is present after copy

3. **Entrypoint**:
   - Simply verifies SatDump exists (should always pass)
   - No fallback copying needed

## Updating SatDump

If you need to update SatDump to a newer version:

1. Install the new SatDump version on a working system
2. Run the extraction script:
   ```bash
   ./docker/scripts/extract-satdump.sh docker/satdump-files
   ```
3. Commit the updated files to git
4. Rebuild the Docker image

## Files Included

- `/usr/bin/satdump` - Main binary
- `/usr/lib/libsatdump_core.so` - Core library
- `/usr/lib/arm-linux-gnueabihf/` - Shared libraries (jemalloc, volk, nng)
- `/usr/share/satdump/` - Config, pipelines, resources
- `/usr/lib/satdump/plugins/` - All SatDump plugins

## Deployment Scenarios

### Fresh Deployment
✅ Works - SatDump is in the image, no host dependency

### SD Card Recovery
✅ Works - Just rebuild the image from git, SatDump files are included

### Different Machine
✅ Works - Docker image is self-contained

### Container Rebuild
✅ Works - SatDump files are in git, build succeeds

## Size Impact

The extracted SatDump files add approximately **57MB** to the repository. This is acceptable given the portability benefits.

## Future Improvements

If the SatDump `.deb` package is ever fixed or a reliable source becomes available, we could:
- Download from GitHub releases during build
- Use a package repository
- Build from source (more complex)

For now, the extracted files approach is the most reliable solution.

