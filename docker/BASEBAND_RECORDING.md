# Baseband Recording for Meteor Captures

This feature allows you to record raw IQ signal data during Meteor satellite passes, which can then be replayed later for testing and debugging without waiting for the next satellite pass.

## How It Works

During a Meteor capture, the system can record the raw baseband (IQ) data in parallel with the normal SatDump processing. This raw data is saved to `/srv/audio/meteor/baseband/` and can be processed later using the replay script.

## Configuration

Enable or disable baseband recording in `docker/config/noaa-v2.conf`:

```bash
# Set to true to record raw IQ data alongside live processing
METEOR_BASEBAND_RECORDING=true
```

When enabled, each Meteor pass will create a baseband file named like:
- `METEOR-M2-4-20251219-141511.s16` (or `.u8` depending on format)

## Replaying Baseband Recordings

Use the `replay_meteor_baseband.sh` script to process a saved baseband file:

```bash
# Basic usage
/opt/raspberry-noaa-v2/scripts/replay_meteor_baseband.sh \
    /srv/audio/meteor/baseband/METEOR-M2-4-20251219-141511.s16

# With custom output directory
/opt/raspberry-noaa-v2/scripts/replay_meteor_baseband.sh \
    /srv/audio/meteor/baseband/METEOR-M2-4-20251219-141511.s16 \
    /tmp/meteor-replay-test

# With explicit satellite name
/opt/raspberry-noaa-v2/scripts/replay_meteor_baseband.sh \
    /srv/audio/meteor/baseband/METEOR-M2-4-20251219-141511.s16 \
    /tmp/meteor-replay-test \
    "METEOR-M2 4"
```

## File Format

The baseband files are recorded in **u8** (8-bit unsigned) format by default when using RTL-SDR. The replay script automatically detects the format from the file extension:
- `.u8` - 8-bit unsigned (RTL-SDR default)
- `.s16` - 16-bit signed
- `.s8` - 8-bit signed
- `.f32` - 32-bit float

## Storage Considerations

Baseband files are large! A typical 10-minute Meteor pass at 1.024 MS/s produces approximately:
- **~600 MB** for u8 format
- **~1.2 GB** for s16 format

Make sure you have sufficient storage space. Old baseband files can be manually deleted or you can add cleanup to your cron jobs.

## Use Cases

1. **Testing SatDump fixes**: After fixing SatDump issues, replay previous captures to verify the fix works
2. **Debugging processing issues**: Replay the same signal multiple times with different settings
3. **Development**: Test new processing scripts without waiting for passes
4. **Signal analysis**: Analyze signal quality from past captures

## Example Workflow

1. A Meteor pass occurs and baseband recording is enabled
2. The capture fails due to a SatDump configuration issue
3. You fix the SatDump configuration
4. Replay the saved baseband file to test the fix:
   ```bash
   docker exec -it rn2 bash
   cd /opt/raspberry-noaa-v2
   ./scripts/replay_meteor_baseband.sh /srv/audio/meteor/baseband/METEOR-M2-4-20251219-141511.s16
   ```
5. Verify the fix works before the next pass

## Notes

- Baseband recording runs in parallel with SatDump processing, so it doesn't slow down captures
- The recording automatically stops when the capture duration completes
- Baseband files are stored on persistent storage (not RAM), so they survive container restarts
- Only works with RTL-SDR receivers currently (other SDR types can be added if needed)

