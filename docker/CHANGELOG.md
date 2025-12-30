# RN2 Changelog

## 2025-12-30 - rtl_tcp Configuration and Testing Improvements

### Fixed Issues
- **rtl_tcp Detection**: Fixed `receive_meteor.sh` script to properly detect and use rtl_tcp connections
  - Script now correctly switches from `rtlsdr` to `rtltcp` source when `SDR_DEVICE_ID` is in format `rtl_tcp=host:port`
  - Uses `--ip_address` and `--port` parameters instead of `--source_id` for rtl_tcp
  - Switches to `--general_gain` instead of `--gain` for rtl_tcp sources
- **Configuration**: Updated both METEOR-M2 3 and METEOR-M2 4 to use rtl_tcp exclusively
  - Both satellites now use `rtl_tcp=192.168.0.86:1234` from wrx (good antenna)
  - Local RTL-SDR device (no antenna) is no longer used
- **Script Deployment**: Fixed script deployment issue where updated scripts weren't in container
  - Updated `receive_meteor.sh` now includes rtl_tcp detection code
  - Script properly copied to container during testing
- **Image Processing**: Fixed missing image processor scripts in wrong location
  - Scripts copied to `scripts/image_processors/` directory
  - Added graceful handling when no images are produced (avoids convert errors)

### Added Features
- **Comprehensive Testing**: Added `test_meteor_pass_simulation.sh` script
  - Tests configuration loading
  - Validates rtl_tcp detection and connectivity
  - Verifies SatDump command construction
  - Checks all required directories and scripts
  - Can be run before passes to verify setup

### Configuration Changes
- `docker/config/noaa-v2.conf`:
  - `METEOR_M2_3_SDR_DEVICE_ID`: Changed from `0` to `"rtl_tcp=192.168.0.86:1234"`
  - `METEOR_M2_4_SDR_DEVICE_ID`: Changed from `0` to `"rtl_tcp=192.168.0.86:1234"`

### Files Modified
- `raspberry-noaa-v2/scripts/receive_meteor.sh`: Added rtl_tcp detection logic (lines 127-139)
- `docker/config/noaa-v2.conf`: Updated SDR_DEVICE_ID for both Meteor satellites
- `docker/entrypoint.sh`: Already handles script copying (no changes needed)
- `raspberry-noaa-v2/scripts/test_meteor_pass_simulation.sh`: New comprehensive test script

### Known Issues Resolved
- ✅ 21:13 pass failure: Script was missing rtl_tcp detection code
- ✅ 15:17 pass failure: Was using local RTL-SDR instead of rtl_tcp
- ✅ Image processor scripts: Fixed path issues

### Next Steps
- Monitor next pass (02:16 tomorrow for METEOR-M2 4)
- All configuration tests pass - system should work correctly with rtl_tcp

