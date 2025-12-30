#!/bin/bash
#
# Purpose: Simulate a full Meteor pass to test the entire workflow
#          This tests configuration, rtl_tcp detection, SatDump command construction,
#          and identifies issues before the next real pass
#
# Usage: ./test_meteor_pass_simulation.sh [satellite_name]
# Example: ./test_meteor_pass_simulation.sh "METEOR-M2 3"

# Don't exit on error - we want to see all test results
set +e

# import common lib and settings
. "/home/pi/.noaa-v2.conf"
. "$NOAA_HOME/scripts/common.sh"

SAT_NAME="${1:-METEOR-M2 3}"
echo "=== Testing Meteor Pass Simulation for: $SAT_NAME ==="
echo ""

# Test 1: Configuration Loading
echo "Test 1: Configuration Loading"
echo "-----------------------------------"
if [ "$SAT_NAME" == "METEOR-M2 3" ]; then
    SDR_DEVICE_ID=${METEOR_M2_3_SDR_DEVICE_ID:-${meteor_m2_3_sdr_device_id}}
    METEOR_FREQUENCY=$METEOR_M2_3_FREQ
    GAIN=$METEOR_M2_3_GAIN
    echo "  METEOR_M2_3_SDR_DEVICE_ID: $SDR_DEVICE_ID"
    echo "  METEOR_M2_3_FREQ: $METEOR_FREQUENCY"
    echo "  METEOR_M2_3_GAIN: $GAIN"
elif [ "$SAT_NAME" == "METEOR-M2 4" ]; then
    SDR_DEVICE_ID=${METEOR_M2_4_SDR_DEVICE_ID:-${meteor_m2_4_sdr_device_id}}
    METEOR_FREQUENCY=$METEOR_M2_4_FREQ
    GAIN=$METEOR_M2_4_GAIN
    echo "  METEOR_M2_4_SDR_DEVICE_ID: $SDR_DEVICE_ID"
    echo "  METEOR_M2_4_FREQ: $METEOR_FREQUENCY"
    echo "  METEOR_M2_4_GAIN: $GAIN"
else
    echo "  ERROR: Unknown satellite: $SAT_NAME"
    exit 1
fi

if [ -z "$SDR_DEVICE_ID" ]; then
    echo "  ❌ FAIL: SDR_DEVICE_ID is empty!"
    exit 1
fi
echo "  ✅ PASS: Configuration loaded"
echo ""

# Test 2: rtl_tcp Detection
echo "Test 2: rtl_tcp Detection"
echo "-----------------------------------"
RECEIVER_TYPE=${RECEIVER_TYPE:-rtlsdr}
receiver="rtlsdr"
device_args=""
gain_option="--gain"

if [[ "$receiver" == "rtlsdr" ]]; then
    device_args="--source_id $SDR_DEVICE_ID"
fi

if [[ "$SDR_DEVICE_ID" == rtl_tcp=* ]]; then
    hostport="${SDR_DEVICE_ID#rtl_tcp=}"
    RTL_TCP_HOST="${hostport%%:*}"
    RTL_TCP_PORT="${hostport##*:}"
    receiver="rtltcp"
    device_args="--ip_address ${RTL_TCP_HOST} --port ${RTL_TCP_PORT}"
    gain_option="--general_gain"
    echo "  ✅ rtl_tcp detected"
    echo "  Host: $RTL_TCP_HOST"
    echo "  Port: $RTL_TCP_PORT"
else
    echo "  ℹ️  Using local RTL-SDR (device: $SDR_DEVICE_ID)"
fi

echo "  Receiver: $receiver"
echo "  Device args: $device_args"
echo "  Gain option: $gain_option"
echo ""

# Test 3: rtl_tcp Connectivity
echo "Test 3: rtl_tcp Connectivity"
echo "-----------------------------------"
if [[ "$receiver" == "rtltcp" ]]; then
    if nc -z -w 2 "$RTL_TCP_HOST" "$RTL_TCP_PORT" 2>/dev/null; then
        echo "  ✅ PASS: rtl_tcp is reachable at $RTL_TCP_HOST:$RTL_TCP_PORT"
    else
        echo "  ❌ FAIL: rtl_tcp is NOT reachable at $RTL_TCP_HOST:$RTL_TCP_PORT"
        echo "  WARNING: This will cause pass failures!"
    fi
else
    echo "  ⏭️  SKIP: Not using rtl_tcp"
fi
echo ""

# Test 4: SatDump Command Construction
echo "Test 4: SatDump Command Construction"
echo "-----------------------------------"
samplerate="1.024e6"
mode=""
finish_processing="--finish_processing"
bias_tee_option="--bias"
METEOR_FREQUENCY="${METEOR_FREQUENCY:-137.9}"
CAPTURE_TIME=60  # Test with 60 seconds

SATDUMP_CMD="$SATDUMP live meteor_m2-x_lrpt${mode} . --source $receiver $device_args --samplerate $samplerate --frequency ${METEOR_FREQUENCY}e6 $gain_option $GAIN $bias_tee_option $finish_processing --timeout $CAPTURE_TIME"

echo "  SatDump command:"
echo "  $SATDUMP_CMD"
echo ""

# Test 5: Verify SatDump binary exists
echo "Test 5: Verify SatDump Binary"
echo "-----------------------------------"
if command -v satdump >/dev/null 2>&1; then
    SATDUMP_VERSION=$(satdump --version 2>&1 | head -1 || echo "unknown")
    echo "  ✅ PASS: SatDump found: $SATDUMP_VERSION"
else
    echo "  ❌ FAIL: SatDump not found!"
    exit 1
fi
echo ""

# Test 6: Check required directories
echo "Test 6: Required Directories"
echo "-----------------------------------"
DIRS=(
    "/srv/images"
    "/srv/audio/meteor"
    "/tmp/ramfs"
    "/home/pi/raspberry-noaa-v2/tmp/meteor"
    "/home/pi/raspberry-noaa-v2/scripts/image_processors"
)

for dir in "${DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "  ✅ $dir exists"
    else
        echo "  ❌ $dir MISSING"
    fi
done
echo ""

# Test 7: Check image processor scripts
echo "Test 7: Image Processor Scripts"
echo "-----------------------------------"
IMAGE_PROC_DIR="${NOAA_HOME}/scripts/image_processors"
REQUIRED_SCRIPTS=(
    "meteor_normalize_annotate.sh"
    "thumbnail.sh"
)

for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [ -f "$IMAGE_PROC_DIR/$script" ]; then
        if [ -x "$IMAGE_PROC_DIR/$script" ]; then
            echo "  ✅ $script exists and is executable"
        else
            echo "  ⚠️  $script exists but is NOT executable"
        fi
    else
        echo "  ❌ $script MISSING"
    fi
done
echo ""

# Test 8: Check TLE file
echo "Test 8: TLE File"
echo "-----------------------------------"
TLE_FILE="/home/pi/raspberry-noaa-v2/tmp/orbit.tle"
if [ -f "$TLE_FILE" ]; then
    TLE_SIZE=$(wc -l < "$TLE_FILE")
    if [ "$TLE_SIZE" -gt 0 ]; then
        echo "  ✅ TLE file exists ($TLE_SIZE lines)"
        if grep -q "METEOR" "$TLE_FILE" 2>/dev/null; then
            echo "  ✅ TLE file contains Meteor satellites"
        else
            echo "  ⚠️  TLE file does not contain Meteor satellites"
        fi
    else
        echo "  ❌ TLE file is empty"
    fi
else
    echo "  ⚠️  TLE file not found (will be downloaded before pass)"
fi
echo ""

# Test 9: Test receive_meteor.sh script location
echo "Test 9: receive_meteor.sh Script"
echo "-----------------------------------"
SCRIPT_PATH="/home/pi/raspberry-noaa-v2/scripts/receive_meteor.sh"
if [ -f "$SCRIPT_PATH" ]; then
    if [ -x "$SCRIPT_PATH" ]; then
        echo "  ✅ Script exists and is executable"
        # Check if script has rtl_tcp detection
        if grep -q "rtl_tcp=" "$SCRIPT_PATH" 2>/dev/null; then
            echo "  ✅ Script contains rtl_tcp detection code"
        else
            echo "  ❌ Script MISSING rtl_tcp detection code!"
        fi
    else
        echo "  ⚠️  Script exists but is NOT executable"
    fi
else
    echo "  ❌ Script MISSING at $SCRIPT_PATH"
fi
echo ""

# Summary
echo "=== Test Summary ==="
echo "Configuration loaded: ✅"
echo "rtl_tcp detection: $(if [[ "$receiver" == "rtltcp" ]]; then echo "✅"; else echo "⏭️ (not using rtl_tcp)"; fi)"
echo "rtl_tcp connectivity: $(if [[ "$receiver" == "rtltcp" ]] && nc -z -w 1 "$RTL_TCP_HOST" "$RTL_TCP_PORT" 2>/dev/null; then echo "✅"; elif [[ "$receiver" == "rtltcp" ]]; then echo "❌"; else echo "⏭️"; fi)"
echo "SatDump binary: ✅"
echo ""
echo "If all tests pass, the next real pass should work correctly."

