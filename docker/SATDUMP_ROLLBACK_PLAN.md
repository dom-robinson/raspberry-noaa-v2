# SatDump Rollback Plan

## Current Situation

**Current Version:** SatDump 1.2.2  
**Issue:** JSON config parsing error - "type must be array, but is null"  
**Error occurs:** After TLE loading, during pipeline initialization  
**Affects:** Both live and offline processing modes  
**Status:** All configuration fixes applied, but error persists

## Available Versions

From git repository analysis:
- **1.2.2** (current) - Latest stable
- **1.2.1** - Previous patch release
- **1.2.0** - Major 1.2 release
- **1.1.4** - Last 1.1.x release (likely most stable)
- **1.1.3, 1.1.2, 1.1.1, 1.1.0** - Earlier 1.1.x releases
- **1.0.3, 1.0.2, 1.0.1** - 1.0.x releases

## Rollback Strategy

### Step 1: Rollback to 1.2.0 (Primary Rollback Target)
**Decision:** Skip 1.2.1, go directly to 1.2.0
**Reasoning:** 1.2.0 is a stable major release with 609 commits of changes from 1.2.2, likely avoiding the regression
**Pros:**
- Stable major release
- Well-tested version
- May not have 1.2.2 regression

**Cons:**
- Missing 1.2.1 and 1.2.2 bug fixes
- May have other issues

**Steps:**
1. Modify `docker/Dockerfile` line 131: `git checkout 1.2.0`
2. Rebuild Docker image
3. Test thoroughly
4. If works, commit and deploy

### Step 2: Rollback to 1.1.4 (Fallback if 1.2.0 Fails)
**Pros:**
- Last stable 1.1.x release
- Likely most stable option
- Well-tested in production

**Cons:**
- Older version, missing newer features
- May have different API/behavior
- Requires more testing

**Steps:**
1. Modify `docker/Dockerfile` line 131: `git checkout 1.1.4`
2. Check if build flags are compatible
3. Rebuild Docker image
4. Test extensively
5. If works, commit and deploy

## Risk Assessment

### Low Risk
- Changing git checkout tag in Dockerfile
- Rebuilding Docker image
- Testing in isolated environment

### Medium Risk
- Different version may have different dependencies
- API changes between versions
- Plugin compatibility issues

### High Risk
- Breaking existing working features
- Different config file format
- Missing features we depend on

## Testing Plan

### Phase 1: Build Test
1. Change version in Dockerfile
2. Rebuild image locally
3. Verify SatDump binary exists and runs
4. Check version output

### Phase 2: Basic Functionality
1. Test SatDump startup (no crash)
2. Test config loading
3. Test pipeline loading
4. Test TLE loading
5. Verify no JSON errors

### Phase 3: Live Mode Test
1. Test live capture with rtl_tcp
2. Verify connection works
3. Test 30-second capture
4. Verify output files created

### Phase 4: Integration Test
1. Test full receive_meteor.sh workflow
2. Test with actual pass
3. Verify end-to-end processing
4. Check image output quality

## Rollback Decision Matrix

| Version | Stability | Features | Risk | Action |
|---------|-----------|----------|------|--------|
| 1.2.2 (current) | ❌ Broken | ✅ Latest | High | Testing with fixes |
| 1.2.1 | ⚠️ Unknown | ✅ Recent | Medium | **SKIP** - Not trying |
| 1.2.0 | ✅ Stable | ✅ Good | Low | **First rollback target** |
| 1.1.4 | ✅✅ Very Stable | ⚠️ Older | Low | **Fallback if 1.2.0 fails** |

## Implementation Steps (When Ready)

1. **Backup Current State**
   ```bash
   git branch backup-satdump-1.2.2
   git commit -am "Backup before SatDump rollback"
   ```

2. **Modify Dockerfile**
   - Change `git checkout 1.2.2` to target version
   - Update comment if needed

3. **Rebuild Image**
   ```bash
   # For 1.2.0:
   docker build -t rn2:test-satdump-1.2.0 docker/
   
   # For 1.1.4 (if needed):
   docker build -t rn2:test-satdump-1.1.4 docker/
   ```

4. **Test in Container**
   ```bash
   # Test 1.2.0:
   docker run --rm rn2:test-satdump-1.2.0 satdump --version
   docker run --rm rn2:test-satdump-1.2.0 satdump live meteor_m2-x_lrpt /tmp/test --source rtltcp --ip_address 192.168.0.86 --port 1234 --samplerate 1.024e6 --frequency 137.9e6 --timeout 5
   
   # Test 1.1.4 (if 1.2.0 fails):
   docker run --rm rn2:test-satdump-1.1.4 satdump --version
   docker run --rm rn2:test-satdump-1.1.4 satdump live meteor_m2-x_lrpt /tmp/test --source rtltcp --ip_address 192.168.0.86 --port 1234 --samplerate 1.024e6 --frequency 137.9e6 --timeout 5
   ```

5. **If Successful**
   - Commit changes
   - Rebuild production image
   - Deploy and test with next pass

## Alternative: Wait for Fix

**Option:** Wait for SatDump 1.2.3 or patch
- May fix the JSON bug
- Keep current version
- Monitor SatDump GitHub issues

## Rollback Sequence (Approved Plan)

**Step 0:** Wait for next pass (21:36:47) to test current fixes with 1.2.2  
**Step 1:** If 1.2.2 still broken → **Rollback directly to 1.2.0** (skip 1.2.1)  
**Step 2:** If 1.2.0 fails → **Rollback to 1.1.4** (most stable fallback)

**Rationale:**
- 1.2.0 is a stable major release (609 commits back from 1.2.2)
- More likely to avoid the regression than 1.2.1 (only 116 commits back)
- 1.1.4 is the proven stable fallback if needed

## Notes

- All fixes applied to current version (config patching, pipeline fixes)
- These fixes may work with older versions too
- Can test versions in parallel by building multiple images
- Keep current fixes in place - they may help older versions too

