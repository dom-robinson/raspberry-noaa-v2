# SatDump Fix Status

## Issue
SatDump crashes (segfault) when processing baseband files in container, but works fine on host.

## Root Cause Identified
1. Missing library dependencies - plugins require libraries that weren't installed
2. Library path mismatches - plugins expect libraries in `/lib/arm-linux-gnueabihf/` but container has them in `/usr/lib/arm-linux-gnueabihf/`

## Fixes Applied

### 1. Added Missing Dependencies to Dockerfile
- libatomic1, libdeflate0, libgomp1, libjbig0, libjpeg62-turbo
- libopencl1, libtiff5, libvolk2.4, libwebp6

### 2. Created Library Symlinks in Dockerfile  
Plugins expect libraries in `/lib/arm-linux-gnueabihf/` but Debian installs them in `/usr/lib/arm-linux-gnueabihf/`. The Dockerfile now creates symlinks during build.

## Current Status
- Dockerfile updated with all fixes (committed to git)
- Running container has dependencies installed manually
- Running container has symlinks created manually
- **Still segfaulting in baseband mode** - needs further investigation

## Testing
- Host SatDump: ✅ Works perfectly
- Container SatDump live mode: ✅ Works
- Container SatDump baseband mode: ❌ Still crashes after plugin loading

## Next Steps
After rebuild with updated Dockerfile, if still broken:
1. Debug with gdb to find exact crash location
2. Check if specific plugin is causing crash
3. Consider using host SatDump for baseband replay

