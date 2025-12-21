#!/bin/bash
#
# Purpose: Replay a saved Meteor baseband recording through SatDump
#          This allows testing and debugging without waiting for the next pass
#
# Parameters:
#   1. Baseband file path (e.g., /srv/audio/meteor/baseband/METEOR-M2-4-20251219-141511.s16)
#   2. Output directory (optional, defaults to /opt/raspberry-noaa-v2/tmp/meteor-replay)
#   3. Satellite name (optional, e.g., "METEOR-M2 4" or "METEOR-M2 3")
#
# Example:
#   ./replay_meteor_baseband.sh /srv/audio/meteor/baseband/METEOR-M2-4-20251219-141511.s16

# import common lib and settings
. "$HOME/.noaa-v2.conf"
. "$NOAA_HOME/scripts/common.sh"

if [ -z "$1" ]; then
    echo "Usage: $0 <baseband_file> [output_dir] [satellite_name]"
    echo ""
    echo "Example:"
    echo "  $0 /srv/audio/meteor/baseband/METEOR-M2-4-20251219-141511.s16"
    exit 1
fi

BASEBAND_FILE="$1"
OUTPUT_DIR="${2:-/opt/raspberry-noaa-v2/tmp/meteor-replay}"
SAT_NAME="${3:-METEOR-M2 4}"

if [ ! -f "$BASEBAND_FILE" ]; then
    log "ERROR: Baseband file not found: $BASEBAND_FILE" "ERROR"
    exit 1
fi

# Determine satellite-specific settings
if [ "$SAT_NAME" == "METEOR-M2 3" ] || [ "$SAT_NAME" == "METEOR-M2-3" ]; then
    SAT_NAME_METEORDEMOD="METEOR-M-2-3"
    METEOR_FREQUENCY=$METEOR_M2_3_FREQ
    interleaving="METEOR_M2_3_80K_INTERLEAVING"
elif [ "$SAT_NAME" == "METEOR-M2 4" ] || [ "$SAT_NAME" == "METEOR-M2-4" ]; then
    SAT_NAME_METEORDEMOD="METEOR-M-2-4"
    METEOR_FREQUENCY=$METEOR_M2_4_FREQ
    interleaving="METEOR_M2_4_80K_INTERLEAVING"
else
    log "WARNING: Unknown satellite name, defaulting to METEOR-M2 4" "WARN"
    SAT_NAME_METEORDEMOD="METEOR-M-2-4"
    METEOR_FREQUENCY=$METEOR_M2_4_FREQ
    interleaving="METEOR_M2_4_80K_INTERLEAVING"
fi

mode="$([[ "${!interleaving}" == "true" ]] && echo "_80k" || echo "")"

# Determine baseband format from file extension or default to u8 (rtl_sdr default)
# rtl_sdr outputs u8 format by default
BASEBAND_FORMAT="u8"
case "$BASEBAND_FILE" in
    *.f32) BASEBAND_FORMAT="f32" ;;
    *.s16) BASEBAND_FORMAT="s16" ;;
    *.s8)  BASEBAND_FORMAT="s8" ;;
    *.u8)  BASEBAND_FORMAT="u8" ;;
esac

# Determine samplerate from config (default to 1.024e6 for rtlsdr)
case "$RECEIVER_TYPE" in
    "rtlsdr")
        SAMPLERATE="1.024e6"
        ;;
    "airspy_mini")
        SAMPLERATE="3e6"
        ;;
    "airspy_r2")
        SAMPLERATE="2.5e6"
        ;;
    "hackrf")
        SAMPLERATE="4e6"
        ;;
    "sdrplay")
        SAMPLERATE="2e6"
        ;;
    *)
        SAMPLERATE="1.024e6"
        ;;
esac

log "Replaying baseband file: $BASEBAND_FILE" "INFO"
log "Output directory: $OUTPUT_DIR" "INFO"
log "Satellite: $SAT_NAME" "INFO"
log "Frequency: ${METEOR_FREQUENCY} MHz" "INFO"
log "Baseband format: $BASEBAND_FORMAT" "INFO"
log "Samplerate: $SAMPLERATE" "INFO"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Process baseband file through SatDump
log "Processing baseband through SatDump..." "INFO"
cd "$OUTPUT_DIR"

# Attempt processing with container SatDump first
$SATDUMP meteor_m2-x_lrpt${mode} baseband "$BASEBAND_FILE" "$OUTPUT_DIR" \
    --samplerate $SAMPLERATE \
    --baseband_format $BASEBAND_FORMAT \
    --finish_processing >> $NOAA_LOG 2>&1

# If it failed with segfault (exit code 139) and we're in a container, try host SatDump
if [ $? -eq 139 ] && [ -f /.dockerenv ]; then
    log "Container SatDump crashed (segfault). Trying host SatDump as fallback..." "WARN"
    # Copy file to host temp and process there
    HOST_TMP="/tmp/replay_baseband_$(basename $BASEBAND_FILE)"
    docker cp "$BASEBAND_FILE" "$(hostname):$HOST_TMP" 2>/dev/null || {
        log "ERROR: Cannot copy file to host for processing" "ERROR"
        exit 1
    }
    
    HOST_OUTPUT="/tmp/replay_output_$(date +%s)"
    docker exec "$(hostname)" satdump meteor_m2-x_lrpt${mode} baseband "$HOST_TMP" "$HOST_OUTPUT" \
        --samplerate $SAMPLERATE \
        --baseband_format $BASEBAND_FORMAT \
        --finish_processing 2>&1 | tee -a $NOAA_LOG
    
    if [ $? -eq 0 ]; then
        # Copy results back to container
        docker cp "$(hostname):$HOST_OUTPUT/." "$OUTPUT_DIR/" 2>/dev/null || true
        log "Host SatDump processing completed, results copied back" "INFO"
    else
        log "ERROR: Host SatDump also failed" "ERROR"
        exit 1
    fi
fi

if [ $? -eq 0 ]; then
    log "Baseband processing completed successfully" "INFO"
    log "Output files in: $OUTPUT_DIR" "INFO"
    
    # List generated files
    log "Generated files:" "INFO"
    find "$OUTPUT_DIR" -type f -name "*.png" -o -name "*.jpg" | head -10 | while read file; do
        log "  - $(basename $file)" "INFO"
    done
else
    log "ERROR: Baseband processing failed. Check logs: $NOAA_LOG" "ERROR"
    exit 1
fi

