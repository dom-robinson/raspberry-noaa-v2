# SatDump Baseband Processing Crash - Test Findings

## Problem
SatDump crashes with segmentation fault when processing baseband files in the container, but works fine in live mode.

## Test Results
- ✅ Signal capture works: Successfully captured 15 seconds of signal (23MB baseband file)
- ✅ SatDump loads: Binary loads and plugins load successfully
- ✅ Live mode works: `satdump meteor_m2-x_lrpt live ...` works without crashing
- ❌ Baseband mode crashes: `satdump meteor_m2-x_lrpt baseband ...` segfaults after loading plugins

## Symptoms
```
[22:53:41] (I) Loading plugins from /usr/lib/satdump/plugins
[SEGMENTATION FAULT - exit code 139]
```

## Possible Causes
1. Plugin compatibility issue with baseband processing mode
2. Missing or incompatible library for baseband processing
3. Architecture/ABI mismatch in plugins or libraries
4. Memory allocation issue in baseband decoder

## Workaround Options
1. Use live mode instead of baseband replay (tested and working)
2. Process on host instead of container
3. Debug with gdb to find exact crash location
4. Re-extract SatDump files from host that works with baseband mode

## Status
This explains why the 21:22 pass failed - SatDump crashed when trying to process the live signal.
